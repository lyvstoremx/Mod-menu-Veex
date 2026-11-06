//
//  Veex.m
//  Veex · BY LEVI · t.me/levibrouh
//  Free Fire 1.132.1 — offsets verificados de dump propio
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <unistd.h>
#import <stdlib.h>
#import <math.h>
#import <pthread.h>

typedef struct { float x, y, z; } V3;

typedef enum {
    VXEspBox = 1, VXEspBone = 2, VXEspName = 3, VXEspHp = 4, VXEspDist = 5, VXEspLine = 6
} VXEspBit;

typedef struct {
    BOOL esp, aim, diag, fovCircle, crosshair, thin, stream;
    NSInteger espBits;
    float aimFov;
    UIColor *color, *bg, *line;
} VXConf;

#define O_FACADE_SB      0xB8
#define O_MATCHGAME      0x8
#define O_MATCH          0x90
#define O_CAMMGR         0xD8
#define O_CAMERA         0x20
#define O_LOCAL          0xD8
#define O_LIST_A         0x158
#define O_LIST_B         0x160
#define O_LIST_C         0x570
#define O_PLAYERID       0x408
#define O_NAME           0x498
#define O_NODE_START     0x698
#define O_NODE_END       0x900
#define O_NODE_TRANSFORM 0x10

#define VXMAX 96

typedef struct {
    CGPoint head, toe;
    CGPoint nk, aL, aR, hL, hR, fL, fR;
    BOOL okN, okL, okR, okHL, okHR, okFL, okFR;
    float dist;
    int hp, maxhp;
    char name[24];
    BOOL valid;
} VXEnt;

static VXConf g;
static BOOL g_built, g_ready;
static void *g_handle;
static UIView *g_win, *g_bubble, *g_panel, *g_draw;
static UILabel *g_status, *g_fps;
static CADisplayLink *g_link;
static UIColor *g_accent;
static NSInteger g_entities;
static int g_cList, g_cBone, g_cProj, g_src;
static void *g_camCls, *g_camMain;
static char g_dbg[220];
static CFTimeInterval g_last, g_lastTouch;
static CGSize g_lastSize;

static void *g_facadeCls, *g_matchM, *g_localM, *g_w2vp, *g_getPosInj, *g_getTransform, *g_lookAt;
static int g_projMode;
static size_t g_neck, g_armL, g_armR, g_handL, g_handR, g_footL, g_footR;

static VXEnt g_snap[VXMAX];
static int g_sn;
static VXEnt g_tmp[VXMAX];
static pthread_mutex_t g_mtx = PTHREAD_MUTEX_INITIALIZER;
static dispatch_queue_t g_q;
static volatile int g_busy;

static void *(*p_domain_get)(void);
static void **(*p_domain_get_assemblies)(void *, size_t *);
static void *(*p_assembly_get_image)(void *);
static const char *(*p_image_get_name)(void *);
static void *(*p_class_from_name)(void *, const char *, const char *);
static void *(*p_class_get_method_from_name)(void *, const char *, int);
static void *(*p_runtime_invoke)(void *, void *, void **, void **);
static void *(*p_class_get_fields)(void *, void **);
static void *(*p_class_get_methods)(void *, void **);
static void *(*p_field_get_type)(void *);
static char *(*p_type_get_name)(void *);
static char *(*p_class_get_name)(void *);
static char *(*p_field_get_name)(void *);
static void *(*p_object_get_class)(void *);
static size_t (*p_image_class_count)(void *);
static void *(*p_image_get_class)(void *, size_t);
static void *(*p_thread_attach)(void *);
static size_t (*p_field_get_offset)(void *);
static void *(*p_method_get_return_type)(void *);
static uint32_t (*p_method_get_param_count)(void *);

static inline BOOL VXPtr(void *p) {
    uintptr_t v = (uintptr_t)p;
    return v > 0x100000000ULL && v < 0x2000000000ULL && (v & 7) == 0;
}

static inline CGSize VXSize(void) {
    UIWindow *w = [UIApplication sharedApplication].keyWindow;
    CGSize s = w ? w.bounds.size : [UIScreen mainScreen].bounds.size;
    if (s.width < 10 || s.height < 10) s = [UIScreen mainScreen].bounds.size;
    return s;
}

static inline CGFloat VXW(void) { return VXSize().width; }
static inline CGFloat VXH(void) { return VXSize().height; }

static void *VXS(const char *n) {
    void *p = dlsym(RTLD_DEFAULT, n);
    if (p) return p;
    return g_handle ? dlsym(g_handle, n) : NULL;
}

static UIColor *VXC(NSString *hex, UIColor *fallback) {
    if (!hex || hex.length < 6) return fallback ?: [UIColor whiteColor];
    unsigned int v = 0;
    NSScanner *s = [NSScanner scannerWithString:[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]];
    if (![s scanHexInt:&v]) return fallback ?: [UIColor whiteColor];
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0 blue:(v & 0xFF) / 255.0 alpha:1];
}

static void VXStr(void *obj, char *out, size_t cap) {
    out[0] = 0;
    if (!VXPtr(obj)) return;
    int32_t len = 0;
    memcpy(&len, (char *)obj + 0x10, 4);
    if (len <= 0 || len > 64) return;
    NSString *s = [NSString stringWithCharacters:(const unichar *)((char *)obj + 0x14) length:len];
    if (!s) return;
    strncpy(out, s.UTF8String ?: "", cap - 1);
    out[cap - 1] = 0;
}

