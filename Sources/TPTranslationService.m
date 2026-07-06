#import "TPTranslationService.h"
#import "TPSettings.h"
#import "TPCacheStore.h"
#import "TPTranslationPromptBuilder.h"
#import "TPDebugLogger.h"

@implementation TPTranslationService

+ (NSMutableSet *)tasks { static NSMutableSet *x; static dispatch_once_t o; dispatch_once(&o,^{x=[NSMutableSet set];}); return x; }

+ (void)translate:(NSString *)text completion:(TPTranslationCompletion)done {
  [self translate:text target:TPSettings.shared.targetLanguage chatId:@"manual" completion:done];
}

+ (void)translate:(NSString *)text chatId:(NSString *)chat completion:(TPTranslationCompletion)done {
  [self translate:text target:TPSettings.shared.targetLanguage chatId:chat completion:done];
}

+ (void)translate:(NSString *)text target:(NSString *)target chatId:(NSString *)chat completion:(TPTranslationCompletion)done {
  NSDictionary *cached=[TPCacheStore.shared entryForChat:chat text:text target:target];
  if(cached){ dispatch_async(dispatch_get_main_queue(),^{done(cached[@"translation"],nil);}); return; }
  [self request:text target:target chat:chat attempt:0 started:NSDate.date completion:done];
}

+ (void)request:(NSString *)text target:(NSString *)target chat:(NSString *)chat attempt:(NSInteger)attempt started:(NSDate *)started completion:(TPTranslationCompletion)done {
  TPSettings *s=TPSettings.shared;
  if(!s.apiKey.length||!s.baseURL.length||!s.model.length){ NSError *e=[NSError errorWithDomain:@"TranslatePlugin" code:1 userInfo:@{NSLocalizedDescriptionKey:@"请先填写 Base URL、API Key 和模型名称"}]; dispatch_async(dispatch_get_main_queue(),^{done(nil,e);}); return; }
  NSString *base=[s.baseURL stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
  NSURL *url=[NSURL URLWithString:[base stringByAppendingString:@"/chat/completions"]];
  if(!url){ dispatch_async(dispatch_get_main_queue(),^{done(nil,[NSError errorWithDomain:@"TranslatePlugin" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Base URL 无效"}]);}); return; }
  NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:s.timeoutSeconds];
  r.HTTPMethod=@"POST"; [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; [r setValue:[@"Bearer " stringByAppendingString:s.apiKey] forHTTPHeaderField:@"Authorization"];
  r.HTTPBody=[NSJSONSerialization dataWithJSONObject:@{@"model":s.model,@"temperature":@0.1,@"messages":@[@{@"role":@"system",@"content":[TPTranslationPromptBuilder systemPromptForTarget:target]},@{@"role":@"user",@"content":text}]} options:0 error:nil];
  __block NSURLSessionDataTask *task;
  task=[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *d,NSURLResponse *response,NSError *error){
    @synchronized(self.tasks){[self.tasks removeObject:task];}
    NSString *result; NSError *finalError=error;
    if(d&&!error){ NSDictionary *j=[NSJSONSerialization JSONObjectWithData:d options:0 error:&finalError]; id content=j[@"choices"][0][@"message"][@"content"]; if([content isKindOfClass:NSString.class])result=[content stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if(!result.length&&!finalError)finalError=[NSError errorWithDomain:@"TranslatePlugin" code:[(NSHTTPURLResponse*)response statusCode] userInfo:@{NSLocalizedDescriptionKey:j[@"error"][@"message"]?:@"翻译接口返回异常"}]; }
    if(finalError&&attempt<s.maxRetries){ [self request:text target:target chat:chat attempt:attempt+1 started:started completion:done]; return; }
    TPDebugLogger.shared.lastRequestDuration=-[started timeIntervalSinceNow]; TPDebugLogger.shared.lastError=finalError.localizedDescription;
    if(result.length)[TPCacheStore.shared setTranslation:result chat:chat text:text target:target provider:s.provider model:s.model];
    dispatch_async(dispatch_get_main_queue(),^{done(result,finalError);});
  }];
  @synchronized(self.tasks){[self.tasks addObject:task];} [task resume];
}

+ (void)testWithCompletion:(TPTranslationCompletion)done { [self translate:@"Hello, what is your best price?" target:@"zh-CN" chatId:@"api-test" completion:done]; }
+ (void)cancelAll { @synchronized(self.tasks){for(NSURLSessionTask *t in self.tasks)[t cancel];[self.tasks removeAllObjects];} }

@end
