#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#include <string.h>
#include <unistd.h>

#if 0
static uint32_t (*orig_count)(void);
static const char *(*orig_name)(uint32_t);
static int g_hideIdx = -1;
static BOOL g_ready = NO;
static int g_busy = 0;

static void VXOrig(void) {
    if (g_ready || g_busy) return;
    g_busy = 1;
    if (!orig_count) orig_count = (uint32_t (*)(void))dlsym(RTLD_DEFAULT, "_dyld_image_count");
    if (!orig_name) orig_name = (const char *(*)(uint32_t))dlsym(RTLD_DEFAULT, "_dyld_get_image_name");
    g_ready = (orig_count != NULL && orig_name != NULL);
    g_busy = 0;
}
__attribute__((constructor(101))) static void VXOrigEarly(void) { VXOrig(); }
static uint32_t vx_count(void) { VXOrig(); return orig_count ? orig_count() : 0; }
static const char *vx_name(uint32_t i) {
    VXOrig();
    if (!orig_name) return NULL;
    if (g_hideIdx >= 0 && (int)i == g_hideIdx) return "";
    return orig_name(i);
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
}
#else
static void VXHideSelf(void) {}
#endif

static struct { BOOL esp, aim, fire, visOnly; CGFloat fov; } g;
static UIWindow *g_win;
static UIView *g_draw;
static UILabel *g_diag;
static NSString *g_patch;

static void VXSay(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{ if (g_diag) g_diag.text = s; });
}

static BOOL VXIsPatch(NSString *p) {
    NSString *n = p.lastPathComponent.lowercaseString;
    if ([n containsString:@"assembly-csharp"] || [n containsString:@"remote_patch"] || [n containsString:@"-patch"]) return YES;
    NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:nil];
    return a && [a fileSize] > 20000 && [a fileSize] < 40000000;
}

static NSString *VXHead(NSString *p) {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:p];
    if (!fh) return nil;
    NSData *d = [fh readDataOfLength:8];
    [fh closeFile];
    return [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding];
}

static NSString *VXFindPatch(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *dirs = [NSMutableArray array];
    NSArray *bases = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    [dirs addObjectsFromArray:bases];
    NSString *lib = [bases.firstObject stringByDeletingLastPathComponent];
    [dirs addObject:[lib stringByAppendingPathComponent:@"Library/Caches"]];
    [dirs addObject:lib];
    for (NSString *d in dirs) {
        NSDirectoryEnumerator *e = [fm enumeratorAtPath:d];
        for (NSString *f in e) {
            NSString *full = [d stringByAppendingPathComponent:f];
            if (!VXIsPatch(full)) continue;
            NSString *magic = VXHead(full);
            if ([magic hasPrefix:@"UnityFS"] || [magic hasPrefix:@"IFix"] || [magic hasPrefix:@"MZ"]) return full;
        }
    }
    return nil;
}

static void VXUpload(NSString *path) {
    if (!path) { VXSay(@"sin parche"); return; }
    NSData *body = [NSData dataWithContentsOfFile:path];
    if (!body) { VXSay(@"no leí"); return; }
    VXSay([NSString stringWithFormat:@"subiendo %lu KB", (unsigned long)(body.length / 1024)]);

    NSString *b = @"----veexboundary";
    NSMutableData *d = [NSMutableData data];
    [d appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"reqtype\"\r\n\r\nfileupload\r\n", b] dataUsingEncoding:NSUTF8StringEncoding]];
    [d appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"fileToUpload\"; filename=\"patch.bytes\"\r\nContent-Type: application/octet-stream\r\n\r\n", b] dataUsingEncoding:NSUTF8StringEncoding]];
    [d appendData:body];
    [d appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", b] dataUsingEncoding:NSUTF8StringEncoding]];

    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://catbox.moe/user/api.php"]];
    r.HTTPMethod = @"POST";
    [r setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", b] forHTTPHeaderField:@"Content-Type"];
    r.HTTPBody = d;
    r.timeoutInterval = 180;

    [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *rd, NSURLResponse *resp, NSError *err) {
        NSString *txt = rd ? [[NSString alloc] initWithData:rd encoding:NSUTF8StringEncoding] : nil;
        txt = [txt stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (txt.length && [txt hasPrefix:@"http"]) VXSay(txt);
        else VXSay([NSString stringWithFormat:@"fallo %ld", (long)((NSHTTPURLResponse *)resp).statusCode]);
    }] resume];
}

