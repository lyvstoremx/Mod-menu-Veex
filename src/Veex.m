#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <string.h>

typedef void  *(*fn_domain_get)(void);
typedef void **(*fn_assemblies)(void *, size_t *);
typedef void  *(*fn_asm_image)(void *);
typedef const char *(*fn_image_name)(void *);
typedef size_t (*fn_img_count)(void *);
typedef void  *(*fn_img_class)(void *, size_t);
typedef const char *(*fn_cls_name)(void *);
typedef const char *(*fn_cls_ns)(void *);

static void *S(const char *n) { return dlsym(RTLD_DEFAULT, n); }

static uint32_t (*orig_count)(void);
static const char *(*orig_name)(uint32_t);
static int g_hideIdx = -1;

static void VXOrig(void) {
    if (orig_count && orig_name) return;
    if (!orig_count) orig_count = (uint32_t (*)(void))dlsym(RTLD_NEXT, "_dyld_image_count");
    if (!orig_name) orig_name = (const char *(*)(uint32_t))dlsym(RTLD_NEXT, "_dyld_get_image_name");
}

static const char *VXFallback(void) {
    static char buf[1024];
    uint32_t sz = sizeof(buf);
    if (_NSGetExecutablePath(buf, &sz) == 0) return buf;
    return "?";
}

static uint32_t vx_count(void) {
    static BOOL busy = NO;
    if (!orig_count) { if (busy) return 1; busy = YES; VXOrig(); busy = NO; }
    uint32_t n = orig_count ? orig_count() : 1;
    if (g_hideIdx < 0 || n == 0) return n;
    return n - 1;
}

static const char *vx_name(uint32_t i) {
    static BOOL busy = NO;
    if (!orig_name) { if (busy) return VXFallback(); busy = YES; VXOrig(); busy = NO; }
    if (!orig_name) return VXFallback();
    uint32_t n = orig_count ? orig_count() : 0;
    uint32_t idx = (g_hideIdx >= 0 && (int)i >= g_hideIdx) ? i + 1 : i;
    if ((int)idx >= (int)n) return NULL;
    return orig_name(idx);
}

__attribute__((used, section("__DATA,__interpose")))
static const void *vx_pairs[][2] = {
    { (const void *)vx_count, (const void *)_dyld_image_count },
    { (const void *)vx_name,  (const void *)_dyld_get_image_name },
};

static void VXHideSelf(void) {
    VXOrig();
    uint32_t n = orig_count ? orig_count() : 0;
    for (uint32_t i = 1; i < n; i++) {
        const char *nm = orig_name ? orig_name(i) : NULL;
        if (!nm) continue;
        if (strstr(nm, "hlslcc") || strstr(nm, "veex")) { g_hideIdx = (int)i; return; }
    }
}

static void VXText(NSString *t) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        w.windowLevel = UIWindowLevelAlert + 3;
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.97];
        w.rootViewController = vc;
        [w makeKeyAndVisible];

        CGRect b = vc.view.bounds;
        UITextView *tv = [[UITextView alloc] initWithFrame:
                          CGRectMake(6, 56, b.size.width - 12, b.size.height - 112)];
        tv.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1];
        tv.textColor = [UIColor colorWithRed:0.5 green:1 blue:0.6 alpha:1];
        tv.font = [UIFont fontWithName:@"Menlo" size:9] ?: [UIFont systemFontOfSize:9];
        tv.text = t;
        tv.editable = NO;
        [vc.view addSubview:tv];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(6, b.size.height - 50, b.size.width - 12, 42);
        [btn setTitle:@"cerrar" forState:UIControlStateNormal];
        [btn addAction:[UIAction actionWithHandler:^(UIAction *a) { w.hidden = YES; }]
          forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:btn];
    });
}

