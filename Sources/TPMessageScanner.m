#import "TPMessageScanner.h"
#import "TPTranslationService.h"
#import <objc/runtime.h>

static const void *TPSourceKey=&TPSourceKey;
static const void *TPTranslationKey=&TPTranslationKey;
static const void *TPPendingKey=&TPPendingKey;

@implementation TPMessageScanner

+ (instancetype)shared { static id x; static dispatch_once_t o; dispatch_once(&o,^{x=[self new];}); return x; }

- (NSString *)cleanText:(NSString *)text {
  if(![text isKindOfClass:NSString.class])return nil;
  NSString *value=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  return value.length ? value : nil;
}

- (BOOL)isForeignMessage:(NSString *)text {
  if(text.length<2||text.length>1200)return NO;
  NSUInteger han=0, letters=0, digits=0;
  for(NSUInteger i=0;i<text.length;i++){
    unichar c=[text characterAtIndex:i];
    if(c>=0x4E00&&c<=0x9FFF)han++;
    else if([[NSCharacterSet letterCharacterSet] characterIsMember:c])letters++;
    else if([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c])digits++;
  }
  if(han>0 && han*5>=MAX((NSUInteger)1,letters))return NO;
  if(letters<2)return NO;
  NSString *lower=text.lowercaseString;
  NSArray *uiWords=@[@"typing…",@"online",@"last seen",@"delivered",@"read",@"yesterday",@"today"];
  for(NSString *word in uiWords)if([lower isEqualToString:word])return NO;
  NSRegularExpression *time=[NSRegularExpression regularExpressionWithPattern:@"^\\d{1,2}[:/.\\-]\\d{1,2}([ :/.\\-]\\d{1,4})?(\\s*[ap]m)?$" options:NSRegularExpressionCaseInsensitive error:nil];
  if([time firstMatchInString:text options:0 range:NSMakeRange(0,text.length)])return NO;
  if(digits>0 && letters==0)return NO;
  return YES;
}

- (void)collectCells:(UIView *)view output:(NSMutableArray *)cells {
  if([view isKindOfClass:UITableViewCell.class]||[view isKindOfClass:UICollectionViewCell.class]){
    if(view.window&&!view.hidden&&view.alpha>.1)[cells addObject:view];
    return;
  }
  for(UIView *subview in view.subviews)[self collectCells:subview output:cells];
}

- (void)collectTextViews:(UIView *)view output:(NSMutableArray *)views {
  if([view.accessibilityIdentifier isEqualToString:@"tp.translation"])return;
  if([view isKindOfClass:UILabel.class]||[view isKindOfClass:UITextView.class]){
    NSString *text=[view isKindOfClass:UILabel.class]?((UILabel*)view).text:((UITextView*)view).text;
    if([self isForeignMessage:[self cleanText:text]])[views addObject:view];
  }
  for(UIView *subview in view.subviews)[self collectTextViews:subview output:views];
}

- (CGFloat)scoreForTextView:(UIView *)view text:(NSString *)text {
  CGFloat fontSize=14;
  if([view isKindOfClass:UILabel.class])fontSize=((UILabel*)view).font.pointSize;
  if([view isKindOfClass:UITextView.class])fontSize=((UITextView*)view).font.pointSize;
  return MIN((CGFloat)text.length,160)+fontSize*4;
}

- (NSString *)textFromView:(UIView *)view {
  if([view isKindOfClass:UILabel.class])return [self cleanText:((UILabel*)view).text];
  if([view isKindOfClass:UITextView.class])return [self cleanText:((UITextView*)view).text];
  return nil;
}

