#import <UIKit/UIKit.h>
@interface TPSettingsTabObserver:NSObject
+(instancetype)shared;-(BOOL)observeController:(UIViewController*)controller;
@end
