#import "HtmlColor.h"


@implementation HtmlColor
+ (UIColor *) colorWithHexString: (NSString *) stringToConvert
{
	NSString *cString = [[stringToConvert stringByTrimmingCharactersInSet:
						  [NSCharacterSet whitespaceAndNewlineCharacterSet]] 
						 uppercaseString];
	
	// String should be 6 or 8 characters
	if ([cString length] < 6) return DEFAULT_VOID_COLOR;
	
	// strip 0X if it appears
	if ([cString hasPrefix:@"0X"]) cString = [cString substringFromIndex:2];
	if ([cString hasPrefix:@"#"]) cString = [cString substringFromIndex:1];
	if ([cString length] != 6) return DEFAULT_VOID_COLOR;
	// Separate into r, g, b substrings
	NSRange range;
	range.location = 0;
	range.length = 2;
	NSString *rString = [cString substringWithRange:range];
	
	range.location = 2;
	NSString *gString = [cString substringWithRange:range];
	
	range.location = 4;
	NSString *bString = [cString substringWithRange:range];
	// Scan values
	unsigned int r, g, b;
	[[NSScanner scannerWithString:rString] scanHexInt:&r];
	[[NSScanner scannerWithString:gString] scanHexInt:&g];
	[[NSScanner scannerWithString:bString] scanHexInt:&b];
	
	return [UIColor colorWithRed:((float) r / 255.0f)
						   green:((float) g / 255.0f)
							blue:((float) b / 255.0f)
						   alpha:1.0f];
}
+(NSString *)changeTo16:(NSString *)string10{
    
    long long long10 = [string10 longLongValue];
    
    NSString *string16 = [NSString stringWithFormat:@"%llx",long10];
    //补0
    NSString *result = [NSString string];
    int x = 0;
    if ([string16 length]<6) {
        x = 6-[string16 length];
    }
    result=[result stringByAppendingString:@"#"];
    for (int i=0; i<x; i++) {
        result=[result stringByAppendingString:@"0"];
    }
    result = [result stringByAppendingString:string16];
    return result;
}
@end
