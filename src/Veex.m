// Veex.m — panel Veex / ESP
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>

typedef void *(*fn_domain_get)(void);
typedef void **(*fn_domain_get_assemblies)(void *, size_t *);
typedef void *(*fn_assembly_get_image)(void *);
typedef const char *(*fn_image_get_name)(void *);
typedef void *(*fn_class_from_name)(void *, const char *, const char *);
typedef void *(*fn_class_get_parent)(void *);
typedef void *(*fn_class_get_field_from_name)(void *, const char *);
typedef size_t (*fn_field_get_offset)(void *);
typedef void (*fn_field_static_get_value)(void *, void *);
typedef void *(*fn_class_get_method_from_name)(void *, const char *, int);
typedef void *(*fn_runtime_invoke)(void *, void *, void **, void **);
typedef void *(*fn_object_new)(void *);
typedef void *(*fn_string_new)(const char *);
typedef void *(*fn_value_box)(void *, void *);
typedef void *(*fn_class_get_methods)(void *, void **);
typedef const char *(*fn_method_get_name)(void *);
typedef uint32_t (*fn_method_get_param_count)(void *);
typedef void *(*fn_method_get_param)(void *, uint32_t);
typedef char *(*fn_type_get_name)(void *);

static fn_domain_get                 p_domain_get;
static fn_domain_get_assemblies      p_domain_get_assemblies;
static fn_assembly_get_image         p_assembly_get_image;
static fn_image_get_name             p_image_get_name;
static fn_class_from_name            p_class_from_name;
static fn_class_get_parent           p_class_get_parent;
static fn_class_get_field_from_name  p_class_get_field_from_name;
static fn_field_get_offset           p_field_get_offset;
static fn_field_static_get_value     p_field_static_get_value;
static fn_class_get_method_from_name p_class_get_method_from_name;
static fn_runtime_invoke             p_runtime_invoke;
static fn_object_new                 p_object_new;
static fn_string_new                 p_string_new;
static fn_value_box                  p_value_box;
static fn_class_get_methods          p_class_get_methods;
static fn_method_get_name            p_method_get_name;
static fn_method_get_param_count     p_method_get_param_count;
static fn_method_get_param           p_method_get_param;
static fn_type_get_name              p_type_get_name;

typedef struct { float x, y, z; } V3;

static void *VXSym(const char *n) {
    static void *h = NULL;
    if (!h) {
        h = dlopen("Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOW);
        if (!h) h = dlopen("Frameworks/libil2cpp.dylib", RTLD_NOW);
    }
    void *p = h ? dlsym(h, n) : NULL;
    if (!p) p = dlsym(RTLD_DEFAULT, n);
    return p;
}

static BOOL VXResolve(void) {
    if (p_runtime_invoke) return YES;
    p_domain_get                 = (fn_domain_get)VXSym("il2cpp_domain_get");
    p_domain_get_assemblies      = (fn_domain_get_assemblies)VXSym("il2cpp_domain_get_assemblies");
    p_assembly_get_image         = (fn_assembly_get_image)VXSym("il2cpp_assembly_get_image");
    p_image_get_name             = (fn_image_get_name)VXSym("il2cpp_image_get_name");
    p_class_from_name            = (fn_class_from_name)VXSym("il2cpp_class_from_name");
    p_class_get_parent           = (fn_class_get_parent)VXSym("il2cpp_class_get_parent");
    p_class_get_field_from_name  = (fn_class_get_field_from_name)VXSym("il2cpp_class_get_field_from_name");
    p_field_get_offset           = (fn_field_get_offset)VXSym("il2cpp_field_get_offset");
    p_field_static_get_value     = (fn_field_static_get_value)VXSym("il2cpp_field_static_get_value");
    p_class_get_method_from_name = (fn_class_get_method_from_name)VXSym("il2cpp_class_get_method_from_name");
    p_runtime_invoke             = (fn_runtime_invoke)VXSym("il2cpp_runtime_invoke");
    p_object_new                 = (fn_object_new)VXSym("il2cpp_object_new");
    p_string_new                 = (fn_string_new)VXSym("il2cpp_string_new");
    p_value_box                  = (fn_value_box)VXSym("il2cpp_value_box");
    p_class_get_methods          = (fn_class_get_methods)VXSym("il2cpp_class_get_methods");
    p_method_get_name            = (fn_method_get_name)VXSym("il2cpp_method_get_name");
    p_method_get_param_count     = (fn_method_get_param_count)VXSym("il2cpp_method_get_param_count");
    p_method_get_param           = (fn_method_get_param)VXSym("il2cpp_method_get_param");
    p_type_get_name              = (fn_type_get_name)VXSym("il2cpp_type_get_name");

    if (!p_domain_get || !p_domain_get_assemblies || !p_assembly_get_image ||
        !p_image_get_name || !p_class_from_name || !p_class_get_field_from_name ||
        !p_field_get_offset || !p_field_static_get_value || !p_class_get_method_from_name ||
        !p_runtime_invoke) return NO;

    void *d = p_domain_get();
    if (!d) return NO;
    size_t n = 0;
    void **as = p_domain_get_assemblies(d, &n);
    if (!as || n == 0) return NO;
    return YES;
}

static void *VXAssembly(const char *needle) {
    if (!p_domain_get || !p_domain_get_assemblies) return NULL;
    size_t n = 0;
    void **as = p_domain_get_assemblies(p_domain_get(), &n);
    if (!as) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *a = *(void **)((char *)as + 0x20 + i * 8);
        if (!a) continue;
        void *img = p_assembly_get_image(a);
        if (!img) continue;
        const char *nm = p_image_get_name(img);
        if (nm && strstr(nm, needle)) return a;
    }
    return NULL;
}