static NSString *VXPost(NSString *url, NSString *txt) {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    r.HTTPMethod = @"POST";
    r.HTTPBody = [txt dataUsingEncoding:NSUTF8StringEncoding];
    [r setValue:@"text/plain; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [r setValue:@"Mozilla/5.0 (iPhone)" forHTTPHeaderField:@"User-Agent"];
    r.timeoutInterval = 25;
    __block NSString *out = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:r
        completionHandler:^(NSData *d, NSURLResponse *x, NSError *e) {
            if (d) out = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            dispatch_semaphore_signal(sem);
        }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    out = [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!out || [out hasPrefix:@"<"]) return nil;
    return out;
}

static BOOL VXSkip(const char *img) {
    if (!img) return YES;
    NSString *s = [NSString stringWithUTF8String:img];
    NSArray *bad = @[@"UnityEngine", @"Unity.", @"System", @"mscorlib", @"Mono",
                     @"Firebase", @"Google", @"Newtonsoft", @"nunit", @"ExCSS",
                     @"zxing", @"protobuf", @"IFix", @"__Generated"];
    for (NSString *b in bad) if ([s containsString:b]) return YES;
    return NO;
}

static void VXDump(void) {
    fn_domain_get dg = (fn_domain_get)S("il2cpp_domain_get");
    fn_assemblies da = (fn_assemblies)S("il2cpp_domain_get_assemblies");
    fn_asm_image ai = (fn_asm_image)S("il2cpp_assembly_get_image");
    fn_image_name in = (fn_image_name)S("il2cpp_image_get_name");
    fn_img_count ic = (fn_img_count)S("il2cpp_image_get_class_count");
    fn_img_class ig = (fn_img_class)S("il2cpp_image_get_class");
    fn_cls_name cn = (fn_cls_name)S("il2cpp_class_get_name");
    fn_cls_ns cs = (fn_cls_ns)S("il2cpp_class_get_namespace");

    if (!dg || !da || !ai || !in || !ic || !ig || !cn) {
        VXText(@"sin simbolos il2cpp");
        return;
    }

    NSMutableString *o = [NSMutableString string];
    void *d = dg();
    size_t n = 0;
    void **as = da(d, &n);
    if (!as) { VXText(@"sin ensamblados"); return; }

    [o appendFormat:@"oculto: %d\nensamblados: %zu\n\n=== LISTA ===\n", g_hideIdx, n];
    for (size_t i = 0; i < n; i++) {
        void *a = *(void **)((char *)as + 0x20 + i * 8);
        if (!a) continue;
        void *img = ai(a);
        if (!img) continue;
        const char *nm = in(img);
        [o appendFormat:@"%s (%zu)%s\n", nm ? nm : "?", ic ? ic(img) : 0,
            VXSkip(nm) ? " [skip]" : " ***"];
    }

    [o appendString:@"\n=== CLASES ===\n"];
    int shown = 0;
    for (size_t i = 0; i < n && shown < 600; i++) {
        void *a = *(void **)((char *)as + 0x20 + i * 8);
        if (!a) continue;
        void *img = ai(a);
        if (!img) continue;
        const char *nm = in(img);
        if (VXSkip(nm)) continue;
        size_t cc = ic(img);
        [o appendFormat:@"\n--- %s (%zu) ---\n", nm ? nm : "?", cc];
        for (size_t j = 0; j < cc && shown < 600; j++) {
            void *c = ig(img, j);
            if (!c) continue;
            const char *cname = cn(c);
            if (!cname) continue;
            shown++;
            const char *ns = cs ? cs(c) : NULL;
            if (ns && ns[0]) [o appendFormat:@"%s::%s\n", ns, cname];
            else [o appendFormat:@"%s\n", cname];
        }
    }
    [o appendFormat:@"\nmostradas %d\n", shown];

    [o writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/veex_dump.txt"]
        atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSString *url = VXPost(@"https://paste.rs", o);
    if (url) VXText([NSString stringWithFormat:@"subido:\n%@\n\n%@", url, o]);
    else VXText([NSString stringWithFormat:@"no subio\n\n%@", o]);
}

static void VXButton(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [[UIWindow alloc] initWithFrame:CGRectMake(0, 140, 54, 54)];
        w.windowLevel = UIWindowLevelAlert + 2;
        w.backgroundColor = [UIColor clearColor];
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        w.rootViewController = vc;
        [w makeKeyAndVisible];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(0, 0, 54, 54);
        b.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
        b.layer.cornerRadius = 27;
        b.layer.borderWidth = 1;
        b.layer.borderColor = [UIColor greenColor].CGColor;
        [b setTitle:@"D" forState:UIControlStateNormal];
        [b addAction:[UIAction actionWithHandler:^(UIAction *a) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ VXDump(); });
        }] forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:b];
    });
}

__attribute__((constructor)) static void VXInit(void) {
    VXHideSelf();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ VXButton(); });
}
