#import <Foundation/Foundation.h>
@interface TPDebugLogger:NSObject
+(instancetype)shared;
@property(nonatomic,copy)NSString*pageState;
@property(nonatomic,copy)NSString*lastError;
@property(nonatomic)NSTimeInterval lastRequestDuration;
-(void)log:(NSString*)message;
-(NSString*)exportText;
@end