- (void)scanVisibleMessagesInView:(UIView *)root excludingComposer:(UITextView *)composer {
  if(!root.window||!composer.window)return;
  NSMutableArray *cells=[NSMutableArray array];
  [self collectCells:root output:cells];
  CGRect composerRect=[composer convertRect:composer.bounds toView:root];
  for(UIView *cell in cells){
    CGRect cellRect=[cell convertRect:cell.bounds toView:root];
    if(!CGRectIntersectsRect(cellRect,root.bounds)||CGRectGetMinY(cellRect)>=CGRectGetMinY(composerRect))continue;
    NSMutableArray *textViews=[NSMutableArray array];
    [self collectTextViews:cell output:textViews];
    UIView *best=nil; NSString *bestText=nil; CGFloat bestScore=0;
    for(UIView *candidate in textViews){ NSString *text=[self textFromView:candidate]; CGFloat score=[self scoreForTextView:candidate text:text]; if(score>bestScore){best=candidate;bestText=text;bestScore=score;} }
    if(!bestText.length){ NSString *accessible=[self cleanText:cell.accessibilityLabel]; if([self isForeignMessage:accessible]){best=cell;bestText=accessible;} }
    if(bestText.length)[self translateText:bestText sourceView:best inCell:cell];
  }
}

- (void)translateText:(NSString *)text sourceView:(UIView *)source inCell:(UIView *)cell {
  NSString *old=objc_getAssociatedObject(cell,TPSourceKey);
  if([old isEqualToString:text]&&(objc_getAssociatedObject(cell,TPTranslationKey)||objc_getAssociatedObject(cell,TPPendingKey)))return;
  UILabel *previous=objc_getAssociatedObject(cell,TPTranslationKey); [previous removeFromSuperview];
  objc_setAssociatedObject(cell,TPTranslationKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(cell,TPSourceKey,text,OBJC_ASSOCIATION_COPY_NONATOMIC);
  objc_setAssociatedObject(cell,TPPendingKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  __weak UIView *weakCell=cell; __weak UIView *weakSource=source;
  [TPTranslationService translate:text target:@"Simplified Chinese" completion:^(NSString *result,NSError *error){
    UIView *strongCell=weakCell; UIView *strongSource=weakSource;
    objc_setAssociatedObject(strongCell,TPPendingKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(!strongCell.window||!result.length||![objc_getAssociatedObject(strongCell,TPSourceKey) isEqualToString:text])return;
    [self showTranslation:result sourceView:strongSource inCell:strongCell];
  }];
}

- (void)showTranslation:(NSString *)text sourceView:(UIView *)source inCell:(UIView *)cell {
  UIView *container=cell;
  if([cell isKindOfClass:UITableViewCell.class])container=((UITableViewCell*)cell).contentView;
  if([cell isKindOfClass:UICollectionViewCell.class])container=((UICollectionViewCell*)cell).contentView;
  UILabel *label=[UILabel new]; label.accessibilityIdentifier=@"tp.translation"; label.text=text; label.numberOfLines=2;
  label.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium]; label.textColor=[UIColor colorWithRed:.08 green:.48 blue:.34 alpha:1];
  label.backgroundColor=[UIColor colorWithWhite:1 alpha:.90]; label.layer.cornerRadius=4; label.clipsToBounds=YES;
  CGFloat width=MAX(100,MIN(CGRectGetWidth(container.bounds)-24,320)); CGSize size=[label sizeThatFits:CGSizeMake(width,44)];
  CGRect sourceRect=source?[source convertRect:source.bounds toView:container]:CGRectZero;
  CGFloat x=source?MAX(12,MIN(CGRectGetMinX(sourceRect),CGRectGetWidth(container.bounds)-width-12)):12;
  CGFloat y=source?CGRectGetMaxY(sourceRect)+2:CGRectGetHeight(container.bounds)-MIN(44,size.height+5)-2;
  y=MIN(y,CGRectGetHeight(container.bounds)-MIN(44,size.height+5)-1);
  label.frame=CGRectMake(x,MAX(1,y),width,MIN(44,size.height+5)); label.autoresizingMask=UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleRightMargin;
  container.clipsToBounds=NO; [container addSubview:label]; [container bringSubviewToFront:label];
  objc_setAssociatedObject(cell,TPTranslationKey,label,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
