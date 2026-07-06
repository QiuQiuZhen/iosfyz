#import <Foundation/Foundation.h>
@interface TPRuntimeGuard:NSObject
+(BOOL)canStart;+(void)performSafely:(dispatch_block_t)block context:(NSString*)context;
@end
