// Veex.m
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
typedef void *(*fn_thread_attach)(void *);
typedef size_t (*fn_image_class_count)(void *);
typedef void *(*fn_image_get_class)(void *, uint32_t);
typedef const char *(*fn_class_get_name)(void *);
typedef const char *(*fn_class_get_namespace)(void *);
typedef void *(*fn_class_get_fields)(void *, void **);
typedef const char *(*fn_field_get_name)(void *);
typedef void *(*fn_field_get_type)(void *);
typedef uint32_t (*fn_field_get_flags)(void *);

static fn_domain_get p_domain_get;
static fn_domain_get_assemblies p_domain_get_assemblies;
static fn_assembly_get_image p_assembly_get_image;
static fn_image_get_name p_image_get_name;
static fn_class_from_name p_class_from_name;
static fn_class_get_parent p_class_get_parent;
static fn_class_get_field_from_name p_class_get_field_from_name;
static fn_field_get_offset p_field_get_offset;
static fn_field_static_get_value p_field_static_get_value;
static fn_class_get_method_from_name p_class_get_method_from_name;
static fn_runtime_invoke p_runtime_invoke;
static fn_object_new p_object_new;
static fn_string_new p_string_new;
static fn_value_box p_value_box;
static fn_class_get_methods p_class_get_methods;
static fn_method_get_name p_method_get_name;
static fn_method_get_param_count p_method_get_param_count;
static fn_method_get_param p_method_get_param;
static fn_type_get_name p_type_get_name;
static fn_thread_attach p_thread_attach;
static fn_image_class_count p_image_class_count;
static fn_image_get_class p_image_get_class;
static fn_class_get_name p_class_get_name;
static fn_class_get_namespace p_class_get_namespace;
static fn_class_get_fields p_class_get_fields;
static fn_field_get_name p_field_get_name;
static fn_field_get_type p_field_get_type;
static fn_field_get_flags p_field_get_flags;

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
    p_domain_get = (fn_domain_get)VXSym("il2cpp_domain_get");
    p_domain_get_assemblies = (fn_domain_get_assemblies)VXSym("il2cpp_domain_get_assemblies");
    p_assembly_get_image = (fn_assembly_get_image)VXSym("il2cpp_assembly_get_image");
    p_image_get_name = (fn_image_get_name)VXSym("il2cpp_image_get_name");
    p_class_from_name = (fn_class_from_name)VXSym("il2cpp_class_from_name");
    p_class_get_parent = (fn_class_get_parent)VXSym("il2cpp_class_get_parent");
    p_class_get_field_from_name = (fn_class_get_field_from_name)VXSym("il2cpp_class_get_field_from_name");
    p_field_get_offset = (fn_field_get_offset)VXSym("il2cpp_field_get_offset");
    p_field_static_get_value = (fn_field_static_get_value)VXSym("il2cpp_field_static_get_value");
    p_class_get_method_from_name = (fn_class_get_method_from_name)VXSym("il2cpp_class_get_method_from_name");
    p_runtime_invoke = (fn_runtime_invoke)VXSym("il2cpp_runtime_invoke");
    p_object_new = (fn_object_new)VXSym("il2cpp_object_new");
    p_string_new = (fn_string_new)VXSym("il2cpp_string_new");
    p_value_box = (fn_value_box)VXSym("il2cpp_value_box");
    p_class_get_methods = (fn_class_get_methods)VXSym("il2cpp_class_get_methods");
    p_method_get_name = (fn_method_get_name)VXSym("il2cpp_method_get_name");
    p_method_get_param_count = (fn_method_get_param_count)VXSym("il2cpp_method_get_param_count");
    p_method_get_param = (fn_method_get_param)VXSym("il2cpp_method_get_param");
    p_type_get_name = (fn_type_get_name)VXSym("il2cpp_type_get_name");
    p_thread_attach = (fn_thread_attach)VXSym("il2cpp_thread_attach");
    p_image_class_count = (fn_image_class_count)VXSym("il2cpp_image_class_count");
    if (!p_image_class_count) p_image_class_count = (fn_image_class_count)VXSym("il2cpp_image_get_class_count");
    p_image_get_class = (fn_image_get_class)VXSym("il2cpp_image_get_class");
    p_class_get_name = (fn_class_get_name)VXSym("il2cpp_class_get_name");
    p_class_get_namespace = (fn_class_get_namespace)VXSym("il2cpp_class_get_namespace");
    p_class_get_fields = (fn_class_get_fields)VXSym("il2cpp_class_get_fields");
    p_field_get_name = (fn_field_get_name)VXSym("il2cpp_field_get_name");
    p_field_get_type = (fn_field_get_type)VXSym("il2cpp_field_get_type");
    p_field_get_flags = (fn_field_get_flags)VXSym("il2cpp_field_get_flags");

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

