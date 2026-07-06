#import "TPSettingsEntryInjector.h"
#import "TPSettingsEntryView.h"
#import "TPSettingsNavigator.h"
#import "TPDebugLogger.h"
#import <objc/runtime.h>
static const void*TPEntryKey=&TPEntryKey;
@implementation TPSettingsEntryInjector
+(instancetype)shared{static id x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];});return x;}
-(void)injectIntoTable:(UITableView*)table controller:(UIViewController*)vc{@try{if(objc_getAssociatedObject(table,TPEntryKey))return;UIView*old=table.tableFooterView;CGFloat oldH=old?MAX(0,CGRectGetHeight(old.bounds)):0;UIView*wrapper=[[UIView alloc]initWithFrame:CGRectMake(0,0,CGRectGetWidth(table.bounds),74+oldH)];TPSettingsEntryView*entry=[[TPSettingsEntryView alloc]initWithFrame:CGRectMake(0,5,CGRectGetWidth(table.bounds),64)];entry.autoresizingMask=UIViewAutoresizingFlexibleWidth;[entry addTarget:self action:@selector(open:) forControlEvents:UIControlEventTouchUpInside];objc_setAssociatedObject(entry,@selector(open:),vc,OBJC_ASSOCIATION_ASSIGN);[wrapper addSubview:entry];if(old){old.frame=CGRectMake(0,74,CGRectGetWidth(wrapper.bounds),oldH);old.autoresizingMask=UIViewAutoresizingFlexibleWidth;[wrapper addSubview:old];}table.tableFooterView=wrapper;objc_setAssociatedObject(table,TPEntryKey,entry,OBJC_ASSOCIATION_RETAIN_NONATOMIC);TPDebugLogger.shared.pageState=@"settings";}@catch(NSException*e){[TPDebugLogger.shared log:e.reason];}}
-(void)open:(TPSettingsEntryView*)sender{UIViewController*vc=objc_getAssociatedObject(sender,@selector(open:));[TPSettingsNavigator openFrom:vc];}
@end
