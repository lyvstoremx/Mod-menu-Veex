//
//  Veex.m
//  Veex · BY LEVI · t.me/levibrouh
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <unistd.h>
#import <stdlib.h>

#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif
extern int ptrace(int _request, pid_t _pid, char *_addr, int _data);

#pragma mark - tipos

typedef struct { float x, y, z; } V3;
typedef struct { float x, y, z, w; } V4;
typedef struct { float x, y, z; } Q3;
typedef struct { float x, y, z, w; } Q4;

typedef enum {
    VXEspBox = 1,
    VXEspBone = 2,
    VXEspName = 3,
    VXEspHp = 4,
    VXEspDist = 5,
    VXEspLine = 6
} VXEspBit;

typedef struct {
    BOOL esp;
    BOOL aim;
    BOOL diag;
    BOOL silent;
    BOOL rage;
    BOOL fovCircle;
    BOOL crosshair;
    BOOL visibleOnly;
    NSInteger espBits;
    float fov;
    float smooth;
    float aimFov;
    CGFloat boxW;
    CGFloat boxH;
    UIColor *color;
    UIColor *bg;
    UIColor *line;
} VXConf;

#pragma mark - globales

static VXConf g;
static BOOL g_built;
static BOOL g_ready;
static BOOL g_hidOnce;
static NSUInteger g_frames;
static void *g_handle;
static UIView *g_win;
static UIView *g_bubble;
static UIView *g_panel;
static UIView *g_draw;
static UILabel *g_status;
static UILabel *g_fps;
static CADisplayLink *g_link;
static UIColor *g_accent;
static NSInteger g_entities;
static NSInteger g_targets;
static void *g_target;
static size_t g_trOff;
static void *g_dictField;
static void *g_dictCls;
static void *g_camCls;
static void *g_camMain;
static void *g_w2s;
static char g_dbg[200];
static CFTimeInterval g_last;

#pragma mark - api

static void *(*p_domain_get)(void);
static void **(*p_domain_get_assemblies)(void *, size_t *);
static void *(*p_assembly_get_image)(void *);
static const char *(*p_image_get_name)(void *);
static void *(*p_class_from_name)(void *, const char *, const char *);
static void *(*p_class_get_method_from_name)(void *, const char *, int);
static void *(*p_runtime_invoke)(void *, void *, void **, void **);
static void (*p_field_static_get_value)(void *, void *);
static void *(*p_class_get_fields)(void *, void **);
static void *(*p_field_get_type)(void *);
static char *(*p_type_get_name)(void *);
static char *(*p_class_get_name)(void *);
static void *(*p_object_get_class)(void *);
static void *(*p_array_new)(void *, size_t);
static size_t (*p_image_class_count)(void *);
static void *(*p_image_get_class)(void *, size_t);
static void *(*p_thread_attach)(void *);
static size_t (*p_field_get_offset)(void *);
static void *(*p_class_get_type)(void *);
static void *(*p_object_new)(void *);
static void (*p_free)(void *);
static void *(*p_string_new)(const char *);
static void *(*p_class_get_property_from_name)(void *, const char *);
static void *(*p_property_get_get_method)(void *);
static void *(*p_method_get_param_count)(void *);

#pragma mark - utilidades

static inline BOOL VXPtr(void *p) {
    return p && ((uintptr_t)p & 3) == 0 && (uintptr_t)p > 0x1000;
}

static inline CGFloat VXW(void) { return [UIScreen mainScreen].bounds.size.width; }
static inline CGFloat VXH(void) { return [UIScreen mainScreen].bounds.size.height; }

static void *VXS(const char *n) {
    return g_handle ? dlsym(g_handle, n) : NULL;
}

static UIColor *VXC(NSString *hex, UIColor *fallback) {
    if (!hex || hex.length < 6) return fallback;
    unsigned int v = 0;
    NSScanner *s = [NSScanner scannerWithString:[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]];
    if (![s scanHexInt:&v]) return fallback;
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0
                           green:((v >> 8) & 0xFF) / 255.0
                            blue:(v & 0xFF) / 255.0
                           alpha:1];
}

#pragma mark - resolucion

static BOOL VXResolve(void) {
    if (p_domain_get) return YES;

    g_handle = dlopen("/usr/lib/libil2cpp.so", RTLD_NOW);
    if (!g_handle) g_handle = dlopen("libil2cpp.so", RTLD_NOW);
    if (!g_handle) {
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const char *nm = _dyld_get_image_name(i);
            if (!nm) continue;
            if (strstr(nm, "UnityFramework") || strstr(nm, "Unity")) {
                g_handle = dlopen(nm, RTLD_NOW);
                if (g_handle) break;
            }
        }
    }
    if (!g_handle) return NO;

    p_domain_get = VXS("il2cpp_domain_get");
    p_domain_get_assemblies = VXS("il2cpp_domain_get_assemblies");
    p_assembly_get_image = VXS("il2cpp_assembly_get_image");
    p_image_get_name = VXS("il2cpp_image_get_name");
    p_class_from_name = VXS("il2cpp_class_from_name");
    p_class_get_method_from_name = VXS("il2cpp_class_get_method_from_name");
    p_runtime_invoke = VXS("il2cpp_runtime_invoke");
    p_field_static_get_value = VXS("il2cpp_field_static_get_value");
    p_class_get_fields = VXS("il2cpp_class_get_fields");
    p_field_get_type = VXS("il2cpp_field_get_type");
    p_type_get_name = VXS("il2cpp_type_get_name");
    p_class_get_name = VXS("il2cpp_class_get_name");
    p_object_get_class = VXS("il2cpp_object_get_class");
    p_array_new = VXS("il2cpp_array_new");
    p_thread_attach = VXS("il2cpp_thread_attach");
    p_field_get_offset = VXS("il2cpp_field_get_offset");
    p_class_get_type = VXS("il2cpp_class_get_type");
    p_object_new = VXS("il2cpp_object_new");
    p_free = VXS("il2cpp_free");
    p_string_new = VXS("il2cpp_string_new");
    p_class_get_property_from_name = VXS("il2cpp_class_get_property_from_name");
    p_property_get_get_method = VXS("il2cpp_property_get_get_method");
    p_method_get_param_count = VXS("il2cpp_method_get_param_count");

    p_image_class_count = VXS("il2cpp_image_class_count");
    if (!p_image_class_count) p_image_class_count = VXS("il2cpp_image_get_class_count");
    p_image_get_class = VXS("il2cpp_image_get_class");

    if (!p_domain_get) return NO;
    if (!p_domain_get_assemblies) return NO;
    if (!p_assembly_get_image) return NO;
    if (!p_class_from_name) return NO;
    if (!p_runtime_invoke) return NO;
    return YES;
}