static void *VXClassIn(const char *asmNeedle, const char *ns, const char *name) {
    void *a = VXAssembly(asmNeedle);
    if (!a) return NULL;
    void *img = p_assembly_get_image(a);
    return p_class_from_name(img, ns, name);
}

static void *VXClass(const char *ns, const char *name) {
    if (!p_domain_get || !p_domain_get_assemblies) return NULL;
    size_t n = 0;
    void **as = p_domain_get_assemblies(p_domain_get(), &n);
    if (!as) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *a = *(void **)((char *)as + 0x20 + i * 8);
        if (!a) continue;
        void *img = p_assembly_get_image(a);
        if (!img) continue;
        void *c = p_class_from_name(img, ns, name);
        if (c) return c;
    }
    return NULL;
}

static void *VXMethod(void *cls, const char *name, int argc) {
    if (!cls || !p_class_get_method_from_name) return NULL;
    return p_class_get_method_from_name(cls, name, argc);
}

static size_t VXFieldOffset(void *cls, const char *name) {
    void *c = cls;
    for (int depth = 0; c && depth < 12; depth++) {
        void *f = p_class_get_field_from_name(c, name);
        if (f) return p_field_get_offset(f);
        c = p_class_get_parent ? p_class_get_parent(c) : NULL;
    }
    return 0;
}

static BOOL VXPtr(void *p) {
    uintptr_t v = (uintptr_t)p;
    return p && v > 0x10000 && v < 0x8000000000ULL;
}

static void *VXClsOf(void *obj) {
    if (!obj) return NULL;
    return (__bridge void *)object_getClass((__bridge id)obj);
}

#pragma mark - estado

static struct {
    BOOL esp;
    BOOL aim;
    BOOL fire;
    BOOL visOnly;
    CGFloat fov;
    UIColor *color;
    int profile;
} g;

static void *g_triggerCls;
static void *g_camCls;
static size_t g_trOff;
static NSInteger g_entities;
static int g_armed;
static int g_built;

static UIWindow *g_win;
static UIView *g_bubble;
static UIView *g_panel;
static UILabel *g_status;
static UILabel *g_fovLabel;
static UIView *g_draw;
static CADisplayLink *g_link;
static BOOL g_diag;
static NSString *g_dbg;
static UIColor *g_accent;

static CGFloat VXW(void) { return [UIScreen mainScreen].bounds.size.width; }
static CGFloat VXH(void) { return [UIScreen mainScreen].bounds.size.height; }

static UIColor *VXAccent(void) { return g_accent ?: [UIColor whiteColor]; }

static void VXSay(NSString *s) {
    dispatch_async(dispatch_get_main_queue(), ^{ if (g_status) g_status.text = s; });
}

static UILabel *VXL(NSString *t, CGFloat s, UIColor *c) {
    UILabel *l = [[UILabel alloc] init];
    l.text = t;
    l.font = [UIFont fontWithName:@"Menlo-Bold" size:s] ?: [UIFont boldSystemFontOfSize:s];
    l.textColor = c;
    l.numberOfLines = 0;
    l.backgroundColor = [UIColor clearColor];
    return l;
}

static UIButton *VXB(NSString *t, CGFloat w, CGFloat h) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(0, 0, w, h);
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11] ?: [UIFont boldSystemFontOfSize:11];
    b.layer.borderWidth = 1;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
    b.layer.cornerRadius = 6;
    return b;
}

