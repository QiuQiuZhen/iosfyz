#import <Foundation/Foundation.h>
typedef void(^TPTranslationCompletion)(NSString *result, NSError *error);
@interface TPTranslationService : NSObject
+ (void)translate:(NSString *)text completion:(TPTranslationCompletion)completion;
@end
