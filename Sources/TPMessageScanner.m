#import "TPMessageScanner.h"
#import "TPMessageTextExtractor.h"
#import "TPTranslationRenderer.h"
#import "TPTranslationService.h"
#import "TPSettings.h"
#import "TPCacheStore.h"
#import "TPDebugLogger.h"
#import <objc/runtime.h>

static const void *TPMessageIdentityKey=&TPMessageIdentityKey;

@interface TPMessageScanner()
@property(nonatomic,strong)NSMutableSet *inFlightKeys;
@end

@implementation TPMessageScanner

+(instancetype)shared{
    static TPMessageScanner *x;
    static dispatch_once_t once;
    dispatch_once(&once,^{x=[self new];x.inFlightKeys=[NSMutableSet set];});
    return x;
}

-(void)collectFromView:(UIView*)view cells:(NSMutableArray*)cells stats:(NSMutableDictionary*)stats depth:(NSUInteger)depth{
    if(!view||depth>90||view.hidden||view.alpha<0.05)return;
    NSString *name=NSStringFromClass(view.class).lowercaseString?:@"";
    if([view isKindOfClass:UIScrollView.class]){
        stats[@"scrollViews"]=@([stats[@"scrollViews"] integerValue]+1);
        if([view isKindOfClass:UITableView.class])stats[@"tableViews"]=@([stats[@"tableViews"] integerValue]+1);
        if([view isKindOfClass:UICollectionView.class])stats[@"collectionViews"]=@([stats[@"collectionViews"] integerValue]+1);
    }
    BOOL native=[view isKindOfClass:UITableViewCell.class]||[view isKindOfClass:UICollectionViewCell.class];
    BOOL custom=([name containsString:@"message"]||[name containsString:@"chatcell"]||[name containsString:@"bubblecell"])&&CGRectGetHeight(view.bounds)>=20&&CGRectGetHeight(view.bounds)<650;
    if((native||custom)&&view.window){
        [cells addObject:view];
        stats[@"messageCells"]=@([stats[@"messageCells"] integerValue]+1);
        if(native)return;
    }
    for(UIView *sub in view.subviews)[self collectFromView:sub cells:cells stats:stats depth:depth+1];
}