static void VXAttach(void) {
    if (p_thread_attach && p_domain_get) {
        void *dom = p_domain_get();
        if (dom) p_thread_attach(dom);
    }
}

#pragma mark - ensamblados y clases

static void *VXAsmAt(void **as, size_t i) {
    if (!as || !as[i]) return NULL;
    return p_assembly_get_image(as[i]);
}

static size_t VXImgCount(void *img) {
    if (!img) return 0;
    if (p_image_class_count) return p_image_class_count(img);
    return 6000;
}

static void *VXImageNamed(const char *needle) {
    if (!VXResolve()) return NULL;
    void *dom = p_domain_get();
    if (!dom) return NULL;
    size_t n = 0;
    void **as = p_domain_get_assemblies(dom, &n);
    if (!as) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = VXAsmAt(as, i);
        if (!img) continue;
        const char *nm = p_image_get_name ? p_image_get_name(img) : NULL;
        if (nm && strstr(nm, needle)) return img;
    }
    return NULL;
}

static void *VXClass(const char *ns, const char *name) {
    if (!VXResolve()) return NULL;
    void *dom = p_domain_get();
    if (!dom) return NULL;
    size_t n = 0;
    void **as = p_domain_get_assemblies(dom, &n);
    if (!as) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = VXAsmAt(as, i);
        if (!img) continue;
        void *c = NULL;
        if (ns && ns[0]) c = p_class_from_name(img, ns, name);
        if (!c) c = p_class_from_name(img, "", name);
        if (c) return c;
    }
    return NULL;
}

static void *VXMethod(void *cls, const char *name, int argc) {
    if (!cls || !p_class_get_method_from_name) return NULL;
    return p_class_get_method_from_name(cls, name, argc);
}

static void *VXClsOf(void *obj) {
    if (!VXPtr(obj)) return NULL;
    if (p_object_get_class) return p_object_get_class(obj);
    return *(void **)obj;
}

static BOOL VXValidObj(void *o) {
    if (!VXPtr(o)) return NO;
    void *k = *(void **)o;
    if (!VXPtr(k)) return NO;
    if (!p_class_get_name) return YES;
    const char *n = p_class_get_name(k);
    return n && n[0];
}

static const char *VXClsName(void *o) {
    if (!VXValidObj(o)) return NULL;
    return p_class_get_name ? p_class_get_name(VXClsOf(o)) : NULL;
}

#pragma mark - diccionario de entidades

static const char *kVXCand[] = {
    "SpawnObjectCrossHairTrigger",
    "SpawnManager",
    "PlayerManager",
    "EntityManager",
    "GameFacade",
    "GameManager",
    "Player",
    "Character",
    "Avatar",
    "AvatarManager",
    "Entity",
    "Match",
    "MatchManager",
    "GameScene",
    "PlayerEntity",
    "EntityFactory"
};

static BOOL VXDictOK(void *dict) {
    if (!VXPtr(dict)) return NO;
    char *e = *(char **)((char *)dict + 0x18);
    int c = *(int *)((char *)dict + 0x20);
    if (!VXPtr(e)) return NO;
    if (c <= 0 || c > 512) return NO;
    void *first = *(void **)(e + 8);
    if (!VXValidObj(first)) return NO;
    return YES;
}

static void *VXFieldDict(void *cls) {
    if (!cls) return NULL;
    void *it = NULL;
    void *fd = NULL;
    while ((fd = p_class_get_fields(cls, &it))) {
        if (p_type_get_name && p_field_get_type) {
            char *tn = p_type_get_name(p_field_get_type(fd));
            if (!tn || !strstr(tn, "Dictionary")) continue;
        }
        void *d = NULL;
        p_field_static_get_value(fd, &d);
        if (VXDictOK(d)) {
            g_dictCls = cls;
            g_dictField = fd;
            return d;
        }
    }
    return NULL;
}