static BOOL VXResolve(void) {
    if (p_domain_get) return YES;
    g_handle = dlopen("/usr/lib/libil2cpp.so", RTLD_NOW);
    if (!g_handle) g_handle = dlopen("libil2cpp.so", RTLD_NOW);
    if (!g_handle) {
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const char *nm = _dyld_get_image_name(i);
            if (!nm) continue;
            if (strstr(nm, "UnityFramework") || strstr(nm, "Unity")) { g_handle = dlopen(nm, RTLD_NOW); if (g_handle) break; }
        }
    }
    p_domain_get = VXS("il2cpp_domain_get");
    p_domain_get_assemblies = VXS("il2cpp_domain_get_assemblies");
    p_assembly_get_image = VXS("il2cpp_assembly_get_image");
    p_image_get_name = VXS("il2cpp_image_get_name");
    p_class_from_name = VXS("il2cpp_class_from_name");
    p_class_get_method_from_name = VXS("il2cpp_class_get_method_from_name");
    p_runtime_invoke = VXS("il2cpp_runtime_invoke");
    p_class_get_fields = VXS("il2cpp_class_get_fields");
    p_class_get_methods = VXS("il2cpp_class_get_methods");
    p_field_get_type = VXS("il2cpp_field_get_type");
    p_type_get_name = VXS("il2cpp_type_get_name");
    p_class_get_name = VXS("il2cpp_class_get_name");
    p_field_get_name = VXS("il2cpp_field_get_name");
    p_object_get_class = VXS("il2cpp_object_get_class");
    p_thread_attach = VXS("il2cpp_thread_attach");
    p_field_get_offset = VXS("il2cpp_field_get_offset");
    p_method_get_return_type = VXS("il2cpp_method_get_return_type");
    p_method_get_param_count = VXS("il2cpp_method_get_param_count");
    if (!p_domain_get || !p_domain_get_assemblies || !p_assembly_get_image || !p_class_from_name || !p_runtime_invoke) return NO;
    return YES;
}

static void VXAttach(void) {
    if (p_thread_attach && p_domain_get) { void *d = p_domain_get(); if (d) p_thread_attach(d); }
}

static void *VXAsmAt(void **as, size_t i) { if (!as || !as[i]) return NULL; return p_assembly_get_image(as[i]); }

static void *VXClass(const char *ns, const char *name) {
    if (!VXResolve()) return NULL;
    void *dom = p_domain_get(); if (!dom) return NULL;
    size_t n = 0; void **as = p_domain_get_assemblies(dom, &n); if (!as) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = VXAsmAt(as, i); if (!img) continue;
        void *c = NULL;
        if (ns && ns[0]) c = p_class_from_name(img, ns, name);
        if (!c) c = p_class_from_name(img, "", name);
        if (c) return c;
    }
    return NULL;
}

static void *VXMethod(void *cls, const char *name, int argc) { if (!cls || !p_class_get_method_from_name) return NULL; return p_class_get_method_from_name(cls, name, argc); }
static void *VXClsOf(void *obj) { if (!VXPtr(obj)) return NULL; if (p_object_get_class) return p_object_get_class(obj); return *(void **)obj; }
static BOOL VXValidObj(void *o) { if (!VXPtr(o)) return NO; return VXPtr(*(void **)o); }

static void *VXInvoke0(void *m, void *self) {
    if (!m) return NULL;
    void *e = NULL; void *r = p_runtime_invoke(m, self, NULL, &e);
    if (!r || e || !VXPtr(r)) return NULL;
    return r;
}

static void *VXMatchGame(void) {
    if (!g_facadeCls) g_facadeCls = VXClass("COW", "GameFacade");
    if (!g_facadeCls) return NULL;
    void *sb = *(void **)((char *)g_facadeCls + O_FACADE_SB);
    if (!VXPtr(sb)) return NULL;
    void *mg = *(void **)((char *)sb + O_MATCHGAME);
    return VXPtr(mg) ? mg : NULL;
}

static void *VXMatch(void) {
    void *mg = VXMatchGame(); if (!mg) return NULL;
    void *m = *(void **)((char *)mg + O_MATCH);
    if (VXPtr(m)) return m;
    if (g_facadeCls) { if (!g_matchM) g_matchM = VXMethod(g_facadeCls, "CurrentMatch", 0); return VXInvoke0(g_matchM, NULL); }
    return NULL;
}

static void *VXLocal(void) {
    void *m = VXMatch();
    if (m) { void *p = *(void **)((char *)m + O_LOCAL); if (VXPtr(p)) return p; }
    if (g_facadeCls) { if (!g_localM) g_localM = VXMethod(g_facadeCls, "CurrentLocalPlayer", 0); return VXInvoke0(g_localM, NULL); }
    return NULL;
}

static void *VXCam(void) {
    void *mg = VXMatchGame();
    if (mg) {
        void *ccm = *(void **)((char *)mg + O_CAMMGR);
        if (VXPtr(ccm)) { void *cam = *(void **)((char *)ccm + O_CAMERA); if (VXPtr(cam)) return cam; }
    }
    if (!g_camCls) g_camCls = VXClass("UnityEngine", "Camera");
    if (!g_camCls) return NULL;
    if (!g_camMain) g_camMain = VXMethod(g_camCls, "get_main", 0);
    return VXInvoke0(g_camMain, NULL);
}

static int VXFromList(void *l, void **arr, int max) {
    if (!VXPtr(l)) return 0;
    int32_t n = 0; memcpy(&n, (char *)l + 0x18, 4);
    if (n <= 0 || n > max) return 0;
    void *items = *(void **)((char *)l + 0x10);
    if (!VXPtr(items)) return 0;
    int k = 0;
    for (int i = 0; i < n && k < max; i++) {
        void *p = *(void **)((char *)items + 0x20 + i * 8);
        if (VXPtr(p)) arr[k++] = p;
    }
    return k;
}

static int VXFromDict(void *d, void **arr, int max) {
    if (!VXPtr(d)) return 0;
    int32_t n = 0; memcpy(&n, (char *)d + 0x20, 4);
    if (n <= 0 || n > max) return 0;
    void *entries = *(void **)((char *)d + 0x18);
    if (!VXPtr(entries)) return 0;
    int k = 0;
    for (int i = 0; i < n && k < max; i++) {
        void *p = *(void **)((char *)entries + 0x20 + i * 0x18 + 0x10);
        if (VXPtr(p)) arr[k++] = p;
    }
    return k;
}

