#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#include <string.h>
#include <unistd.h>

#pragma mark - log

static NSMutableString *g_log;
static void VXLog(NSString *fmt, ...) {
    if (!g_log) g_log = [NSMutableString new];
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    [g_log appendFormat:@"%@\n", s];
    if (g_log.length > 4000) [g_log deleteCharactersInRange:NSMakeRange(0, 2000)];
}

#pragma mark - dyld

static uint32_t (*orig_count)(void);
static const char *(*orig_name)(uint32_t);
static int g_hideIdx = -1;
static BOOL g_dyldReady = NO;

static void VXOrig(void) {
    if (g_dyldReady) return;
    static void *sys;
    if (!sys) sys = dlopen("/usr/lib/libSystem.B.dylib", RTLD_LAZY);
    if (sys) {
        if (!orig_count) orig_count = (uint32_t (*)(void))dlsym(sys, "_dyld_image_count");
        if (!orig_name) orig_name = (const char *(*)(uint32_t))dlsym(sys, "_dyld_get_image_name");
    }
    g_dyldReady = (orig_count != NULL && orig_name != NULL);
}

static uint32_t vx_count(void) {
    VXOrig();
    uint32_t n = orig_count ? orig_count() : 0;
    return (g_hideIdx >= 0 && n > 0) ? n - 1 : n;
}

static const char *vx_name(uint32_t i) {
    VXOrig();
    if (!orig_name) return NULL;
    uint32_t n = orig_count ? orig_count() : 0;
    uint32_t idx = (g_hideIdx >= 0 && (int)i >= g_hideIdx) ? i + 1 : i;
    if ((int)idx >= (int)n) return NULL;
    return orig_name(idx);
}

__attribute__((used, section("__DATA,__interpose")))
static const void *vx_pairs[][2] = {
    { (const void *)vx_count, (const void *)_dyld_image_count },
    { (const void *)vx_name,  (const void *)_dyld_get_image_name },
};

static void VXHideSelf(void) {
    VXOrig();
    if (!orig_count || !orig_name) return;
    uint32_t n = orig_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = orig_name(i);
        if (!nm) continue;
        if (strstr(nm, "veex") || strstr(nm, "Vee.x")) { g_hideIdx = (int)i; break; }
    }
    VXLog(@"oculto: %d de %u", g_hideIdx, n);
}

#pragma mark - keychain

static int VXKeychainPurge(BOOL guestOnly) {
    NSArray *tokens = guestOnly
        ? @[@"garena", @"freefire", @"com.dts", @"guest", @"dts"]
        : @[@"garena", @"freefire", @"com.dts", @"facebook", @"google", @"apple"];
    NSArray *classes = @[(__bridge id)kSecClassGenericPassword, (__bridge id)kSecClassInternetPassword];
    int removed = 0;
    for (id cls in classes) {
        NSDictionary *q = @{ (__bridge id)kSecClass: cls,
                             (__bridge id)kSecReturnAttributes: @YES,
                             (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll };
        CFTypeRef out = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &out) != errSecSuccess || !out) continue;
        NSArray *items = (__bridge_transfer NSArray *)out;
        for (NSDictionary *it in items) {
            NSString *acct = it[(__bridge id)kSecAttrAccount] ?: @"";
            NSString *svc  = it[(__bridge id)kSecAttrService] ?: @"";
            NSString *blob = [[acct stringByAppendingString:@" "] stringByAppendingString:svc].lowercaseString;
            BOOL hit = NO;
            for (NSString *t in tokens) { if ([blob containsString:t]) { hit = YES; break; } }
            if (!hit) continue;
            NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:it];
            [d setObject:cls forKey:(__bridge id)kSecClass];
            if (SecItemDelete((__bridge CFDictionaryRef)d) == errSecSuccess) removed++;
        }
    }
    return removed;
}

#pragma mark - il2cpp

static void *h_unity;
static void *(*p_domain_get)(void);
static void *(*p_domain_assemblies)(void *, size_t *);
static void *(*p_assembly_image)(void *);
static size_t (*p_image_class_count)(void *);
static void *(*p_image_class)(void *, size_t);
static const char *(*p_class_name)(void *);
static const char *(*p_class_ns)(void *);
static void *(*p_class_parent)(void *);
static void *(*p_class_field)(void *, const char *);
static size_t (*p_field_offset)(void *);
static void *(*p_class_methods)(void *, void **);
static const char *(*p_method_name)(void *);