#pragma mark - il2cpp juego

static NSString *VXExcMsg(void *exc);

static void *VXTrigger(void) {
    if (!g_triggerCls) {
        g_triggerCls = VXClass("", "SpawnObjectCrossHairTrigger");
        if (g_triggerCls) g_trOff = VXFieldOffset(g_triggerCls, "transform");
    }
    if (!g_triggerCls) return NULL;
    void *f = p_class_get_field_from_name(g_triggerCls, "ActiveInstance");
    if (!f) return NULL;
    void *inst = NULL;
    p_field_static_get_value(f, &inst);
    return VXPtr(inst) ? inst : NULL;
}

static void *VXTransformOf(void *obj) {
    if (!VXPtr(obj)) return NULL;
    size_t off = g_trOff ? g_trOff : 0x50;
    void *t = *(void **)((char *)obj + off);
    return VXPtr(t) ? t : NULL;
}

static void *VXPosMethod(void *tr) {
    static void *k[32];
    static void *m[32];
    static int n;
    void *cls = VXClsOf(tr);
    for (int i = 0; i < n; i++) if (k[i] == cls) return m[i];
    void *mm = VXMethod(cls, "get_position", 0);
    if (n < 32) { k[n] = cls; m[n] = mm; n++; }
    return mm;
}

static void *VXCamera(void) {
    if (!g_camCls) g_camCls = VXClass("UnityEngine", "Camera");
    if (!g_camCls) { g_dbg = @"sin clase cam"; return NULL; }
    void *mm = VXMethod(g_camCls, "get_main", 0);
    if (!mm) { g_dbg = @"sin get_main"; return NULL; }
    void *e = NULL;
    void *c = p_runtime_invoke(mm, NULL, NULL, &e);
    if (e) { g_dbg = [@"exc cam " stringByAppendingString:VXExcMsg(e)]; return NULL; }
    if (!c) { g_dbg = @"cam null"; return NULL; }
    return c;
}

static BOOL VXWorldToScreen(void *cam, V3 w, CGPoint *out) {
    if (!cam) return NO;
    void *mm = VXMethod(VXClsOf(cam), "WorldToScreenPoint", 1);
    if (!mm && g_camCls) mm = VXMethod(g_camCls, "WorldToScreenPoint", 1);
    if (!mm) return NO;
    void *args[1] = { &w };
    void *exc = NULL;
    void *r = p_runtime_invoke(mm, cam, args, &exc);
    if (!r || exc) return NO;
    V3 *v = (V3 *)((char *)r + 16);
    out->x = v->x;
    out->y = VXH() - v->y;
    return v->z > 0.01f;
}

#pragma mark - parche

static NSString *VXExcMsg(void *exc) {
    if (!exc) return @"?";
    void *cls = VXClsOf(exc);
    void *mm = VXMethod(cls, "get_Message", 0);
    if (!mm) return @"?";
    void *e2 = NULL;
    void *s = p_runtime_invoke(mm, exc, NULL, &e2);
    if (!s || e2) return @"?";
    void *str = *(void **)((char *)s + 16);
    if (!VXPtr(str)) return @"?";
    return [NSString stringWithUTF8String:(const char *)str];
}

static void *VXStream(NSString *path, NSString **why) {
    void *fsCls = VXClass("System.IO", "FileStream");
    void *strCls = VXClass("System", "String");
    void *intCls = VXClass("System", "Int32");
    if (!fsCls || !strCls || !intCls) { if (why) *why = @"sin FileStream"; return NULL; }

    void *obj = p_object_new(fsCls);
    if (!obj) { if (why) *why = @"sin objeto"; return NULL; }

    void *ctor = NULL;
    void *it = NULL;
    while (1) {
        void *mm = p_class_get_methods(fsCls, &it);
        if (!mm) break;
        const char *nm = p_method_get_name(mm);
        if (!nm || strcmp(nm, ".ctor") != 0) continue;
        if (p_method_get_param_count(mm) != 3) continue;
        char *a0 = p_type_get_name(p_method_get_param(mm, 0));
        char *a1 = p_type_get_name(p_method_get_param(mm, 1));
        char *a2 = p_type_get_name(p_method_get_param(mm, 2));
        if (a0 && a1 && a2 && strstr(a0, "String") &&
            strstr(a1, "FileMode") && strstr(a2, "FileAccess")) { ctor = mm; break; }
    }
    if (!ctor) { if (why) *why = @"sin ctor"; return NULL; }

    void *sPath = p_string_new([path UTF8String]);
    int mode = 3;
    int acc = 1;
    void *bMode = p_value_box(intCls, &mode);
    void *bAcc = p_value_box(intCls, &acc);
    void *args[3] = { sPath, bMode, bAcc };
    void *exc = NULL;
    p_runtime_invoke(ctor, obj, args, &exc);
    if (exc) { if (why) *why = @"ctor"; return NULL; }
    return obj;
}

