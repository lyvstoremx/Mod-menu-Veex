// Veex.m — 3.2 (proyección con profundidad, nombre/distancia, globo arrastrable)
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <Security/Security.h>
#import <math.h>

typedef struct { float x, y, z; } V3;

static BOOL  g_esp = NO;
static BOOL  g_box = YES;
static BOOL  g_line = NO;
static BOOL  g_name = NO;
static BOOL  g_dist = NO;
static int   g_color = 0;
static float g_fov = 60.f;
static float g_scale = 1.f;

static uint64_t g_local = 0;
static float g_mtx[16];
static BOOL  g_mtxOk = NO;
static int   g_tIdx = 1;
static CGSize g_sz = {926, 428};

static UIWindow *g_win = nil;
static UIButton *g_bub = nil;
static UIView   *g_panel = nil;
static UIView   *g_over = nil;
static CADisplayLink *g_link = nil;
static NSMutableArray *g_lays = nil;
static NSMutableArray *g_txts = nil;
static NSTimer *g_mount = nil;
static int g_logFrames = 0;

#pragma mark - log

static void VXLog(NSString *fmt, ...) {
    static dispatch_queue_t q; static dispatch_once_t o;
    dispatch_once(&o, ^{ q = dispatch_queue_create("vxlog", NULL); });
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    dispatch_async(q, ^{
        NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/veex_log.txt"];
        NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:p];
        if (!h) {
            [[NSFileManager defaultManager] createFileAtPath:p contents:nil attributes:nil];
            h = [NSFileHandle fileHandleForWritingAtPath:p];
        }
        if (!h) return;
        [h seekToEndOfFile];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], s];
        [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [h closeFile];
    });
}

#pragma mark - memoria

static BOOL VXRead(uint64_t a, void *b, size_t n) {
    if (!a) return NO;
    vm_size_t out = 0;
    kern_return_t k = vm_read_overwrite(mach_task_self(), (vm_address_t)a, n,
                                        (vm_address_t)b, &out);
    return (k == KERN_SUCCESS && out == n);
}

static uint64_t VXPtr(uint64_t a) {
    uint64_t v = 0;
    if (!VXRead(a, &v, 8)) return 0;
    return v;
}

static int VXInt(uint64_t a) {
    int v = 0;
    if (!VXRead(a, &v, 4)) return 0;
    return v;
}

static NSString *VXStr(uint64_t a) {
    uint64_t p = VXPtr(a);
    if (!p) return nil;
    char b[64]; memset(b, 0, sizeof b);
    if (!VXRead(p + 0x10, b, sizeof b - 1)) return nil;
    NSString *s = [NSString stringWithUTF8String:b];
    if (s.length < 2 || s.length > 20) return nil;
    return s;
}

#pragma mark - il2cpp

static void *(*p_domain_get)(void);
static void *(*p_domain_assembly_open)(void *, const char *);
static void *(*p_assembly_get_image)(void *);
static void *(*p_class_from_name)(void *, const char *, const char *);
static void *(*p_class_get_field_from_name)(void *, const char *);
static void  (*p_field_static_get_value)(void *, void *);