static void *VXAsmAt(void **as, size_t i) {
    void *a = ((void **)as)[i];
    void *img = a ? p_assembly_get_image(a) : NULL;
    if (img && p_image_get_name(img)) return a;
    return *(void **)((char *)as + 0x20 + i * 8);
}

static void *VXClass(const char *ns, const char *name) {
    if (!p_domain_get || !p_domain_get_assemblies) return NULL;
    size_t n = 0;
    void **as = p_domain_get_assemblies(p_domain_get(), &n);
    if (!as) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *a = VXAsmAt(as, i);
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

static void *VXStaticField(void *cls, const char *name) {
    void *c = cls;
    for (int d = 0; c && d < 12; d++) {
        void *f = p_class_get_field_from_name(c, name);
        if (f) return f;
        c = p_class_get_parent ? p_class_get_parent(c) : NULL;
    }
    return NULL;
}

static size_t VXFieldOffset(void *cls, const char *name) {
    void *f = VXStaticField(cls, name);
    return f ? p_field_get_offset(f) : 0;
}

static BOOL VXPtr(void *p) {
    uintptr_t v = (uintptr_t)p;
    return p && v > 0x10000 && v < 0x8000000000ULL;
}

static void *VXClsOf(void *obj) {
    if (!obj) return NULL;
    return (__bridge void *)object_getClass((__bridge id)obj);
}

static struct { BOOL esp, aim, fire, visOnly; CGFloat fov; UIColor *color; int profile; } g;

static void *g_triggerCls, *g_camCls, *g_dictField, *g_dictCls;
static void *kImgs[512];
static size_t kCounts[512];
static int kImgN;
static size_t g_trOff;
static NSInteger g_entities;
static int g_armed, g_built;
static BOOL g_busy;

static UIWindow *g_win;
static UIView *g_bubble, *g_panel, *g_draw;
static UILabel *g_status, *g_fovLabel;
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

static NSString *VXExcMsg(void *exc);

static BOOL VXDictOK(void *dict) {
    if (!VXPtr(dict)) return NO;
    char *e = *(char **)((char *)dict + 0x18);
    int c = *(int *)((char *)dict + 0x20);
    return VXPtr(e) && c > 0 && c <= 512;
}

static size_t VXImgCount(void *img) {
    for (int i = 0; i < kImgN; i++) if (kImgs[i] == img) return kCounts[i];
    size_t c = 0;
    if (p_image_class_count) c = p_image_class_count(img);
    else while (c < 5000 && p_image_get_class(img, (uint32_t)c)) c++;
    if (kImgN < 512) { kImgs[kImgN] = img; kCounts[kImgN] = c; kImgN++; }
    return c;
}

static void VXDiscover(void) {
    if (g_dictField) return;
    if (!p_image_get_class || !p_class_get_fields || !p_field_get_type || !p_type_get_name) {
        VXSay(@"falta api dict");
        return;
    }

    size_t n = 0;
    void **as = p_domain_get_assemblies(p_domain_get(), &n);
    if (!as) return;

    int prob = 0;
    for (size_t i = 0; i < n; i++) {
        void *a = VXAsmAt(as, i);
        if (!a) continue;
        void *img = p_assembly_get_image(a);
        if (!img) continue;

        size_t cc = VXImgCount(img);
        for (size_t k = 0; k < cc; k++) {
            void *cls = p_image_get_class(img, (uint32_t)k);
            if (!cls) continue;
            const char *cn = p_class_get_name(cls);
            if (!cn) continue;
            if (!(strstr(cn, "Spawn") || strstr(cn, "Manager") || strstr(cn, "Entity") ||
                  strstr(cn, "Player") || strstr(cn, "CrossHair"))) continue;
            prob++;

            void *it = NULL;
            void *fd = NULL;
            while ((fd = p_class_get_fields(cls, &it))) {
                if (p_field_get_flags && !(p_field_get_flags(fd) & 0x10)) continue;
                void *ft = p_field_get_type(fd);
                char *tn = ft ? p_type_get_name(ft) : NULL;
                if (!tn || !strstr(tn, "Dictionary")) continue;
                void *v = NULL;
                p_field_static_get_value(fd, &v);
                if (!VXDictOK(v)) continue;
                g_dictField = fd;
                g_dictCls = cls;
                VXSay(@"dict lista");
                return;
            }
        }
    }
    VXSay([NSString stringWithFormat:@"sin dict %d", prob]);
}

static void *VXFindDict(void) {
    if (!g_dictField) return NULL;
    void *d = NULL;
    p_field_static_get_value(g_dictField, &d);
    if (VXDictOK(d)) return d;
    g_dbg = @"dict vacia";
    return NULL;
}

static BOOL VXValidObj(void *o) {
    if (!VXPtr(o)) return NO;
    void *k = *(void **)o;
    if (!VXPtr(k)) return NO;
    if (!p_class_get_name) return YES;
    const char *n = p_class_get_name(k);
    return n && n[0];
}

static void VXReport(void) {
    if (!VXResolve()) { VXSay(@"r sin il2cpp"); return; }
    if (p_thread_attach) p_thread_attach(p_domain_get());
    void *dict = VXFindDict();
    if (!dict) { VXSay(@"r sin dict"); return; }
    char *entries = *(char **)((char *)dict + 0x18);
    int count = *(int *)((char *)dict + 0x20);
    NSMutableString *s = [NSMutableString stringWithFormat:@"r n=%d ", count];
    for (int i = 0; i < count && i < 20; i++) {
        void *ent = *(void **)(entries + i * 24 + 16);
        if (!VXValidObj(ent)) ent = *(void **)(entries + i * 24 + 8);
        if (!VXValidObj(ent)) { [s appendString:@"?- "]; continue; }
        const char *cn = p_class_get_name(*(void **)ent);
        [s appendFormat:@"%s ", cn ? cn : "?"];
    }
    VXSay(s);
}

static void *VXTrMethod(void *cls) {
    static void *k[16], *m[16];
    static int n;
    for (int i = 0; i < n; i++) if (k[i] == cls) return m[i];
    void *mm = VXMethod(cls, "get_transform", 0);
    if (n < 16) { k[n] = cls; m[n] = mm; n++; }
    return mm;
}

static void *VXTransformOf(void *obj) {
    if (!VXValidObj(obj)) return NULL;
    void *mm = VXTrMethod(VXClsOf(obj));
    if (!mm) return NULL;
    void *e = NULL;
    void *r = p_runtime_invoke(mm, obj, NULL, &e);
    if (!r || e || !VXPtr(r)) return NULL;
    return r;
}

static void *VXPosMethod(void *tr) {
    static void *k[32], *m[32];
    static int n;
    void *cls = VXClsOf(tr);
    for (int i = 0; i < n; i++) if (k[i] == cls) return m[i];
    void *mm = VXMethod(cls, "get_position", 0);
    if (n < 32) { k[n] = cls; m[n] = mm; n++; }
    return mm;
}

static void *VXCamera(void) {
    if (!g_camCls) {
        g_camCls = VXClass("UnityEngine", "Camera");
        if (!g_camCls) g_camCls = VXClass("", "Camera");
    }
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

static void VXDump(void) {
    if (!VXResolve()) { VXSay(@"dump: sin il2cpp"); return; }
    void *d = p_domain_get();
    if (!d) { VXSay(@"dump: sin dominio"); return; }
    if (p_thread_attach) p_thread_attach(d);

    if (!p_image_get_class || !p_class_get_fields || !p_field_get_name ||
        !p_field_get_type || !p_class_get_name) {
        VXSay(@"dump: api falta");
        return;
    }

    size_t n = 0;
    void **as = p_domain_get_assemblies(d, &n);
    if (!as) { VXSay(@"dump: sin ensamblados"); return; }

    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                      stringByAppendingPathComponent:@"veexdump.txt"];
    FILE *f = fopen([path UTF8String], "w");
    if (!f) { VXSay(@"dump: no escribo"); return; }

    int clases = 0, campos = 0;
    for (size_t i = 0; i < n; i++) {
        void *a = VXAsmAt(as, i);
        if (!a) continue;
        void *img = p_assembly_get_image(a);
        if (!img) continue;
        const char *inm = p_image_get_name(img);
        fprintf(f, "\n=== %s ===\n", inm ? inm : "?");
        VXSay([NSString stringWithFormat:@"dump %s %d", inm ? inm : "?", clases]);

        size_t cc = VXImgCount(img);
        for (size_t c = 0; c < cc; c++) {
            void *cls = p_image_get_class(img, (uint32_t)c);
            if (!cls) continue;
            const char *nm = p_class_get_name(cls);
            if (!nm) continue;
            if (!(strstr(nm, "Player") || strstr(nm, "Spawn") || strstr(nm, "Manager") ||
                  strstr(nm, "Entity") || strstr(nm, "Camera") || strstr(nm, "Trigger") ||
                  strstr(nm, "Avatar") || strstr(nm, "Weapon") || strstr(nm, "Health") ||
                  strstr(nm, "Team") || strstr(nm, "Match") || strstr(nm, "Aim") ||
                  strstr(nm, "Target") || strstr(nm, "Hit") || strstr(nm, "Damage") ||
                  strstr(nm, "Local") || strstr(nm, "Base"))) continue;

            const char *ns = p_class_get_namespace ? p_class_get_namespace(cls) : "";
            fprintf(f, "C %s.%s\n", ns ? ns : "", nm);
            clases++;

            void *it = NULL;
            void *fd = NULL;
            while ((fd = p_class_get_fields(cls, &it))) {
                const char *fn = p_field_get_name(fd);
                if (!fn) continue;
                void *ft = p_field_get_type(fd);
                char *ftn = ft ? p_type_get_name(ft) : NULL;
                fprintf(f, "  F %s %s @%zu\n", ftn ? ftn : "?", fn, p_field_get_offset(fd));
                campos++;
            }
        }
    }
    fclose(f);
    VXSay([NSString stringWithFormat:@"dump %d cls %d f", clases, campos]);
}

static NSString *VXExcMsg(void *exc) {
    if (!exc) return @"?";
    void *mm = VXMethod(VXClsOf(exc), "get_Message", 0);
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
    void *intCls = VXClass("System", "Int32");
    if (!fsCls || !intCls) { if (why) *why = @"sin FileStream"; return NULL; }

    void *obj = p_object_new(fsCls);
    if (!obj) { if (why) *why = @"sin objeto"; return NULL; }

    void *ctor = NULL, *it = NULL;
    while (1) {
        void *mm = p_class_get_methods(fsCls, &it);
        if (!mm) break;
        const char *nm = p_method_get_name(mm);
        if (!nm || strcmp(nm, ".ctor") != 0) continue;
        if (p_method_get_param_count(mm) != 3) continue;
        char *a0 = p_type_get_name(p_method_get_param(mm, 0));
        char *a1 = p_type_get_name(p_method_get_param(mm, 1));
        char *a2 = p_type_get_name(p_method_get_param(mm, 2));
        if (a0 && a1 && a2 && strstr(a0, "String") && strstr(a1, "FileMode") &&
            strstr(a2, "FileAccess")) { ctor = mm; break; }
    }
    if (!ctor) { if (why) *why = @"sin ctor"; return NULL; }

    void *sPath = p_string_new([path UTF8String]);
    int mode = 3, acc = 1;
    void *bm = p_value_box(intCls, &mode);
    void *ba = p_value_box(intCls, &acc);
    void *args[3] = { sPath, bm, ba };
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
    VXSay([NSString stringWithFormat:@"5 %lu b %02X%02X", (unsigned long)d.length, raw[0], raw[1]]);

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
        for (int i = 0; i < 20; i++) { if (VXCargar()) return; sleep(2); }
    });
}

