#import <UIKit/UIKit.h>
@interface TPMessageScanner:NSObject
+(instancetype)shared;
-(void)scanRoot:(UIView*)root composer:(UITextView*)composer chatId:(NSString*)chatId;
@end
