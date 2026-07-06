#import "TPSettingsNavigator.h"
#import "TPPluginSettingsPage.h"
#import "TPDebugLogger.h"
@implementation TPSettingsNavigator
+(void)openFrom:(UIViewController*)vc{@try{TPPluginSettingsPage*p=[TPPluginSettingsPage new];if(vc.navigationController)[vc.navigationController pushViewController:p animated:YES];else{UINavigationController*n=[[UINavigationController alloc]initWithRootViewController:p];[vc presentViewController:n animated:YES completion:nil];}}@catch(NSException*e){[TPDebugLogger.shared log:e.reason];[vc.presentedViewController dismissViewControllerAnimated:NO completion:nil];}}
@end
