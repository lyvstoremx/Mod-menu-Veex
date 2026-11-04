#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <string.h>
#import <unistd.h>

#define VX_HIDE 0

@class VXWindow;
@class VeexPanel;

static void VXArmPatch(void);

static struct { BOOL esp, aim, fire, visOnly; CGFloat fov; } g;
static VXWindow *g_win;
static UIView *g_draw;
static UILabel *g_diag;
static UILabel *g_title;

static void VXSay(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_diag) g_diag.text = s;
        if (g_title) g_title.text = s;
    });
}

#pragma mark - panel

@interface VXWindow : UIWindow
@property (nonatomic, assign) VeexPanel *panel;
@end

@implementation VXWindow
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e {
    if (self.panel) return [self.panel pointInside:p withEvent:e];
    return NO;
}
@end

@interface VeexDraw : UIView
@end

@implementation VeexDraw
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e { return NO; }
- (void)drawRect:(CGRect)r {
    if (!g.esp) return;
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(c, UIColor.greenColor.CGColor);
    CGContextSetLineWidth(c, 1.4);
    CGFloat rad = g.fov / 2.0;
    CGPoint m = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGContextStrokeEllipseInRect(c, CGRectMake(m.x - rad, m.y - rad, rad * 2, rad * 2));
}
@end

@interface VeexPanel : UIView
@property (nonatomic, assign) BOOL open;
- (void)tick:(CADisplayLink *)l;
@end

@implementation VeexPanel {
    UIView *_box;
    UISlider *_fov;
    UILabel *_fovVal;
    UISwitch *_sw[4];
    CGRect _swr[4];
    CGRect _btr[2];
    CGRect _slr;
    CGFloat _bx, _by;
    BOOL _drag, _moved, _inBox, _sliding;
    CGPoint _off;
}

- (instancetype)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.multipleTouchEnabled = NO;
    _bx = f.size.width - 76;
    _by = f.size.height * 0.35;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [self addGestureRecognizer:tap];
    [self buildBox];
    return self;
}

- (void)buildBox {
    _box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 366)];
    _box.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.94];
    _box.layer.cornerRadius = 14;
    _box.layer.borderWidth = 1;
    _box.layer.borderColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:0.5].CGColor;
    _box.userInteractionEnabled = NO;
    _box.hidden = YES;
    [self addSubview:_box];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 220, 20)];
    t.text = @"VEE.X  1.132";
    t.font = [UIFont boldSystemFontOfSize:13];
    t.textColor = UIColor.greenColor;
    t.adjustsFontSizeToFitWidth = YES;
    [_box addSubview:t];
    g_title = t;

    NSArray *nombres = @[ @"ESP", @"AIM", @"VISIBLE", @"AUTO FIRE" ];
    for (int i = 0; i < 4; i++) {
        CGFloat y = 38 + i * 34;
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, y + 4, 150, 20)];
        l.text = nombres[i];
        l.font = [UIFont systemFontOfSize:13];
        l.textColor = UIColor.whiteColor;
        [_box addSubview:l];

        UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectMake(184, y, 51, 31)];
        s.on = NO;
        s.transform = CGAffineTransformMakeScale(0.78, 0.78);
        s.userInteractionEnabled = NO;
        [_box addSubview:s];
        _sw[i] = s;
        _swr[i] = CGRectMake(180, y - 3, 56, 37);
    }

    _fovVal = [[UILabel alloc] initWithFrame:CGRectMake(14, 178, 220, 16)];
    _fovVal.text = @"FOV 140";
    _fovVal.font = [UIFont systemFontOfSize:12];
    _fovVal.textColor = UIColor.lightGrayColor;
    [_box addSubview:_fovVal];

    _fov = [[UISlider alloc] initWithFrame:CGRectMake(14, 196, 222, 30)];
    _fov.minimumValue = 40;
    _fov.maximumValue = 300;
    _fov.value = 140;
    _fov.userInteractionEnabled = NO;
    g.fov = 140;
    [_box addSubview:_fov];
    _slr = CGRectMake(10, 194, 230, 34);

    _btr[0] = CGRectMake(14, 234, 222, 32);
    _btr[1] = CGRectMake(14, 272, 222, 32);
    [self boton:@"CARGAR PARCHE" r:_btr[0]];
    [self boton:@"RESET GUEST" r:_btr[1]];

    g_diag = [[UILabel alloc] initWithFrame:CGRectMake(10, 310, 230, 44)];
    g_diag.font = [UIFont systemFontOfSize:9];
    g_diag.textColor = UIColor.yellowColor;
    g_diag.numberOfLines = 0;
    [_box addSubview:g_diag];
}

