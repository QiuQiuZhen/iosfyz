#import <Foundation/Foundation.h>
@interface TPCacheStore : NSObject
+ (instancetype)shared;
- (NSString *)translationForText:(NSString *)text target:(NSString *)target;
- (void)setTranslation:(NSString *)translation forText:(NSString *)text target:(NSString *)target;
- (void)clear;
@end
