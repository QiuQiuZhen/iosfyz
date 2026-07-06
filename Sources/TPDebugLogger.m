#import "TPDebugLogger.h"
#import "TPSettings.h"
@interface TPDebugLogger()@property(nonatomic,strong)NSMutableArray*lines;@end
@implementation TPDebugLogger
+(instancetype)shared{static TPDebugLogger *x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];x.lines=[NSMutableArray array];x.pageState=@"unknown";});return x;}
-(void)log:(NSString*)message{if(!message.length)return;if([message.lowercaseString containsString:@"api key"])message=@"[敏感信息已隐藏]";NSString*line=[NSString stringWithFormat:@"%@ %@",NSDate.date,message];@synchronized(self.lines){[self.lines addObject:line];if(self.lines.count>300)[self.lines removeObjectAtIndex:0];}if(TPSettings.shared.debugLogEnabled)NSLog(@"[TranslatePlugin] %@",message);}
-(void)setLastError:(NSString*)v{_lastError=[v copy];if(v.length)[self log:[@"ERROR " stringByAppendingString:v]];}
-(NSString*)exportText{NSMutableArray*out=[NSMutableArray array];[out addObject:@"=== TranslatePlugin Debug Snapshot ==="];[out addObject:[NSString stringWithFormat:@"time=%@",NSDate.date]];[out addObject:[NSString stringWithFormat:@"pageState=%@",self.pageState?:@"unknown"]];[out addObject:[NSString stringWithFormat:@"scanSummary=%@",self.scanSummary?:@"none"]];[out addObject:[NSString stringWithFormat:@"lastError=%@",self.lastError?:@"none"]];[out addObject:[NSString stringWithFormat:@"lastRequestDuration=%.3f",self.lastRequestDuration]];[out addObject:@"=== Log Lines ==="];@synchronized(self.lines){[out addObjectsFromArray:self.lines];}return [out componentsJoinedByString:@"\n"];}
@end