static BOOL VXResolve(void) {
    if (!h_unity) h_unity = dlopen("UnityFramework", RTLD_LAZY);
    if (!h_unity) h_unity = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
    if (!h_unity) return NO;
    if (!p_domain_get) p_domain_get = dlsym(h_unity, "il2cpp_domain_get");
    if (!p_domain_assemblies) p_domain_assemblies = dlsym(h_unity, "il2cpp_domain_get_assemblies");
    if (!p_assembly_image) p_assembly_image = dlsym(h_unity, "il2cpp_assembly_get_image");
    if (!p_image_class_count) p_image_class_count = dlsym(h_unity, "il2cpp_image_get_class_count");
    if (!p_image_class) p_image_class = dlsym(h_unity, "il2cpp_image_get_class");
    if (!p_class_name) p_class_name = dlsym(h_unity, "il2cpp_class_get_name");
    if (!p_class_ns) p_class_ns = dlsym(h_unity, "il2cpp_class_get_namespace");
    if (!p_class_parent) p_class_parent = dlsym(h_unity, "il2cpp_class_get_parent");
    if (!p_class_field) p_class_field = dlsym(h_unity, "il2cpp_class_get_field_from_name");
    if (!p_field_offset) p_field_offset = dlsym(h_unity, "il2cpp_field_get_offset");
    if (!p_class_methods) p_class_methods = dlsym(h_unity, "il2cpp_class_get_methods");
    if (!p_method_name) p_method_name = dlsym(h_unity, "il2cpp_method_get_name");
    return p_domain_get && p_domain_assemblies && p_assembly_image && p_image_class;
}

static void *VXClass(const char *ns, const char *name) {
    if (!VXResolve()) return NULL;
    void *dom = p_domain_get();
    if (!dom) return NULL;
    size_t n = 0;
    void **as = p_domain_assemblies(dom, &n);
    if (!as) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = p_assembly_image(as[i]);
        if (!img || !p_image_class_count) continue;
        size_t cc = p_image_class_count(img);
        for (size_t j = 0; j < cc; j++) {
            void *k = p_image_class(img, j);
            if (!k) continue;
            const char *cn = p_class_name ? p_class_name(k) : NULL;
            if (!cn || strcmp(cn, name)) continue;
            if (ns && *ns && p_class_ns) {
                const char *cns = p_class_ns(k);
                if (!cns || strcmp(cns, ns)) continue;
            }
            return k;
        }
    }
    return NULL;
}

static size_t VXFieldOffset(void *k, const char *name) {
    if (!k || !p_class_field) return 0;
    for (int d = 0; k && d < 12; d++) {
        void *f = p_class_field(k, name);
        if (f && p_field_offset) return p_field_offset(f);
        k = p_class_parent ? p_class_parent(k) : NULL;
    }
    return 0;
}

#pragma mark - estado

static struct {
    BOOL esp;
    BOOL aim;
    BOOL fire;
    BOOL visOnly;
    CGFloat fov;
} g;

static UIWindow *g_win;
static UIView *g_draw;
static UILabel *g_diag;
static NSInteger g_classes;

#pragma mark - vista

@interface VXDraw : UIView
@end

@implementation VXDraw
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(c, [UIColor colorWithRed:0 green:1 blue:0.4 alpha:0.85].CGColor);
    CGContextSetLineWidth(c, 1.5);
    CGPoint m = CGPointMake(r.size.width / 2, r.size.height / 2);
    CGContextStrokeEllipseInRect(c, CGRectMake(m.x - g.fov, m.y - g.fov, g.fov * 2, g.fov * 2));
    CGContextSetFillColorWithColor(c, [UIColor colorWithRed:0 green:1 blue:0.4 alpha:0.9].CGColor);
    CGContextFillRect(c, CGRectMake(m.x - 1, m.y - 1, 2, 2));
}
@end

#pragma mark - panel

@interface VeexPanel : UIView
@property (nonatomic, strong) UIView *box;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) CADisplayLink *link;
- (void)show;
- (void)tick:(CADisplayLink *)l;
@end

@implementation VeexPanel

- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        g.fov = 130;
        self.backgroundColor = [UIColor clearColor];

        _box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 300)];
        _box.backgroundColor = [UIColor colorWithRed:0.05 green:0.07 blue:0.11 alpha:0.95];
        _box.layer.cornerRadius = 14;
        _box.layer.borderWidth = 1;
        _box.layer.borderColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.5].CGColor;
        _box.hidden = YES;
        [self addSubview:_box];

        _title = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 170, 22)];
        _title.text = @"VEEX 1.132";
        _title.textColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:1];
        _title.font = [UIFont boldSystemFontOfSize:14];
        [_box addSubview:_title];

        UIButton *x = [UIButton buttonWithType:UIButtonTypeSystem];
        x.frame = CGRectMake(210, 8, 30, 26);
        [x setTitle:@"x" forState:UIControlStateNormal];
        [x addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
        [_box addSubview:x];

        NSArray *names = @[@"ESP", @"AIMBOT", @"AUTO FIRE", @"SOLO VISIBLES"];
        for (int i = 0; i < names.count; i++) {
            UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 40 + i * 34, 150, 26)];
            l.text = names[i];
            l.textColor = [UIColor whiteColor];
            l.font = [UIFont systemFontOfSize:12];
            [_box addSubview:l];

            UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectMake(178, 38 + i * 34, 51, 31)];
            s.tag = i;
            s.transform = CGAffineTransformMakeScale(0.7, 0.7);
            [s addTarget:self action:@selector(sw:) forControlEvents:UIControlEventValueChanged];
            [_box addSubview:s];
        }

        UILabel *fl = [[UILabel alloc] initWithFrame:CGRectMake(14, 182, 100, 20)];
        fl.text = @"FOV";
        fl.textColor = [UIColor lightGrayColor];
        fl.font = [UIFont systemFontOfSize:11];
        [_box addSubview:fl];

        UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(14, 202, 216, 24)];
        sl.minimumValue = 60; sl.maximumValue = 300; sl.value = 130;
        [sl addTarget:self action:@selector(fov:) forControlEvents:UIControlEventValueChanged];
        [_box addSubview:sl];

        UIButton *rb = [UIButton buttonWithType:UIButtonTypeSystem];
        rb.frame = CGRectMake(14, 234, 216, 32);
        [rb setTitle:@"RESET INVITADO" forState:UIControlStateNormal];
        rb.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.18];
        rb.layer.cornerRadius = 8;
        [rb addTarget:self action:@selector(reset) forControlEvents:UIControlEventTouchUpInside];
        [_box addSubview:rb];

        g_diag = [[UILabel alloc] initWithFrame:CGRectMake(14, 270, 220, 20)];
        g_diag.textColor = [UIColor colorWithRed:0.6 green:0.8 blue:1 alpha:1];
        g_diag.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
        g_diag.text = @"...";
        [_box addSubview:g_diag];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        [_box addGestureRecognizer:pan];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        [self addGestureRecognizer:tap];

        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)tap:(UITapGestureRecognizer *)t {
    CGPoint p = [t locationInView:self];
    if (!CGRectContainsPoint(_box.frame, p)) {
        _box.hidden = !_box.hidden;
        _box.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    }
}

- (void)drag:(UIPanGestureRecognizer *)p {
    CGPoint d = [p translationInView:self];
    _box.center = CGPointMake(_box.center.x + d.x, _box.center.y + d.y);
    [p setTranslation:CGPointZero inView:self];
}

- (void)close { _box.hidden = YES; }

- (void)sw:(UISwitch *)s {
    BOOL on = s.isOn;
    switch (s.tag) {
        case 0: g.esp = on; break;
        case 1: g.aim = on; break;
        case 2: g.fire = on; break;
        case 3: g.visOnly = on; break;
    }
    VXLog(@"sw %ld = %d", (long)s.tag, on);
}

- (void)fov:(UISlider *)s { g.fov = s.value; }

- (void)reset {
    int n = VXKeychainPurge(YES);
    g_diag.text = [NSString stringWithFormat:@"reset: %d", n];
}

- (void)tick:(CADisplayLink *)l {
    if (g_classes == 0 && VXResolve()) {
        void *k = VXClass("", "SpawnObjectCrossHairTrigger");
        if (k) g_classes = 1;
    }
    if (g_diag) g_diag.text = [NSString stringWithFormat:@"cls %ld esp%d aim%d", (long)g_classes, g.esp, g.aim];
    if (g_draw) [g_draw setNeedsDisplay];
}

@end

#pragma mark - arranque

static void VXBuildMenu(void) {
    CGRect s = [UIScreen mainScreen].bounds;
    g_win = [[UIWindow alloc] initWithFrame:s];
    g_win.windowLevel = UIWindowLevelAlert + 10;
    g_win.backgroundColor = [UIColor clearColor];
    g_win.rootViewController = [UIViewController new];
    g_win.hidden = NO;

    VXDraw *d = [[VXDraw alloc] initWithFrame:s];
    d.backgroundColor = [UIColor clearColor];
    d.userInteractionEnabled = NO;
    [g_win addSubview:d];
    g_draw = d;

    VeexPanel *p = [[VeexPanel alloc] initWithFrame:s];
    [g_win addSubview:p];

    UIView *bub = [[UIView alloc] initWithFrame:CGRectMake(20, 120, 52, 52)];
    bub.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.22];
    bub.layer.cornerRadius = 26;
    bub.layer.borderWidth = 1.5;
    bub.layer.borderColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.9].CGColor;
    bub.userInteractionEnabled = NO;
    [g_win addSubview:bub];

    VXLog(@"menu");
}

__attribute__((constructor)) static void VXInit(void) {
    VXHideSelf();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (int i = 0; i < 900; i++) {
            __block BOOL up = NO;
            dispatch_sync(dispatch_get_main_queue(), ^{
                UIApplication *a = [UIApplication sharedApplication];
                up = (a != nil && a.windows.count > 0);
            });
            if (up) break;
            usleep(200000);
        }
        dispatch_async(dispatch_get_main_queue(), ^{ VXBuildMenu(); });
    });
}
