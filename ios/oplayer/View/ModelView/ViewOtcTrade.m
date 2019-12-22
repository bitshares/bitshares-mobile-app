//
//  ViewOtcTrade.m
//  ViewOtcTrade
//

#import "ViewOtcTrade.h"
#import "UITableViewCellBase.h"
#import "MyTextField.h"
#import "OtcManager.h"

#import "AsyncTaskManager.h"
#import "OrgUtils.h"

enum
{
    tf_tag_number = 0,                      //  数量输入框
    tf_tag_total,                           //  总金额输入框
};

@interface ViewOtcTrade()
{
    WsPromiseObject*    _result_promise;
    
    NSDictionary*       _adInfo;            //  广告牌信息
    NSDictionary*       _lockInfo;          //  锁定后的价格信息
    NSDictionary*       _sell_user_balance; //  卖单时：用户账号对应资产余额信息。买单时为nil。
    NSDictionary*       _assetInfo;         //  资产信息
    NSDecimalNumber*    _nBalance;          //  我的余额（仅卖出需要）
    NSDecimalNumber*    _nPrice;            //  价格
    NSDecimalNumber*    _nStock;            //  数量限额
    NSDecimalNumber*    _nStockFinal;       //  数量限额（考虑了最大金额限额的的情况）
    NSDecimalNumber*    _nMaxLimit;         //  最大金额限制
    NSDecimalNumber*    _nMaxLimitFinal;    //  最大金额限制（考虑数量和单价的总金额的情况）
    NSInteger           _numPrecision;
    NSInteger           _totalPrecision;
    
    CGRect              _rectIn;
    CGRect              _rectOut;
    
    UIView*             _mainDialog;        //  底部主输入框
    MyTextField*        _tfNumber;          //  数量
    MyTextField*        _tfTotal;           //  总成交金额
    UIButton*           _autoCloseButton;   //  自动取消按钮
    
    UILabel*            _tradeAmount;       //  最终交易数量
    UILabel*            _finalTotalValue;   //  最终金额
    
    NSInteger           _autoCloseTimerID;
    NSInteger           _autoCloseSeconds;  //  自动关闭秒数
}

@end

@implementation ViewOtcTrade

- (void)dealloc
{
    _result_promise = nil;
    _tradeAmount = nil;
    _finalTotalValue = nil;
    _autoCloseButton = nil;
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
    _assetInfo = nil;
    _nBalance = nil;
    _nPrice = nil;
    _nStock = nil;
    _nStockFinal = nil;
    _nMaxLimit = nil;
    _nMaxLimitFinal = nil;
}