static void *VXFindDict(void) {
    if (g_dictField) {
        void *d = NULL;
        p_field_static_get_value(g_dictField, &d);
        if (VXDictOK(d)) return d;
        g_dictField = NULL;
    }
    if (!VXResolve()) return NULL;
    void *dom = p_domain_get();
    if (!dom) return NULL;
    size_t n = 0;
    void **as = p_domain_get_assemblies(dom, &n);
    if (!as) return NULL;

    for (size_t t = 0; t < sizeof(kVXCand) / sizeof(*kVXCand); t++) {
        for (size_t i = 0; i < n; i++) {
            void *img = VXAsmAt(as, i);
            if (!img) continue;
            void *cls = p_class_from_name(img, "", kVXCand[t]);
            if (!cls) continue;
            void *d = VXFieldDict(cls);
            if (d) return d;
        }
    }
    return NULL;
}

#pragma mark - camara y transform

static void *VXCam(void) {
    if (!g_camCls) g_camCls = VXClass("UnityEngine", "Camera");
    if (!g_camCls) return NULL;
    if (!g_camMain) g_camMain = VXMethod(g_camCls, "get_main", 0);
    if (!g_camMain) return NULL;
    void *e = NULL;
    void *cam = p_runtime_invoke(g_camMain, NULL, NULL, &e);
    if (!cam || e) return NULL;
    return cam;
}

static void *VXTransformOf(void *obj) {
    if (!VXValidObj(obj)) return NULL;
    void *m = VXMethod(VXClsOf(obj), "get_transform", 0);
    if (!m) return NULL;
    void *e = NULL;
    void *r = p_runtime_invoke(m, obj, NULL, &e);
    if (!r || e) return NULL;
    return VXPtr(r) ? r : NULL;
}

static BOOL VXPosOf(void *tr, V3 *out) {
    if (!VXValidObj(tr)) return NO;
    void *m = VXMethod(VXClsOf(tr), "get_position", 0);
    if (!m) return NO;
    void *e = NULL;
    void *r = p_runtime_invoke(m, tr, NULL, &e);
    if (!r || e) return NO;
    memcpy(out, (char *)r + 16, sizeof(V3));
    return YES;
}

static void *VXChild(void *tr, int idx) {
    if (!VXValidObj(tr)) return NULL;
    void *m = VXMethod(VXClsOf(tr), "GetChild", 1);
    if (!m) return NULL;
    int32_t a = idx;
    void *args[1] = { &a };
    void *e = NULL;
    void *r = p_runtime_invoke(m, tr, args, &e);
    if (!r || e) return NULL;
    return VXPtr(r) ? r : NULL;
}

static BOOL VXToScreen(void *cam, V3 w, CGPoint *out) {
    if (!cam) return NO;
    if (!g_w2s) {
        void *c = VXClsOf(cam);
        g_w2s = VXMethod(c, "WorldToScreenPoint", 1);
    }
    if (!g_w2s) return NO;
    void *args[1] = { &w };
    void *e = NULL;
    void *r = p_runtime_invoke(g_w2s, cam, args, &e);
    if (!r || e) return NO;
    V3 *v = (V3 *)((char *)r + 16);
    out->x = v->x;
    out->y = VXH() - v->y;
    return v->z > 0.01f;
}

static float VXDistTo(V3 a, V3 b) {
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    float dz = a.z - b.z;
    return sqrtf(dx * dx + dy * dy + dz * dz);
}

#pragma mark - vida

static BOOL VXHpOf(void *ent, float *out) {
    if (!VXValidObj(ent)) return NO;
    void *cls = VXClsOf(ent);
    const char *names[] = { "get_Hp", "get_HP", "get_Health", "get_CurHp", "get_hp" };
    for (int i = 0; i < 5; i++) {
        void *m = VXMethod(cls, names[i], 0);
        if (!m) continue;
        void *e = NULL;
        void *r = p_runtime_invoke(m, ent, NULL, &e);
        if (!r || e) continue;
        float v = 0;
        memcpy(&v, (char *)r + 16, 4);
        if (v > 0 && v < 100000) {
            *out = v;
            return YES;
        }
    }
    return NO;
}

#pragma mark - carga del parche

static BOOL VXPatchLoad(void) {
    NSString *src = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"veexpatch.bin"];
    NSData *d = [NSData dataWithContentsOfFile:src];
    if (!d || d.length < 64) return NO;

    void *img = VXImageNamed("IFix.Core");
    if (!img) return NO;
    void *cls = p_class_from_name(img, "IFix.Core", "PatchManager");
    if (!cls) return NO;

    void *ms = VXImageNamed("mscorlib");
    if (!ms) return NO;
    void *byteCls = p_class_from_name(ms, "System", "Byte");
    if (!byteCls || !p_array_new) return NO;

    void *arr = p_array_new(byteCls, d.length);
    if (!arr) return NO;
    memcpy((char *)arr + 0x20, d.bytes, d.length);

    void *m = VXMethod(cls, "Load", 1);
    void *exc = NULL;
    if (m) {
        void *args[1] = { arr };
        p_runtime_invoke(m, NULL, args, &exc);
        return exc == NULL;
    }
    m = VXMethod(cls, "Load", 0);
    if (!m) return NO;
    p_runtime_invoke(m, NULL, NULL, &exc);
    return exc == NULL;
}

#pragma mark - reset invitado

static void VXResetGuest(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSArray *paths = @[
        @"Documents/il2cpp",
        @"Library/Preferences/com.dts.freefireth.plist",
        @"Library/Caches/com.dts.freefireth",
        @"Documents/Unity",
        @"Library/Application Support/com.dts.freefireth"
    ];
    for (NSString *p in paths) {
        [fm removeItemAtPath:[home stringByAppendingPathComponent:p] error:nil];
    }
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    for (NSString *k in [ud dictionaryRepresentation].allKeys) {
        if ([k.lowercaseString containsString:@"guest"] ||
            [k.lowercaseString containsString:@"uid"] ||
            [k.lowercaseString containsString:@"login"]) {
            [ud removeObjectForKey:k];
        }
    }
    [ud synchronize];
}