static NSArray *VXGuestTokens(void) { return @[@"garena", @"freefire", @"com.dts", @"guest", @"dts"]; }
static NSArray *VXOtherTokens(void) { return @[@"facebook", @"google", @"apple", @"oauth", @"signin"]; }

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
                for (NSString *t in VXGuestTokens()) if ([hay containsString:t]) { hit = YES; break; }
                if (hit) for (NSString *t in VXOtherTokens()) if ([hay containsString:t]) { hit = NO; break; }
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
        for (NSString *it in [fm contentsOfDirectoryAtPath:full error:nil]) {
            NSString *low = it.lowercaseString;
            if (!([low hasSuffix:@".plist"] || [low hasSuffix:@".json"] || [low hasSuffix:@".dat"] ||
                  [low hasSuffix:@".xml"] || [low hasSuffix:@".txt"])) continue;
            BOOL hit = [d hasSuffix:@"Preferences"];
            if (!hit) for (NSString *t in toks) if ([low containsString:t]) { hit = YES; break; }
            if (!hit) continue;
            if ([fm removeItemAtPath:[full stringByAppendingPathComponent:it] error:nil]) files++;
        }
    }
    for (NSString *nm in @[@"com.dts.freefireth.plist", @"com.garena.plist"]) {
        NSString *p = [[home stringByAppendingPathComponent:@"Library/Preferences"] stringByAppendingPathComponent:nm];
        if ([fm removeItemAtPath:p error:nil]) files++;
    }
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (log) [log appendFormat:@"ar:%d", files];
    return kc + files;
}

