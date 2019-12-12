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

- (instancetype)initWithAdInfo:(id)ad_info lock_info:(id)lock_info result_promise:(WsPromiseObject*)result_promise
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
        _assetInfo = [[OtcManager sharedOtcManager] getAssetInfo:ad_info[@"assetSymbol"]];
        _numPrecision = [[_assetInfo objectForKey:@"assetPrecision"] integerValue];
        _totalPrecision = [[[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"precision"] integerValue];
        _nBalance = [NSDecimalNumber decimalNumberWithString:@"100.3"];//TODO:2.9 !!!
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
        _autoCloseSeconds = [[lock_info objectForKey:@"expireDate"] integerValue];     //  TODO:2.9 real 45: test 345
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

//  TODO:2.9
//<__NSSingleObjectArrayI 0x2811d8680>(
//{
//    adId = 22f879a1303f167c70292fb2f88fef58f1301d02;
//    adType = 2;
//    aliPaySwitch = 1;
//    assetId = "1.0.3";
//    assetSymbol = CNY;
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
    BOOL bUserBuy = [self isBuy];
    
    UIView* content = [[UIView alloc] init];
        
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    NSString* fiat_symbol = [[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"short_symbol"];
    NSString* asset_symbol = _adInfo[@"assetSymbol"];
    
    //  单价
    UILabel* lbPriceTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbPriceTitle.text = @"单价 ";
    lbPriceTitle.textAlignment = NSTextAlignmentLeft;
    lbPriceTitle.textColor = theme.textColorGray;
    
    UILabel* lbPrice = [self auxGenLabel:[UIFont boldSystemFontOfSize:28.0f] superview:content];
    lbPrice.text = [NSString stringWithFormat:@"%@%@", fiat_symbol, _adInfo[@"price"]];
    lbPrice.textColor = theme.textColorHighlight;
    
    //  TODO:2.9  买 or 卖
    UILabel* lbNumberTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbNumberTitle.text = bUserBuy ? @"购买数量" : @"出售数量";
    lbNumberTitle.textAlignment = NSTextAlignmentLeft;
    lbNumberTitle.textColor = theme.textColorMain;
    
    UILabel* lbAvailable = nil;
    if (!bUserBuy) {
        lbAvailable = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
        lbAvailable.text = [NSString stringWithFormat:@"%@ %@ %@", @"余额",
                            [OrgUtils formatFloatValue:_nBalance usesGroupingSeparator:NO],
                            asset_symbol];//TODO:2.9
        lbAvailable.textAlignment = NSTextAlignmentLeft;
        lbAvailable.textColor = theme.textColorNormal;
    }
    
    UILabel* lbMaxNumber = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbMaxNumber.text = [NSString stringWithFormat:@"%@ %@ %@", @"数量", _adInfo[@"stock"], asset_symbol];
    lbMaxNumber.textAlignment = NSTextAlignmentRight;
    lbMaxNumber.textColor = theme.textColorGray;
    
    UILabel* lbTotalTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbTotalTitle.text = bUserBuy ? @"购买金额" : @"出售金额";
    lbTotalTitle.textAlignment = NSTextAlignmentLeft;
    lbTotalTitle.textColor = theme.textColorMain;
    
    UILabel* lbTotalLimited = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbTotalLimited.text = [NSString stringWithFormat:@"%@ %@%@ - %@%@", @"限额",
                           fiat_symbol, _lockInfo[@"lowLimitPrice"], fiat_symbol, _lockInfo[@"highLimitPrice"]];
    lbTotalLimited.textAlignment = NSTextAlignmentRight;
    lbTotalLimited.textColor = theme.textColorGray;
    
    NSString* numberPlaceHolder = bUserBuy ? @"请输入购买数量" : @"请输入出售数量";
    NSString* totalPlaceHolder = bUserBuy ? @"请输入购买金额" : @"请输入出售金额";
    
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
    
    //  绑定输入事件（限制输入）
    [_tfNumber addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_tfTotal addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 输入框末尾按钮
    _tfNumber.rightView = [self genTailerView:asset_symbol action:bUserBuy ? @"全部买入" : @"全部出售" tag:tf_tag_number];//TODO:2.9
    _tfNumber.rightViewMode = UITextFieldViewModeAlways;
    _tfTotal.rightView = [self genTailerView:fiat_symbol action:bUserBuy ? @"最大金额" : @"最大金额" tag:tf_tag_total];//TODO:2.9 fiat currency
    _tfTotal.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 交易数量
    _tradeAmount = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    _tradeAmount.text = [NSString stringWithFormat:@"%@ %@ %@", @"交易数量", @"0", asset_symbol];//TODO:2.9
    _tradeAmount.textAlignment = NSTextAlignmentRight;
    _tradeAmount.textColor = theme.textColorMain;
    
    //  UI - 实付款/实际到账
    UILabel* finalTotalTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    _finalTotalValue = [self auxGenLabel:[UIFont boldSystemFontOfSize:18.0f] superview:content];
    finalTotalTitle.text = bUserBuy ? @"实际付款" : @"实际到账";
    finalTotalTitle.textAlignment = NSTextAlignmentLeft;
    
    _finalTotalValue.text = [NSString stringWithFormat:@"%@%@", fiat_symbol, @"0"];//TODO:2.9 teatdata
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
    //  TODO:2.9
    [_autoCloseButton setTitle:[NSString stringWithFormat:@"%@%@", @(_autoCloseSeconds), @"秒后自动取消"] forState:UIControlStateNormal];
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
    [btnBottomSubmit setTitle:@"下单" forState:UIControlStateNormal];
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
    
    CGSize size_price = [UITableViewCellBase auxSizeWithText:lbPrice.text font:lbPrice.font maxsize:CGSizeMake(max_width, 9999)];
    CGSize size_title = [UITableViewCellBase auxSizeWithText:lbPriceTitle.text font:lbPriceTitle.font maxsize:CGSizeMake(max_width, 9999)];
    CGFloat fSizePriceX = (max_width - size_price.width) / 2;
    lbPrice.frame = CGRectMake(fSizePriceX, fOffsetY, size_price.width, fLineHeight);
    lbPriceTitle.frame = CGRectMake(fSizePriceX - size_title.width, fOffsetY, size_title.width, fLineHeight);
//    lbPrice.backgroundColor = [UIColor  redColor];
//    lbPriceTitle.backgroundColor = [UIColor greenColor];
////    lbPrice.frame = CGRectMake(0, fOffsetY, max_width, fLineHeight);
    fOffsetY += fLineHeight + 8.0f;
    
    lbNumberTitle.frame = CGRectMake(0, fOffsetY, max_width, 18.0f);
    lbMaxNumber.frame = lbNumberTitle.frame;
    if (lbAvailable) {
        CGSize s = [UITableViewCellBase auxSizeWithText:lbNumberTitle.text font:lbNumberTitle.font maxsize:CGSizeMake(max_width, 9999)];
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
    //  TODO:2.9 多语言 
    if ([self isBuy]) {
        lb_title.text = [NSString stringWithFormat:@"%@ %@", @"购买", _adInfo[@"assetSymbol"]];
    } else {
        lb_title.text = [NSString stringWithFormat:@"%@ %@", @"出售", _adInfo[@"assetSymbol"]];
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
            //  刷新 TODO:2.9 多语言
            [_autoCloseButton setTitle:[NSString stringWithFormat:@"%@%@", @(left_ts), @"秒后自动取消"] forState:UIControlStateNormal];
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
    //  TODO:2.9
    id str_amount = _tfNumber.text;
    id str_total = _tfTotal.text;
    
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    id n_total = [OrgUtils auxGetStringDecimalNumberValue:str_total];
    
    //  TODO:2.9 result test data
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
    //  TODO:2.9
//    [self onSubmitClicked];
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
    //  TODO:2.9 是否超过。余额 以及。数量限制
    NSString* asset_symbol = _adInfo[@"assetSymbol"];
    
    _tradeAmount.text = [NSString stringWithFormat:@"%@ %@ %@", @"交易数量",
                         [OrgUtils formatFloatValue:n_value usesGroupingSeparator:NO],
                         asset_symbol];//TODO:2.9
}

- (void)_draw_ui_final_value:(NSDecimalNumber*)n_final
{
    //  TODO:2.9 是否超过限额
    NSString* fiat_symbol = [[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"short_symbol"];
    _finalTotalValue.text = [NSString stringWithFormat:@"%@%@", fiat_symbol,
                             [OrgUtils formatFloatValue:n_final usesGroupingSeparator:YES]];
}

@end
