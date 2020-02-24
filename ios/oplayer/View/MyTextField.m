//
//  MyTextField.m
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import "MyTextField.h"
#import "ThemeManager.h"

#import "ViewUtils.h"
#import "UIImage+Template.h"

@interface MyTextField()
{
    UIImage*    _imageClearButtonHighlighted;   //  clearButton 两种状态下的图片对象
    UIImage*    _imageClearButtonNormal;
    
    UILabel*    _pLeftTitleView;
    UIView*     _pBottomLine;
}

@end

@implementation MyTextField

@synthesize showRectBorder;
@synthesize showBottomLine;
@synthesize updateClearButtonTintColor;

- (void)dealloc
{
    _imageClearButtonNormal = nil;
    _imageClearButtonHighlighted = nil;
    _colorClearButtonNormal = nil;
    _colorClearButtonHighlighted = nil;
    
    _pLeftTitleView = nil;
    _pBottomLine = nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _imageClearButtonNormal = nil;
        _imageClearButtonHighlighted = nil;
        _colorClearButtonNormal = nil;
        _colorClearButtonHighlighted = nil;
        
        self.showRectBorder = NO;
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
    
    //  [兼容性] iOS13 会直接重置 label 的 frame 大小。这里套一层外部 view。
    UIView* wrapperView = [[UIView alloc] initWithFrame:frame];
    if (_pLeftTitleView.superview) {
        [_pLeftTitleView removeFromSuperview];
    }
    [wrapperView addSubview:_pLeftTitleView];
    
    self.leftView = wrapperView;
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
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    if (self.showBottomLine){
        if (!_pBottomLine){
            _pBottomLine = [[UIView alloc] initWithFrame:CGRectZero];
            [self addSubview:_pBottomLine];
        }
        CGRect tfFrame = self.frame;
        if (self.isFirstResponder){
            _pBottomLine.frame = CGRectMake(0, tfFrame.size.height - 1, tfFrame.size.width, 1);
            _pBottomLine.backgroundColor = theme.textColorHighlight;
        }else{
            _pBottomLine.frame = CGRectMake(0, tfFrame.size.height - 0.5, tfFrame.size.width, 0.5);
            _pBottomLine.backgroundColor = theme.textColorGray;
        }
    }else{
        if (_pBottomLine){
            if (_pBottomLine.superview){
                [_pBottomLine removeFromSuperview];
            }
            _pBottomLine = nil;
        }
    }
    
    //  显示边框
    if (self.showRectBorder) {
        if (self.isFirstResponder) {
            self.layer.borderColor = [theme.textColorHighlight CGColor];
        } else {
            self.layer.borderColor = [theme.textColorGray CGColor];
        }
        self.layer.borderWidth = 1.0f;
        self.layer.cornerRadius = 0;
        self.layer.masksToBounds = NO;
    }
    
    //  兼容 - 之前的版本用的该属性设置颜色，默认转换为以下两个属性。
    if (self.updateClearButtonTintColor){
        _colorClearButtonNormal = theme.textColorHighlight;
        _colorClearButtonHighlighted = theme.textColorHighlight;
    }
    
    //  5.0 - 刷新 clearButton 颜色。
    [self refreshClearButtonColor];
}

/*
 *  重载 - 占位符文字矩形
 */
- (CGRect)textRectForBounds:(CGRect)bounds {
    if (self.showRectBorder) {
        CGRect rect = [super textRectForBounds:bounds];
        rect.origin.x += 8;
        rect.size.width -= 8;
        if (self.rightViewMode == UITextFieldViewModeAlways) {
            rect.size.width -= 8;
        }
        return rect;
    } else {
        return [super textRectForBounds:bounds];
    }
}

/*
 *  重载 - 编辑中文字矩形
 */
- (CGRect)editingRectForBounds:(CGRect)bounds {
    if (self.showRectBorder) {
        CGRect rect = [super editingRectForBounds:bounds];
        rect.origin.x += 8;
        rect.size.width -= 8;
        if (self.rightViewMode == UITextFieldViewModeAlways) {
            rect.size.width -= 8;
        }
        return rect;
    } else {
        return [super editingRectForBounds:bounds];
    }
}

- (CGRect)rightViewRectForBounds:(CGRect)bounds {
    CGRect rect = [super rightViewRectForBounds:bounds];
    if (self.showRectBorder) {
        rect.origin.x -= 8;
    }
    return rect;
}

/*
 *  (private) 辅助 - 从子view中查找 clearButton 对象。
 */
-(UIButton*)findClearButton
{
    Class buttonKlass = [UIButton class];
    for (UIView* subView in self.subviews) {
        //  REMARK：是否是 UIButton 子类实例判断，不能是 UIButton 实例。clearButton 是 _UITextFieldClearButton 类实例。
        if ([subView isKindOfClass:buttonKlass] && ![subView isMemberOfClass:buttonKlass]) {
            UIButton* button = (UIButton*)subView;
            NSString* txt = button.titleLabel.text;
            //  REMARK：过滤掉 tailer 上的其他 BUTTON。可以考虑判断 _UITextFieldClearButton。
            if (!txt || [txt isEqualToString:@""]) {
                return button;
            }
        }
    }
    return nil;
}

/*
 *  (private) 刷新 clearButton 颜色
 */
- (void)refreshClearButtonColor
{
    UIButton* clearButton = [self findClearButton];
    if (!clearButton) {
        return;
    }
    
    //  更新普通状态图片
    if (_colorClearButtonNormal && !_imageClearButtonNormal) {
        _imageClearButtonNormal = [UIImage templateImageNamed:@"iconClear"];
        [clearButton setImage:_imageClearButtonNormal forState:UIControlStateNormal];
        clearButton.tintColor = _colorClearButtonNormal;
    }
    
    //  更新高亮状态图片
    if (_colorClearButtonHighlighted && !_imageClearButtonHighlighted) {
        _imageClearButtonHighlighted = [UIImage templateImageNamed:@"iconClear"];
        [clearButton setImage:_imageClearButtonHighlighted forState:UIControlStateHighlighted];
        clearButton.tintColor = _colorClearButtonHighlighted;
    }
}

@end
