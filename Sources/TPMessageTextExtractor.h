#import <UIKit/UIKit.h>
@interface TPExtractedMessage:NSObject
@property(nonatomic,copy)NSString*text;
@property(nonatomic,weak)UIView*sourceView;
@property(nonatomic,weak)UIView*cell;
@property(nonatomic)BOOL outgoing;
@property(nonatomic,copy)NSString*messageId;
@property(nonatomic,copy)NSString*sourceClass;
@property(nonatomic,copy)NSString*sourceProperty;
@property(nonatomic)BOOL containsChinese;
@property(nonatomic,copy)NSString*preview;
@end
@interface TPMessageTextExtractor:NSObject
+(TPExtractedMessage*)extractFromCell:(UIView*)cell inRoot:(UIView*)root;
+(TPExtractedMessage*)extractFromCell:(UIView*)cell inRoot:(UIView*)root diagnostics:(NSDictionary**)diagnostics;
@end
