#import <Foundation/Foundation.h>
@interface TPSettings : NSObject
+ (instancetype)shared;
@property(nonatomic, copy) NSString *baseURL;
@property(nonatomic, copy) NSString *model;
@property(nonatomic, copy) NSString *targetLanguage;
- (NSString *)apiKey;
- (void)setAPIKey:(NSString *)key;
@end
