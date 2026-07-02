#import <UIKit/UIKit.h>
@interface TPMessageScanner : NSObject
+ (instancetype)shared;
- (void)scanVisibleMessagesInView:(UIView *)root excludingComposer:(UITextView *)composer;
@end
