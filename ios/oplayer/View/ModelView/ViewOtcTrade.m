//
//  ViewOtcTrade.m
//  ViewOtcTrade
//

#import "ViewOtcTrade.h"
#import "UITableViewCellBase.h"
#import "MyTextField.h"
#import "OtcManager.h"

@interface ViewOtcTrade()
{
    NSDictionary*   _adInfo;            //  广告牌信息
    
    CGRect          _rectIn;
    CGRect          _rectOut;
    
    UIView*         _mainDialog;        //  底部主输入框
    MyTextField*    _tfNumber;          //  数量
    MyTextField*    _tfTotal;           //  总成交金额
}

@end

@implementation ViewOtcTrade

- (void)dealloc
{
    if (_tfNumber){
        _tfNumber.delegate = nil;
        _tfNumber = nil;
    }
    if (_tfTotal){
        _tfTotal.delegate = nil;
        _tfTotal = nil;
    }
    _mainDialog = nil;
    _adInfo = nil;
}

- (instancetype)initWithAdInfo:(id)ad_info
{
    if (self = [super init])
    {
        _adInfo = ad_info;
        self.cancelable = YES;
        _tfNumber = nil;
        _tfTotal = nil;
    }
    return self;
}

- (BOOL)isBuy
{
    return [[_adInfo objectForKey:@"adType"] integerValue] == eoadt_user_buy;
}

- (MyTextField*)createTfWithRect:(CGRect)rect keyboard:(UIKeyboardType)kbt placeholder:(NSString*)placeholder
{
    MyTextField* tf = [[MyTextField alloc] initWithFrame:rect];
    
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    tf.keyboardType = kbt;
    tf.returnKeyType = UIReturnKeyNext;
    tf.delegate = self;
    tf.placeholder = placeholder;
    tf.borderStyle = UITextBorderStyleNone;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.tintColor = [ThemeManager sharedThemeManager].tintColor;
    
    return tf;
}

- (CGRect)makeTextFieldRectFull:(CGFloat)offset_y width:(CGFloat)width
{
    return CGRectMake(0, offset_y, width, 31);
}

- (UIView*)genTailerView:(NSString*)asset_symbol action:(NSString*)action tag:(NSInteger)tag
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  100 + 20 + 60
    UIView* tailer_view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 31)];
    
    UILabel* lbAsset = [self auxGenLabel:[UIFont boldSystemFontOfSize:13] superview:tailer_view];
    UILabel* lbSpace = [self auxGenLabel:[UIFont systemFontOfSize:13] superview:tailer_view];
    lbAsset.text = asset_symbol;
    lbSpace.text = @"|";//TODO:2.9
    lbAsset.textColor = theme.textColorMain;
    lbSpace.textColor = theme.textColorGray;
    lbAsset.textAlignment = NSTextAlignmentRight;
    
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn setTitle:action forState:UIControlStateNormal];
    [btn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onButtonTailerClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn.tag = tag;
    
    //  设置 frame
    lbAsset.frame = CGRectMake(0, 0, 100, 31);
    lbSpace.frame = CGRectMake(100, 0, 20, 31);
    btn.frame = CGRectMake(120, 0, 60, 31);
    
    [tailer_view addSubview:lbAsset];
    [tailer_view addSubview:lbSpace];
    [tailer_view addSubview:btn];
    
    return tailer_view;
}

//  TODO:2.9
//<__NSSingleObjectArrayI 0x2811d8680>(
//{
//    adId = 22f879a1303f167c70292fb2f88fef58f1301d02;
//    adType = 2;
//    aliPaySwitch = 1;
//    assetId = "1.0.3";
//    assetName = CNY;
//    bankcardPaySwitch = 1;
//    ctime = "2019-11-12T07:27:11.000+0000";
//    deadTime = "2019-11-12T07:27:11.000+0000";
//    frozenQuantity = 0;
//    id = 14;
//    isDeleted = 0;
//    leagalType = 1;
//    lowestLimit = 50;
//    maxLimit = 1000;
//    merchantId = 7;
//    merchantNickname = "\U5409\U7965\U627f\U5151";
//    mtime = "2019-11-12T10:33:55.000+0000";
//    otcAccount = "gdex-otc1";
//    otcBtsId = "1.2.42";
//    price = "1.02";
//    priceType = 1;
//    quantity = 5000;
//    remark = "\U6d4b\U8bd5\U5907\U6ce8";
//    status = 1;
//    stock = 5000;
//    userId = "<null>";
//}
//)


