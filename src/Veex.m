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

#pragma mark - il2cpp

typedef void    *(*fn_domain_get)(void);
typedef void    *(*fn_thread_attach)(void *);
typedef void   **(*fn_domain_get_assemblies)(void *, size_t *);
typedef void    *(*fn_assembly_get_image)(void *);
typedef const char *(*fn_image_get_name)(void *);
typedef size_t   (*fn_image_class_count)(void *);
typedef void    *(*fn_image_get_class)(void *, size_t);
typedef const char *(*fn_class_get_name)(void *);
typedef const char *(*fn_class_get_namespace)(void *);
typedef void    *(*fn_class_from_name)(void *, const char *, const char *);
typedef void    *(*fn_class_get_methods)(void *, void **);
typedef void    *(*fn_class_get_method_from_name)(void *, const char *, int);
typedef void    *(*fn_method_get_name)(void *);
typedef int      (*fn_method_get_param_count)(void *);
typedef void    *(*fn_method_get_param)(void *, int);
typedef char    *(*fn_type_get_name)(void *);
typedef void    *(*fn_runtime_invoke)(void *, void *, void **, void **);
typedef void    *(*fn_object_new)(void *);
typedef void    *(*fn_object_get_class)(void *);
typedef void    *(*fn_string_new)(const char *);
typedef uint16_t *(*fn_string_chars)(void *);
typedef void    *(*fn_value_box)(void *, void *);

static fn_domain_get                 p_dom;
static fn_thread_attach              p_attach;
static fn_domain_get_assemblies      p_asms;
static fn_assembly_get_image         p_img;
static fn_image_get_name             p_iname;
static fn_image_class_count          p_icount;
static fn_image_get_class            p_iget;
static fn_class_get_name             p_cname;
static fn_class_get_namespace        p_cns;
static fn_class_from_name            p_cfn;
static fn_class_get_methods          p_cmeth;
static fn_class_get_method_from_name p_cmn;
static fn_method_get_name            p_mname;
static fn_method_get_param_count     p_mpc;
static fn_method_get_param           p_mparam;
static fn_type_get_name              p_tname;
static fn_runtime_invoke             p_inv;
static fn_object_new                 p_onew;
static fn_object_get_class           p_ogc;
static fn_string_new                 p_snew;
static fn_string_chars               p_schars;
static fn_value_box                  p_box;

static const char *g_miss = NULL;

static void *VXS(void *h, const char *n) {
    void *p = dlsym(h, n);
    if (!p && !g_miss) g_miss = n;
    return p;
}

static int VXBind(void) {
    if (p_inv) return 1;
    void *h = dlopen("/usr/lib/libil2cpp.dylib", RTLD_NOW);
    if (!h) h = dlopen("@rpath/libil2cpp.dylib", RTLD_NOW);
    if (!h) h = dlopen("@executable_path/Frameworks/libil2cpp.dylib", RTLD_NOW);
    if (!h) h = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOW);
    if (!h) h = dlopen(NULL, RTLD_NOW);
    if (!h) { g_miss = "dlopen"; return 0; }

    p_dom    = (fn_domain_get)VXS(h, "il2cpp_domain_get");
    p_attach = (fn_thread_attach)VXS(h, "il2cpp_thread_attach");
    p_asms   = (fn_domain_get_assemblies)VXS(h, "il2cpp_domain_get_assemblies");
    p_img    = (fn_assembly_get_image)VXS(h, "il2cpp_assembly_get_image");
    p_iname  = (fn_image_get_name)VXS(h, "il2cpp_image_get_name");
    p_cname  = (fn_class_get_name)VXS(h, "il2cpp_class_get_name");
    p_cns    = (fn_class_get_namespace)VXS(h, "il2cpp_class_get_namespace");
    p_cfn    = (fn_class_from_name)VXS(h, "il2cpp_class_from_name");
    p_cmeth  = (fn_class_get_methods)VXS(h, "il2cpp_class_get_methods");
    p_cmn    = (fn_class_get_method_from_name)VXS(h, "il2cpp_class_get_method_from_name");
    p_mname  = (fn_method_get_name)VXS(h, "il2cpp_method_get_name");
    p_mpc    = (fn_method_get_param_count)VXS(h, "il2cpp_method_get_param_count");
    p_mparam = (fn_method_get_param)VXS(h, "il2cpp_method_get_param");
    p_tname  = (fn_type_get_name)VXS(h, "il2cpp_type_get_name");
    p_inv    = (fn_runtime_invoke)VXS(h, "il2cpp_runtime_invoke");
    p_onew   = (fn_object_new)VXS(h, "il2cpp_object_new");
    p_ogc    = (fn_object_get_class)VXS(h, "il2cpp_object_get_class");
    p_snew   = (fn_string_new)VXS(h, "il2cpp_string_new");
    p_schars = (fn_string_chars)VXS(h, "il2cpp_string_chars");
    p_box    = (fn_value_box)VXS(h, "il2cpp_value_box");

    p_icount = (fn_image_class_count)dlsym(h, "il2cpp_image_class_count");
    p_iget   = (fn_image_get_class)dlsym(h, "il2cpp_image_get_class");

    return g_miss ? 0 : 1;
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

