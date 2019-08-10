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
    UILabel*    _pLeftTitleView;
    UIView*     _pBottomLine;
}

@end

@implementation MyTextField

@synthesize showBottomLine;
@synthesize updateClearButtonTintColor;

- (void)dealloc
{
    _pLeftTitleView = nil;
    _pBottomLine = nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.showBottomLine = NO;
        self.updateClearButtonTintColor = NO;
        _pLeftTitleView = nil;
        _pBottomLine = nil;
    }
    return self;
}

- (void)setLeftTitleView:(NSString*)title frame:(CGRect)frame
{
    if (!_pLeftTitleView){
        _pLeftTitleView = [[UILabel alloc] initWithFrame:frame];
        _pLeftTitleView.lineBreakMode = NSLineBreakByTruncatingTail;
        _pLeftTitleView.numberOfLines = 1;
        _pLeftTitleView.textAlignment = NSTextAlignmentLeft;
        _pLeftTitleView.backgroundColor = [UIColor clearColor];
        _pLeftTitleView.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _pLeftTitleView.font = [UIFont systemFontOfSize:16];
    }
    _pLeftTitleView.text = title;
    self.leftView = _pLeftTitleView;
    self.leftViewMode = UITextFieldViewModeAlways;
}

- (void)setLeftTitleView:(NSString*)title
{
    if (_pLeftTitleView){
        _pLeftTitleView.text = title;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.showBottomLine){
        if (!_pBottomLine){
            _pBottomLine = [[UIView alloc] initWithFrame:CGRectZero];
            [self addSubview:_pBottomLine];
        }
        CGRect tfFrame = self.frame;
        if (self.isFirstResponder){
            _pBottomLine.frame = CGRectMake(0, tfFrame.size.height - 1, tfFrame.size.width, 1);
            _pBottomLine.backgroundColor = [ThemeManager sharedThemeManager].textColorHighlight;
        }else{
            _pBottomLine.frame = CGRectMake(0, tfFrame.size.height - 0.5, tfFrame.size.width, 0.5);
            _pBottomLine.backgroundColor = [ThemeManager sharedThemeManager].textColorGray;
        }
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
