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

typedef void   *(*fn_domain_get)(void);
typedef void    (*fn_thread_attach)(void *);
typedef void   *(*fn_class_from_name)(void *, const char *, const char *);
typedef void   *(*fn_class_get_method_from_name)(void *, const char *, int);
typedef void   *(*fn_runtime_invoke)(void *, void *, void **, void **);
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
typedef size_t  (*fn_image_class_count)(void *);
typedef void   *(*fn_image_get_class)(void *, int);
typedef char   *(*fn_image_get_name)(void *);
typedef void  **(*fn_get_assemblies)(void *, size_t *);
typedef void   *(*fn_assembly_get_image)(void *);

static fn_domain_get p_domain_get;
static fn_thread_attach p_attach;
static fn_class_from_name p_class_from_name;
static fn_class_get_method_from_name p_class_get_method_from_name;
static fn_runtime_invoke p_runtime_invoke;
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
static fn_get_assemblies p_get_assemblies;
static fn_assembly_get_image p_assembly_get_image;

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
    p_get_assemblies = (fn_get_assemblies)VXSym("il2cpp_domain_get_assemblies");
    p_assembly_get_image = (fn_assembly_get_image)VXSym("il2cpp_assembly_get_image");
    return p_runtime_invoke != NULL;
}

static void *VXClass(const char *imagen, const char *ns, const char *nombre) {
    if (!p_domain_get || !p_class_from_name || !p_get_assemblies || !p_assembly_get_image) return NULL;
    size_t n = 0;
    void **lista = p_get_assemblies(p_domain_get(), &n);
    if (!lista) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = p_assembly_get_image(lista[i]);
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

static void *VXFindPatchClass(void) {
    if (!p_image_class_count || !p_image_get_class || !p_get_assemblies) return NULL;
    size_t n = 0;
    void **lista = p_get_assemblies(p_domain_get(), &n);
    if (!lista) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = p_assembly_get_image(lista[i]);
        if (!img) continue;
        const char *nom = p_image_get_name ? p_image_get_name(img) : NULL;
        if (!nom || !strstr(nom, "IFix.Core")) continue;
        int c = (int)p_image_class_count(img);
        for (int k = 0; k < c; k++) {
            void *cl = p_image_get_class(img, k);
            if (!cl) continue;
            char *nm = p_class_get_name ? p_class_get_name(cl) : NULL;
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

static void VXSay(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_status) g_status.text = s;
    });
}

#pragma mark - cargar

static BOOL VXProbar(void *m, NSString *path, NSString *etiqueta) {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d || d.length < 1000) { VXSay([NSString stringWithFormat:@"%@ vacio", etiqueta]); return NO; }
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
    if (exc) { VXSay([NSString stringWithFormat:@"9 %@ %@", etiqueta, VXExc(exc)]); return NO; }
    VXSay([NSString stringWithFormat:@"OK %@ b0", etiqueta]);
    return YES;
}

static BOOL VXCargar(void) {
    if (!VXBind()) { VXSay(@"1 sin il2cpp"); return NO; }
    void *dom = p_domain_get();
    if (dom && p_attach) p_attach(dom);

    void *cls = NULL;
    for (int i = 0; i < 15; i++) {
        cls = VXFindPatchClass();
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
    return VXProbar(m, p1, @"nuestro");
}

#pragma mark - reset

static int VXPurga(void) {
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
    s.transform = CGAffineTransformMakeScale(0.78, 0.78);
    s.onTintColor = [UIColor colorWithRed:0.15 green:0.9 blue:0.4 alpha:1];
    [s addTarget:t action:a forControlEvents:UIControlEventValueChanged];
    return s;
}

static UIButton *VXBtn(CGRect f, NSString *t, id target, SEL a) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f;
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11] ?: [UIFont boldSystemFontOfSize:11];
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    b.layer.cornerRadius = 7;
    [b addTarget:target action:a forControlEvents:UIControlEventTouchUpInside];
    return b;
}

@interface VeexPanel : UIView
@end

@implementation VeexPanel {
    UIView *_box;
    UIScrollView *_scroll;
    UILabel *_fovVal;
    CGFloat _fila;
}

- (void)add:(UIView *)v { [_scroll addSubview:v]; }

- (void)fila:(NSString *)titulo tag:(int)tag on:(BOOL)on {
    [self add:VXLabel(CGRectMake(10, _fila, 200, 20), titulo, 11, UIColor.whiteColor)];
    [self add:VXSwitch(CGRectMake(250, _fila - 4, 0, 0), on, tag, self, @selector(cambio:))];
    _fila += 26;
}

- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;

    CGFloat alto = MIN(f.size.height - 20, 300);
    _box = [[UIView alloc] initWithFrame:CGRectMake(14, 10, 300, alto)];
    _box.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.97];
    _box.layer.cornerRadius = 12;
    _box.layer.borderWidth = 1;
    _box.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    [self addSubview:_box];

    UIView *cab = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 56)];
    cab.backgroundColor = UIColor.clearColor;
    [_box addSubview:cab];
    [cab addSubview:VXLabel(CGRectMake(12, 6, 180, 22), @"Veex", 18, UIColor.whiteColor)];
    [cab addSubview:VXLabel(CGRectMake(12, 26, 180, 12), @"BY LEVI", 9,
                            [UIColor colorWithWhite:1 alpha:0.45])];
    [cab addSubview:VXLabel(CGRectMake(12, 39, 200, 12), @"t.me/levibrouh", 9,
                            [UIColor colorWithRed:0.15 green:0.9 blue:0.4 alpha:1])];
    [cab addSubview:VXBtn(CGRectMake(258, 8, 34, 34), @"X", self, @selector(cerrar))];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(arrastrar:)];
    pan.cancelsTouchesInView = NO;
    [cab addGestureRecognizer:pan];

    CGFloat altoScroll = alto - 56 - 44;
    _scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 56, 300, altoScroll)];
    _scroll.contentSize = CGSizeMake(300, 400);
    _scroll.showsVerticalScrollIndicator = NO;
    _scroll.alwaysBounceVertical = YES;
    [_box addSubview:_scroll];

    _fila = 4;
    [self add:VXLabel(CGRectMake(10, _fila, 120, 14), @"AIM", 9,
                      [UIColor colorWithWhite:1 alpha:0.5])];
    _fila += 18;
    [self fila:@"Silent aim" tag:2 on:NO];
    [self fila:@"Aim drag" tag:1 on:NO];
    [self fila:@"Circulo FOV" tag:3 on:YES];

    _fovVal = VXLabel(CGRectMake(10, _fila, 70, 18), @"FOV 120", 11, UIColor.whiteColor);
    [self add:_fovVal];
    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(80, _fila, 190, 22)];
    sl.minimumValue = 30; sl.maximumValue = 400; sl.value = 120;
    sl.minimumTrackTintColor = [UIColor colorWithRed:0.15 green:0.9 blue:0.4 alpha:1];
    [sl addTarget:self action:@selector(fov:) forControlEvents:UIControlEventValueChanged];
    [self add:sl];
    _fila += 30;

    [self add:VXLabel(CGRectMake(10, _fila, 120, 14), @"ESP", 9,
                      [UIColor colorWithWhite:1 alpha:0.5])];
    _fila += 18;
    NSArray *nombres = @[@"ESP", @"Caja", @"Linea", @"Salud", @"Nombre", @"Distancia"];
    for (int i = 0; i < 6; i++) [self fila:nombres[i] tag:10 + i on:(i == 0)];
    _scroll.contentSize = CGSizeMake(300, _fila + 10);

    [_box addSubview:VXBtn(CGRectMake(10, alto - 38, 140, 30), @"CARGAR PARCHE", self, @selector(cargar))];
    [_box addSubview:VXBtn(CGRectMake(156, alto - 38, 134, 30), @"RESET GUEST", self, @selector(reset))];

    g_status = VXLabel(CGRectMake(0, 0, 0, 0), @"", 9,
                       [UIColor colorWithRed:1 green:0.85 blue:0.3 alpha:1]);
    g_status.numberOfLines = 0;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    tap.cancelsTouchesInView = NO;
    [cab addGestureRecognizer:tap];
    return self;
}

- (void)tap:(UITapGestureRecognizer *)t { if (t.state == UIGestureRecognizerStateEnded) _box.hidden = YES; }

- (void)arrastrar:(UIPanGestureRecognizer *)p {
    CGPoint d = [p translationInView:self];
    _box.center = CGPointMake(_box.center.x + d.x, _box.center.y + d.y);
    [p setTranslation:CGPointZero inView:self];
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
        int n = VXPurga();
        VXSay([NSString stringWithFormat:@"reset %d", n]);
        sleep(2);
        exit(0);
    });
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
    [g_win addSubview:[[VeexPanel alloc] initWithFrame:b]];
    [g_win makeKeyAndVisible];
}

__attribute__((constructor)) static void VXInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(14 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ VXInstall(); });
}
