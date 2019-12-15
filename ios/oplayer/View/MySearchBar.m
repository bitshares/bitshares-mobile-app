//
//  MySearchBar.m
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import "MySearchBar.h"
#import "ThemeManager.h"
#import "ViewUtils.h"

@interface MySearchBar()
{
    UIView*     _pLine;
    BOOL        _tfColorInited;
}

@end

@implementation MySearchBar

- (void)dealloc
{
    _pLine = nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _pLine = [[UIView alloc] initWithFrame:CGRectZero];
        _pLine.backgroundColor = [ThemeManager sharedThemeManager].textColorGray;
        _tfColorInited = NO;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    UITextField* tfSearchBar = [self valueForKey:@"searchField"];
    if (tfSearchBar){
        //  初始化输入框的下划线
        CGRect tfFrame = tfSearchBar.frame;
        if (!_pLine.superview){
            [tfSearchBar addSubview:_pLine];
        }
        _pLine.frame = CGRectMake(0, tfFrame.size.height - 0.5, tfFrame.size.width, 0.5);
        //  仅初始化一次。
        if (!_tfColorInited){
            _tfColorInited = YES;
            tfSearchBar.backgroundColor = [UIColor clearColor];
            tfSearchBar.textColor = [ThemeManager sharedThemeManager].textColorMain;
            tfSearchBar.attributedPlaceholder = [ViewUtils placeholderAttrString:tfSearchBar.placeholder];
        }
    }
}

@end