static int VXTeam(void *p) {
    if (!VXValidObj(p)) return -1;
    void *id = *(void **)((char *)p + O_PLAYERID);
    if (!VXPtr(id)) return -1;
    return (int)(*(unsigned char *)((char *)id + 0x8));
}

static void VXBoneOffsets(void) {
    if (g_neck) return;
    void *cls = VXClass("COW.GamePlay", "Player");
    if (!cls || !p_field_get_name || !p_field_get_offset) return;
    const char *n[] = { "NeckBone", "ArmBoneLeft", "ArmBoneRight", "HandBoneLeft", "HandBoneRight", "FootBoneLeft", "FootBoneRight" };
    size_t *dst[] = { &g_neck, &g_armL, &g_armR, &g_handL, &g_handR, &g_footL, &g_footR };
    void *it = NULL, *fd = NULL;
    while ((fd = p_class_get_fields(cls, &it))) {
        char *nm = p_field_get_name(fd);
        if (!nm) continue;
        for (int k = 0; k < 7; k++) if (strcmp(nm, n[k]) == 0) *dst[k] = p_field_get_offset(fd);
    }
}

static void *VXTransformOf(void *obj) {
    if (!VXValidObj(obj)) return NULL;
    if (g_getTransform) { void *r = VXInvoke0(g_getTransform, obj); if (VXPtr(r)) return r; }
    return VXInvoke0(VXMethod(VXClsOf(obj), "get_transform", 0), obj);
}

static BOOL VXPosOf(void *tr, V3 *out) {
    if (!VXValidObj(tr)) return NO;
    if (g_getPosInj) {
        V3 v; memset(&v, 0, sizeof v);
        void *a[1] = { &v }; void *e = NULL;
        p_runtime_invoke(g_getPosInj, tr, a, &e);
        if (!e) { *out = v; return YES; }
    }
    void *r = VXInvoke0(VXMethod(VXClsOf(tr), "get_position", 0), tr);
    if (!r) return NO;
    memcpy(out, (char *)r + 16, sizeof(V3));
    return YES;
}

static void *VXNodeAt(void *p, int off) {
    void *node = *(void **)((char *)p + off);
    if (!VXPtr(node)) return NULL;
    void *tf = *(void **)((char *)node + O_NODE_TRANSFORM);
    return VXPtr(tf) ? tf : NULL;
}

static BOOL VXExtremeY(void *p, BOOL wantMax, void *tfOut) {
    float best = wantMax ? -1e9f : 1e9f;
    void *winner = NULL;
    for (int off = O_NODE_START; off < O_NODE_END; off += 8) {
        void *tf = VXNodeAt(p, off);
        if (!tf) continue;
        V3 pos;
        if (!VXPosOf(tf, &pos)) continue;
        if (wantMax ? (pos.y > best) : (pos.y < best)) { best = pos.y; winner = tf; }
    }
    if (winner && tfOut) *(void **)tfOut = winner;
    return winner != NULL;
}

static void *VXProjMethod(void *cam) {
    if (g_w2vp) return g_w2vp;
    void *cls = VXClsOf(cam);
    if (!cls) return NULL;
    g_w2vp = VXMethod(cls, "WorldToViewportPoint_Injected", 2); if (g_w2vp) { g_projMode = 1; return g_w2vp; }
    g_w2vp = VXMethod(cls, "WorldToViewportPoint", 1); if (g_w2vp) { g_projMode = 1; return g_w2vp; }
    g_w2vp = VXMethod(cls, "WorldToScreenPoint_Injected", 2); if (g_w2vp) { g_projMode = 2; return g_w2vp; }
    g_w2vp = VXMethod(cls, "WorldToScreenPoint", 1); if (g_w2vp) { g_projMode = 2; return g_w2vp; }
    return NULL;
}

static BOOL VXProject(V3 w, CGPoint *out, float *depth) {
    void *cam = VXCam();
    if (!cam) return NO;
    void *m = VXProjMethod(cam);
    if (!m) return NO;
    V3 vp; memset(&vp, 0, sizeof vp);
    uint32_t argc = p_method_get_param_count ? p_method_get_param_count(m) : 0;
    if (argc == 2) {
        void *a[2] = { &w, &vp }; void *e = NULL;
        p_runtime_invoke(m, cam, a, &e);
        if (e) return NO;
    } else {
        void *a[1] = { &w }; void *e = NULL;
        void *r = p_runtime_invoke(m, cam, a, &e);
        if (!r || e) return NO;
        memcpy(&vp, (char *)r + 16, sizeof(V3));
    }
    if (vp.z < 0.01f) return NO;
    if (isnan(vp.x) || isnan(vp.y)) return NO;
    if (fabsf(vp.x) > 40000.0f || fabsf(vp.y) > 40000.0f) return NO;
    CGSize s = VXSize();
    if (g_projMode == 2 || fabsf(vp.x) > 1.5f) { out->x = vp.x; out->y = s.height - vp.y; }
    else { out->x = vp.x * s.width; out->y = (1.0f - vp.y) * s.height; }
    if (depth) *depth = vp.z;
    return YES;
}

static float VXDist(V3 a, V3 b) { float dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z; return sqrtf(dx * dx + dy * dy + dz * dz); }

