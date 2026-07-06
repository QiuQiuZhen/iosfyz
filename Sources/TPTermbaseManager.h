#import <Foundation/Foundation.h>
@interface TPTermbaseManager:NSObject
+(instancetype)shared;
-(NSDictionary*)terms;
-(void)setTarget:(NSString*)target forSource:(NSString*)source;
-(void)removeSource:(NSString*)source;
-(NSString*)promptContext;
@end
