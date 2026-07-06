#import "TPLanguageDetector.h"
#import "TPSettings.h"
@implementation TPLanguageDetector
+(BOOL)shouldTranslateText:(NSString*)text{NSString*t=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(t.length<2||t.length>2000)return NO;NSUInteger han=0,letters=0,digits=0,symbols=0;for(NSUInteger i=0;i<t.length;i++){unichar c=[t characterAtIndex:i];if(c>=0x4E00&&c<=0x9FFF)han++;else if([[NSCharacterSet letterCharacterSet]characterIsMember:c])letters++;else if([[NSCharacterSet decimalDigitCharacterSet]characterIsMember:c])digits++;else if(![[NSCharacterSet whitespaceAndNewlineCharacterSet]characterIsMember:c])symbols++;}if(TPSettings.shared.skipChineseMessages&&han*10>=t.length*3)return NO;if(letters<2)return NO;if(digits+symbols==t.length)return NO;NSURL*u=[NSURL URLWithString:t];if(u.scheme.length&&u.host.length)return NO;return YES;}
@end