@interface VeexDraw : UIView
@end

@implementation VeexDraw
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e { return NO; }

- (void)drawRect:(CGRect)rect {
    if (!g.esp) { g_dbg = @"esp off"; return; }
    void *cam = VXCamera();
    if (!cam) return;
    void *dict = VXFindDict();
    if (!dict) return;

    char *entries = *(char **)((char *)dict + 0x18);
    int count = *(int *)((char *)dict + 0x20);
    g_dbg = [NSString stringWithFormat:@"cnt %d", count];
    if (!VXPtr(entries) || count <= 0 || count > 300) return;

    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(c, 1.2);
    CGContextSetStrokeColorWithColor(c, (g.color ?: [UIColor whiteColor]).CGColor);

    NSInteger drawn = 0;
    for (int i = 0; i < count; i++) {
        void *ent = *(void **)(entries + i * 24 + 16);
        if (!VXValidObj(ent)) ent = *(void **)(entries + i * 24 + 8);
        if (!VXValidObj(ent)) continue;
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

@interface VeexPanel : UIView
- (void)tick;
- (void)bubbleTapped;
- (void)drag:(UIPanGestureRecognizer *)p;
- (void)dragBubble:(UIPanGestureRecognizer *)p;
- (void)showReset;
- (void)cancelReset;
- (void)doReset;
- (void)switchChanged:(UISwitch *)s;
- (void)fovChanged:(UISlider *)s;
- (void)profileChanged:(UISegmentedControl *)s;
- (void)chip:(UIButton *)b;
- (void)dumpSubir;
- (void)enviar:(NSData *)d modo:(int)m;
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
    if (g_diag && g_status && !g_busy) g_status.text = g_dbg ?: @"...";
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

- (void)dumpSubir {
    g_busy = YES;
    g_status.text = @"dump...";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        VXDump();
        NSString *p = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                       stringByAppendingPathComponent:@"veexdump.txt"];
        NSData *d = [NSData dataWithContentsOfFile:p];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!d.length) { g_status.text = @"sin dump"; return; }
            [self enviar:d modo:0];
        });
    });
}

