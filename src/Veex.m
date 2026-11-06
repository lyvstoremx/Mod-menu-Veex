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
#import <math.h>

#pragma mark - tipos

typedef struct { float x, y, z; } V3;

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
    BOOL fovCircle;
    BOOL crosshair;
    NSInteger espBits;
    float aimFov;
    UIColor *color;
    UIColor *bg;
    UIColor *line;
} VXConf;

#pragma mark - globales

static VXConf g;
static BOOL g_built;
static BOOL g_ready;
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
static void *g_camCls;
static void *g_camMain;
static void *g_w2s;
static char g_dbg[200];
static CFTimeInterval g_last;

static void *g_facadeCls;
static void *g_matchM;
static void *g_localM;
static void *g_playersM;
static size_t g_neck, g_armL, g_armR, g_handL, g_handR, g_footL, g_footR;

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
static void *(*p_class_get_methods)(void *, void **);
static void *(*p_field_get_type)(void *);
static char *(*p_type_get_name)(void *);
static char *(*p_class_get_name)(void *);
static char *(*p_field_get_name)(void *);
static void *(*p_object_get_class)(void *);
static void *(*p_array_new)(void *, size_t);
static size_t (*p_image_class_count)(void *);
static void *(*p_image_get_class)(void *, size_t);
static void *(*p_thread_attach)(void *);
static size_t (*p_field_get_offset)(void *);
static void *(*p_method_get_return_type)(void *);
static uint32_t (*p_method_get_param_count)(void *);

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
    p_class_get_methods = VXS("il2cpp_class_get_methods");
    p_field_get_type = VXS("il2cpp_field_get_type");
    p_type_get_name = VXS("il2cpp_type_get_name");
    p_class_get_name = VXS("il2cpp_class_get_name");
    p_field_get_name = VXS("il2cpp_field_get_name");
    p_object_get_class = VXS("il2cpp_object_get_class");
    p_array_new = VXS("il2cpp_array_new");
    p_thread_attach = VXS("il2cpp_thread_attach");
    p_field_get_offset = VXS("il2cpp_field_get_offset");
    p_method_get_return_type = VXS("il2cpp_method_get_return_type");
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

static void *VXInvoke0(void *m, void *self) {
    if (!m) return NULL;
    void *e = NULL;
    void *r = p_runtime_invoke(m, self, NULL, &e);
    if (!r || e || !VXPtr(r)) return NULL;
    return r;
}

#pragma mark - entidades

static void *VXFacade(void) {
    if (!g_facadeCls) g_facadeCls = VXClass("COW", "GameFacade");
    return g_facadeCls;
}

static void *VXMatch(void) {
    void *f = VXFacade();
    if (!f) return NULL;
    if (!g_matchM) g_matchM = VXMethod(f, "CurrentMatch", 0);
    return VXInvoke0(g_matchM, NULL);
}

static void *VXLocal(void) {
    void *f = VXFacade();
    if (!f) return NULL;
    if (!g_localM) g_localM = VXMethod(f, "CurrentLocalPlayer", 0);
    return VXInvoke0(g_localM, NULL);
}

static void *VXPlayersMethod(void *match) {
    if (!match) return NULL;
    if (g_playersM) return g_playersM;
    void *cls = VXClsOf(match);
    if (!cls) return NULL;
    void *it = NULL;
    void *m = NULL;
    while ((m = p_class_get_methods(cls, &it))) {
        if (p_method_get_param_count && p_method_get_param_count(m) != 0) continue;
        char *tn = (p_method_get_return_type && p_type_get_name)
                   ? p_type_get_name(p_method_get_return_type(m)) : NULL;
        if (!tn) continue;
        if (!strstr(tn, "Player")) continue;
        if (!strstr(tn, "List")) continue;
        g_playersM = m;
        return m;
    }
    return NULL;
}

static void *VXPlayers(void *match) {
    void *m = VXPlayersMethod(match);
    if (!m) return NULL;
    void *e = NULL;
    void *r = p_runtime_invoke(m, match, NULL, &e);
    if (!r || e || !VXPtr(r)) return NULL;
    return r;
}

static int VXCount(void *list) {
    if (!list) return 0;
    void *m = VXMethod(VXClsOf(list), "get_Count", 0);
    void *r = VXInvoke0(m, list);
    if (!r) return 0;
    int32_t v = 0;
    memcpy(&v, (char *)r + 16, 4);
    return (v > 0 && v < 128) ? v : 0;
}

static void *VXItem(void *list, int i) {
    if (!list) return NULL;
    void *m = VXMethod(VXClsOf(list), "get_Item", 1);
    if (!m) return NULL;
    int32_t a = i;
    void *args[1] = { &a };
    void *e = NULL;
    void *r = p_runtime_invoke(m, list, args, &e);
    if (!r || e || !VXPtr(r)) return NULL;
    return r;
}

