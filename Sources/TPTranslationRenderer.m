#import "TPTranslationRenderer.h"
#import "TPSettings.h"
#import "TPRetryController.h"
#import "TPDebugLogger.h"
#import <objc/runtime.h>

static const void *TPStateKey=&TPStateKey;
static const void *TPMessageKey=&TPMessageKey;
static const void *TPTranslationTextKey=&TPTranslationTextKey;
static const void *TPSourceViewKey=&TPSourceViewKey;
static const void *TPFallbackLabelKey=&TPFallbackLabelKey;
static const void *TPFallbackConstraintsKey=&TPFallbackConstraintsKey;
static const void *TPFallbackSpacerKey=&TPFallbackSpacerKey;
static const void *TPFallbackSourceKey=&TPFallbackSourceKey;
static const void *TPReservedHeightKey=&TPReservedHeightKey;
static const void *TPBaseTransformKey=&TPBaseTransformKey;
static const void *TPAppliedShiftKey=&TPAppliedShiftKey;
static const void *TPAppliedFrameKey=&TPAppliedFrameKey;
static const void *TPTableAppliedExtraKey=&TPTableAppliedExtraKey;
static const void *TPTableBaseContentHeightKey=&TPTableBaseContentHeightKey;
static const void *TPTableExpectedContentHeightKey=&TPTableExpectedContentHeightKey;
static const void *TPOriginalTextKey=&TPOriginalTextKey;
static const void *TPOriginalAttributedTextKey=&TPOriginalAttributedTextKey;
static const void *TPOriginalLinesKey=&TPOriginalLinesKey;
static const void *TPOriginalEditableKey=&TPOriginalEditableKey;
static const void *TPOriginalSelectableKey=&TPOriginalSelectableKey;
static const void *TPOriginalInteractionKey=&TPOriginalInteractionKey;
static const NSInteger TPTranslationLabelTag=0x7A71001;

@interface TPTranslationRenderer()
+(UITableView*)tableForCell:(UIView*)cell;
+(void)updateReservedHeightForMessage:(TPExtractedMessage*)message label:(UILabel*)label;
+(void)refreshVisibleSpacingNearCell:(UIView*)cell;
@end

@implementation TPTranslationRenderer

+(TPBubbleState)stateForCell:(UIView*)cell{
    NSNumber *n=objc_getAssociatedObject(cell,TPStateKey);
    return n?(TPBubbleState)n.integerValue:TPBubbleStateUnprocessed;
}

+(NSArray*)plainTextKeys{return @[@"text",@"messageText",@"displayText",@"plainText",@"contentText",@"bodyText",@"title",@"string"];}
+(NSArray*)richTextKeys{return @[@"attributedText",@"attributedString",@"messageAttributedText",@"displayAttributedText",@"attributedTitle"];}

+(id)safeValue:(id)object key:(NSString*)key{
    if(!object||!key.length)return nil;
    @try{return [object valueForKey:key];}
    @catch(NSException *e){return nil;}
}

+(BOOL)safeSet:(id)value object:(id)object key:(NSString*)key{
    if(!object||!key.length)return NO;
    @try{[object setValue:value forKey:key];return YES;}
    @catch(NSException *e){return NO;}
}