- (void)enviar:(NSData *)d modo:(int)m {
    g_status.text = [NSString stringWithFormat:@"subiendo %lu KB", (unsigned long)(d.length / 1024)];
    NSMutableURLRequest *r;
    if (m == 0) {
        NSString *b = @"----veexb";
        NSMutableData *body = [NSMutableData data];
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", b] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Disposition: form-data; name=\"file\"; filename=\"veexdump.txt\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: text/plain\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:d];
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", b] dataUsingEncoding:NSUTF8StringEncoding]];
        r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://0x0.st"]];
        r.HTTPMethod = @"POST";
        [r setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", b] forHTTPHeaderField:@"Content-Type"];
        r.HTTPBody = body;
    } else {
        r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://paste.rs"]];
        r.HTTPMethod = @"POST";
        [r setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
        r.HTTPBody = d;
    }
    r.timeoutInterval = 240;
    [r setValue:@"Mozilla/5.0 (iPhone)" forHTTPHeaderField:@"User-Agent"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:r
        completionHandler:^(NSData *rd, NSURLResponse *rs, NSError *e) {
            NSString *s = rd ? [[NSString alloc] initWithData:rd encoding:NSUTF8StringEncoding] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (s.length && [s containsString:@"http"]) {
                    g_status.text = s;
                    UIPasteboard.generalPasteboard.string = s;
                    return;
                }
                if (m == 0) { [self enviar:d modo:1]; return; }
                g_status.text = e ? e.localizedDescription : @"subida fallo";
            });
        }] resume];
}

