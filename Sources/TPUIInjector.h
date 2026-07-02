#import <UIKit/UIKit.h>
@interface TPUIInjector : NSObject
+ (instancetype)shared;
- (void)scanFrom:(UIViewController *)controller;
@end
