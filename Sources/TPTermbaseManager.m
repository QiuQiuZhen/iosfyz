#import "TPTermbaseManager.h"
@implementation TPTermbaseManager
+(instancetype)shared{static id x;static dispatch_once_t o;dispatch_once(&o,^{x=[self new];if(![NSUserDefaults.standardUserDefaults dictionaryForKey:@"TPTerms"]){NSDictionary*d=@{@"V100":@"V100 显卡",@"dual V100":@"双 V100",@"V100 32GB":@"V100 32GB",@"air cooling":@"风冷",@"liquid cooling":@"水冷",@"water cooling":@"水冷",@"server":@"服务器",@"workstation":@"工作站",@"GPU":@"显卡",@"CPU":@"处理器",@"RAM":@"内存",@"SSD":@"固态硬盘",@"power supply":@"电源",@"rack server":@"机架式服务器"};[NSUserDefaults.standardUserDefaults setObject:d forKey:@"TPTerms"];}});return x;}
-(NSDictionary*)terms{return [NSUserDefaults.standardUserDefaults dictionaryForKey:@"TPTerms"]?:@{};}
-(void)setTarget:(NSString*)target forSource:(NSString*)source{if(!source.length||!target.length)return;NSMutableDictionary*d=[self.terms mutableCopy];d[source]=target;[NSUserDefaults.standardUserDefaults setObject:d forKey:@"TPTerms"];}
-(void)removeSource:(NSString*)source{NSMutableDictionary*d=[self.terms mutableCopy];[d removeObjectForKey:source];[NSUserDefaults.standardUserDefaults setObject:d forKey:@"TPTerms"];}
-(NSString*)promptContext{NSMutableArray*a=[NSMutableArray array];[self.terms enumerateKeysAndObjectsUsingBlock:^(id k,id v,BOOL*stop){[a addObject:[NSString stringWithFormat:@"%@ = %@",k,v]];}];return [a componentsJoinedByString:@"\n"];}
@end
