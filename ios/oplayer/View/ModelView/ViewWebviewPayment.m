//
//  ViewWebviewPayment.m
//  ViewWebviewPayment
//

#import "ViewWebviewPayment.h"
#import "UITableViewCellBase.h"
#import "MyTextField.h"

@interface ViewWebviewPayment()
{
    CGRect          _rectNaviIn;
    CGRect          _rectNaviOut;
    
    UIView*         _safeNaviBar;
    UILabel*        _lbReserveSecureText;
    UILabel*        _lbSafeTips;
    
    UIView*         _viewPasswordDialog;
    MyTextField*    _tf_password;
}

@end

@implementation ViewWebviewPayment

- (void)dealloc
{
    if (_tf_password){
        _tf_password.delegate = nil;
        _tf_password = nil;
    }
    _viewPasswordDialog = nil;
    
    _lbReserveSecureText = nil;
    _safeNaviBar = nil;
    _lbSafeTips = nil;
}

- (instancetype)init
{
    if (self = [super init])
    {
        self.cancelable = YES;
        _safeNaviBar = nil;
        _lbReserveSecureText = nil;
        _lbSafeTips = nil;
        _viewPasswordDialog = nil;
        _tf_password = nil;
    }
    return self;
}

- (UIView*)genMainPasswordDialog:(CGRect)main_rect
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat fWidth = main_rect.size.width * 0.7f;   //  主对话框宽度
    CGFloat fTitleHeight = 38.0f;                   //  标题栏高度
    CGFloat fLineHeight = 28.0f;                    //  文字行高
    CGFloat fTextFieldHeight = 35.0f;               //  输入框高度
    CGFloat fTextFieldBorder = 2.0f;                //  输入框上下边框高度
    CGFloat fMainButtonHeight = 38.0f;              //  主按钮高度
    
    UIView* dialog = [[UIView alloc] init];
    
    //  UI - 标题栏
    UIView* frame_bg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, fWidth, fTitleHeight)];
    frame_bg.backgroundColor = theme.textColorHighlight;
    [dialog addSubview:frame_bg];
    
    //  UI - 标题栏左边关闭按钮
    UIButton* btn_close = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn_close setTitle:@"×" forState:UIControlStateNormal];
    [btn_close setTitleColor:theme.textColorMain forState:UIControlStateNormal];
    btn_close.titleLabel.font = [UIFont boldSystemFontOfSize:28.0f];
    btn_close.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    btn_close.titleLabel.textAlignment = NSTextAlignmentCenter;
    btn_close.titleLabel.numberOfLines = 0;
    [btn_close.titleLabel sizeToFit];
    btn_close.userInteractionEnabled = YES;
    [btn_close addTarget:self action:@selector(onCloseButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn_close.backgroundColor = [UIColor clearColor];
    [frame_bg addSubview:btn_close];
    
    //  UI - 标题栏中间标题文字
    UILabel* title = [self auxGenLabel:[UIFont boldSystemFontOfSize:16] superview:dialog];
    
    //  UI - 第二行支付内容描述文字
    UILabel* desc = [self auxGenLabel:[UIFont systemFontOfSize:16] superview:dialog];
    
    //  UI - 第三行支付价格
    UILabel* price = [self auxGenLabel:[UIFont boldSystemFontOfSize:28] superview:dialog];
    
    //  UI - 第三行密码输入框
    MyTextField* _tf_password = [[MyTextField alloc] init];
    NSString* placeholder = @"请输入钱包密码";
    _tf_password.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _tf_password.autocorrectionType = UITextAutocorrectionTypeNo;
    _tf_password.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _tf_password.keyboardType = UIKeyboardTypeDefault;
    _tf_password.returnKeyType = UIReturnKeyDone;
    _tf_password.delegate = self;
    _tf_password.placeholder = placeholder;
    _tf_password.borderStyle = UITextBorderStyleNone;
    _tf_password.clearButtonMode = UITextFieldViewModeWhileEditing;
    _tf_password.secureTextEntry = YES;
    _tf_password.textColor = theme.textColorMain;
    _tf_password.tintColor = theme.tintColor;
    _tf_password.backgroundColor = [UIColor clearColor];
    _tf_password.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _tf_password.autocorrectionType = UITextAutocorrectionTypeNo;
    _tf_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder
                                                                         attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
                                                                                      NSFontAttributeName:[UIFont systemFontOfSize:14]}];
    UIView* tf_border = [[UIView alloc] init];
    tf_border.layer.borderWidth = 0.5f;
    tf_border.layer.cornerRadius = 3.0f;
    tf_border.layer.borderColor = theme.textColorNormal.CGColor;
    [tf_border addSubview:_tf_password];
    [dialog addSubview:tf_border];
    
    //  UI - 第五行 确定按钮
    UIColor* textColor = theme.textColorMain;
    UIColor* backColor = theme.textColorHighlight;
    UIButton* btn_ok = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn_ok setTitle:NSLocalizedString(@"kBtnOK", @"确定") forState:UIControlStateNormal];
    [btn_ok setTitleColor:textColor forState:UIControlStateNormal];
    btn_ok.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    btn_ok.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    btn_ok.titleLabel.textAlignment = NSTextAlignmentCenter;
    btn_ok.titleLabel.numberOfLines = 0;
    [btn_ok.titleLabel sizeToFit];
    btn_ok.layer.borderWidth = 1;
    btn_ok.layer.borderColor = backColor.CGColor;
    btn_ok.layer.cornerRadius = 3.0f;
    btn_ok.layer.masksToBounds = YES;
    btn_ok.layer.backgroundColor = backColor.CGColor;
    btn_ok.userInteractionEnabled = YES;
    [btn_ok addTarget:self action:@selector(onDoneButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [dialog addSubview:btn_ok];
    
    //  TODO:多语言
    title.text = @"支付";
    desc.text = @"论坛打赏 abc";
    price.text = @"19999 CNVOTE";
    price.textColor = theme.buyColor;
    price.adjustsFontSizeToFitWidth = YES;
    
    //  设置各种 frame
    CGFloat fBorderOffset = 11.0f;
    CGFloat fContentWidth = fWidth - fBorderOffset * 2.0f;
    CGFloat fOffset = fBorderOffset;
    
    CGSize maxSize = CGSizeMake(fContentWidth, 9999);
    CGSize tmp = [ViewUtils auxSizeWithLabel:btn_close.titleLabel maxsize:maxSize];
    btn_close.frame = CGRectMake(0, 0, fBorderOffset * 2 + tmp.width, fTitleHeight);
    
    tmp = [ViewUtils auxSizeWithLabel:title maxsize:maxSize];
    title.frame = CGRectMake(fBorderOffset, (fTitleHeight - tmp.height) / 2.0f,
                             fContentWidth, tmp.height);
    fOffset += fTitleHeight;
    
    tmp = [ViewUtils auxSizeWithLabel:desc maxsize:maxSize];
    desc.frame = CGRectMake(fBorderOffset, fOffset + (fLineHeight - tmp.height) / 2.0f, fContentWidth, tmp.height);
    fOffset += fLineHeight;
    
    tmp = [ViewUtils auxSizeWithLabel:price maxsize:maxSize];
    price.frame = CGRectMake(fBorderOffset, fOffset + (fLineHeight * 2 - tmp.height) / 2.0f, fContentWidth, tmp.height);
    fOffset += fLineHeight * 2;
    
    tf_border.frame = CGRectMake(fBorderOffset, fOffset, fContentWidth, fTextFieldHeight);
    _tf_password.frame = CGRectMake(6, fTextFieldBorder, fContentWidth - 12.0f, fTextFieldHeight - fTextFieldBorder * 2);
    fOffset += fTextFieldHeight + fBorderOffset * 2;
    
    btn_ok.frame = CGRectMake(fBorderOffset, fOffset, fContentWidth, fMainButtonHeight);
    fOffset += fMainButtonHeight + fBorderOffset;
    
    //  UI - 最终输入框圆角等属性
    dialog.frame = CGRectMake((main_rect.size.width - fWidth) / 2.0f,
                              (main_rect.size.height - fOffset) * 2.0f / 5.0f, fWidth, fOffset);
    dialog.layer.backgroundColor = theme.appBackColor.CGColor;
    dialog.layer.cornerRadius = 6.0f;
    dialog.layer.borderWidth = 0.5f;
    dialog.layer.borderColor = theme.tabBarColor.CGColor;
    dialog.clipsToBounds = YES;
    
    return dialog;
}

- (void)setupSubViews
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGRect rect = [UIScreen mainScreen].bounds;
    
    CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat fWidth = rect.size.width;
    CGFloat fNaviHeight = 44 + statusBarHeight;
    _rectNaviIn = CGRectMake(0, 0, fWidth, fNaviHeight);
    _rectNaviOut = CGRectMake(0, -fNaviHeight, fWidth, fNaviHeight);
    
    _safeNaviBar = [[UIView alloc] init];
    _safeNaviBar.backgroundColor = theme.textColorHighlight;
    [self addSubview:_safeNaviBar];
    
    _lbReserveSecureText = [self auxGenLabel:[UIFont boldSystemFontOfSize:14] superview:_safeNaviBar];
    _lbReserveSecureText.attributedText = [ViewUtils genAndColorAttributedText:@"您的预留信息 "
                                                                         value:@"佛系持币～"
                                                                    titleColor:theme.textColorMain
                                                                    valueColor:theme.buyColor];
    _lbReserveSecureText.frame = CGRectMake(0, statusBarHeight + 2, rect.size.width, 20.0f);
    
    _lbSafeTips = [self auxGenLabel:[UIFont systemFontOfSize:12.0f] superview:_safeNaviBar];
    _lbSafeTips.frame = CGRectMake(0, statusBarHeight + 22, rect.size.width, 18.0f);
    _lbSafeTips.text = @"安全提示：如果预留信息和您设置的不同，请立即停止支付！";
    _lbSafeTips.textColor = theme.textColorMain;
    
    _viewPasswordDialog = [self genMainPasswordDialog:rect];
    [self addSubview:_viewPasswordDialog];
}

