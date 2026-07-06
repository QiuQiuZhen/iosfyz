#import <Foundation/Foundation.h>
extern NSString *const TPSettingsDidChangeNotification;
@interface TPSettings : NSObject
+ (instancetype)shared;
@property(nonatomic) BOOL autoTranslate;
@property(nonatomic) BOOL translateIncomingOnly;
@property(nonatomic) BOOL translateOutgoing;
@property(nonatomic) BOOL showTranslationPrefix;
@property(nonatomic) BOOL showRetryOnFailure;
@property(nonatomic) BOOL autoScanVisibleMessages;
@property(nonatomic) BOOL skipChineseMessages;
@property(nonatomic) BOOL enableCache;
@property(nonatomic) BOOL enableTermbase;
@property(nonatomic) BOOL debugLogEnabled;
@property(nonatomic) NSTimeInterval timeoutSeconds;
@property(nonatomic) NSInteger maxRetries;
@property(nonatomic,copy) NSString *translationPrefix;
@property(nonatomic,copy) NSString *targetLanguage;
@property(nonatomic,copy) NSString *sourceLanguage;
@property(nonatomic,copy) NSString *provider;
@property(nonatomic,copy) NSString *baseURL;
@property(nonatomic,copy) NSString *model;
@property(nonatomic,copy) NSString *translationStyle;
- (NSString *)apiKey;
- (void)setAPIKey:(NSString *)key;
- (void)resetDefaults;
@end
