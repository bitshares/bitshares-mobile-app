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

@end
