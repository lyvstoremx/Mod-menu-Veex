// Veex.m
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <math.h>
#import <string.h>

#define VX_PATCH_URL "https://github.com/lyvstoremx/Mod-menu-Veex/releases/download/base/Assembly-CSharp-patch.bytes"
#define VX_NEUTRAL_URL "https://github.com/lyvstoremx/Mod-menu-Veex/releases/download/base/Assembly-CSharp-patch-neutral.bytes"

typedef void   *(*fn_domain_get)(void);
typedef void    (*fn_thread_attach)(void *);
typedef void   *(*fn_class_from_name)(void *, const char *, const char *);
typedef void   *(*fn_class_get_method_from_name)(void *, const char *, int);
typedef void   *(*fn_runtime_invoke)(void *, void *, void **, void **);
typedef void   *(*fn_string_new)(const char *);
typedef void   *(*fn_object_new)(void *);
typedef void   *(*fn_value_box)(void *, void *);
typedef void   *(*fn_array_new)(void *, uint32_t);
typedef void   *(*fn_class_get_methods)(void *, void **);
typedef const char *(*fn_method_get_name)(void *);
typedef int     (*fn_method_get_param_count)(void *);
typedef void   *(*fn_method_get_param)(void *, int);
typedef char   *(*fn_type_get_name)(void *);
typedef void   *(*fn_object_get_class)(void *);
typedef char   *(*fn_class_get_name)(void *);
typedef void   *(*fn_image_class_count)(void *);
typedef void   *(*fn_image_get_class)(void *, int);
typedef char   *(*fn_image_get_name)(void *);

static fn_domain_get p_domain_get;
static fn_thread_attach p_attach;
static fn_class_from_name p_class_from_name;
static fn_class_get_method_from_name p_class_get_method_from_name;
static fn_runtime_invoke p_runtime_invoke;
static fn_string_new p_string_new;
static fn_object_new p_object_new;
static fn_value_box p_value_box;
static fn_array_new p_array_new;
static fn_class_get_methods p_class_get_methods;
static fn_method_get_name p_method_get_name;
static fn_method_get_param_count p_method_get_param_count;
static fn_method_get_param p_method_get_param;
static fn_type_get_name p_type_get_name;
static fn_object_get_class p_object_get_class;
static fn_class_get_name p_class_get_name;
static fn_image_class_count p_image_class_count;
static fn_image_get_class p_image_get_class;
static fn_image_get_name p_image_get_name;

static void *VXSym(const char *n) {
    static void *h = NULL;
    if (!h) {
        h = dlopen("/usr/lib/libil2cpp.dylib", RTLD_NOW);
        if (!h) h = dlopen("@rpath/libil2cpp.dylib", RTLD_NOW);
        if (!h) h = dlopen("@executable_path/Frameworks/libil2cpp.dylib", RTLD_NOW);
        if (!h) h = dlopen("Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOW);
    }
    void *p = h ? dlsym(h, n) : NULL;
    if (!p) p = dlsym(RTLD_DEFAULT, n);
    return p;
}

static BOOL VXBind(void) {
    if (p_runtime_invoke) return YES;
    p_domain_get = (fn_domain_get)VXSym("il2cpp_domain_get");
    p_attach = (fn_thread_attach)VXSym("il2cpp_thread_attach");
    p_class_from_name = (fn_class_from_name)VXSym("il2cpp_class_from_name");
    p_class_get_method_from_name = (fn_class_get_method_from_name)VXSym("il2cpp_class_get_method_from_name");
    p_runtime_invoke = (fn_runtime_invoke)VXSym("il2cpp_runtime_invoke");
    p_string_new = (fn_string_new)VXSym("il2cpp_string_new");
    p_object_new = (fn_object_new)VXSym("il2cpp_object_new");
    p_value_box = (fn_value_box)VXSym("il2cpp_value_box");
    p_array_new = (fn_array_new)VXSym("il2cpp_array_new");
    p_class_get_methods = (fn_class_get_methods)VXSym("il2cpp_class_get_methods");
    p_method_get_name = (fn_method_get_name)VXSym("il2cpp_method_get_name");
    p_method_get_param_count = (fn_method_get_param_count)VXSym("il2cpp_method_get_param_count");
    p_method_get_param = (fn_method_get_param)VXSym("il2cpp_method_get_param");
    p_type_get_name = (fn_type_get_name)VXSym("il2cpp_type_get_name");
    p_object_get_class = (fn_object_get_class)VXSym("il2cpp_object_get_class");
    p_class_get_name = (fn_class_get_name)VXSym("il2cpp_class_get_name");
    p_image_class_count = (fn_image_class_count)VXSym("il2cpp_image_class_count");
    p_image_get_class = (fn_image_get_class)VXSym("il2cpp_image_get_class");
    p_image_get_name = (fn_image_get_name)VXSym("il2cpp_image_get_name");
    return p_runtime_invoke != NULL;
}

static void *VXClass(const char *imagen, const char *ns, const char *nombre) {
    if (!p_domain_get || !p_class_from_name) return NULL;
    size_t n = 0;
    void **imgs = (void **)VXSym("il2cpp_domain_get_assemblies");
    if (!imgs) return NULL;
    void **lista = (void **)((void *(*)(void *, size_t *))imgs)(p_domain_get(), &n);
    if (!lista) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = ((void *(*)(void *))VXSym("il2cpp_assembly_get_image"))(lista[i]);
        if (!img) continue;
        const char *nom = p_image_get_name ? p_image_get_name(img) : NULL;
        if (!nom || !strstr(nom, imagen)) continue;
        void *c = p_class_from_name(img, ns, nombre);
        if (c) return c;
    }
    return NULL;
}