static BOOL VXIl2Cpp(void) {
    static BOOL ok = NO; static dispatch_once_t o;
    dispatch_once(&o, ^{
        p_domain_get                = dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
        p_domain_assembly_open      = dlsym(RTLD_DEFAULT, "il2cpp_domain_assembly_open");
        p_assembly_get_image        = dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
        p_class_from_name           = dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
        p_class_get_field_from_name = dlsym(RTLD_DEFAULT, "il2cpp_class_get_field_from_name");
        p_field_static_get_value    = dlsym(RTLD_DEFAULT, "il2cpp_field_static_get_value");
        ok = (p_domain_get && p_domain_assembly_open && p_assembly_get_image &&
              p_class_from_name && p_class_get_field_from_name && p_field_static_get_value);
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
    void *v = NULL;
    p_field_static_get_value(f, &v);
    return (uint64_t)v;
}

#pragma mark - matriz y proyección

static BOOL VXLoadMatrix(uint64_t cam) {
    if (!cam) return NO;
    float m[16];
    if (!VXRead(cam + 0x10, m, 64)) return NO;
    for (int i = 0; i < 16; i++)
        if (isnan(m[i]) || isinf(m[i])) return NO;
    memcpy(g_mtx, m, 64);
    float a = fabsf(m[12]) + fabsf(m[13]) + fabsf(m[14]);
    float b = fabsf(m[3])  + fabsf(m[7])  + fabsf(m[11]);
    g_tIdx = (b > a * 2.f) ? 0 : 1;
    g_mtxOk = YES;
    return YES;
}

static BOOL VXProj(V3 w, CGPoint *o) {
    if (!g_mtxOk) return NO;
    const float *m = g_mtx;
    float cx, cy, cz;
    if (g_tIdx) {
        cx = m[0]*w.x + m[4]*w.y + m[8]*w.z  + m[12];
        cy = m[1]*w.x + m[5]*w.y + m[9]*w.z  + m[13];
        cz = m[2]*w.x + m[6]*w.y + m[10]*w.z + m[14];
    } else {
        cx = m[0]*w.x + m[1]*w.y + m[2]*w.z  + m[3];
        cy = m[4]*w.x + m[5]*w.y + m[6]*w.z  + m[7];
        cz = m[8]*w.x + m[9]*w.y + m[10]*w.z + m[11];
    }
    float d = -cz;
    if (d < 0.05f) return NO;
    float f = (g_sz.height * 0.5f) / tanf(g_fov * (float)M_PI / 360.f) * g_scale;
    o->x = g_sz.width  * 0.5f + (cx / d) * f;
    o->y = g_sz.height * 0.5f - (cy / d) * f;
    if (isnan(o->x) || isnan(o->y)) return NO;
    return YES;
}

#pragma mark - posiciones

static BOOL VXMatPos(uint64_t t, V3 *o) {
    if (!t) return NO;
    float m[10];
    if (!VXRead(t, m, 40)) return NO;
    if (isnan(m[7]) || isnan(m[8]) || isnan(m[9])) return NO;
    o->x = m[7]; o->y = m[8]; o->z = m[9];
    if (fabsf(o->x) > 30000.f || fabsf(o->y) > 30000.f || fabsf(o->z) > 30000.f) return NO;
    return YES;
}

static BOOL VXHead(uint64_t pl, V3 *o) {
    uint64_t tr = VXPtr(pl + 0x3E8);
    V3 ref; BOOL hasRef = VXMatPos(tr, &ref);

    for (uint64_t off = 0x698; off <= 0x730; off += 8) {
        uint64_t b = VXPtr(pl + off);
        if (!b) continue;
        V3 p;
        if (!VXMatPos(b, &p)) continue;
        if (hasRef) {
            float dx = p.x - ref.x, dy = p.y - ref.y, dz = p.z - ref.z;
            if (dx*dx + dy*dy + dz*dz > 9.f) continue;
            if (p.y < ref.y - 0.2f) continue;
        }
        *o = p;
        return YES;
    }
    if (hasRef) { *o = ref; o->y += 1.75f; return YES; }
    return NO;
}

#pragma mark - contenedor

static uint64_t VXScanOne(uint64_t match, int *outN) {
    for (uint64_t off = 0x98; off <= 0x900; off += 8) {
        uint64_t o = VXPtr(match + off);
        if (!o) continue;
        uint64_t dict = VXPtr(o);
        if (!dict) continue;
        int n = VXInt(dict + 0x20);
        if (n < 2 || n > 200) continue;
        uint64_t e = VXPtr(dict + 0x18);
        if (!e) continue;
        int score = 0, lim = (n < 8) ? n : 8;
        for (int i = 0; i < lim; i++) {
            uint64_t v = VXPtr(e + (uint64_t)i * 0x18 + 0x30);
            if (!v) continue;
            if (VXStr(v + 0x498)) score++;
        }
        if (score >= 2) { *outN = n; return o; }
    }
    return 0;
}

#pragma mark - dibujo

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
        s.fillColor = nil;
        s.lineWidth = 1.5f;
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
        t.foregroundColor = UIColor.whiteColor.CGColor;
        t.shadowColor = UIColor.blackColor.CGColor;
        t.shadowOpacity = 0.9f;
        t.shadowRadius = 2;
        t.shadowOffset = CGSizeMake(0, 1);
        [g_over.layer addSublayer:t];
        [g_txts addObject:t];
    }
    return g_txts[i];
}