#pragma mark - dump

static NSString *VXReport(void) {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"VEEX DUMP\n"];

    void *img = VXImageNamed("Assembly-CSharp");
    if (!img) return @"sin assembly";
    const char *in = p_image_get_name ? p_image_get_name(img) : "?";
    [s appendFormat:@"IMG %s\n", in ?: "?"];

    size_t cc = VXImgCount(img);
    [s appendFormat:@"clases %zu\n", cc];

    for (size_t k = 0; k < cc; k++) {
        void *cls = p_image_get_class ? p_image_get_class(img, k) : NULL;
        if (!cls) break;
        char *cn = p_class_get_name(cls);
        if (!cn) continue;
        BOOL hit = NO;
        const char *keys[] = { "Spawn", "Player", "Entity", "Manager", "Avatar", "Match", "Game" };
        for (int i = 0; i < 7; i++) {
            if (strstr(cn, keys[i])) { hit = YES; break; }
        }
        if (!hit) continue;
        [s appendFormat:@"CLS %s\n", cn];
        void *it = NULL;
        void *fd = NULL;
        while ((fd = p_class_get_fields(cls, &it))) {
            char *tn = (p_type_get_name && p_field_get_type) ? p_type_get_name(p_field_get_type(fd)) : NULL;
            size_t off = p_field_get_offset ? p_field_get_offset(fd) : 0;
            [s appendFormat:@"  F +0x%zx %s\n", off, tn ?: "?"];
            if (tn && strstr(tn, "Dictionary")) {
                void *d = NULL;
                p_field_static_get_value(fd, &d);
                [s appendFormat:@"    -> %p ok %d\n", d, VXDictOK(d)];
            }
        }
    }
    return s;
}

static void VXShow(NSString *t) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_status) g_status.text = t.length > 160 ? [t substringToIndex:160] : t;
    });
}

