#import "TPTranslationService.h"
#import "TPSettings.h"
#import "TPCacheStore.h"
#import "TPTranslationPromptBuilder.h"
#import "TPDebugLogger.h"

@implementation TPTranslationService

+(NSMutableSet*)tasks{
    static NSMutableSet *x;
    static dispatch_once_t once;
    dispatch_once(&once,^{x=[NSMutableSet set];});
    return x;
}

+(NSString*)preview:(NSString*)text{
    NSString *t=[text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    if(t.length>80)return [[t substringToIndex:80] stringByAppendingString:@"..."];
    return t?:@"";
}

+(void)translate:(NSString*)text completion:(TPTranslationCompletion)done{
    [self translate:text target:TPSettings.shared.targetLanguage chatId:@"manual" completion:done];
}

+(void)translate:(NSString*)text chatId:(NSString*)chat completion:(TPTranslationCompletion)done{
    [self translate:text target:TPSettings.shared.targetLanguage chatId:chat completion:done];
}

+(void)translate:(NSString*)text target:(NSString*)target chatId:(NSString*)chat completion:(TPTranslationCompletion)done{
    if(!text.length){
        NSError *e=[NSError errorWithDomain:@"TranslatePlugin" code:0 userInfo:@{NSLocalizedDescriptionKey:@"empty text"}];
        dispatch_async(dispatch_get_main_queue(),^{if(done)done(nil,e);});
        return;
    }
    NSDictionary *cached=[TPCacheStore.shared entryForChat:chat text:text target:target];
    if(cached[@"translation"]){
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"translate cache-hit chat=%@ target=%@ len=%lu result=%@",chat?:@"unknown",target?:@"",(unsigned long)text.length,[self preview:cached[@"translation"]]]];
        dispatch_async(dispatch_get_main_queue(),^{if(done)done(cached[@"translation"],nil);});
        return;
    }
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"translate enqueue queued=YES chat=%@ target=%@ len=%lu model=%@ preview=%@",
                               chat?:@"unknown",target?:@"",(unsigned long)text.length,TPSettings.shared.model?:@"",[self preview:text]]];
    [self request:text target:target chat:chat attempt:0 started:NSDate.date completion:done];
}

+(NSError*)errorWithCode:(NSInteger)code message:(NSString*)message{
    return [NSError errorWithDomain:@"TranslatePlugin" code:code userInfo:@{NSLocalizedDescriptionKey:message?:@"translation failed"}];
}

+(NSString*)hostForURLString:(NSString*)urlString{
    NSURL *u=[NSURL URLWithString:urlString];
    return u.host?:urlString?:@"";
}

