#import "TPTranslationRenderer.h"
#import "TPSettings.h"
#import "TPRetryController.h"
#import "TPDebugLogger.h"
#import <objc/runtime.h>

static const void *TPStateKey=&TPStateKey,*TPMessageKey=&TPMessageKey,*TPSourceViewKey=&TPSourceViewKey,*TPFallbackLabelKey=&TPFallbackLabelKey,*TPOriginalTextKey=&TPOriginalTextKey,*TPOriginalAttributedTextKey=&TPOriginalAttributedTextKey,*TPOriginalLinesKey=&TPOriginalLinesKey,*TPOriginalEditableKey=&TPOriginalEditableKey,*TPOriginalSelectableKey=&TPOriginalSelectableKey;

@implementation TPTranslationRenderer

+ (TPBubbleState)stateForCell:(UIView *)cell { return [objc_getAssociatedObject(cell,TPStateKey) integerValue]; }
+ (id)safeValue:(id)object key:(NSString *)key { if(!object)return nil; @try { return [object valueForKey:key]; } @catch(NSException *e) { return nil; } }
+ (BOOL)safeSet:(id)value object:(id)object key:(NSString *)key { @try { [object setValue:value forKey:key]; return YES; } @catch(NSException *e) { return NO; } }
+ (NSArray *)plainTextKeys { return @[@"text",@"messageText",@"displayText",@"plainText",@"string",@"contentText",@"bodyText",@"title"]; }
+ (NSArray *)richTextKeys { return @[@"attributedText",@"attributedString",@"messageAttributedText",@"displayAttributedText",@"attributedTitle"]; }

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
  for(NSString *key in self.plainTextKeys){ id v=[self safeValue:source key:key]; if([v isKindOfClass:NSString.class]&&[(NSString*)v length])return v; }
  return @"";
}
+ (NSAttributedString *)attributedTextFromSource:(UIView *)source {
  if([source isKindOfClass:UILabel.class])return ((UILabel*)source).attributedText;
  if([source isKindOfClass:UITextView.class])return ((UITextView*)source).attributedText;
  for(NSString *key in self.richTextKeys){ id v=[self safeValue:source key:key]; if([v isKindOfClass:NSAttributedString.class]&&[(NSAttributedString*)v length])return v; }
  return nil;
}
+ (BOOL)string:(NSString *)haystack containsMessage:(NSString *)message {
  NSString *h=[haystack stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSString *m=[message stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  return m.length&&h.length&&([h containsString:m]||[m containsString:h]);
}
+ (BOOL)viewLooksLikeMessageHost:(UIView *)view message:(TPExtractedMessage *)message {
  if(!view||view.hidden||view.alpha<.05)return NO;
  if([view isKindOfClass:UITableViewCell.class]||[view isKindOfClass:UICollectionViewCell.class])return NO;
  if(view==message.sourceView)return YES;
  NSString *text=[self textFromSource:view];
  if([self string:text containsMessage:message.text])return YES;
  if([self string:view.accessibilityLabel containsMessage:message.text])return YES;
  if([self string:view.accessibilityValue containsMessage:message.text])return YES;
  NSString *name=NSStringFromClass(view.class).lowercaseString;
  return ([name containsString:@"message"]||[name containsString:@"text"]||[name containsString:@"bubble"])&&[self string:(text?:view.accessibilityLabel) containsMessage:message.text];
}
+ (void)collectViews:(UIView *)view into:(NSMutableArray *)items {
  if(!view)return;
  [items addObject:view];
  for(UIView *sub in view.subviews)[self collectViews:sub into:items];
}
+ (NSArray *)candidateTextHostsForMessage:(TPExtractedMessage *)message {
  NSMutableArray *raw=[NSMutableArray array];
  NSMutableSet *seen=[NSMutableSet set];
  void (^add)(UIView*)=^(UIView *v){ if(!v)return; NSValue *key=[NSValue valueWithNonretainedObject:v]; if([seen containsObject:key])return; [seen addObject:key]; [raw addObject:v]; };
  NSMutableArray *desc=[NSMutableArray array]; [self collectViews:message.cell into:desc];
  for(UIView *v in desc)if([self viewLooksLikeMessageHost:v message:message])add(v);
  if(message.sourceView&&![message.sourceView isKindOfClass:UITableViewCell.class]&&![message.sourceView isKindOfClass:UICollectionViewCell.class])add(message.sourceView);
  for(UIView *v=message.sourceView.superview;v;v=v.superview){ if(v==message.cell)break; if([self viewLooksLikeMessageHost:v message:message])add(v); }
  return raw;
}
+ (NSString *)debugViewSummaryForCell:(UIView *)cell message:(NSString *)message {
  NSMutableArray *views=[NSMutableArray array]; [self collectViews:cell into:views];
  NSMutableArray *parts=[NSMutableArray array];
  for(UIView *v in views){
    NSString *name=NSStringFromClass(v.class);
    NSString *lower=name.lowercaseString;
    NSString *text=[self textFromSource:v];
    BOOL interesting=[lower containsString:@"message"]||[lower containsString:@"text"]||[lower containsString:@"bubble"]||[self string:text containsMessage:message]||[self string:v.accessibilityLabel containsMessage:message];
    if(!interesting)continue;
    CGRect r=[v convertRect:v.bounds toView:cell];
    [parts addObject:[NSString stringWithFormat:@"%@ frame=(%.0f,%.0f,%.0f,%.0f) text=%@ acc=%@",name,CGRectGetMinX(r),CGRectGetMinY(r),CGRectGetWidth(r),CGRectGetHeight(r),text.length?@"YES":@"NO",v.accessibilityLabel.length?@"YES":@"NO"]];
    if(parts.count>=20)break;
  }
  return [parts componentsJoinedByString:@" | "];
}
+ (NSMutableAttributedString *)baseAttributedTextForSource:(UIView *)source {
  NSAttributedString *stored=objc_getAssociatedObject(source,TPOriginalAttributedTextKey);
  if(stored.length)return [stored mutableCopy];
  NSString *text=objc_getAssociatedObject(source,TPOriginalTextKey)?:[self textFromSource:source]?:@"";
  return [[NSMutableAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[self fontFromSource:source failed:NO],NSForegroundColorAttributeName:[self textColorFromSource:source]}];
}
+ (void)rememberOriginalSource:(UIView *)source cell:(UIView *)cell {
  if(!source||objc_getAssociatedObject(source,TPOriginalTextKey))return;
  objc_setAssociatedObject(cell,TPSourceViewKey,source,OBJC_ASSOCIATION_ASSIGN);
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
  for(UIView *v=cell;v;v=v.superview){[v setNeedsDisplay];[v setNeedsLayout];}
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
+ (BOOL)setStyledText:(NSAttributedString *)styled plain:(NSString *)plain source:(UIView *)source failed:(BOOL)failed usedKey:(NSString **)usedKey {
  if([source isKindOfClass:UITableViewCell.class]||[source isKindOfClass:UICollectionViewCell.class])return NO;
  if([source isKindOfClass:UILabel.class]){
    UILabel *label=(UILabel*)source; label.numberOfLines=0; label.attributedText=styled; label.userInteractionEnabled=failed; if(usedKey)*usedKey=@"UILabel.attributedText"; return YES;
  }
  if([source isKindOfClass:UITextView.class]){
    UITextView *view=(UITextView*)source; view.editable=NO; view.selectable=failed; view.attributedText=styled; if(usedKey)*usedKey=@"UITextView.attributedText"; return YES;
  }
  [self safeSet:@0 object:source key:@"numberOfLines"];
  for(NSString *key in self.richTextKeys)if([self safeSet:styled object:source key:key]){ if(usedKey)*usedKey=key; return YES; }
  for(NSString *key in self.plainTextKeys)if([self safeSet:plain object:source key:key]){ if(usedKey)*usedKey=key; return YES; }
  return NO;
}
+ (BOOL)renderInlineLine:(NSString *)line source:(UIView *)source failed:(BOOL)failed usedKey:(NSString **)usedKey {
  NSMutableAttributedString *styled=[self baseAttributedTextForSource:source];
  [styled appendAttributedString:[[NSAttributedString alloc]initWithString:[@"\n" stringByAppendingString:line] attributes:@{NSFontAttributeName:[self fontFromSource:source failed:failed],NSForegroundColorAttributeName:[self translationColorFailed:failed]}]];
  NSString *plain=[NSString stringWithFormat:@"%@\n%@",objc_getAssociatedObject(source,TPOriginalTextKey)?:[self textFromSource:source]?:@"",line];
  return [self setStyledText:styled plain:plain source:source failed:failed usedKey:usedKey];
}
+ (UILabel *)fallbackLabelForMessage:(TPExtractedMessage *)message failed:(BOOL)failed {
  UILabel *label=objc_getAssociatedObject(message.cell,TPFallbackLabelKey);
  UIView *source=message.sourceView?:message.cell;
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
+ (void)setState:(TPBubbleState)state message:(TPExtractedMessage *)message text:(NSString *)text {
  if(!message.cell)return;
  objc_setAssociatedObject(message.cell,TPStateKey,@(state),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(message.cell,TPMessageKey,message.messageId,OBJC_ASSOCIATION_COPY_NONATOMIC);
  BOOL failed=state==TPBubbleStateFailed;
  NSString *line=[self displayText:text state:state];
  UILabel *old=objc_getAssociatedObject(message.cell,TPFallbackLabelKey);
  [old removeFromSuperview]; objc_setAssociatedObject(message.cell,TPFallbackLabelKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  for(UIView *host in [self candidateTextHostsForMessage:message]){
    [self rememberOriginalSource:host cell:message.cell];
    NSString *used=nil;
    if([self renderInlineLine:line source:host failed:failed usedKey:&used]){
      NSString *summary=[NSString stringWithFormat:@"inline=%@ key=%@",NSStringFromClass(host.class),used?:@"unknown"];
      TPDebugLogger.shared.scanSummary=summary;
      [TPDebugLogger.shared log:[@"render " stringByAppendingString:summary]];
      [self refreshLayoutAroundCell:message.cell];
      return;
    }
  }
  TPDebugLogger.shared.lastError=[NSString stringWithFormat:@"未找到可写消息文本宿主: %@",NSStringFromClass(message.sourceView.class)];
  [TPDebugLogger.shared log:[@"host candidates " stringByAppendingString:[self debugViewSummaryForCell:message.cell message:message.text]?:@"none"]];
  UILabel *label=[self fallbackLabelForMessage:message failed:failed];
  label.text=line;
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
      BOOL restored=NO;
      if(attr.length)for(NSString *key in self.richTextKeys)if([self safeSet:attr object:source key:key]){restored=YES;break;}
      if(!restored&&text)for(NSString *key in self.plainTextKeys)if([self safeSet:text object:source key:key])break;
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
