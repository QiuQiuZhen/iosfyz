#import <Foundation/Foundation.h>
typedef void(^TPTranslationCompletion)(NSString *result, NSError *error);
@interface TPTranslationService : NSObject
+ (void)translate:(NSString *)text completion:(TPTranslationCompletion)completion;
+ (void)translate:(NSString *)text target:(NSString *)target completion:(TPTranslationCompletion)completion;
+ (NSString *)automaticTargetForText:(NSString *)text;
@end
