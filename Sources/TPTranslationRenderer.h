#import <UIKit/UIKit.h>
#import "TPMessageTextExtractor.h"
typedef NS_ENUM(NSInteger,TPBubbleState){TPBubbleStateUnprocessed,TPBubbleStateTranslating,TPBubbleStateTranslated,TPBubbleStateFailed};
@interface TPTranslationRenderer:NSObject
+(TPBubbleState)stateForCell:(UIView*)cell;
+(void)setTranslatingForMessage:(TPExtractedMessage*)message;
+(void)setTranslation:(NSString*)translation forMessage:(TPExtractedMessage*)message;
+(void)setFailure:(NSError*)error forMessage:(TPExtractedMessage*)message retry:(dispatch_block_t)retry;
+(void)resetCell:(UIView*)cell;
+(void)refreshVisibleSpacingInRoot:(UIView*)root;
+(BOOL)maintainTranslationForMessage:(TPExtractedMessage*)message;
@end