- (instancetype)initWithAdInfo:(id)ad_info
                     lock_info:(id)lock_info
             sell_user_balance:(id)sell_user_balance
                result_promise:(WsPromiseObject*)result_promise
{
    if (self = [super init])
    {
        //    lock_info
        //    code = 0;
        //    data =     {
        //        assetSymbol = USD;
        //        expireDate = 60;
        //        highLimitPrice = 1250;
        //        legalCurrencySymbol = "\U00a5";
        //        lowLimitPrice = 30;
        //        unitPrice = "7.21";
        //    };
        //    message = success;
        _result_promise = result_promise;
        _adInfo = ad_info;
        _lockInfo = lock_info;
        _sell_user_balance = sell_user_balance;
        _assetInfo = [[OtcManager sharedOtcManager] getAssetInfo:ad_info[@"assetSymbol"]];
        _numPrecision = [[_assetInfo objectForKey:@"assetPrecision"] integerValue];
        _totalPrecision = [[[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"assetPrecision"] integerValue];
        if (_sell_user_balance) {
            _nBalance = [NSDecimalNumber decimalNumberWithMantissa:[[_sell_user_balance objectForKey:@"amount"] unsignedLongLongValue]
                                                          exponent:-_numPrecision
                                                        isNegative:NO];
        } else {
            _nBalance = nil;
        }
        _nPrice = [OrgUtils auxGetStringDecimalNumberValue:[NSString stringWithFormat:@"%@", lock_info[@"unitPrice"]]];
        _nStock = [OrgUtils auxGetStringDecimalNumberValue:[NSString stringWithFormat:@"%@", ad_info[@"stock"]]];
        _nMaxLimit = [OrgUtils auxGetStringDecimalNumberValue:[NSString stringWithFormat:@"%@", lock_info[@"highLimitPrice"]]];
        _nMaxLimitFinal = _nMaxLimit;
        NSDecimalNumber* n_trade_max_limit = [self _calc_n_total_from_number:_nStock];
        if ([_nMaxLimitFinal compare:n_trade_max_limit] > 0) {
            _nMaxLimitFinal = n_trade_max_limit;
        }
        _nStockFinal = _nStock;
        NSDecimalNumber* n_stock_limit = [self _calc_n_number_from_total:_nMaxLimit];
        if ([_nStockFinal compare:n_stock_limit] > 0) {
            _nStockFinal = n_stock_limit;
        }
        
        self.cancelable = YES;
        _tfNumber = nil;
        _tfTotal = nil;
        _autoCloseSeconds = [[lock_info objectForKey:@"expireDate"] integerValue]; //  TODO:2.9 real 45: test 345
        _autoCloseTimerID = 0;
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

- (UIView*)genDialogMain:(CGFloat)max_width
{
    BOOL bUserBuy = [self isBuy];
    
    UIView* content = [[UIView alloc] init];
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    NSString* fiat_symbol = [[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"legalCurrencySymbol"];
    NSString* asset_symbol = _adInfo[@"assetSymbol"];
    
    //  单价
    UILabel* lbPriceTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbPriceTitle.text = NSLocalizedString(@"kOtcInputLabelUnitPrice", @"单价 ");
    lbPriceTitle.textAlignment = NSTextAlignmentLeft;
    lbPriceTitle.textColor = theme.textColorGray;
    
    UILabel* lbPrice = [self auxGenLabel:[UIFont boldSystemFontOfSize:28.0f] superview:content];
    lbPrice.text = [NSString stringWithFormat:@"%@%@", fiat_symbol, _adInfo[@"price"]];
    lbPrice.textColor = theme.textColorHighlight;
    
    //  买 or 卖
    UILabel* lbNumberTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbNumberTitle.text = bUserBuy ? NSLocalizedString(@"kOtcInputCellLabelBuyAmount", @"购买数量") : NSLocalizedString(@"kOtcInputCellLabelSellAmount", @"出售数量");
    lbNumberTitle.textAlignment = NSTextAlignmentLeft;
    lbNumberTitle.textColor = theme.textColorMain;
    
    UILabel* lbAvailable = nil;
    if (!bUserBuy) {
        lbAvailable = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
        lbAvailable.text = [NSString stringWithFormat:@"%@ %@ %@", NSLocalizedString(@"kOtcInputCellYourBalance", @"您的余额"),
                            [OrgUtils formatFloatValue:_nBalance usesGroupingSeparator:NO],
                            asset_symbol];
        lbAvailable.textAlignment = NSTextAlignmentLeft;
        lbAvailable.textColor = theme.textColorNormal;
    }
    
    UILabel* lbMaxNumber = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbMaxNumber.text = [NSString stringWithFormat:@"%@ %@ %@", NSLocalizedString(@"kOtcInputCellStock", @"数量"), _adInfo[@"stock"], asset_symbol];
    lbMaxNumber.textAlignment = NSTextAlignmentRight;
    lbMaxNumber.textColor = theme.textColorGray;
    
    UILabel* lbTotalTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbTotalTitle.text = bUserBuy ? NSLocalizedString(@"kOtcInputCellLabelBuyTotal", @"购买金额") : NSLocalizedString(@"kOtcInputCellLabelSellTotal", @"出售金额");
    lbTotalTitle.textAlignment = NSTextAlignmentLeft;
    lbTotalTitle.textColor = theme.textColorMain;
    
    UILabel* lbTotalLimited = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbTotalLimited.text = [NSString stringWithFormat:@"%@ %@%@ - %@%@", NSLocalizedString(@"kOtcInputCellLabelLimit", @"限额"),
                           fiat_symbol, _lockInfo[@"lowLimitPrice"], fiat_symbol, _lockInfo[@"highLimitPrice"]];
    lbTotalLimited.textAlignment = NSTextAlignmentRight;
    lbTotalLimited.textColor = theme.textColorGray;
    
    NSString* numberPlaceHolder = bUserBuy ? NSLocalizedString(@"kOtcInputPlaceholderBuyAmount", @"请输入购买数量") : NSLocalizedString(@"kOtcInputPlaceholderSellAmount", @"请输入出售数量");
    NSString* totalPlaceHolder = bUserBuy ? NSLocalizedString(@"kOtcInputPlaceholderBuyTotal", @"请输入购买金额") : NSLocalizedString(@"kOtcInputPlaceholderSellTotal", @"请输入出售金额");
    
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
    
    _tfNumber.attributedPlaceholder = [ViewUtils placeholderAttrString:numberPlaceHolder];
    _tfTotal.attributedPlaceholder = [ViewUtils placeholderAttrString:totalPlaceHolder];
    
    //  绑定输入事件（限制输入）
    [_tfNumber addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_tfTotal addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 输入框末尾按钮
    _tfNumber.rightView = [self genTailerView:asset_symbol
                                       action:bUserBuy ? NSLocalizedString(@"kOtcInputTailerBtnBuyAll", @"全部买入") : NSLocalizedString(@"kOtcInputTailerBtnSellAll", @"全部出售")
                                          tag:tf_tag_number];
    _tfNumber.rightViewMode = UITextFieldViewModeAlways;
    _tfTotal.rightView = [self genTailerView:fiat_symbol
                                      action:NSLocalizedString(@"kOtcInputTailerBtnMaxTotal", @"最大金额")
                                         tag:tf_tag_total];
    _tfTotal.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 交易数量
    _tradeAmount = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    _tradeAmount.text = [NSString stringWithFormat:@"%@ %@ %@", NSLocalizedString(@"kOtcInputCellLabelTradeAmount", @"交易数量"), @"0", asset_symbol];
    _tradeAmount.textAlignment = NSTextAlignmentRight;
    _tradeAmount.textColor = theme.textColorMain;
    
    //  UI - 实付款/实际到账
    UILabel* finalTotalTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    _finalTotalValue = [self auxGenLabel:[UIFont boldSystemFontOfSize:18.0f] superview:content];
    finalTotalTitle.text = bUserBuy ? NSLocalizedString(@"kOtcInputCellRealPayment", @"实际付款") : NSLocalizedString(@"kOtcInputCellRealReceive", @"实际到账");
    finalTotalTitle.textAlignment = NSTextAlignmentLeft;
    
    _finalTotalValue.text = [NSString stringWithFormat:@"%@%@", fiat_symbol, @"0"];
    _finalTotalValue.textColor = theme.textColorHighlight;
    _finalTotalValue.textAlignment = NSTextAlignmentRight;
    
    //  UI - 按钮
    CGFloat fBottomViewHeight = 60.0f;
    CGFloat fBottomSpace = 12.0f;
    UIView* pBottomView = [[UIView alloc] init];
    CGFloat fBottomBuySellWidth = max_width;
    CGFloat fBottomButtonWidth = (fBottomBuySellWidth - fBottomSpace) / 2;
    CGFloat fBottomButton = 38.0f;
    //  REMARK：用系统按钮更新文字时会闪烁。
    _autoCloseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _autoCloseButton.titleLabel.font = [UIFont systemFontOfSize:16];
    _autoCloseButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [_autoCloseButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"kOtcInputAutoCloseSecTips", @"%@秒后自动取消"), @(_autoCloseSeconds)] forState:UIControlStateNormal];
    [_autoCloseButton setTitleColor:theme.textColorPercent forState:UIControlStateNormal];
    _autoCloseButton.userInteractionEnabled = YES;
    [_autoCloseButton addTarget:self action:@selector(onButtomAutoCancelClicked) forControlEvents:UIControlEventTouchUpInside];
    _autoCloseButton.frame = CGRectMake(0, (fBottomViewHeight  - fBottomButton) / 2,
                                        fBottomButtonWidth, fBottomButton);
    _autoCloseButton.backgroundColor = theme.textColorGray;
    [pBottomView addSubview:_autoCloseButton];
    UIButton* btnBottomSubmit = [UIButton buttonWithType:UIButtonTypeSystem];
    btnBottomSubmit.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    btnBottomSubmit.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [btnBottomSubmit setTitle:NSLocalizedString(@"kOtcInputBtnCreateOrder", @"下单") forState:UIControlStateNormal];
    [btnBottomSubmit setTitleColor:theme.textColorPercent forState:UIControlStateNormal];
    btnBottomSubmit.userInteractionEnabled = YES;
    [btnBottomSubmit addTarget:self action:@selector(onButtomSubmitClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnBottomSubmit.frame = CGRectMake(fBottomButtonWidth + fBottomSpace,
                                       (fBottomViewHeight  - fBottomButton) / 2, fBottomButtonWidth, fBottomButton);
    btnBottomSubmit.backgroundColor = bUserBuy ? theme.buyColor : theme.sellColor;
    [pBottomView addSubview:btnBottomSubmit];
    
    [content addSubview:_tfNumber];
    [content addSubview:_tfTotal];
    [content addSubview:pBottomView];
    
    //  设置 frame
    CGFloat fSpace = 16.0f;
    CGFloat fOffsetY = 8.0f;
    CGFloat fLineHeight = 44.0f;
    CGFloat fTextHeight = 28.0f;
    CGSize size_price = [ViewUtils auxSizeWithLabel:lbPrice maxsize:CGSizeMake(max_width, 9999)];
    CGSize size_title = [ViewUtils auxSizeWithLabel:lbPriceTitle maxsize:CGSizeMake(max_width, 9999)];
    CGFloat fSizePriceX = (max_width - size_price.width) / 2;
    lbPrice.frame = CGRectMake(fSizePriceX, fOffsetY, size_price.width, fLineHeight);
    lbPriceTitle.frame = CGRectMake(fSizePriceX - size_title.width, fOffsetY, size_title.width, fLineHeight);
    fOffsetY += fLineHeight + 8.0f;
    
    lbNumberTitle.frame = CGRectMake(0, fOffsetY, max_width, 18.0f);
    lbMaxNumber.frame = lbNumberTitle.frame;
    if (lbAvailable) {
        CGSize s = [ViewUtils auxSizeWithLabel:lbNumberTitle maxsize:CGSizeMake(max_width, 9999)];
        lbAvailable.frame = CGRectMake(s.width + 8, fOffsetY, max_width, 18.0f);
    }
    fOffsetY += lbNumberTitle.bounds.size.height;
    _tfNumber.frame = CGRectMake(0, fOffsetY, max_width, fLineHeight);
    fOffsetY += fLineHeight + 16;
    
    lbTotalTitle.frame = CGRectMake(0, fOffsetY, max_width, 18.0f);
    lbTotalLimited.frame = lbTotalTitle.frame;
    fOffsetY += lbTotalTitle.bounds.size.height;
    
    _tfTotal.frame = CGRectMake(0, fOffsetY, max_width, fLineHeight);
    fOffsetY += fLineHeight + fSpace;
    
    _tradeAmount.frame = CGRectMake(0, fOffsetY, max_width, fTextHeight);
    fOffsetY += fTextHeight;
    
    finalTotalTitle.frame = CGRectMake(0, fOffsetY, max_width, fTextHeight);
    _finalTotalValue.frame = CGRectMake(0, fOffsetY, max_width, fTextHeight);
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
    if ([self isBuy]) {
        lb_title.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kOtcInputTitleBuy", @"购买"), _adInfo[@"assetSymbol"]];
    } else {
        lb_title.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kOtcInputTitleSell", @"出售"), _adInfo[@"assetSymbol"]];
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
    
    //  自动关闭定时器
    _autoCloseTimerID = [[AsyncTaskManager sharedAsyncTaskManager] scheduledSecondsTimer:_autoCloseSeconds callback:^(NSInteger left_ts) {
        if (left_ts > 0) {
            //  刷新
            [_autoCloseButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"kOtcInputAutoCloseSecTips", @"%@秒后自动取消"), @(left_ts)] forState:UIControlStateNormal];
        } else {
            [self onButtomAutoCancelClicked];
        }
    }];
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
    switch (sender.tag) {
        case tf_tag_number:
        {
            NSDecimalNumber* max_value = _nStockFinal;
            //  出售的情况下
            if (![self isBuy]) {
                if ([max_value compare:_nBalance] > 0) {
                    max_value = _nBalance;
                }
            }
            _tfNumber.text = [OrgUtils formatFloatValue:max_value usesGroupingSeparator:NO];
            [self onNumberFieldChanged];
        }
            break;
        case tf_tag_total:
        {
            NSDecimalNumber* max_value = _nMaxLimitFinal;
            //  出售的情况下
            if (![self isBuy]) {
                id sell_max = [self _calc_n_total_from_number:_nBalance];
                if ([max_value compare:sell_max] > 0) {
                    max_value = sell_max;
                }
            }
            _tfTotal.text = [OrgUtils formatFloatValue:max_value usesGroupingSeparator:NO];
            [self onTotalFieldChanged];
        }
            break;
        default:
            break;
    }
}

/*
 *  事件 -  自动取消按钮
 */
- (void)onButtomAutoCancelClicked
{
    [self _handleCloseWithResult:nil];
}

/*
 *  事件 - 下单按钮
 */
- (void)onButtomSubmitClicked:(UIButton*)sender
{
    id str_amount = _tfNumber.text;
    id str_total = _tfTotal.text;
    
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    id n_total = [OrgUtils auxGetStringDecimalNumberValue:str_total];
    
    //  REMARK：该界面的toast居中显示。不然可能会被键盘遮挡。
    NSString* toastPosition = @"CSToastPositionCenter";
    if ([n_total compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcInputSubmitTipTotalZero", @"交易金额不能为零。")
                   position:toastPosition];
        return;
    }
    
    if ([n_amount compare:_nStock] > 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcInputSubmitTipAmountGreatThanStock", @"交易数量不能大于可用数量。")
                   position:toastPosition];
        return;
    }
    
    if (_nBalance && [n_amount compare:_nBalance] > 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcInputSubmitTipAmountGreatThanBalance", @"交易数量不能大于用户可用余额。")
                   position:toastPosition];
        return;
    }
    
    id n_min_limit = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", _lockInfo[@"lowLimitPrice"]]];
    if ([n_total compare:n_min_limit] < 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcInputSubmitTipTotalLessMinLimit", @"交易金额不能低于单笔最小限额。")
                   position:toastPosition];
        return;
    }
    
    if ([n_total compare:_nMaxLimit] > 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcInputSubmitTipTotalGreatMaxLimit", @"交易金额不能大于单笔最大限额。")
                   position:toastPosition];
        return;
    }
    
    //  校验完毕，前往下单。
    [self _handleCloseWithResult:@{@"total":str_total}];
}

