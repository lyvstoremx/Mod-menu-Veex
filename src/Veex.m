// 3.7
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <Security/Security.h>
#import <math.h>

typedef struct { float x, y, z; } V3;

static BOOL  g_esp = YES;
static BOOL  g_box = YES;
static BOOL  g_line = NO;
static BOOL  g_name = NO;
static BOOL  g_dist = NO;
static BOOL  g_aim = YES;
static int   g_color = 0;
static float g_fov = 60.f;
static float g_scale = 1.f;
static float g_aimFov = 180.f;
static float g_aimSm = 0.35f;

static uint64_t g_local = 0;
static float g_mtx[16];
static BOOL  g_mtxOk = NO;
static int   g_tIdx = 1;
static CGSize g_sz = {926, 428};

static UIWindow *g_win;
static UIButton *g_bub;
static UIView *g_panel, *g_over;
static UIScrollView *g_scroll;
static UILabel *g_hud;
static CADisplayLink *g_link;
static NSMutableArray *g_lays, *g_txts;
static NSTimer *g_mount;

static BOOL VXRead(uint64_t a, void *b, size_t n) {
    if (!a) return NO;
    vm_size_t out = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)a, n, (vm_address_t)b, &out) == KERN_SUCCESS && out == n;
}
static BOOL VXWrite(uint64_t a, const void *b, size_t n) {
    if (!a || !b || !n) return NO;
    vm_address_t page = (vm_address_t)(a & ~0xFFFULL);
    vm_protect(mach_task_self(), page, 0x1000, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    memcpy((void *)(uintptr_t)a, b, n);
    return YES;
}
static uint64_t VXPtr(uint64_t a) {
    uint64_t v = 0;
    if (!VXRead(a, &v, 8) || v < 0x100000000ULL) return 0;
    return v;
}
static int VXInt(uint64_t a) { int v = 0; VXRead(a, &v, 4); return v; }
static BOOL VXFin3(V3 o) {
    if (isnan(o.x)||isnan(o.y)||isnan(o.z)||isinf(o.x)||isinf(o.y)||isinf(o.z)) return NO;
    return fabsf(o.x) < 30000.f && fabsf(o.y) < 30000.f && fabsf(o.z) < 30000.f;
}
static NSString *VXStr(uint64_t a) {
    uint64_t p = VXPtr(a); if (!p) return nil;
    char b[64]; memset(b, 0, sizeof b);
    if (!VXRead(p + 0x10, b, sizeof b - 1)) return nil;
    NSString *s = [NSString stringWithUTF8String:b];
    return (s.length >= 2 && s.length <= 20) ? s : nil;
}

static void *(*p_domain_get)(void);
static void *(*p_domain_assembly_open)(void *, const char *);
static void *(*p_assembly_get_image)(void *);
static void *(*p_class_from_name)(void *, const char *, const char *);
static void *(*p_class_get_field_from_name)(void *, const char *);
static void  (*p_field_static_get_value)(void *, void *);

static BOOL VXIl2Cpp(void) {
    static BOOL ok = NO; static dispatch_once_t o;
    dispatch_once(&o, ^{
        p_domain_get = dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
        p_domain_assembly_open = dlsym(RTLD_DEFAULT, "il2cpp_domain_assembly_open");
        p_assembly_get_image = dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
        p_class_from_name = dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
        p_class_get_field_from_name = dlsym(RTLD_DEFAULT, "il2cpp_class_get_field_from_name");
        p_field_static_get_value = dlsym(RTLD_DEFAULT, "il2cpp_field_static_get_value");
        ok = p_domain_get && p_domain_assembly_open && p_assembly_get_image &&
             p_class_from_name && p_class_get_field_from_name && p_field_static_get_value;
    });
    return ok;
}
static uint64_t VXFacade(void) {
    if (!VXIl2Cpp()) return 0;
    void *d = p_domain_get(); if (!d) return 0;
    void *a = p_domain_assembly_open(d, "Assembly-CSharp"); if (!a) return 0;
    void *img = p_assembly_get_image(a); if (!img) return 0;
    void *k = p_class_from_name(img, "", "GameFacade"); if (!k) return 0;
    void *f = p_class_get_field_from_name(k, "CurrentMatchGame"); if (!f) return 0;
    void *v = NULL; p_field_static_get_value(f, &v);
    return (uint64_t)v;
}

static BOOL VXTryMtx(uint64_t addr) {
    if (!addr) return NO;
    float m[16];
    if (!VXRead(addr, m, 64)) return NO;
    for (int i = 0; i < 16; i++) if (isnan(m[i]) || isinf(m[i])) return NO;
    float rot = fabsf(m[0]) + fabsf(m[5]) + fabsf(m[10]);
    if (rot < 0.3f || rot > 8.f) return NO;
    memcpy(g_mtx, m, 64);
    float A = fabsf(m[12])+fabsf(m[13])+fabsf(m[14]);
    float B = fabsf(m[3])+fabsf(m[7])+fabsf(m[11]);
    g_tIdx = (B > A * 2.f) ? 0 : 1;
    g_mtxOk = YES;
    return YES;
}
static BOOL VXLoadMatrix(uint64_t cam) {
    if (!cam) return NO;
    uint64_t n = VXPtr(cam + 0x10);
    uint64_t t[8] = { n?n+0xD8:0, n?n+0x80:0, n?n+0xC0:0, n?n+0x100:0, cam+0xD8, cam+0xDC, cam+0x80, cam+0x10 };
    for (int i = 0; i < 8; i++) if (VXTryMtx(t[i])) return YES;
    g_mtxOk = NO; return NO;
}
static uint64_t VXFindCam(uint64_t mg) {
    uint64_t offs[] = { 0xD8, 0xB8, 0xC0, 0xE0, 0xF0, 0xA8 };
    for (int i = 0; i < 6; i++) {
        uint64_t a = VXPtr(mg + offs[i]); if (!a) continue;
        uint64_t cam = VXPtr(a + 0x20);
        if (cam && VXLoadMatrix(cam)) return cam;
        if (VXLoadMatrix(a)) return a;
    }
    return 0;
}
static BOOL VXProj(V3 w, CGPoint *o) {
    if (!g_mtxOk) return NO;
    const float *m = g_mtx;
    float cx, cy, cz, cw;
    if (g_tIdx) {
        cx = m[0]*w.x + m[4]*w.y + m[8]*w.z + m[12];
        cy = m[1]*w.x + m[5]*w.y + m[9]*w.z + m[13];
        cz = m[2]*w.x + m[6]*w.y + m[10]*w.z + m[14];
        cw = m[3]*w.x + m[7]*w.y + m[11]*w.z + m[15];
    } else {
        cx = m[0]*w.x + m[1]*w.y + m[2]*w.z + m[3];
        cy = m[4]*w.x + m[5]*w.y + m[6]*w.z + m[7];
        cz = m[8]*w.x + m[9]*w.y + m[10]*w.z + m[11];
        cw = m[12]*w.x + m[13]*w.y + m[14]*w.z + m[15];
    }
    if (fabsf(cw) > 0.001f && fabsf(cw - 1.f) > 0.05f) {
        if (cw < 0.05f) return NO;
        cx /= cw; cy /= cw;
        o->x = (cx + 1.f) * 0.5f * g_sz.width;
        o->y = (1.f - cy) * 0.5f * g_sz.height;
    } else {
        float d = -cz; if (d < 0.05f) d = cz; if (d < 0.05f) return NO;
        float f = (g_sz.height * 0.5f) / tanf(g_fov * (float)M_PI / 360.f) * g_scale;
        o->x = g_sz.width * 0.5f + (cx / d) * f;
        o->y = g_sz.height * 0.5f - (cy / d) * f;
    }
    return !(isnan(o->x) || isnan(o->y));
}

static BOOL VXMatPos(uint64_t t, V3 *o) {
    if (!t) return NO;
    uint64_t n = VXPtr(t + 0x10);
    float m[16];
    uint64_t b[4] = { n?n+0x80:0, n?n+0x90:0, n?n+0x40:0, t+0x80 };
    for (int i = 0; i < 4; i++) {
        if (!b[i] || !VXRead(b[i], m, 64)) continue;
        V3 p = { m[12], m[13], m[14] }; if (VXFin3(p)) { *o = p; return YES; }
        p = (V3){ m[3], m[7], m[11] }; if (VXFin3(p)) { *o = p; return YES; }
    }
    V3 p;
    if (VXRead(t + 0x38, &p, 12) && VXFin3(p)) { *o = p; return YES; }
    if (n && VXRead(n + 0x80, &p, 12) && VXFin3(p)) { *o = p; return YES; }
    return NO;
}
static BOOL VXHead(uint64_t pl, V3 *o) {
    uint64_t tr = VXPtr(pl + 0x3E8);
    V3 ref; BOOL hasRef = VXMatPos(tr, &ref);
    V3 best = ref; float bestY = hasRef ? ref.y : -99999.f; BOOL got = hasRef;
    for (uint64_t off = 0x698; off <= 0x730; off += 8) {
        uint64_t b = VXPtr(pl + off); if (!b) continue;
        V3 p; if (!VXMatPos(b, &p)) continue;
        if (hasRef) {
            float dx=p.x-ref.x, dy=p.y-ref.y, dz=p.z-ref.z;
            if (dx*dx+dy*dy+dz*dz > 16.f) continue;
        }
        if (p.y > bestY) { bestY = p.y; best = p; got = YES; }
    }
    if (got) { *o = best; return YES; }
    if (hasRef) { *o = ref; o->y += 1.75f; return YES; }
    return NO;
}

static uint64_t VXScanOne(uint64_t match, int *outN) {
    for (uint64_t off = 0x98; off <= 0x900; off += 8) {
        uint64_t o = VXPtr(match + off); if (!o) continue;
        uint64_t dict = VXPtr(o); if (!dict) continue;
        int n = VXInt(dict + 0x20); if (n < 2 || n > 200) continue;
        uint64_t e = VXPtr(dict + 0x18); if (!e) continue;
        int score = 0, lim = n < 8 ? n : 8;
        for (int i = 0; i < lim; i++) {
            uint64_t v = VXPtr(e + (uint64_t)i * 0x18 + 0x30);
            if (v && VXStr(v + 0x498)) score++;
        }
        if (score >= 2) { *outN = n; return o; }
    }
    return 0;
}

static void VXLookQuat(V3 from, V3 to, float q[4]) {
    V3 f = { to.x-from.x, to.y-from.y, to.z-from.z };
    float len = sqrtf(f.x*f.x + f.y*f.y + f.z*f.z);
    if (len < 1e-3f) { q[0]=q[1]=q[2]=0; q[3]=1; return; }
    f.x/=len; f.y/=len; f.z/=len;
    V3 up = { 0, 1, 0 };
    if (fabsf(f.y) > 0.98f) up = (V3){ 0, 0, 1 };
    V3 r = { up.y*f.z - up.z*f.y, up.z*f.x - up.x*f.z, up.x*f.y - up.y*f.x };
    float rl = sqrtf(r.x*r.x+r.y*r.y+r.z*r.z);
    if (rl < 1e-4f) { q[0]=q[1]=q[2]=0; q[3]=1; return; }
    r.x/=rl; r.y/=rl; r.z/=rl;
    V3 u = { f.y*r.z - f.z*r.y, f.z*r.x - f.x*r.z, f.x*r.y - f.y*r.x };
    float m00=r.x, m01=u.x, m02=f.x, m10=r.y, m11=u.y, m12=f.y, m20=r.z, m21=u.z, m22=f.z;
    float tr = m00+m11+m22;
    if (tr > 0) {
        float s = sqrtf(tr+1.f)*2.f;
        q[3]=0.25f*s; q[0]=(m21-m12)/s; q[1]=(m02-m20)/s; q[2]=(m10-m01)/s;
    } else if (m00 > m11 && m00 > m22) {
        float s = sqrtf(1.f+m00-m11-m22)*2.f;
        q[0]=0.25f*s; q[1]=(m01+m10)/s; q[2]=(m02+m20)/s; q[3]=(m21-m12)/s;
    } else if (m11 > m22) {
        float s = sqrtf(1.f+m11-m00-m22)*2.f;
        q[1]=0.25f*s; q[0]=(m01+m10)/s; q[2]=(m12+m21)/s; q[3]=(m02-m20)/s;
    } else {
        float s = sqrtf(1.f+m22-m00-m11)*2.f;
        q[2]=0.25f*s; q[0]=(m02+m20)/s; q[1]=(m12+m21)/s; q[3]=(m10-m01)/s;
    }
}
static void VXSlerp(const float a[4], float b[4], float t, float o[4]) {
    float dot = a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3];
    if (dot < 0) { b[0]=-b[0]; b[1]=-b[1]; b[2]=-b[2]; b[3]=-b[3]; dot=-dot; }
    if (dot > 0.9995f) {
        o[0]=a[0]+t*(b[0]-a[0]); o[1]=a[1]+t*(b[1]-a[1]);
        o[2]=a[2]+t*(b[2]-a[2]); o[3]=a[3]+t*(b[3]-a[3]);
    } else {
        float th = acosf(dot), st = sinf(th), s1 = sinf((1-t)*th)/st, s2 = sinf(t*th)/st;
        o[0]=s1*a[0]+s2*b[0]; o[1]=s1*a[1]+s2*b[1]; o[2]=s1*a[2]+s2*b[2]; o[3]=s1*a[3]+s2*b[3];
    }
    float n = sqrtf(o[0]*o[0]+o[1]*o[1]+o[2]*o[2]+o[3]*o[3]);
    if (n > 1e-6f) { o[0]/=n; o[1]/=n; o[2]/=n; o[3]/=n; }
}
static BOOL VXWriteQuat(uint64_t tr, float q[4]) {
    uint64_t n = VXPtr(tr + 0x10);
    uint64_t cand[6] = { n?n+0x70:0, n?n+0x58:0, n?n+0x48:0, n?n+0x40:0, tr+0x58, tr+0x48 };
    for (int i = 0; i < 6; i++) {
        if (!cand[i]) continue;
        float cur[4];
        if (!VXRead(cand[i], cur, 16)) continue;
        float nn = cur[0]*cur[0]+cur[1]*cur[1]+cur[2]*cur[2]+cur[3]*cur[3];
        if (nn < 0.7f || nn > 1.3f) continue;
        float out[4];
        VXSlerp(cur, q, g_aimSm, out);
        return VXWrite(cand[i], out, 16);
    }
    return NO;
}
static void VXAimAt(V3 target) {
    if (!g_local) return;
    uint64_t tr = VXPtr(g_local + 0x3E8);
    if (!tr) return;
    V3 from;
    if (!VXMatPos(tr, &from)) return;
    float q[4];
    VXLookQuat(from, target, q);
    VXWriteQuat(tr, q);
}