static NSString *VXPatchPath(void) {
    NSString *src = [[NSBundle mainBundle] pathForResource:@"veexpatch" ofType:@"bin"];
    if (!src) return nil;
    NSString *dst = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                     stringByAppendingPathComponent:@"veexpatch.bin"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dst]) [fm copyItemAtPath:src toPath:dst error:nil];
    return dst;
}

static BOOL VXProbar(void *m, NSString *path) {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d || d.length < 64) { VXSay(@"5 vacio"); return NO; }
    const unsigned char *raw = d.bytes;
    VXSay([NSString stringWithFormat:@"5 %lu b %02X%02X%02X%02X",
           (unsigned long)d.length, raw[0], raw[1], raw[2], raw[3]]);

    void *boolCls = VXClass("System", "Boolean");
    for (int k = 0; k < 2; k++) {
        NSString *why = nil;
        void *stream = VXStream(path, &why);
        if (!stream) { VXSay([NSString stringWithFormat:@"6 %@", why]); return NO; }
        int t = k;
        void *b = boolCls ? p_value_box(boolCls, &t) : NULL;
        void *args[4] = { NULL, NULL, stream, b };
        void *exc = NULL;
        p_runtime_invoke(m, NULL, args, &exc);
        if (!exc) { VXSay(@"parche cargado"); return YES; }
        VXSay([NSString stringWithFormat:@"9 b%d %@", t, VXExcMsg(exc)]);
    }
    return NO;
}

static BOOL VXCargar(void) {
    if (!VXResolve()) { VXSay(@"1 sin il2cpp"); return NO; }
    void *cls = VXClass("IFix.Core", "PatchManager");
    if (!cls) { VXSay(@"2 sin PatchManager"); return NO; }
    void *m = VXMethod(cls, "OptimizeLoad", 4);
    if (!m) { VXSay(@"3 sin OptimizeLoad"); return NO; }

    NSString *p = VXPatchPath();
    if (!p) { VXSay(@"4 sin veexpatch.bin"); return NO; }
    return VXProbar(m, p);
}

static void VXArmPatch(void) {
    if (g_armed) return;
    g_armed = 1;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        for (int i = 0; i < 20; i++) {
            if (VXCargar()) return;
            sleep(2);
        }
    });
}

#pragma mark - reset invitado

static NSArray *VXGuestTokens(void) {
    return @[@"garena", @"freefire", @"com.dts", @"guest", @"dts"];
}

static NSArray *VXOtherTokens(void) {
    return @[@"facebook", @"google", @"apple", @"oauth", @"signin"];
}

static int VXKeychainPurge(BOOL guestOnly, NSMutableString *log) {
    int removed = 0;
    NSArray *classes = @[(__bridge id)kSecClassGenericPassword,
                         (__bridge id)kSecClassInternetPassword];

    for (id cls in classes) {
        NSMutableDictionary *q = [NSMutableDictionary dictionary];
        q[(__bridge id)kSecClass] = cls;
        q[(__bridge id)kSecReturnAttributes] = @YES;
        q[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;

        CFTypeRef res = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &res) != errSecSuccess || !res) continue;

        NSArray *items = (__bridge_transfer NSArray *)res;
        for (NSDictionary *it in items) {
            NSString *svc = it[(__bridge id)kSecAttrService] ?: @"";
            NSString *acc = it[(__bridge id)kSecAttrAccount] ?: @"";
            NSString *grp = it[(__bridge id)kSecAttrAccessGroup] ?: @"";
            NSString *hay = [NSString stringWithFormat:@"%@ %@ %@", svc, acc, grp].lowercaseString;

            BOOL hit = !guestOnly;
            if (guestOnly) {
                for (NSString *t in VXGuestTokens()) {
                    if ([hay containsString:t]) { hit = YES; break; }
                }
                if (hit) {
                    for (NSString *t in VXOtherTokens()) {
                        if ([hay containsString:t]) { hit = NO; break; }
                    }
                }
            }
            if (!hit) continue;

            NSMutableDictionary *del = [NSMutableDictionary dictionary];
            del[(__bridge id)kSecClass] = cls;
            if (svc.length) del[(__bridge id)kSecAttrService] = svc;
            if (acc.length) del[(__bridge id)kSecAttrAccount] = acc;
            if (grp.length) del[(__bridge id)kSecAttrAccessGroup] = grp;
            if (SecItemDelete((__bridge CFDictionaryRef)del) == errSecSuccess) removed++;
        }
    }
    if (log) [log appendFormat:@"kc:%d ", removed];
    return removed;
}

