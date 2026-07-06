#import "TPLanguageDetector.h"
#import "TPSettings.h"

@implementation TPLanguageDetector

+(BOOL)containsChinese:(NSString*)text{
    for(NSUInteger i=0;i<text.length;i++){
        unichar c=[text characterAtIndex:i];
        if(c>=0x4E00&&c<=0x9FFF)return YES;
    }
    return NO;
}

+(BOOL)matches:(NSString*)text pattern:(NSString*)pattern{
    if(!text.length||!pattern.length)return NO;
    NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSRange range=NSMakeRange(0,text.length);
    NSTextCheckingResult *m=[re firstMatchInString:text options:0 range:range];
    return m&&NSEqualRanges(m.range,range);
}

+(BOOL)containsLink:(NSString*)text{
    NSString *lower=text.lowercaseString?:@"";
    if([lower hasPrefix:@"http://"]||[lower hasPrefix:@"https://"]||[lower hasPrefix:@"www."])return YES;
    if([lower containsString:@"http://"]||[lower containsString:@"https://"]||[lower containsString:@"www."])return YES;
    NSURL *url=[NSURL URLWithString:text];
    if(url.scheme.length&&url.host.length)return YES;
    return [self matches:lower pattern:@"[a-z0-9._%+-]+\\.[a-z]{2,}(/[\\S]*)?"];
}

+(BOOL)hasTranslationMarker:(NSString*)text{
    NSString *lower=text.lowercaseString?:@"";
    NSArray *marks=@[@"译文：",@"译文:",@"翻译：",@"翻译:",@"translating",@"translation failed",@"tp.translation"];
    for(NSString *mark in marks)if([lower containsString:mark.lowercaseString])return YES;
    NSString *prefix=TPSettings.shared.translationPrefix;
    return prefix.length&&[text containsString:prefix];
}

+(NSString*)skipReasonForText:(NSString*)text{
    NSString *t=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!t.length)return @"empty";
    if([self hasTranslationMarker:t])return @"already-translated";
    if(t.length<2)return @"too-short";
    if(t.length>2000)return @"too-long";
    if([self matches:t pattern:@"[0-9]{1,2}:[0-9]{2}(\\s*(am|pm))?"])return @"time";
    if([self matches:t pattern:@"[0-9]{1,2}/[0-9]{1,2}(/[0-9]{2,4})?"])return @"date";
    if([self containsLink:t])return @"link";
    NSUInteger han=0,letters=0,digits=0,symbols=0,spaces=0;
    NSCharacterSet *letterSet=NSCharacterSet.letterCharacterSet;
    NSCharacterSet *digitSet=NSCharacterSet.decimalDigitCharacterSet;
    NSCharacterSet *spaceSet=NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for(NSUInteger i=0;i<t.length;i++){
        unichar c=[t characterAtIndex:i];
        if(c>=0x4E00&&c<=0x9FFF)han++;
        else if([letterSet characterIsMember:c])letters++;
        else if([digitSet characterIsMember:c])digits++;
        else if([spaceSet characterIsMember:c])spaces++;
        else symbols++;
    }
    NSUInteger visible=t.length-spaces;
    if([self matches:t pattern:@"[+()0-9\\-\\s]{5,}"])return @"phone-or-number";
    if(TPSettings.shared.skipChineseMessages&&han>0&&han*10>=MAX((NSUInteger)1,visible)*3)return @"chinese";
    if(letters<1)return symbols>0?@"emoji-or-symbol-only":@"no-letters";
    if(digits+symbols>=visible&&letters<=1)return @"number-symbol-only";
    NSString *lower=t.lowercaseString;
    NSArray *statusWords=@[@"delivered",@"read",@"sent",@"typing",@"online",@"today",@"yesterday",@"missed call",@"voice call",@"video call"];
    for(NSString *word in statusWords)if([lower isEqualToString:word])return @"status-text";
    return nil;
}

+(BOOL)shouldTranslateText:(NSString*)text{
    return [self skipReasonForText:text]==nil;
}

@end
