#import <UIKit/UIKit.h>
@interface TPExtractedMessage:NSObject
@property(nonatomic,copy)NSString*text;
@property(nonatomic,weak)UIView*sourceView;
@property(nonatomic,weak)UIView*cell;
@property(nonatomic)BOOL outgoing;
@property(nonatomic,copy)NSString*messageId;
@end
@interface TPMessageTextExtractor:NSObject
+(TPExtractedMessage*)extractFromCell:(UIView*)cell inRoot:(UIView*)root;
@end
