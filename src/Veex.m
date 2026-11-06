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

static BOOL VXOk(void *p){
    if (!p) return NO;
    uintptr_t v = (uintptr_t)p;
    return (v > 0x10000) && ((v & 7) == 0);
}

#pragma mark - il2cpp

static void *(*p_domain_get)(void);
static void **(*p_domain_get_assemblies)(void *, size_t *);
static void *(*p_assembly_get_image)(void *);
static void *(*p_class_from_name)(void *, const char *, const char *);
static void *(*p_class_get_method_from_name)(void *, const char *, int);
static void *(*p_runtime_invoke)(void *, void *, void **, void **);
static const char *(*p_class_get_name)(void *);
static void *(*p_class_get_parent)(void *);

static BOOL g_ready = NO;
static void *g_facade = NULL;
static void *g_match = NULL;
static void *g_local = NULL;
static void *g_cam = NULL;

static void *g_m_getTransform = NULL;
static void *g_m_getPosition = NULL;
static void *g_m_proj[4] = {NULL, NULL, NULL, NULL};
static int   g_projCount = 0;

static void VXResolve(void){
    if (g_ready) return;

    p_domain_get                 = dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
    p_domain_get_assemblies      = dlsym(RTLD_DEFAULT, "il2cpp_domain_get_assemblies");
    p_assembly_get_image         = dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
    p_class_from_name            = dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
    p_class_get_method_from_name = dlsym(RTLD_DEFAULT, "il2cpp_class_get_method_from_name");
    p_runtime_invoke             = dlsym(RTLD_DEFAULT, "il2cpp_runtime_invoke");
    p_class_get_name             = dlsym(RTLD_DEFAULT, "il2cpp_class_get_name");
    p_class_get_parent           = dlsym(RTLD_DEFAULT, "il2cpp_class_get_parent");

    if (!p_domain_get || !p_domain_get_assemblies || !p_assembly_get_image ||
        !p_class_from_name || !p_class_get_method_from_name || !p_runtime_invoke) {
        VXLog(@"FALLO dlsym il2cpp");
        return;
    }

    void *dom = p_domain_get();
    if (!dom) { VXLog(@"FALLO domain"); return; }

    size_t n = 0;
    void **asms = p_domain_get_assemblies(dom, &n);
    if (!asms || !n) { VXLog(@"FALLO assemblies"); return; }

    const char *nss[] = { "COW.GamePlay", "COW", "" };
    for (size_t i = 0; i < n && !g_facade; i++) {
        void *img = p_assembly_get_image(asms[i]);
        if (!img) continue;
        for (int k = 0; k < 3 && !g_facade; k++) {
            g_facade = p_class_from_name(img, nss[k], "GameFacade");
        }
    }
    if (!g_facade) { VXLog(@"FALLO clase GameFacade"); return; }

    VXLog(@"api OK facade=%p", g_facade);
    g_ready = YES;
}