+(BOOL)isSelfChat:(NSString*)chat{
    NSString *clean=[[chat?:@"" componentsSeparatedByCharactersInSet:NSCharacterSet.controlCharacterSet] componentsJoinedByString:@""];
    clean=[clean stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *lower=clean.lowercaseString;
    return [clean isEqualToString:@"你"]||[lower isEqualToString:@"you"]||[lower containsString:@"(you)"]||[clean containsString:@"（你）"];
}

-(NSString*)reasonSummary:(NSDictionary*)reasons{
    if(!reasons.count)return @"none";
    NSMutableArray *parts=[NSMutableArray array];
    for(NSString *key in [reasons.allKeys sortedArrayUsingSelector:@selector(compare:)]){
        [parts addObject:[NSString stringWithFormat:@"%@=%@",key,reasons[key]]];
    }
    return [parts componentsJoinedByString:@","];
}

-(void)mergeExtractorDiagnostics:(NSDictionary*)diag intoReasons:(NSMutableDictionary*)reasons{
    NSDictionary *skip=diag[@"skipReasons"];
    for(NSString *key in skip){
        NSInteger old=[reasons[key] integerValue];
        reasons[key]=@(old+[skip[key] integerValue]);
    }
}

-(BOOL)cell:(UIView*)cell visibleInRoot:(UIView*)root beforeComposer:(UIView*)composer{
    if(!cell.window||!root.window)return NO;
    CGRect r=[cell convertRect:cell.bounds toView:root];
    if(CGRectIsEmpty(r)||!CGRectIntersectsRect(r,root.bounds))return NO;
    if(composer.window){
        CGRect input=[composer convertRect:composer.bounds toView:root];
        if(CGRectGetMinY(r)>=CGRectGetMinY(input)-4)return NO;
    }
    return YES;
}

-(NSString*)requestKeyForMessage:(TPExtractedMessage*)message chat:(NSString*)chat{
    return [NSString stringWithFormat:@"%@|%@",chat?:@"unknown",message.messageId?:@""];
}

-(void)scanRoot:(UIView*)root composer:(UIView*)composer chatId:(NSString*)chat{
    TPSettings *settings=TPSettings.shared;
    if(!settings.autoTranslate||!settings.autoScanVisibleMessages||!root.window||!composer.window){
        NSString *reason=!settings.autoTranslate?@"autoTranslate-off":(!settings.autoScanVisibleMessages?@"autoScan-off":@"not-visible");
        TPDebugLogger.shared.scanSummary=[NSString stringWithFormat:@"scan skipped reason=%@",reason];
        [TPDebugLogger.shared log:TPDebugLogger.shared.scanSummary];
        return;
    }
    NSDate *started=NSDate.date;
    NSMutableArray *cells=[NSMutableArray array];
    NSMutableDictionary *stats=[@{@"scrollViews":@0,@"tableViews":@0,@"collectionViews":@0,@"messageCells":@0} mutableCopy];
    [self collectFromView:root cells:cells stats:stats depth:0];
    BOOL selfChat=[TPMessageScanner isSelfChat:chat];
    BOOL allowOutgoing=settings.translateOutgoing||selfChat;
    NSInteger extracted=0,queued=0,cached=0,renderedCached=0,skippedNoText=0,skippedOutgoing=0,skippedAlreadyTranslated=0,skippedTranslating=0,skippedInvisible=0,skippedSame=0,skippedInFlight=0,cellReset=0,detailLogs=0;
    NSMutableDictionary *skipReasons=[NSMutableDictionary dictionary];
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"scan begin time=%@ chat=%@ root=%@ composer=%@ scrollViews=%ld tableViews=%ld collectionViews=%ld messageCells=%ld",
                               started,chat?:@"unknown",NSStringFromClass(root.class),NSStringFromClass(composer.class),
                               (long)[stats[@"scrollViews"] integerValue],(long)[stats[@"tableViews"] integerValue],(long)[stats[@"collectionViews"] integerValue],(long)[stats[@"messageCells"] integerValue]]];
    for(UIView *cell in cells){
        if(![self cell:cell visibleInRoot:root beforeComposer:composer]){skippedInvisible++;continue;}
        NSDictionary *diag=nil;
        TPExtractedMessage *message=[TPMessageTextExtractor extractFromCell:cell inRoot:root diagnostics:&diag];
        if(!message){
            skippedNoText++;
            [self mergeExtractorDiagnostics:diag intoReasons:skipReasons];
            if(detailLogs<12){
                detailLogs++;
                [TPDebugLogger.shared log:[NSString stringWithFormat:@"extract skipped cell=%@ result=%@ visited=%@ accepted=%@ skipped=%@ reasons=%@",
                                           NSStringFromClass(cell.class),diag[@"result"]?:@"nil",diag[@"visitedViews"]?:@0,diag[@"acceptedCandidates"]?:@0,diag[@"skippedCandidates"]?:@0,[self reasonSummary:diag[@"skipReasons"]]]];
            }
            continue;
        }
        extracted++;
        if(detailLogs<20){
            detailLogs++;
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"extract ok cell=%@ source=%@ prop=%@ len=%lu preview=%@ containsChinese=%@ outgoing=%@ key=%@",
                                       NSStringFromClass(cell.class),message.sourceClass?:@"unknown",message.sourceProperty?:@"unknown",(unsigned long)message.text.length,message.preview?:@"",message.containsChinese?@"YES":@"NO",message.outgoing?@"YES":@"NO",message.messageId?:@"nil"]];
        }
        if(message.outgoing&&!allowOutgoing){
            skippedOutgoing++;
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"skip key=%@ reason=outgoing-disabled",message.messageId?:@"nil"]];
            continue;
        }
        NSString *prior=objc_getAssociatedObject(cell,TPMessageIdentityKey);
        if(prior.length&&![prior isEqualToString:message.messageId]){
            cellReset++;
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"cell reuse cleanup cell=%@ oldKey=%@ newKey=%@",NSStringFromClass(cell.class),prior,message.messageId?:@"nil"]];
            [TPTranslationRenderer resetCell:cell];
            objc_setAssociatedObject(cell,TPMessageIdentityKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        TPBubbleState state=[TPTranslationRenderer stateForCell:cell];
        if([prior isEqualToString:message.messageId]){
            if(state==TPBubbleStateTranslated){skippedAlreadyTranslated++;continue;}
            if(state==TPBubbleStateTranslating){skippedTranslating++;continue;}
            if(state==TPBubbleStateFailed){skippedSame++;continue;}
        }
        objc_setAssociatedObject(cell,TPMessageIdentityKey,message.messageId,OBJC_ASSOCIATION_COPY_NONATOMIC);
        NSDictionary *cachedEntry=[TPCacheStore.shared entryForChat:chat text:message.text target:settings.targetLanguage];
        if(cachedEntry[@"translation"]){
            cached++;
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"translate cache-hit key=%@ chat=%@ len=%lu",message.messageId?:@"nil",chat?:@"unknown",(unsigned long)message.text.length]];
            [TPTranslationRenderer setTranslation:cachedEntry[@"translation"] forMessage:message];
            renderedCached++;
            continue;
        }
        NSString *requestKey=[self requestKeyForMessage:message chat:chat];
        if([self.inFlightKeys containsObject:requestKey]){
            skippedInFlight++;
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"skip key=%@ reason=in-flight",message.messageId?:@"nil"]];
            continue;
        }
        queued++;
        [self.inFlightKeys addObject:requestKey];
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"queue translation key=%@ chat=%@ model=%@ source=%@ prop=%@",
                                   message.messageId?:@"nil",chat?:@"unknown",settings.model?:@"",message.sourceClass?:@"unknown",message.sourceProperty?:@"unknown"]];
        [self translate:message chat:chat requestKey:requestKey];
    }
    NSTimeInterval duration=-[started timeIntervalSinceNow];
    NSString *summary=[NSString stringWithFormat:@"scan end chat=%@ selfChat=%@ allowOutgoing=%@ duration=%.3f scroll=%ld table=%ld collection=%ld messageCells=%ld visibleCells=%lu extracted=%ld queued=%ld cacheHits=%ld renderedCached=%ld skippedNoText=%ld skippedOutgoing=%ld skippedTranslated=%ld skippedTranslating=%ld skippedFailed=%ld skippedInFlight=%ld skippedInvisible=%ld cellReset=%ld extractorSkipReasons={%@}",
                       chat?:@"unknown",selfChat?@"YES":@"NO",allowOutgoing?@"YES":@"NO",duration,
                       (long)[stats[@"scrollViews"] integerValue],(long)[stats[@"tableViews"] integerValue],(long)[stats[@"collectionViews"] integerValue],(long)[stats[@"messageCells"] integerValue],(unsigned long)cells.count,
                       (long)extracted,(long)queued,(long)cached,(long)renderedCached,(long)skippedNoText,(long)skippedOutgoing,(long)skippedAlreadyTranslated,(long)skippedTranslating,(long)skippedSame,(long)skippedInFlight,(long)skippedInvisible,(long)cellReset,[self reasonSummary:skipReasons]];
    TPDebugLogger.shared.scanSummary=summary;
    [TPDebugLogger.shared log:summary];
}

