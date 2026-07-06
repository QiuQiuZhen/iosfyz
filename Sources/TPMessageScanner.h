#import <UIKit/UIKit.h>
@interface TPMessageScanner:NSObject
+(instancetype)shared;
-(void)scanRoot:(UIView*)root composer:(UIView*)composer chatId:(NSString*)chatId;
@end