+(NSString*)preview:(NSString*)text{
    NSString *t=[text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    if(t.length>80)return [[t substringToIndex:80] stringByAppendingString:@"..."];
    return t?:@"";
}

+(NSString*)displayText:(NSString*)translation state:(TPBubbleState)state{
    if(state==TPBubbleStateFailed)return @"翻译失败 · 点按重试";
    NSString *prefix=TPSettings.shared.showTranslationPrefix?(TPSettings.shared.translationPrefix?:@"译文："):@"";
    return [prefix stringByAppendingString:translation?:@""];
}

+(UIColor*)baseTextColorFromSource:(UIView*)source{
    if([source isKindOfClass:UILabel.class])return ((UILabel*)source).textColor?:UIColor.blackColor;
    if([source isKindOfClass:UITextView.class])return ((UITextView*)source).textColor?:UIColor.blackColor;
    id v=[self safeValue:source key:@"textColor"];
    return [v isKindOfClass:UIColor.class]?v:UIColor.blackColor;
}

+(UIColor*)translationColorFromSource:(UIView*)source failed:(BOOL)failed{
    if(failed){
        if(@available(iOS 13,*))return UIColor.systemRedColor;
        return UIColor.redColor;
    }
    UIColor *base=[self baseTextColorFromSource:source];
    if([base respondsToSelector:@selector(colorWithAlphaComponent:)])return [base colorWithAlphaComponent:0.72];
    if(@available(iOS 13,*))return UIColor.secondaryLabelColor;
    return UIColor.darkGrayColor;
}

+(UIFont*)fontFromSource:(UIView*)source failed:(BOOL)failed{
    UIFont *font=nil;
    if([source isKindOfClass:UILabel.class])font=((UILabel*)source).font;
    else if([source isKindOfClass:UITextView.class])font=((UITextView*)source).font;
    else if([source isKindOfClass:UITextField.class])font=((UITextField*)source).font;
    else {
        id v=[self safeValue:source key:@"font"];
        if([v isKindOfClass:UIFont.class])font=v;
    }
    CGFloat size=MAX(11.0,MIN((font?:[UIFont systemFontOfSize:16]).pointSize-1.5,15.0));
    return failed?[UIFont systemFontOfSize:size weight:UIFontWeightSemibold]:[UIFont systemFontOfSize:size weight:UIFontWeightRegular];
}

+(NSString*)textFromSource:(UIView*)source{
    if([source isKindOfClass:UILabel.class])return ((UILabel*)source).text?:@"";
    if([source isKindOfClass:UITextView.class])return ((UITextView*)source).text?:@"";
    if([source isKindOfClass:UITextField.class])return ((UITextField*)source).text?:@"";
    for(NSString *key in self.plainTextKeys){
        id v=[self safeValue:source key:key];
        if([v isKindOfClass:NSString.class]&&[(NSString*)v length])return v;
    }
    return @"";
}

+(NSAttributedString*)attributedTextFromSource:(UIView*)source{
    if([source isKindOfClass:UILabel.class])return ((UILabel*)source).attributedText;
    if([source isKindOfClass:UITextView.class])return ((UITextView*)source).attributedText;
    for(NSString *key in self.richTextKeys){
        id v=[self safeValue:source key:key];
        if([v isKindOfClass:NSAttributedString.class]&&[(NSAttributedString*)v length])return v;
    }
    return nil;
}

+(BOOL)string:(NSString*)haystack containsMessage:(NSString*)message{
    NSString *h=[haystack stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *m=[message stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!h.length||!m.length)return NO;
    return [h containsString:m]||[m containsString:h];
}

+(void)collectViews:(UIView*)view into:(NSMutableArray*)views depth:(NSUInteger)depth{
    if(!view||depth>90)return;
    [views addObject:view];
    for(UIView *sub in view.subviews)[self collectViews:sub into:views depth:depth+1];
}

+(NSString*)supportSummaryForHost:(UIView*)host{
    NSMutableArray *parts=[NSMutableArray array];
    for(NSString *key in self.plainTextKeys){
        NSString *setter=[NSString stringWithFormat:@"set%@%@:",[[key substringToIndex:1] uppercaseString],[key substringFromIndex:1]];
        if([host respondsToSelector:NSSelectorFromString(setter)])[parts addObject:[key stringByAppendingString:@"=setter"]];
    }
    for(NSString *key in self.richTextKeys){
        NSString *setter=[NSString stringWithFormat:@"set%@%@:",[[key substringToIndex:1] uppercaseString],[key substringFromIndex:1]];
        if([host respondsToSelector:NSSelectorFromString(setter)])[parts addObject:[key stringByAppendingString:@"=setter"]];
    }
    if([host isKindOfClass:UILabel.class])[parts addObject:@"UILabel"];
    if([host isKindOfClass:UITextView.class])[parts addObject:@"UITextView"];
    return parts.count?[parts componentsJoinedByString:@","]:@"none";
}

+(BOOL)viewLooksLikeMessageHost:(UIView*)view message:(TPExtractedMessage*)message{
    if(!view||view.hidden||view.alpha<0.05)return NO;
    if(view==message.cell)return NO;
    if([view isKindOfClass:UITableViewCell.class]||[view isKindOfClass:UICollectionViewCell.class])return NO;
    if(view==message.sourceView)return YES;
    NSString *text=[self textFromSource:view];
    if([self string:text containsMessage:message.text])return YES;
    if([self string:view.accessibilityLabel containsMessage:message.text])return YES;
    if([self string:view.accessibilityValue containsMessage:message.text])return YES;
    NSString *name=NSStringFromClass(view.class).lowercaseString;
    NSString *candidate=text.length?text:view.accessibilityLabel;
    return ([name containsString:@"message"]||[name containsString:@"text"]||[name containsString:@"slice"])&&[self string:candidate containsMessage:message.text];
}

+(NSArray*)candidateTextHostsForMessage:(TPExtractedMessage*)message{
    NSMutableArray *views=[NSMutableArray array];
    NSMutableArray *result=[NSMutableArray array];
    NSMutableSet *seen=[NSMutableSet set];
    [self collectViews:message.cell into:views depth:0];
    void (^add)(UIView*)=^(UIView *view){
        if(!view)return;
        NSValue *key=[NSValue valueWithNonretainedObject:view];
        if([seen containsObject:key])return;
        [seen addObject:key];
        [result addObject:view];
    };
    add(message.sourceView);
    for(UIView *view in views)if([self viewLooksLikeMessageHost:view message:message])add(view);
    return result;
}

+(NSMutableAttributedString*)baseAttributedTextForSource:(UIView*)source original:(NSString*)original{
    NSAttributedString *stored=objc_getAssociatedObject(source,TPOriginalAttributedTextKey);
    if(stored.length)return [stored mutableCopy];
    NSString *text=objc_getAssociatedObject(source,TPOriginalTextKey)?:original?:[self textFromSource:source]?:@"";
    NSDictionary *attrs=@{NSFontAttributeName:[self fontFromSource:source failed:NO],
                          NSForegroundColorAttributeName:[self baseTextColorFromSource:source]};
    return [[NSMutableAttributedString alloc] initWithString:text attributes:attrs];
}

+(void)rememberOriginalSource:(UIView*)source cell:(UIView*)cell originalText:(NSString*)originalText{
    if(!source||objc_getAssociatedObject(source,TPOriginalTextKey))return;
    objc_setAssociatedObject(cell,TPSourceViewKey,source,OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(source,TPOriginalTextKey,originalText?:[self textFromSource:source]?:@"",OBJC_ASSOCIATION_COPY_NONATOMIC);
    NSAttributedString *attr=[self attributedTextFromSource:source];
    if(attr.length)objc_setAssociatedObject(source,TPOriginalAttributedTextKey,attr,OBJC_ASSOCIATION_COPY_NONATOMIC);
    if([source isKindOfClass:UILabel.class])objc_setAssociatedObject(source,TPOriginalLinesKey,@(((UILabel*)source).numberOfLines),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    else {
        id lines=[self safeValue:source key:@"numberOfLines"];
        if(lines)objc_setAssociatedObject(source,TPOriginalLinesKey,lines,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if([source isKindOfClass:UITextView.class]){
        UITextView *view=(UITextView*)source;
        objc_setAssociatedObject(source,TPOriginalEditableKey,@(view.editable),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(source,TPOriginalSelectableKey,@(view.selectable),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    objc_setAssociatedObject(source,TPOriginalInteractionKey,@(source.userInteractionEnabled),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+(void)restoreSource:(UIView*)source{
    if(!source)return;
    NSAttributedString *attr=objc_getAssociatedObject(source,TPOriginalAttributedTextKey);
    NSString *text=objc_getAssociatedObject(source,TPOriginalTextKey);
    NSNumber *lines=objc_getAssociatedObject(source,TPOriginalLinesKey);
    NSNumber *interaction=objc_getAssociatedObject(source,TPOriginalInteractionKey);
    if([source isKindOfClass:UILabel.class]){
        UILabel *label=(UILabel*)source;
        if(attr.length)label.attributedText=attr;else if(text)label.text=text;
        if(lines)label.numberOfLines=lines.integerValue;
    }else if([source isKindOfClass:UITextView.class]){
        UITextView *view=(UITextView*)source;
        NSNumber *editable=objc_getAssociatedObject(source,TPOriginalEditableKey);
        NSNumber *selectable=objc_getAssociatedObject(source,TPOriginalSelectableKey);
        if(attr.length)view.attributedText=attr;else if(text)view.text=text;
        if(editable)view.editable=editable.boolValue;
        if(selectable)view.selectable=selectable.boolValue;
    }else{
        BOOL restored=NO;
        if(attr.length){
            for(NSString *key in self.richTextKeys)if([self safeSet:attr object:source key:key]){restored=YES;break;}
        }
        if(!restored&&text.length){
            for(NSString *key in self.plainTextKeys)if([self safeSet:text object:source key:key])break;
        }
        if(lines)[self safeSet:lines object:source key:@"numberOfLines"];
    }
    if(interaction)source.userInteractionEnabled=interaction.boolValue;
    objc_setAssociatedObject(source,TPOriginalTextKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalAttributedTextKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalLinesKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalEditableKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalSelectableKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalInteractionKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+(BOOL)setStyledText:(NSAttributedString*)styled plain:(NSString*)plain source:(UIView*)source failed:(BOOL)failed usedKey:(NSString**)usedKey{
    if([source isKindOfClass:UILabel.class]){
        UILabel *label=(UILabel*)source;
        label.numberOfLines=0;
        label.attributedText=styled;
        label.userInteractionEnabled=failed;
        if(usedKey)*usedKey=@"UILabel.attributedText";
        return YES;
    }
    if([source isKindOfClass:UITextView.class]){
        UITextView *view=(UITextView*)source;
        view.editable=NO;
        view.selectable=failed;
        view.scrollEnabled=NO;
        view.attributedText=styled;
        if(usedKey)*usedKey=@"UITextView.attributedText";
        return YES;
    }
    [self safeSet:@0 object:source key:@"numberOfLines"];
    for(NSString *key in self.richTextKeys)if([self safeSet:styled object:source key:key]){if(usedKey)*usedKey=key;return YES;}
    for(NSString *key in self.plainTextKeys)if([self safeSet:plain object:source key:key]){if(usedKey)*usedKey=key;return YES;}
    return NO;
}

+(void)refreshLayoutAroundCell:(UIView*)cell{
    for(UIView *v=cell;v;v=v.superview){
        [v setNeedsDisplay];
        [v setNeedsLayout];
    }
    [cell layoutIfNeeded];
    UIView *list=cell.superview;
    while(list&&![list isKindOfClass:UITableView.class]&&![list isKindOfClass:UICollectionView.class])list=list.superview;
    if([list isKindOfClass:UITableView.class]){
        UITableView *table=(UITableView*)list;
        [UIView performWithoutAnimation:^{[table beginUpdates];[table endUpdates];}];
    }else if([list isKindOfClass:UICollectionView.class]){
        UICollectionView *collection=(UICollectionView*)list;
        [UIView performWithoutAnimation:^{[collection.collectionViewLayout invalidateLayout];[collection layoutIfNeeded];}];
    }
}

+(BOOL)sourceMayClipAfterInline:(UIView*)source{
    CGFloat width=MAX(40.0,CGRectGetWidth(source.bounds));
    if(width<=0||CGRectGetHeight(source.bounds)<=0)return NO;
    if([source isKindOfClass:UILabel.class]){
        UILabel *label=(UILabel*)source;
        CGSize needed=[label sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)];
        return needed.height>CGRectGetHeight(label.bounds)+8.0&&CGRectGetHeight(label.bounds)<needed.height*0.85;
    }
    if([source isKindOfClass:UITextView.class]){
        UITextView *view=(UITextView*)source;
        CGSize needed=[view sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)];
        return needed.height>CGRectGetHeight(view.bounds)+8.0&&CGRectGetHeight(view.bounds)<needed.height*0.85;
    }
    return NO;
}

+(BOOL)tryInlineForMessage:(TPExtractedMessage*)message line:(NSString*)line failed:(BOOL)failed{
    for(UIView *host in [self candidateTextHostsForMessage:message]){
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"render inline-probe cell=%@ host=%@ supports={%@} sourceProp=%@",
                                   NSStringFromClass(message.cell.class),NSStringFromClass(host.class),[self supportSummaryForHost:host],message.sourceProperty?:@"unknown"]];
        [self rememberOriginalSource:host cell:message.cell originalText:message.text];
        NSMutableAttributedString *styled=[self baseAttributedTextForSource:host original:message.text];
        NSDictionary *translationAttrs=@{NSFontAttributeName:[self fontFromSource:host failed:failed],
                                         NSForegroundColorAttributeName:[self translationColorFromSource:host failed:failed]};
        [styled appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:line] attributes:translationAttrs]];
        NSString *plain=[NSString stringWithFormat:@"%@\n%@",message.text?:@"",line?:@""];
        NSString *used=nil;
        if(![self setStyledText:styled plain:plain source:host failed:failed usedKey:&used]){
            [self restoreSource:host];
            continue;
        }
        [self refreshLayoutAroundCell:message.cell];
        if([self sourceMayClipAfterInline:host]){
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"render inline-reject reason=possible-clip host=%@ bounds=%@",NSStringFromClass(host.class),NSStringFromCGRect(host.bounds)]];
            [self restoreSource:host];
            continue;
        }
        objc_setAssociatedObject(message.cell,TPSourceViewKey,host,OBJC_ASSOCIATION_ASSIGN);
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"render strategy=inline-native cell=%@ host=%@ used=%@ hostFrame=%@ layoutRefreshed=YES",
                                   NSStringFromClass(message.cell.class),NSStringFromClass(host.class),used?:@"unknown",NSStringFromCGRect([host convertRect:host.bounds toView:message.cell])]];
        return YES;
    }
    return NO;
}

+(UIView*)findInView:(UIView*)view classNameContainsAny:(NSArray*)needles{
    if(!view)return nil;
    NSString *name=NSStringFromClass(view.class).lowercaseString?:@"";
    for(NSString *needle in needles)if([name containsString:[needle lowercaseString]])return view;
    for(UIView *sub in view.subviews){
        UIView *found=[self findInView:sub classNameContainsAny:needles];
        if(found)return found;
    }
    return nil;
}

+(UIView*)bubbleContainerForMessage:(TPExtractedMessage*)message{
    NSArray *strong=@[@"wdsbubble",@"bubble",@"messagecontainer",@"messagecontent",@"balloon"];
    UIView *best=nil;
    NSInteger bestScore=NSIntegerMin;
    for(UIView *v=message.sourceView;v&&v!=message.cell;v=v.superview){
        NSString *name=NSStringFromClass(v.class).lowercaseString?:@"";
        NSInteger score=0;
        for(NSString *needle in strong)if([name containsString:needle])score+=40;
        if(CGRectGetWidth(v.bounds)>=CGRectGetWidth(message.sourceView.bounds))score+=5;
        if(CGRectGetHeight(v.bounds)>=CGRectGetHeight(message.sourceView.bounds))score+=5;
        if(score>bestScore){bestScore=score;best=v;}
    }
    if(best&&best!=message.cell)return best;
    UIView *found=[self findInView:message.cell classNameContainsAny:strong];
    if(found&&found!=message.cell)return found;
    return message.sourceView.superview&&message.sourceView.superview!=message.cell?message.sourceView.superview:nil;
}

+(UIView*)statusViewInContainer:(UIView*)container{
    return [self findInView:container classNameContainsAny:@[@"status",@"timestamp",@"receipt",@"readreceipt",@"time"]];
}

+(void)removeFallbackFromCell:(UIView*)cell{
    UILabel *label=objc_getAssociatedObject(cell,TPFallbackLabelKey);
    UIView *spacer=objc_getAssociatedObject(cell,TPFallbackSpacerKey);
    NSArray *constraints=objc_getAssociatedObject(cell,TPFallbackConstraintsKey);
    if(constraints.count)[NSLayoutConstraint deactivateConstraints:constraints];
    [label removeFromSuperview];
    [spacer removeFromSuperview];
    objc_setAssociatedObject(cell,TPFallbackLabelKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell,TPFallbackSpacerKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell,TPFallbackSourceKey,nil,OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(cell,TPFallbackConstraintsKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+(UILabel*)preparedFallbackLabelForCell:(UIView*)cell container:(UIView*)container failed:(BOOL)failed source:(UIView*)source text:(NSString*)text{
    UILabel *label=objc_getAssociatedObject(cell,TPFallbackLabelKey);
    if(!label){
        label=[UILabel new];
        label.tag=TPTranslationLabelTag;
        label.accessibilityIdentifier=@"tp.translation";
        label.backgroundColor=UIColor.clearColor;
        label.numberOfLines=0;
        label.lineBreakMode=NSLineBreakByWordWrapping;
        label.translatesAutoresizingMaskIntoConstraints=NO;
        objc_setAssociatedObject(cell,TPFallbackLabelKey,label,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if(label.superview!=container){
        [label removeFromSuperview];
        [container addSubview:label];
    }
    label.text=text?:@"";
    label.font=[self fontFromSource:source failed:failed];
    label.textColor=[self translationColorFromSource:source failed:failed];
    label.userInteractionEnabled=failed;
    [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    return label;
}

+(void)positionOverlayLabel:(UILabel*)label forCell:(UIView*)cell{
    UITableView *table=[self tableForCell:cell];
    UIView *source=objc_getAssociatedObject(cell,TPFallbackSourceKey);
    if(!table||!label||!source||label.superview!=table||!source.window)return;
    CGRect sourceRect=[source convertRect:source.bounds toView:table];
    CGFloat width=MAX(80.0,MIN(CGRectGetWidth(sourceRect),CGRectGetWidth(table.bounds)-CGRectGetMinX(sourceRect)-12.0));
    CGSize fit=[label sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)];
    label.frame=CGRectIntegral(CGRectMake(CGRectGetMinX(sourceRect),CGRectGetMaxY(sourceRect)+4.0,width,fit.height));
    [table bringSubviewToFront:label];
}

+(BOOL)renderTableOverlayFallbackForMessage:(TPExtractedMessage*)message line:(NSString*)line failed:(BOOL)failed source:(UIView*)source{
    UITableView *table=[self tableForCell:message.cell];
    if(!table||!source.window)return NO;
    UILabel *label=[self preparedFallbackLabelForCell:message.cell container:table failed:failed source:source text:line];
    NSArray *old=objc_getAssociatedObject(message.cell,TPFallbackConstraintsKey);
    if(old.count)[NSLayoutConstraint deactivateConstraints:old];
    objc_setAssociatedObject(message.cell,TPFallbackConstraintsKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(message.cell,TPFallbackSourceKey,source,OBJC_ASSOCIATION_ASSIGN);
    label.translatesAutoresizingMaskIntoConstraints=YES;
    [self positionOverlayLabel:label forCell:message.cell];
    [self updateReservedHeightForMessage:message label:label];
    [self refreshVisibleSpacingNearCell:message.cell];
    [self positionOverlayLabel:label forCell:message.cell];
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"render strategy=table-overlay-fallback cell=%@ table=%@ source=%@ labelFrame=%@ layoutRefreshed=YES",
                               NSStringFromClass(message.cell.class),NSStringFromClass(table.class),NSStringFromClass(source.class),NSStringFromCGRect(label.frame)]];
    return YES;
}

+(NSArray*)installCellSpacerForMessage:(TPExtractedMessage*)message label:(UILabel*)label{
    UIView *host=nil;
    if([message.cell respondsToSelector:@selector(contentView)])host=((UITableViewCell*)message.cell).contentView;
    if(!host)host=message.cell;
    UIView *spacer=objc_getAssociatedObject(message.cell,TPFallbackSpacerKey);
    if(!spacer){
        spacer=[UIView new];
        spacer.hidden=YES;
        spacer.userInteractionEnabled=NO;
        spacer.translatesAutoresizingMaskIntoConstraints=NO;
        objc_setAssociatedObject(message.cell,TPFallbackSpacerKey,spacer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if(spacer.superview!=host){
        [spacer removeFromSuperview];
        [host addSubview:spacer];
    }
    spacer.translatesAutoresizingMaskIntoConstraints=NO;
    NSLayoutConstraint *top=[spacer.topAnchor constraintGreaterThanOrEqualToAnchor:label.bottomAnchor constant:8.0];
    NSLayoutConstraint *height=[spacer.heightAnchor constraintGreaterThanOrEqualToConstant:8.0];
    NSLayoutConstraint *bottom=[spacer.bottomAnchor constraintEqualToAnchor:host.bottomAnchor constant:-2.0];
    NSLayoutConstraint *leading=[spacer.leadingAnchor constraintEqualToAnchor:host.leadingAnchor];
    NSLayoutConstraint *trailing=[spacer.trailingAnchor constraintEqualToAnchor:host.trailingAnchor];
    bottom.priority=UILayoutPriorityRequired;
    NSArray *constraints=@[top,height,bottom,leading,trailing];
    @try{[NSLayoutConstraint activateConstraints:constraints];}
    @catch(NSException *e){[TPDebugLogger.shared log:[NSString stringWithFormat:@"render spacer constraints exception=%@",e.reason?:@"unknown"]];}
    host.clipsToBounds=NO;
    message.cell.clipsToBounds=NO;
    return constraints;
}

+(void)collectTablesInView:(UIView*)view into:(NSMutableArray*)tables depth:(NSUInteger)depth{
    if(!view||depth>80)return;
    if([view isKindOfClass:UITableView.class])[tables addObject:view];
    for(UIView *sub in view.subviews)[self collectTablesInView:sub into:tables depth:depth+1];
}

+(UITableView*)tableForCell:(UIView*)cell{
    UIView *v=cell.superview;
    while(v&&![v isKindOfClass:UITableView.class])v=v.superview;
    return (UITableView*)v;
}

+(CGFloat)reservedHeightForCell:(UIView*)cell{
    NSNumber *n=objc_getAssociatedObject(cell,TPReservedHeightKey);
    return n?MAX(0.0,n.doubleValue):0.0;
}

+(void)updateReservedHeightForMessage:(TPExtractedMessage*)message label:(UILabel*)label{
    if(!message.cell||!label)return;
    CGRect r=[label convertRect:label.bounds toView:message.cell];
    CGFloat required=CGRectGetMaxY(r)+12.0-CGRectGetHeight(message.cell.bounds);
    CGFloat extra=MAX(0.0,MIN(required,80.0));
    if(extra<3.0)extra=0.0;
    objc_setAssociatedObject(message.cell,TPReservedHeightKey,@(extra),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"render spacing-reserve cell=%@ labelInCell=%@ cellBounds=%@ extra=%.1f",
                               NSStringFromClass(message.cell.class),NSStringFromCGRect(r),NSStringFromCGRect(message.cell.bounds),extra]];
}

+(void)refreshVisibleSpacingInTable:(UITableView*)table{
    NSMutableArray *items=[NSMutableArray array];
    NSInteger staleShiftFrames=0;
    for(UIView *cell in [table visibleCells]){
        CGFloat oldShift=[objc_getAssociatedObject(cell,TPAppliedShiftKey) doubleValue];
        CGRect currentFrame=cell.frame;
        CGRect baseFrame=currentFrame;
        NSValue *appliedFrameValue=objc_getAssociatedObject(cell,TPAppliedFrameKey);
        BOOL currentStillContainsOldShift=NO;
        if(oldShift>0.5&&appliedFrameValue){
            CGRect appliedFrame=[appliedFrameValue CGRectValue];
            currentStillContainsOldShift=fabs(CGRectGetMinY(currentFrame)-CGRectGetMinY(appliedFrame))<1.5&&fabs(CGRectGetHeight(currentFrame)-CGRectGetHeight(appliedFrame))<1.5;
            if(currentStillContainsOldShift)baseFrame.origin.y-=oldShift;
            else staleShiftFrames++;
        }else if(oldShift>0.5){
            staleShiftFrames++;
        }
        [items addObject:@{@"cell":cell,@"baseFrame":[NSValue valueWithCGRect:baseFrame],@"baseY":@(CGRectGetMinY(baseFrame))}];
    }
    NSArray *sorted=[items sortedArrayUsingComparator:^NSComparisonResult(id obj1,id obj2){
        NSDictionary *a=obj1;
        NSDictionary *b=obj2;
        CGFloat ay=[a[@"baseY"] doubleValue],by=[b[@"baseY"] doubleValue];
        if(ay<by)return NSOrderedAscending;
        if(ay>by)return NSOrderedDescending;
        return NSOrderedSame;
    }];
    CGFloat oldTableExtra=[objc_getAssociatedObject(table,TPTableAppliedExtraKey) doubleValue];
    CGFloat previousBase=[objc_getAssociatedObject(table,TPTableBaseContentHeightKey) doubleValue];
    CGFloat previousExpected=[objc_getAssociatedObject(table,TPTableExpectedContentHeightKey) doubleValue];
    CGSize currentSize=table.contentSize;
    BOOL currentLooksAlreadyPadded=(oldTableExtra>0.5&&previousExpected>0.5&&currentSize.height>=previousExpected-1.0&&currentSize.height<=previousExpected+MAX(48.0,oldTableExtra*0.5));
    BOOL contentSizeLooksStripped=(oldTableExtra>0.5&&previousExpected>0.5&&currentSize.height<previousExpected-1.0&&fabs((previousExpected-currentSize.height)-oldTableExtra)<48.0);
    CGFloat measuredBase=currentLooksAlreadyPadded?MAX(0.0,currentSize.height-oldTableExtra):MAX(0.0,currentSize.height);
    CGFloat visibleBaseBottom=0.0;
    for(NSDictionary *entry in sorted){
        CGRect frame=[entry[@"baseFrame"] CGRectValue];
        visibleBaseBottom=MAX(visibleBaseBottom,CGRectGetMaxY(frame));
    }
    CGFloat baseContentHeight=MAX(measuredBase,visibleBaseBottom);
    if(previousBase>0.5){
        BOOL sameLayoutOrReset=fabs(measuredBase-previousBase)<48.0||currentLooksAlreadyPadded||contentSizeLooksStripped;
        if(sameLayoutOrReset)baseContentHeight=MAX(baseContentHeight,previousBase);
    }
    CGFloat bottomInset=0.0;
    if(@available(iOS 11,*))bottomInset=table.adjustedContentInset.bottom;else bottomInset=table.contentInset.bottom;
    BOOL nearBottom=table.contentOffset.y+CGRectGetHeight(table.bounds)>=currentSize.height+bottomInset-96.0;
    CGFloat cumulative=0.0;
    NSInteger shifted=0;
    for(NSDictionary *entry in sorted){
        UIView *cell=entry[@"cell"];
        CGRect frame=[entry[@"baseFrame"] CGRectValue];
        CGFloat applied=cumulative;
        cell.transform=CGAffineTransformIdentity;
        frame.origin.y+=applied;
        CGRect currentFrame=cell.frame;
        if(fabs(CGRectGetMinY(currentFrame)-CGRectGetMinY(frame))>0.5||fabs(CGRectGetHeight(currentFrame)-CGRectGetHeight(frame))>0.5)cell.frame=frame;
        objc_setAssociatedObject(cell,TPAppliedShiftKey,@(applied),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(cell,TPAppliedFrameKey,[NSValue valueWithCGRect:frame],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if(applied>0.5)shifted++;
        cumulative+=[self reservedHeightForCell:cell];
    }
    CGSize newSize=currentSize;
    newSize.height=MAX(baseContentHeight+cumulative,baseContentHeight);
    if(fabs(newSize.height-currentSize.height)>0.5)table.contentSize=newSize;
    objc_setAssociatedObject(table,TPTableAppliedExtraKey,@(cumulative),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(table,TPTableBaseContentHeightKey,@(baseContentHeight),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(table,TPTableExpectedContentHeightKey,@(newSize.height),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(nearBottom&&newSize.height>CGRectGetHeight(table.bounds)){
        CGFloat targetY=MAX(-table.contentInset.top,newSize.height-CGRectGetHeight(table.bounds)+bottomInset);
        if(fabs(table.contentOffset.y-targetY)>1.0)[table setContentOffset:CGPointMake(table.contentOffset.x,targetY) animated:NO];
    }
    for(NSDictionary *entry in sorted){
        UIView *cell=entry[@"cell"];
        UILabel *label=objc_getAssociatedObject(cell,TPFallbackLabelKey);
        if(label.superview==table)[self positionOverlayLabel:label forCell:cell];
    }
    if(shifted>0||cumulative>0.5)[TPDebugLogger.shared log:[NSString stringWithFormat:@"render visible-spacing table=%@ shifted=%ld staleFrames=%ld totalExtra=%.1f contentHeight=%.1f baseHeight=%.1f currentHeight=%.1f alreadyPadded=%@ stripped=%@ nearBottom=%@",NSStringFromClass(table.class),(long)shifted,(long)staleShiftFrames,cumulative,newSize.height,baseContentHeight,currentSize.height,currentLooksAlreadyPadded?@"YES":@"NO",contentSizeLooksStripped?@"YES":@"NO",nearBottom?@"YES":@"NO"]];
}

+(void)refreshVisibleSpacingInRoot:(UIView*)root{
    NSMutableArray *tables=[NSMutableArray array];
    [self collectTablesInView:root into:tables depth:0];
    for(UITableView *table in tables)[self refreshVisibleSpacingInTable:table];
}

+(void)refreshVisibleSpacingNearCell:(UIView*)cell{
    UITableView *table=[self tableForCell:cell];
    if(table)[self refreshVisibleSpacingInTable:table];
}

+(BOOL)renderBubbleFallbackForMessage:(TPExtractedMessage*)message line:(NSString*)line failed:(BOOL)failed strategyName:(NSString*)strategyName{
    UIView *source=message.sourceView?:message.cell;
    UIView *container=[self bubbleContainerForMessage:message];
    if(!container||container==message.cell)return NO;
    if([self renderTableOverlayFallbackForMessage:message line:line failed:failed source:source])return YES;
    UILabel *label=[self preparedFallbackLabelForCell:message.cell container:container failed:failed source:source text:line];
    label.translatesAutoresizingMaskIntoConstraints=NO;
    NSArray *old=objc_getAssociatedObject(message.cell,TPFallbackConstraintsKey);
    if(old.count)[NSLayoutConstraint deactivateConstraints:old];
    UIView *status=[self statusViewInContainer:container];
    CGRect sourceRect=[source convertRect:source.bounds toView:container];
    CGFloat maxWidth=MAX(80.0,MIN(CGRectGetWidth(container.bounds)-MAX(8.0,CGRectGetMinX(sourceRect))-12.0,CGRectGetWidth(sourceRect)>40?CGRectGetWidth(sourceRect):CGRectGetWidth(container.bounds)-24.0));
    NSLayoutConstraint *top=[label.topAnchor constraintGreaterThanOrEqualToAnchor:source.bottomAnchor constant:4.0];
    NSLayoutConstraint *leading=[label.leadingAnchor constraintEqualToAnchor:source.leadingAnchor];
    NSLayoutConstraint *trailing=[label.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-8.0];
    NSLayoutConstraint *width=[label.widthAnchor constraintLessThanOrEqualToConstant:maxWidth];
    NSMutableArray *constraints=[NSMutableArray arrayWithObjects:top,leading,trailing,width,nil];
    if(status&&status!=label&&status.superview){
        NSLayoutConstraint *bottom=[label.bottomAnchor constraintLessThanOrEqualToAnchor:status.topAnchor constant:-2.0];
        bottom.priority=UILayoutPriorityDefaultHigh;
        [constraints addObject:bottom];
    }else{
        NSLayoutConstraint *bottom=[label.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-6.0];
        bottom.priority=UILayoutPriorityDefaultHigh;
        [constraints addObject:bottom];
    }
    @try{[NSLayoutConstraint activateConstraints:constraints];}
    @catch(NSException *e){[TPDebugLogger.shared log:[NSString stringWithFormat:@"render constraints exception=%@",e.reason?:@"unknown"]];}
    NSArray *spacerConstraints=[self installCellSpacerForMessage:message label:label];
    [constraints addObjectsFromArray:spacerConstraints];
    objc_setAssociatedObject(message.cell,TPFallbackConstraintsKey,constraints,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    container.clipsToBounds=NO;
    for(UIView *v=container.superview;v&&v!=message.cell.superview;v=v.superview)v.clipsToBounds=NO;
    [container setNeedsLayout];
    [container layoutIfNeeded];
    if(CGRectGetWidth(label.frame)<20||CGRectGetHeight(label.frame)<8){
        [NSLayoutConstraint deactivateConstraints:constraints];
        objc_setAssociatedObject(message.cell,TPFallbackConstraintsKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CGSize fit=[label sizeThatFits:CGSizeMake(maxWidth,CGFLOAT_MAX)];
        CGFloat y=CGRectGetMaxY(sourceRect)+4.0;
        if(status){
            CGRect statusRect=[status convertRect:status.bounds toView:container];
            y=MIN(y,MAX(CGRectGetMaxY(sourceRect)+2.0,CGRectGetMinY(statusRect)-fit.height-2.0));
        }
        label.translatesAutoresizingMaskIntoConstraints=YES;
        label.frame=CGRectIntegral(CGRectMake(CGRectGetMinX(sourceRect),y,maxWidth,fit.height));
        NSArray *frameSpacer=[self installCellSpacerForMessage:message label:label];
        objc_setAssociatedObject(message.cell,TPFallbackConstraintsKey,frameSpacer,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [container bringSubviewToFront:label];
    [self refreshLayoutAroundCell:message.cell];
    [self updateReservedHeightForMessage:message label:label];
    [self refreshVisibleSpacingNearCell:message.cell];
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"render strategy=%@ cell=%@ container=%@ bubbleFound=YES source=%@ status=%@ labelFrame=%@ constraints=%lu spacer=YES layoutRefreshed=YES",
                               strategyName,NSStringFromClass(message.cell.class),NSStringFromClass(container.class),NSStringFromClass(source.class),status?NSStringFromClass(status.class):@"none",NSStringFromCGRect(label.frame),(unsigned long)constraints.count]];
    return YES;
}

+(void)renderCellFallbackForMessage:(TPExtractedMessage*)message line:(NSString*)line failed:(BOOL)failed{
    UIView *host=nil;
    if([message.cell respondsToSelector:@selector(contentView)])host=((UITableViewCell*)message.cell).contentView;
    if(!host)host=message.cell;
    UILabel *label=[self preparedFallbackLabelForCell:message.cell container:host failed:failed source:message.sourceView?:message.cell text:line];
    NSArray *old=objc_getAssociatedObject(message.cell,TPFallbackConstraintsKey);
    if(old.count)[NSLayoutConstraint deactivateConstraints:old];
    CGRect sourceRect=[message.sourceView convertRect:message.sourceView.bounds toView:host];
    CGFloat width=MAX(80.0,MIN(CGRectGetWidth(sourceRect)>40?CGRectGetWidth(sourceRect):CGRectGetWidth(host.bounds)-24.0,CGRectGetWidth(host.bounds)-CGRectGetMinX(sourceRect)-12.0));
    label.translatesAutoresizingMaskIntoConstraints=YES;
    CGSize fit=[label sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)];
    label.frame=CGRectIntegral(CGRectMake(CGRectGetMinX(sourceRect),CGRectGetMaxY(sourceRect)+4.0,width,fit.height));
    NSArray *spacerConstraints=[self installCellSpacerForMessage:message label:label];
    objc_setAssociatedObject(message.cell,TPFallbackConstraintsKey,spacerConstraints,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    host.clipsToBounds=NO;
    [host bringSubviewToFront:label];
    [self refreshLayoutAroundCell:message.cell];
    [self updateReservedHeightForMessage:message label:label];
    [self refreshVisibleSpacingNearCell:message.cell];
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"render strategy=cell-fallback cell=%@ host=%@ reason=no-bubble-container labelFrame=%@ layoutRefreshed=YES",
                               NSStringFromClass(message.cell.class),NSStringFromClass(host.class),NSStringFromCGRect(label.frame)]];
}

+(BOOL)cellIsCurrentForMessage:(TPExtractedMessage*)message allowUnbound:(BOOL)allowUnbound{
    NSString *current=objc_getAssociatedObject(message.cell,TPMessageKey);
    if(!current.length)return allowUnbound;
    return [current isEqualToString:message.messageId];
}

+(void)setState:(TPBubbleState)state message:(TPExtractedMessage*)message text:(NSString*)translation{
    if(!message.cell)return;
    if(state!=TPBubbleStateTranslating&&(!message.cell.window||![self cellIsCurrentForMessage:message allowUnbound:YES])){
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"render skipped stale cell=%@ key=%@ state=%ld",message.cell?NSStringFromClass(message.cell.class):@"nil",message.messageId?:@"nil",(long)state]];
        return;
    }
    NSString *existingKey=objc_getAssociatedObject(message.cell,TPMessageKey);
    NSString *existingText=objc_getAssociatedObject(message.cell,TPTranslationTextKey);
    TPBubbleState existingState=[self stateForCell:message.cell];
    if(existingKey.length&&[existingKey isEqualToString:message.messageId]&&existingState==state&&((!translation.length&&!existingText.length)||[existingText isEqualToString:translation])){
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"render skipped duplicate key=%@ state=%ld",message.messageId?:@"nil",(long)state]];
        return;
    }
    if(existingKey.length&&![existingKey isEqualToString:message.messageId]){
        [self resetCell:message.cell];
    }
    objc_setAssociatedObject(message.cell,TPStateKey,@(state),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(message.cell,TPMessageKey,message.messageId,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(message.cell,TPTranslationTextKey,translation?:@"",OBJC_ASSOCIATION_COPY_NONATOMIC);
    if(state==TPBubbleStateTranslating){
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"render state=translating key=%@ cell=%@ uiMutation=NO",message.messageId?:@"nil",NSStringFromClass(message.cell.class)]];
        return;
    }
    [self removeFallbackFromCell:message.cell];
    BOOL failed=state==TPBubbleStateFailed;
    NSString *line=[self displayText:translation state:state];
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"render begin key=%@ cell=%@ source=%@ prop=%@ translationPreview=%@",
                               message.messageId?:@"nil",NSStringFromClass(message.cell.class),message.sourceClass?:@"unknown",message.sourceProperty?:@"unknown",[self preview:line]]];
    if([self tryInlineForMessage:message line:line failed:failed])return;
    if([self renderBubbleFallbackForMessage:message line:line failed:failed strategyName:@"bubble-fallback"])return;
    [self renderCellFallbackForMessage:message line:line failed:failed];
}

+(BOOL)maintainTranslationForMessage:(TPExtractedMessage*)message{
    if(!message.cell||[self stateForCell:message.cell]!=TPBubbleStateTranslated)return NO;
    NSString *translation=objc_getAssociatedObject(message.cell,TPTranslationTextKey);
    if(!translation.length)return NO;
    UILabel *fallback=objc_getAssociatedObject(message.cell,TPFallbackLabelKey);
    UIView *currentContainer=[self bubbleContainerForMessage:message];
    UITableView *table=[self tableForCell:message.cell];
    BOOL overlayFallback=(fallback&&table&&fallback.superview==table);
    BOOL staleContainer=(fallback&&currentContainer&&fallback.superview&&fallback.superview!=currentContainer&&!overlayFallback);
    BOOL missingFallback=(!fallback||!fallback.superview||fallback.hidden||fallback.alpha<0.05||!fallback.text.length||(message.cell.window&&fallback.window!=message.cell.window)||staleContainer);
    if(missingFallback){
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"render repair key=%@ reason=fallback-missing cell=%@ label=%@ superview=%@ currentContainer=%@ staleContainer=%@",
                                   message.messageId?:@"nil",NSStringFromClass(message.cell.class),fallback?@"YES":@"NO",fallback.superview?NSStringFromClass(fallback.superview.class):@"none",currentContainer?NSStringFromClass(currentContainer.class):@"none",staleContainer?@"YES":@"NO"]];
        [self removeFallbackFromCell:message.cell];
        objc_setAssociatedObject(message.cell,TPStateKey,@(TPBubbleStateUnprocessed),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(message.cell,TPTranslationTextKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
        [self setTranslation:translation forMessage:message];
        return YES;
    }
    [fallback.superview bringSubviewToFront:fallback];
    if(overlayFallback)[self positionOverlayLabel:fallback forCell:message.cell];
    [self updateReservedHeightForMessage:message label:fallback];
    [self refreshVisibleSpacingNearCell:message.cell];
    if(overlayFallback)[self positionOverlayLabel:fallback forCell:message.cell];
    return NO;
}

+(void)setTranslatingForMessage:(TPExtractedMessage*)message{
    [self setState:TPBubbleStateTranslating message:message text:@""];
}

+(void)setTranslation:(NSString*)translation forMessage:(TPExtractedMessage*)message{
    [self setState:TPBubbleStateTranslated message:message text:translation?:@""];
}

+(void)setFailure:(NSError*)error forMessage:(TPExtractedMessage*)message retry:(dispatch_block_t)retry{
    if(!TPSettings.shared.showRetryOnFailure){
        [self resetCell:message.cell];
        return;
    }
    [self setState:TPBubbleStateFailed message:message text:@""];
    UIView *source=objc_getAssociatedObject(message.cell,TPSourceViewKey);
    if([source isKindOfClass:UILabel.class])[TPRetryController attachRetry:retry toLabel:(UILabel*)source cell:message.cell];
    UILabel *fallback=objc_getAssociatedObject(message.cell,TPFallbackLabelKey);
    if(fallback)[TPRetryController attachRetry:retry toLabel:fallback cell:message.cell];
}

+(void)resetCell:(UIView*)cell{
    if(!cell)return;
    [self removeFallbackFromCell:cell];
    UIView *source=objc_getAssociatedObject(cell,TPSourceViewKey);
    [self restoreSource:source];
    objc_setAssociatedObject(cell,TPSourceViewKey,nil,OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(cell,TPStateKey,@(TPBubbleStateUnprocessed),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell,TPMessageKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(cell,TPTranslationTextKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(cell,TPReservedHeightKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGFloat oldShift=[objc_getAssociatedObject(cell,TPAppliedShiftKey) doubleValue];
    if(fabs(oldShift)>0.5){
        CGRect f=cell.frame;
        f.origin.y-=oldShift;
        cell.frame=f;
    }
    cell.transform=CGAffineTransformIdentity;
    NSValue *base=objc_getAssociatedObject(cell,TPBaseTransformKey);
    if(base)cell.transform=[base CGAffineTransformValue];
    objc_setAssociatedObject(cell,TPBaseTransformKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell,TPAppliedShiftKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell,TPAppliedFrameKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self refreshLayoutAroundCell:cell];
    [self refreshVisibleSpacingNearCell:cell];
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"render reset cell=%@ restoredSource=%@",NSStringFromClass(cell.class),source?NSStringFromClass(source.class):@"none"]];
}

@end