static int VXPass(void **arr, int cnt, void *local, V3 lpos, BOOL hasL, int lteam, BOOL useTeam) {
    int out = 0;
    for (int i = 0; i < cnt && out < VXMAX; i++) {
        void *p = arr[i];
        if (!p || p == local) continue;
        if (useTeam) {
            int team = VXTeam(p);
            if (lteam >= 0 && team >= 0 && team == lteam) continue;
        }
        void *htf = NULL, *ttf = NULL;
        if (!VXExtremeY(p, YES, &htf)) htf = VXTransformOf(p);
        if (!VXExtremeY(p, NO, &ttf)) ttf = VXTransformOf(p);
        if (!htf || !ttf) continue;
        g_cBone++;
        V3 head, toe;
        if (!VXPosOf(htf, &head)) continue;
        if (!VXPosOf(ttf, &toe)) continue;
        float dist = hasL ? VXDist(lpos, head) : 0;
        if (hasL && dist > 400.0f) continue;
        CGPoint hs, ts; float hd = 0;
        if (!VXProject(head, &hs, &hd)) continue;
        if (!VXProject(toe, &ts, NULL)) continue;
        if (hd < 0.05f) continue;
        g_cProj++;
        VXEnt *e = &g_tmp[out];
        memset(e, 0, sizeof *e);
        e->head = hs; e->toe = ts; e->dist = dist; e->hp = -1; e->maxhp = -1;
        void *nm = *(void **)((char *)p + O_NAME);
        if (!VXPtr(nm)) nm = *(void **)((char *)p + 0x490);
        if (!VXPtr(nm)) nm = *(void **)((char *)p + 0x460);
        if (VXPtr(nm)) VXStr(nm, e->name, sizeof e->name);
        void *rh = VXInvoke0(VXMethod(VXClsOf(p), "get_CurHP", 0), p);
        void *rm = VXInvoke0(VXMethod(VXClsOf(p), "get_MaxHP", 0), p);
        if (rh) memcpy(&e->hp, (char *)rh + 16, 4);
        if (rm) memcpy(&e->maxhp, (char *)rm + 16, 4);
        void *b[7];
        b[0] = g_neck ? VXNodeAt(p, (int)g_neck) : NULL;
        b[1] = g_armL ? VXNodeAt(p, (int)g_armL) : NULL;
        b[2] = g_armR ? VXNodeAt(p, (int)g_armR) : NULL;
        b[3] = g_handL ? VXNodeAt(p, (int)g_handL) : NULL;
        b[4] = g_handR ? VXNodeAt(p, (int)g_handR) : NULL;
        b[5] = g_footL ? VXNodeAt(p, (int)g_footL) : NULL;
        b[6] = g_footR ? VXNodeAt(p, (int)g_footR) : NULL;
        V3 w2;
        if (b[0] && VXPosOf(b[0], &w2)) e->okN = VXProject(w2, &e->nk, NULL);
        if (b[1] && VXPosOf(b[1], &w2)) e->okL = VXProject(w2, &e->aL, NULL);
        if (b[2] && VXPosOf(b[2], &w2)) e->okR = VXProject(w2, &e->aR, NULL);
        if (b[3] && VXPosOf(b[3], &w2)) e->okHL = VXProject(w2, &e->hL, NULL);
        if (b[4] && VXPosOf(b[4], &w2)) e->okHR = VXProject(w2, &e->hR, NULL);
        if (b[5] && VXPosOf(b[5], &w2)) e->okFL = VXProject(w2, &e->fL, NULL);
        if (b[6] && VXPosOf(b[6], &w2)) e->okFR = VXProject(w2, &e->fR, NULL);
        e->valid = YES;
        out++;
    }
    return out;
}

static void VXCollect(void) {
    if (!g_ready || !g.esp) { pthread_mutex_lock(&g_mtx); g_sn = 0; pthread_mutex_unlock(&g_mtx); return; }
    VXAttach();
    g_cBone = 0; g_cProj = 0; g_cList = 0; g_src = 0;
    void *cam = VXCam(); if (!cam) return;
    void *local = VXLocal();
    void *ltr = local ? VXTransformOf(local) : NULL;
    V3 lpos; BOOL hasL = ltr && VXPosOf(ltr, &lpos);
    int lteam = local ? VXTeam(local) : -1;

    void *m = VXMatch(); if (!m) return;
    static void *arr[VXMAX];
    int cnt = 0;
    static const int lists[3] = { O_LIST_A, O_LIST_B, O_LIST_C };
    for (int i = 0; i < 3 && cnt == 0; i++) { cnt = VXFromList(*(void **)((char *)m + lists[i]), arr, VXMAX); if (cnt) g_src = 1 + i; }
    static const int dicts[3] = { 0x128, 0x130, 0x148 };
    for (int i = 0; i < 3 && cnt == 0; i++) { cnt = VXFromDict(*(void **)((char *)m + dicts[i]), arr, VXMAX); if (cnt) g_src = 4 + i; }
    g_cList = cnt;
    if (cnt <= 0) { pthread_mutex_lock(&g_mtx); g_sn = 0; pthread_mutex_unlock(&g_mtx); return; }

    int out = VXPass(arr, cnt, local, lpos, hasL, lteam, YES);
    if (out == 0) out = VXPass(arr, cnt, local, lpos, hasL, lteam, NO);
    pthread_mutex_lock(&g_mtx);
    memcpy(g_snap, g_tmp, sizeof(VXEnt) * out);
    g_sn = out;
    pthread_mutex_unlock(&g_mtx);
}

static NSString *VXReport(void) {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"L%d B%d P%d D%ld src%d\n", g_cList, g_cBone, g_cProj, (long)g_entities, g_src];
    [s appendFormat:@"api %d\n", p_domain_get ? 1 : 0];
    [s appendFormat:@"mg %p match %p\n", VXMatchGame(), VXMatch()];
    [s appendFormat:@"cam %p local %p\n", VXCam(), VXLocal()];
    [s appendFormat:@"w2vp %p modo %d\n", g_w2vp, g_projMode];
    return s;
}

static void VXShow(NSString *t) {
    dispatch_async(dispatch_get_main_queue(), ^{ if (g_status) g_status.text = t.length > 240 ? [t substringToIndex:240] : t; });
}

