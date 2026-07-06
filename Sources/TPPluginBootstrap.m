#import "TPPluginBootstrap.h"
#import "TPRuntimeGuard.h"
#import "TPChatPageObserver.h"
#import "TPSettingsTabObserver.h"
#import "TPDebugLogger.h"
@implementation TPPluginBootstrap
+(instancetype)shared{static id x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];});return x;}
-(void)start{[TPDebugLogger.shared log:@"plugin started"];}
-(void)controllerDidAppear:(UIViewController*)vc{if(!vc.view.window)return;[TPRuntimeGuard performSafely:^{NSString*name=NSStringFromClass(vc.class);[TPDebugLogger.shared log:[NSString stringWithFormat:@"controller appeared %@",name]];if([TPSettingsTabObserver.shared observeController:vc]){[TPDebugLogger.shared log:[NSString stringWithFormat:@"controller handled as settings %@",name]];return;}if([TPChatPageObserver.shared observeController:vc]){[TPDebugLogger.shared log:[NSString stringWithFormat:@"controller handled as chat %@",name]];return;}[TPDebugLogger.shared log:[NSString stringWithFormat:@"controller ignored %@",name]];} context:@"page observer"];}
@end