static void VXBoneOffsets(void) {
    if (g_neck) return;
    void *cls = VXClass("COW.GamePlay", "Player");
    if (!cls || !p_field_get_name || !p_field_get_offset) return;
    const char *n[] = { "NeckBone", "ArmBoneLeft", "ArmBoneRight",
                        "HandBoneLeft", "HandBoneRight", "FootBoneLeft", "FootBoneRight" };
    size_t *dst[] = { &g_neck, &g_armL, &g_armR, &g_handL, &g_handR, &g_footL, &g_footR };
    void *it = NULL;
    void *fd = NULL;
    while ((fd = p_class_get_fields(cls, &it))) {
        char *nm = p_field_get_name(fd);
        if (!nm) continue;
        for (int k = 0; k < 7; k++) {
            if (strcmp(nm, n[k]) == 0) *dst[k] = p_field_get_offset(fd);
        }
    }
}

static void *VXBone(void *player, size_t off) {
    if (!off || !VXValidObj(player)) return NULL;
    void *t = *(void **)((char *)player + off);
    return VXPtr(t) ? t : NULL;
}

#pragma mark - camara y transform

static void *VXCam(void) {
    if (!g_camCls) g_camCls = VXClass("UnityEngine", "Camera");
    if (!g_camCls) return NULL;
    if (!g_camMain) g_camMain = VXMethod(g_camCls, "get_main", 0);
    if (!g_camMain) return NULL;
    void *e = NULL;
    void *cam = p_runtime_invoke(g_camMain, NULL, NULL, &e);
    if (!cam || e || !VXPtr(cam)) return NULL;
    return cam;
}

static void *VXTransformOf(void *obj) {
    if (!VXValidObj(obj)) return NULL;
    void *m = VXMethod(VXClsOf(obj), "get_transform", 0);
    return VXInvoke0(m, obj);
}

static BOOL VXPosOf(void *tr, V3 *out) {
    if (!VXValidObj(tr)) return NO;
    void *m = VXMethod(VXClsOf(tr), "get_position", 0);
    void *r = VXInvoke0(m, tr);
    if (!r) return NO;
    memcpy(out, (char *)r + 16, sizeof(V3));
    return YES;
}

static BOOL VXToScreen(void *cam, V3 w, CGPoint *out) {
    if (!cam) return NO;
    if (!g_w2s) g_w2s = VXMethod(VXClsOf(cam), "WorldToScreenPoint", 1);
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

#pragma mark - dump

static NSString *VXReport(void) {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"VEEX\n"];
    void *facade = VXFacade();
    [s appendFormat:@"facade %p\n", facade];
    void *m = VXMatch();
    [s appendFormat:@"match %p\n", m];
    if (m) {
        void *pm = VXPlayersMethod(m);
        [s appendFormat:@"listaMetodo %p\n", pm];
        void *pl = VXPlayers(m);
        [s appendFormat:@"lista %p n=%d\n", pl, VXCount(pl)];
        if (pl) {
            void *p = VXItem(pl, 0);
            [s appendFormat:@"item0 %p\n", p];
            if (p) {
                char *cn = p_class_get_name ? p_class_get_name(VXClsOf(p)) : NULL;
                [s appendFormat:@"item0Cls %s\n", cn ?: "?"];
            }
        }
    }
    return s;
}

static void VXShow(NSString *t) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_status) g_status.text = t.length > 200 ? [t substringToIndex:200] : t;
    });
}

#pragma mark - aim

