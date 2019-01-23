//
//  UITableViewBase.m
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import "UITableViewBase.h"

@implementation UITableViewBase

@synthesize hideAllLines;

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self) {
        // Initialization code
        self.hideAllLines = NO;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    //  隐藏多余的短横线
    if (self.style == UITableViewStylePlain && self.hideAllLines){
        Class klass = NSClassFromString(@"_UITableViewCellSeparatorView");  //  REMARK：分割线的class
        if (klass){
            for (UIView* v1 in self.subviews) {
                if ([v1 isKindOfClass:klass]){
                    v1.hidden = YES;
                    continue;
                }
            }
        }
    }
}

@end
