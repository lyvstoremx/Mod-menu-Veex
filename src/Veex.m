// Veex.m
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <math.h>
#import <string.h>
#import <stdlib.h>

#define VX_HIDE 0
#define VX_PATCH_URL "https://github.com/lyvstoremx/Mod-menu-Veex/releases/download/base/Assembly-CSharp-patch.bytes"

#pragma mark - il2cpp

typedef void    *(*fn_domain_get)(void);
typedef void   **(*fn_domain_get_assemblies)(void *, size_t *);
typedef void    *(*fn_assembly_get_image)(void *);
typedef const char *(*fn_image_get_name)(void *);
typedef void    *(*fn_class_from_name)(void *, const char *, const char *);
typedef void    *(*fn_class_get_methods)(void *, void **);
typedef void    *(*fn_method_get_name)(void *);
typedef int      (*fn_method_get_param_count)(void *);
typedef void    *(*fn_method_get_param)(void *, int);
typedef char    *(*fn_type_get_name)(void *);
typedef void    *(*fn_runtime_invoke)(void *, void *, void **, void **);
typedef void    *(*fn_object_new)(void *);
typedef void    *(*fn_string_new)(const char *);
typedef void    *(*fn_value_box)(void *, void *);

static fn_domain_get                 p_dom;
static fn_domain_get_assemblies      p_asms;
static fn_assembly_get_image         p_img;
static fn_image_get_name             p_iname;
static fn_class_from_name            p_cfn;
static fn_class_get_methods          p_cmeth;
static fn_method_get_name            p_mname;
static fn_method_get_param_count     p_mpc;
static fn_method_get_param           p_mparam;
static fn_type_get_name              p_tname;
static fn_runtime_invoke             p_inv;
static fn_object_new                 p_onew;
static fn_string_new                 p_snew;
static fn_value_box                  p_box;

static int VXBind(void) {
    if (p_inv) return 1;
    void *h = dlopen("/usr/lib/libil2cpp.dylib", RTLD_NOW);
    if (!h) h = dlopen("@rpath/libil2cpp.dylib", RTLD_NOW);
    if (!h) h = dlopen("@executable_path/Frameworks/libil2cpp.dylib", RTLD_NOW);
    if (!h) h = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOW);
    if (!h) h = RTLD_DEFAULT;

    p_dom    = (fn_domain_get)dlsym(h, "il2cpp_domain_get");
    p_asms   = (fn_domain_get_assemblies)dlsym(h, "il2cpp_domain_get_assemblies");
    p_img    = (fn_assembly_get_image)dlsym(h, "il2cpp_assembly_get_image");
    p_iname  = (fn_image_get_name)dlsym(h, "il2cpp_image_get_name");
    p_cfn    = (fn_class_from_name)dlsym(h, "il2cpp_class_from_name");
    p_cmeth  = (fn_class_get_methods)dlsym(h, "il2cpp_class_get_methods");
    p_mname  = (fn_method_get_name)dlsym(h, "il2cpp_method_get_name");
    p_mpc    = (fn_method_get_param_count)dlsym(h, "il2cpp_method_get_param_count");
    p_mparam = (fn_method_get_param)dlsym(h, "il2cpp_method_get_param");
    p_tname  = (fn_type_get_name)dlsym(h, "il2cpp_type_get_name");
    p_inv    = (fn_runtime_invoke)dlsym(h, "il2cpp_runtime_invoke");
    p_onew   = (fn_object_new)dlsym(h, "il2cpp_object_new");
    p_snew   = (fn_string_new)dlsym(h, "il2cpp_string_new");
    p_box    = (fn_value_box)dlsym(h, "il2cpp_value_box");

    if (!p_dom || !p_asms || !p_img || !p_iname || !p_cfn || !p_cmeth ||
        !p_mname || !p_mpc || !p_mparam || !p_tname || !p_inv ||
        !p_onew || !p_snew || !p_box) return 0;
    return 1;
}

static void *VXImage(const char *needle) {
    if (!p_dom) return NULL;
    size_t n = 0;
    void **list = p_asms(p_dom(), &n);
    if (!list) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *im = p_img(list[i]);
        if (!im) continue;
        const char *nm = p_iname(im);
        if (nm && strstr(nm, needle)) return im;
    }
    return NULL;
}

static void *VXClass(const char *img, const char *ns, const char *name) {
    void *im = VXImage(img);
    if (!im) return NULL;
    return p_cfn(im, ns, name);
}