static void VXUpload(NSString *txt) {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/veexdump.txt"];
    [txt writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSData *d = [txt dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://paste.rs/"]];
    r.HTTPMethod = @"POST";
    r.HTTPBody = d;
    r.timeoutInterval = 25;
    r.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    [[[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData *rd, NSURLResponse *rp, NSError *er) {
        if (!er && rd.length && rd.length < 200) {
            NSString *u = [[NSString alloc] initWithData:rd encoding:NSUTF8StringEncoding];
            VXShow([@"paste.rs/" stringByAppendingString:[u stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]);
            return;
        }
        NSString *b = @"----VXB";
        NSString *hd = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"veexdump.txt\"\r\n\r\n", b];
        NSMutableData *body = [NSMutableData data];
        [body appendData:[hd dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:d];
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", b] dataUsingEncoding:NSUTF8StringEncoding]];

        NSMutableURLRequest *r2 = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://0x0.st"]];
        r2.HTTPMethod = @"POST";
        r2.HTTPBody = body;
        r2.timeoutInterval = 25;
        [r2 setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", b] forHTTPHeaderField:@"Content-Type"];

        [[[NSURLSession sharedSession] dataTaskWithRequest:r2 completionHandler:^(NSData *rd2, NSURLResponse *rp2, NSError *er2) {
            if (!er2 && rd2.length && rd2.length < 200) {
                VXShow([[NSString alloc] initWithData:rd2 encoding:NSUTF8StringEncoding]);
            } else {
                VXShow(@"dump local en Documents");
            }
        }] resume];
    }] resume];
}

#pragma mark - aim

static void VXAimStep(void) {
    if (!g.aim || !g_ready) return;
    if (g_targets <= 0) return;

    void *cam = VXCam();
    if (!cam) return;

    CGPoint mid = CGPointMake(VXW() / 2, VXH() / 2);
    float best = g.aimFov > 0 ? g.aimFov : 400;
    void *pick = NULL;

    void *dict = VXFindDict();
    if (!dict) return;
    char *e = *(char **)((char *)dict + 0x18);
    int cnt = *(int *)((char *)dict + 0x20);

    for (int i = 0; i < cnt; i++) {
        void *ent = *(void **)(e + i * 24 + 8);
        if (!VXValidObj(ent)) continue;
        void *tr = VXTransformOf(ent);
        if (!tr) continue;
        V3 w;
        if (!VXPosOf(tr, &w)) continue;
        CGPoint p;
        if (!VXToScreen(cam, w, &p)) continue;
        float dx = p.x - mid.x;
        float dy = p.y - mid.y;
        float d = sqrtf(dx * dx + dy * dy);
        if (d < best) {
            best = d;
            pick = ent;
        }
    }

    if (!pick) {
        g_target = NULL;
        return;
    }
    g_target = pick;

    void *ptr = VXTransformOf(pick);
    if (!ptr) return;

    void *mLook = VXMethod(VXClass("UnityEngine", "Transform"), "LookAt", 1);
    if (!mLook) return;
    void *t = VXTransformOf(ptr);
    if (!t) return;

    void *args[1] = { &g_target };
    void *exc = NULL;
    p_runtime_invoke(mLook, ptr, args, &exc);
}

#pragma mark - overlay

@interface VeexDraw : UIView
@end

@implementation VeexDraw

- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e { return NO; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    if (!c) return;

    if (g.fovCircle && g.aim) {
        CGContextSetStrokeColorWithColor(c, [[UIColor colorWithWhite:1 alpha:0.5] CGColor]);
        CGContextSetLineWidth(c, 1);
        CGFloat r = g.aimFov > 0 ? g.aimFov : 160;
        CGContextStrokeEllipseInRect(c, CGRectMake(VXW() / 2 - r, VXH() / 2 - r, r * 2, r * 2));
    }

    if (g.crosshair) {
        CGContextSetStrokeColorWithColor(c, g.color.CGColor);
        CGContextSetLineWidth(c, 1);
        CGPoint m = CGPointMake(VXW() / 2, VXH() / 2);
        CGContextMoveToPoint(c, m.x - 9, m.y);
        CGContextAddLineToPoint(c, m.x - 3, m.y);
        CGContextMoveToPoint(c, m.x + 3, m.y);
        CGContextAddLineToPoint(c, m.x + 9, m.y);
        CGContextMoveToPoint(c, m.x, m.y - 9);
        CGContextAddLineToPoint(c, m.x, m.y - 3);
        CGContextMoveToPoint(c, m.x, m.y + 3);
        CGContextAddLineToPoint(c, m.x, m.y + 9);
        CGContextStrokePath(c);
    }

    if (!g.esp || !g_ready) return;

    void *cam = VXCam();
    if (!cam) {
        g_status.text = @"cam null";
        return;
    }

    void *dict = VXFindDict();
    if (!dict) {
        g_status.text = @"sin dict";
        return;
    }

    char *e = *(char **)((char *)dict + 0x18);
    int cnt = *(int *)((char *)dict + 0x20);
    if (!VXPtr(e) || cnt <= 0) {
        g_status.text = [NSString stringWithFormat:@"r mal n=%d", cnt];
        return;
    }

    V3 camPos;
    void *camTr = VXTransformOf(cam);
    BOOL hasCam = camTr ? VXPosOf(camTr, &camPos) : NO;

    NSInteger drawn = 0;
    CGContextSetLineWidth(c, 1.1);
    CGContextSetStrokeColorWithColor(c, g.color.CGColor);

    for (int i = 0; i < cnt; i++) {
        void *ent = *(void **)(e + i * 24 + 8);
        if (!VXValidObj(ent)) ent = *(void **)(e + i * 16 + 8);
        if (!VXValidObj(ent)) continue;

        void *tr = VXTransformOf(ent);
        if (!tr) continue;
        V3 w;
        if (!VXPosOf(tr, &w)) continue;
        CGPoint p;
        if (!VXToScreen(cam, w, &p)) continue;
        if (p.x < -80 || p.x > VXW() + 80) continue;
        if (p.y < -80 || p.y > VXH() + 80) continue;

        float dist = hasCam ? VXDistTo(camPos, w) : 0;
        CGFloat h = 2400.0 / (dist > 1 ? dist : 1);
        if (h < 14) h = 14;
        if (h > 260) h = 260;
        CGFloat bw = h * 0.42;
        if (g.boxW > 0) bw = g.boxW;
        if (g.boxH > 0) h = g.boxH;
        CGRect box = CGRectMake(p.x - bw / 2, p.y - h, bw, h);

        if (g.espBits & (1 << VXEspBox)) {
            CGContextStrokeRect(c, box);
            CGContextStrokeRect(c, CGRectInset(box, -1.5, -1.5));
        }

        if (g.espBits & (1 << VXEspLine)) {
            CGContextMoveToPoint(c, VXW() / 2, VXH() - 42);
            CGContextAddLineToPoint(c, p.x, p.y);
            CGContextStrokePath(c);
        }

        if (g.espBits & (1 << VXEspBone)) {
            CGPoint pts[24];
            BOOL ok[24];
            for (int b = 0; b < 24; b++) {
                ok[b] = NO;
                void *ct = VXChild(tr, b);
                if (!ct) continue;
                V3 bw2;
                if (!VXPosOf(ct, &bw2)) continue;
                ok[b] = VXToScreen(cam, bw2, &pts[b]);
            }
            const int pair[][2] = {
                {0,1},{1,2},{2,3},{3,4},{2,5},{5,6},{6,7},{2,8},{8,9},{9,10},
                {2,11},{11,12},{12,13},{11,14},{14,15},{15,16},{11,17},{17,18},{18,19}
            };
            for (int b = 0; b < (int)(sizeof(pair) / sizeof(*pair)); b++) {
                int a1 = pair[b][0], a2 = pair[b][1];
                if (a1 > 23 || a2 > 23) continue;
                if (!ok[a1] || !ok[a2]) continue;
                CGContextMoveToPoint(c, pts[a1].x, pts[a1].y);
                CGContextAddLineToPoint(c, pts[a2].x, pts[a2].y);
                CGContextStrokePath(c);
            }
        }

        if (g.espBits & (1 << VXEspHp)) {
            float hp = 0;
            if (VXHpOf(ent, &hp) && hp > 0) {
                CGFloat pct = hp / 200.0;
                if (pct > 1) pct = 1;
                CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:0.15 alpha:1] CGColor]);
                CGContextFillRect(c, CGRectMake(box.origin.x - 5, box.origin.y, 3, h));
                CGContextSetFillColorWithColor(c, [[UIColor greenColor] CGColor]);
                CGContextFillRect(c, CGRectMake(box.origin.x - 5, box.origin.y + h * (1 - pct), 3, h * pct));
                CGContextSetStrokeColorWithColor(c, g.color.CGColor);
            }
        }

        if (g.espBits & (1 << VXEspName)) {
            const char *cn = VXClsName(ent);
            NSString *nm = cn ? [NSString stringWithUTF8String:cn] : @"ent";
            [nm drawAtPoint:CGPointMake(box.origin.x, box.origin.y - 13)
             withAttributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:9],
                               NSForegroundColorAttributeName: g.color }];
        }

        if (g.espBits & (1 << VXEspDist)) {
            NSString *ds = [NSString stringWithFormat:@"%.0fm", dist];
            [ds drawAtPoint:CGPointMake(box.origin.x, box.origin.y + h + 2)
             withAttributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:9],
                               NSForegroundColorAttributeName: g.color }];
        }

        drawn++;
    }

    g_entities = drawn;
    if (g.diag) {
        snprintf(g_dbg, sizeof(g_dbg), "cnt %d dib %ld cls %s",
                 cnt, (long)drawn, g_dictCls && p_class_get_name ? p_class_get_name(g_dictCls) : "?");
        [[NSString stringWithUTF8String:g_dbg] drawAtPoint:CGPointMake(12, VXH() * 0.5)
            withAttributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:12],
                              NSForegroundColorAttributeName: [UIColor whiteColor] }];
    }
}