static void *VXFindPatchClass(int *total) {
    if (total) *total = 0;
    if (!p_dom) return NULL;
    const char *imgs[] = {"IFix.Core", "Assembly-CSharp", "mscorlib"};
    for (int i = 0; i < 3; i++) {
        void *im = VXImage(imgs[i]);
        if (!im) continue;
        void *c = p_cfn(im, "IFix.Core", "PatchManager");
        if (c) { if (total) *total = 10 + i; return c; }
        void *c2 = p_cfn(im, "", "PatchManager");
        if (c2) { if (total) *total = 20 + i; return c2; }
        if (total) *total = i + 1;
    }
    return NULL;
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

static NSString *VXExcMsg(void *exc) {
    if (!exc) return @"?";
    if (p_ogc && p_cmn && p_inv && p_schars) {
        void *c = p_ogc(exc);
        void *m = p_cmn(c, "get_Message", 0);
        if (m) {
            void *e2 = NULL;
            void *r = p_inv(m, exc, NULL, &e2);
            if (r) {
                uint16_t *ch = p_schars(r);
                if (ch) {
                    char buf[200];
                    int i = 0;
                    for (; i < 190 && ch[i]; i++) buf[i] = (char)(ch[i] & 0xFF);
                    buf[i] = 0;
                    if (i > 0) return [NSString stringWithUTF8String:buf];
                }
            }
        }
    }
    return @"?";
}

#pragma mark - ui

static UIWindow *g_win;
static UITextView *g_log;
static int       g_armed;

@class VeexPanel;

@interface VXWindow : UIWindow
@end

static UIWindow *g_game;
static VeexPanel *g_panel;

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
- (BOOL)sobre:(CGPoint)p;
@end

static void VXSay(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_log) return;
        NSString *t = g_log.text;
        if (t.length > 3000) t = [t substringFromIndex:t.length - 2400];
        g_log.text = [NSString stringWithFormat:@"%@%@\n", t, s];
        NSRange r = NSMakeRange(g_log.text.length, 0);
        [g_log scrollRangeToVisible:r];
    });
}

#pragma mark - parche

