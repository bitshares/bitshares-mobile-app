//
//  ViewRightTextAndCellButton.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "ViewRightTextAndCellButton.h"

@interface ViewRightTextAndCellButton()
{    
}

@end

@implementation ViewRightTextAndCellButton

@synthesize disableDelayTouch;

- (void)addSubview:(UIView *)view
{
    if (view.superview){
        [view removeFromSuperview];
    }
    [super addSubview:view];
}

- (void)closeDelayTouches
{
    UIView* view = self.contentView;
    if (view){
        if ([view respondsToSelector:@selector(setDelaysContentTouches:)]){
            [view performSelector:@selector(setDelaysContentTouches:) withObject:NO];
        }
    }
    while (view.superview){
        if ([view respondsToSelector:@selector(setDelaysContentTouches:)]){
            [view performSelector:@selector(setDelaysContentTouches:) withObject:NO];
        }
        if ([view isKindOfClass:[UITableView class]]){
            break;
        }
        view = view.superview;
    }
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.disableDelayTouch){
        [self closeDelayTouches];
    }
    
    UILabel* label = nil;
    UIButton* button = nil;
    for (UIView* view in self.contentView.subviews)
    {
        if (!label && [view isKindOfClass:[UILabel class]] && view.tag == 0xdead)
        {
            label = (UILabel*)view;
        }
        else if (!button && [view isKindOfClass:[UIButton class]])
        {
            button = (UIButton*)view;
        }
    }
    if (!label || !button){
        return;
    }
    
    CGRect fLable = label.frame;
    CGRect fButton = button.frame;
    
    CGFloat w = self.detailTextLabel.frame.origin.x + self.detailTextLabel.frame.size.width;
    
    label.frame = CGRectMake(w - fLable.size.width - fButton.size.width, fLable.origin.y, fLable.size.width, fLable.size.height);
    
    button.frame = CGRectMake(w - fButton.size.width, fButton.origin.y, fButton.size.width, fButton.size.height);
}

@end