- (void)boton:(NSString *)txt r:(CGRect)r {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = r;
    [b setTitle:txt forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [b setTitleColor:UIColor.greenColor forState:UIControlStateNormal];
    b.layer.cornerRadius = 8;
    b.layer.borderWidth = 1;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    b.userInteractionEnabled = NO;
    [_box addSubview:b];
}

- (CGRect)bubble { return CGRectMake(_bx, _by, 56, 56); }

- (CGPoint)enCaja:(CGPoint)p { return [_box convertPoint:p fromView:self]; }

- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e {
    if (CGRectContainsPoint(self.bubble, p)) return YES;
    if (self.open && CGRectContainsPoint(_box.frame, p)) return YES;
    return NO;
}

- (void)layoutBox {
    CGFloat w = _box.frame.size.width, h = _box.frame.size.height;
    CGFloat x = _bx + 28 - w / 2;
    CGFloat y = _by - h - 10;
    if (y < 44) y = _by + 66;
    if (x < 6) x = 6;
    if (x + w > self.bounds.size.width - 6) x = self.bounds.size.width - w - 6;
    _box.frame = CGRectMake(x, y, w, h);
}

- (void)onTap:(UITapGestureRecognizer *)t {
    CGPoint p = [t locationInView:self];
    if (CGRectContainsPoint(self.bubble, p)) { [self setOpen:!self.open]; return; }
    if (!self.open || !CGRectContainsPoint(_box.frame, p)) { [self setOpen:NO]; return; }
    [self tocaEn:[self enCaja:p]];
}

- (void)touchesBegan:(NSSet *)_t withEvent:(UIEvent *)e {
    CGPoint p = [[_t anyObject] locationInView:self];
    _moved = NO; _sliding = NO; _inBox = NO;
    if (!CGRectContainsPoint(self.bubble, p)) return;
    _drag = YES;
    _off = CGPointMake(p.x - _bx, p.y - _by);
}

- (void)touchesMoved:(NSSet *)_t withEvent:(UIEvent *)e {
    if (!_drag) return;
    CGPoint p = [[_t anyObject] locationInView:self];
    _bx = MAX(6, MIN(p.x - _off.x, self.bounds.size.width - 62));
    _by = MAX(44, MIN(p.y - _off.y, self.bounds.size.height - 100));
    _moved = YES;
    [self setNeedsDisplay];
    if (self.open) [self layoutBox];
}

- (void)touchesEnded:(NSSet *)_t withEvent:(UIEvent *)e {
    if (_drag && _moved) { _drag = NO; return; }
    _drag = NO;
    CGPoint p = [[_t anyObject] locationInView:self];
    if (CGRectContainsPoint(self.bubble, p)) { [self setOpen:!self.open]; return; }
    if (!self.open || !CGRectContainsPoint(_box.frame, p)) { [self setOpen:NO]; return; }
    [self tocaEn:[self enCaja:p]];
}

- (void)tocaEn:(CGPoint)q {
    for (int i = 0; i < 4; i++) {
        if (CGRectContainsPoint(_swr[i], q)) {
            _sw[i].on = !_sw[i].on;
            [self aplica:i];
            return;
        }
    }
    if (CGRectContainsPoint(_btr[0], q)) { [self doPatch]; return; }
    if (CGRectContainsPoint(_btr[1], q)) { [self doReset]; return; }
    if (CGRectContainsPoint(_slr, q)) { [self desliza:q]; }
}

- (void)desliza:(CGPoint)q {
    CGFloat t = (q.x - _slr.origin.x) / _slr.size.width;
    t = MAX(0, MIN(1, t));
    _fov.value = 40 + t * 260;
    g.fov = _fov.value;
    _fovVal.text = [NSString stringWithFormat:@"FOV %.0f", g.fov];
    if (g_draw) [g_draw setNeedsDisplay];
}

- (void)aplica:(int)i {
    if (i == 0) { g.esp = _sw[0].on; if (g_draw) [g_draw setNeedsDisplay]; }
    if (i == 1) g.aim = _sw[1].on;
    if (i == 2) g.visOnly = _sw[2].on;
    if (i == 3) g.fire = _sw[3].on;
}

- (void)setOpen:(BOOL)o {
    _open = o;
    _box.hidden = !o;
    if (o) [self layoutBox];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bubble;
    CGContextSetFillColorWithColor(c, [UIColor colorWithWhite:0.06 alpha:0.9].CGColor);
    CGContextFillEllipseInRect(c, b);
    CGContextSetStrokeColorWithColor(c, [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:0.9].CGColor);
    CGContextSetLineWidth(c, 1.6);
    CGContextStrokeEllipseInRect(c, b);

    UIFont *f = [UIFont boldSystemFontOfSize:22];
    NSDictionary *at = @{ NSFontAttributeName: f, NSForegroundColorAttributeName: UIColor.greenColor };
    CGSize s = [@"V" sizeWithAttributes:at];
    [@"V" drawAtPoint:CGPointMake(CGRectGetMidX(b) - s.width / 2, CGRectGetMidY(b) - s.height / 2)
       withAttributes:at];
}

#pragma mark - acciones

- (void)doPatch {
    VXSay(@"cargando...");
    VXArmPatch();
}

- (void)doReset {
    VXSay(@"reseteando...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary *q1 = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword };
        SecItemDelete((__bridge CFDictionaryRef)q1);
        NSDictionary *q2 = @{ (__bridge id)kSecClass: (__bridge id)kSecClassInternetPassword };
        SecItemDelete((__bridge CFDictionaryRef)q2);

        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *home = NSHomeDirectory();
        NSArray *zonas = @[ @"Library/Preferences",
                            @"Library/Caches/com.dts.freefireth",
                            @"Library/Application Support" ];
        int borrados = 0;
        for (NSString *z in zonas) {
            NSString *d = [home stringByAppendingPathComponent:z];
            for (NSString *h in [fm contentsOfDirectoryAtPath:d error:nil]) {
                if ([fm removeItemAtPath:[d stringByAppendingPathComponent:h] error:nil]) borrados++;
            }
        }
        VXSay([NSString stringWithFormat:@"reset: %d\nreiniciando...", borrados]);
        [NSThread sleepForTimeInterval:1.5];
        dispatch_async(dispatch_get_main_queue(), ^{ exit(0); });
    });
}