static UIColor *VXColor(void) {
    switch (g_color) {
        case 0: return UIColor.redColor;
        case 1: return UIColor.greenColor;
        case 2: return UIColor.cyanColor;
        case 3: return UIColor.yellowColor;
        default: return UIColor.whiteColor;
    }
}
static CAShapeLayer *VXLayerAt(int i) {
    while (g_lays.count <= (NSUInteger)i) {
        CAShapeLayer *s = [CAShapeLayer layer];
        s.fillColor = nil; s.lineWidth = 1.5f;
        [g_over.layer addSublayer:s];
        [g_lays addObject:s];
    }
    return g_lays[i];
}
static CATextLayer *VXTextAt(int i) {
    while (g_txts.count <= (NSUInteger)i) {
        CATextLayer *t = [CATextLayer layer];
        t.contentsScale = UIScreen.mainScreen.scale;
        t.alignmentMode = kCAAlignmentCenter;
        t.fontSize = 11;
        [g_over.layer addSublayer:t];
        [g_txts addObject:t];
    }
    return g_txts[i];
}

static void VXTick(CADisplayLink *l) {
    if (!g_over) return;
    g_sz = g_over.bounds.size;
    if (g_sz.width < 10) g_sz = UIScreen.mainScreen.bounds.size;
    for (CAShapeLayer *s in g_lays) s.hidden = YES;
    for (CATextLayer *t in g_txts) t.hidden = YES;

    int F=0,M=0,X=0,C=0,n=0,P=0,D=0;
    if (!g_esp) { if (g_hud) g_hud.text = @"OFF"; return; }

    uint64_t fac = VXFacade(); F = fac?1:0;
    uint64_t mg = 0;
    if (fac) { mg = VXPtr(fac + 0xB8); if (mg) mg = VXPtr(mg + 0x90); }
    M = mg?1:0;
    if (mg) { g_local = VXPtr(mg + 0xD8); X = VXFindCam(mg)?1:0; }
    if (!mg || !X) { if (g_hud) g_hud.text = [NSString stringWithFormat:@"F%d M%d X%d", F,M,X]; return; }

    uint64_t cont = VXScanOne(mg, &n); C = cont?1:0;
    if (!cont) { if (g_hud) g_hud.text = [NSString stringWithFormat:@"F%d M%d X%d C0", F,M,X]; return; }
    uint64_t dict = VXPtr(cont);
    uint64_t ent = dict ? VXPtr(dict + 0x18) : 0;
    V3 lh={0}; BOOL hasL = g_local && VXHead(g_local, &lh);

    int used = 0;
    float best = 1e9f; V3 bestH = {0}; BOOL hasT = NO;
    float cx0 = g_sz.width*0.5f, cy0 = g_sz.height*0.5f;

    for (int i = 0; i < n && ent; i++) {
        uint64_t pl = VXPtr(ent + (uint64_t)i*0x18 + 0x30);
        if (!pl || pl == g_local) continue;
        V3 hd; if (!VXHead(pl, &hd)) { D++; continue; }
        V3 toe = hd; toe.y -= 1.75f;
        CGPoint a, b;
        if (!VXProj(hd, &a) || !VXProj(toe, &b)) { D++; continue; }
        float h = fabsf(b.y - a.y);
        if (h < 4.f) { D++; continue; }
        if (h > g_sz.height*0.6f) h = g_sz.height*0.6f;
        float w = fmaxf(10.f, h*0.62f);
        float cx = (a.x+b.x)*0.5f;

        float dd = hypotf(a.x - cx0, a.y - cy0);
        if (dd < best && dd < g_aimFov) { best = dd; bestH = hd; hasT = YES; }

        CAShapeLayer *s = VXLayerAt(used);
        s.hidden = NO; s.strokeColor = VXColor().CGColor;
        UIBezierPath *path = [UIBezierPath bezierPath];
        if (g_box) [path appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cx-w*0.5f, a.y, w, h)]];
        if (g_line) {
            [path moveToPoint:CGPointMake(cx0, g_sz.height)];
            [path addLineToPoint:CGPointMake(cx, a.y+h)];
        }
        s.path = path.CGPath;
        if (g_name || g_dist) {
            NSMutableString *cap = [NSMutableString string];
            if (g_name) { NSString *nm = VXStr(pl+0x498); if (nm) [cap appendString:nm]; }
            if (g_dist && hasL) {
                float dx=hd.x-lh.x, dy=hd.y-lh.y, dz=hd.z-lh.z;
                if (cap.length) [cap appendString:@"  "];
                [cap appendFormat:@"%.0fm", sqrtf(dx*dx+dy*dy+dz*dz)/100.f];
            }
            if (cap.length) {
                CATextLayer *t = VXTextAt(used);
                t.hidden = NO; t.string = cap; t.foregroundColor = VXColor().CGColor;
                t.frame = CGRectMake(cx-70, a.y-15, 140, 14);
            }
        }
        P++; used++;
    }
    if (g_aim && hasT) VXAimAt(bestH);
    if (g_hud) g_hud.text = [NSString stringWithFormat:@"F%d M%d X%d C%d n%d P%d D%d A%d", F,M,X,C,n,P,D, hasT&&g_aim];
}