static void VXAimStep(void) {
    if (!g.aim || !g_ready) return;
    void *cam = VXCam(); if (!cam) return;
    void *m = VXMatch(); if (!m) return;
    void *local = VXLocal();
    static void *arr[VXMAX];
    int cnt = 0;
    static const int lists[3] = { O_LIST_A, O_LIST_B, O_LIST_C };
    for (int i = 0; i < 3 && cnt == 0; i++) cnt = VXFromList(*(void **)((char *)m + lists[i]), arr, VXMAX);
    static const int dicts[3] = { 0x128, 0x130, 0x148 };
    for (int i = 0; i < 3 && cnt == 0; i++) cnt = VXFromDict(*(void **)((char *)m + dicts[i]), arr, VXMAX);
    if (cnt <= 0) return;
    CGPoint mid = CGPointMake(VXW() / 2, VXH() / 2);
    float best = g.aimFov > 0 ? g.aimFov : 400;
    void *pick = NULL;
    for (int i = 0; i < cnt; i++) {
        void *p = arr[i];
        if (!p || p == local) continue;
        void *tr = VXTransformOf(p); if (!tr) continue;
        V3 w; if (!VXPosOf(tr, &w)) continue;
        CGPoint sp; if (!VXProject(w, &sp, NULL)) continue;
        float dx = sp.x - mid.x, dy = sp.y - mid.y;
        float d = sqrtf(dx * dx + dy * dy);
        if (d < best) { best = d; pick = p; }
    }
    if (!pick) return;
    void *head = VXInvoke0(VXMethod(VXClsOf(pick), "GetHeadTF", 0), pick);
    void *root = VXTransformOf(pick);
    if (!root || !head) return;
    if (!g_lookAt) g_lookAt = VXMethod(VXClass("UnityEngine", "Transform"), "LookAt", 1);
    if (!g_lookAt) return;
    void *args[1] = { &head }; void *exc = NULL;
    p_runtime_invoke(g_lookAt, root, args, &exc);
}

@interface VeexDraw : UIView
@end

@implementation VeexDraw
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e { return NO; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    if (!c) return;
    UIColor *col = g.color ?: [UIColor whiteColor];
    CGSize sz = VXSize();
    if (g.fovCircle && g.aim) {
        CGContextSetStrokeColorWithColor(c, [[UIColor colorWithWhite:1 alpha:0.4] CGColor]);
        CGContextSetLineWidth(c, 1);
        CGFloat r = g.aimFov > 0 ? g.aimFov : 160;
        CGContextStrokeEllipseInRect(c, CGRectMake(sz.width / 2 - r, sz.height / 2 - r, r * 2, r * 2));
    }
    if (g.crosshair) {
        CGContextSetStrokeColorWithColor(c, col.CGColor);
        CGContextSetLineWidth(c, 1);
        CGPoint m = CGPointMake(sz.width / 2, sz.height / 2);
        CGContextMoveToPoint(c, m.x - 9, m.y); CGContextAddLineToPoint(c, m.x - 3, m.y);
        CGContextMoveToPoint(c, m.x + 3, m.y); CGContextAddLineToPoint(c, m.x + 9, m.y);
        CGContextMoveToPoint(c, m.x, m.y - 9); CGContextAddLineToPoint(c, m.x, m.y - 3);
        CGContextMoveToPoint(c, m.x, m.y + 3); CGContextAddLineToPoint(c, m.x, m.y + 9);
        CGContextStrokePath(c);
    }
    if (!g.esp || !g_ready) return;
    pthread_mutex_lock(&g_mtx);
    static VXEnt local[VXMAX];
    int n = g_sn; if (n > VXMAX) n = VXMAX;
    memcpy(local, g_snap, sizeof(VXEnt) * n);
    pthread_mutex_unlock(&g_mtx);
    CGContextSetLineWidth(c, g.thin ? 1.0 : 1.4);
    CGContextSetStrokeColorWithColor(c, col.CGColor);
    NSInteger drawn = 0;
    for (int i = 0; i < n; i++) {
        VXEnt *e = &local[i];
        if (!e->valid) continue;
        CGFloat rawH = fabs(e->toe.y - e->head.y);
        if (rawH < 2 || rawH > 1400) continue;
        CGFloat bw = rawH * 0.5f;
        CGRect box = CGRectMake(e->head.x - bw / 2, e->head.y, bw, rawH);
        if (g.espBits & (1 << VXEspBox)) { CGContextStrokeRect(c, box); if (!g.thin) CGContextStrokeRect(c, CGRectInset(box, -1.5, -1.5)); }
        if (g.espBits & (1 << VXEspLine)) { CGContextMoveToPoint(c, sz.width / 2, sz.height - 42); CGContextAddLineToPoint(c, box.origin.x + bw / 2, box.origin.y + rawH); CGContextStrokePath(c); }
        if (g.espBits & (1 << VXEspBone)) {
            void (^seg)(CGPoint, BOOL, CGPoint, BOOL) = ^(CGPoint a, BOOL oka, CGPoint b, BOOL okb) {
                if (!oka || !okb) return;
                CGContextMoveToPoint(c, a.x, a.y); CGContextAddLineToPoint(c, b.x, b.y); CGContextStrokePath(c);
            };
            seg(e->head, YES, e->nk, e->okN); seg(e->nk, e->okN, e->aL, e->okL); seg(e->nk, e->okN, e->aR, e->okR);
            seg(e->aL, e->okL, e->hL, e->okHL); seg(e->aR, e->okR, e->hR, e->okHR);
            seg(e->nk, e->okN, e->toe, YES); seg(e->toe, YES, e->fL, e->okFL); seg(e->toe, YES, e->fR, e->okFR);
        }
        if ((g.espBits & (1 << VXEspHp)) && e->hp >= 0 && e->maxhp > 0) {
            CGFloat pct = (CGFloat)e->hp / (CGFloat)e->maxhp;
            if (pct < 0) pct = 0; if (pct > 1) pct = 1;
            CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:0.15 alpha:1] CGColor]);
            CGContextFillRect(c, CGRectMake(box.origin.x - 5, box.origin.y, 2, rawH));
            CGContextSetFillColorWithColor(c, [[UIColor greenColor] CGColor]);
            CGContextFillRect(c, CGRectMake(box.origin.x - 5, box.origin.y + rawH * (1 - pct), 2, rawH * pct));
            CGContextSetStrokeColorWithColor(c, col.CGColor);
        }
        if (g.espBits & (1 << VXEspName)) {
            NSString *nm = e->name[0] ? [NSString stringWithUTF8String:e->name] : @"";
            [nm drawAtPoint:CGPointMake(box.origin.x, box.origin.y - 12) withAttributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:9], NSForegroundColorAttributeName: col }];
        }
        if (g.espBits & (1 << VXEspDist)) {
            NSString *ds = [NSString stringWithFormat:@"%.0f", e->dist];
            [ds drawAtPoint:CGPointMake(box.origin.x, box.origin.y + rawH + 2) withAttributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:9], NSForegroundColorAttributeName: col }];
        }
        drawn++;
    }
    g_entities = drawn;
    if (g.diag) {
        snprintf(g_dbg, sizeof(g_dbg), "L%d B%d P%d D%ld", g_cList, g_cBone, g_cProj, (long)drawn);
        [[NSString stringWithUTF8String:g_dbg] drawAtPoint:CGPointMake(12, sz.height * 0.5)
            withAttributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:14], NSForegroundColorAttributeName: [UIColor whiteColor] }];
    }
}
@end