- (void)tick:(CADisplayLink *)l { if (g.esp && g_draw) [g_draw setNeedsDisplay]; }

@end

#pragma mark - ifix

typedef void *(*fn_domain_get)(void);
typedef void *(*fn_get_assemblies)(void *, size_t *);
typedef void *(*fn_assembly_get_image)(void *);
typedef const char *(*fn_image_get_name)(void *);
typedef void *(*fn_class_from_name)(void *, const char *, const char *);
typedef void *(*fn_class_get_method_from_name)(void *, const char *, int);
typedef void *(*fn_runtime_invoke)(void *, void *, void **, void **);
typedef void *(*fn_array_new)(void *, size_t);

static void *VXS(const char *n) { return dlsym(RTLD_DEFAULT, n); }

static NSString *VXLoadPatch(void) {
    fn_domain_get dg = VXS("il2cpp_domain_get");
    fn_get_assemblies ga = VXS("il2cpp_domain_get_assemblies");
    fn_assembly_get_image ai = VXS("il2cpp_assembly_get_image");
    fn_image_get_name inm = VXS("il2cpp_image_get_name");
    fn_class_from_name cf = VXS("il2cpp_class_from_name");
    fn_class_get_method_from_name cm = VXS("il2cpp_class_get_method_from_name");
    fn_runtime_invoke ri = VXS("il2cpp_runtime_invoke");
    fn_array_new an = VXS("il2cpp_array_new");
    if (!dg || !ga || !ai || !inm || !cf || !cm || !ri || !an) return @"1 sin simbolos";

    void *dom = dg();
    if (!dom) return @"2 sin dominio";
    size_t n = 0;
    void **as = ga(dom, &n);
    if (!as || n == 0) return @"3 sin ensamblados";

    void *img = NULL, *msc = NULL;
    for (size_t i = 0; i < n; i++) {
        void *im = ai(as[i]);
        const char *nm = im ? inm(im) : NULL;
        if (!nm) continue;
        if (strstr(nm, "IFix.Core")) img = im;
        if (strstr(nm, "mscorlib")) msc = im;
    }
    if (!img) return [NSString stringWithFormat:@"4 sin IFix (de %zu)", n];
    if (!msc) return @"5 sin mscorlib";

    void *cls = cf(img, "IFix.Core", "PatchManager");
    if (!cls) return @"6 sin PatchManager";

    NSString *dst = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Assembly-CSharp.patch.bytes"];
    NSData *d = [NSData dataWithContentsOfFile:dst];
    if (!d) {
        NSString *src = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"veexpatch.bin"];
        d = [NSData dataWithContentsOfFile:src];
        if (!d) return @"7 sin archivo";
        [d writeToFile:dst atomically:YES];
    }

    void *byteCls = cf(msc, "System", "Byte");
    if (!byteCls) return @"8 sin Byte";

    void *m = cm(cls, "Load", 1);
    if (!m) {
        m = cm(cls, "Load", 0);
        if (!m) return @"9 sin Load";
        void *exc0 = NULL;
        ri(m, NULL, NULL, &exc0);
        return exc0 ? @"9b excepcion" : @"ok";
    }

    void *arr = an(byteCls, d.length);
    if (!arr) return @"10 sin arreglo";
    memcpy((char *)arr + 0x20, d.bytes, d.length);

    void *exc = NULL;
    void *args[1] = { arr };
    ri(m, NULL, args, &exc);
    return exc ? @"11 excepcion al cargar" : @"ok";
}

