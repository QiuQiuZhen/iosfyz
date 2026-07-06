#import "TPMessageTextExtractor.h"
#import "TPLanguageDetector.h"
#import "TPSettings.h"
#import <CommonCrypto/CommonDigest.h>

@implementation TPExtractedMessage @end

@implementation TPMessageTextExtractor

+(NSString*)preview:(NSString*)text{
    NSString *t=[text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    t=[t stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(t.length>80)return [[t substringToIndex:80] stringByAppendingString:@"..."];
    return t?:@"";
}

+(NSString*)stripPluginSuffix:(NSString*)text{
    NSString *t=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!t.length)return @"";
    NSMutableArray *marks=[NSMutableArray arrayWithArray:@[@"\n译文：",@"\n译文:",@"\n翻译：",@"\n翻译:",@"\nTranslating",@"\nTranslation failed",@"\n翻译中",@"\n翻译失败"]];
    NSString *prefix=TPSettings.shared.translationPrefix;
    if(prefix.length)[marks addObject:[@"\n" stringByAppendingString:prefix]];
    for(NSString *mark in marks){
        NSRange r=[t rangeOfString:mark options:NSBackwardsSearch|NSCaseInsensitiveSearch];
        if(r.location!=NSNotFound)t=[[t substringToIndex:r.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return t;
}

+(NSString*)safeStringValue:(id)value{
    if([value isKindOfClass:NSString.class])return value;
    if([value isKindOfClass:NSAttributedString.class])return [(NSAttributedString*)value string];
    return nil;
}

+(id)safeValue:(id)object key:(NSString*)key{
    if(!object||!key.length)return nil;
    @try{return [object valueForKey:key];}
    @catch(NSException *e){return nil;}
}

+(CGFloat)fontSizeForView:(UIView*)view fallback:(CGFloat)fallback{
    UIFont *font=nil;
    if([view isKindOfClass:UILabel.class])font=((UILabel*)view).font;
    else if([view isKindOfClass:UITextView.class])font=((UITextView*)view).font;
    else if([view isKindOfClass:UITextField.class])font=((UITextField*)view).font;
    else if([view isKindOfClass:UIButton.class])font=((UIButton*)view).titleLabel.font;
    else {
        id v=[self safeValue:view key:@"font"];
        if([v isKindOfClass:UIFont.class])font=v;
    }
    return font.pointSize>0?font.pointSize:fallback;
}

+(BOOL)viewLooksLikeStatusOrChrome:(UIView*)view property:(NSString*)property{
    NSString *name=NSStringFromClass(view.class).lowercaseString?:@"";
    NSString *prop=property.lowercaseString?:@"";
    if([prop containsString:@"button"]||[name containsString:@"button"])return YES;
    NSArray *needles=@[@"status",@"timestamp",@"time",@"receipt",@"checkmark",@"tick",@"avatar",@"sendername",@"date",@"separator",@"unread",@"reaction"];
    for(NSString *needle in needles)if([name containsString:needle])return YES;
    return NO;
}

+(NSArray*)partsForText:(NSString*)text accessibility:(BOOL)accessibility{
    NSString *clean=[self stripPluginSuffix:text];
    if(!clean.length)return @[];
    if(!accessibility)return @[clean];
    NSMutableArray *parts=[NSMutableArray array];
    NSCharacterSet *separators=[NSCharacterSet characterSetWithCharactersInString:@",，\n|•·"];
    for(NSString *part in [clean componentsSeparatedByCharactersInSet:separators]){
        NSString *p=[part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(p.length)[parts addObject:p];
    }
    if(!parts.count)[parts addObject:clean];
    return parts;
}

+(void)bumpReason:(NSString*)reason diagnostics:(NSMutableDictionary*)diag{
    if(!reason.length)reason=@"unknown";
    NSMutableDictionary *reasons=diag[@"skipReasons"];
    NSNumber *old=reasons[reason];
    reasons[reason]=@((old?old.integerValue:0)+1);
    diag[@"skippedCandidates"]=@([diag[@"skippedCandidates"] integerValue]+1);
}

+(void)addText:(NSString*)value view:(UIView*)view property:(NSString*)property into:(NSMutableArray*)items diagnostics:(NSMutableDictionary*)diag{
    if(!value.length||!view)return;
    BOOL accessibility=[property.lowercaseString containsString:@"accessibility"];
    for(NSString *part in [self partsForText:value accessibility:accessibility]){
        if([self viewLooksLikeStatusOrChrome:view property:property]){
            [self bumpReason:@"chrome-or-status-view" diagnostics:diag];
            continue;
        }
        NSString *reason=[TPLanguageDetector skipReasonForText:part];
        if(reason){
            [self bumpReason:reason diagnostics:diag];
            continue;
        }
        CGFloat font=[self fontSizeForView:view fallback:15];
        [items addObject:@{@"view":view,@"text":part,@"font":@(font),@"property":property?:@"unknown"}];
        diag[@"acceptedCandidates"]=@([diag[@"acceptedCandidates"] integerValue]+1);
    }
}

+(void)collect:(UIView*)view into:(NSMutableArray*)items diagnostics:(NSMutableDictionary*)diag depth:(NSUInteger)depth{
    if(!view||depth>80)return;
    diag[@"visitedViews"]=@([diag[@"visitedViews"] integerValue]+1);
    if(view.hidden||view.alpha<0.05)return;
    if([view.accessibilityIdentifier isEqualToString:@"tp.translation"])return;
    if([view isKindOfClass:UILabel.class]){
        UILabel *label=(UILabel*)view;
        [self addText:label.text view:view property:@"UILabel.text" into:items diagnostics:diag];
        [self addText:label.attributedText.string view:view property:@"UILabel.attributedText" into:items diagnostics:diag];
    }else if([view isKindOfClass:UITextView.class]){
        UITextView *textView=(UITextView*)view;
        [self addText:textView.text view:view property:@"UITextView.text" into:items diagnostics:diag];
        [self addText:textView.attributedText.string view:view property:@"UITextView.attributedText" into:items diagnostics:diag];
    }else if([view isKindOfClass:UITextField.class]){
        [self addText:((UITextField*)view).text view:view property:@"UITextField.text" into:items diagnostics:diag];
    }else if([view isKindOfClass:UIButton.class]){
        UIButton *button=(UIButton*)view;
        [self addText:button.currentTitle view:view property:@"UIButton.currentTitle" into:items diagnostics:diag];
        [self addText:button.titleLabel.text view:view property:@"UIButton.titleLabel.text" into:items diagnostics:diag];
    }
    for(NSString *key in @[@"text",@"attributedText",@"string",@"attributedString",@"messageText",@"displayText",@"plainText",@"contentText",@"bodyText"]){
        NSString *text=[self safeStringValue:[self safeValue:view key:key]];
        [self addText:text view:view property:key into:items diagnostics:diag];
    }
    if(view.subviews.count==0||view.isAccessibilityElement){
        [self addText:view.accessibilityLabel view:view property:@"accessibilityLabel" into:items diagnostics:diag];
        [self addText:view.accessibilityValue view:view property:@"accessibilityValue" into:items diagnostics:diag];
    }
    for(UIView *sub in view.subviews)[self collect:sub into:items diagnostics:diag depth:depth+1];
}

+(CGFloat)scoreCandidate:(NSDictionary*)candidate root:(UIView*)root cell:(UIView*)cell{
    NSString *text=candidate[@"text"];
    UIView *view=candidate[@"view"];
    NSString *property=candidate[@"property"];
    CGFloat font=[candidate[@"font"] doubleValue];
    CGFloat score=MIN((CGFloat)text.length,220.0)+font*4.0;
    NSString *prop=property.lowercaseString?:@"";
    NSString *name=NSStringFromClass(view.class).lowercaseString?:@"";
    if([view isKindOfClass:UILabel.class])score+=35;
    if([view isKindOfClass:UITextView.class])score+=30;
    if([prop containsString:@"messagetext"]||[prop containsString:@"displaytext"]||[prop containsString:@"bodytext"])score+=55;
    if([prop containsString:@"accessibility"])score-=35;
    if([view isKindOfClass:UIButton.class])score-=80;
    if([name containsString:@"message"]||[name containsString:@"text"]||[name containsString:@"slice"])score+=20;
    CGRect r=[view convertRect:view.bounds toView:cell];
    if(CGRectGetWidth(r)<35||CGRectGetHeight(r)<8)score-=45;
    if(CGRectGetMaxY(r)>CGRectGetHeight(cell.bounds)-18&&text.length<12)score-=60;
    if(text.length<=3)score-=15;
    return score;
}

+(NSString*)hash:(NSString*)s{
    NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char out[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(d.bytes,(CC_LONG)d.length,out);
    NSMutableString *r=[NSMutableString string];
    for(int i=0;i<12;i++)[r appendFormat:@"%02x",out[i]];
    return r;
}

+(TPExtractedMessage*)extractFromCell:(UIView*)cell inRoot:(UIView*)root{
    return [self extractFromCell:cell inRoot:root diagnostics:nil];
}

+(TPExtractedMessage*)extractFromCell:(UIView*)cell inRoot:(UIView*)root diagnostics:(NSDictionary**)diagnostics{
    NSMutableDictionary *diag=[@{@"cellClass":NSStringFromClass(cell.class)?:@"unknown",
                                 @"visitedViews":@0,
                                 @"acceptedCandidates":@0,
                                 @"skippedCandidates":@0,
                                 @"skipReasons":[NSMutableDictionary dictionary]} mutableCopy];
    NSMutableArray *items=[NSMutableArray array];
    [self collect:cell into:items diagnostics:diag depth:0];
    NSDictionary *best=nil;
    CGFloat bestScore=-CGFLOAT_MAX;
    for(NSDictionary *candidate in items){
        CGFloat score=[self scoreCandidate:candidate root:root cell:cell];
        if(score>bestScore){bestScore=score;best=candidate;}
    }
    if(!best){
        NSString *fallback=[cell.accessibilityLabel stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *reason=[TPLanguageDetector skipReasonForText:fallback];
        if(reason)[self bumpReason:reason diagnostics:diag];
        if(!reason&&fallback.length)best=@{@"view":cell,@"text":fallback,@"font":@15,@"property":@"cell.accessibilityLabel"};
    }
    NSString *text=best[@"text"];
    UIView *source=best[@"view"];
    NSString *property=best[@"property"];
    if(!text.length||!source){
        diag[@"result"]=@"no-text";
        if(diagnostics)*diagnostics=[diag copy];
        return nil;
    }
    CGRect sourceRect=[source convertRect:source.bounds toView:root];
    CGRect cellRect=[cell convertRect:cell.bounds toView:root];
    TPExtractedMessage *m=[TPExtractedMessage new];
    m.text=text;
    m.sourceView=source;
    m.cell=cell;
    m.outgoing=CGRectGetMidX(sourceRect)>CGRectGetWidth(root.bounds)*0.55||CGRectGetMidX(cellRect)>CGRectGetWidth(root.bounds)*0.55;
    m.sourceClass=NSStringFromClass(source.class)?:@"unknown";
    m.sourceProperty=property?:@"unknown";
    m.containsChinese=[TPLanguageDetector containsChinese:text];
    m.preview=[self preview:text];
    m.messageId=[self hash:[NSString stringWithFormat:@"%@|%@|%@|%@",m.outgoing?@"out":@"in",m.sourceClass,m.sourceProperty,text]];
    diag[@"result"]=@"ok";
    diag[@"sourceClass"]=m.sourceClass;
    diag[@"sourceProperty"]=m.sourceProperty;
    diag[@"textLength"]=@(m.text.length);
    diag[@"containsChinese"]=m.containsChinese?@"YES":@"NO";
    diag[@"messageKey"]=m.messageId?:@"nil";
    diag[@"preview"]=m.preview?:@"";
    if(diagnostics)*diagnostics=[diag copy];
    return m;
}

@end
