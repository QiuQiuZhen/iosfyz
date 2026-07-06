#import <Foundation/Foundation.h>
extern NSString *const TPPluginVersion;
@interface TPDebugLogger:NSObject
+(instancetype)shared;
@property(nonatomic,copy)NSString*pageState;
@property(nonatomic,copy)NSString*lastError;
@property(nonatomic)NSTimeInterval lastRequestDuration;
@property(nonatomic,copy)NSString*scanSummary;
@property(nonatomic,readonly,copy)NSString*logFilePath;
-(void)log:(NSString*)message;
-(NSString*)exportText;
@end