static int VXKeychainPurge(void) {
    NSArray *tokens = @[@"garena", @"freefire", @"com.dts", @"guest", @"dts"];
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
            NSString *blob = [[acct stringByAppendingString:svc] lowercaseString];
            BOOL hit = NO;
            for (NSString *t in tokens) { if ([blob containsString:t]) { hit = YES; break; } }
            if (!hit) continue;
            NSMutableDictionary *dd = [NSMutableDictionary dictionaryWithDictionary:it];
            [dd setObject:cls forKey:(__bridge id)kSecClass];
            if (SecItemDelete((__bridge CFDictionaryRef)dd) == errSecSuccess) removed++;
        }
    }
    return removed;
}

@interface VXDraw : UIView
@end
@implementation VXDraw
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(c, [UIColor colorWithRed:0 green:1 blue:0.4 alpha:0.8].CGColor);
    CGContextSetLineWidth(c, 1.5);
    CGPoint m = CGPointMake(r.size.width / 2, r.size.height / 2);
    CGContextStrokeEllipseInRect(c, CGRectMake(m.x - g.fov, m.y - g.fov, g.fov * 2, g.fov * 2));
}
@end

#pragma mark - panel

@interface VeexPanel : UIView
@property (nonatomic, strong) UIView *box;
@property (nonatomic, strong) UIView *bub;
@property (nonatomic, strong) CADisplayLink *link;
@end

@implementation VeexPanel {
    CGPoint _pos;
}

- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        g.fov = 130;
        self.backgroundColor = UIColor.clearColor;
        _pos = CGPointMake(14, 130);

        _bub = [[UIView alloc] initWithFrame:CGRectMake(_pos.x, _pos.y, 46, 46)];
        _bub.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.22];
        _bub.layer.cornerRadius = 23;
        _bub.layer.borderWidth = 1.5;
        _bub.layer.borderColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.9].CGColor;
        UILabel *bl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 46, 46)];
        bl.text = @"VX";
        bl.textAlignment = NSTextAlignmentCenter;
        bl.textColor = UIColor.whiteColor;
        bl.font = [UIFont boldSystemFontOfSize:13];
        [_bub addSubview:bl];
        [_bub addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggle)]];
        [_bub addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
        [self addSubview:_bub];

        _box = [[UIView alloc] initWithFrame:CGRectMake(_pos.x, _pos.y + 54, 250, 296)];
        _box.backgroundColor = [UIColor colorWithRed:0.05 green:0.07 blue:0.11 alpha:0.95];
        _box.layer.cornerRadius = 14;
        _box.layer.borderWidth = 1;
        _box.layer.borderColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.5].CGColor;
        _box.hidden = YES;
        [self addSubview:_box];

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 180, 22)];
        t.text = @"VEEX 1.132";
        t.textColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:1];
        t.font = [UIFont boldSystemFontOfSize:14];
        [_box addSubview:t];

        UIButton *x = [UIButton buttonWithType:UIButtonTypeSystem];
        x.frame = CGRectMake(210, 8, 30, 26);
        [x setTitle:@"x" forState:UIControlStateNormal];
        [x addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
        [_box addSubview:x];

        NSArray *names = @[@"ESP", @"AIMBOT", @"AUTO FIRE", @"SOLO VISIBLES"];
        for (int i = 0; i < names.count; i++) {
            UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 40 + i * 32, 150, 26)];
            l.text = names[i];
            l.textColor = UIColor.whiteColor;
            l.font = [UIFont systemFontOfSize:12];
            [_box addSubview:l];
            UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectMake(178, 38 + i * 32, 51, 31)];
            s.tag = i;
            s.transform = CGAffineTransformMakeScale(0.7, 0.7);
            [s addTarget:self action:@selector(sw:) forControlEvents:UIControlEventValueChanged];
            [_box addSubview:s];
        }

        UIButton *pb = [UIButton buttonWithType:UIButtonTypeSystem];
        pb.frame = CGRectMake(14, 170, 216, 32);
        [pb setTitle:@"SUBIR PARCHE" forState:UIControlStateNormal];
        pb.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:1 alpha:0.22];
        pb.layer.cornerRadius = 8;
        [pb addTarget:self action:@selector(doPatch) forControlEvents:UIControlEventTouchUpInside];
        [_box addSubview:pb];

        UIButton *rb = [UIButton buttonWithType:UIButtonTypeSystem];
        rb.frame = CGRectMake(14, 208, 216, 32);
        [rb setTitle:@"RESET INVITADO" forState:UIControlStateNormal];
        rb.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0.5 alpha:0.18];
        rb.layer.cornerRadius = 8;
        [rb addTarget:self action:@selector(reset) forControlEvents:UIControlEventTouchUpInside];
        [_box addSubview:rb];

        g_diag = [[UILabel alloc] initWithFrame:CGRectMake(14, 246, 220, 40)];
        g_diag.textColor = [UIColor colorWithRed:0.6 green:0.85 blue:1 alpha:1];
        g_diag.font = [UIFont monospacedSystemFontOfSize:8 weight:UIFontWeightRegular];
        g_diag.numberOfLines = 3;
        g_diag.text = @"listo";
        [_box addSubview:g_diag];

        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e {
    if (!_box.hidden && CGRectContainsPoint(_box.frame, p)) return YES;
    return CGRectContainsPoint(_bub.frame, p);
}

