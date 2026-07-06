#import "TPChatPageObserver.h"
#import "TPMessageScanner.h"
#import "TPSettings.h"
#import "TPDebugLogger.h"
#import "TPComposerController.h"
@interface TPChatPageObserver()@property(nonatomic,weak)UIView*root;@property(nonatomic,weak)UITextView*composer;@property(nonatomic,strong)NSTimer*timer;@property(nonatomic,readwrite)BOOL inChatPage;@property(nonatomic,copy)NSString*chatId;@end
@implementation TPChatPageObserver
-(NSString*)currentChatId{return self.chatId?:@"unknown";}
+(instancetype)shared{static id x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];[NSNotificationCenter.defaultCenter addObserver:x selector:@selector(settingsChanged) name:TPSettingsDidChangeNotification object:nil];});return x;}
-(void)collectTextViews:(UIView*)v into:(NSMutableArray*)a{if([v isKindOfClass:UITextView.class]&&v.window&&!v.hidden)[a addObject:v];for(UIView*s in v.subviews)[self collectTextViews:s into:a];}
-(BOOL)hasMessageList:(UIView*)v{if([v isKindOfClass:UITableView.class]||[v isKindOfClass:UICollectionView.class])return YES;for(UIView*s in v.subviews)if([self hasMessageList:s])return YES;return NO;}
-(BOOL)observeController:(UIViewController*)vc{if(!vc.view.window)return NO;NSMutableArray*a=[NSMutableArray array];[self collectTextViews:vc.view into:a];UITextView*best;for(UITextView*t in a)if(CGRectGetHeight(t.bounds)<180&&(!best||CGRectGetMinY([t convertRect:t.bounds toView:nil])>CGRectGetMinY([best convertRect:best.bounds toView:nil])))best=t;if(!best||![self hasMessageList:vc.view])return NO;CGRect composerRect=[best convertRect:best.bounds toView:vc.view];if(CGRectGetMidY(composerRect)<CGRectGetHeight(vc.view.bounds)*.68||CGRectGetWidth(composerRect)<CGRectGetWidth(vc.view.bounds)*.35)return NO;self.root=vc.view;self.composer=best;self.inChatPage=YES;NSString*title=vc.navigationItem.title?:vc.title;self.chatId=title.length?title:[NSString stringWithFormat:@"chat-%p",vc];TPDebugLogger.shared.pageState=@"chat";[TPDebugLogger.shared log:[NSString stringWithFormat:@"chat page detected vc=%@ chat=%@ textViews=%lu composer=%@",NSStringFromClass(vc.class),self.chatId,(unsigned long)a.count,NSStringFromClass(best.class)]];[TPComposerController.shared attachToComposer:best chatId:self.chatId];if(!self.timer)self.timer=[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(rescan) userInfo:nil repeats:YES];[self rescan];return YES;}
-(void)rescan{if(!self.root.window||!self.composer.window){self.inChatPage=NO;return;}[TPMessageScanner.shared scanRoot:self.root composer:self.composer chatId:self.chatId];}
-(void)settingsChanged{if(TPSettings.shared.autoTranslate)[self rescan];}
@end
