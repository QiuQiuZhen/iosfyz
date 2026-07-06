#import "TPPluginBootstrap.h"
#import "TPRuntimeGuard.h"
#import "TPChatPageObserver.h"
#import "TPSettingsTabObserver.h"
#import "TPDebugLogger.h"
@implementation TPPluginBootstrap
+(instancetype)shared{static id x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];});return x;}
-(void)start{[TPDebugLogger.shared log:@"plugin started"];}
-(void)controllerDidAppear:(UIViewController*)vc{if(!vc.view.window)return;[TPRuntimeGuard performSafely:^{if([TPSettingsTabObserver.shared observeController:vc])return;if([TPChatPageObserver.shared observeController:vc])return;} context:@"page observer"];}
@end