static void *VXMethod(void *cls, const char *name, int argc) {
    if (!cls) return NULL;
    void *it = NULL;
    while (1) {
        void *m = p_cmeth(cls, &it);
        if (!m) break;
        const char *nm = p_mname(m);
        if (!nm || strcmp(nm, name) != 0) continue;
        if (p_mpc(m) != argc) continue;
        return m;
    }
    return NULL;
}

#pragma mark - ui

static UIWindow *g_win;
static UILabel  *g_diag;
static UILabel  *g_title;
static int       g_armed;

@interface VXWindow : UIWindow
@end

@interface VeexPanel : UIView {
@public
    UIView   *_box;
    UIView   *_bubble;
    UIButton *_x;
    UISwitch *_sw[3];
    UISlider *_fov;
    UILabel  *_fovVal;
    CGRect    _btr[2];
    CGFloat   _bx, _by, _dx, _dy;
    BOOL      _open, _drag;
}
- (void)abrir;
- (void)cerrar;
@end

static void VXSay(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_diag) { g_diag.text = s; [g_diag sizeToFit]; }
    });
}

#pragma mark - parche

static NSString *VXFindPatch(void) {
    NSArray *dirs = @[
        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject],
        [[NSBundle mainBundle] bundlePath],
        [[NSBundle mainBundle] resourcePath]
    ];
    for (NSString *d in dirs) {
        if (!d) continue;
        NSString *p = [d stringByAppendingPathComponent:@"Assembly-CSharp-patch.bytes"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    }
    return nil;
}

static BOOL VXBajar(NSString *dst) {
    NSURL *u = [NSURL URLWithString:@(VX_PATCH_URL)];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:u];
    r.timeoutInterval = 40;
    __block NSData *out = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[NSURLSession sharedSession] dataTaskWithRequest:r
        completionHandler:^(NSData *d, NSURLResponse *resp, NSError *e) {
            if (!e && d.length > 1024) out = d;
            dispatch_semaphore_signal(sem);
        }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45 * NSEC_PER_SEC)));
    if (!out) return NO;
    return [out writeToFile:dst atomically:YES];
}

static void *VXNewStream(NSString *path, int *step) {
    *step = 0;
    void *fsCls  = VXClass("mscorlib", "System.IO", "FileStream");
    void *intCls = VXClass("mscorlib", "System", "Int32");
    if (!fsCls)  { *step = 1; return NULL; }
    if (!intCls) { *step = 2; return NULL; }

    void *obj = p_onew(fsCls);
    if (!obj) { *step = 3; return NULL; }

    void *ctor = NULL;
    void *it = NULL;
    while (1) {
        void *m = p_cmeth(fsCls, &it);
        if (!m) break;
        const char *nm = p_mname(m);
        if (!nm || strcmp(nm, ".ctor") != 0) continue;
        if (p_mpc(m) != 3) continue;
        char *a0 = p_tname(p_mparam(m, 0));
        char *a1 = p_tname(p_mparam(m, 1));
        char *a2 = p_tname(p_mparam(m, 2));
        if (a0 && a1 && a2 && strstr(a0, "String") &&
            strstr(a1, "FileMode") && strstr(a2, "FileAccess")) { ctor = m; break; }
    }
    if (!ctor) { *step = 4; return NULL; }

    void *sPath = p_snew([path UTF8String]);
    if (!sPath) { *step = 5; return NULL; }

    int mode = 3;   // FileMode.Open
    int acc  = 1;   // FileAccess.Read
    void *bMode = p_box(intCls, &mode);
    void *bAcc  = p_box(intCls, &acc);
    if (!bMode || !bAcc) { *step = 6; return NULL; }

    void *args[3] = { sPath, bMode, bAcc };
    void *exc = NULL;
    p_inv(ctor, obj, args, &exc);
    if (exc) { *step = 7; return NULL; }
    return obj;
}