static int VXResetGuest(NSMutableString *log) {
    int kc = VXKeychainPurge(YES, log);

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSArray *dirs = @[@"Documents", @"Library/Application Support", @"Library/Preferences"];
    NSArray *toks = @[@"guest", @"garena", @"freefire", @"account", @"token",
                      @"login", @"uid", @"session", @"device", @"user"];
    int files = 0;

    for (NSString *d in dirs) {
        NSString *full = [home stringByAppendingPathComponent:d];
        NSArray *items = [fm contentsOfDirectoryAtPath:full error:nil];
        for (NSString *it in items) {
            NSString *low = it.lowercaseString;
            if (!([low hasSuffix:@".plist"] || [low hasSuffix:@".json"] ||
                  [low hasSuffix:@".dat"] || [low hasSuffix:@".xml"] ||
                  [low hasSuffix:@".txt"])) continue;

            BOOL hit = [d hasSuffix:@"Preferences"];
            if (!hit) {
                for (NSString *t in toks) {
                    if ([low containsString:t]) { hit = YES; break; }
                }
            }
            if (!hit) continue;
            if ([fm removeItemAtPath:[full stringByAppendingPathComponent:it] error:nil]) files++;
        }
    }

    for (NSString *nm in @[@"com.dts.freefireth.plist", @"com.garena.plist", @"com.dts.freefiremax.plist"]) {
        NSString *p = [[home stringByAppendingPathComponent:@"Library/Preferences"] stringByAppendingPathComponent:nm];
        if ([fm removeItemAtPath:p error:nil]) files++;
    }

    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (log) [log appendFormat:@"ar:%d", files];
    return kc + files;
}

#pragma mark - overlay

@interface VeexDraw : UIView
@end

@implementation VeexDraw
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e { return NO; }

- (void)drawRect:(CGRect)rect {
    if (!g.esp) { g_dbg = @"esp off"; return; }
    void *cam = VXCamera();
    if (!cam) return;

    void *trg = VXTrigger();
    if (!trg) { g_dbg = @"sin trigger"; return; }
    void *dict = *(void **)((char *)trg + 0x50);
    if (!VXPtr(dict)) { g_dbg = @"dict mala"; return; }

    char *entries = *(char **)((char *)dict + 0x18);
    int count = *(int *)((char *)dict + 0x20);
    g_dbg = [NSString stringWithFormat:@"cnt %d", count];
    if (!VXPtr(entries) || count <= 0 || count > 512) return;

    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(c, 1.2);
    CGContextSetStrokeColorWithColor(c, (g.color ?: [UIColor whiteColor]).CGColor);

    NSInteger drawn = 0;
    for (int i = 0; i < count; i++) {
        void *ent = *(void **)(entries + i * 24 + 8);
        if (!VXPtr(ent)) continue;
        void *tr = VXTransformOf(ent);
        if (!tr) continue;

        void *mPos = VXPosMethod(tr);
        if (!mPos) continue;
        void *e2 = NULL;
        void *r = p_runtime_invoke(mPos, tr, NULL, &e2);
        if (!r || e2) continue;
        V3 *pos = (V3 *)((char *)r + 16);

        CGPoint head = CGPointZero, foot = CGPointZero;
        V3 h = *pos; h.y += 1.65f;
        V3 f = *pos;
        if (!VXWorldToScreen(cam, h, &head)) continue;
        if (!VXWorldToScreen(cam, f, &foot)) continue;

        CGFloat hgt = foot.y - head.y;
        if (hgt < 6 || hgt > VXH()) continue;
        CGFloat wid = hgt * 0.45;
        if (wid < 6) wid = 6;
        CGRect box = CGRectMake(head.x - wid / 2, head.y, wid, hgt);

        CGContextStrokeRect(c, box);
        CGContextMoveToPoint(c, CGRectGetMidX(box), head.y - 4);
        CGContextAddLineToPoint(c, CGRectGetMidX(box), foot.y + 4);
        CGContextStrokePath(c);
        drawn++;
    }
    g_entities = drawn;
    g_dbg = [NSString stringWithFormat:@"cnt %d dib %ld", count, (long)drawn];
}
@end

