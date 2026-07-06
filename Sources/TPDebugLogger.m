#import "TPDebugLogger.h"
#import "TPSettings.h"
@interface TPDebugLogger()@property(nonatomic,strong)NSMutableArray*lines;@end
@implementation TPDebugLogger
+(instancetype)shared{static TPDebugLogger *x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];x.lines=[NSMutableArray array];x.pageState=@"unknown";});return x;}
-(void)log:(NSString*)message{if(!message.length)return;if([message.lowercaseString containsString:@"api key"])message=@"[敏感信息已隐藏]";NSString*line=[NSString stringWithFormat:@"%@ %@",NSDate.date,message];@synchronized(self.lines){[self.lines addObject:line];if(self.lines.count>300)[self.lines removeObjectAtIndex:0];}if(TPSettings.shared.debugLogEnabled)NSLog(@"[TranslatePlugin] %@",message);}
-(void)setLastError:(NSString*)v{_lastError=[v copy];if(v.length)[self log:[@"ERROR " stringByAppendingString:v]];}
-(NSString*)exportText{@synchronized(self.lines){return [self.lines componentsJoinedByString:@"\n"];}}
@end