@interface VeexPanel : UIView
- (void)tick; - (void)bubbleTapped; - (void)bubbleDouble; - (void)drag:(UIPanGestureRecognizer *)p;
- (void)onChip:(UIButton *)b; - (void)onSlider:(UISlider *)s; - (void)onColor:(UIButton *)b;
- (void)doDump; - (void)doBoot; - (void)doReset; - (void)paint:(UIButton *)b;
@end

@implementation VeexPanel
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (!g_bubble) return nil;
    CGPoint bp = [g_bubble convertPoint:p fromView:self];
    if (CGRectContainsPoint(CGRectInset(g_bubble.bounds, -16, -16), bp)) return g_bubble;
    if (g_panel && !g_panel.hidden) return [super hitTest:p withEvent:e];
    return nil;
}
- (UILabel *)label:(NSString *)t size:(CGFloat)s color:(UIColor *)c y:(CGFloat)y {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, y, 272, s + 6)];
    l.text = t; l.textColor = c;
    l.font = [UIFont fontWithName:@"Menlo-Bold" size:s] ?: [UIFont boldSystemFontOfSize:s];
    return l;
}
- (UIButton *)chip:(NSString *)t x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w tag:(NSInteger)tag {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(x, y, w, 30);
    [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11] ?: [UIFont boldSystemFontOfSize:11];
    b.layer.cornerRadius = 6; b.layer.borderWidth = 1; b.tag = tag;
    [b addTarget:self action:@selector(onChip:) forControlEvents:UIControlEventTouchUpInside];
    [self paint:b];
    return b;
}
- (void)paint:(UIButton *)b {
    BOOL on = NO;
    switch (b.tag) {
        case 101: on = g.esp; break; case 102: on = (g.espBits & (1 << VXEspBox)) != 0; break;
        case 103: on = (g.espBits & (1 << VXEspBone)) != 0; break; case 104: on = (g.espBits & (1 << VXEspName)) != 0; break;
        case 105: on = (g.espBits & (1 << VXEspHp)) != 0; break; case 106: on = (g.espBits & (1 << VXEspDist)) != 0; break;
        case 107: on = (g.espBits & (1 << VXEspLine)) != 0; break; case 108: on = g.aim; break;
        case 109: on = g.fovCircle; break; case 110: on = g.crosshair; break; case 111: on = g.diag; break;
        case 115: on = g.thin; break; case 116: on = g.stream; break;
    }
    b.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1];
    UIColor *acc = g_accent ?: [UIColor greenColor];
    b.layer.borderColor = (on ? acc : [UIColor colorWithWhite:0.30 alpha:1]).CGColor;
    [b setTitleColor:(on ? acc : [UIColor colorWithWhite:0.90 alpha:1]) forState:UIControlStateNormal];
}
- (void)onChip:(UIButton *)b {
    g_lastTouch = CACurrentMediaTime();
    switch (b.tag) {
        case 101: g.esp = !g.esp; if (g.esp) [self doBoot]; break;
        case 102: g.espBits ^= (1 << VXEspBox); break; case 103: g.espBits ^= (1 << VXEspBone); break;
        case 104: g.espBits ^= (1 << VXEspName); break; case 105: g.espBits ^= (1 << VXEspHp); break;
        case 106: g.espBits ^= (1 << VXEspDist); break; case 107: g.espBits ^= (1 << VXEspLine); break;
        case 108: g.aim = !g.aim; if (g.aim) [self doBoot]; break;
        case 109: g.fovCircle = !g.fovCircle; break; case 110: g.crosshair = !g.crosshair; break;
        case 111: g.diag = !g.diag; break; case 112: [self doDump]; break; case 113: g_panel.hidden = YES; break;
        case 114: [self doReset]; break; case 115: g.thin = !g.thin; break;
        case 116: g.stream = !g.stream; g_panel.hidden = YES; break;
    }
    [self paint:b];
}
- (void)onSlider:(UISlider *)s { if (s.tag == 201) g.aimFov = s.value; }
- (void)onColor:(UIButton *)b {
    NSArray *hex = @[ @"#FFFFFF", @"#00FF66", @"#FF3355", @"#33AAFF", @"#FFCC00", @"#CC66FF" ];
    NSInteger i = b.tag - 301;
    if (i < 0 || i >= (NSInteger)hex.count) return;
    UIColor *c = VXC(hex[i], [UIColor whiteColor]);
    if (c) g.color = c;
}
- (void)doBoot {
    if (g_ready) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VXAttach();
        if (!VXResolve()) { VXShow(@"sin api"); return; }
        VXBoneOffsets();
        dispatch_async(dispatch_get_main_queue(), ^{ g_ready = YES; });
    });
}
- (void)doDump {
    VXShow(@"dump...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ VXAttach(); VXShow(VXReport()); });
}
- (void)doReset {
    VXShow(@"reseteando...");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @try {
            NSArray *cls = @[ (__bridge id)kSecClassGenericPassword, (__bridge id)kSecClassInternetPassword, (__bridge id)kSecClassKey, (__bridge id)kSecClassCertificate ];
            for (id c in cls) { NSDictionary *q = @{ (__bridge id)kSecClass: c }; SecItemDelete((__bridge CFDictionaryRef)q); }
            NSFileManager *fm = [NSFileManager defaultManager];
            NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *lib = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
            if (docs) for (NSString *f in [fm contentsOfDirectoryAtPath:docs error:nil]) [fm removeItemAtPath:[docs stringByAppendingPathComponent:f] error:nil];
            if (lib) for (NSString *sub in @[@"Preferences", @"Caches", @"Saved Application State"]) {
                NSString *p = [lib stringByAppendingPathComponent:sub];
                for (NSString *f in [fm contentsOfDirectoryAtPath:p error:nil]) [fm removeItemAtPath:[p stringByAppendingPathComponent:f] error:nil];
            }
        } @catch (NSException *ex) {}
        dispatch_async(dispatch_get_main_queue(), ^{
            VXShow(@"reset ok · cerrando");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
        });
    });
}
- (void)tick {
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (kw && (g_win != kw || !CGSizeEqualToSize(kw.bounds.size, g_lastSize))) {
        g_lastSize = kw.bounds.size; g_win = kw;
        if (self.superview != kw) {
            [self removeFromSuperview];
            self.frame = kw.bounds;
            self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [kw addSubview:self];
            if (g_draw) {
                [g_draw removeFromSuperview];
                g_draw.frame = kw.bounds;
                g_draw.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [kw addSubview:g_draw];
                [kw bringSubviewToFront:self];
            }
        }
        if (g_panel) {
            g_panel.center = CGPointMake(kw.bounds.size.width / 2, kw.bounds.size.height / 2);
            g_panel.frame = CGRectMake(g_panel.frame.origin.x, g_panel.frame.origin.y, MIN(306, kw.bounds.size.width - 40), MIN(kw.bounds.size.height - 160, 560));
        }
    }
    if (g_bubble) {
        CFTimeInterval idle = CACurrentMediaTime() - g_lastTouch;
        if (g.stream) g_bubble.alpha = 0.06f;
        else if (idle > 3.0) g_bubble.alpha = 0.28f;
        else g_bubble.alpha = 1.0f;
    }
    if (g_draw) [g_draw setNeedsDisplay];
    if (g.aim) VXAimStep();
    if (g_ready && g.esp && !g_busy) { g_busy = 1; dispatch_async(g_q, ^{ VXCollect(); g_busy = 0; }); }
    CFTimeInterval now = CACurrentMediaTime();
    if (now - g_last >= 0.5) { g_last = now; if (g_fps) g_fps.text = [NSString stringWithFormat:@"%ld", (long)g_entities]; }
}
- (void)bubbleTapped { g_lastTouch = CACurrentMediaTime(); g_panel.hidden = !g_panel.hidden; }
- (void)bubbleDouble { g_lastTouch = CACurrentMediaTime(); g.esp = !g.esp; if (g.esp) [self doBoot]; }
- (void)drag:(UIPanGestureRecognizer *)p {
    g_lastTouch = CACurrentMediaTime();
    CGPoint t = [p translationInView:self];
    CGPoint c = g_bubble.center;
    CGSize s = self.bounds.size;
    c.x = MAX(30, MIN(s.width - 30, c.x + t.x));
    c.y = MAX(40, MIN(s.height - 40, c.y + t.y));
    g_bubble.center = c;
    [p setTranslation:CGPointZero inView:self];
}
@end

