#import "TPTranslationPromptBuilder.h"
#import "TPSettings.h"
#import "TPTermbaseManager.h"

@implementation TPTranslationPromptBuilder

+(NSString*)systemPrompt{
    return [self systemPromptForTarget:@"zh-CN"];
}

+(NSString*)systemPromptForTarget:(NSString*)target{
    NSString *style=TPSettings.shared.translationStyle?:@"natural";
    NSString *terms=TPSettings.shared.enableTermbase?TPTermbaseManager.shared.promptContext:@"";
    BOOL chinese=[target.lowercaseString containsString:@"zh"]||[target containsString:@"中文"];
    NSString *instruction=chinese?
    @"你是 WhatsApp 聊天消息翻译器。请把用户消息翻译成自然、简洁、口语化的中文。只输出中文译文，不要解释，不要添加前缀，不要添加引号，不要保留原文。遇到链接、代码、用户名、品牌名、型号、金额、尺码、表情符号时保持原样。":
    @"You are a WhatsApp chat message translator. Translate the user message into natural, concise English. Output only the translation, without explanations, prefixes, quotes, Markdown, or the original text. Keep links, code, usernames, brand names, model numbers, amounts, sizes, and emoji unchanged.";
    if(terms.length){
        return [NSString stringWithFormat:@"%@ Translation style: %@. Follow this glossary when applicable:\n%@",instruction,style,terms];
    }
    return [NSString stringWithFormat:@"%@ Translation style: %@.",instruction,style];
}

@end