- (void)switchChanged:(UISwitch *)s {
    g_busy = NO;
    switch (s.tag) {
        case 1001:
            g.esp = s.isOn;
            if (g.esp) dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ VXReport(); });
            break;
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
}
@end

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

    [head addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:g_panel action:@selector(drag:)]];

    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 44, pw, ph - 44)];
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

    UIButton *dmp = VXB(@"DUMP Y SUBIR", pw - 28, 32);
    dmp.frame = CGRectMake(14, y, pw - 28, 32);
    [dmp addTarget:g_panel action:@selector(dumpSubir) forControlEvents:UIControlEventTouchUpInside];
    [sv addSubview:dmp];
    y += 44;

    g_status = VXL(@"", 8, [UIColor colorWithWhite:1 alpha:0.7]);
    g_status.frame = CGRectMake(14, y, pw - 28, 90);
    g_diag = YES;
    [sv addSubview:g_status];
    y += 96;

    sv.contentSize = CGSizeMake(pw, y);

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

    [g_bubble addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:g_panel
                                                                          action:@selector(bubbleTapped)]];
    [g_bubble addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:g_panel
                                                                          action:@selector(dragBubble:)]];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (p_thread_attach && p_domain_get) p_thread_attach(p_domain_get());
        for (int i = 0; i < 600; i++) {
            if (g_dictField) return;
            VXDiscover();
            sleep(2);
        }
    });

    g_link = [CADisplayLink displayLinkWithTarget:g_panel selector:@selector(tick)];
    [g_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

__attribute__((constructor)) static void VXInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ VXBuildMenu(); });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (p_thread_attach && p_domain_get) p_thread_attach(p_domain_get());
        for (int i = 0; i < 600; i++) {
            if (VXResolve()) {
                void *c = VXClass("", "SpawnObjectCrossHairTrigger");
                if (c) { g_triggerCls = c; g_trOff = VXFieldOffset(c, "transform"); return; }
            }
            usleep(300000);
        }
    });
}
