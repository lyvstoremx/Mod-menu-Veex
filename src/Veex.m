#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <Security/Security.h>

#pragma mark - log

static NSString *g_logPath = nil;

static void VXInitLog(void){
    if (g_logPath) return;
    NSString *d = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    g_logPath = [d stringByAppendingPathComponent:@"veex_log.txt"];
}

static void VXLog(NSString *fmt, ...){
    VXInitLog();
    va_list a; va_start(a, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:a];
    va_end(a);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], s];
    FILE *f = fopen(g_logPath.UTF8String, "a");
    if (f) { fputs(line.UTF8String, f); fflush(f); fsync(fileno(f)); fclose(f); }
}

#pragma mark - memoria segura

static BOOL VXRead(void *addr, void *out, size_t n){
    if (!addr || !out || !n) return NO;
    vm_size_t got = 0;
    kern_return_t k = vm_read_overwrite(mach_task_self(), (vm_address_t)addr, (vm_size_t)n, (vm_address_t)out, &got);
    return (k == KERN_SUCCESS && got == n);
}

static void *VXAt(void *base, size_t off){
    if (!base) return NULL;
    void *p = NULL;
    if (!VXRead((char *)base + off, &p, sizeof(p))) return NULL;
    return p;
}

static int VXInt(void *base, size_t off){
    if (!base) return 0;
    int v = 0;
    if (!VXRead((char *)base + off, &v, sizeof(v))) return 0;
    return v;
}

static BOOL VXOk(void *p){
    if (!p) return NO;
    uintptr_t v = (uintptr_t)p;
    return (v > 0x10000) && ((v & 7) == 0);
}

static BOOL VXName(void *pl){
    if (!VXOk(pl)) return NO;
    void *s = VXAt(pl, 0x498);
    if (!VXOk(s)) return NO;
    int len = VXInt(s, 0x10);
    return (len > 0 && len < 48);
}

#pragma mark - il2cpp

static void *(*p_domain_get)(void);
static void **(*p_domain_get_assemblies)(void *, size_t *);
static void *(*p_assembly_get_image)(void *);
static void *(*p_class_from_name)(void *, const char *, const char *);
static const char *(*p_class_get_name)(void *);
static void *(*p_class_get_field_from_name)(void *, const char *);
static void  (*p_field_static_get_value)(void *, void *);

static BOOL g_ready = NO;
static void *g_facade = NULL;
static void *g_fCurrentMatchGame = NULL;
static void *g_match = NULL;
static void *g_local = NULL;
static void *g_cam = NULL;

static float g_mtx[16];
static BOOL  g_mtxOk = NO;
static BOOL  g_swept = NO;
static BOOL  g_dict = NO;

static void VXLoadMatrix(void){
    g_mtxOk = NO;
    if (!VXOk(g_cam)) return;
    void *nat = VXAt(g_cam, 0x10);
    if (!VXOk(nat)) return;
    for (int i = 0; i < 16; i++) {
        if (!VXRead((char *)nat + 0xD8 + i * 4, &g_mtx[i], 4)) return;
    }
    if (g_mtx[0] == 0.0f && g_mtx[5] == 0.0f) return;
    g_mtxOk = YES;
}

static void *VXFacadeObj(void){
    void *sb = VXAt(g_facade, 0xB8);
    if (VXOk(sb)) {
        void *o = VXAt(sb, 0x8);
        if (VXOk(o) && (VXOk(VXAt(o, 0x90)) || VXOk(VXAt(o, 0xD8)))) return o;
        if (VXOk(o)) return o;
    }
    void *out = NULL;
    if (g_fCurrentMatchGame && p_field_static_get_value) {
        void *exc = NULL;
        @try { p_field_static_get_value(g_fCurrentMatchGame, &out); } @catch (...) { out = NULL; }
    }
    if (!VXOk(out)) out = VXAt(g_facade, 0x8);
    return VXOk(out) ? out : NULL;
}

