#import "TPCacheStore.h"
#import "TPSettings.h"
#import <CommonCrypto/CommonDigest.h>
@interface TPCacheStore() @property(nonatomic,strong)NSMutableDictionary*items; @end
@implementation TPCacheStore
+(instancetype)shared{static id x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];NSDictionary*d=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"TPTranslationCacheV3"];x.items=[d mutableCopy]?:[NSMutableDictionary dictionary];});return x;}
- (NSString*)hash:(NSString*)s{NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];unsigned char out[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,out);NSMutableString*r=[NSMutableString string];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[r appendFormat:@"%02x",out[i]];return r;}
- (NSString*)keyChat:(NSString*)chat text:(NSString*)text target:(NSString*)target{return [NSString stringWithFormat:@"%@|%@|%@",chat?:@"unknown",[self hash:text?:@""],target?:@"zh-CN"];}
- (NSDictionary*)entryForChat:(NSString*)chat text:(NSString*)text target:(NSString*)target{if(!TPSettings.shared.enableCache)return nil;@synchronized(self){return self.items[[self keyChat:chat text:text target:target]];}}
- (void)setTranslation:(NSString*)translation chat:(NSString*)chat text:(NSString*)text target:(NSString*)target provider:(NSString*)provider model:(NSString*)model{if(!TPSettings.shared.enableCache||!translation.length)return;NSDictionary*entry=@{@"chatId":chat?:@"unknown",@"original":text?:@"",@"translation":translation,@"target":target?:@"zh-CN",@"provider":provider?:@"",@"model":model?:@"",@"createdAt":@([NSDate.date timeIntervalSince1970])};@synchronized(self){self.items[[self keyChat:chat text:text target:target]]=entry;if(self.items.count>1000)[self.items removeObjectForKey:self.items.allKeys.firstObject];[NSUserDefaults.standardUserDefaults setObject:self.items forKey:@"TPTranslationCacheV3"];}}
- (void)clearChat:(NSString*)chat{@synchronized(self){for(NSString*k in self.items.allKeys.copy)if([self.items[k][@"chatId"] isEqualToString:chat?:@"unknown"])[self.items removeObjectForKey:k];[NSUserDefaults.standardUserDefaults setObject:self.items forKey:@"TPTranslationCacheV3"];}}
- (void)clear{@synchronized(self){[self.items removeAllObjects];[NSUserDefaults.standardUserDefaults removeObjectForKey:@"TPTranslationCacheV3"];}}
- (NSUInteger)count{@synchronized(self){return self.items.count;}}
- (NSUInteger)sizeInBytes{@synchronized(self){return [NSPropertyListSerialization dataWithPropertyList:self.items format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil].length;}}
@end