- (UIView*)genDialogMain:(CGFloat)max_width
{
    BOOL buy = [self isBuy];
    
    UIView* content = [[UIView alloc] init];
        
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  TODO:2.9  买 or 卖
    
    NSString* numberPlaceHolder = NSLocalizedString(@"kPlaceHolderSellAmount", @"卖出数量");
    NSString* totalPlaceHolder = NSLocalizedString(@"kLableTotalPrice", @"交易额");
    
    //  UI -  数量输入框
    _tfNumber = [self createTfWithRect:CGRectZero
                              keyboard:UIKeyboardTypeDecimalPad
                           placeholder:numberPlaceHolder];
    _tfNumber.textColor = theme.textColorMain;
    _tfNumber.showBottomLine = YES;
    
    //  UI - 金额输入框
    _tfTotal = [self createTfWithRect:CGRectZero
                             keyboard:UIKeyboardTypeDecimalPad
                          placeholder:totalPlaceHolder];
    _tfTotal.textColor = theme.textColorMain;
    _tfTotal.showBottomLine = YES;
    
    _tfNumber.attributedPlaceholder = [[NSAttributedString alloc] initWithString:numberPlaceHolder
                                                                      attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
                                                                                   NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    _tfTotal.attributedPlaceholder = [[NSAttributedString alloc] initWithString:totalPlaceHolder
                                                                     attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
                                                                                   NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    //  UI - 输入框末尾按钮
    _tfNumber.rightView = [self genTailerView:_adInfo[@"assetName"] action:@"全部买入" tag:0];//TODO:2.9
    _tfNumber.rightViewMode = UITextFieldViewModeAlways;
    _tfTotal.rightView = [self genTailerView:@"¥" action:@"全部买入" tag:0];//TODO:2.9 fiat currency
    _tfTotal.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 交易数量
    UILabel* tradeAmount = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    tradeAmount.text = @"交易数量 2323 BTC";
    tradeAmount.textAlignment = NSTextAlignmentRight;
    tradeAmount.textColor = theme.textColorNormal;
    
    //  UI - 实付款/实际到账
    UILabel* finalTotalTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    UILabel* finalTotalValue = [self auxGenLabel:[UIFont boldSystemFontOfSize:18.0f] superview:content];
    finalTotalTitle.text = @"实付款";
    finalTotalTitle.textAlignment = NSTextAlignmentLeft;
    
    finalTotalValue.text = @"$ 3333";
    finalTotalValue.textColor = theme.textColorHighlight;
    finalTotalValue.textAlignment = NSTextAlignmentRight;
    
    //  UI - 按钮
    CGFloat fBottomViewHeight = 60.0f;
    CGFloat fBottomSpace = 12.0f;
    UIView* pBottomView = [[UIView alloc] init];
//    pBottomView.backgroundColor = theme.tabBarColor;
    CGFloat fBottomBuySellWidth = max_width;
    CGFloat fBottomButtonWidth = (fBottomBuySellWidth - fBottomSpace) / 2;
    CGFloat fBottomButton = 38.0f;
    UIButton* btnBottomBuy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnBottomBuy.titleLabel.font = [UIFont systemFontOfSize:16];
    btnBottomBuy.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [btnBottomBuy setTitle:@"14s后自动取消" forState:UIControlStateNormal];
    [btnBottomBuy setTitleColor:theme.textColorPercent forState:UIControlStateNormal];
    btnBottomBuy.userInteractionEnabled = YES;
    [btnBottomBuy addTarget:self action:@selector(onButtomAutoCancelClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnBottomBuy.frame = CGRectMake(0, (fBottomViewHeight  - fBottomButton) / 2,
                                    fBottomButtonWidth, fBottomButton);
    btnBottomBuy.backgroundColor = theme.textColorGray;
    [pBottomView addSubview:btnBottomBuy];
    UIButton* btnBottomSell = [UIButton buttonWithType:UIButtonTypeSystem];
    btnBottomSell.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    btnBottomSell.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [btnBottomSell setTitle:@"下单" forState:UIControlStateNormal];
    [btnBottomSell setTitleColor:theme.textColorPercent forState:UIControlStateNormal];
    btnBottomSell.userInteractionEnabled = YES;
    [btnBottomSell addTarget:self action:@selector(onButtomSubmitClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnBottomSell.frame = CGRectMake(fBottomButtonWidth + fBottomSpace,
                                     (fBottomViewHeight  - fBottomButton) / 2, fBottomButtonWidth, fBottomButton);
    btnBottomSell.backgroundColor = buy ? theme.buyColor : theme.sellColor;
    [pBottomView addSubview:btnBottomSell];
    
    
    [content addSubview:_tfNumber];
    [content addSubview:_tfTotal];
    [content addSubview:pBottomView];
    
    //  设置 frame
    CGFloat fSpace = 16.0f;
    CGFloat fOffsetY = fSpace;
    CGFloat fLineHeight = 44.0f;
    CGFloat fTextHeight = 28.0f;
    
    _tfNumber.frame = CGRectMake(0, fOffsetY, max_width, fLineHeight);
    fOffsetY += fLineHeight;
    
    _tfTotal.frame = CGRectMake(0, fOffsetY, max_width, fLineHeight);
    fOffsetY += fLineHeight;
    
    tradeAmount.frame = CGRectMake(0, fOffsetY, max_width, fTextHeight);
    fOffsetY += fTextHeight;
    
    finalTotalTitle.frame = CGRectMake(0, fOffsetY, max_width, fTextHeight);
    finalTotalValue.frame = CGRectMake(0, fOffsetY, max_width, fTextHeight);
    fOffsetY += fTextHeight;
    
    pBottomView.frame = CGRectMake(0, fOffsetY, max_width, fBottomViewHeight);
    fOffsetY += fBottomViewHeight + fSpace;
    
    content.frame = CGRectMake(0, 0, max_width, fOffsetY);
    content.backgroundColor = [UIColor clearColor];
    return content;
    
}

- (UIView*)genToolbar:(CGRect)rect
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UIView* toolbar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, rect.size.width, 44)];
    toolbar.backgroundColor = theme.tabBarColor;
    
    UILabel* lb_title = [[UILabel alloc] initWithFrame:toolbar.bounds];
    lb_title.lineBreakMode = NSLineBreakByWordWrapping;
    lb_title.numberOfLines = 1;
    lb_title.backgroundColor = [UIColor clearColor];
    lb_title.textColor = theme.textColorMain;
    lb_title.textAlignment = NSTextAlignmentCenter;
    lb_title.font = [UIFont boldSystemFontOfSize:16.0f];
    //  TODO:2.9 多语言 
    if ([self isBuy]) {
        lb_title.text = [NSString stringWithFormat:@"%@ %@", @"购买", _adInfo[@"assetName"]];
    } else {
        lb_title.text = [NSString stringWithFormat:@"%@ %@", @"出售", _adInfo[@"assetName"]];
    }
    [toolbar addSubview:lb_title];
    
    return toolbar;
}

- (void)setupSubViews
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGRect rect = [UIScreen mainScreen].bounds;
    
    CGFloat xOffset = 16.0f;

    //  UI - 标题栏
    UIView* toolbar = [self genToolbar:rect];
    
    //  UI - 内容
    UIView* content = [self genDialogMain:rect.size.width - xOffset * 2];
    
    CGSize size_content = content.bounds.size;
    content.frame = CGRectMake(xOffset, toolbar.bounds.size.height, size_content.width, size_content.height);
    
    //  主对话框
    CGFloat height = toolbar.bounds.size.height + content.bounds.size.height;
    _rectIn = CGRectMake(0, rect.size.height - height, rect.size.width, height);
    _rectOut = CGRectMake(0, rect.size.height, rect.size.width, height);
    _mainDialog = [[UIView alloc] initWithFrame:_rectIn];
    _mainDialog.backgroundColor = theme.appBackColor;
    [_mainDialog addSubview:toolbar];
    [_mainDialog addSubview:content];
    [self addSubview:_mainDialog];
}

- (void)setupAnimationBeginPosition:(BOOL)bSlideIn
{
    if (bSlideIn) {
        _mainDialog.frame = _rectOut;
    } else {
        //  消失动画，不设置初始位置，从当前位置滑出即可。
    }
}

- (void)setupAnimationEndPosition:(BOOL)bSlideIn
{
    if (bSlideIn) {
        _mainDialog.frame = _rectIn;
    } else {
        _mainDialog.frame = _rectOut;
    }
}

- (void)onFollowKeyboard:(CGFloat)keyboard_y duration:(CGFloat)duration
{
    CGFloat ty = keyboard_y - [UIScreen mainScreen].bounds.size.height;
    [UIView animateWithDuration:duration animations:^{
        _mainDialog.transform = CGAffineTransformMakeTranslation(0, ty);
    }];
}

- (void)onOutsideClicked
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
    [self endEditing:YES];
    if (_tfNumber) {
        [_tfNumber safeResignFirstResponder];
    }
    if (_tfTotal) {
        [_tfTotal safeResignFirstResponder];
    }
}

/*
 *  事件 - 输入框末尾按钮
 */
- (void)onButtonTailerClicked:(UIButton*)sender
{
    //  TODO:2.9
}

/*
 *  事件 -  自动取消按钮
 */
- (void)onButtomAutoCancelClicked:(UIButton*)sender
{
    [self resignAllFirstResponder];
    [self dismissWithCompletion:nil];
}

/*
 *  事件 - 下单按钮
 */
- (void)onButtomSubmitClicked:(UIButton*)sender
{
    //  TODO:2.9
}

//- (void)onSubmitClicked
//{
//    //  TODO:2.9
//    [self resignAllFirstResponder];
//    [self dismissWithCompletion:nil];
//}

#pragma mark- UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    //  TODO:2.9
//    [self onSubmitClicked];
    return YES;
}

@end