static void *VXMethod(void *cls, const char *nombre, int argc) {
    if (!cls || !p_class_get_method_from_name) return NULL;
    return p_class_get_method_from_name(cls, nombre, argc);
}

static void *VXFindPatchClass(int *total) {
    if (!p_image_class_count || !p_image_get_class) return NULL;
    size_t n = 0;
    void **lista = (void **)((void *(*)(void *, size_t *))VXSym("il2cpp_domain_get_assemblies"))(p_domain_get(), &n);
    if (!lista) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = ((void *(*)(void *))VXSym("il2cpp_assembly_get_image"))(lista[i]);
        if (!img) continue;
        const char *nom = p_image_get_name(img);
        if (!nom || !strstr(nom, "IFix.Core")) continue;
        int c = (int)(size_t)p_image_class_count(img);
        if (total) *total += c;
        for (int k = 0; k < c; k++) {
            void *cl = p_image_get_class(img, k);
            if (!cl) continue;
            char *nm = p_class_get_name(cl);
            if (nm && !strcmp(nm, "PatchManager")) return cl;
        }
    }
    return NULL;
}

static NSString *VXExc(void *exc) {
    if (!exc) return @"?";
    void *cl = p_object_get_class ? p_object_get_class(exc) : NULL;
    char *nm = (cl && p_class_get_name) ? p_class_get_name(cl) : NULL;
    return [NSString stringWithFormat:@"%s", nm ? nm : "?"];
}

#pragma mark - estado

typedef struct { BOOL esp, aim, silent, fovAim, diag; CGFloat fov; } VXState;
static VXState g;
static UIWindow *g_win;
static UILabel *g_status;
static NSString *g_patchPath;
static int g_armed = 0;
static int g_hideIdx = -1;
static int g_frame = 0;

static void VXSay(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_status) g_status.text = s;
    });
}

#pragma mark - cargar parche

static BOOL VXProbar(void *m, NSString *path, NSString *etiqueta) {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d || d.length < 1000) {
        VXSay([NSString stringWithFormat:@"%@ vacio", etiqueta]);
        return NO;
    }
    void *byteCls = VXClass("mscorlib", "System", "Byte");
    void *msCls = VXClass("mscorlib", "System.IO", "MemoryStream");
    if (!byteCls || !msCls) { VXSay(@"9 sin clases"); return NO; }

    void *arr = p_array_new(byteCls, (uint32_t)d.length);
    if (!arr) { VXSay(@"9 sin arreglo"); return NO; }
    memcpy((char *)arr + 0x20, d.bytes, d.length);

    void *ctor = NULL, *it = NULL, *mm;
    while ((mm = p_class_get_methods(msCls, &it))) {
        const char *nm = p_method_get_name(mm);
        if (!nm || strcmp(nm, ".ctor")) continue;
        if (p_method_get_param_count(mm) != 1) continue;
        char *t = p_type_get_name(p_method_get_param(mm, 0));
        if (t && strstr(t, "Byte[]")) { ctor = mm; break; }
    }
    if (!ctor) { VXSay(@"9 sin constructor"); return NO; }

    void *obj = p_object_new(msCls);
    void *a1[1] = { arr };
    void *exc = NULL;
    p_runtime_invoke(ctor, obj, a1, &exc);
    if (exc) { VXSay(@"9 stream"); return NO; }

    void *bCls = VXClass("mscorlib", "System", "Boolean");
    int uno = 1;
    void *bTrue = p_value_box(bCls, &uno);

    void *args[4] = { NULL, NULL, obj, bTrue };
    exc = NULL;
    p_runtime_invoke(m, NULL, args, &exc);
    if (exc) {
        VXSay([NSString stringWithFormat:@"9 %@ %@", etiqueta, VXExc(exc)]);
        return NO;
    }
    VXSay([NSString stringWithFormat:@"OK %@ b0", etiqueta]);
    return YES;
}

