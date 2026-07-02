#import "TPSettings.h"
#import <Security/Security.h>
static NSString *const TPService = @"com.local.translateplugin.apikey";
@implementation TPSettings
+ (instancetype)shared { static TPSettings *x; static dispatch_once_t once; dispatch_once(&once, ^{ x=[self new]; }); return x; }
- (instancetype)init { if ((self=[super init])) { NSUserDefaults *d=NSUserDefaults.standardUserDefaults; _baseURL=[d stringForKey:@"TPBaseURL"] ?: @"https://api.openai.com/v1"; _model=[d stringForKey:@"TPModel"] ?: @"gpt-4.1-mini"; _targetLanguage=[d stringForKey:@"TPTarget"] ?: @"English"; } return self; }
- (void)setBaseURL:(NSString *)v { _baseURL=[v copy]; [NSUserDefaults.standardUserDefaults setObject:v forKey:@"TPBaseURL"]; }
- (void)setModel:(NSString *)v { _model=[v copy]; [NSUserDefaults.standardUserDefaults setObject:v forKey:@"TPModel"]; }
- (void)setTargetLanguage:(NSString *)v { _targetLanguage=[v copy]; [NSUserDefaults.standardUserDefaults setObject:v forKey:@"TPTarget"]; }
- (NSMutableDictionary *)query { return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:TPService,(__bridge id)kSecAttrAccount:@"default"} mutableCopy]; }
- (NSString *)apiKey { NSMutableDictionary *q=[self query]; q[(__bridge id)kSecReturnData]=@YES; q[(__bridge id)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne; CFTypeRef out=NULL; if(SecItemCopyMatching((__bridge CFDictionaryRef)q,&out)!=errSecSuccess) return @""; return [[NSString alloc] initWithData:CFBridgingRelease(out) encoding:NSUTF8StringEncoding] ?: @""; }
- (void)setAPIKey:(NSString *)key { NSMutableDictionary *q=[self query]; SecItemDelete((__bridge CFDictionaryRef)q); if(!key.length)return; q[(__bridge id)kSecValueData]=[key dataUsingEncoding:NSUTF8StringEncoding]; SecItemAdd((__bridge CFDictionaryRef)q,NULL); }
@end
