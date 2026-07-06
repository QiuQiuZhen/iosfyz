#import <UIKit/UIKit.h>
@interface TPSettingsEntryInjector:NSObject
+(instancetype)shared;
-(void)injectIntoTable:(UITableView*)table controller:(UIViewController*)controller;
@end