static BOOL VXCargar(void) {
    if (!VXBind()) { VXSay(@"1 sin il2cpp"); return NO; }

    void *dom = p_domain_get();
    if (dom && p_attach) p_attach(dom);

    void *cls = NULL;
    int total = 0;
    for (int i = 0; i < 15; i++) {
        cls = VXFindPatchClass(&total);
        if (cls) break;
        VXSay([NSString stringWithFormat:@"2 sin PatchManager | %d/15", i + 1]);
        [NSThread sleepForTimeInterval:1.0];
    }
    if (!cls) { VXSay(@"2 nunca aparecio"); return NO; }

    void *m = VXMethod(cls, "OptimizeLoad", 4);
    if (!m) m = VXMethod(cls, "Load", 2);
    if (!m) { VXSay(@"3 sin metodo"); return NO; }

    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *p1 = [doc stringByAppendingPathComponent:@"vx_nuestro.bytes"];

    NSString *bundle = [[NSBundle mainBundle] pathForResource:@"veexpatch" ofType:@"bin"];
    if (bundle) {
        NSData *d = [NSData dataWithContentsOfFile:bundle];
        if (d.length > 1000) {
            [d writeToFile:p1 atomically:YES];
            VXSay([NSString stringWithFormat:@"4 parche de la app %lu", (unsigned long)d.length]);
        }
    }

    if (VXProbar(m, p1, @"nuestro")) return YES;
    return NO;
}

#pragma mark - reset

static int VXPurga(BOOL soloGuest) {
    int n = 0;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *raices = @[
        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] ?: @"",
        [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject] ?: @""
    ];
    NSArray *claves = @[@"guest", @"garena", @"session", @"login", @"uuid", @"device", @"com.dts"];
    for (NSString *r in raices) {
        if (!r.length) continue;
        for (NSString *h in [fm contentsOfDirectoryAtPath:r error:nil]) {
            NSString *low = h.lowercaseString;
            BOOL pega = NO;
            for (NSString *k in claves) if ([low containsString:k]) { pega = YES; break; }
            if (!pega) continue;
            if ([fm removeItemAtPath:[r stringByAppendingPathComponent:h] error:nil]) n++;
        }
    }
    NSDictionary *q = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword };
    SecItemDelete((__bridge CFDictionaryRef)q);
    return n;
}

#pragma mark - ocultar

#if VX_HIDE
static uint32_t (*o_count)(void);
static const char *(*o_name)(uint32_t);
static uint32_t vx_count(void) {
    uint32_t n = o_count ? o_count() : 0;
    if (g_hideIdx < 0 || !n) return n;
    return n - 1;
}
static const char *vx_name(uint32_t i) {
    uint32_t n = o_count ? o_count() : 0;
    uint32_t idx = (g_hideIdx >= 0 && (int)i >= g_hideIdx) ? i + 1 : i;
    if ((int)idx >= (int)n) return NULL;
    return o_name ? o_name(idx) : NULL;
}
__attribute__((used, section("__DATA,__interpose")))
static const void *vx_pairs[][2] = {
    { (const void *)vx_count, (const void *)_dyld_image_count },
    { (const void *)vx_name,  (const void *)_dyld_get_image_name },
};
static void VXHideSelf(void) {
    o_count = (uint32_t (*)(void))dlsym(RTLD_DEFAULT, "_dyld_image_count");
    o_name = (const char *(*)(uint32_t))dlsym(RTLD_DEFAULT, "_dyld_get_image_name");
    uint32_t n = o_count ? o_count() : 0;
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = o_name ? o_name(i) : NULL;
        if (!nm) continue;
        if (strstr(nm, "veex") || strstr(nm, "Veex")) { g_hideIdx = (int)i; return; }
    }
}
#endif

