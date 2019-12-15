//
//  ViewUtils.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import "ViewUtils.h"
#import "ThemeManager.h"

@implementation ViewUtils

/*
 *  (public) 辅助方法 - 生成Label。
 */
+ (UILabel*)auxGenLabel:(UIFont*)font superview:(UIView*)superview
{
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [ThemeManager sharedThemeManager].textColorMain;
    label.font = font;
    if (superview) {
        [superview addSubview:label];
    }
    return label;
}

/*
 *  (public) 辅助计算文字尺寸
 */
+ (CGSize)auxSizeWithText:(NSString*)text font:(UIFont*)font maxsize:(CGSize)maxsize
{
    assert(text);
    assert(font);
    return [text boundingRectWithSize:maxsize
                              options:NSStringDrawingUsesLineFragmentOrigin
                           attributes:@{NSFontAttributeName:font}
                              context:nil].size;
}

+ (CGSize)auxSizeWithText:(NSString*)text font:(UIFont*)font
{
    return [self auxSizeWithText:text font:font maxsize:CGSizeMake(9999, 9999)];
}

+ (CGSize)auxSizeWithLabel:(UILabel*)label maxsize:(CGSize)maxsize
{
    assert(label);
    return [self auxSizeWithText:label.text font:label.font maxsize:maxsize];
}

+ (CGSize)auxSizeWithLabel:(UILabel*)label
{
    assert(label);
    return [self auxSizeWithText:label.text font:label.font];
}

/*
 *  (public) 辅助着色
 */
+ (NSMutableAttributedString*)genAndColorAttributedText:(NSString*)titleString
                                                  value:(NSString*)valueString
                                             titleColor:(UIColor*)titleColor
                                             valueColor:(UIColor*)valueColor
{
    assert(titleString && valueString && titleColor && valueColor);
    NSString* finalString = [NSString stringWithFormat:@"%@%@", titleString, valueString];
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:finalString];
    NSRange range = [finalString rangeOfString:valueString];
    [attrString addAttribute:NSForegroundColorAttributeName value:titleColor range:NSMakeRange(0, range.location)];
    [attrString addAttribute:NSForegroundColorAttributeName value:valueColor range:range];
    return attrString;
}

/*
 *  (public) 大部分输入框占位符默认属性字符串
 */
+ (NSAttributedString*)placeholderAttrString:(NSString*)placeholder
{
    return [self placeholderAttrString:placeholder
                                  font:[UIFont systemFontOfSize:17]
                                 color:[ThemeManager sharedThemeManager].textColorGray];
}

+ (NSAttributedString*)placeholderAttrString:(NSString*)placeholder font:(UIFont*)font color:(UIColor*)color
{
    assert(placeholder);
    assert(font);
    assert(color);
    
    return [[NSAttributedString alloc] initWithString:placeholder
                                           attributes:@{NSForegroundColorAttributeName:color,
                                                        NSFontAttributeName:font}];
}


@end