/*
 *  (private) 关闭界面
 */
- (void)_handleCloseWithResult:(id)result
{
    [[AsyncTaskManager sharedAsyncTaskManager] removeSecondsTimer:_autoCloseTimerID];
    [self resignAllFirstResponder];
    [self dismissWithCompletion:^{
        if (_result_promise) {
            [_result_promise resolve:result];
        }
    }];
}

#pragma mark- UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return YES;
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != _tfNumber && textField != _tfTotal){
        return YES;
    }
    
    //  根据输入框不同，限制不同小数点位数。
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:textField == _tfNumber ? _numPrecision : _totalPrecision];
}

- (void)onTextFieldDidChange:(UITextField*)textField
{
    if (textField != _tfNumber && textField != _tfTotal){
        return;
    }
    
    //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
    [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
    
    //  处理事件
    if (textField == _tfTotal){
        [self onTotalFieldChanged];
    }else{
        [self onNumberFieldChanged];
    }
}

/**
 *  (private) 输入交易额变化，重新计算交易数量or价格。
 */
- (void)onTotalFieldChanged
{
    id str_total = _tfTotal.text;
    
    NSDecimalNumber* n_total = [OrgUtils auxGetStringDecimalNumberValue:str_total];
    NSDecimalNumber* n_amount = [self _calc_n_number_from_total:n_total];
    
    //  刷新 交易数量 和 最终金额。
    [self _draw_ui_trade_value:n_amount];
    [self _draw_ui_final_value:n_total];
    
    //  交易数量
    if (!str_total || [str_total isEqualToString:@""]){
        _tfNumber.text = @"";
    }else{
        _tfNumber.text = [OrgUtils formatFloatValue:n_amount usesGroupingSeparator:NO];
    }
}

/**
 *  (private) 输入的数量发生变化，评估交易额。
 */
- (void)onNumberFieldChanged
{
    id str_amount = _tfNumber.text;
    
    NSDecimalNumber* n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    NSDecimalNumber* n_total = [self _calc_n_total_from_number:n_amount];
    
    //  刷新 交易数量 和 最终金额。
    [self _draw_ui_trade_value:n_amount];
    [self _draw_ui_final_value:n_total];
    
    //  总金额
    if (!str_amount || [str_amount isEqualToString:@""]){
        _tfTotal.text = @"";
    }else{
        _tfTotal.text = [OrgUtils formatFloatValue:n_total usesGroupingSeparator:NO];
    }
}

/*
 *  (private) 根据总金额计算数量
 *  REMARK：买入行为：数量向下取整 卖出行为：数量向上取整
 */
- (NSDecimalNumber*)_calc_n_number_from_total:(NSDecimalNumber*)n_total
{
    NSDecimalNumberHandler* roundHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:[self isBuy] ? NSRoundDown : NSRoundUp
                                                                                                  scale:_numPrecision
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];
    return [n_total decimalNumberByDividingBy:_nPrice withBehavior:roundHandler];
}

