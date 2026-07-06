#import <UIKit/UIKit.h>
@interface TPRetryController:NSObject
+(void)attachRetry:(dispatch_block_t)retry toLabel:(UILabel*)label cell:(UIView*)cell;
@end