static void VXTick(CADisplayLink *l) {
    if (!g_over) return;
    for (CAShapeLayer *s in g_lays) s.hidden = YES;
    for (CATextLayer *t in g_txts) t.hidden = YES;
    if (!g_esp) return;

    uint64_t fac = VXFacade();
    if (!fac) return;
    uint64_t mg = VXPtr(fac + 0xB8);
    if (mg) mg = VXPtr(mg + 0x90);
    if (!mg) return;

    uint64_t ccm = VXPtr(mg + 0xB8);
    uint64_t cam = ccm ? VXPtr(ccm + 0x20) : 0;
    if (!VXLoadMatrix(cam)) return;

    g_local = VXPtr(mg + 0xD8);

    int n = 0;
    uint64_t cont = VXScanOne(mg, &n);
    if (!cont) return;
    uint64_t dict = VXPtr(cont);
    uint64_t ent  = dict ? VXPtr(dict + 0x18) : 0;
    if (!ent) return;

    V3 lh = {0, 0, 0};
    BOOL hasL = g_local ? VXHead(g_local, &lh) : NO;

    int used = 0;
    for (int i = 0; i < n; i++) {
        uint64_t pl = VXPtr(ent + (uint64_t)i * 0x18 + 0x30);
        if (!pl || pl == g_local) continue;

        V3 hd;
        if (!VXHead(pl, &hd)) continue;
        V3 toe = hd; toe.y -= 1.75f;

        CGPoint a, b;
        if (!VXProj(hd, &a)) continue;
        if (!VXProj(toe, &b)) continue;

        float h = fabsf(b.y - a.y);
        if (h < 4.f) continue;
        if (h > g_sz.height * 0.6f) h = g_sz.height * 0.6f;
        float w  = fmaxf(10.f, h * 0.62f);
        float cx = (a.x + b.x) * 0.5f;

        CAShapeLayer *s = VXLayerAt(used);
        s.hidden = NO;
        s.strokeColor = VXColor().CGColor;
        UIBezierPath *path = [UIBezierPath bezierPath];

        if (g_box) {
            [path appendPath:[UIBezierPath bezierPathWithRect:
                CGRectMake(cx - w * 0.5f, a.y, w, h)]];
        }
        if (g_line) {
            [path moveToPoint:CGPointMake(g_sz.width * 0.5f, g_sz.height)];
            [path addLineToPoint:CGPointMake(cx, a.y + h)];
        }
        s.path = path.CGPath;

        if (g_name || g_dist) {
            NSMutableString *cap = [NSMutableString string];
            if (g_name) {
                NSString *nm = VXStr(pl + 0x498);
                if (nm) [cap appendString:nm];
            }
            if (g_dist && hasL) {
                float dx = hd.x - lh.x, dy = hd.y - lh.y, dz = hd.z - lh.z;
                float m = sqrtf(dx*dx + dy*dy + dz*dz) / 100.f;
                if (cap.length) [cap appendString:@"  "];
                [cap appendFormat:@"%.0fm", m];
            }
            if (cap.length) {
                CATextLayer *t = VXTextAt(used);
                t.hidden = NO;
                t.string = cap;
                t.foregroundColor = VXColor().CGColor;
                t.frame = CGRectMake(cx - 70, a.y - 15, 140, 14);
            }
        }

        if (g_logFrames < 4)
            VXLog(@"box %d x=%.0f y=%.0f h=%.0f head=(%.1f,%.1f,%.1f) scr=%.0fx%.0f fov=%.0f esc=%.2f",
                  i, cx, a.y, h, hd.x, hd.y, hd.z, g_sz.width, g_sz.height, g_fov, g_scale);

        used++;
    }
    if (g_logFrames < 4) g_logFrames++;
}

#pragma mark - reset guest

static void VXWipeDir(NSString *d) {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    for (NSString *f in [fm contentsOfDirectoryAtPath:d error:nil]) {
        if ([f isEqualToString:@"veex_log.txt"]) continue;
        NSString *p = [d stringByAppendingPathComponent:f];
        if ([fm fileExistsAtPath:p isDirectory:&isDir] && isDir) VXWipeDir(p);
        [fm removeItemAtPath:p error:nil];
    }
}

