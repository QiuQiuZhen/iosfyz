#import "TPPluginBootstrap.h"
#import "TPRuntimeGuard.h"
#import "TPChatPageObserver.h"
#import "TPSettingsTabObserver.h"
#import "TPDebugLogger.h"

@implementation TPPluginBootstrap

+(instancetype)shared{
    static id x;
    static dispatch_once_t once;
    dispatch_once(&once,^{x=[self new];});
    return x;
}

-(void)start{
    NSProcessInfo *p=NSProcessInfo.processInfo;
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"plugin started version=%@ bundle=%@ process=%@ pid=%d system=%@",
                               TPPluginVersion,
                               NSBundle.mainBundle.bundleIdentifier?:@"unknown",
                               p.processName?:@"unknown",
                               p.processIdentifier,
                               p.operatingSystemVersionString?:@"unknown"]];
}

-(void)controllerDidAppear:(UIViewController*)vc{
    if(!vc.view.window)return;
    [TPRuntimeGuard performSafely:^{
        NSString *name=NSStringFromClass(vc.class)?:@"unknown";
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"controller appeared %@",name]];
        if([vc isKindOfClass:UINavigationController.class]||[vc isKindOfClass:UITabBarController.class]){
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"controller ignored container %@",name]];
            return;
        }
        if([TPSettingsTabObserver.shared observeController:vc]){
            [TPChatPageObserver.shared stopObserving];
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"controller handled as settings %@",name]];
            return;
        }
        if([TPChatPageObserver.shared observeController:vc]){
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"controller handled as chat %@",name]];
            return;
        }
        [TPChatPageObserver.shared stopObserving];
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"controller ignored non-chat %@",name]];
    } context:@"page observer"];
}

@end