static BOOL VXCargar(void) {
    if (!VXBind()) { VXSay(@"1 sin il2cpp"); return NO; }

    void *cls = VXClass("Assembly-CSharp", "IFix.Core", "PatchManager");
    if (!cls) { VXSay(@"2 sin PatchManager"); return NO; }

    void *m = VXMethod(cls, "OptimizeLoad", 4);
    if (!m) { VXSay(@"3 sin OptimizeLoad"); return NO; }

    NSString *p = VXFindPatch();
    if (!p) {
        VXSay(@"4 bajando parche...");
        NSString *dst = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                         stringByAppendingPathComponent:@"Assembly-CSharp-patch.bytes"];
        if (!VXBajar(dst)) { VXSay(@"4 no se pudo bajar"); return NO; }
        p = dst;
    }

    NSDictionary *at = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:nil];
    VXSay([NSString stringWithFormat:@"5 archivo %lu KB", (unsigned long)(at.fileSize / 1024)]);

    int step = 0;
    void *stream = VXNewStream(p, &step);
    if (!stream) {
        VXSay([NSString stringWithFormat:@"6 fallo stream (%d)", step]);
        return NO;
    }
    VXSay(@"7 stream listo");

    void *boolCls = VXClass("mscorlib", "System", "Boolean");
    if (!boolCls) { VXSay(@"8 sin Boolean"); return NO; }
    int t = 1;
    void *bTrue = p_box(boolCls, &t);

    void *args[4] = { NULL, NULL, stream, bTrue };
    void *exc = NULL;
    p_inv(m, NULL, args, &exc);
    if (exc) {
        char *tn = p_tname(cls);
        VXSay([NSString stringWithFormat:@"9 excepcion %s", tn ? tn : "?"]);
        return NO;
    }

    VXSay(@"parche cargado");
    return YES;
}

static void VXArmPatch(void) {
    if (g_armed) return;
    g_armed = 1;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (int i = 0; i < 20; i++) {
            if (VXCargar()) return;
            [NSThread sleepForTimeInterval:2.0];
        }
    });
}

static void VXResetGuest(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSArray *names = @[@"guest", @"Guest", @"garena_guest", @"login", @"session", @"uuid", @"device_id", @"prefs"];
        int n = 0;
        for (NSString *nm in names) {
            NSString *full = [doc stringByAppendingPathComponent:nm];
            if ([fm fileExistsAtPath:full]) { [fm removeItemAtPath:full error:nil]; n++; }
        }
        VXSay([NSString stringWithFormat:@"reset: %d borrados", n]);
    });
}

#pragma mark - panel

@implementation VeexPanel

- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = YES;

    _bx = 16; _by = 90;

    _bubble = [[UIView alloc] initWithFrame:CGRectMake(_bx, _by, 56, 56)];
    _bubble.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
    _bubble.layer.cornerRadius = 28;
    _bubble.layer.borderWidth = 1.5;
    _bubble.layer.borderColor = UIColor.greenColor.CGColor;
    [self addSubview:_bubble];

    UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(0, 14, 56, 28)];
    v.text = @"VX";
    v.textAlignment = NSTextAlignmentCenter;
    v.font = [UIFont boldSystemFontOfSize:20];
    v.textColor = UIColor.greenColor;
    [_bubble addSubview:v];

    _box = [[UIView alloc] initWithFrame:CGRectMake(_bx, _by, 250, 0)];
    _box.backgroundColor = [UIColor colorWithWhite:0 alpha:0.88];
    _box.layer.cornerRadius = 14;
    _box.layer.borderWidth = 1;
    _box.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    _box.clipsToBounds = YES;
    _box.hidden = YES;
    [self addSubview:_box];

    g_title = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 190, 20)];
    g_title.text = @"Veex";
    g_title.font = [UIFont boldSystemFontOfSize:16];
    g_title.textColor = UIColor.whiteColor;
    [_box addSubview:g_title];

    UILabel *by = [[UILabel alloc] initWithFrame:CGRectMake(14, 28, 190, 12)];
    by.text = @"BY LEVI";
    by.font = [UIFont systemFontOfSize:8];
    by.textColor = [UIColor colorWithWhite:1 alpha:0.45];
    [_box addSubview:by];

    _x = [UIButton buttonWithType:UIButtonTypeSystem];
    _x.frame = CGRectMake(214, 8, 28, 28);
    [_x setTitle:@"X" forState:UIControlStateNormal];
    [_x setTitleColor:UIColor.redColor forState:UIControlStateNormal];
    _x.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [_x addTarget:self action:@selector(cerrar) forControlEvents:UIControlEventTouchUpInside];
    [_box addSubview:_x];

    g_diag = [[UILabel alloc] initWithFrame:CGRectMake(14, 42, 222, 14)];
    g_diag.font = [UIFont systemFontOfSize:9];
    g_diag.textColor = UIColor.yellowColor;
    g_diag.numberOfLines = 0;
    g_diag.text = @"";
    [_box addSubview:g_diag];

    NSArray *names = @[@"AIM", @"ESP", @"FOV"];
    for (int i = 0; i < 3; i++) {
        CGFloat y = 62 + i * 26;
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, y, 170, 18)];
        l.text = names[i];
        l.font = [UIFont boldSystemFontOfSize:12];
        l.textColor = UIColor.whiteColor;
        [_box addSubview:l];

        UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectMake(184, y, 51, 31)];
        s.transform = CGAffineTransformMakeScale(0.72, 0.72);
        [_box addSubview:s];
        _sw[i] = s;
    }

    _fovVal = [[UILabel alloc] initWithFrame:CGRectMake(14, 140, 220, 14)];
    _fovVal.text = @"FOV 140";
    _fovVal.font = [UIFont systemFontOfSize:11];
    _fovVal.textColor = UIColor.lightGrayColor;
    [_box addSubview:_fovVal];

    _fov = [[UISlider alloc] initWithFrame:CGRectMake(14, 154, 222, 30)];
    _fov.minimumValue = 40;
    _fov.maximumValue = 300;
    _fov.value = 140;
    [_fov addTarget:self action:@selector(fovMueve:) forControlEvents:UIControlEventValueChanged];
    [_box addSubview:_fov];

    _btr[0] = CGRectMake(14, 192, 222, 32);
    _btr[1] = CGRectMake(14, 230, 222, 32);
    [self boton:@"CARGAR PARCHE" r:_btr[0] sel:@selector(parche)];
    [self boton:@"RESET GUEST" r:_btr[1] sel:@selector(reset)];

    UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self addGestureRecognizer:t];
    UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self addGestureRecognizer:p];

    return self;
}

