#import "TPTranslationRenderer.h"
#import "TPSettings.h"
#import "TPRetryController.h"
#import <objc/runtime.h>

static const void *TPStateKey=&TPStateKey,*TPLabelKey=&TPLabelKey,*TPMessageKey=&TPMessageKey;

@implementation TPTranslationRenderer

+ (TPBubbleState)stateForCell:(UIView *)cell { return [objc_getAssociatedObject(cell,TPStateKey) integerValue]; }
+ (UIView *)container:(UIView *)cell { if([cell isKindOfClass:UITableViewCell.class])return ((UITableViewCell*)cell).contentView; if([cell isKindOfClass:UICollectionViewCell.class])return ((UICollectionViewCell*)cell).contentView; return cell; }

+ (void)applyTheme:(UILabel *)label outgoing:(BOOL)outgoing failed:(BOOL)failed {
  label.layer.cornerRadius=9; label.layer.borderWidth=.5; label.clipsToBounds=YES;
  if(@available(iOS 13,*)){
    label.textColor=failed?UIColor.systemRedColor:UIColor.secondaryLabelColor;
    label.backgroundColor=failed?[UIColor.systemRedColor colorWithAlphaComponent:.08]:(outgoing?[UIColor.systemGreenColor colorWithAlphaComponent:.10]:UIColor.secondarySystemBackgroundColor);
    label.layer.borderColor=(failed?UIColor.systemRedColor:[UIColor.separatorColor colorWithAlphaComponent:.35]).CGColor;
  }else{
    label.textColor=failed?UIColor.redColor:UIColor.darkGrayColor;
    label.backgroundColor=outgoing?[UIColor colorWithRed:.88 green:.97 blue:.88 alpha:.96]:[UIColor colorWithWhite:.94 alpha:.96];
    label.layer.borderColor=[UIColor colorWithWhite:.7 alpha:.35].CGColor;
  }
}

+ (UILabel *)labelForMessage:(TPExtractedMessage *)message {
  UILabel *label=objc_getAssociatedObject(message.cell,TPLabelKey);
  UIView *container=[self container:message.cell];
  if(!label){ label=[UILabel new]; label.accessibilityIdentifier=@"tp.translation"; label.numberOfLines=2; label.font=[UIFont systemFontOfSize:11.5 weight:UIFontWeightRegular]; label.userInteractionEnabled=NO; label.textAlignment=NSTextAlignmentNatural; [container addSubview:label]; objc_setAssociatedObject(message.cell,TPLabelKey,label,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
  [self applyTheme:label outgoing:message.outgoing failed:[self stateForCell:message.cell]==TPBubbleStateFailed];
  CGRect source=[message.sourceView convertRect:message.sourceView.bounds toView:container];
  CGFloat limit=MIN(300,MAX(120,CGRectGetWidth(container.bounds)-24));
  CGSize fit=[label sizeThatFits:CGSizeMake(limit-14,38)];
  CGFloat width=MIN(limit,MAX(72,fit.width+16));
  CGFloat height=MIN(40,MAX(22,fit.height+7));
  CGFloat x=message.outgoing?CGRectGetMaxX(source)-width:CGRectGetMinX(source);
  x=MAX(8,MIN(x,CGRectGetWidth(container.bounds)-width-8));
  CGFloat desiredY=CGRectGetMaxY(source)+3;
  CGFloat y=MIN(desiredY,MAX(1,CGRectGetHeight(container.bounds)-height-2));
  label.frame=CGRectIntegral(CGRectMake(x,y,width,height));
  label.autoresizingMask=UIViewAutoresizingFlexibleTopMargin|(message.outgoing?UIViewAutoresizingFlexibleLeftMargin:UIViewAutoresizingFlexibleRightMargin);
  container.clipsToBounds=NO; [container bringSubviewToFront:label];
  return label;
}

+ (void)setState:(TPBubbleState)state message:(TPExtractedMessage *)message text:(NSString *)text {
  objc_setAssociatedObject(message.cell,TPStateKey,@(state),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(message.cell,TPMessageKey,message.messageId,OBJC_ASSOCIATION_COPY_NONATOMIC);
  UILabel *label=[self labelForMessage:message]; label.text=[@"  " stringByAppendingString:text?:@""]; label.userInteractionEnabled=state==TPBubbleStateFailed;
  [self labelForMessage:message];
}

+ (void)setTranslatingForMessage:(TPExtractedMessage *)message { [self setState:TPBubbleStateTranslating message:message text:@"翻译中…"]; }

+ (void)setTranslation:(NSString *)translation forMessage:(TPExtractedMessage *)message {
  NSString *prefix=TPSettings.shared.showTranslationPrefix?(TPSettings.shared.translationPrefix?:@"译文："):@"";
  [self setState:TPBubbleStateTranslated message:message text:[prefix stringByAppendingString:translation]];
  UILabel *label=objc_getAssociatedObject(message.cell,TPLabelKey);
  if(prefix.length&&label.text.length>=prefix.length+2){ NSMutableAttributedString *styled=[[NSMutableAttributedString alloc]initWithString:label.text attributes:@{NSForegroundColorAttributeName:label.textColor,NSFontAttributeName:label.font}]; NSRange range=NSMakeRange(2,prefix.length); [styled addAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:.04 green:.62 blue:.40 alpha:1],NSFontAttributeName:[UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold]} range:range]; label.attributedText=styled; [self labelForMessage:message]; }
}

+ (void)setFailure:(NSError *)error forMessage:(TPExtractedMessage *)message retry:(dispatch_block_t)retry { if(!TPSettings.shared.showRetryOnFailure){[self resetCell:message.cell];return;} [self setState:TPBubbleStateFailed message:message text:@"翻译失败 · 点按重试"]; UILabel *label=objc_getAssociatedObject(message.cell,TPLabelKey); [TPRetryController attachRetry:retry toLabel:label cell:message.cell]; }

+ (void)resetCell:(UIView *)cell { UILabel *label=objc_getAssociatedObject(cell,TPLabelKey); [label removeFromSuperview]; objc_setAssociatedObject(cell,TPLabelKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC); objc_setAssociatedObject(cell,TPStateKey,@(TPBubbleStateUnprocessed),OBJC_ASSOCIATION_RETAIN_NONATOMIC); objc_setAssociatedObject(cell,TPMessageKey,nil,OBJC_ASSOCIATION_COPY_NONATOMIC); }

@end
