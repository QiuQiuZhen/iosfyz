#import <Foundation/Foundation.h>
@interface TPLanguageDetector:NSObject
+(BOOL)shouldTranslateText:(NSString*)text;
+(NSString*)skipReasonForText:(NSString*)text;
+(BOOL)containsChinese:(NSString*)text;
@end