- (void)boton:(NSString *)txt r:(CGRect)r sel:(SEL)s {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = r;
    [b setTitle:txt forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [b setTitleColor:UIColor.greenColor forState:UIControlStateNormal];
    b.layer.cornerRadius = 8;
    b.layer.borderWidth = 1;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside];
    [_box addSubview:b];
}

- (void)fovMueve:(UISlider *)s { _fovVal.text = [NSString stringWithFormat:@"FOV %d", (int)s.value]; }

- (void)parche {
    VXSay(@"cargando...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ VXCargar(); });
}

- (void)reset { VXResetGuest(); }

- (void)abrir {
    _open = YES;
    CGFloat w = MIN(250, self.bounds.size.width - 24);
    _box.frame = CGRectMake(_bx, _by, w, 272);
    _box.hidden = NO;
    _bubble.hidden = YES;
}

- (void)cerrar { _open = NO; _box.hidden = YES; _bubble.hidden = NO; }

- (void)tap:(UITapGestureRecognizer *)g {
    if (_open) return;
    CGPoint p = [g locationInView:self];
    if (CGRectContainsPoint(_bubble.frame, p)) [self abrir];
}

- (void)pan:(UIPanGestureRecognizer *)g {
    CGPoint p = [g locationInView:self];
    CGRect zona = _open ? _box.frame : _bubble.frame;
    if (g.state == UIGestureRecognizerStateBegan) {
        if (!CGRectContainsPoint(zona, p)) { _drag = NO; return; }
        _drag = YES;
        _dx = p.x - zona.origin.x;
        _dy = p.y - zona.origin.y;
        return;
    }
    if (!_drag) return;
    if (g.state == UIGestureRecognizerStateChanged) {
        _bx = p.x - _dx; _by = p.y - _dy;
        _bubble.frame = CGRectMake(_bx, _by, 56, 56);
        _box.frame = CGRectMake(_bx, _by, _box.frame.size.width, _box.frame.size.height);
        return;
    }
    _drag = NO;
}

@end

#pragma mark - instalar

static void VXInstall(void) {
    CGRect b = UIScreen.mainScreen.bounds;
    g_win = [[VXWindow alloc] initWithFrame:b];
    g_win.windowLevel = UIWindowLevelAlert + 1;
    g_win.backgroundColor = UIColor.clearColor;
    g_win.hidden = NO;

    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = UIColor.clearColor;
    g_win.rootViewController = vc;

    VeexPanel *panel = [[VeexPanel alloc] initWithFrame:b];
    [vc.view addSubview:panel];

    VXSay(@"listo");
}

__attribute__((constructor))
static void VXInit(void) {
#if VX_HIDE
    return;
#endif
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        VXInstall();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ VXArmPatch(); });
    });
}

@implementation VXWindow
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e {
    for (UIView *v in self.subviews)
        for (UIView *s in v.subviews)
            if (!s.hidden && CGRectContainsPoint(s.frame, p)) return YES;
    return NO;
}
@end
