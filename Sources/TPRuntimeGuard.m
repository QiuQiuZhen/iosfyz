#import "TPRuntimeGuard.h"
#import "TPDebugLogger.h"
@implementation TPRuntimeGuard
+(BOOL)canStart{NSString*b=NSBundle.mainBundle.bundleIdentifier.lowercaseString;return [b containsString:@"whatsapp"];}
+(void)performSafely:(dispatch_block_t)block context:(NSString*)context{@try{if(block)block();}@catch(NSException*e){[TPDebugLogger.shared log:[NSString stringWithFormat:@"%@ exception: %@",context,e.reason]];}}
@end