static void VXResolve(void){
    if (g_ready) return;

    p_domain_get                 = dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
    p_domain_get_assemblies      = dlsym(RTLD_DEFAULT, "il2cpp_domain_get_assemblies");
    p_assembly_get_image         = dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
    p_class_from_name            = dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
    p_class_get_name             = dlsym(RTLD_DEFAULT, "il2cpp_class_get_name");
    p_class_get_field_from_name  = dlsym(RTLD_DEFAULT, "il2cpp_class_get_field_from_name");
    p_field_static_get_value     = dlsym(RTLD_DEFAULT, "il2cpp_field_static_get_value");

    if (!p_domain_get || !p_domain_get_assemblies || !p_assembly_get_image || !p_class_from_name) {
        VXLog(@"FALLO dlsym il2cpp");
        return;
    }

    void *dom = p_domain_get();
    if (!dom) { VXLog(@"FALLO domain"); return; }

    size_t n = 0;
    void **asms = p_domain_get_assemblies(dom, &n);
    if (!asms || !n) { VXLog(@"FALLO assemblies"); return; }

    const char *nss[] = { "COW.GamePlay", "COW", "" };
    for (size_t i = 0; n && i < n && !g_facade; i++) {
        void *img = p_assembly_get_image(asms[i]);
        if (!img) continue;
        for (int k = 0; k < 3 && !g_facade; k++) {
            g_facade = p_class_from_name(img, nss[k], "GameFacade");
        }
    }
    if (!g_facade) { VXLog(@"FALLO clase GameFacade"); return; }

    if (p_class_get_field_from_name) {
        g_fCurrentMatchGame = p_class_get_field_from_name(g_facade, "CurrentMatchGame");
    }
    VXLog(@"api OK facade=%p", g_facade);
    g_ready = YES;
}

#pragma mark - posición por matrices de Unity

typedef struct { float px, py, pz; float rx, ry, rz, rw; float sx, sy, sz; } VXTMat;

static BOOL VXPos(void *node, CGPoint *out){
    void *t = VXAt(node, 0x10);
    if (!VXOk(t)) return NO;
    void *mtx = VXAt(t, 0x38);
    if (!VXOk(mtx)) return NO;
    void *list = VXAt(mtx, 0x18);
    void *indices = VXAt(mtx, 0x20);
    if (!VXOk(list) || !VXOk(indices)) return NO;

    int index = VXInt(t, 0x40);
    if (index < 0 || index > 4096) return NO;

    VXTMat base;
    if (!VXRead((char *)list + 40 * index, &base, 40)) return NO;

    float rx = base.px, ry = base.py, rz = base.pz;
    int ti = VXInt(indices, 4 * index);
    int guard = 0;

    while (ti >= 0 && guard++ < 64) {
        VXTMat m;
        if (!VXRead((char *)list + 40 * ti, &m, 40)) break;
        float sX = rx * m.sx, sY = ry * m.sy, sZ = rz * m.sz;
        float qx = m.rx, qy = m.ry, qz = m.rz, qw = m.rw;
        float nx = m.px + sX + (sX * ((qy * qy * -2.0f) - (qz * qz * 2.0f)))
                 + (sY * ((qw * qz * -2.0f) - (qy * qx * -2.0f)))
                 + (sZ * ((qz * qx * 2.0f) - (qw * qy * -2.0f)));
        float ny = m.py + sY + (sX * ((qx * qy * 2.0f) - (qw * qz * -2.0f)))
                 + (sY * ((qz * qz * -2.0f) - (qx * qx * 2.0f)))
                 + (sZ * ((qw * qx * -2.0f) - (qz * qy * -2.0f)));
        float nz = m.pz + sZ + (sX * ((qw * qy * -2.0f) - (qx * qz * -2.0f)))
                 + (sY * ((qy * qz * 2.0f) - (qw * qx * -2.0f)))
                 + (sZ * ((qx * qx * -2.0f) - (qy * qy * 2.0f)));
        rx = nx; ry = ny; rz = nz;
        ti = VXInt(indices, 4 * ti);
    }

    out->x = rx;
    out->y = ry;
    return YES;
}

