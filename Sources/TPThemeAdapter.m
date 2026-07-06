#import "TPThemeAdapter.h"
@implementation TPThemeAdapter
+(UIColor*)primaryText{if(@available(iOS 13,*))return UIColor.labelColor;return UIColor.blackColor;}+(UIColor*)secondaryText{if(@available(iOS 13,*))return UIColor.secondaryLabelColor;return UIColor.grayColor;}+(UIColor*)background{if(@available(iOS 13,*))return UIColor.systemGroupedBackgroundColor;return [UIColor colorWithWhite:.95 alpha:1];}+(UIColor*)cellBackground{if(@available(iOS 13,*))return UIColor.secondarySystemGroupedBackgroundColor;return UIColor.whiteColor;}+(UIColor*)accent{return [UIColor colorWithRed:.05 green:.65 blue:.45 alpha:1];}
@end