#pragma mark - panel

@interface VXWindow : UIWindow
@end
@implementation VXWindow
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e {
    for (UIView *v in self.subviews)
        for (UIView *s in v.subviews)
            if (!s.hidden && CGRectContainsPoint(s.frame, p)) return YES;
    return NO;
}
@end

static UILabel *VXLabel(CGRect f, NSString *t, CGFloat size, UIColor *c) {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.text = t;
    l.textColor = c;
    l.font = [UIFont fontWithName:@"Menlo-Bold" size:size] ?: [UIFont boldSystemFontOfSize:size];
    l.backgroundColor = UIColor.clearColor;
    return l;
}

static UISwitch *VXSwitch(CGRect f, BOOL on, int tag, id t, SEL a) {
    UISwitch *s = [[UISwitch alloc] initWithFrame:f];
    s.on = on;
    s.tag = tag;
    s.onTintColor = [UIColor colorWithRed:0.15 green:0.9 blue:0.4 alpha:1];
    [s addTarget:t action:a forControlEvents:UIControlEventValueChanged];
    return s;
}

static UIButton *VXBtn(CGRect f, NSString *t, id target, SEL a) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f;
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12] ?: [UIFont boldSystemFontOfSize:12];
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    b.layer.cornerRadius = 8;
    [b addTarget:target action:a forControlEvents:UIControlEventTouchUpInside];
    return b;
}

@interface VeexPanel : UIView
@end

@implementation VeexPanel {
    UIView *_box;
    UILabel *_fovVal;
    CGPoint _last;
}

- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;

    _box = [[UIView alloc] initWithFrame:CGRectMake(16, 90, 300, 430)];
    _box.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.97];
    _box.layer.cornerRadius = 14;
    _box.layer.borderWidth = 1;
    _box.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    [self addSubview:_box];

    UILabel *t = VXLabel(CGRectMake(16, 12, 200, 24), @"Veex", 20, UIColor.whiteColor);
    [_box addSubview:t];
    [_box addSubview:VXLabel(CGRectMake(16, 36, 200, 14), @"BY LEVI", 10,
                             [UIColor colorWithWhite:1 alpha:0.45])];
    UILabel *tg = VXLabel(CGRectMake(16, 52, 240, 14), @"t.me/levibrouh", 10,
                          [UIColor colorWithRed:0.15 green:0.9 blue:0.4 alpha:1]);
    [_box addSubview:tg];

    UIButton *x = VXBtn(CGRectMake(258, 12, 30, 30), @"X", self, @selector(cerrar));
    [_box addSubview:x];

    [_box addSubview:VXLabel(CGRectMake(16, 78, 120, 16), @"AIM", 11,
                             [UIColor colorWithWhite:1 alpha:0.5])];
    [_box addSubview:VXLabel(CGRectMake(16, 100, 150, 18), @"Silent aim", 12, UIColor.whiteColor)];
    [_box addSubview:VXSwitch(CGRectMake(238, 96, 0, 0), NO, 2, self, @selector(cambio:))];
    [_box addSubview:VXLabel(CGRectMake(16, 132, 150, 18), @"Aim drag", 12, UIColor.whiteColor)];
    [_box addSubview:VXSwitch(CGRectMake(238, 128, 0, 0), NO, 1, self, @selector(cambio:))];
    [_box addSubview:VXLabel(CGRectMake(16, 164, 150, 18), @"Circulo FOV", 12, UIColor.whiteColor)];
    [_box addSubview:VXSwitch(CGRectMake(238, 160, 0, 0), YES, 3, self, @selector(cambio:))];

    _fovVal = VXLabel(CGRectMake(16, 192, 100, 18), @"FOV 120", 12, UIColor.whiteColor);
    [_box addSubview:_fovVal];
    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(110, 190, 170, 24)];
    sl.minimumValue = 30; sl.maximumValue = 400; sl.value = 120;
    sl.minimumTrackTintColor = [UIColor colorWithRed:0.15 green:0.9 blue:0.4 alpha:1];
    [sl addTarget:self action:@selector(fov:) forControlEvents:UIControlEventValueChanged];
    [_box addSubview:sl];

    [_box addSubview:VXLabel(CGRectMake(16, 224, 120, 16), @"ESP", 11,
                             [UIColor colorWithWhite:1 alpha:0.5])];
    NSArray *nombres = @[@"ESP", @"Caja", @"Linea", @"Salud", @"Nombre", @"Distancia"];
    for (int i = 0; i < 6; i++) {
        CGFloat y = 246 + i * 26;
        [_box addSubview:VXLabel(CGRectMake(16, y, 180, 18), nombres[i], 12, UIColor.whiteColor)];
        [_box addSubview:VXSwitch(CGRectMake(238, y - 4, 0, 0), i == 0, 10 + i, self, @selector(cambio:))];
    }

    [_box addSubview:VXBtn(CGRectMake(16, 408, 130, 34), @"CARGAR PARCHE", self, @selector(cargar))];
    [_box addSubview:VXBtn(CGRectMake(154, 408, 130, 34), @"RESET GUEST", self, @selector(reset))];

    g_status = VXLabel(CGRectMake(16, 448, 268, 60), @"listo", 9,
                       [UIColor colorWithRed:1 green:0.85 blue:0.3 alpha:1]);
    g_status.numberOfLines = 0;
    [_box addSubview:g_status];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [_box addGestureRecognizer:tap];
    return self;
}