static void VXArmPatch(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (int i = 0; i < 3; i++) {
            NSString *r = VXLoadPatch();
            VXSay([NSString stringWithFormat:@"carga: %@", r]);
            if ([r isEqualToString:@"ok"]) return;
            [NSThread sleepForTimeInterval:2.0];
        }
    });
}

#pragma mark - instalar

static void VXInstall(void) {
    CGRect b = UIScreen.mainScreen.bounds;
    g_win = [[VXWindow alloc] initWithFrame:b];
    g_win.windowLevel = UIWindowLevelAlert;
    g_win.backgroundColor = UIColor.clearColor;

    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = UIColor.clearColor;
    vc.view.userInteractionEnabled = NO;
    g_win.rootViewController = vc;

    VeexPanel *p = [[VeexPanel alloc] initWithFrame:b];
    [g_win addSubview:p];
    g_win.panel = p;

    VeexDraw *d = [[VeexDraw alloc] initWithFrame:b];
    d.backgroundColor = UIColor.clearColor;
    d.userInteractionEnabled = NO;
    [g_win addSubview:d];
    g_draw = d;

    [g_win makeKeyAndVisible];

    CADisplayLink *l = [CADisplayLink displayLinkWithTarget:p selector:@selector(tick:)];
    [l addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

__attribute__((constructor)) static void VXInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ VXInstall(); });
}