/*
 *  (private) 根据数量计算总金额
 *  REMARK：买入行为：总金额向上取整 卖出行为：向下取整
 */
- (NSDecimalNumber*)_calc_n_total_from_number:(NSDecimalNumber*)n_amount
{
    NSDecimalNumberHandler* roundHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:[self isBuy] ? NSRoundUp : NSRoundDown
                                                                                                  scale:_totalPrecision
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];
    return [_nPrice decimalNumberByMultiplyingBy:n_amount withBehavior:roundHandler];
}

- (void)_draw_ui_trade_value:(NSDecimalNumber*)n_value
{
    //  TODO:2.9 是否超过。余额 以及。数量限制 着色
    NSString* asset_symbol = _adInfo[@"assetSymbol"];
    
    _tradeAmount.text = [NSString stringWithFormat:@"%@ %@ %@", NSLocalizedString(@"kOtcInputCellLabelTradeAmount", @"交易数量"),
                         [OrgUtils formatFloatValue:n_value usesGroupingSeparator:NO],
                         asset_symbol];//TODO:2.9
}

- (void)_draw_ui_final_value:(NSDecimalNumber*)n_final
{
    //  TODO:2.9 是否超过限额
    NSString* fiat_symbol = [[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"legalCurrencySymbol"];
    _finalTotalValue.text = [NSString stringWithFormat:@"%@%@", fiat_symbol,
                             [OrgUtils formatFloatValue:n_final usesGroupingSeparator:YES]];
}

@end
