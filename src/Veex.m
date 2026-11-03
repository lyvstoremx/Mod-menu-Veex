// Veex.m — fase 1: cascaron
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>
#import <unistd.h>

static UIWindow *g_win;
static UIView *g_bubble;
static UIView *g_panel;
static UILabel *g_tick;
static UILabel *g_status;
static CADisplayLink *g_link;
static BOOL g_built;
static uint64_t g_frames;

static UIColor *g_accent;

static CGFloat VXW(void) { return [UIScreen mainScreen].bounds.size.width; }
static CGFloat VXH(void) { return [UIScreen mainScreen].bounds.size.height; }

static UIColor *VXAccent(void) { return g_accent ?: [UIColor whiteColor]; }

static UILabel *VXL(NSString *t, CGFloat s, UIColor *c) {
    UILabel *l = [[UILabel alloc] init];
    l.text = t;
    l.font = [UIFont fontWithName:@"Menlo-Bold" size:s] ?: [UIFont boldSystemFontOfSize:s];
    l.textColor = c;
    l.numberOfLines = 0;
    return l;
}

static UIButton *VXB(NSString *t, CGFloat w, CGFloat h) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(0, 0, w, h);
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11] ?: [UIFont boldSystemFontOfSize:11];
    b.layer.borderWidth = 1;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    b.layer.cornerRadius = 6;
    return b;
}

static void VXBuildMenu(void);

@interface VeexPanel : UIView
- (void)tick;
- (void)bubbleTapped;
- (void)drag:(UIPanGestureRecognizer *)p;
- (void)dragBubble:(UIPanGestureRecognizer *)p;
- (void)close;
- (void)probe;
@end

@implementation VeexPanel

- (void)tick {
    if (++g_frames % 15 == 0 && g_tick)
        g_tick.text = [NSString stringWithFormat:@"v0.1 shell  f%llu", g_frames];
}

- (void)bubbleTapped { g_panel.hidden = !g_panel.hidden; }

- (void)drag:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:g_win];
    CGPoint c = g_panel.center;
    CGFloat hw = g_panel.bounds.size.width / 2, hh = g_panel.bounds.size.height / 2;
    c.x = MAX(hw, MIN(VXW() - hw, c.x + t.x));
    c.y = MAX(hh, MIN(VXH() - hh, c.y + t.y));
    g_panel.center = c;
    [p setTranslation:CGPointZero inView:g_win];
}

- (void)dragBubble:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:g_win];
    CGPoint c = g_bubble.center;
    CGFloat h = g_bubble.bounds.size.height / 2;
    c.x = MAX(h, MIN(VXW() - h, c.x + t.x));
    c.y = MAX(h, MIN(VXH() - h, c.y + t.y));
    g_bubble.center = c;
    [p setTranslation:CGPointZero inView:g_win];
}

- (void)close { g_panel.hidden = YES; }

- (void)probe {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"home: %@\n", NSHomeDirectory()];
    [s appendFormat:@"bundle: %@\n", [[NSBundle mainBundle] bundleIdentifier]];
    [s appendFormat:@"ios: %@\n", [[UIDevice currentDevice] systemVersion]];
    [s appendFormat:@"pantalla: %.0fx%.0f\n", VXW(), VXH()];
    [s appendString:@"il2cpp: pendiente"];
    g_status.text = s;
}

@end

static void VXBuildMenu(void) {
    if (g_built) return;
    g_built = YES;

    g_accent = [UIColor colorWithRed:0.15 green:1 blue:0.35 alpha:1];

    g_win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    g_win.windowLevel = UIWindowLevelAlert + 1;
    g_win.backgroundColor = [UIColor clearColor];
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    g_win.rootViewController = vc;
    [g_win makeKeyAndVisible];

    CGFloat pw = 272;
    CGFloat ph = MIN(420, VXH() - 110);
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
    title.frame = CGRectMake(14, 8, 120, 18);
    [head addSubview:title];

    UILabel *by = VXL(@"BY LEVI", 8, [UIColor colorWithWhite:1 alpha:0.45]);
    by.frame = CGRectMake(14, 26, 120, 10);
    [head addSubview:by];

    UIButton *x = VXB(@"X", 26, 26);
    x.frame = CGRectMake(pw - 36, 9, 26, 26);
    [x addTarget:g_panel action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [head addSubview:x];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:g_panel action:@selector(drag:)];
    [head addGestureRecognizer:pan];

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

    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 44, pw, ph - 44)];
    sv.delaysContentTouches = NO;
    sv.showsVerticalScrollIndicator = YES;
    [g_panel addSubview:sv];

    CGFloat y = 12;

    g_tick = VXL(@"v0.1 shell", 10, VXAccent());
    g_tick.frame = CGRectMake(14, y, pw - 28, 14);
    [sv addSubview:g_tick];
    y += 24;

    UILabel *note = VXL(@"Sin ESP ni aim todavia.\nSolo prueba de carga.", 9, [UIColor colorWithWhite:1 alpha:0.6]);
    note.frame = CGRectMake(14, y, pw - 28, 30);
    [sv addSubview:note];
    y += 40;

    UIButton *pr = VXB(@"ESTADO", pw - 28, 32);
    pr.frame = CGRectMake(14, y, pw - 28, 32);
    [pr addTarget:g_panel action:@selector(probe) forControlEvents:UIControlEventTouchUpInside];
    [sv addSubview:pr];
    y += 40;

    g_status = VXL(@"", 8, [UIColor colorWithRed:0.4 green:1 blue:0.6 alpha:1]);
    g_status.frame = CGRectMake(14, y, pw - 28, 150);
    [sv addSubview:g_status];
    y += 156;

    sv.contentSize = CGSizeMake(pw, y);

    g_link = [CADisplayLink displayLinkWithTarget:g_panel selector:@selector(tick)];
    [g_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

static void VXBoot(void) {
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

__attribute__((constructor)) static void VXInit(void) { VXBoot(); }