@end

#pragma mark - panel

@interface VeexPanel : UIView <UIScrollViewDelegate>
- (void)tick;
- (void)bubbleTapped;
- (void)drag:(UIPanGestureRecognizer *)p;
- (void)onChip:(UIButton *)b;
- (void)onSlider:(UISlider *)s;
- (void)onColor:(UIButton *)b;
- (void)doDump;
- (void)doReset;
- (void)doBoot;
- (void)paint:(UIButton *)b;
@end

@implementation VeexPanel

- (BOOL)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (!g_bubble || !g_panel) return YES;
    CGRect b = [g_bubble convertRect:g_bubble.bounds toView:self];
    if (CGRectContainsPoint(CGRectInset(b, -18, -18), p)) return YES;
    CGRect q = [g_panel convertRect:g_panel.bounds toView:self];
    if (CGRectContainsPoint(q, p)) return YES;
    return NO;
}

- (UILabel *)label:(NSString *)t size:(CGFloat)s color:(UIColor *)c y:(CGFloat)y {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, y, 272, s + 6)];
    l.text = t;
    l.textColor = c;
    l.font = [UIFont fontWithName:@"Menlo-Bold" size:s] ?: [UIFont boldSystemFontOfSize:s];
    return l;
}

- (UIButton *)chip:(NSString *)t x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w tag:(NSInteger)tag {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, w, 30);
    [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11] ?: [UIFont boldSystemFontOfSize:11];
    b.layer.cornerRadius = 6;
    b.layer.borderWidth = 1;
    b.tag = tag;
    [b addTarget:self action:@selector(onChip:) forControlEvents:UIControlEventTouchUpInside];
    [self paint:b];
    return b;
}

- (void)paint:(UIButton *)b {
    BOOL on = NO;
    switch (b.tag) {
        case 101: on = g.esp; break;
        case 102: on = (g.espBits & (1 << VXEspBox)) != 0; break;
        case 103: on = (g.espBits & (1 << VXEspBone)) != 0; break;
        case 104: on = (g.espBits & (1 << VXEspName)) != 0; break;
        case 105: on = (g.espBits & (1 << VXEspHp)) != 0; break;
        case 106: on = (g.espBits & (1 << VXEspDist)) != 0; break;
        case 107: on = (g.espBits & (1 << VXEspLine)) != 0; break;
        case 108: on = g.aim; break;
        case 109: on = g.fovCircle; break;
        case 110: on = g.crosshair; break;
        case 111: on = g.diag; break;
        case 112: on = g.silent; break;
        default: break;
    }
    b.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1];
    b.layer.borderColor = (on ? g_accent : [UIColor colorWithWhite:0.30 alpha:1]).CGColor;
    [b setTitleColor:(on ? g_accent : [UIColor colorWithWhite:0.90 alpha:1]) forState:UIControlStateNormal];
}

- (void)onChip:(UIButton *)b {
    switch (b.tag) {
        case 101:
            g.esp = !g.esp;
            if (g.esp) [self doBoot];
            break;
        case 102: g.espBits ^= (1 << VXEspBox); break;
        case 103: g.espBits ^= (1 << VXEspBone); break;
        case 104: g.espBits ^= (1 << VXEspName); break;
        case 105: g.espBits ^= (1 << VXEspHp); break;
        case 106: g.espBits ^= (1 << VXEspDist); break;
        case 107: g.espBits ^= (1 << VXEspLine); break;
        case 108:
            g.aim = !g.aim;
            if (g.aim) [self doBoot];
            break;
        case 109: g.fovCircle = !g.fovCircle; break;
        case 110: g.crosshair = !g.crosshair; break;
        case 111: g.diag = !g.diag; break;
        case 112: g.silent = !g.silent; break;
        case 113: [self doDump]; break;
        case 114: [self doReset]; break;
        case 115: g_panel.hidden = YES; break;
    }
    [self paint:b];
}

