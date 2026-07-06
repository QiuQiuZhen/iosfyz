#import <UIKit/UIKit.h>
@interface TPChatPageObserver:NSObject
+(instancetype)shared;
-(BOOL)observeController:(UIViewController*)controller;
-(void)rescan;
@property(nonatomic,readonly)BOOL inChatPage;
@property(nonatomic,readonly,copy)NSString*currentChatId;
@end