#pragma mark - ventana

@interface VXWindow : UIWindow
@end
@implementation VXWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (g_panel && !g_panel.hidden && CGRectContainsPoint(g_panel.frame, p))
        return [super hitTest:p withEvent:e];
    if (g_bubble && CGRectContainsPoint(CGRectInset(g_bubble.frame, -16, -16), p))
        return [super hitTest:p withEvent:e];
    return nil;
}
@end

#pragma mark - panel

@interface VeexPanel : UIView
- (void)tick;
- (void)bubbleTapped;
- (void)drag:(UIPanGestureRecognizer *)p;
- (void)dragBubble:(UIPanGestureRecognizer *)p;
- (void)showReset;
- (void)cancelReset;
- (void)doReset;
- (void)toggleDiag;
- (void)switchChanged:(UISwitch *)s;
- (void)fovChanged:(UISlider *)s;
- (void)profileChanged:(UISegmentedControl *)s;
- (void)chip:(UIButton *)b;
- (void)close;
@end

static void VXShowResetCard(void) {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((VXW() - 250) / 2, (VXH() - 118) / 2, 250, 118)];
    card.tag = 9912;
    card.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.98];
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor whiteColor].CGColor;
    card.layer.cornerRadius = 12;
    [g_win addSubview:card];

    UILabel *t = VXL(@"RESET INVITADO", 11, [UIColor whiteColor]);
    t.frame = CGRectMake(12, 10, 226, 16);
    [card addSubview:t];

    UILabel *d = VXL(@"Borra la cuenta de invitado.\nNo toca FB / Google.", 9, [UIColor colorWithWhite:1 alpha:0.6]);
    d.frame = CGRectMake(12, 30, 226, 30);
    [card addSubview:d];

    UIButton *no = VXB(@"CANCELAR", 108, 30);
    no.frame = CGRectMake(12, 72, 108, 30);
    [no addTarget:g_panel action:@selector(cancelReset) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:no];

    UIButton *yes = VXB(@"BORRAR", 108, 30);
    yes.frame = CGRectMake(130, 72, 108, 30);
    yes.layer.borderColor = VXAccent().CGColor;
    [yes addTarget:g_panel action:@selector(doReset) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:yes];
}

@implementation VeexPanel

- (void)tick {
    if (g.esp && g_draw) [(VeexDraw *)g_draw setNeedsDisplay];
    if (g_diag && g_status) g_status.text = g_dbg ?: @"...";
}

- (void)bubbleTapped {
    BOOL abrir = g_panel.hidden;
    if (abrir) [g_win bringSubviewToFront:g_panel];
    g_panel.hidden = !abrir;
    g_bubble.layer.borderColor = (abrir ? VXAccent() : [UIColor whiteColor]).CGColor;
}

- (void)close {
    g_panel.hidden = YES;
    g_bubble.layer.borderColor = [UIColor whiteColor].CGColor;
}

- (void)drag:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:g_win];
    CGPoint c = g_panel.center;
    c.x = MAX(g_panel.bounds.size.width / 2, MIN(VXW() - g_panel.bounds.size.width / 2, c.x + t.x));
    c.y = MAX(g_panel.bounds.size.height / 2, MIN(VXH() - g_panel.bounds.size.height / 2, c.y + t.y));
    g_panel.center = c;
    [p setTranslation:CGPointZero inView:g_win];
}

- (void)dragBubble:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:g_win];
    CGPoint c = g_bubble.center;
    c.x = MAX(26, MIN(VXW() - 26, c.x + t.x));
    c.y = MAX(26, MIN(VXH() - 26, c.y + t.y));
    g_bubble.center = c;
    [p setTranslation:CGPointZero inView:g_win];
}

- (void)showReset { VXShowResetCard(); }

- (void)cancelReset {
    UIView *c = [g_win viewWithTag:9912];
    if (c) [c removeFromSuperview];
}

- (void)doReset {
    NSMutableString *log = [NSMutableString string];
    VXResetGuest(log);
    g_status.hidden = NO;
    g_status.text = [NSString stringWithFormat:@"reset ok  %@\ncerrando en 2s", log];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ exit(0); });
}

- (void)toggleDiag {
    g_diag = !g_diag;
    g_status.hidden = !g_diag;
    if (g_diag) g_status.text = @"...";
}

- (void)switchChanged:(UISwitch *)s {
    switch (s.tag) {
        case 1001: g.esp = s.isOn; break;
        case 1002: g.aim = s.isOn; break;
        case 1003: g.fire = s.isOn; break;
        case 1004: g.visOnly = s.isOn; break;
        default: break;
    }
}

