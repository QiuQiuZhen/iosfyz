#import "TPTranslationService.h"
#import "TPSettings.h"
#import "TPCacheStore.h"
@implementation TPTranslationService
+ (void)translate:(NSString *)text completion:(TPTranslationCompletion)done {
  [self translate:text target:TPSettings.shared.targetLanguage completion:done];
}
+ (NSString *)automaticTargetForText:(NSString *)text {
  NSUInteger han=0, letters=0;
  for(NSUInteger i=0;i<text.length;i++){ unichar c=[text characterAtIndex:i]; if(c>=0x4E00&&c<=0x9FFF)han++; else if([[NSCharacterSet letterCharacterSet] characterIsMember:c])letters++; }
  return han>MAX((NSUInteger)1,letters/3) ? @"English" : @"Simplified Chinese";
}
+ (void)translate:(NSString *)text target:(NSString *)target completion:(TPTranslationCompletion)done {
  TPSettings *s=TPSettings.shared; NSString *key=s.apiKey;
  NSString *cached=[TPCacheStore.shared translationForText:text target:target]; if(cached){dispatch_async(dispatch_get_main_queue(),^{done(cached,nil);});return;}
  if(!text.length || !key.length){ dispatch_async(dispatch_get_main_queue(), ^{ done(nil,[NSError errorWithDomain:@"TranslatePlugin" code:1 userInfo:@{NSLocalizedDescriptionKey:@"请先配置 API Key"}]); }); return; }
  NSString *url=[s.baseURL stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
  NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[url stringByAppendingString:@"/chat/completions"]] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
  r.HTTPMethod=@"POST"; [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; [r setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
  NSString *prompt=[NSString stringWithFormat:@"Detect the source language, then translate the user's message into %@. Preserve names, prices, model numbers and line breaks. Return only the translation, with no explanation.",target];
  NSDictionary *body=@{@"model":s.model,@"temperature":@0.2,@"messages":@[@{@"role":@"system",@"content":prompt},@{@"role":@"user",@"content":text}]};
  r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
  [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *resp, NSError *e){
    NSString *result; NSError *err=e; if(d && !e){ NSDictionary *j=[NSJSONSerialization JSONObjectWithData:d options:0 error:&err]; result=j[@"choices"][0][@"message"][@"content"]; if(!result && !err) err=[NSError errorWithDomain:@"TranslatePlugin" code:[(NSHTTPURLResponse*)resp statusCode] userInfo:@{NSLocalizedDescriptionKey:j[@"error"][@"message"] ?: @"翻译接口返回异常"}]; }
    result=[result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if(result.length)[TPCacheStore.shared setTranslation:result forText:text target:target];
    dispatch_async(dispatch_get_main_queue(), ^{ done(result,err); });
  }] resume];
}
@end
