#import "TPTranslationService.h"
#import "TPSettings.h"
@implementation TPTranslationService
+ (void)translate:(NSString *)text completion:(TPTranslationCompletion)done {
  TPSettings *s=TPSettings.shared; NSString *key=s.apiKey;
  if(!text.length || !key.length){ dispatch_async(dispatch_get_main_queue(), ^{ done(nil,[NSError errorWithDomain:@"TranslatePlugin" code:1 userInfo:@{NSLocalizedDescriptionKey:@"请先配置 API Key"}]); }); return; }
  NSString *url=[s.baseURL stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
  NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[url stringByAppendingString:@"/chat/completions"]] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
  r.HTTPMethod=@"POST"; [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; [r setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
  NSString *prompt=[NSString stringWithFormat:@"Translate the user's message into %@. Preserve names, prices, model numbers and line breaks. Return only the translation.",s.targetLanguage];
  NSDictionary *body=@{@"model":s.model,@"temperature":@0.2,@"messages":@[@{@"role":@"system",@"content":prompt},@{@"role":@"user",@"content":text}]};
  r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
  [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *resp, NSError *e){
    NSString *result; NSError *err=e; if(d && !e){ NSDictionary *j=[NSJSONSerialization JSONObjectWithData:d options:0 error:&err]; result=j[@"choices"][0][@"message"][@"content"]; if(!result && !err) err=[NSError errorWithDomain:@"TranslatePlugin" code:[(NSHTTPURLResponse*)resp statusCode] userInfo:@{NSLocalizedDescriptionKey:j[@"error"][@"message"] ?: @"翻译接口返回异常"}]; }
    dispatch_async(dispatch_get_main_queue(), ^{ done([result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],err); });
  }] resume];
}
@end
