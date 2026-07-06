#import "TPRetryController.h"
#import <objc/runtime.h>
static const void*TPRetryBlockKey=&TPRetryBlockKey;
@implementation TPRetryController
+(void)attachRetry:(dispatch_block_t)retry toLabel:(UILabel*)label cell:(UIView*)cell{objc_setAssociatedObject(cell,TPRetryBlockKey,retry,OBJC_ASSOCIATION_COPY_NONATOMIC);for(UIGestureRecognizer*g in label.gestureRecognizers.copy)[label removeGestureRecognizer:g];[label addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap:)]];}
+(void)tap:(UITapGestureRecognizer*)g{UIView*cell=g.view;while(cell&&![cell isKindOfClass:UITableViewCell.class]&&![cell isKindOfClass:UICollectionViewCell.class])cell=cell.superview;dispatch_block_t block=objc_getAssociatedObject(cell,TPRetryBlockKey);if(block)block();}
@end
