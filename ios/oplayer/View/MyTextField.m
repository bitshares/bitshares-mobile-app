//
//  MyTextField.m
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import "MyTextField.h"
#import "ThemeManager.h"

@interface MyTextField()
{
    UIView*     _pBottomLine;
}

@end

@implementation MyTextField

@synthesize showBottomLine;
@synthesize updateClearButtonTintColor;

- (void)dealloc
{
    _pBottomLine = nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.showBottomLine = NO;
        self.updateClearButtonTintColor = NO;
        _pBottomLine = nil;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.showBottomLine){
        if (!_pBottomLine){
            _pBottomLine = [[UIView alloc] initWithFrame:CGRectZero];
            _pBottomLine.backgroundColor = [ThemeManager sharedThemeManager].textColorGray;
            [self addSubview:_pBottomLine];
        }
        CGRect tfFrame = self.frame;
        _pBottomLine.frame = CGRectMake(0, tfFrame.size.height - 0.5, tfFrame.size.width, 0.5);
    }else{
        if (_pBottomLine){
            if (_pBottomLine.superview){
                [_pBottomLine removeFromSuperview];
            }
            _pBottomLine = nil;
        }
    }
    
    //  why clear button is not same as UITextField??
    if (self.updateClearButtonTintColor){
        for (UIView* subView in self.subviews) {
            if ([subView isKindOfClass:[UIButton class]]) {
                UIButton* button = (UIButton*)subView;
                UIImage* image = [button imageForState:UIControlStateNormal];
                if (image){
                    UIImage* template = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                    [button setImage:template forState:UIControlStateNormal];
                    button.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
                }
            }
        }
    }
}

@end