static const int kNodes[] = {
    0x698, 0x6A0, 0x6A8, 0x6B0, 0x6B8, 0x6C0, 0x6C8, 0x6D0,
    0x6D8, 0x6E0, 0x6E8, 0x6F0, 0x6F8, 0x708, 0x710, 0x718,
    0x720, 0x728, 0x730
};
static const int kNodeCount = 19;

static BOOL VXHead(void *pl, CGPoint *head){
    float hi = -1e9f;
    CGPoint ph = {0,0};
    BOOL has = NO;
    int valid = 0;
    for (int i = 0; i < kNodeCount; i++) {
        void *node = VXAt(pl, kNodes[i]);
        if (!VXOk(node)) continue;
        CGPoint p;
        if (!VXPos(node, &p)) continue;
        if (fabsf(p.x) > 20000.0f || fabsf(p.y) > 20000.0f) continue;
        valid++;
        if (p.y > hi) { hi = p.y; ph = p; has = YES; }
    }
    if (!has || valid < 3) return NO;
    *head = ph;
    return YES;
}

#pragma mark - barrido de contenedor

static BOOL VXScanOne(void *obj, void **oObj, size_t *oOff, int *oN, BOOL *oDict){
    BOOL found = NO; int bestScore = 0;
    for (size_t off = 0x80; off <= 0x400; off += 8) {
        void *l = VXAt(obj, off);
        if (!VXOk(l)) continue;

        void *it = VXAt(l, 0x10);
        int s = VXInt(l, 0x18);
        if (VXOk(it) && s > 1 && s < 300) {
            int score = 0;
            for (int k = 0; k < 8 && k < s; k++) {
                void *e = VXAt(it, 0x20 + k * 8);
                if (VXName(e)) score++;
            }
            if (score >= 2 && score > bestScore) {
                *oObj = l; *oOff = off; *oN = s; *oDict = NO; bestScore = score; found = YES;
            }
        }

        void *ent = VXAt(l, 0x18);
        int c = VXInt(l, 0x20);
        if (VXOk(ent) && c > 1 && c < 300) {
            int score = 0;
            for (int k = 0; k < 8 && k < c; k++) {
                void *e = VXAt(ent, 0x30 + k * 0x18);
                if (VXName(e)) score++;
            }
            if (score >= 2 && score > bestScore) {
                *oObj = l; *oOff = off; *oN = c; *oDict = YES; bestScore = score; found = YES;
            }
        }
    }
    return found;
}

static void VXSweep(void *match){
    if (g_swept || !VXOk(match)) return;
    g_swept = YES;
    void *mk = VXAt(match, 0);
    VXLog(@"--- SWEEP match=%p clase=%s ---", match,
          (mk && p_class_get_name) ? p_class_get_name(mk) : "?");
    for (size_t off = 0x80; off <= 0x900; off += 8) {
        void *p = VXAt(match, off);
        if (!VXOk(p)) continue;
        VXLog(@"  +0x%zx -> %p n=%d", off, p, VXInt(p, 0x18));
    }
    VXLog(@"--- FIN SWEEP ---");
}

#pragma mark - estado

static BOOL g_esp = NO;
static int  g_step = 0;
static int  g_retry = 0;
static int  g_L = 0, g_B = 0, g_P = 0, g_D = 0;
static int  g_color = 0;

static void *g_listObj = NULL;
static size_t g_listOff = 0;

static CGPoint g_box[256][4];
static int g_boxN = 0;

static UIColor *VXC(void){
    NSArray *c = @[ [UIColor greenColor], [UIColor redColor], [UIColor cyanColor],
                    [UIColor yellowColor], [UIColor magentaColor], [UIColor whiteColor] ];
    if (g_color < 0 || g_color >= (int)c.count) return [UIColor greenColor];
    return c[g_color];
}

#pragma mark - proyección

