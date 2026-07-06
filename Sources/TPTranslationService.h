#import <Foundation/Foundation.h>
typedef void(^TPTranslationCompletion)(NSString *result,NSError *error);
@interface TPTranslationService:NSObject
+(void)translate:(NSString*)text completion:(TPTranslationCompletion)completion;
+(void)translate:(NSString*)text chatId:(NSString*)chatId completion:(TPTranslationCompletion)completion;
+(void)translate:(NSString*)text target:(NSString*)target chatId:(NSString*)chatId completion:(TPTranslationCompletion)completion;
+(void)testWithCompletion:(TPTranslationCompletion)completion;
+(void)cancelAll;
@end