- (void)setupAnimationBeginPosition:(BOOL)bSlideIn
{
    if (bSlideIn) {
        _safeNaviBar.frame = _rectNaviOut;
        _viewPasswordDialog.alpha = 0.0f;
    } else {
        _safeNaviBar.frame = _rectNaviIn;
        _viewPasswordDialog.alpha = 1.0f;
    }
}

- (void)setupAnimationEndPosition:(BOOL)bSlideIn
{
    if (bSlideIn) {
        _safeNaviBar.frame = _rectNaviIn;
        _viewPasswordDialog.alpha = 1.0f;
    } else {
        _safeNaviBar.frame = _rectNaviOut;
        _viewPasswordDialog.alpha = 0.0f;
    }
}

- (void)onOutsideClicked
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
    [self endEditing:YES];
    if (_tf_password) {
        [_tf_password safeResignFirstResponder];
    }
}

- (void)onCloseButtonClicked:(UIButton*)sender
{
    [self resignAllFirstResponder];
    [self dismissWithCompletion:nil];
}

- (void)onDoneButtonClicked:(UIButton*)sender
{
    [self onSubmitClicked];
}

- (void)onSubmitClicked
{
    //  TODO:2.9
    [self resignAllFirstResponder];
    [self dismissWithCompletion:nil];
}

#pragma mark- UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self resignAllFirstResponder];
    return YES;
}

@end