static BOOL VXProj(CGPoint world, CGSize sz, CGPoint *out){
    if (!g_mtxOk) return NO;
    float x = (float)world.x, y = (float)world.y, z = 0.0f;
    float w = g_mtx[3] * x + g_mtx[7] * y + g_mtx[11] * z + g_mtx[15];
    if (w < 0.5f) w = 0.5f;
    float nx = (g_mtx[0] * x + g_mtx[4] * y + g_mtx[8] * z + g_mtx[12]) / w;
    float ny = (g_mtx[1] * x + g_mtx[5] * y + g_mtx[9] * z + g_mtx[13]) / w;
    out->x = (sz.width / 2.0f) + nx * (sz.width / 2.0f);
    out->y = (sz.height / 2.0f) - ny * (sz.height / 2.0f);
    return YES;
}

#pragma mark - overlay

@interface VXOverlay : UIView
@end

@implementation VXOverlay
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}
- (void)drawRect:(CGRect)r {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx || g_boxN == 0) return;
    UIColor *col = VXC();
    CGContextSetStrokeColorWithColor(ctx, col.CGColor);
    CGContextSetLineWidth(ctx, 1.5);
    for (int i = 0; i < g_boxN; i++) {
        CGPoint a = g_box[i][0], b = g_box[i][1], c = g_box[i][2], d = g_box[i][3];
        CGContextMoveToPoint(ctx, a.x, a.y);
        CGContextAddLineToPoint(ctx, b.x, b.y);
        CGContextAddLineToPoint(ctx, c.x, c.y);
        CGContextAddLineToPoint(ctx, d.x, d.y);
        CGContextClosePath(ctx);
        CGContextStrokePath(ctx);
    }
}
@end

#pragma mark - root

static VXOverlay *g_overlay = nil;
static UIView    *g_root    = nil;
static UIView    *g_bubble  = nil;
static UIView    *g_panel   = nil;
static BOOL       g_open    = NO;
static CADisplayLink *g_link = nil;
static UISwitch  *g_sw      = nil;

@interface VXRoot : UIView
@end

@implementation VXRoot
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (!g_open) {
        if (g_bubble && !g_bubble.hidden) {
            CGRect big = CGRectInset(g_bubble.frame, -12, -12);
            if (CGRectContainsPoint(big, p)) return g_bubble;
        }
        return nil;
    }
    if (g_panel && !g_panel.hidden && CGRectContainsPoint(g_panel.frame, p)) {
        return [super hitTest:p withEvent:e];
    }
    if (g_bubble && CGRectContainsPoint(g_bubble.frame, p)) return g_bubble;
    return nil;
}
@end

@interface VXTarget : NSObject
@end
static VXTarget *g_target = nil;

#pragma mark - reset guest

static void VXWipeDir(NSString *dir, NSString *keep){
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *f in [fm contentsOfDirectoryAtPath:dir error:nil]) {
        if (keep && [f isEqualToString:keep]) continue;
        [fm removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil];
    }
}

static void VXResetGuest(void){
    NSArray *classes = @[ (__bridge id)kSecClassGenericPassword,
                          (__bridge id)kSecClassInternetPassword,
                          (__bridge id)kSecClassKey,
                          (__bridge id)kSecClassCertificate ];
    for (id c in classes) {
        SecItemDelete((__bridge CFDictionaryRef)@{ (__bridge id)kSecClass : c });
    }

    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *lib  = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *tmp  = NSTemporaryDirectory();

    VXWipeDir(docs, @"veex_log.txt");
    VXWipeDir(lib, nil);
    VXWipeDir(tmp, nil);

    _exit(0);
}

#pragma mark - ciclo ESP

static void VXStopESP(void){
    g_esp = NO;
    g_boxN = 0;
    if (g_link) { [g_link invalidate]; g_link = nil; }
    [g_overlay setNeedsDisplay];
    dispatch_async(dispatch_get_main_queue(), ^{ if (g_sw) [g_sw setOn:NO animated:YES]; });
}