- (void)fovChanged:(UISlider *)s {
    g.fov = s.value;
    g_fovLabel.text = [NSString stringWithFormat:@"FOV %.0f", s.value];
}

- (void)profileChanged:(UISegmentedControl *)s {
    g.profile = (int)s.selectedSegmentIndex;
    g.fov = (g.profile == 0) ? 120 : 45;
    UISlider *f = (UISlider *)[self viewWithTag:1005];
    f.value = g.fov;
    g_fovLabel.text = [NSString stringWithFormat:@"FOV %.0f", g.fov];
}

- (void)chip:(UIButton *)b {
    NSArray *cs = @[[UIColor colorWithRed:0.15 green:1 blue:0.35 alpha:1],
                    [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:1],
                    [UIColor colorWithRed:0.3 green:0.65 blue:1 alpha:1],
                    [UIColor colorWithRed:1 green:0.85 blue:0.2 alpha:1],
                    [UIColor colorWithRed:0.85 green:0.35 blue:1 alpha:1],
                    [UIColor whiteColor]];
    NSInteger i = b.tag - 2001;
    if (i < 0 || i >= (NSInteger)cs.count) return;
    g_accent = cs[i];
    g.color = cs[i];
    [(VeexDraw *)g_draw setNeedsDisplay];
    for (UIView *o in self.subviews) {
        if (o.tag >= 2001 && o.tag <= 2006)
            o.layer.borderWidth = (o.tag - 2001 == i) ? 2 : 1;
    }
}

@end

#pragma mark - construcción