+(void)request:(NSString*)text target:(NSString*)target chat:(NSString*)chat attempt:(NSInteger)attempt started:(NSDate*)started completion:(TPTranslationCompletion)done{
    TPSettings *settings=TPSettings.shared;
    if(!settings.apiKey.length||!settings.baseURL.length||!settings.model.length){
        NSError *e=[self errorWithCode:1 message:@"Please configure Base URL, API Key, and Model Name first."];
        TPDebugLogger.shared.lastError=e.localizedDescription;
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"translate config-missing hasBaseURL=%@ hasAPIKey=%@ hasModel=%@",
                                   settings.baseURL.length?@"YES":@"NO",settings.apiKey.length?@"YES":@"NO",settings.model.length?@"YES":@"NO"]];
        dispatch_async(dispatch_get_main_queue(),^{if(done)done(nil,e);});
        return;
    }
    NSString *base=[settings.baseURL stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    NSURL *url=[NSURL URLWithString:[base stringByAppendingString:@"/chat/completions"]];
    if(!url){
        NSError *e=[self errorWithCode:2 message:@"Invalid Base URL."];
        TPDebugLogger.shared.lastError=e.localizedDescription;
        dispatch_async(dispatch_get_main_queue(),^{if(done)done(nil,e);});
        return;
    }
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:settings.timeoutSeconds];
    request.HTTPMethod=@"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[@"Bearer " stringByAppendingString:settings.apiKey] forHTTPHeaderField:@"Authorization"];
    NSDictionary *body=@{@"model":settings.model,
                         @"temperature":@0.1,
                         @"messages":@[@{@"role":@"system",@"content":[TPTranslationPromptBuilder systemPromptForTarget:target]},
                                       @{@"role":@"user",@"content":text}]};
    NSError *jsonError=nil;
    request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if(jsonError){
        TPDebugLogger.shared.lastError=jsonError.localizedDescription;
        dispatch_async(dispatch_get_main_queue(),^{if(done)done(nil,jsonError);});
        return;
    }
    NSDate *attemptStarted=NSDate.date;
    [TPDebugLogger.shared log:[NSString stringWithFormat:@"translate request-start chat=%@ attempt=%ld/%ld host=%@ model=%@ timeout=%.0f textLen=%lu",
                               chat?:@"unknown",(long)attempt+1,(long)settings.maxRetries+1,[self hostForURLString:settings.baseURL],settings.model?:@"",settings.timeoutSeconds,(unsigned long)text.length]];
    __block NSURLSessionDataTask *task=nil;
    task=[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        @synchronized(self.tasks){[self.tasks removeObject:task];}
        NSTimeInterval attemptDuration=-[attemptStarted timeIntervalSinceNow];
        NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse*)response statusCode]:0;
        NSString *result=nil;
        NSError *finalError=error;
        NSDictionary *json=nil;
        if(data.length){
            NSError *parseError=nil;
            id parsed=[NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if([parsed isKindOfClass:NSDictionary.class])json=parsed;
            if(parseError&&!finalError)finalError=parseError;
        }
        if(json){
            id choices=json[@"choices"];
            if([choices isKindOfClass:NSArray.class]&&[(NSArray*)choices count]>0){
                id first=[(NSArray*)choices firstObject];
                id content=[first valueForKeyPath:@"message.content"];
                if([content isKindOfClass:NSString.class])result=[content stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            }
            if(!result.length&&!finalError){
                NSString *message=[json valueForKeyPath:@"error.message"];
                finalError=[self errorWithCode:status message:message.length?message:@"translation API returned no content"];
            }
        }else if(!finalError){
            finalError=[self errorWithCode:status message:@"translation API returned invalid JSON"];
        }
        if(status>=400&&!finalError)finalError=[self errorWithCode:status message:[NSString stringWithFormat:@"HTTP %ld",(long)status]];
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"translate request-finish chat=%@ attempt=%ld status=%ld duration=%.3f error=%@ result=%@",
                                   chat?:@"unknown",(long)attempt+1,(long)status,attemptDuration,finalError.localizedDescription?:@"none",[self preview:result]]];
        if(finalError&&attempt<settings.maxRetries){
            [TPDebugLogger.shared log:[NSString stringWithFormat:@"translate retry-scheduled chat=%@ nextAttempt=%ld maxRetries=%ld reason=%@",
                                       chat?:@"unknown",(long)attempt+2,(long)settings.maxRetries,finalError.localizedDescription?:@"unknown"]];
            [self request:text target:target chat:chat attempt:attempt+1 started:started completion:done];
            return;
        }
        TPDebugLogger.shared.lastRequestDuration=-[started timeIntervalSinceNow];
        TPDebugLogger.shared.lastError=finalError.localizedDescription;
        if(result.length)[TPCacheStore.shared setTranslation:result chat:chat text:text target:target provider:settings.provider model:settings.model];
        [TPDebugLogger.shared log:[NSString stringWithFormat:@"translate done chat=%@ status=%ld totalDuration=%.3f error=%@ result=%@",
                                   chat?:@"unknown",(long)status,TPDebugLogger.shared.lastRequestDuration,finalError.localizedDescription?:@"none",[self preview:result]]];
        dispatch_async(dispatch_get_main_queue(),^{if(done)done(result,finalError);});
    }];
    @synchronized(self.tasks){[self.tasks addObject:task];}
    [task resume];
}

+(void)testWithCompletion:(TPTranslationCompletion)done{
    [self translate:@"Hello, what is your best price?" target:@"zh-CN" chatId:@"api-test" completion:done];
}

+(void)cancelAll{
    @synchronized(self.tasks){
        for(NSURLSessionTask *task in self.tasks)[task cancel];
        [self.tasks removeAllObjects];
    }
    [TPDebugLogger.shared log:@"translate cancel-all"];
}

@end
