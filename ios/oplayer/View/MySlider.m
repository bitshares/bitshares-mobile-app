//
//  MySlider.m
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import "MySlider.h"

#import "UIImage+Template.h"
#import "ThemeManager.h"

@implementation MySlider

- (id)init
{
    self = [super init];
    if (self) {
        //  TODO:5.0 默认高度
        _customProgressBarHeight = 2.0f;
        UIImage* thumbImage = [UIImage templateImageNamed:@"iconSlider"];
        [self setThumbImage:thumbImage forState:UIControlStateNormal];
        [self setThumbImage:thumbImage forState:UIControlStateHighlighted];
    }
    return self;
}

/*
 *  (private) 重载 - 设置进度条高度
 */
- (CGRect)trackRectForBounds:(CGRect)bounds
{
    bounds = [super trackRectForBounds:bounds];
    if (_customProgressBarHeight > 0) {
        return CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, _customProgressBarHeight);
    }
    return bounds;
}

/*
 *  (private) 重载 - 设置滑块触摸范围
 */
- (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value
{
    bounds = [super thumbRectForBounds:bounds trackRect:rect value:value];
    CGFloat fExtraBorderWidth = 0;// 40.0f; TODO:5.0
    if (fExtraBorderWidth > 0) {
        return CGRectMake(bounds.origin.x - fExtraBorderWidth, bounds.origin.y - fExtraBorderWidth,
                          bounds.size.width + fExtraBorderWidth * 2, bounds.size.height + fExtraBorderWidth * 2);
    } else {
        return bounds;
    }
}

@end
