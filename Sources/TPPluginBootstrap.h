#import <UIKit/UIKit.h>
@interface TPPluginBootstrap:NSObject
+(instancetype)shared;-(void)start;-(void)controllerDidAppear:(UIViewController*)controller;
@end
