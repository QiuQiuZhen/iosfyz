#import <Foundation/Foundation.h>
@interface TPTranslationPromptBuilder:NSObject
+(NSString*)systemPrompt;
+(NSString*)systemPromptForTarget:(NSString*)target;
@end