- (void)tap:(UITapGestureRecognizer *)t {
    if (t.state != UIGestureRecognizerStateEnded) return;
    CGPoint p = [t locationInView:self];
    if (!CGRectContainsPoint(_box.frame, p)) _box.hidden = !_box.hidden;
}
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e { _last = [[t anyObject] locationInView:self]; }
- (void)touchesMoved:(NSSet *)t withEvent:(UIEvent *)e {
    CGPoint p = [[t anyObject] locationInView:self];
    _box.center = CGPointMake(_box.center.x + p.x - _last.x, _box.center.y + p.y - _last.y);
    _last = p;
}
- (void)cerrar { _box.hidden = YES; }

- (void)cambio:(UISwitch *)s {
    switch (s.tag) {
        case 1: g.aim = s.isOn; break;
        case 2: g.silent = s.isOn; break;
        case 3: g.fovAim = s.isOn; break;
        case 10: g.esp = s.isOn; break;
        default: break;
    }
}

- (void)fov:(UISlider *)s {
    g.fov = s.value;
    _fovVal.text = [NSString stringWithFormat:@"FOV %.0f", s.value];
}

- (void)cargar {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (VXCargar()) VXSay(@"parche cargado");
        else VXSay(@"no cargo");
    });
}

- (void)reset {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int n = VXPurga(YES);
        VXSay([NSString stringWithFormat:@"reset %d", n]);
        sleep(2);
        exit(0);
    });
}

- (void)tic {
    g_frame++;
    if (g.diag && g_status && g_frame % 30 == 0) {
        NSString *d = [[NSBundle mainBundle] pathForResource:@"veexpatch" ofType:@"bin"];
        NSDictionary *a = d ? [[NSFileManager defaultManager] attributesOfItemAtPath:d error:nil] : nil;
        g_status.text = [NSString stringWithFormat:@"hidden %d\nesp %d aim %d\nparche %llu",
                         g_hideIdx, g.esp, g.aim, a ? [a fileSize] : 0];
    }
}
@end

#pragma mark - arranque

static void VXInstall(void) {
    CGRect b = UIScreen.mainScreen.bounds;
    g_win = [[VXWindow alloc] initWithFrame:b];
    g_win.windowLevel = UIWindowLevelAlert;
    g_win.backgroundColor = UIColor.clearColor;
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = UIColor.clearColor;
    g_win.rootViewController = vc;

    VeexPanel *p = [[VeexPanel alloc] initWithFrame:b];
    [g_win addSubview:p];
    [g_win makeKeyAndVisible];

    CADisplayLink *l = [CADisplayLink displayLinkWithTarget:p selector:@selector(tic)];
    [l addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

__attribute__((constructor)) static void VXInit(void) {
#if VX_HIDE
    VXHideSelf();
#endif
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(14 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ VXInstall(); });
}