-(void)translate:(TPExtractedMessage*)message chat:(NSString*)chat requestKey:(NSString*)requestKey{
    if(requestKey.length)[self.inFlightKeys addObject:requestKey];
    [TPTranslationRenderer setTranslatingForMessage:message];
    __weak typeof(self) weakSelf=self;
    __weak UIView *weakCell=message.cell;
    NSString *expectedKey=message.messageId;
    [TPTranslationService translate:message.text chatId:chat completion:^(NSString *translation,NSError *error){
        TPMessageScanner *strong=weakSelf;
        if(strong)[strong.inFlightKeys removeObject:requestKey];
        UIView *cell=weakCell;
        NSString *currentKey=cell?objc_getAssociatedObject(cell,TPMessageIdentityKey):nil;
        if(!cell.window||!currentKey.length||![currentKey isEqualToString:expectedKey]){
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"drop translation key=%@ reason=cell-stale currentKey=%@ cell=%@",expectedKey?:@"nil",currentKey?:@"nil",cell?NSStringFromClass(cell.class):@"nil"]];
            return;
        }
        if(translation.length){
            [TPTranslationRenderer setTranslation:translation forMessage:message];
        }else{
            TPDebugLogger.shared.lastError=error.localizedDescription?:@"translation failed";
            [TPTranslationRenderer setFailure:error forMessage:message retry:^{[strong translate:message chat:chat requestKey:requestKey];}];
        }
    }];
}

@end
