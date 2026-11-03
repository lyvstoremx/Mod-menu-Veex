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

static void VXAlert(NSString *t, NSString *m) {
    UIWindow *w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    w.windowLevel = UIWindowLevelAlert + 2;
    w.rootViewController = [[UIViewController alloc] init];
    [w makeKeyAndVisible];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:t message:m
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:nil]];
    [w.rootViewController presentViewController:a animated:YES completion:nil];
}

static NSString *VXUpload(NSString *txt) {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:
                              [NSURL URLWithString:@"https://paste.rs"]];
    r.HTTPMethod = @"POST";
    r.HTTPBody = [txt dataUsingEncoding:NSUTF8StringEncoding];
    r.timeoutInterval = 30;
    __block NSString *out = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:r
        completionHandler:^(NSData *d, NSURLResponse *x, NSError *e) {
            if (d) out = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            dispatch_semaphore_signal(sem);
        }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 35 * NSEC_PER_SEC));
    return [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
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
    fn_cls_fields cf = (fn_cls_fields)S("il2cpp_class_get_fields");
    fn_f_name fn = (fn_f_name)S("il2cpp_field_get_name");

    if (!dg || !da || !ai || !in || !ic || !ig || !cn) {
        VXAlert(@"VEEX", @"sin simbolos il2cpp");
        return;
    }

    NSArray *keys = @[@"Player", @"Weapon", @"Camera", @"Trigger", @"Hit",
                      @"Damage", @"Fire", @"Shoot", @"Aim", @"Target", @"Enemy", @"Bot"];

    NSMutableString *o = [NSMutableString string];
    [o appendFormat:@"veex dump %@\n", [NSDate date]];

    void *d = dg();
    size_t n = 0;
    void **as = da(d, &n);
    [o appendFormat:@"ensamblados: %zu\n", n];
    if (!as) { VXAlert(@"VEEX", @"sin ensamblados"); return; }

    int matched = 0;
    for (size_t i = 0; i < n && matched < 300; i++) {
        void *a = *(void **)((char *)as + 0x20 + i * 8);
        if (!a) continue;
        void *img = ai(a);
        if (!img) continue;
        const char *inm = in(img);
        [o appendFormat:@"\n### imagen %s\n", inm ? inm : "?"];
        size_t cc = ic(img);
        for (size_t j = 0; j < cc && matched < 300; j++) {
            void *c = ig(img, j);
            if (!c || !cn) continue;
            const char *cname = cn(c);
            if (!cname) continue;
            NSString *full = [NSString stringWithUTF8String:cname];
            BOOL hit = NO;
            for (NSString *k in keys) if ([full containsString:k]) { hit = YES; break; }
            if (!hit) continue;
            matched++;
            const char *ns = cs ? cs(c) : NULL;
            [o appendFormat:@"\nclase %s::%s\n", ns ? ns : "", cname];
            if (cm && mn) {
                void *it = NULL;
                void *m;
                int lim = 0;
                while ((m = cm(c, &it)) && lim++ < 40) {
                    const char *mname = mn(m);
                    if (mname) [o appendFormat:@"  m %s\n", mname];
                }
            }
            if (cf && fn) {
                void *it = NULL;
                void *f;
                int lim = 0;
                while ((f = cf(c, &it)) && lim++ < 40) {
                    const char *fname = fn(f);
                    if (fname) [o appendFormat:@"  f %s\n", fname];
                }
            }
        }
    }

    [o appendFormat:@"\nclases encontradas: %d\n", matched];
    [o writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/veex_dump.txt"]
        atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSString *url = VXUpload(o);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (url.length > 0) VXAlert(@"VEEX dump", url);
        else VXAlert(@"VEEX", @"no subio, queda en Documents/veex_dump.txt");
    });
}

__attribute__((constructor)) static void VXInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VXDump();
    });
}
