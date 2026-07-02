#import "TPCacheStore.h"
@interface TPCacheStore()
@property(nonatomic,strong) NSCache *memory;
@property(nonatomic,strong) NSMutableDictionary *disk;
@property(nonatomic,strong) dispatch_queue_t queue;
@end
@implementation TPCacheStore
+ (instancetype)shared { static id x; static dispatch_once_t o; dispatch_once(&o,^{x=[self new];}); return x; }
- (instancetype)init { if((self=[super init])) { _memory=[NSCache new]; _memory.countLimit=500; _queue=dispatch_queue_create("com.local.translateplugin.cache",DISPATCH_QUEUE_SERIAL); NSDictionary *saved=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"TPTranslationCache"]; _disk=[saved mutableCopy] ?: [NSMutableDictionary dictionary]; } return self; }
- (NSString *)keyForText:(NSString *)text target:(NSString *)target { NSData *d=[[NSString stringWithFormat:@"%@\n%@",target,text] dataUsingEncoding:NSUTF8StringEncoding]; return [d base64EncodedStringWithOptions:0]; }
- (NSString *)translationForText:(NSString *)text target:(NSString *)target { NSString *k=[self keyForText:text target:target]; NSString *v=[self.memory objectForKey:k]; if(!v) { @synchronized(self.disk){v=self.disk[k];} if(v)[self.memory setObject:v forKey:k]; } return v; }
- (void)setTranslation:(NSString *)value forText:(NSString *)text target:(NSString *)target { if(!value.length)return; NSString *k=[self keyForText:text target:target]; [self.memory setObject:value forKey:k]; @synchronized(self.disk){self.disk[k]=value; if(self.disk.count>500)[self.disk removeObjectForKey:self.disk.allKeys.firstObject]; NSDictionary *snapshot=[self.disk copy]; dispatch_async(self.queue,^{[NSUserDefaults.standardUserDefaults setObject:snapshot forKey:@"TPTranslationCache"];});} }
- (void)clear { [self.memory removeAllObjects]; @synchronized(self.disk){[self.disk removeAllObjects];[NSUserDefaults.standardUserDefaults removeObjectForKey:@"TPTranslationCache"];} }
@end