static void VXAimStep(void) {
    if (!g.aim || !g_ready) return;
    void *cam = VXCam();
    if (!cam) return;
    void *match = VXMatch();
    if (!match) return;
    void *list = VXPlayers(match);
    int cnt = VXCount(list);
    if (cnt <= 0) return;
    void *local = VXLocal();

    CGPoint mid = CGPointMake(VXW() / 2, VXH() / 2);
    float best = g.aimFov > 0 ? g.aimFov : 400;
    void *pick = NULL;

    for (int i = 0; i < cnt; i++) {
        void *p = VXItem(list, i);
        if (!p || p == local) continue;
        void *tr = VXTransformOf(p);
        if (!tr) continue;
        V3 w;
        if (!VXPosOf(tr, &w)) continue;
        CGPoint sp;
        if (!VXToScreen(cam, w, &sp)) continue;
        float dx = sp.x - mid.x;
        float dy = sp.y - mid.y;
        float d = sqrtf(dx * dx + dy * dy);
        if (d < best) {
            best = d;
            pick = p;
        }
    }
    if (!pick) return;

    void *hm = VXMethod(VXClsOf(pick), "GetHeadTF", 0);
    void *head = VXInvoke0(hm, pick);
    void *root = VXTransformOf(pick);
    if (!root || !head) return;
    void *mLook = VXMethod(VXClass("UnityEngine", "Transform"), "LookAt", 1);
    if (!mLook) return;
    void *args[1] = { &head };
    void *exc = NULL;
    p_runtime_invoke(mLook, root, args, &exc);
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
    void *match = VXMatch();
    if (!match) {
        g_status.text = @"sin match";
        return;
    }
    void *players = VXPlayers(match);
    if (!players) {
        g_status.text = @"sin lista";
        return;
    }
    int cnt = VXCount(players);
    if (cnt <= 0) {
        g_status.text = @"lista vacia";
        return;
    }

    void *local = VXLocal();
    void *localTr = local ? VXTransformOf(local) : NULL;
    V3 localPos;
    BOOL hasLocal = localTr ? VXPosOf(localTr, &localPos) : NO;

    VXBoneOffsets();

    NSInteger drawn = 0;
    CGContextSetLineWidth(c, 1.2);
    CGContextSetStrokeColorWithColor(c, g.color.CGColor);

    for (int i = 0; i < cnt; i++) {
        void *p = VXItem(players, i);
        if (!p || p == local) continue;

        void *vm = VXMethod(VXClsOf(p), "IsVisible", 0);
        if (vm) {
            void *r = VXInvoke0(vm, p);
            if (r) {
                uint8_t v = 0;
                memcpy(&v, (char *)r + 16, 1);
                if (!v) continue;
            }
        }

        void *tr = VXTransformOf(p);
        if (!tr) continue;
        V3 hip;
        if (!VXPosOf(tr, &hip)) continue;
        float dist = hasLocal ? VXDistTo(localPos, hip) : 0;
        if (hasLocal && dist > 150) continue;

        void *hm = VXMethod(VXClsOf(p), "GetHeadTF", 0);
        void *head = VXInvoke0(hm, p);
        if (!head) continue;

        V3 feetW = { hip.x, hip.y - 0.85f, hip.z };
        V3 headW = { hip.x, hip.y + 0.95f, hip.z };
        CGPoint fs, hs;
        if (!VXToScreen(cam, feetW, &fs)) continue;
        if (!VXToScreen(cam, headW, &hs)) continue;

        CGFloat rawH = fabs(hs.y - fs.y);
        if (rawH < 2) continue;
        CGFloat h = rawH * 0.85f;
        CGFloat bw = rawH * 0.5f;
        CGRect box = CGRectMake(hs.x - bw / 2, hs.y - rawH * 0.15f, bw, h);

        if (g.espBits & (1 << VXEspBox)) {
            CGContextStrokeRect(c, box);
            CGContextStrokeRect(c, CGRectInset(box, -1.5, -1.5));
        }
        if (g.espBits & (1 << VXEspLine)) {
            CGContextMoveToPoint(c, VXW() / 2, VXH() - 42);
            CGContextAddLineToPoint(c, box.origin.x + bw / 2, box.origin.y + h);
            CGContextStrokePath(c);
        }
        if (g.espBits & (1 << VXEspBone)) {
            CGPoint nk, aL, aR, hL, hR, fL, fR;
            V3 w2;
            void *bt = NULL;
            BOOL okN = NO, okL = NO, okR = NO, okHL = NO, okHR = NO, okFL = NO, okFR = NO;
            bt = VXBone(p, g_neck); okN = bt && VXPosOf(bt, &w2) && VXToScreen(cam, w2, &nk);
            bt = VXBone(p, g_armL); okL = bt && VXPosOf(bt, &w2) && VXToScreen(cam, w2, &aL);
            bt = VXBone(p, g_armR); okR = bt && VXPosOf(bt, &w2) && VXToScreen(cam, w2, &aR);
            bt = VXBone(p, g_handL); okHL = bt && VXPosOf(bt, &w2) && VXToScreen(cam, w2, &hL);
            bt = VXBone(p, g_handR); okHR = bt && VXPosOf(bt, &w2) && VXToScreen(cam, w2, &hR);
            bt = VXBone(p, g_footL); okFL = bt && VXPosOf(bt, &w2) && VXToScreen(cam, w2, &fL);
            bt = VXBone(p, g_footR); okFR = bt && VXPosOf(bt, &w2) && VXToScreen(cam, w2, &fR);

            void (^seg)(CGPoint, BOOL, CGPoint, BOOL) = ^(CGPoint a, BOOL oka, CGPoint b, BOOL okb) {
                if (!oka || !okb) return;
                CGContextMoveToPoint(c, a.x, a.y);
                CGContextAddLineToPoint(c, b.x, b.y);
                CGContextStrokePath(c);
            };
            seg(hs, YES, nk, okN);
            seg(nk, okN, aL, okL);
            seg(nk, okN, aR, okR);
            seg(aL, okL, hL, okHL);
            seg(aR, okR, hR, okHR);
            seg(nk, okN, fs, YES);
            seg(fs, YES, fL, okFL);
            seg(fs, YES, fR, okFR);
        }
        if (g.espBits & (1 << VXEspHp)) {
            void *hc = VXMethod(VXClsOf(p), "get_CurHP", 0);
            void *mc = VXMethod(VXClsOf(p), "get_MaxHP", 0);
            void *rh = VXInvoke0(hc, p);
            void *rm = VXInvoke0(mc, p);
            if (rh && rm) {
                int32_t hpv = 0, mxv = 100;
                memcpy(&hpv, (char *)rh + 16, 4);
                memcpy(&mxv, (char *)rm + 16, 4);
                if (mxv > 0) {
                    CGFloat pct = (CGFloat)hpv / (CGFloat)mxv;
                    if (pct < 0) pct = 0;
                    if (pct > 1) pct = 1;
                    CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:0.15 alpha:1] CGColor]);
                    CGContextFillRect(c, CGRectMake(box.origin.x - 6, box.origin.y, 3, h));
                    CGContextSetFillColorWithColor(c, [[UIColor greenColor] CGColor]);
                    CGContextFillRect(c, CGRectMake(box.origin.x - 6, box.origin.y + h * (1 - pct), 3, h * pct));
                    CGContextSetStrokeColorWithColor(c, g.color.CGColor);
                }
            }
        }
        if (g.espBits & (1 << VXEspName)) {
            [@"enemigo" drawAtPoint:CGPointMake(box.origin.x, box.origin.y - 12)
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
        snprintf(g_dbg, sizeof(g_dbg), "n %d dib %ld", cnt, (long)drawn);
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
        default: break;
    }
    b.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1];
    b.layer.borderColor = (on ? g_accent : [UIColor colorWithWhite:0.30 alpha:1]).CGColor;
    [b setTitleColor:(on ? g_accent : [UIColor colorWithWhite:0.90 alpha:1]) forState:UIControlStateNormal];
}

