#import <Foundation/Foundation.h>

#define DEFAULT_VOID_COLOR 0
@interface HtmlColor : UIColor {

}
+ (UIColor *) colorWithHexString: (NSString *) stringToConvert;
+(NSString *)changeTo16:(NSString *)string10;
@end