static void *VXStream(NSString *path, NSString **why) {
    *why = nil;
    void *fileCls = VXClass("mscorlib", "System.IO", "File");
    void *msCls   = VXClass("mscorlib", "System.IO", "MemoryStream");
    if (!fileCls) { *why = @"sin File"; return NULL; }
    if (!msCls)   { *why = @"sin MemoryStream"; return NULL; }

    void *rab = VXMethod(fileCls, "ReadAllBytes", 1);
    if (!rab) { *why = @"sin ReadAllBytes"; return NULL; }

    void *exc = NULL;
    void *a1[1] = { p_snew([path UTF8String]) };
    void *arr = p_inv(rab, NULL, a1, &exc);
    if (exc) { *why = VXExcMsg(exc); return NULL; }
    if (!arr) { *why = @"sin bytes"; return NULL; }

    void *obj = p_onew(msCls);
    if (!obj) { *why = @"sin objeto"; return NULL; }

    void *ctor = VXMethod(msCls, ".ctor", 1);
    if (!ctor) { *why = @"sin ctor"; return NULL; }

    void *a2[1] = { arr };
    exc = NULL;
    p_inv(ctor, obj, a2, &exc);
    if (exc) { *why = VXExcMsg(exc); return NULL; }
    return obj;
}

static BOOL VXProbar(void *m, NSString *path, NSString *eti) {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d || d.length < 64) { VXSay([NSString stringWithFormat:@"%@ vacio", eti]); return NO; }
    const unsigned char *raw = d.bytes;
    VXSay([NSString stringWithFormat:@"%@ %lu b %02X%02X%02X%02X",
           eti, (unsigned long)d.length, raw[0], raw[1], raw[2], raw[3]]);

    void *boolCls = VXClass("mscorlib", "System", "Boolean");
    for (int k = 0; k < 2; k++) {
        NSString *why = nil;
        void *stream = VXStream(path, &why);
        if (!stream) { VXSay([NSString stringWithFormat:@"%@ stream: %@", eti, why]); return NO; }
        int t = k;
        void *b = boolCls ? p_box(boolCls, &t) : NULL;
        void *args[4] = { NULL, NULL, stream, b };
        void *exc = NULL;
        p_inv(m, NULL, args, &exc);
        if (!exc) { VXSay([NSString stringWithFormat:@"OK %@ b%d", eti, t]); VXSay(@"parche cargado"); return YES; }
        VXSay([NSString stringWithFormat:@"9 %@ b%d: %@", eti, t, VXExcMsg(exc)]);
    }
    return NO;
}

static BOOL VXCargar(void) {
    if (!VXBind()) { VXSay([NSString stringWithFormat:@"1 sin %s", g_miss ? g_miss : "?"]); return NO; }
    void *dom = p_dom();
    if (dom && p_attach) p_attach(dom);

    void *cls = VXFindPatchClass(NULL);
    if (!cls) { VXSay(@"2 sin PatchManager"); return NO; }

    void *m = VXMethod(cls, "OptimizeLoad", 4);
    if (!m) m = VXMethod(cls, "Load", 2);
    if (!m) m = VXMethod(cls, "Load", 1);
    if (!m) { VXSay(@"3 sin metodo"); return NO; }

    NSString *bp = [[NSBundle mainBundle] resourcePath];
    NSString *p1 = [bp stringByAppendingPathComponent:@"Assembly-CSharp-patch.bytes"];
    NSString *p2 = [bp stringByAppendingPathComponent:@"neutral.bytes"];
    NSFileManager *fm = [NSFileManager defaultManager];
    VXSay([NSString stringWithFormat:@"4 local %d %d",
           [fm fileExistsAtPath:p1] ? 1 : 0, [fm fileExistsAtPath:p2] ? 1 : 0]);

    if (VXProbar(m, p1, @"nuestro")) return YES;
    if (VXProbar(m, p2, @"neutral")) return YES;
    return NO;
}

static void VXResetGuest(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *raices = @[
            [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject],
            [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject]
        ];
        NSArray *claves = @[@"guest", @"account", @"session", @"login", @"uuid", @"device", @"garena", @"com.dts"];
        int n = 0;
        for (NSString *r in raices) {
            if (!r) continue;
            for (NSString *h in [fm contentsOfDirectoryAtPath:r error:nil]) {
                NSString *low = h.lowercaseString;
                BOOL pega = NO;
                for (NSString *k in claves) if ([low containsString:k]) { pega = YES; break; }
                if (!pega || [low hasSuffix:@".bytes"]) continue;
                if ([fm removeItemAtPath:[r stringByAppendingPathComponent:h] error:nil]) n++;
            }
        }
        NSString *pref = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject]
                          stringByAppendingPathComponent:@"Preferences/com.dts.freefireth.plist"];
        if ([fm fileExistsAtPath:pref] && [fm removeItemAtPath:pref error:nil]) n++;
        VXSay([NSString stringWithFormat:@"reset: %d | cierra el juego", n]);
    });
}

