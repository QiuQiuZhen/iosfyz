#import "TPTranslationRenderer.h"
#import "TPSettings.h"
#import "TPRetryController.h"
#import <objc/runtime.h>

static const void *TPStateKey=&TPStateKey,*TPMessageKey=&TPMessageKey,*TPOriginalTextKey=&TPOriginalTextKey,*TPOriginalAttributedTextKey=&TPOriginalAttributedTextKey,*TPSourceViewKey=&TPSourceViewKey,*TPOriginalLinesKey=&TPOriginalLinesKey,*TPOriginalEditableKey=&TPOriginalEditableKey,*TPOriginalSelectableKey=&TPOriginalSelectableKey;

@implementation TPTranslationRenderer

+ (TPBubbleState)stateForCell:(UIView *)cell { return [objc_getAssociatedObject(cell,TPStateKey) integerValue]; }
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
+ (UIFont *)translationFontFrom:(UIFont *)font failed:(BOOL)failed {
  CGFloat size=MAX(11,MIN((font?:[UIFont systemFontOfSize:16]).pointSize-2,14));
  return failed?[UIFont systemFontOfSize:size weight:UIFontWeightSemibold]:[UIFont systemFontOfSize:size weight:UIFontWeightRegular];
}
+ (NSMutableAttributedString *)baseAttributedTextForLabel:(UILabel *)label {
  NSAttributedString *stored=objc_getAssociatedObject(label,TPOriginalAttributedTextKey);
  if(stored.length)return [stored mutableCopy];
  NSString *text=objc_getAssociatedObject(label,TPOriginalTextKey)?:label.text?:@"";
  return [[NSMutableAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:label.font?:[UIFont systemFontOfSize:16],NSForegroundColorAttributeName:label.textColor?:UIColor.blackColor}];
}
+ (NSMutableAttributedString *)baseAttributedTextForTextView:(UITextView *)view {
  NSAttributedString *stored=objc_getAssociatedObject(view,TPOriginalAttributedTextKey);
  if(stored.length)return [stored mutableCopy];
  NSString *text=objc_getAssociatedObject(view,TPOriginalTextKey)?:view.text?:@"";
  return [[NSMutableAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:view.font?:[UIFont systemFontOfSize:16],NSForegroundColorAttributeName:view.textColor?:UIColor.blackColor}];
}
+ (void)rememberOriginalForMessage:(TPExtractedMessage *)message {
  UIView *source=message.sourceView;
  if(!source||objc_getAssociatedObject(source,TPOriginalTextKey))return;
  objc_setAssociatedObject(message.cell,TPSourceViewKey,source,OBJC_ASSOCIATION_ASSIGN);
  if([source isKindOfClass:UILabel.class]){
    UILabel *label=(UILabel*)source;
    objc_setAssociatedObject(source,TPOriginalTextKey,label.text?:@"",OBJC_ASSOCIATION_COPY_NONATOMIC);
    if(label.attributedText.length)objc_setAssociatedObject(source,TPOriginalAttributedTextKey,label.attributedText,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(source,TPOriginalLinesKey,@(label.numberOfLines),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }else if([source isKindOfClass:UITextView.class]){
    UITextView *view=(UITextView*)source;
    objc_setAssociatedObject(source,TPOriginalTextKey,view.text?:@"",OBJC_ASSOCIATION_COPY_NONATOMIC);
    if(view.attributedText.length)objc_setAssociatedObject(source,TPOriginalAttributedTextKey,view.attributedText,OBJC_ASSOCIATION_COPY_NONATOMIC);
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
+ (void)setState:(TPBubbleState)state message:(TPExtractedMessage *)message text:(NSString *)text {
  UIView *source=message.sourceView;
  if(!source||(![source isKindOfClass:UILabel.class]&&![source isKindOfClass:UITextView.class]))return;
  [self rememberOriginalForMessage:message];
  objc_setAssociatedObject(message.cell,TPStateKey,@(state),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(message.cell,TPMessageKey,message.messageId,OBJC_ASSOCIATION_COPY_NONATOMIC);
  objc_setAssociatedObject(message.cell,TPSourceViewKey,source,OBJC_ASSOCIATION_ASSIGN);
  NSString *line=[self displayText:text state:state];
  BOOL failed=state==TPBubbleStateFailed;
  UIColor *color=[self translationColorFailed:failed];
  if([source isKindOfClass:UILabel.class]){
    UILabel *label=(UILabel*)source;
    NSMutableAttributedString *styled=[self baseAttributedTextForLabel:label];
    [styled appendAttributedString:[[NSAttributedString alloc]initWithString:[@"\n" stringByAppendingString:line] attributes:@{NSFontAttributeName:[self translationFontFrom:label.font failed:failed],NSForegroundColorAttributeName:color}]];
    label.numberOfLines=0;
    label.attributedText=styled;
    label.userInteractionEnabled=failed;
    if(failed)[TPRetryController attachRetry:nil toLabel:label cell:message.cell];
  }else if([source isKindOfClass:UITextView.class]){
    UITextView *view=(UITextView*)source;
    NSMutableAttributedString *styled=[self baseAttributedTextForTextView:view];
    [styled appendAttributedString:[[NSAttributedString alloc]initWithString:[@"\n" stringByAppendingString:line] attributes:@{NSFontAttributeName:[self translationFontFrom:view.font failed:failed],NSForegroundColorAttributeName:color}]];
    view.editable=NO; view.selectable=failed; view.attributedText=styled;
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
}

+ (void)resetCell:(UIView *)cell {
  UIView *source=objc_getAssociatedObject(cell,TPSourceViewKey);
  if([source isKindOfClass:UILabel.class]){
    UILabel *label=(UILabel*)source;
    NSAttributedString *attr=objc_getAssociatedObject(source,TPOriginalAttributedTextKey);
    NSString *text=objc_getAssociatedObject(source,TPOriginalTextKey);
    NSNumber *lines=objc_getAssociatedObject(source,TPOriginalLinesKey);
    if(attr.length)label.attributedText=attr;else if(text)label.text=text;
    if(lines)label.numberOfLines=lines.integerValue;
    label.userInteractionEnabled=NO;
  }else if([source isKindOfClass:UITextView.class]){
    UITextView *view=(UITextView*)source;
    NSAttributedString *attr=objc_getAssociatedObject(source,TPOriginalAttributedTextKey);
    NSString *text=objc_getAssociatedObject(source,TPOriginalTextKey);
    NSNumber *editable=objc_getAssociatedObject(source,TPOriginalEditableKey),*selectable=objc_getAssociatedObject(source,TPOriginalSelectableKey);
    if(attr.length)view.attributedText=attr;else if(text)view.text=text;
    if(editable)view.editable=editable.boolValue;
    if(selectable)view.selectable=selectable.boolValue;
  }
  if(source){
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
