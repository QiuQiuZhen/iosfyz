#import "TPDebugLogger.h"
#import "TPSettings.h"

NSString *const TPPluginVersion=@"3.2.1";
static NSString *const TPDebugLogLinesKey=@"TPDebugLogLinesV4";
static const NSUInteger TPDebugLogMaxLines=1000;

@interface TPDebugLogger()
@property(nonatomic,strong)NSMutableArray *lines;
@property(nonatomic,copy)NSString *logFilePath;
@end

@implementation TPDebugLogger

+(instancetype)shared{
    static TPDebugLogger *x;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        x=[self new];
        NSArray *saved=[NSUserDefaults.standardUserDefaults arrayForKey:TPDebugLogLinesKey];
        x.lines=[saved mutableCopy]?:[NSMutableArray array];
        x.pageState=@"unknown";
        x.logFilePath=[x defaultLogFilePath];
        NSArray *fileLines=[x readFileLines];
        if(fileLines.count>x.lines.count)x.lines=[[x tail:fileLines limit:TPDebugLogMaxLines] mutableCopy];
    });
    return x;
}

-(NSString*)defaultLogFilePath{
    NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
    NSString *dir=dirs.firstObject?:NSTemporaryDirectory();
    return [dir stringByAppendingPathComponent:@"TranslatePlugin.debug.log"];
}

-(NSArray*)tail:(NSArray*)lines limit:(NSUInteger)limit{
    if(!lines.count)return @[];
    if(lines.count<=limit)return lines;
    return [lines subarrayWithRange:NSMakeRange(lines.count-limit,limit)];
}

-(NSArray*)readFileLines{
    if(!self.logFilePath.length)return @[];
    NSString *text=[NSString stringWithContentsOfFile:self.logFilePath encoding:NSUTF8StringEncoding error:nil];
    if(!text.length)return @[];
    NSArray *parts=[text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    NSMutableArray *clean=[NSMutableArray array];
    for(NSString *line in parts)if(line.length)[clean addObject:line];
    return clean;
}

-(NSString*)redactedMessage:(NSString*)message{
    NSString *lower=message.lowercaseString?:@"";
    if([lower containsString:@"api key"]||
       [lower containsString:@"apikey"]||
       [lower containsString:@"authorization"]||
       [lower containsString:@"bearer "]||
       [lower containsString:@"token="]||
       [lower containsString:@"secret"]){
        return @"[sensitive log redacted]";
    }
    return message;
}

-(void)persistLinesLocked{
    NSArray *tail=[self tail:self.lines limit:TPDebugLogMaxLines];
    if(tail.count!=self.lines.count)self.lines=[tail mutableCopy];
    [NSUserDefaults.standardUserDefaults setObject:self.lines forKey:TPDebugLogLinesKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    NSString *body=[self.lines componentsJoinedByString:@"\n"];
    [body writeToFile:self.logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

-(void)log:(NSString*)message{
    if(!message.length)return;
    message=[self redactedMessage:message];
    NSString *line=[NSString stringWithFormat:@"%@ %@",NSDate.date,message];
    @synchronized(self.lines){
        [self.lines addObject:line];
        while(self.lines.count>TPDebugLogMaxLines)[self.lines removeObjectAtIndex:0];
        [self persistLinesLocked];
    }
    if(TPSettings.shared.debugLogEnabled)NSLog(@"[TranslatePlugin] %@",message);
}

-(void)setLastError:(NSString*)value{
    _lastError=[value copy];
    if(value.length)[self log:[@"ERROR " stringByAppendingString:value]];
}

-(NSString*)exportText{
    NSMutableArray *out=[NSMutableArray array];
    NSMutableArray *merged=[NSMutableArray array];
    @synchronized(self.lines){[merged addObjectsFromArray:self.lines];}
    NSArray *fileLines=[self readFileLines];
    if(fileLines.count){
        NSMutableSet *seen=[NSMutableSet setWithArray:merged];
        for(NSString *line in fileLines){
            if(![seen containsObject:line]){
                [merged addObject:line];
                [seen addObject:line];
            }
        }
    }
    NSArray *recent=[self tail:merged limit:TPDebugLogMaxLines];
    [out addObject:@"=== TranslatePlugin Debug Snapshot ==="];
    [out addObject:[NSString stringWithFormat:@"time=%@",NSDate.date]];
    [out addObject:[NSString stringWithFormat:@"version=%@",TPPluginVersion]];
    [out addObject:[NSString stringWithFormat:@"bundle=%@",NSBundle.mainBundle.bundleIdentifier?:@"unknown"]];
    [out addObject:[NSString stringWithFormat:@"process=%@",NSProcessInfo.processInfo.processName?:@"unknown"]];
    [out addObject:[NSString stringWithFormat:@"logFile=%@",self.logFilePath?:@"unknown"]];
    [out addObject:[NSString stringWithFormat:@"pageState=%@",self.pageState?:@"unknown"]];
    [out addObject:[NSString stringWithFormat:@"scanSummary=%@",self.scanSummary?:@"none"]];
    [out addObject:[NSString stringWithFormat:@"lastError=%@",self.lastError?:@"none"]];
    [out addObject:[NSString stringWithFormat:@"lastRequestDuration=%.3f",self.lastRequestDuration]];
    [out addObject:[NSString stringWithFormat:@"lineCount=%lu",(unsigned long)recent.count]];
    [out addObject:@"=== Log Lines ==="];
    [out addObjectsFromArray:recent];
    return [out componentsJoinedByString:@"\n"];
}

@end