#pragma mark - panel

@implementation VeexPanel

- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if ([self sobre:p]) return [super hitTest:p withEvent:e];
    return nil;
}

- (BOOL)sobre:(CGPoint)p {
    if (_open) return CGRectContainsPoint(_box.frame, p);
    return CGRectContainsPoint(_bubble.frame, p);
}

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
    _box.backgroundColor = [UIColor colorWithWhite:0 alpha:0.92];
    _box.layer.cornerRadius = 14;
    _box.layer.borderWidth = 1;
    _box.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    _box.clipsToBounds = YES;
    _box.hidden = YES;
    [self addSubview:_box];

    UILabel *tt = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 190, 20)];
    tt.text = @"Veex";
    tt.font = [UIFont boldSystemFontOfSize:16];
    tt.textColor = UIColor.whiteColor;
    [_box addSubview:tt];

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

    NSArray *names = @[@"AIM", @"ESP", @"FOV"];
    for (int i = 0; i < 3; i++) {
        CGFloat y = 46 + i * 26;
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

    _fovVal = [[UILabel alloc] initWithFrame:CGRectMake(14, 126, 220, 14)];
    _fovVal.text = @"FOV 140";
    _fovVal.font = [UIFont systemFontOfSize:11];
    _fovVal.textColor = UIColor.lightGrayColor;
    [_box addSubview:_fovVal];

    _fov = [[UISlider alloc] initWithFrame:CGRectMake(14, 140, 222, 30)];
    _fov.minimumValue = 40;
    _fov.maximumValue = 300;
    _fov.value = 140;
    [_fov addTarget:self action:@selector(fovMueve:) forControlEvents:UIControlEventValueChanged];
    [_box addSubview:_fov];

    _btr[0] = CGRectMake(14, 176, 222, 32);
    _btr[1] = CGRectMake(14, 214, 222, 32);
    [self boton:@"CARGAR PARCHE" r:_btr[0] sel:@selector(parche)];
    [self boton:@"RESET GUEST" r:_btr[1] sel:@selector(reset)];

    g_log = [[UITextView alloc] initWithFrame:CGRectMake(10, 250, 230, 96)];
    g_log.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    g_log.textColor = UIColor.yellowColor;
    g_log.font = [UIFont systemFontOfSize:9];
    g_log.editable = NO;
    g_log.scrollEnabled = YES;
    g_log.textContainerInset = UIEdgeInsetsMake(3, 3, 3, 3);
    g_log.layer.cornerRadius = 6;
    [_box addSubview:g_log];

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
    if (g_log) g_log.text = @"";
    VXSay(@"cargando...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ VXCargar(); });
}

- (void)reset { VXResetGuest(); }

- (void)abrir {
    _open = YES;
    CGFloat w = MIN(250, self.bounds.size.width - 24);
    _box.frame = CGRectMake(_bx, _by, w, 358);
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
    UIWindow *w = nil;
    for (UIWindow *x in UIApplication.sharedApplication.windows) {
        if (x.rootViewController && !x.isHidden) { w = x; break; }
    }
    if (!w) w = UIApplication.sharedApplication.keyWindow;
    if (!w) return;
    g_game = w;
    g_win = w;

    g_panel = [[VeexPanel alloc] initWithFrame:w.bounds];
    g_panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [w addSubview:g_panel];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [g_panel abrir];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ VXCargar(); });
    });
}

__attribute__((constructor))
static void VXInit(void) {
#if VX_HIDE
    return;
#endif
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(14 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ VXInstall(); });
}

@implementation VXWindow
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e { return YES; }
@end
