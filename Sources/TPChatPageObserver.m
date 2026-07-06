#import "TPChatPageObserver.h"
#import "TPMessageScanner.h"
#import "TPSettings.h"
#import "TPDebugLogger.h"
#import "TPComposerController.h"

@interface TPChatPageObserver()
@property(nonatomic,weak)UIView *root;
@property(nonatomic,weak)UIView *composer;
@property(nonatomic,strong)NSTimer *timer;
@property(nonatomic,readwrite)BOOL inChatPage;
@property(nonatomic,copy)NSString *chatId;
@end

@implementation TPChatPageObserver

+(instancetype)shared{
    static TPChatPageObserver *x;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        x=[self new];
        [NSNotificationCenter.defaultCenter addObserver:x selector:@selector(settingsChanged) name:TPSettingsDidChangeNotification object:nil];
    });
    return x;
}

-(NSString*)currentChatId{return self.chatId?:@"unknown";}

-(void)collectVisibleViews:(UIView*)view stats:(NSMutableDictionary*)stats inputs:(NSMutableArray*)inputs depth:(NSUInteger)depth{
    if(!view||depth>80||view.hidden||view.alpha<0.05)return;
    stats[@"views"]=@([stats[@"views"] integerValue]+1);
    NSString *name=NSStringFromClass(view.class).lowercaseString?:@"";
    if([view isKindOfClass:UIScrollView.class]){
        stats[@"scrollViews"]=@([stats[@"scrollViews"] integerValue]+1);
        if([view isKindOfClass:UITableView.class])stats[@"tableViews"]=@([stats[@"tableViews"] integerValue]+1);
        if([view isKindOfClass:UICollectionView.class])stats[@"collectionViews"]=@([stats[@"collectionViews"] integerValue]+1);
    }
    BOOL nativeCell=[view isKindOfClass:UITableViewCell.class]||[view isKindOfClass:UICollectionViewCell.class];
    BOOL namedCell=([name containsString:@"message"]||[name containsString:@"chatcell"]||[name containsString:@"bubblecell"])&&CGRectGetHeight(view.bounds)>=20&&CGRectGetHeight(view.bounds)<650;
    if(nativeCell||namedCell){
        stats[@"messageLikeCells"]=@([stats[@"messageLikeCells"] integerValue]+1);
        if(nativeCell)return;
    }
    BOOL input=[view isKindOfClass:UITextView.class]||[view isKindOfClass:UITextField.class];
    if(input&&CGRectGetWidth(view.bounds)>40&&CGRectGetHeight(view.bounds)>18&&CGRectGetHeight(view.bounds)<180)[inputs addObject:view];
    for(UIView *sub in view.subviews)[self collectVisibleViews:sub stats:stats inputs:inputs depth:depth+1];
}

-(UIView*)bestComposerInInputs:(NSArray*)inputs root:(UIView*)root{
    UIView *best=nil;
    CGFloat bestScore=-CGFLOAT_MAX;
    for(UIView *input in inputs){
        CGRect r=[input convertRect:input.bounds toView:root];
        CGFloat score=CGRectGetMinY(r)+CGRectGetWidth(r)*0.1-CGRectGetHeight(r)*0.2;
        if(CGRectGetMidY(r)<CGRectGetHeight(root.bounds)*0.55)score-=300;
        if(CGRectGetWidth(r)<CGRectGetWidth(root.bounds)*0.25)score-=200;
        if(score>bestScore){bestScore=score;best=input;}
    }
    return best;
}

-(NSString*)controllerHierarchy:(UIViewController*)vc{
    NSMutableArray *parts=[NSMutableArray array];
    for(UIViewController *c=vc;c;c=c.parentViewController){
        [parts addObject:NSStringFromClass(c.class)?:@"unknown"];
        if(parts.count>=8)break;
    }
    if(vc.navigationController)[parts addObject:[NSString stringWithFormat:@"nav=%@ top=%@",NSStringFromClass(vc.navigationController.class),NSStringFromClass(vc.navigationController.topViewController.class)]];
    if(vc.tabBarController)[parts addObject:[NSString stringWithFormat:@"tab=%@ index=%lu",NSStringFromClass(vc.tabBarController.class),(unsigned long)vc.tabBarController.selectedIndex]];
    if(vc.presentingViewController)[parts addObject:[NSString stringWithFormat:@"presenting=%@",NSStringFromClass(vc.presentingViewController.class)]];
    return [parts componentsJoinedByString:@" > "];
}

-(UIWindow*)keyWindow{
    UIWindow *fallback=nil;
    for(UIWindow *w in UIApplication.sharedApplication.windows){
        if(w.isKeyWindow)return w;
        if(!fallback&&w.windowLevel==UIWindowLevelNormal)fallback=w;
    }
    return fallback;
}

-(NSString*)keyWindowSummary{
    UIWindow *w=[self keyWindow];
    UIViewController *rootVC=w.rootViewController;
    return [NSString stringWithFormat:@"window=%@ frame=(%.0f,%.0f,%.0f,%.0f) rootVC=%@",w?NSStringFromClass(w.class):@"none",CGRectGetMinX(w.frame),CGRectGetMinY(w.frame),CGRectGetWidth(w.frame),CGRectGetHeight(w.frame),rootVC?NSStringFromClass(rootVC.class):@"none"];
}