static void VXBuildMenu(void) {
    if (g_built) return;
    g_built = YES;
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    if (!kw) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ VXBuildMenu(); });
        return;
    }
    g_q = dispatch_queue_create("veex.esp", DISPATCH_QUEUE_SERIAL);
    g_accent = [UIColor greenColor];
    g.color = [UIColor whiteColor];
    g.bg = [UIColor colorWithWhite:0.05 alpha:0.97];
    g.line = [UIColor colorWithWhite:0.28 alpha:1];
    g.espBits = (1 << VXEspBox) | (1 << VXEspDist);
    g.thin = YES; g.aim = NO; g.aimFov = 160;
    g_lastSize = kw.bounds.size;
    g_lastTouch = CACurrentMediaTime();

    g_draw = [[VeexDraw alloc] initWithFrame:kw.bounds];
    g_draw.backgroundColor = [UIColor clearColor];
    g_draw.userInteractionEnabled = NO;
    g_draw.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    g_draw.opaque = NO; g_draw.clearsContextBeforeDrawing = NO;
    [kw addSubview:g_draw];

    VeexPanel *host = [[VeexPanel alloc] initWithFrame:kw.bounds];
    host.backgroundColor = [UIColor clearColor];
    host.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [kw addSubview:host];

    g_bubble = [[UIView alloc] initWithFrame:CGRectMake(14, 130, 46, 46)];
    g_bubble.backgroundColor = [UIColor colorWithWhite:0.07 alpha:0.94];
    g_bubble.layer.cornerRadius = 23; g_bubble.layer.borderWidth = 1;
    g_bubble.layer.borderColor = g.line.CGColor;
    UILabel *vl = [[UILabel alloc] initWithFrame:g_bubble.bounds];
    vl.text = @"VX"; vl.textAlignment = NSTextAlignmentCenter; vl.textColor = [UIColor whiteColor];
    vl.font = [UIFont fontWithName:@"Menlo-Bold" size:15] ?: [UIFont boldSystemFontOfSize:15];
    [g_bubble addSubview:vl];
    [host addSubview:g_bubble];

    UITapGestureRecognizer *one = [[UITapGestureRecognizer alloc] initWithTarget:host action:@selector(bubbleTapped)];
    UITapGestureRecognizer *two = [[UITapGestureRecognizer alloc] initWithTarget:host action:@selector(bubbleDouble)];
    two.numberOfTapsRequired = 2;
    [one requireGestureRecognizerToFail:two];
    [g_bubble addGestureRecognizer:one];
    [g_bubble addGestureRecognizer:two];
    [g_bubble addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:host action:@selector(drag:)]];

    CGFloat pw = MIN(306, kw.bounds.size.width - 40);
    CGFloat ph = MIN(kw.bounds.size.height - 160, 560);
    g_panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, ph)];
    g_panel.center = CGPointMake(kw.bounds.size.width / 2, kw.bounds.size.height / 2);
    g_panel.backgroundColor = g.bg;
    g_panel.layer.cornerRadius = 12; g_panel.layer.borderWidth = 1;
    g_panel.layer.borderColor = g.line.CGColor;
    g_panel.hidden = YES;
    [host addSubview:g_panel];

    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, 52)];
    head.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    [g_panel addSubview:head];
    UILabel *t1 = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, 180, 22)];
    t1.text = @"Veex"; t1.textColor = [UIColor whiteColor];
    t1.font = [UIFont fontWithName:@"Menlo-Bold" size:17] ?: [UIFont boldSystemFontOfSize:17];
    [head addSubview:t1];
    UILabel *t2 = [[UILabel alloc] initWithFrame:CGRectMake(14, 29, 220, 14)];
    t2.text = @"BY LEVI · t.me/levibrouh"; t2.textColor = [UIColor colorWithWhite:0.52 alpha:1];
    t2.font = [UIFont fontWithName:@"Menlo" size:9] ?: [UIFont systemFontOfSize:9];
    [head addSubview:t2];
    g_fps = [[UILabel alloc] initWithFrame:CGRectMake(pw - 74, 10, 34, 16)];
    g_fps.text = @"0"; g_fps.textAlignment = NSTextAlignmentRight; g_fps.textColor = g_accent;
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
    [sv addSubview:[host label:@"VISUAL" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]]; y += 20;
    NSArray *chips = @[@"ESP", @"CAJA", @"HUESOS", @"NOMBRE", @"VIDA", @"DIST", @"LINEA"];
    CGFloat cx = 14;
    for (NSInteger i = 0; i < chips.count; i++) {
        CGFloat wd = 72;
        if (cx + wd > pw - 14) { cx = 14; y += 36; }
        [sv addSubview:[host chip:chips[i] x:cx y:y w:wd tag:101 + i]];
        cx += wd + 8;
    }
    y += 44;
    [sv addSubview:[host label:@"APUNTADO" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]]; y += 20;
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
    sf.minimumValue = 40; sf.maximumValue = 700; sf.value = g.aimFov; sf.tag = 201;
    [sf addTarget:host action:@selector(onSlider:) forControlEvents:UIControlEventValueChanged];
    [sv addSubview:sf]; y += 52;
    [sv addSubview:[host label:@"COLOR" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]]; y += 20;
    NSArray *hex = @[ @"#FFFFFF", @"#00FF66", @"#FF3355", @"#33AAFF", @"#FFCC00", @"#CC66FF" ];
    for (NSInteger i = 0; i < hex.count; i++) {
        UIButton *cb = [UIButton buttonWithType:UIButtonTypeSystem];
        cb.frame = CGRectMake(14 + i * 40, y, 30, 30);
        cb.backgroundColor = VXC(hex[i], [UIColor whiteColor]);
        cb.layer.cornerRadius = 15; cb.layer.borderWidth = 1;
        cb.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:1].CGColor;
        cb.tag = 301 + i;
        [cb addTarget:host action:@selector(onColor:) forControlEvents:UIControlEventTouchUpInside];
        [sv addSubview:cb];
    }
    y += 42;
    [sv addSubview:[host label:@"SISTEMA" size:10 color:[UIColor colorWithWhite:0.5 alpha:1] y:y]]; y += 20;
    [sv addSubview:[host chip:@"SUTIL" x:14 y:y w:72 tag:115]];
    [sv addSubview:[host chip:@"STREAM" x:94 y:y w:80 tag:116]];
    [sv addSubview:[host chip:@"ESTADO" x:182 y:y w:96 tag:112]];
    y += 36;
    [sv addSubview:[host chip:@"RESET GUEST" x:14 y:y w:130 tag:114]];
    y += 44;
    g_status = [[UILabel alloc] initWithFrame:CGRectMake(14, y, pw - 28, 90)];
    g_status.text = @"listo"; g_status.numberOfLines = 0;
    g_status.textColor = [UIColor colorWithWhite:0.72 alpha:1];
    g_status.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    [sv addSubview:g_status]; y += 96;
    sv.contentSize = CGSizeMake(pw, y + 20);
    g_link = [CADisplayLink displayLinkWithTarget:host selector:@selector(tick)];
    [g_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

__attribute__((constructor)) static void VXInit(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (int i = 0; i < 900; i++) {
            __block BOOL up = NO;
            dispatch_sync(dispatch_get_main_queue(), ^{
                UIApplication *a = [UIApplication sharedApplication];
                up = a != nil && a.windows.count > 0 && a.keyWindow != nil;
            });
            if (up) break;
            usleep(200000);
        }
        dispatch_async(dispatch_get_main_queue(), ^{ VXBuildMenu(); });
    });
}
