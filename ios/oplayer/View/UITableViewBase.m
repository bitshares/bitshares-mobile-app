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

/**
 *  (public) 在CELL的附加View上关联输入框。（自动适配输入框宽度）
 */
- (void)attachTextfieldToCell:(UITableViewCell*)cell tf:(UITextField*)tf
{
    assert(cell && tf);
    CGFloat old_height = tf.bounds.size.height;
    CGFloat xOffset = self.layoutMargins.left;
    tf.frame = CGRectMake(xOffset, 0, self.bounds.size.width - 2 * xOffset, old_height);
    cell.accessoryView = tf;
}

@end
