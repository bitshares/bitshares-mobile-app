//
//  ViewTextFieldAmountCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewTextFieldAmountCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "MyTextField.h"
#import "OrgUtils.h"

enum
{
    kTailerTagAssetName = 1,
    kTailerTagSpace,
    kTailerTagBtnAll
};

@interface ViewTextFieldAmountCell()
{
    UILabel*        _lbTitleName;
    UILabel*        _lbTitleValue;      //  默认不可见（draw之后可见）
    MyTextField*    _text_field;
}

@end

@implementation ViewTextFieldAmountCell

- (void)dealloc
{
    _lbTitleName = nil;
    _lbTitleValue = nil;
    
    if (_text_field){
        _text_field.delegate = nil;
        _text_field = nil;
    }
    
    _delegate = nil;
}

- (id)initWithTitle:(NSString*)title placeholder:(NSString*)placeholder tailer:(NSString*)tailer
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        assert(title);
        assert(placeholder);
        assert(tailer);
        
        //  初始化变量
        _delegate = nil;
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        //  UI - 标题名
        _lbTitleName = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbTitleName.text = title;
        
        _lbTitleValue = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbTitleValue.textAlignment = NSTextAlignmentRight;
        _lbTitleValue.hidden = YES;
        
        //  UI - 输入框
        _text_field = [[MyTextField alloc] init];
        _text_field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _text_field.autocorrectionType = UITextAutocorrectionTypeNo;
        _text_field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        _text_field.keyboardType = UIKeyboardTypeDecimalPad;
        _text_field.returnKeyType = UIReturnKeyNext;
        _text_field.delegate = nil;
        _text_field.placeholder = placeholder;
        _text_field.borderStyle = UITextBorderStyleNone;
        _text_field.clearButtonMode = UITextFieldViewModeWhileEditing;
        _text_field.tintColor = theme.tintColor;
        _text_field.updateClearButtonTintColor = YES;
        _text_field.showBottomLine = YES;
        _text_field.textColor = theme.textColorMain;
        _text_field.attributedPlaceholder = [ViewUtils placeholderAttrString:placeholder];
        
        //  绑定输入事件（限制输入）
        [_text_field addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        _text_field.rightView = [self genTailerView:tailer action:NSLocalizedString(@"kLabelSendAll", @"全部")];
        _text_field.rightViewMode = UITextFieldViewModeAlways;
        
        [self addSubview:_text_field];
    }
    return self;
}

- (void)_resetTailerViewFrame:(UILabel*)lbAsset space:(UILabel*)lbSpace btn:(UIButton*)btn tailer_view:(UIView*)tailer_view
{
    CGFloat fHeight = 31.0f;
    CGFloat fSpace = 12.0f;
    
    CGSize size1 = [ViewUtils auxSizeWithLabel:btn.titleLabel];
    CGSize size2 = [ViewUtils auxSizeWithLabel:lbSpace];
    CGSize size3 = [ViewUtils auxSizeWithLabel:lbAsset];
    
    CGFloat fWidth = size1.width + size2.width + size3.width + fSpace * 3;
    
    tailer_view.frame = CGRectMake(0, 0, fWidth, fHeight);
    lbAsset.frame = CGRectMake(fSpace * 1, 0, size3.width, fHeight);
    lbSpace.frame = CGRectMake(fSpace * 2 + size3.width, 0, size2.width, fHeight);
    btn.frame = CGRectMake(fSpace * 3 + size3.width + size2.width, 0, size1.width, fHeight);
}

- (UIView*)genTailerView:(NSString*)asset_symbol action:(NSString*)action
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UIView* tailer_view = [[UIView alloc] initWithFrame:CGRectZero];
    
    UILabel* lbAsset = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:13] superview:tailer_view];
    UILabel* lbSpace = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:tailer_view];
    lbAsset.text = asset_symbol;
    lbSpace.text = @"|";
    lbAsset.textColor = theme.textColorMain;
    lbSpace.textColor = theme.textColorGray;
    lbAsset.textAlignment = NSTextAlignmentRight;
    
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn setTitle:action forState:UIControlStateNormal];
    [btn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onButtonTailerClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    
    //  设置TAG
    lbAsset.tag = kTailerTagAssetName;
    lbSpace.tag = kTailerTagSpace;
    btn.tag = kTailerTagBtnAll;
    
    //  设置 frame
    [self _resetTailerViewFrame:lbAsset space:lbSpace btn:btn tailer_view:tailer_view];
    
    [tailer_view addSubview:lbAsset];
    [tailer_view addSubview:lbSpace];
    [tailer_view addSubview:btn];
    
    return tailer_view;
}

/*
 *  事件 - 全部 按钮点击
 */
- (void)onButtonTailerClicked:(UIButton*)sender
{
    //  代理回调
    if (_delegate && [_delegate respondsToSelector:@selector(textFieldAmount:onTailerClicked:)]) {
        [_delegate textFieldAmount:self onTailerClicked:sender];
    }
}

/*
 *  事件 - 输入数量发生变化
 */
- (void)onTextFieldDidChange:(UITextField*)textField
{
    //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
    [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
    //  代理回调
    if (_delegate && [_delegate respondsToSelector:@selector(textFieldAmount:onAmountChanged:)]) {
        [_delegate textFieldAmount:self onAmountChanged:[OrgUtils auxGetStringDecimalNumberValue:_text_field.text]];
    }
}

-(void)setDelegate:(id<ViewTextFieldAmountCellDelegate>)delegate
{
    _delegate = delegate;
    _text_field.delegate = delegate;
}

- (void)endInput
{
    if (_text_field) {
        [_text_field safeResignFirstResponder];
    }
}

- (NSString*)getInputTextValue
{
    return _text_field.text;
}

- (void)setInputTextValue:(NSString*)newValue
{
    _text_field.text = newValue ?: @"";
}

- (void)clearInputTextValue
{
    _text_field.text = @"";
}

- (void)drawUI_newTailer:(NSString*)text
{
    UILabel* lbAsset = nil;
    UILabel* lbSpace = nil;
    UIButton* btn = nil;
    for (UIView* view in _text_field.rightView.subviews) {
        switch (view.tag) {
            case kTailerTagAssetName:
                lbAsset = (UILabel*)view;
                lbAsset.text = text;
                break;
            case kTailerTagSpace:
                lbSpace = (UILabel*)view;
                break;
            case kTailerTagBtnAll:
                btn = (UIButton*)view;
                break;
            default:
                break;
        }
        if (lbAsset && lbSpace && btn) {
            [self _resetTailerViewFrame:lbAsset space:lbSpace btn:btn tailer_view:lbAsset.superview];
            break;
        }
    }
}

- (void)drawUI_titleValue:(NSString*)text color:(UIColor*)color
{
    if (text && color) {
        _lbTitleValue.text = text;
        _lbTitleValue.textColor = color;
        _lbTitleValue.hidden = NO;
    } else {
        _lbTitleValue.hidden = YES;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    //  header
    CGFloat fOffsetY = 0.0f;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fWidth = self.bounds.size.width - 2 * fOffsetX;
    CGFloat fLineHeight = 28.0f;
    
    _lbTitleName.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    _lbTitleValue.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    fOffsetY += fLineHeight;
    
    CGFloat old_height = 31;
    _text_field.frame = CGRectMake(fOffsetX, fOffsetY + (44 - old_height) / 2.0f, fWidth, old_height);
}

@end
