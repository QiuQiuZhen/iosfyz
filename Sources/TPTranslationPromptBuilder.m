#import "TPTranslationPromptBuilder.h"
#import "TPSettings.h"
#import "TPTermbaseManager.h"
@implementation TPTranslationPromptBuilder
+(NSString*)systemPrompt{return [self systemPromptForTarget:@"zh-CN"];}
+(NSString*)systemPromptForTarget:(NSString*)target{NSString*style=TPSettings.shared.translationStyle;NSString*terms=TPSettings.shared.enableTermbase?TPTermbaseManager.shared.promptContext:@"";BOOL chinese=[target.lowercaseString containsString:@"zh"]||[target containsString:@"中文"];NSString*instruction=chinese?@"把外语消息翻译成自然、准确、适合客服阅读的简体中文":@"Translate the Chinese message into natural, accurate business English suitable for WhatsApp customer communication";return [NSString stringWithFormat:@"你是一个 WhatsApp 聊天翻译器。%@。只输出译文，不解释，不输出 Markdown、代码块或原文；不添加、删减或总结；保留产品型号、品牌、金额、数量、邮箱、网址、订单号和换行。翻译风格：%@。必须尽量遵守以下术语：\n%@",instruction,style,terms];}
@end