static void VXTick(void){
    if (!g_esp) return;

    UIWindow *kw = UIApplication.sharedApplication.keyWindow;
    if (!kw) return;
    CGSize sz = kw.bounds.size;

    @try {
        if (g_step == 0) {
            g_step = 1;
            VXLog(@"=== ESP ON inicio ===");
            VXResolve();
            if (!g_ready) { VXLog(@"FALLO paso 1"); VXStopESP(); return; }
        }

        if (!VXOk(g_cam)) {
            void *mg = VXFacadeObj();
            void *ccm = mg ? VXAt(mg, 0xD8) : NULL;
            if (VXOk(ccm)) g_cam = VXAt(ccm, 0x20);
        }
        VXLoadMatrix();

        if (g_step == 1) {
            void *f = VXFacadeObj();
            g_match = f ? VXAt(f, 0x90) : NULL;
            if (!VXOk(g_match)) {
                g_retry++;
                if (g_retry % 300 == 0) VXLog(@"esperando match (%d)", g_retry);
                return;
            }
            g_retry = 0;
            g_step = 2;
            VXLog(@"paso 2 match=%p cam=%p mtx=%d", g_match, g_cam, g_mtxOk);
            VXSweep(g_match);
        }

        if (g_step == 2) {
            g_step = 3;
            g_local = VXAt(g_match, 0xD8);
            VXLog(@"paso 3 local=%p", g_local);
        }

        if (g_step == 3) {
            g_retry++;
            if (g_retry % 45 != 0) return;

            void *b = NULL; size_t bOff = 0; int bN = 0; BOOL bD = NO;
            int depth = 0;

            if (VXScanOne(g_match, &b, &bOff, &bN, &bD)) depth = 1;
            else {
                void *mg2 = VXFacadeObj();
                if (VXOk(mg2) && VXScanOne(mg2, &b, &bOff, &bN, &bD)) depth = 2;
                else {
                    int tried = 0;
                    for (size_t off = 0x80; off <= 0x400 && tried < 40 && !b; off += 8) {
                        void *o = VXAt(g_match, off);
                        if (!VXOk(o)) continue;
                        void *k = VXAt(o, 0);
                        if (!VXOk(k)) continue;
                        tried++;
                        if (VXScanOne(o, &b, &bOff, &bN, &bD)) depth = 3;
                    }
                    if (!b && g_retry % 300 == 0) VXLog(@"sin contenedor (%d) tried=%d", g_retry, tried);
                }
            }
            if (!b) return;

            g_retry = 0;
            g_listObj = b;
            g_listOff = bOff;
            g_dict = bD;
            g_step = 4;
            VXLog(@"paso 4 obj=%p off=0x%zx n=%d dict=%d nivel=%d", b, bOff, bN, bD, depth);
        }

        if (!g_listObj) return;

        g_L = 0; g_B = 0; g_P = 0; g_D = 0; g_boxN = 0;

        int count = 0;
        void *items = NULL;
        size_t stride = 8, base = 0x20;

        if (g_dict) {
            count = VXInt(g_listObj, 0x20);
            items = VXAt(g_listObj, 0x18);
            stride = 0x18; base = 0x30;
        } else {
            count = VXInt(g_listObj, 0x18);
            items = VXAt(g_listObj, 0x10);
            int arrLen = items ? VXInt(items, 0x18) : 0;
            if (arrLen > 0 && arrLen < count) count = arrLen;
        }

        if (count <= 0 || count > 200) return;
        if (!VXOk(items)) return;
        g_L = count;
        g_B = 1;

        for (int i = 0; i < count && g_boxN < 120; i++) {
            void *pl = VXAt(items, base + i * stride);
            if (!VXOk(pl)) { g_D++; continue; }

            if (pl == g_local) continue;
            if (!VXName(pl)) { g_D++; continue; }

            CGPoint head;
            BOOL viaCam = NO;
            if (!VXHead(pl, &head)) {
                void *tf = VXAt(pl, 0x3E8);
                if (!VXOk(tf) || !VXPos(tf, &head)) { g_D++; continue; }
                viaCam = YES;
            }
            CGPoint toe = CGPointMake(head.x, head.y - 1.75f);

            CGPoint ph, pt;
            if (!VXProj(head, sz, &ph)) { g_D++; continue; }
            if (!VXProj(toe, sz, &pt)) { g_D++; continue; }

            float h = fabsf(pt.y - ph.y);
            if (h < 4 || h > sz.height * 0.6f) { g_D++; continue; }

            float w = h * 0.62f;
            if (w < 10) w = 10;

            float top = (ph.y < pt.y) ? ph.y : pt.y;
            float mid = (ph.x + pt.x) / 2.0f;
            float left = mid - w / 2.0f;

            if (g_boxN < 6) {
                VXLog(@"box %d x=%.0f y=%.0f h=%.0f cam=%d head=(%.1f,%.1f) scr=%.0fx%.0f",
                      g_boxN, left, top, h, viaCam, head.x, head.y, sz.width, sz.height);
            }

            g_box[g_boxN][0] = CGPointMake(left, top);
            g_box[g_boxN][1] = CGPointMake(left + w, top);
            g_box[g_boxN][2] = CGPointMake(left + w, top + h);
            g_box[g_boxN][3] = CGPointMake(left, top + h);
            g_boxN++;
            g_P++;
        }

        [g_overlay setNeedsDisplay];
    } @catch (NSException *e) {
        VXLog(@"EXCEPCION %@", e.reason);
        VXStopESP();
    }
}