static void VXBuildMenu(void) {
    if (g_built) return;
    g_built = 1;

    g_accent = [UIColor colorWithRed:0.15 green:1 blue:0.35 alpha:1];
    g.color = g_accent;

    g_win = [[VXWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    g_win.windowLevel = UIWindowLevelAlert + 1;
    g_win.backgroundColor = [UIColor clearColor];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    g_win.rootViewController = vc;
    [g_win makeKeyAndVisible];

    g_draw = [[VeexDraw alloc] initWithFrame:g_win.bounds];
    g_draw.backgroundColor = [UIColor clearColor];
    g_draw.userInteractionEnabled = NO;
    [g_win addSubview:g_draw];

    // panel
    CGFloat pw = 272;
    CGFloat ph = MIN(560, VXH() - 110);
    g_panel = [[VeexPanel alloc] initWithFrame:CGRectMake((VXW() - pw) / 2, 74, pw, ph)];
    g_panel.backgroundColor = [UIColor colorWithWhite:0.03 alpha:0.96];
    g_panel.layer.borderWidth = 1;
    g_panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
    g_panel.layer.cornerRadius = 12;
    g_panel.clipsToBounds = YES;
    g_panel.hidden = YES;
    [g_win addSubview:g_panel];

    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, 44)];
    head.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    [g_panel addSubview:head];

    UILabel *title = VXL(@"VEEX", 15, [UIColor whiteColor]);
    title.frame = CGRectMake(14, 8, 80, 18);
    [head addSubview:title];

    UILabel *by = VXL(@"BY LEVI", 8, [UIColor colorWithWhite:1 alpha:0.45]);
    by.frame = CGRectMake(14, 26, 80, 10);
    [head addSubview:by];

    UILabel *tg = VXL(@"t.me/levibrouh", 8, [UIColor colorWithWhite:1 alpha:0.45]);
    tg.frame = CGRectMake(100, 26, 120, 10);
    [head addSubview:tg];

    UIButton *x = VXB(@"X", 26, 26);
    x.frame = CGRectMake(pw - 36, 9, 26, 26);
    [x addTarget:g_panel action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:x];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:g_panel action:@selector(drag:)];
    [head addGestureRecognizer:pan];

    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 44, pw, ph - 44)];
    sv.contentSize = CGSizeMake(pw, 520);
    sv.delaysContentTouches = NO;
    sv.showsVerticalScrollIndicator = YES;
    [g_panel addSubview:sv];

    CGFloat y = 12;

    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"PODEROSO", @"DISIMULADO"]];
    seg.frame = CGRectMake(14, y, pw - 28, 30);
    seg.selectedSegmentIndex = 0;
    seg.tintColor = [UIColor whiteColor];
    [seg addTarget:g_panel action:@selector(profileChanged:) forControlEvents:UIControlEventValueChanged];
    [sv addSubview:seg];
    y += 40;

    NSArray *names = @[@"ESP", @"AIMBOT", @"AUTO FIRE", @"SOLO VISIBLES"];
    for (NSInteger i = 0; i < names.count; i++) {
        UILabel *l = VXL(names[i], 10, [UIColor colorWithWhite:1 alpha:0.85]);
        l.frame = CGRectMake(14, y + 4, 150, 16);
        [sv addSubview:l];

        UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectMake(pw - 66, y, 51, 31)];
        s.tag = 1001 + i;
        s.onTintColor = VXAccent();
        [s addTarget:g_panel action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        [sv addSubview:s];
        y += 40;
    }

    g_fovLabel = VXL(@"FOV 120", 10, [UIColor whiteColor]);
    g_fovLabel.frame = CGRectMake(14, y, 200, 14);
    [sv addSubview:g_fovLabel];
    y += 18;

    UISlider *fov = [[UISlider alloc] initWithFrame:CGRectMake(14, y, pw - 28, 30)];
    fov.minimumValue = 1; fov.maximumValue = 360; fov.value = 120;
    fov.tag = 1005;
    fov.tintColor = [UIColor whiteColor];
    [fov addTarget:g_panel action:@selector(fovChanged:) forControlEvents:UIControlEventValueChanged];
    [sv addSubview:fov];
    y += 42;

    UILabel *cl = VXL(@"COLOR", 9, [UIColor colorWithWhite:1 alpha:0.5]);
    cl.frame = CGRectMake(14, y, 100, 12);
    [sv addSubview:cl];
    y += 16;

    NSArray *cs = @[[UIColor colorWithRed:0.15 green:1 blue:0.35 alpha:1],
                    [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:1],
                    [UIColor colorWithRed:0.3 green:0.65 blue:1 alpha:1],
                    [UIColor colorWithRed:1 green:0.85 blue:0.2 alpha:1],
                    [UIColor colorWithRed:0.85 green:0.35 blue:1 alpha:1],
                    [UIColor whiteColor]];
    for (NSInteger i = 0; i < cs.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(14 + i * 34, y, 26, 26);
        b.backgroundColor = cs[i];
        b.layer.cornerRadius = 13;
        b.layer.borderWidth = 1;
        b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
        b.tag = 2001 + i;
        [b addTarget:g_panel action:@selector(chip:) forControlEvents:UIControlEventTouchUpInside];
        [sv addSubview:b];
    }
    y += 40;

    UIButton *rst = VXB(@"RESET INVITADO", pw - 28, 32);
    rst.frame = CGRectMake(14, y, pw - 28, 32);
    rst.layer.borderColor = VXAccent().CGColor;
    [rst addTarget:g_panel action:@selector(showReset) forControlEvents:UIControlEventTouchUpInside];
    [sv addSubview:rst];
    y += 44;

    g_status = VXL(@"", 8, [UIColor colorWithWhite:1 alpha:0.7]);
    g_status.frame = CGRectMake(14, y, pw - 28, 90);
    g_diag = YES;
    g_status.hidden = NO;
    [sv addSubview:g_status];
    y += 96;

    sv.contentSize = CGSizeMake(pw, y);

    // burbuja
    g_bubble = [[UIView alloc] initWithFrame:CGRectMake(14, 120, 46, 46)];
    g_bubble.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.9];
    g_bubble.layer.cornerRadius = 23;
    g_bubble.layer.borderWidth = 1;
    g_bubble.layer.borderColor = [UIColor whiteColor].CGColor;
    UILabel *v = VXL(@"V", 22, [UIColor whiteColor]);
    v.textAlignment = NSTextAlignmentCenter;
    v.frame = CGRectMake(0, 8, 46, 28);
    [g_bubble addSubview:v];
    [g_win addSubview:g_bubble];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:g_panel
                                                                         action:@selector(bubbleTapped)];
    [g_bubble addGestureRecognizer:tap];

    UIPanGestureRecognizer *bpan = [[UIPanGestureRecognizer alloc] initWithTarget:g_panel
                                                                          action:@selector(dragBubble:)];
    [g_bubble addGestureRecognizer:bpan];

    g_link = [CADisplayLink displayLinkWithTarget:g_panel selector:@selector(tick)];
    [g_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

#pragma mark - arranque

__attribute__((constructor)) static void VXInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ VXBuildMenu(); });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (int i = 0; i < 600; i++) {
            if (VXResolve()) {
                void *c = VXClass("", "SpawnObjectCrossHairTrigger");
                if (c) { g_triggerCls = c; g_trOff = VXFieldOffset(c, "transform"); return; }
            }
            usleep(200000);
        }
    });
}