- (void)onChip:(UIButton *)b {
    switch (b.tag) {
        case 101: g.esp = !g.esp; if (g.esp) [self doBoot]; break;
        case 102: g.espBits ^= (1 << VXEspBox); break;
        case 103: g.espBits ^= (1 << VXEspBone); break;
        case 104: g.espBits ^= (1 << VXEspName); break;
        case 105: g.espBits ^= (1 << VXEspHp); break;
        case 106: g.espBits ^= (1 << VXEspDist); break;
        case 107: g.espBits ^= (1 << VXEspLine); break;
        case 108: g.aim = !g.aim; if (g.aim) [self doBoot]; break;
        case 109: g.fovCircle = !g.fovCircle; break;
        case 110: g.crosshair = !g.crosshair; break;
        case 111: g.diag = !g.diag; break;
        case 112: [self doDump]; break;
        case 113: g_panel.hidden = YES; break;
    }
    [self paint:b];
}

- (void)onSlider:(UISlider *)s {
    if (s.tag == 201) g.aimFov = s.value;
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
        dispatch_async(dispatch_get_main_queue(), ^{ g_ready = YES; });
    });
}

- (void)doDump {
    VXShow(@"dump...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VXAttach();
        VXShow(VXReport());
    });
}

- (void)tick {
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

@end

#pragma mark - construccion

static void VXBuildMenu(void) {
    if (g_built) return;
    g_built = YES;

    g_accent = [UIColor greenColor];
    g.color = [UIColor whiteColor];
    g.bg = [UIColor colorWithWhite:0.05 alpha:0.97];
    g.line = [UIColor colorWithWhite:0.28 alpha:1];
    g.espBits = (1 << VXEspBox) | (1 << VXEspDist);
    g.aimFov = 160;

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
    [g_bubble addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:host action:@selector(drag:)]];

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
    x.tag = 113;
    [x addTarget:host action:@selector(onChip:) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:x];

    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 52, pw, ph - 52)];
    sv.showsVerticalScrollIndicator = NO;
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
    NSArray *achips = @[@"AIM", @"FOV", @"MIRA", @"DIAG"];
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
    [sv addSubview:[host chip:@"ESTADO" x:14 y:y w:100 tag:112]];
    y += 40;

    g_status = [[UILabel alloc] initWithFrame:CGRectMake(14, y, pw - 28, 80)];
    g_status.text = @"listo";
    g_status.numberOfLines = 0;
    g_status.textColor = [UIColor colorWithWhite:0.72 alpha:1];
    g_status.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    [sv addSubview:g_status];
    y += 86;

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