static void VXStartESP(void){
    if (g_esp) return;
    g_step = 0;
    g_retry = 0;
    g_listObj = NULL;
    g_swept = NO;
    g_dict = NO;
    g_esp = YES;
    if (!g_target) g_target = [VXTarget new];
    if (g_link) [g_link invalidate];
    g_link = [CADisplayLink displayLinkWithTarget:g_target selector:NSSelectorFromString(@"vxTick")];
    [g_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

@implementation VXTarget
- (void)vxTick { VXTick(); }
@end

#pragma mark - panel

static UILabel *VXLabel(NSString *t, CGRect f, CGFloat sz) {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.text = t; l.textColor = [UIColor whiteColor]; l.font = [UIFont boldSystemFontOfSize:sz];
    l.backgroundColor = [UIColor clearColor];
    return l;
}

static UIButton *VXBtn(NSString *t, CGRect f, id tgt, SEL sel) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f;
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.15];
    b.layer.cornerRadius = 7;
    [b addTarget:tgt action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

@interface VXMenu : NSObject
@end

static VXMenu *g_menu = nil;

@implementation VXMenu

+ (void)show {
    if (g_root && g_root.superview) return;
    if (g_root && !g_root.superview) g_root = nil;
    g_menu = [VXMenu new];

    UIWindow *kw = UIApplication.sharedApplication.keyWindow;
    if (!kw) return;

    g_root = [[VXRoot alloc] initWithFrame:kw.bounds];
    g_root.backgroundColor = [UIColor clearColor];
    g_root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [kw addSubview:g_root];

    g_overlay = [[VXOverlay alloc] initWithFrame:g_root.bounds];
    [g_root addSubview:g_overlay];

    g_bubble = [[UIView alloc] initWithFrame:CGRectMake(14, 120, 46, 46)];
    g_bubble.backgroundColor = [UIColor colorWithRed:0.1 green:0.45 blue:0.95 alpha:0.9];
    g_bubble.layer.cornerRadius = 23;
    g_bubble.layer.borderWidth = 2;
    g_bubble.layer.borderColor = [UIColor whiteColor].CGColor;
    UILabel *bl = VXLabel(@"VX", CGRectMake(0, 0, 46, 46), 15);
    bl.textAlignment = NSTextAlignmentCenter;
    [g_bubble addSubview:bl];
    [g_root addSubview:g_bubble];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:g_menu action:@selector(drag:)];
    [g_bubble addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:g_menu action:@selector(togglePanel)];
    [g_bubble addGestureRecognizer:tap];

    g_panel = [[UIView alloc] initWithFrame:CGRectMake(14, 180, 250, 300)];
    g_panel.backgroundColor = [UIColor colorWithRed:0.05 green:0.07 blue:0.12 alpha:0.94];
    g_panel.layer.cornerRadius = 14;
    g_panel.layer.borderWidth = 1;
    g_panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
    g_panel.hidden = YES;
    [g_root addSubview:g_panel];

    [g_panel addSubview:VXLabel(@"VEEX 1.132.1", CGRectMake(14, 10, 200, 20), 15)];

    g_sw = [[UISwitch alloc] initWithFrame:CGRectMake(200, 44, 51, 31)];
    [g_sw addTarget:g_menu action:@selector(espChanged:) forControlEvents:UIControlEventValueChanged];
    [g_panel addSubview:g_sw];

    [g_panel addSubview:VXLabel(@"ESP", CGRectMake(14, 48, 100, 18), 13)];
    [g_panel addSubview:VXBtn(@"COLOR", CGRectMake(14, 86, 110, 30), g_menu, @selector(colorTap))];
    [g_panel addSubview:VXBtn(@"ESTADO", CGRectMake(14, 124, 100, 32), g_menu, @selector(estadoTap))];
    [g_panel addSubview:VXBtn(@"RESET GUEST", CGRectMake(120, 124, 110, 32), g_menu, @selector(resetTap))];
    [g_panel addSubview:VXBtn(@"CERRAR", CGRectMake(14, 168, 100, 32), g_menu, @selector(togglePanel))];

    UILabel *foot = VXLabel(@"log: Documents/veex_log.txt", CGRectMake(14, 210, 220, 16), 10);
    foot.textColor = [UIColor colorWithWhite:0.6 alpha:0.6];
    [g_panel addSubview:foot];
}

- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint d = [g translationInView:g_root];
    g_bubble.center = CGPointMake(g_bubble.center.x + d.x, g_bubble.center.y + d.y);
    [g setTranslation:CGPointZero inView:g_root];
}