-(NSString*)topBarSignalForController:(UIViewController*)vc{
    NSMutableArray *signals=[NSMutableArray array];
    if(vc.navigationItem.title.length)[signals addObject:[@"title=" stringByAppendingString:vc.navigationItem.title]];
    if(vc.title.length&&![vc.title isEqualToString:vc.navigationItem.title])[signals addObject:[@"vcTitle=" stringByAppendingString:vc.title]];
    if(vc.navigationItem.leftBarButtonItem||vc.navigationItem.backBarButtonItem)[signals addObject:@"backButton=YES"];
    if(vc.navigationController.viewControllers.count>1)[signals addObject:@"navDepth>1"];
    return [signals componentsJoinedByString:@","];
}

-(BOOL)observeController:(UIViewController*)vc{
    if(!vc.view.window)return NO;
    NSString *className=NSStringFromClass(vc.class)?:@"unknown";
    NSMutableDictionary *stats=[@{@"views":@0,@"scrollViews":@0,@"tableViews":@0,@"collectionViews":@0,@"messageLikeCells":@0} mutableCopy];
    NSMutableArray *inputs=[NSMutableArray array];
    [self collectVisibleViews:vc.view stats:stats inputs:inputs depth:0];
    UIView *composer=[self bestComposerInInputs:inputs root:vc.view];
    NSInteger lists=[stats[@"tableViews"] integerValue]+[stats[@"collectionViews"] integerValue];
    BOOL hasList=lists>0||[stats[@"scrollViews"] integerValue]>=2;
    BOOL hasCells=[stats[@"messageLikeCells"] integerValue]>=1;
    NSString *topSignal=[self topBarSignalForController:vc];
    NSString *lower=className.lowercaseString;
    BOOL likelyByName=[lower containsString:@"chat"]||[lower containsString:@"conversation"]||[lower containsString:@"message"];
    BOOL likelyByStructure=composer&&hasList&&(hasCells||topSignal.length||likelyByName);
    CGRect composerFrame=composer?[composer convertRect:composer.bounds toView:vc.view]:CGRectZero;
    BOOL composerLooksBottom=composer&&CGRectGetMidY(composerFrame)>CGRectGetHeight(vc.view.bounds)*0.58&&CGRectGetWidth(composerFrame)>CGRectGetWidth(vc.view.bounds)*0.22;
    BOOL accepted=likelyByStructure&&composerLooksBottom;
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"page-probe chat=%@ vc=%@ hierarchy=%@ keyWindow={%@} stats views=%ld scroll=%ld table=%ld collection=%ld messageCells=%ld inputs=%lu composer=%@ composerFrame=(%.0f,%.0f,%.0f,%.0f) hasList=%@ hasCells=%@ topSignal=%@",
                               accepted?@"YES":@"NO",className,[self controllerHierarchy:vc],[self keyWindowSummary],
                               (long)[stats[@"views"] integerValue],(long)[stats[@"scrollViews"] integerValue],(long)[stats[@"tableViews"] integerValue],(long)[stats[@"collectionViews"] integerValue],(long)[stats[@"messageLikeCells"] integerValue],(unsigned long)inputs.count,
                               composer?NSStringFromClass(composer.class):@"none",
                               CGRectGetMinX(composerFrame),CGRectGetMinY(composerFrame),CGRectGetWidth(composerFrame),CGRectGetHeight(composerFrame),
                               hasList?@"YES":@"NO",hasCells?@"YES":@"NO",topSignal.length?topSignal:@"none"]];
    if(!accepted)return NO;
    self.root=vc.view;
    self.composer=composer;
    self.inChatPage=YES;
    NSString *title=vc.navigationItem.title?:vc.title;
    self.chatId=title.length?title:[NSString stringWithFormat:@"chat-%p",vc];
    TPDebugLogger.shared.pageState=[NSString stringWithFormat:@"chat vc=%@ chat=%@",className,self.chatId];
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"chat page accepted vc=%@ chat=%@ composer=%@ listViews=%ld messageCells=%ld",className,self.chatId,NSStringFromClass(composer.class),(long)lists,(long)[stats[@"messageLikeCells"] integerValue]]];
    if([composer isKindOfClass:UITextView.class])[TPComposerController.shared attachToComposer:(UITextView*)composer chatId:self.chatId];
    if(!self.timer){
        self.timer=[NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(rescan) userInfo:nil repeats:YES];
        self.timer.tolerance=0.35;
    }
    [self rescan];
    return YES;
}

-(void)rescan{
    if(!self.inChatPage||!self.root.window||!self.composer.window){
        [self stopObserving];
        return;
    }
    [TPMessageScanner.shared scanRoot:self.root composer:self.composer chatId:self.chatId];
}

-(void)stopObserving{
    if(self.timer){
        [self.timer invalidate];
        self.timer=nil;
    }
    if(self.inChatPage)[TPDebugLogger.shared log:[NSString stringWithFormat:@"chat page stopped chat=%@",self.chatId?:@"unknown"]];
    self.inChatPage=NO;
    self.root=nil;
    self.composer=nil;
    self.chatId=nil;
    if([TPDebugLogger.shared.pageState hasPrefix:@"chat"])TPDebugLogger.shared.pageState=@"not-chat";
}

-(void)settingsChanged{
    if(TPSettings.shared.autoTranslate&&self.inChatPage)[self rescan];
}

@end
