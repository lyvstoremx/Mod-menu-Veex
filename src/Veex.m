#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>

typedef void  *(*fn_domain_get)(void);
typedef void **(*fn_assemblies)(void *, size_t *);
typedef void  *(*fn_asm_image)(void *);
typedef const char *(*fn_image_name)(void *);
typedef size_t (*fn_img_count)(void *);
typedef void  *(*fn_img_class)(void *, size_t);
typedef const char *(*fn_cls_name)(void *);
typedef const char *(*fn_cls_ns)(void *);
typedef void  *(*fn_cls_methods)(void *, void **);
typedef const char *(*fn_m_name)(void *);
typedef void  *(*fn_cls_fields)(void *, void **);
typedef const char *(*fn_f_name)(void *);

static void *S(const char *n) { return dlsym(RTLD_DEFAULT, n); }

static void VXText(NSString *t) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        w.windowLevel = UIWindowLevelAlert + 2;
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

static BOOL VXEngine(const char *img) {
    if (!img) return YES;
    NSString *s = [NSString stringWithUTF8String:img];
    NSArray *bad = @[@"UnityEngine", @"Firebase", @"mscorlib", @"System", @"Mono",
                     @"Newtonsoft", @"Google", @"nunit", @"ExCSS"];
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
    fn_cls_methods cm = (fn_cls_methods)S("il2cpp_class_get_methods");
    fn_m_name mn = (fn_m_name)S("il2cpp_method_get_name");

    if (!dg || !da || !ai || !in || !ic || !ig || !cn) {
        VXText(@"sin simbolos il2cpp");
        return;
    }

    NSMutableString *o = [NSMutableString string];
    void *d = dg();
    size_t n = 0;
    void **as = da(d, &n);
    if (!as) { VXText(@"sin ensamblados"); return; }

    [o appendFormat:@"ensamblados %zu\n\n=== LISTA ===\n", n];
    for (size_t i = 0; i < n; i++) {
        void *a = *(void **)((char *)as + 0x20 + i * 8);
        if (!a) continue;
        void *img = ai(a);
        if (!img) continue;
        const char *nm = in(img);
        [o appendFormat:@"%s  (%zu clases)%s\n", nm ? nm : "?",
            ic ? ic(img) : 0, VXEngine(nm) ? " [motor]" : ""];
    }

    [o appendString:@"\n=== CLASES DEL JUEGO ===\n"];
    int shown = 0;
    for (size_t i = 0; i < n && shown < 400; i++) {
        void *a = *(void **)((char *)as + 0x20 + i * 8);
        if (!a) continue;
        void *img = ai(a);
        if (!img) continue;
        const char *nm = in(img);
        if (VXEngine(nm)) continue;
        size_t cc = ic(img);
        [o appendFormat:@"\n--- %s ---\n", nm ? nm : "?"];
        for (size_t j = 0; j < cc && shown < 400; j++) {
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

__attribute__((constructor)) static void VXInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VXDump();
    });
}