static BOOL VXAccName(NSString *n) {
    NSString *l = n.lowercaseString;
    for (NSString *s in @[@"account", @"guest", @"ffacc", @"login", @"session", @"uid", @"user"])
        if ([l containsString:s]) return YES;
    return NO;
}
static void VXResetGuest(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSString *docs = [home stringByAppendingPathComponent:@"Documents"];
    for (NSString *f in [fm contentsOfDirectoryAtPath:docs error:nil]) {
        if (!VXAccName(f)) continue;
        [fm removeItemAtPath:[docs stringByAppendingPathComponent:f] error:nil];
    }
    NSString *bid = [NSBundle mainBundle].bundleIdentifier;
    if (bid) {
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bid];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [fm removeItemAtPath:[home stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Preferences/%@.plist", bid]] error:nil];
    }
    SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword});
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
}

@interface VXHost : NSObject
+ (instancetype)shared;
- (void)tick:(CADisplayLink *)l;
- (void)swEsp:(UISwitch *)s; - (void)swBox:(UISwitch *)s;
- (void)swLine:(UISwitch *)s; - (void)swName:(UISwitch *)s;
- (void)swDist:(UISwitch *)s; - (void)swAim:(UISwitch *)s;
- (void)slFov:(UISlider *)s; - (void)slScale:(UISlider *)s;
- (void)btColor; - (void)btReset; - (void)btClose;
- (void)tapBubble:(id)b; - (void)panBubble:(UIPanGestureRecognizer *)g;
@end
@implementation VXHost
+ (instancetype)shared { static VXHost *h; static dispatch_once_t o; dispatch_once(&o, ^{ h=[VXHost new]; }); return h; }
- (void)tick:(CADisplayLink *)l { VXTick(l); }
- (void)swEsp:(UISwitch *)s { g_esp=s.on; } - (void)swBox:(UISwitch *)s { g_box=s.on; }
- (void)swLine:(UISwitch *)s { g_line=s.on; } - (void)swName:(UISwitch *)s { g_name=s.on; }
- (void)swDist:(UISwitch *)s { g_dist=s.on; } - (void)swAim:(UISwitch *)s { g_aim=s.on; }
- (void)slFov:(UISlider *)s { g_fov=s.value; } - (void)slScale:(UISlider *)s { g_scale=s.value; }
- (void)btColor { g_color=(g_color+1)%5; } - (void)btReset { VXResetGuest(); } - (void)btClose { g_panel.hidden=YES; }
- (void)tapBubble:(id)b { g_panel.hidden=!g_panel.hidden; }
- (void)panBubble:(UIPanGestureRecognizer *)g {
    CGPoint d=[g translationInView:g_bub.superview];
    g_bub.center=CGPointMake(g_bub.center.x+d.x, g_bub.center.y+d.y);
    [g setTranslation:CGPointZero inView:g_bub.superview];
}
@end

