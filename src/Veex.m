#import <Foundation/Foundation.h>

__attribute__((constructor)) static void VXInit(void) {
    NSString *p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/veex.log"];
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"fecha %@\n", [NSDate date]];
    [s appendFormat:@"bundle %@\n", [[NSBundle mainBundle] bundleIdentifier]];
    [s appendString:@"constructor ok\n"];
    [s writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"[veex] constructor");
}