- (void)onSlider:(UISlider *)s {
    if (s.tag == 201) {
        g.fov = s.value;
        g.aimFov = s.value;
    }
    if (s.tag == 202) g.smooth = s.value;
    if (s.tag == 203) g.boxW = s.value;
    if (s.tag == 204) g.boxH = s.value;
}

- (void)onColor:(UIButton *)b {
    NSArray *hex = @[ @"#FFFFFF", @"#00FF66", @"#FF3355", @"#33AAFF", @"#FFCC00", @"#CC66FF" ];
    g.color = VXC(hex[b.tag - 301], [UIColor whiteColor]);
}

- (void)doBoot {
    if (g_ready) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VXAttach();
        if (!VXResolve()) {
            VXShow(@"sin api");
            return;
        }
        for (int i = 0; i < 60 && !g_ready; i++) {
            if (VXFindDict()) break;
            usleep(300000);
        }
        if (!g_ready) {
            if (VXPatchLoad()) VXShow(@"parche cargado");
            else VXShow(@"parche no");
        }
        dispatch_async(dispatch_get_main_queue(), ^{ g_ready = YES; });
    });
}

- (void)doDump {
    VXShow(@"dump...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VXAttach();
        VXUpload(VXReport());
    });
}

- (void)doReset {
    VXShow(@"reset...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VXResetGuest();
        usleep(600000);
        VXShow(@"listo, cierra el juego");
    });
}

- (void)tick {
    if (!g_hidOnce) {
        g_hidOnce = YES;
        ptrace(PT_DENY_ATTACH, 0, 0, 0);
    }
    g_frames++;
    if (g_draw) [g_draw setNeedsDisplay];
    if (g.aim) VXAimStep();

    CFTimeInterval now = CACurrentMediaTime();
    if (now - g_last >= 0.5) {
        g_last = now;
        if (g_fps) g_fps.text = [NSString stringWithFormat:@"%ld", (long)g_entities];
    }
}

- (void)bubbleTapped { g_panel.hidden = !g_panel.hidden; }

- (void)drag:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:self];
    CGPoint c = g_bubble.center;
    g_bubble.center = CGPointMake(c.x + t.x, c.y + t.y);
    [p setTranslation:CGPointZero inView:self];
}

- (void)closePanel { g_panel.hidden = YES; }

@end

#pragma mark - construccion

