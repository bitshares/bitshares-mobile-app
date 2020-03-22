//
//  ViewAdvTextFieldCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewAdvTextFieldCell.h"
#import "ViewAutoresizeContailerHor.h"

//#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "MyTextField.h"
#import "NativeMethodExtension.h"
#import "UIImage+Template.h"
#import "OrgUtils.h"

//enum
//{
//    kTailerTagAssetName = 1,
//    kTailerTagSpace,
//    kTailerTagBtnAll
//};

@interface ViewAdvTextFieldCell()
{
    NSInteger _iDecimalPrecision;               //  小数精度：0 - 整数键盘 >0 - 小数键盘(该参数指定小数位数) <0 - 普通键盘
}

@end

@implementation ViewAdvTextFieldCell

- (void)dealloc
{
    _labelTitle = nil;
    _labelValue = nil;
    _helpButton = nil;
    
    if (_mainTextfield){
        _mainTextfield.delegate = nil;
        _mainTextfield = nil;
    }
    
    _formatConditonsView = nil;
}

- (id)initWithTitle:(NSString*)title placeholder:(NSString*)placeholder
{
    return [self initWithTitle:title placeholder:placeholder decimalPrecision:-1];
}

- (id)initWithTitle:(NSString*)title placeholder:(NSString*)placeholder decimalPrecision:(NSInteger)decimalPrecision
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
        
        _iDecimalPrecision = decimalPrecision;
        
        //        assert(tailer);
        
        //  初始化变量
        //        _delegate = nil;
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        //  UI - 标题名
        _labelTitle = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _labelTitle.text = title;
        _labelTitle.textAlignment = NSTextAlignmentLeft;
        
        _labelValue = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _labelValue.textAlignment = NSTextAlignmentRight;
        
        //  UI - 输入框
        _mainTextfield = [[MyTextField alloc] init];
        _mainTextfield.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _mainTextfield.autocorrectionType = UITextAutocorrectionTypeNo;
        _mainTextfield.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        if (_iDecimalPrecision == 0) {
            //  键盘：整数
            _mainTextfield.keyboardType = UIKeyboardTypeNumberPad;
        } else if (_iDecimalPrecision > 0) {
            //  键盘：小数
            _mainTextfield.keyboardType = UIKeyboardTypeDecimalPad;
        } else {
            //  键盘：默认
            _mainTextfield.keyboardType = UIKeyboardTypeDefault;
        }
        _mainTextfield.returnKeyType = UIReturnKeyNext;
        _mainTextfield.delegate = self;//TODO:5.0
        _mainTextfield.placeholder = placeholder;
        _mainTextfield.borderStyle = UITextBorderStyleNone;
        _mainTextfield.clearButtonMode = UITextFieldViewModeWhileEditing;
        _mainTextfield.tintColor = theme.tintColor;
        _mainTextfield.updateClearButtonTintColor = YES;
        _mainTextfield.showBottomLine = YES;
        _mainTextfield.textColor = theme.textColorMain;
        _mainTextfield.attributedPlaceholder = [ViewUtils placeholderAttrString:placeholder];
        
        //  绑定输入事件（限制输入）
        [_mainTextfield addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        
        [self addSubview:_mainTextfield];
        
        //  默认无
        _formatConditonsView = nil;
        _helpButton = nil;
    }
    return self;
}

/*
 *  (public) 在输入框尾部生成资产名称视图。
 */
- (void)genTailerAssetName:(NSString*)asset_name
{
    _mainTextfield.rightView = [[TailerViewAssetAndButtons alloc] initWithHeight:31 asset_name:asset_name];
    _mainTextfield.rightViewMode = UITextFieldViewModeAlways;
}

/*
 *  (public) 在输入框尾部生成资产名称和各种按钮集合的视图。
 */
- (void)genTailerAssetNameAndButtons:(NSString*)asset_name button_names:(NSArray*)button_names target:(id)target action:(SEL)action
{
    _mainTextfield.rightView = [[TailerViewAssetAndButtons alloc] initWithHeight:31
                                                                      asset_name:asset_name
                                                                    button_names:button_names
                                                                          target:target
                                                                          action:action];
    _mainTextfield.rightViewMode = UITextFieldViewModeAlways;
}

/*
 *  (public) 在输入框尾部生成帮助问号的 tailerView。
 */
- (void)genHelpTailerView:(id)target action:(SEL)action tag:(NSInteger)tag
{
    _mainTextfield.rightView = [self _genHelpButtonCore:target action:action tag:tag];
    _mainTextfield.rightViewMode = UITextFieldViewModeAlways;
}

/*
 *  (public) 在 titleValue 后面生成帮助按钮。
 */
