#import <UIKit/UIKit.h>
@interface TPComposerController:NSObject
+(instancetype)shared;
-(void)attachToComposer:(UITextView*)composer chatId:(NSString*)chatId;
@end
