#import "TPTranslationRenderer.h"
#import "TPSettings.h"
#import "TPRetryController.h"
#import <objc/runtime.h>

static const void *TPStateKey=&TPStateKey,*TPMessageKey=&TPMessageKey,*TPSourceViewKey=&TPSourceViewKey,*TPFallbackLabelKey=&TPFallbackLabelKey,*TPOriginalTextKey=&TPOriginalTextKey,*TPOriginalAttributedTextKey=&TPOriginalAttributedTextKey,*TPOriginalLinesKey=&TPOriginalLinesKey,*TPOriginalEditableKey=&TPOriginalEditableKey,*TPOriginalSelectableKey=&TPOriginalSelectableKey;

@implementation TPTranslationRenderer

+ (TPBubbleState)stateForCell:(UIView *)cell { return [objc_getAssociatedObject(cell,TPStateKey) integerValue]; }
+ (id)safeValue:(id)object key:(NSString *)key { @try { return [object valueForKey:key]; } @catch(NSException *e) { return nil; } }
+ (BOOL)safeSet:(id)value object:(id)object key:(NSString *)key { @try { [object setValue:value forKey:key]; return YES; } @catch(NSException *e) { return NO; } }
+ (NSString *)displayText:(NSString *)text state:(TPBubbleState)state {
  if(state==TPBubbleStateTranslating)return @"翻译中…";
  if(state==TPBubbleStateFailed)return @"翻译失败 · 点按重试";
  NSString *prefix=TPSettings.shared.showTranslationPrefix?(TPSettings.shared.translationPrefix?:@"译文："):@"";
  return [prefix stringByAppendingString:text?:@""];
}
+ (UIColor *)translationColorFailed:(BOOL)failed {
  if(@available(iOS 13,*))return failed?UIColor.systemRedColor:UIColor.secondaryLabelColor;
  return failed?UIColor.redColor:UIColor.darkGrayColor;
}
+ (UIFont *)fontFromSource:(UIView *)source failed:(BOOL)failed {
  UIFont *font=nil;
  if([source isKindOfClass:UILabel.class])font=((UILabel*)source).font;
  else if([source isKindOfClass:UITextView.class])font=((UITextView*)source).font;
  else { id v=[self safeValue:source key:@"font"]; if([v isKindOfClass:UIFont.class])font=v; }
  CGFloat size=MAX(11,MIN((font?:[UIFont systemFontOfSize:16]).pointSize-2,14));
  return failed?[UIFont systemFontOfSize:size weight:UIFontWeightSemibold]:[UIFont systemFontOfSize:size weight:UIFontWeightRegular];
}
+ (UIColor *)textColorFromSource:(UIView *)source {
  if([source isKindOfClass:UILabel.class])return ((UILabel*)source).textColor?:UIColor.blackColor;
  if([source isKindOfClass:UITextView.class])return ((UITextView*)source).textColor?:UIColor.blackColor;
  id v=[self safeValue:source key:@"textColor"];
  return [v isKindOfClass:UIColor.class]?v:UIColor.blackColor;
}
+ (NSString *)textFromSource:(UIView *)source {
  if([source isKindOfClass:UILabel.class])return ((UILabel*)source).text?:@"";
  if([source isKindOfClass:UITextView.class])return ((UITextView*)source).text?:@"";
  id v=[self safeValue:source key:@"text"];
  return [v isKindOfClass:NSString.class]?v:@"";
}
+ (NSAttributedString *)attributedTextFromSource:(UIView *)source {
  if([source isKindOfClass:UILabel.class])return ((UILabel*)source).attributedText;
  if([source isKindOfClass:UITextView.class])return ((UITextView*)source).attributedText;
  id v=[self safeValue:source key:@"attributedText"];
  return [v isKindOfClass:NSAttributedString.class]?v:nil;
}
+ (NSMutableAttributedString *)baseAttributedTextForSource:(UIView *)source {
  NSAttributedString *stored=objc_getAssociatedObject(source,TPOriginalAttributedTextKey);
  if(stored.length)return [stored mutableCopy];
  NSString *text=objc_getAssociatedObject(source,TPOriginalTextKey)?:[self textFromSource:source]?:@"";
  return [[NSMutableAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[self fontFromSource:source failed:NO],NSForegroundColorAttributeName:[self textColorFromSource:source]}];
}
+ (void)rememberOriginalForMessage:(TPExtractedMessage *)message {
  UIView *source=message.sourceView;
  if(!source||objc_getAssociatedObject(source,TPOriginalTextKey))return;
  objc_setAssociatedObject(message.cell,TPSourceViewKey,source,OBJC_ASSOCIATION_ASSIGN);
  objc_setAssociatedObject(source,TPOriginalTextKey,[self textFromSource:source]?:@"",OBJC_ASSOCIATION_COPY_NONATOMIC);
  NSAttributedString *attr=[self attributedTextFromSource:source];
  if(attr.length)objc_setAssociatedObject(source,TPOriginalAttributedTextKey,attr,OBJC_ASSOCIATION_COPY_NONATOMIC);
  if([source isKindOfClass:UILabel.class])objc_setAssociatedObject(source,TPOriginalLinesKey,@(((UILabel*)source).numberOfLines),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  else { id lines=[self safeValue:source key:@"numberOfLines"]; if(lines)objc_setAssociatedObject(source,TPOriginalLinesKey,lines,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
  if([source isKindOfClass:UITextView.class]){
    UITextView *view=(UITextView*)source;
    objc_setAssociatedObject(source,TPOriginalEditableKey,@(view.editable),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalSelectableKey,@(view.selectable),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
}
+ (void)refreshLayoutAroundCell:(UIView *)cell {
  for(UIView *v=cell;v;v=v.superview)[v setNeedsLayout];
  [cell setNeedsLayout];
  [cell layoutIfNeeded];
  UIView *p=cell.superview;
  while(p&&![p isKindOfClass:UITableView.class]&&![p isKindOfClass:UICollectionView.class])p=p.superview;
  if([p isKindOfClass:UITableView.class]){
    UITableView *table=(UITableView*)p;
    [UIView performWithoutAnimation:^{[table beginUpdates];[table endUpdates];}];
  }else if([p isKindOfClass:UICollectionView.class]){
    UICollectionView *collection=(UICollectionView*)p;
    [UIView performWithoutAnimation:^{[collection.collectionViewLayout invalidateLayout];[collection layoutIfNeeded];}];
  }
}
+ (UILabel *)fallbackLabelForMessage:(TPExtractedMessage *)message failed:(BOOL)failed {
  UILabel *label=objc_getAssociatedObject(message.cell,TPFallbackLabelKey);
  UIView *source=message.sourceView;
  UIView *container=source.superview?:message.cell;
  if(!label){
    label=[UILabel new];
    label.accessibilityIdentifier=@"tp.translation";
    label.numberOfLines=0;
    label.backgroundColor=UIColor.clearColor;
    [container addSubview:label];
    objc_setAssociatedObject(message.cell,TPFallbackLabelKey,label,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  label.textColor=[self translationColorFailed:failed];
  label.font=[self fontFromSource:source failed:failed];
  label.userInteractionEnabled=failed;
  CGRect r=[source convertRect:source.bounds toView:container];
  CGFloat width=MAX(80,MIN(CGRectGetWidth(r),CGRectGetWidth(container.bounds)-CGRectGetMinX(r)-8));
  CGSize fit=[label sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)];
  label.frame=CGRectIntegral(CGRectMake(CGRectGetMinX(r),CGRectGetMaxY(r)+2,width,MIN(42,MAX(18,fit.height))));
  [container bringSubviewToFront:label];
  return label;
}
+ (BOOL)renderInlineLine:(NSString *)line source:(UIView *)source failed:(BOOL)failed {
  NSMutableAttributedString *styled=[self baseAttributedTextForSource:source];
  [styled appendAttributedString:[[NSAttributedString alloc]initWithString:[@"\n" stringByAppendingString:line] attributes:@{NSFontAttributeName:[self fontFromSource:source failed:failed],NSForegroundColorAttributeName:[self translationColorFailed:failed]}]];
  if([source isKindOfClass:UILabel.class]){
    UILabel *label=(UILabel*)source;
    label.numberOfLines=0;
    label.attributedText=styled;
    label.userInteractionEnabled=failed;
    return YES;
  }
  if([source isKindOfClass:UITextView.class]){
    UITextView *view=(UITextView*)source;
    view.editable=NO; view.selectable=failed; view.attributedText=styled;
    return YES;
  }
  [self safeSet:@0 object:source key:@"numberOfLines"];
  if([self safeSet:styled object:source key:@"attributedText"])return YES;
  NSString *plain=[NSString stringWithFormat:@"%@\n%@",objc_getAssociatedObject(source,TPOriginalTextKey)?:[self textFromSource:source]?:@"",line];
  return [self safeSet:plain object:source key:@"text"];
}
+ (void)setState:(TPBubbleState)state message:(TPExtractedMessage *)message text:(NSString *)text {
  UIView *source=message.sourceView?:message.cell;
  if(!source)return;
  [self rememberOriginalForMessage:message];
  objc_setAssociatedObject(message.cell,TPStateKey,@(state),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(message.cell,TPMessageKey,message.messageId,OBJC_ASSOCIATION_COPY_NONATOMIC);
  objc_setAssociatedObject(message.cell,TPSourceViewKey,source,OBJC_ASSOCIATION_ASSIGN);
  BOOL failed=state==TPBubbleStateFailed;
  NSString *line=[self displayText:text state:state];
  UILabel *old=objc_getAssociatedObject(message.cell,TPFallbackLabelKey);
  [old removeFromSuperview]; objc_setAssociatedObject(message.cell,TPFallbackLabelKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if(![self renderInlineLine:line source:source failed:failed]){
    UILabel *label=[self fallbackLabelForMessage:message failed:failed];
    label.text=line;
  }
  [self refreshLayoutAroundCell:message.cell];
}

+ (void)setTranslatingForMessage:(TPExtractedMessage *)message { [self setState:TPBubbleStateTranslating message:message text:@""]; }
+ (void)setTranslation:(NSString *)translation forMessage:(TPExtractedMessage *)message { [self setState:TPBubbleStateTranslated message:message text:translation]; }
+ (void)setFailure:(NSError *)error forMessage:(TPExtractedMessage *)message retry:(dispatch_block_t)retry {
  if(!TPSettings.shared.showRetryOnFailure){[self resetCell:message.cell];return;}
  [self setState:TPBubbleStateFailed message:message text:@""];
  UIView *source=objc_getAssociatedObject(message.cell,TPSourceViewKey);
  if([source isKindOfClass:UILabel.class])[TPRetryController attachRetry:retry toLabel:(UILabel*)source cell:message.cell];
  UILabel *fallback=objc_getAssociatedObject(message.cell,TPFallbackLabelKey);
  if(fallback)[TPRetryController attachRetry:retry toLabel:fallback cell:message.cell];
}
+ (void)resetCell:(UIView *)cell {
  UIView *source=objc_getAssociatedObject(cell,TPSourceViewKey);
  UILabel *fallback=objc_getAssociatedObject(cell,TPFallbackLabelKey);
  [fallback removeFromSuperview];
  objc_setAssociatedObject(cell,TPFallbackLabelKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if(source){
    NSAttributedString *attr=objc_getAssociatedObject(source,TPOriginalAttributedTextKey);
    NSString *text=objc_getAssociatedObject(source,TPOriginalTextKey);
    NSNumber *lines=objc_getAssociatedObject(source,TPOriginalLinesKey);
    if([source isKindOfClass:UILabel.class]){
      UILabel *label=(UILabel*)source;
      if(attr.length)label.attributedText=attr;else if(text)label.text=text;
      if(lines)label.numberOfLines=lines.integerValue;
      label.userInteractionEnabled=NO;
    }else if([source isKindOfClass:UITextView.class]){
      UITextView *view=(UITextView*)source;
      NSNumber *editable=objc_getAssociatedObject(source,TPOriginalEditableKey),*selectable=objc_getAssociatedObject(source,TPOriginalSelectableKey);
      if(attr.length)view.attributedText=attr;else if(text)view.text=text;
      if(editable)view.editable=editable.boolValue;
      if(selectable)view.selectable=selectable.boolValue;
    }else{
      if(attr.length)[self safeSet:attr object:source key:@"attributedText"];
      else if(text)[self safeSet:text object:source key:@"text"];
      if(lines)[self safeSet:lines object:source key:@"numberOfLines"];
    }
    objc_setAssociatedObject(source,TPOriginalTextKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalAttributedTextKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalLinesKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalEditableKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalSelectableKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  objc_setAssociatedObject(cell,TPSourceViewKey,nil,OBJC_ASSOCIATION_ASSIGN);
  objc_setAssociatedObject(cell,TPStateKey,@(TPBubbleStateUnprocessed),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(cell,TPMessageKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC);
  [self refreshLayoutAroundCell:cell];
}

@end