static UIView *VXRow(CGFloat y, NSString *title, BOOL on, SEL act) {
    UIView *r=[[UIView alloc] initWithFrame:CGRectMake(0,y,280,40)];
    UILabel *l=[[UILabel alloc] initWithFrame:CGRectMake(14,0,190,40)];
    l.text=title; l.textColor=UIColor.whiteColor; l.font=[UIFont boldSystemFontOfSize:14];
    [r addSubview:l];
    UISwitch *s=[[UISwitch alloc] initWithFrame:CGRectMake(198,5,51,31)];
    s.on=on; s.onTintColor=[UIColor colorWithRed:0.1 green:0.72 blue:0.42 alpha:1];
    [s addTarget:[VXHost shared] action:act forControlEvents:UIControlEventValueChanged];
    [r addSubview:s]; return r;
}
static UIView *VXSlider(CGFloat y, NSString *title, float lo, float hi, float v, SEL act) {
    UIView *r=[[UIView alloc] initWithFrame:CGRectMake(0,y,280,58)];
    UILabel *l=[[UILabel alloc] initWithFrame:CGRectMake(14,0,250,20)];
    l.text=title; l.textColor=[UIColor colorWithWhite:0.85 alpha:1]; l.font=[UIFont systemFontOfSize:12];
    [r addSubview:l];
    UISlider *s=[[UISlider alloc] initWithFrame:CGRectMake(14,22,250,30)];
    s.minimumValue=lo; s.maximumValue=hi; s.value=v;
    [s addTarget:[VXHost shared] action:act forControlEvents:UIControlEventValueChanged];
    [r addSubview:s]; return r;
}
static UIButton *VXButton(CGRect f, NSString *t, SEL act) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    b.frame=f; [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font=[UIFont boldSystemFontOfSize:14];
    b.backgroundColor=[UIColor colorWithRed:0.16 green:0.18 blue:0.22 alpha:1];
    b.layer.cornerRadius=8;
    [b addTarget:[VXHost shared] action:act forControlEvents:UIControlEventTouchUpInside];
    return b;
}
static void VXBuildPanel(void) {
    if (g_panel) return;
    CGFloat H=MIN(560.f, [UIScreen mainScreen].bounds.size.height-150.f);
    g_panel=[[UIView alloc] initWithFrame:CGRectMake(14,90,280,H)];
    g_panel.backgroundColor=[UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:0.96];
    g_panel.layer.cornerRadius=14; g_panel.clipsToBounds=YES; g_panel.hidden=YES;
    UILabel *t=[[UILabel alloc] initWithFrame:CGRectMake(14,8,250,26)];
    t.text=@"PANEL"; t.textColor=[UIColor colorWithRed:0.1 green:0.72 blue:0.42 alpha:1];
    t.font=[UIFont boldSystemFontOfSize:17]; [g_panel addSubview:t];
    g_scroll=[[UIScrollView alloc] initWithFrame:CGRectMake(0,40,280,H-88)];
    [g_panel addSubview:g_scroll];
    NSArray *defs=@[
        @[@"ESP",@(g_esp),NSStringFromSelector(@selector(swEsp:))],
        @[@"Caja",@(g_box),NSStringFromSelector(@selector(swBox:))],
        @[@"Línea",@(g_line),NSStringFromSelector(@selector(swLine:))],
        @[@"Nombre",@(g_name),NSStringFromSelector(@selector(swName:))],
        @[@"Distancia",@(g_dist),NSStringFromSelector(@selector(swDist:))],
        @[@"Aim",@(g_aim),NSStringFromSelector(@selector(swAim:))]
    ];
    CGFloat y=0;
    for (NSArray *d in defs) { [g_scroll addSubview:VXRow(y,d[0],[d[1] boolValue],NSSelectorFromString(d[2]))]; y+=40; }
    [g_scroll addSubview:VXSlider(y+4,@"FOV",40,110,g_fov,@selector(slFov:))]; y+=62;
    [g_scroll addSubview:VXSlider(y+4,@"Escala",0.3,2.5,g_scale,@selector(slScale:))]; y+=62;
    [g_scroll addSubview:VXButton(CGRectMake(14,y+6,122,40),@"COLOR",@selector(btColor))];
    [g_scroll addSubview:VXButton(CGRectMake(144,y+6,122,40),@"RESET",@selector(btReset))]; y+=52;
    g_scroll.contentSize=CGSizeMake(280,y+16);
    [g_panel addSubview:VXButton(CGRectMake(14,H-44,252,34),@"CERRAR",@selector(btClose))];
}
static void VXBuildBubble(UIWindow *w) {
    if (g_bub) return;
    g_bub=[UIButton buttonWithType:UIButtonTypeCustom];
    g_bub.frame=CGRectMake(w.bounds.size.width-66,96,52,52);
    g_bub.backgroundColor=[UIColor colorWithRed:0.1 green:0.72 blue:0.42 alpha:0.92];
    g_bub.layer.cornerRadius=26;
    [g_bub setTitle:@"V" forState:UIControlStateNormal];
    [g_bub setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    g_bub.titleLabel.font=[UIFont boldSystemFontOfSize:22];
    [g_bub addTarget:[VXHost shared] action:@selector(tapBubble:) forControlEvents:UIControlEventTouchUpInside];
    [g_bub addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:[VXHost shared] action:@selector(panBubble:)]];
    [w addSubview:g_bub];
}
static void VXMount(void) {
    UIWindow *w=nil;
    for (UIWindow *x in [UIApplication sharedApplication].windows)
        if (x.isKeyWindow && x.windowLevel<UIWindowLevelAlert) { w=x; break; }
    if (!w) w=[UIApplication sharedApplication].keyWindow;
    if (!w) return;
    if (!g_bub) VXBuildBubble(w);
    if (!g_panel) VXBuildPanel();
    if (!g_over) {
        g_over=[[UIView alloc] initWithFrame:w.bounds];
        g_over.userInteractionEnabled=NO;
        g_over.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        g_lays=[NSMutableArray array]; g_txts=[NSMutableArray array];
        g_link=[CADisplayLink displayLinkWithTarget:[VXHost shared] selector:@selector(tick:)];
        [g_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    if (!g_hud) {
        g_hud=[[UILabel alloc] initWithFrame:CGRectMake(8,36,420,20)];
        g_hud.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightBold];
        g_hud.textColor=UIColor.greenColor;
        g_hud.backgroundColor=[UIColor colorWithWhite:0 alpha:0.45];
        g_hud.userInteractionEnabled=NO;
        g_hud.text=@"...";
    }
    if (g_over.superview!=w){ [g_over removeFromSuperview]; [w addSubview:g_over]; }
    if (g_hud.superview!=w){ [g_hud removeFromSuperview]; [w addSubview:g_hud]; }
    if (g_panel.superview!=w){ [g_panel removeFromSuperview]; [w addSubview:g_panel]; }
    if (g_bub.superview!=w){ [g_bub removeFromSuperview]; [w addSubview:g_bub]; }
    [w bringSubviewToFront:g_over]; [w bringSubviewToFront:g_hud];
    [w bringSubviewToFront:g_panel]; [w bringSubviewToFront:g_bub];
    g_win=w;
}
static void VXStart(void) {
    VXBuildPanel(); VXMount();
    if (!g_mount) g_mount=[NSTimer scheduledTimerWithTimeInterval:0.8 repeats:YES block:^(NSTimer *t){ VXMount(); }];
}
__attribute__((constructor))
static void VXInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ VXStart(); });
}
