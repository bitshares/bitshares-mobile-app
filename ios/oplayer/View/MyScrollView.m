//
//  MyScrollView.m
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import "MyScrollView.h"

#import "ThemeManager.h"

@implementation MyScrollView

- (id)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

/*
 *  重载 - 禁止在 UISlider 上滑动。
 */
-(BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch:(UITouch*)touch
{
    if ([touch.view isKindOfClass:[UISlider class]]) {
        return NO;
    }
    return YES;
}

@end
