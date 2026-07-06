#import <Foundation/Foundation.h>
@interface TPCacheStore : NSObject
+ (instancetype)shared;
- (NSDictionary *)entryForChat:(NSString *)chatId text:(NSString *)text target:(NSString *)target;
- (void)setTranslation:(NSString *)translation chat:(NSString *)chatId text:(NSString *)text target:(NSString *)target provider:(NSString *)provider model:(NSString *)model;
- (void)clearChat:(NSString *)chatId;
- (void)clear;
- (NSUInteger)count;
- (NSUInteger)sizeInBytes;
@end
