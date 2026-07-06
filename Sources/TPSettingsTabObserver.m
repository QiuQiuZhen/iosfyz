#import "TPSettingsTabObserver.h"
#import "TPSettingsPageDetector.h"
#import "TPSettingsEntryInjector.h"
@implementation TPSettingsTabObserver
+(instancetype)shared{static id x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];});return x;}
-(BOOL)observeController:(UIViewController*)vc{UITableView*t=[TPSettingsPageDetector settingsTableInController:vc];if(!t)return NO;[TPSettingsEntryInjector.shared injectIntoTable:t controller:vc];return YES;}
@end