- (void)genHelpButton:(id)target action:(SEL)action tag:(NSInteger)tag
{
    if (!_helpButton) {
        _helpButton = [self _genHelpButtonCore:target action:action tag:tag];
        [self addSubview:_helpButton];
    }
}

- (UIButton*)_genHelpButtonCore:(id)target action:(SEL)action tag:(NSInteger)tag
{
    UIButton* btnTips = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
    [btnTips setBackgroundImage:btn_image forState:UIControlStateNormal];
    btnTips.userInteractionEnabled = YES;
    [btnTips addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    btnTips.frame = CGRectMake(0, 0, btn_image.size.width, btn_image.size.height);
    btnTips.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
    btnTips.tag = tag;
    return btnTips;
}

/*
 *  (public) 生成条件视图。
 */
- (void)genFormatConditonsView:(void (^)(ViewFormatConditons* formatConditonsView))config_body
{
    if (!_formatConditonsView) {
        _formatConditonsView = [[ViewFormatConditons alloc] initWithFrame:CGRectZero];
        if (config_body) {
            config_body(_formatConditonsView);
        }
        //  设置默认可见性
        _formatConditonsView.hidden = !_formatConditonsView.isAlwaysShow;
        [self addSubview:_formatConditonsView];
    }
}

/*
 *  (public) 辅助 - 快速生成【钱包密码】格式的条件视图。
 */
- (void)auxFastConditionsViewForWalletPassword
{
    [self genFormatConditonsView:^(ViewFormatConditons *formatConditonsView) {
        [formatConditonsView fastConditionContainsUppercaseLetter:NSLocalizedString(@"kFmtConditioncontainsUpperLetters", @"必须包含大写字母")];
        [formatConditonsView fastConditionContainsLowercaseLetter:NSLocalizedString(@"kFmtConditionContainsLowerLetters", @"必须包含小写字母")];
        [formatConditonsView fastConditionContainsArabicNumerals:NSLocalizedString(@"kFmtConditionContainsDigits", @"必须包含数字")];
        [formatConditonsView addLengthCondition:NSLocalizedString(@"kFmtConditionLen12To40Chars", @"长度12到40个字符")
                                     min_length:12
                                     max_length:40 negative:NO];
    }];
}

/*
 *  (public) 辅助 - 快速生成【账号模式的账号密码】格式的条件视图。
 */
- (void)auxFastConditionsViewForAccountPassword
{
    //  TODO:5.0 是否随机密码？
    [self genFormatConditonsView:^(ViewFormatConditons *formatConditonsView) {
        [formatConditonsView fastConditionContainsUppercaseLetter:NSLocalizedString(@"kFmtConditioncontainsUpperLetters", @"必须包含大写字母")];
        [formatConditonsView fastConditionContainsLowercaseLetter:NSLocalizedString(@"kFmtConditionContainsLowerLetters", @"必须包含小写字母")];
        [formatConditonsView fastConditionContainsArabicNumerals:NSLocalizedString(@"kFmtConditionContainsDigits", @"必须包含数字")];
        [formatConditonsView addLengthCondition:NSLocalizedString(@"kFmtConditionLen32To40Chars", @"长度32到40个字符")
                                     min_length:32 max_length:40 negative:NO];
    }];
}

/*
 *  (public) 辅助 - 快速生成【账号名】格式的条件视图。
 */
- (void)auxFastConditionsViewForAccountNameFormat
{
    [self genFormatConditonsView:^(ViewFormatConditons *formatConditonsView) {
        //  REMARK：注册时的账号名，默认显示。
        formatConditonsView.isAlwaysShow = YES;
        [formatConditonsView addRegularCondition:NSLocalizedString(@"kFmtConditionOnlyContainsLetterDigitAndHyphens", @"由字母、数字或短横线组成")
                                         regular:@"^[A-Za-z0-9\\-]+$"
                                        negative:NO];
        [formatConditonsView fastConditionBeginWithLetter:NSLocalizedString(@"kFmtConditionBeginwithLetters", @"必须以字母开头")];
        [formatConditonsView fastConditionEndWithLetterOrDigit:NSLocalizedString(@"kFmtConditionEndWithLetterOrDigits", @"必须以字母或数字结尾")];
        [formatConditonsView fastConditionContainsArabicNumerals:NSLocalizedString(@"kFmtConditionContainsDigits", @"必须包含数字")];
        [formatConditonsView addLengthCondition:NSLocalizedString(@"kFmtConditionLen3To32Chars", @"长度3到32个字符")
                                     min_length:3 max_length:32 negative:NO];
    }];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    //  未设置一直显示标记，则允许动态切换可见性。
    if (_formatConditonsView && !_formatConditonsView.isAlwaysShow) {
        _formatConditonsView.hidden = YES;
        [UIView performWithoutAnimation:^{
            UITableView* tableView = [ViewUtils findSuperTableView:self];
            [tableView beginUpdates];
            [tableView reloadRowsAtIndexPaths:@[[tableView indexPathForCell:self]] withRowAnimation:UITableViewRowAnimationNone];
            [tableView endUpdates];
        }];
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    //    if (textField == _tfCollateralValue) {
    //        NSDecimalNumber* n_debt = [OrgUtils auxGetStringDecimalNumberValue:_tfDebtValue.text];
    //        if ([n_debt compare:[NSDecimalNumber zero]] <= 0) {
    //            [self resignAllFirstResponder];
    //            [OrgUtils makeToast:NSLocalizedString(@"kDebtTipPleaseInputDebtValueFirst", @"请先输入借款金额。")];
    //            return NO;
    //        }
    //    }
    //  未设置一直显示标记，则允许动态切换可见性。
    if (_formatConditonsView && !_formatConditonsView.isAlwaysShow) {
        _formatConditonsView.hidden = NO;
        [_formatConditonsView onTextDidChange:textField.text];
        [UIView performWithoutAnimation:^{
            UITableView* tableView = [ViewUtils findSuperTableView:self];
            [tableView beginUpdates];
            [tableView reloadRowsAtIndexPaths:@[[tableView indexPathForCell:self]] withRowAnimation:UITableViewRowAnimationNone];
            [tableView endUpdates];
        }];
    }
    return YES;
}

/*
 *  事件 - 输入数量发生变化
 */
- (void)onTextFieldDidChange:(UITextField*)textField
{
    if (_formatConditonsView && !_formatConditonsView.hidden) {
        [_formatConditonsView onTextDidChange:textField.text];
    }
    //  TODO:5.0
    //    //  代理回调
    //    if (_delegate && [_delegate respondsToSelector:@selector(textFieldAmount:onAmountChanged:)]) {
    //        [_delegate textFieldAmount:self onAmountChanged:[OrgUtils auxGetStringDecimalNumberValue:_text_field.text]];
    //    }
    
    //  小于0 - 不限制
    //  等于0 - 用整数键盘限制
    //  大于0 - 限制小数精度
    if (_iDecimalPrecision > 0) {
        //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
        [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
    }
}

//-(void)setDelegate:(id<ViewAdvTextFieldCellDelegate>)delegate
//{
//    _delegate = delegate;
//    _text_field.delegate = delegate;
//}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    //  小于0 - 不限制
    //  等于0 - 用整数键盘限制
    //  大于0 - 限制小数精度
    if (_iDecimalPrecision > 0) {
        return [OrgUtils isValidAmountOrPriceInput:textField.text
                                             range:range
                                        new_string:string
                                         precision:_iDecimalPrecision];
    }
    return YES;
}

- (void)endInput
{
    if (_mainTextfield) {
        [_mainTextfield safeResignFirstResponder];
    }
}

- (CGFloat)cellHeight
{
    CGFloat base = 28.0f + 44.0f;
    if (_formatConditonsView) {
        base += _formatConditonsView.cellHeight;
    }
    return base;
}

- (BOOL)isAllConditionsMatched
{
    if (!_formatConditonsView) {
        return NO;
    }
    return _formatConditonsView.isAllConditionsMatched;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    //  header
    CGFloat fOffsetY = 0.0f;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fWidth = self.bounds.size.width - 2 * fOffsetX;
    CGFloat fLineHeight = 28.0f;
    
    _labelTitle.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    if (_helpButton) {
        //  包含 value 和 help button
        CGSize origin_size = _helpButton.bounds.size;
        _helpButton.frame = CGRectMake(self.bounds.size.width - fOffsetX - origin_size.width,
                                       (fLineHeight - origin_size.height) / 2, origin_size.width, origin_size.height);
        _labelValue.frame = CGRectMake(fOffsetX, fOffsetY, fWidth - origin_size.width - 4.0f, fLineHeight);
    } else {
        //  仅包含 value
        _labelValue.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    }
    fOffsetY += fLineHeight;
    
    CGFloat old_height = 31;
    _mainTextfield.frame = CGRectMake(fOffsetX, fOffsetY + (44 - old_height) / 2.0f, fWidth, old_height);
    fOffsetY += 44.0f;
    
    if (_formatConditonsView) {
        [_formatConditonsView resizeFrame:fOffsetX offsetY:fOffsetY width:fWidth];
    }
}

@end
