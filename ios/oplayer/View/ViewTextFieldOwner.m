//
//  ViewTextFieldOwner.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "ViewTextFieldOwner.h"
#import "AppCommon.h"

@interface ViewTextFieldOwner()
{
    //  REMARK：textfield后面的尾巴长度
    NSInteger subviewTailerWidth;
}

@end

@implementation ViewTextFieldOwner

- (void)dealloc
{
    //  REMARK：在回收cell之前，先把cell内到textfield移除掉。不然textfield的superview可能有野指针，导致添加到其他view内部会导致重复remove的问题。
    for (UIView* view in self.contentView.subviews) {
        if ([view isKindOfClass:[UITextField class]])
        {
            [view removeFromSuperview];
            break;
        }
    }
}

- (void)addToContentView:(UIView *)view
{
    subviewTailerWidth = [[UIScreen mainScreen] bounds].size.width * kAppTextFieldWidthFactor - view.bounds.size.width;
    if (view.superview){
        [view removeFromSuperview];
    }
    [self.contentView addSubview:view];
}

- (NSInteger)calcTextFieldLeftX
{
    return subviewTailerWidth;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    for (UIView* view in self.contentView.subviews) {
        if ([view isKindOfClass:[UITextField class]])
        {
            UITextField* tf = (UITextField*)view;
            CGFloat fLeftX  = self.accessoryView.frame.origin.x + self.accessoryView.frame.size.width - (tf.bounds.size.width + [self calcTextFieldLeftX]);
            CGFloat fTopY   = (self.bounds.size.height - tf.bounds.size.height) / 2.0f;
            tf.frame = CGRectMake(fLeftX, fTopY, tf.bounds.size.width, tf.bounds.size.height);
            break;
        }
    }
}

@end