static void VXResetGuest(void) {
    NSString *h = NSHomeDirectory();
    VXWipeDir([h stringByAppendingPathComponent:@"Documents"]);
    VXWipeDir([h stringByAppendingPathComponent:@"Library"]);
    VXWipeDir(NSTemporaryDirectory());
    NSDictionary *q = @{ (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword };
    SecItemDelete((__bridge CFDictionaryRef)q);
    usleep(400000);
    _exit(0);
}

#pragma mark - host

@interface VXHost : NSObject
+ (instancetype)shared;
- (void)tick:(CADisplayLink *)l;
- (void)swEsp:(UISwitch *)s;
- (void)swBox:(UISwitch *)s;
- (void)swLine:(UISwitch *)s;
- (void)swName:(UISwitch *)s;
- (void)swDist:(UISwitch *)s;
- (void)slFov:(UISlider *)s;
- (void)slScale:(UISlider *)s;
- (void)btColor;
- (void)btReset;
- (void)btClose;
- (void)tapBubble:(UIButton *)b;
- (void)panBubble:(UIPanGestureRecognizer *)g;
@end

@implementation VXHost
+ (instancetype)shared {
    static VXHost *h; static dispatch_once_t o;
    dispatch_once(&o, ^{ h = [VXHost new]; });
    return h;
}
- (void)tick:(CADisplayLink *)l { VXTick(l); }
- (void)swEsp:(UISwitch *)s {
    g_esp = s.on;
    if (g_esp) { g_logFrames = 0; VXLog(@"=== ESP ON 3.2 ==="); }
    else { VXLog(@"ESP OFF"); }
}
- (void)swBox:(UISwitch *)s  { g_box  = s.on; }
- (void)swLine:(UISwitch *)s { g_line = s.on; }
- (void)swName:(UISwitch *)s { g_name = s.on; }
- (void)swDist:(UISwitch *)s { g_dist = s.on; }
- (void)slFov:(UISlider *)s  { g_fov = s.value; }
- (void)slScale:(UISlider *)s{ g_scale = s.value; }
- (void)btColor { g_color = (g_color + 1) % 5; }
- (void)btReset { VXResetGuest(); }
- (void)btClose { g_panel.hidden = YES; }
- (void)tapBubble:(UIButton *)b { g_panel.hidden = !g_panel.hidden; }
- (void)panBubble:(UIPanGestureRecognizer *)g {
    CGPoint d = [g translationInView:g_bub.superview];
    g_bub.center = CGPointMake(g_bub.center.x + d.x, g_bub.center.y + d.y);
    [g setTranslation:CGPointZero inView:g_bub.superview];
}
@end

#pragma mark - UI

static UIView *VXRow(CGFloat y, NSString *title, BOOL on, SEL act) {
    UIView *r = [[UIView alloc] initWithFrame:CGRectMake(0, y, 280, 40)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 190, 40)];
    l.text = title;
    l.textColor = UIColor.whiteColor;
    l.font = [UIFont boldSystemFontOfSize:14];
    [r addSubview:l];
    UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectMake(198, 5, 51, 31)];
    s.on = on;
    s.onTintColor = [UIColor colorWithRed:0.10 green:0.72 blue:0.42 alpha:1];
    [s addTarget:[VXHost shared] action:act forControlEvents:UIControlEventValueChanged];
    [r addSubview:s];
    return r;
}

static UIView *VXSlider(CGFloat y, NSString *title, float lo, float hi, float v, SEL act) {
    UIView *r = [[UIView alloc] initWithFrame:CGRectMake(0, y, 280, 58)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 250, 20)];
    l.text = title;
    l.textColor = [UIColor colorWithWhite:0.85 alpha:1];
    l.font = [UIFont systemFontOfSize:12];
    [r addSubview:l];
    UISlider *s = [[UISlider alloc] initWithFrame:CGRectMake(14, 22, 250, 30)];
    s.minimumValue = lo; s.maximumValue = hi; s.value = v;
    s.minimumTrackTintColor = [UIColor colorWithRed:0.10 green:0.72 blue:0.42 alpha:1];
    [s addTarget:[VXHost shared] action:act forControlEvents:UIControlEventValueChanged];
    [r addSubview:s];
    return r;
}