static void VXPrepMethods(void){
    if (g_m_getTransform && g_m_getPosition) return;

    void *k = g_facade;
    for (int i = 0; i < 12 && k; i++) {
        if (!g_m_getTransform) g_m_getTransform = p_class_get_method_from_name(k, "get_transform", 0);
        k = p_class_get_parent ? p_class_get_parent(k) : NULL;
    }

    if (g_local) {
        void *lk = VXAt(g_local, 0);
        if (VXOk(lk)) g_m_getPosition = p_class_get_method_from_name(lk, "get_position", 0);
    }

    if (g_cam) {
        void *ck = VXAt(g_cam, 0);
        if (VXOk(ck)) {
            const char *nm[4] = { "WorldToViewportPoint_Injected", "WorldToViewportPoint",
                                  "WorldToScreenPoint_Injected", "WorldToScreenPoint" };
            for (int i = 0; i < 4; i++) {
                void *m = p_class_get_method_from_name(ck, nm[i], 1);
                if (m) g_m_proj[g_projCount++] = m;
            }
        }
    }
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

static BOOL VXProj(void *cam, CGPoint world, CGSize sz, CGPoint *out){
    if (!cam || g_projCount == 0) return NO;

    float v[3] = { (float)world.x, (float)world.y, 0.0f };
    for (int i = 0; i < g_projCount; i++) {
        void *args[1] = { v };
        void *exc = NULL;
        float *r = NULL;
        @try { r = (float *)p_runtime_invoke(g_m_proj[i], cam, args, &exc); } @catch (...) { r = NULL; }
        if (!r) continue;
        float x = r[0], y = r[1], z = r[2];
        if (x != x || y != y) continue;

        BOOL norm = (fabsf(x) <= 1.5f && fabsf(y) <= 1.5f);
        if (norm) {
            if (x < -0.05f || x > 1.05f || y < -0.05f || y > 1.05f) continue;
            out->x = x * sz.width;
            out->y = (1.0f - y) * sz.height;
        } else {
            if (z < 0.01f) continue;
            out->x = x;
            out->y = sz.height - y;
        }
        return YES;
    }
    return NO;
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
    CGContextSetLineWidth(ctx, 1.2);
    CGContextSetFillColorWithColor(ctx, [col colorWithAlphaComponent:0.12].CGColor);
    for (int i = 0; i < g_boxN; i++) {
        CGPoint a = g_box[i][0], b = g_box[i][1], c = g_box[i][2], d = g_box[i][3];
        CGContextMoveToPoint(ctx, a.x, a.y);
        CGContextAddLineToPoint(ctx, b.x, b.y);
        CGContextAddLineToPoint(ctx, c.x, c.y);
        CGContextAddLineToPoint(ctx, d.x, d.y);
        CGContextClosePath(ctx);
        CGContextDrawPath(ctx, kCGPathFillStroke);
        CGPoint h = g_box[i][3];
        CGContextFillRect(ctx, CGRectMake(h.x - 1.5, h.y - 1.5, 3, 3));
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

static void VXResetGuest(void){
    NSArray *classes = @[ (__bridge id)kSecClassGenericPassword,
                          (__bridge id)kSecClassInternetPassword,
                          (__bridge id)kSecClassKey,
                          (__bridge id)kSecClassCertificate ];
    for (id c in classes) {
        NSDictionary *q = @{ (__bridge id)kSecClass : c };
        SecItemDelete((__bridge CFDictionaryRef)q);
    }
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *lib  = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *base in @[ docs, lib ]) {
        for (NSString *f in [fm contentsOfDirectoryAtPath:base error:nil]) {
            if ([f hasSuffix:@".plist"] || [f hasSuffix:@".db"] || [f hasSuffix:@".sqlite"] ||
                [f containsString:@"com.dts"] || [f containsString:@"Preferences"]) {
                [fm removeItemAtPath:[base stringByAppendingPathComponent:f] error:nil];
            }
        }
    }
    VXLog(@"reset guest hecho");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

#pragma mark - ciclo ESP

static void VXStopESP(void){
    g_esp = NO;
    g_boxN = 0;
    if (g_link) { [g_link invalidate]; g_link = nil; }
    [g_overlay setNeedsDisplay];
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
            VXLog(@"paso 1 ok");
        }

        if (g_step == 1) {
            g_step = 2;
            void *f = VXAt(g_facade, 0x8);
            if (!VXOk(f)) { VXLog(@"FALLO paso 2 facade"); VXStopESP(); return; }
            g_match = VXAt(f, 0x90);
            if (!VXOk(g_match)) { VXLog(@"FALLO paso 2 match %p", f); VXStopESP(); return; }
            VXLog(@"paso 2 ok match=%p", g_match);
        }

        if (g_step == 2) {
            g_step = 3;
            g_local = VXAt(g_match, 0xD8);
            void *mg  = VXAt(g_facade, 0x8);
            void *ccm = mg ? VXAt(mg, 0xD8) : NULL;
            if (VXOk(ccm)) g_cam = VXAt(ccm, 0x20);
            VXLog(@"paso 3 local=%p cam=%p", g_local, g_cam);
            VXPrepMethods();
            VXLog(@"paso 3 metodos tf=%p pos=%p proj=%d", g_m_getTransform, g_m_getPosition, g_projCount);
            if (!g_m_getTransform || !g_m_getPosition || g_projCount == 0) {
                VXLog(@"FALLO paso 3 metodos"); VXStopESP(); return;
            }
        }

        if (g_step == 3) {
            size_t offs[3] = { 0x158, 0x160, 0x570 };
            for (int i = 0; i < 3; i++) {
                void *l = VXAt(g_match, offs[i]);
                if (!VXOk(l)) continue;
                size_t s = 0;
                if (!VXRead((char *)l + 0x18, &s, sizeof(s))) continue;
                if (s > 0 && s < 300) { g_listObj = l; g_listOff = offs[i]; break; }
            }
            if (!g_listObj) {
                g_retry++;
                if (g_retry > 400) { VXLog(@"FALLO paso 4 sin lista"); VXStopESP(); }
                return;
            }
            g_step = 4;
            VXLog(@"paso 4 lista=%p off=0x%zx", g_listObj, g_listOff);
        }

        if (!g_listObj) return;

        g_L = 0; g_B = 0; g_P = 0; g_D = 0; g_boxN = 0;

        size_t count = 0;
        if (!VXRead((char *)g_listObj + 0x18, &count, sizeof(count))) return;
        if (count == 0 || count > 200) return;
        g_L = (int)count;

        void *items = VXAt(g_listObj, 0x10);
        if (!VXOk(items)) return;
        g_B = 1;

        for (size_t i = 0; i < count && g_boxN < 120; i++) {
            void *pl = VXAt(items, 0x20 + i * 8);
            if (!VXOk(pl)) { g_D++; continue; }

            void *args[1] = { NULL };
            void *exc = NULL;
            void *tf = NULL;
            @try { tf = p_runtime_invoke(g_m_getTransform, pl, args, &exc); } @catch (...) { tf = NULL; }
            if (!VXOk(tf)) { g_D++; continue; }

            float *pos = NULL;
            void *exc2 = NULL;
            @try { pos = (float *)p_runtime_invoke(g_m_getPosition, tf, args, &exc2); } @catch (...) { pos = NULL; }
            if (!pos) { g_D++; continue; }

            CGPoint feet = CGPointMake(pos[0], pos[1]);
            CGPoint head = CGPointMake(pos[0], pos[1] + 1.75f);

            CGPoint pf, ph;
            if (!VXProj(g_cam, feet, sz, &pf)) { g_D++; continue; }
            if (!VXProj(g_cam, head, sz, &ph)) { g_D++; continue; }
            if (pf.y <= ph.y) { g_D++; continue; }

            float h = pf.y - ph.y;
            float w = h * 0.45f;
            if (w < 4 || w > sz.width) continue;

            g_box[g_boxN][0] = CGPointMake(pf.x - w / 2, pf.y);
            g_box[g_boxN][1] = CGPointMake(pf.x + w / 2, pf.y);
            g_box[g_boxN][2] = CGPointMake(ph.x + w / 2, ph.y);
            g_box[g_boxN][3] = CGPointMake(ph.x - w / 2, ph.y);
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
    if (g_root) return;
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

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(180, 8, 51, 31)];
    [sw addTarget:g_menu action:@selector(espChanged:) forControlEvents:UIControlEventValueChanged];
    [g_panel addSubview:sw];

    [g_panel addSubview:VXLabel(@"ESP", CGRectMake(14, 46, 100, 18), 13)];
    [g_panel addSubview:VXBtn(@"COLOR", CGRectMake(120, 42, 110, 30), g_menu, @selector(colorTap))];
    [g_panel addSubview:VXBtn(@"ESTADO", CGRectMake(14, 86, 100, 32), g_menu, @selector(estadoTap))];
    [g_panel addSubview:VXBtn(@"RESET GUEST", CGRectMake(120, 86, 110, 32), g_menu, @selector(resetTap))];
    [g_panel addSubview:VXBtn(@"CERRAR", CGRectMake(14, 130, 100, 32), g_menu, @selector(togglePanel))];

    UILabel *foot = VXLabel(@"log: Documents/veex_log.txt", CGRectMake(14, 175, 220, 16), 10);
    foot.textColor = [UIColor colorWithWhite:1 alpha:0.5];
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
    if (s.isOn) {
        VXStartESP();
    } else {
        VXStopESP();
        VXLog(@"ESP OFF");
    }
}

- (void)colorTap {
    g_color++;
    NSArray *n = @[ @"VERDE", @"ROJO", @"CYAN", @"AMARILLO", @"MAGENTA", @"BLANCO" ];
    if (g_color >= (int)n.count) g_color = 0;
    VXLog(@"color %@", n[g_color]);
}

- (void)estadoTap {
    NSString *msg = [NSString stringWithFormat:@"L %d  B %d  P %d  D %d\noff 0x%zx  proj %d",
                     g_L, g_B, g_P, g_D, g_listOff, g_projCount];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"ESTADO" message:msg
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:a animated:YES completion:nil];
}

- (void)resetTap {
    VXResetGuest();
}

@end

#pragma mark - constructor

__attribute__((constructor))
static void VXInit(void){
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [VXMenu show];
    });
}