- (void)toggle {
    _box.hidden = !_box.hidden;
    [self clamp];
}

- (void)drag:(UIPanGestureRecognizer *)p {
    CGPoint d = [p translationInView:self];
    _pos = CGPointMake(_pos.x + d.x, _pos.y + d.y);
    [p setTranslation:CGPointZero inView:self];
    [self clamp];
}

- (void)clamp {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    _pos.x = MAX(6, MIN(_pos.x, w - 56));
    _pos.y = MAX(40, MIN(_pos.y, h - 60));
    _bub.frame = CGRectMake(_pos.x, _pos.y, 46, 46);
    CGFloat bx = MIN(_pos.x, w - 258);
    CGFloat by = _pos.y + 54 + 296 > h ? _pos.y - 302 : _pos.y + 54;
    _box.frame = CGRectMake(MAX(6, bx), MAX(40, by), 250, 296);
}

- (void)sw:(UISwitch *)s {
    BOOL on = s.isOn;
    if (s.tag == 0) g.esp = on;
    if (s.tag == 1) g.aim = on;
    if (s.tag == 2) g.fire = on;
    if (s.tag == 3) g.visOnly = on;
}

- (void)reset { VXSay([NSString stringWithFormat:@"reset: %d", VXKeychainPurge()]); }

- (void)doPatch {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *p = g_patch ?: VXFindPatch();
        if (p) { g_patch = p; VXUpload(p); }
        else VXSay(@"no encontré parche");
    });
}

- (void)tick:(CADisplayLink *)l { if (g_draw) [g_draw setNeedsDisplay]; }

@end

static void VXBuildMenu(void) {
    CGRect s = UIScreen.mainScreen.bounds;
    g_win = [[UIWindow alloc] initWithFrame:s];
    g_win.windowLevel = UIWindowLevelAlert + 10;
    g_win.backgroundColor = UIColor.clearColor;
    g_win.rootViewController = [UIViewController new];
    g_win.hidden = NO;

    VXDraw *d = [[VXDraw alloc] initWithFrame:s];
    d.backgroundColor = UIColor.clearColor;
    d.userInteractionEnabled = NO;
    [g_win addSubview:d];
    g_draw = d;

    [g_win addSubview:[[VeexPanel alloc] initWithFrame:s]];
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