static UIButton *VXButton(CGRect f, NSString *t, SEL act) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f;
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    b.backgroundColor = [UIColor colorWithRed:0.16 green:0.18 blue:0.22 alpha:1];
    b.layer.cornerRadius = 8;
    [b addTarget:[VXHost shared] action:act forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void VXBuildPanel(void) {
    if (g_panel) return;
    g_panel = [[UIView alloc] initWithFrame:CGRectMake(14, 90, 280, 466)];
    g_panel.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:0.96];
    g_panel.layer.cornerRadius = 14;
    g_panel.layer.borderWidth = 1;
    g_panel.layer.borderColor = [UIColor colorWithRed:0.10 green:0.72 blue:0.42 alpha:0.6].CGColor;
    g_panel.hidden = YES;

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 250, 26)];
    t.text = @"VEEX 3.2";
    t.textColor = [UIColor colorWithRed:0.10 green:0.72 blue:0.42 alpha:1];
    t.font = [UIFont boldSystemFontOfSize:17];
    [g_panel addSubview:t];

    [g_panel addSubview:VXRow(40,  @"ESP",       g_esp,  @selector(swEsp:))];
    [g_panel addSubview:VXRow(80,  @"Caja",      g_box,  @selector(swBox:))];
    [g_panel addSubview:VXRow(120, @"Línea",     g_line, @selector(swLine:))];
    [g_panel addSubview:VXRow(160, @"Nombre",    g_name, @selector(swName:))];
    [g_panel addSubview:VXRow(200, @"Distancia", g_dist, @selector(swDist:))];
    [g_panel addSubview:VXSlider(244, @"FOV",    40.f, 110.f, g_fov,   @selector(slFov:))];
    [g_panel addSubview:VXSlider(306, @"Escala", 0.3f, 2.5f,  g_scale, @selector(slScale:))];

    [g_panel addSubview:VXButton(CGRectMake(14, 372, 122, 40), @"COLOR",       @selector(btColor))];
    [g_panel addSubview:VXButton(CGRectMake(144, 372, 122, 40), @"RESET GUEST", @selector(btReset))];
    [g_panel addSubview:VXButton(CGRectMake(14, 418, 252, 36), @"CERRAR",      @selector(btClose))];
}

static void VXBuildBubble(UIWindow *w) {
    if (g_bub) return;
    g_bub = [UIButton buttonWithType:UIButtonTypeCustom];
    g_bub.frame = CGRectMake(w.bounds.size.width - 66, 96, 52, 52);
    g_bub.backgroundColor = [UIColor colorWithRed:0.10 green:0.72 blue:0.42 alpha:0.92];
    g_bub.layer.cornerRadius = 26;
    g_bub.layer.shadowColor = UIColor.blackColor.CGColor;
    g_bub.layer.shadowOpacity = 0.5f;
    g_bub.layer.shadowRadius = 6;
    [g_bub setTitle:@"V" forState:UIControlStateNormal];
    [g_bub setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    g_bub.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [g_bub addTarget:[VXHost shared] action:@selector(tapBubble:) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc] initWithTarget:[VXHost shared] action:@selector(panBubble:)];
    [g_bub addGestureRecognizer:p];
    [w addSubview:g_bub];
}

static void VXMount(void) {
    UIWindow *w = nil;
    for (UIWindow *x in [UIApplication sharedApplication].windows)
        if (x.isKeyWindow && x.windowLevel < UIWindowLevelAlert) { w = x; break; }
    if (!w) w = [UIApplication sharedApplication].keyWindow;
    if (!w) return;

    if (!g_bub) VXBuildBubble(w);
    if (g_bub.superview != w) { [g_bub removeFromSuperview]; [w addSubview:g_bub]; }
    if (g_panel.superview != w) { [g_panel removeFromSuperview]; [w addSubview:g_panel]; }

    if (!g_over) {
        g_over = [[UIView alloc] initWithFrame:w.bounds];
        g_over.backgroundColor = UIColor.clearColor;
        g_over.userInteractionEnabled = NO;
        g_over.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        g_lays = [NSMutableArray array];
        g_txts = [NSMutableArray array];
        [w addSubview:g_over];
        g_link = [CADisplayLink displayLinkWithTarget:[VXHost shared] selector:@selector(tick:)];
        [g_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    if (g_over.superview != w) { [g_over removeFromSuperview]; [w addSubview:g_over]; }
    g_win = w;
}

static void VXStart(void) {
    VXBuildPanel();
    int tries = 0;
    while (tries++ < 900) {
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        if (w && w.bounds.size.width > 100) break;
        usleep(20000);
    }
    VXMount();
    dispatch_async(dispatch_get_main_queue(), ^{
        VXMount();
        if (!g_mount)
            g_mount = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer *t) {
                VXMount();
            }];
    });
    VXLog(@"menu montado 3.2");
}

__attribute__((constructor))
static void VXInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        VXStart();
    });
}