- (void)togglePanel {
    g_open = !g_open;
    g_panel.hidden = !g_open;
}

- (void)espChanged:(UISwitch *)s {
    if (s.isOn) { VXStartESP(); }
    else { VXStopESP(); VXLog(@"ESP OFF"); }
}

- (void)colorTap {
    g_color++;
    NSArray *n = @[ @"VERDE", @"ROJO", @"CYAN", @"AMARILLO", @"MAGENTA", @"BLANCO" ];
    if (g_color >= (int)n.count) g_color = 0;
    VXLog(@"color %@", n[g_color]);
}

- (void)estadoTap {
    NSString *msg = [NSString stringWithFormat:
        @"L %d  B %d  P %d  D %d\noff 0x%zx  mtx %d\nmatch %p\ncam %p",
        g_L, g_B, g_P, g_D, g_listOff, g_mtxOk, g_match, g_cam];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ESTADO" message:msg
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:a animated:YES completion:nil];
}

- (void)resetTap { VXResetGuest(); }

@end

#pragma mark - arranque

__attribute__((constructor))
static void VXInit(void){
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (int i = 0; i < 900; i++) {
            __block BOOL up = NO;
            dispatch_sync(dispatch_get_main_queue(), ^{
                UIApplication *a = [UIApplication sharedApplication];
                up = a != nil && a.windows.count > 0 && a.keyWindow != nil;
            });
            if (up) break;
            usleep(200000);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [VXMenu show];
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *tt){
                if (g_root && g_root.superview) return;
                if (g_root && !g_root.superview) g_root = nil;
                UIWindow *kw = UIApplication.sharedApplication.keyWindow;
                if (!kw) return;
                [VXMenu show];
            }];
        });
    });
}