static void VXBuildMenu(void) {
    if (g_built) return;
    g_built = YES;

    g_accent = [UIColor greenColor];
    g.color = [UIColor whiteColor];
    g.bg = [UIColor colorWithWhite:0.05 alpha:0.97];
    g.line = [UIColor colorWithWhite:0.28 alpha:1];
    g.espBits = (1 << VXEspBox) | (1 << VXEspName) | (1 << VXEspDist);
    g.fov = 160;
    g.aimFov = 160;
    g.smooth = 0.35;
    g.boxW = 0;
    g.boxH = 0;

    UIWindow *w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    w.windowLevel = UIWindowLevelAlert + 1;
    w.backgroundColor = [UIColor clearColor];
    w.rootViewController = [[UIViewController alloc] init];
    w.hidden = NO;
    g_win = w;

    g_draw = [[VeexDraw alloc] initWithFrame:[UIScreen mainScreen].bounds];
    g_draw.backgroundColor = [UIColor clearColor];
    g_draw.userInteractionEnabled = NO;
    [w addSubview:g_draw];

    VeexPanel *host = [[VeexPanel alloc] initWithFrame:[UIScreen mainScreen].bounds];
    host.backgroundColor = [UIColor clearColor];
    [w addSubview:host];

    g_bubble = [[UIView alloc] initWithFrame:CGRectMake(14, 130, 46, 46)];
    g_bubble.backgroundColor = [UIColor colorWithWhite:0.07 alpha:0.94];
    g_bubble.layer.cornerRadius = 23;
    g_bubble.layer.borderWidth = 1;
    g_bubble.layer.borderColor = g.line.CGColor;
    UILabel *vl = [[UILabel alloc] initWithFrame:g_bubble.bounds];
    vl.text = @"VX";
    vl.textAlignment = NSTextAlignmentCenter;
    vl.textColor = [UIColor whiteColor];
    vl.font = [UIFont fontWithName:@"Menlo-Bold" size:15] ?: [UIFont boldSystemFontOfSize:15];
    [g_bubble addSubview:vl];
    [host addSubview:g_bubble];

    [g_bubble addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:host action:@selector(bubbleTapped)]];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:host action:@selector(drag:)];
    [g_bubble addGestureRecognizer:pan];

    CGFloat pw = 306, ph = VXH() - 180;
    g_panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, ph)];
    g_panel.center = CGPointMake(VXW() / 2, VXH() / 2);
    g_panel.backgroundColor = g.bg;
    g_panel.layer.cornerRadius = 12;
    g_panel.layer.borderWidth = 1;
    g_panel.layer.borderColor = g.line.CGColor;
    g_panel.hidden = YES;
    [host addSubview:g_panel];

    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, 52)];
    head.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    [g_panel addSubview:head];

    UILabel *t1 = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, 180, 22)];
    t1.text = @"Veex";
    t1.textColor = [UIColor whiteColor];
    t1.font = [UIFont fontWithName:@"Menlo-Bold" size:17] ?: [UIFont boldSystemFontOfSize:17];
    [head addSubview:t1];

    UILabel *t2 = [[UILabel alloc] initWithFrame:CGRectMake(14, 29, 220, 14)];
    t2.text = @"BY LEVI · t.me/levibrouh";
    t2.textColor = [UIColor colorWithWhite:0.52 alpha:1];
    t2.font = [UIFont fontWithName:@"Menlo" size:9] ?: [UIFont systemFontOfSize:9];
    [head addSubview:t2];

    g_fps = [[UILabel alloc] initWithFrame:CGRectMake(pw - 74, 10, 34, 16)];
    g_fps.text = @"0";
    g_fps.textAlignment = NSTextAlignmentRight;
    g_fps.textColor = g_accent;
    g_fps.font = [UIFont fontWithName:@"Menlo-Bold" size:12] ?: [UIFont boldSystemFontOfSize:12];
    [head addSubview:g_fps];

    UIButton *x = [UIButton buttonWithType:UIButtonTypeSystem];
    x.frame = CGRectMake(pw - 34, 8, 26, 26);
    [x setTitle:@"×" forState:UIControlStateNormal];
    [x setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    x.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    x.tag = 115;
    [x addTarget:host action:@selector(onChip:) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:x];

    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 52, pw, ph - 52)];
    sv.showsVerticalScrollIndicator = NO;
    sv.contentSize = CGSizeMake(pw, 760);
    [g_panel addSubview:sv];

    CGFloat y = 10;
    [sv addSubview:[host label:@"VISUAL" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]];
    y += 20;

    NSArray *chips = @[@"ESP", @"CAJA", @"HUESOS", @"NOMBRE", @"VIDA", @"DIST", @"LINEA"];
    CGFloat cx = 14;
    for (NSInteger i = 0; i < chips.count; i++) {
        CGFloat wd = 72;
        if (cx + wd > pw - 14) { cx = 14; y += 36; }
        [sv addSubview:[host chip:chips[i] x:cx y:y w:wd tag:101 + i]];
        cx += wd + 8;
    }
    y += 44;

    [sv addSubview:[host label:@"APUNTADO" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]];
    y += 20;
    cx = 14;
    NSArray *achips = @[@"AIM", @"FOV", @"MIRA", @"DIAG", @"SILENT"];
    for (NSInteger i = 0; i < achips.count; i++) {
        CGFloat wd = 72;
        if (cx + wd > pw - 14) { cx = 14; y += 36; }
        [sv addSubview:[host chip:achips[i] x:cx y:y w:wd tag:108 + i]];
        cx += wd + 8;
    }
    y += 44;

    [sv addSubview:[host label:@"FOV" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]];
    UISlider *sf = [[UISlider alloc] initWithFrame:CGRectMake(14, y + 16, pw - 28, 26)];
    sf.minimumValue = 40;
    sf.maximumValue = 700;
    sf.value = g.aimFov;
    sf.tag = 201;
    [sf addTarget:host action:@selector(onSlider:) forControlEvents:UIControlEventValueChanged];
    [sv addSubview:sf];
    y += 52;

    [sv addSubview:[host label:@"SUAVIDAD" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]];
    UISlider *ss = [[UISlider alloc] initWithFrame:CGRectMake(14, y + 16, pw - 28, 26)];
    ss.minimumValue = 0.02;
    ss.maximumValue = 1;
    ss.value = g.smooth;
    ss.tag = 202;
    [ss addTarget:host action:@selector(onSlider:) forControlEvents:UIControlEventValueChanged];
    [sv addSubview:ss];
    y += 52;

    [sv addSubview:[host label:@"COLOR" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]];
    y += 20;
    NSArray *hex = @[ @"#FFFFFF", @"#00FF66", @"#FF3355", @"#33AAFF", @"#FFCC00", @"#CC66FF" ];
    for (NSInteger i = 0; i < hex.count; i++) {
        UIButton *cb = [UIButton buttonWithType:UIButtonTypeSystem];
        cb.frame = CGRectMake(14 + i * 40, y, 30, 30);
        cb.backgroundColor = VXC(hex[i], [UIColor whiteColor]);
        cb.layer.cornerRadius = 15;
        cb.layer.borderWidth = 1;
        cb.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:1].CGColor;
        cb.tag = 301 + i;
        [cb addTarget:host action:@selector(onColor:) forControlEvents:UIControlEventTouchUpInside];
        [sv addSubview:cb];
    }
    y += 42;

    [sv addSubview:[host label:@"SISTEMA" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]];
    y += 20;
    [sv addSubview:[host chip:@"DUMP" x:14 y:y w:100 tag:113]];
    [sv addSubview:[host chip:@"RESET GUEST" x:122 y:y w:130 tag:114]];
    y += 40;

    g_status = [[UILabel alloc] initWithFrame:CGRectMake(14, y, pw - 28, 60)];
    g_status.text = @"listo";
    g_status.numberOfLines = 0;
    g_status.textColor = [UIColor colorWithWhite:0.72 alpha:1];
    g_status.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    [sv addSubview:g_status];
    y += 66;

    sv.contentSize = CGSizeMake(pw, y + 20);

    g_link = [CADisplayLink displayLinkWithTarget:host selector:@selector(tick)];
    [g_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

#pragma mark - arranque

__attribute__((constructor)) static void VXInit(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (int i = 0; i < 900; i++) {
            __block BOOL up = NO;
            dispatch_sync(dispatch_get_main_queue(), ^{
                UIApplication *a = [UIApplication sharedApplication];
                up = a != nil && a.windows.count > 0;
            });
            if (up) break;
            usleep(200000);
        }
        dispatch_async(dispatch_get_main_queue(), ^{ VXBuildMenu(); });
    });
}
