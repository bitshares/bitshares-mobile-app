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
    UIButton*       _autoCloseButton;   //  自动取消按钮
    
    NSTimer*        _autoCloseTimer;
    NSTimeInterval  _autoCloseStartTs;  //  开始计时
    NSInteger       _autoCloseSeconds;  //  自动关闭秒数
}

@end

@implementation ViewOtcTrade

- (void)dealloc
{
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
    [self stopAutoCloseTimer];
}

- (instancetype)initWithAdInfo:(id)ad_info
{
    if (self = [super init])
    {
        _adInfo = ad_info;
        self.cancelable = YES;
        _tfNumber = nil;
        _tfTotal = nil;
        _autoCloseSeconds = 45;     //  TODO:2.9
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
    BOOL bUserBuy = [self isBuy];
    
    UIView* content = [[UIView alloc] init];
        
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    NSString* fiat_symbol = @"¥";// TODO:2.9
    NSString* asset_symbol = _adInfo[@"assetName"];
    
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
        lbAvailable.text = [NSString stringWithFormat:@"%@ %@ %@", @"余额", @"333.44", asset_symbol];//TODO:2.9
        lbAvailable.textAlignment = NSTextAlignmentLeft;
        lbAvailable.textColor = theme.textColorNormal;
    }
    
    UILabel* lbMaxNumber = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbMaxNumber.text = [NSString stringWithFormat:@"%@ %@ %@", @"限量", _adInfo[@"stock"], asset_symbol];
    lbMaxNumber.textAlignment = NSTextAlignmentRight;
    lbMaxNumber.textColor = theme.textColorNormal;
    
    UILabel* lbTotalTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbTotalTitle.text = bUserBuy ? @"购买金额" : @"出售金额";
    lbTotalTitle.textAlignment = NSTextAlignmentLeft;
    lbTotalTitle.textColor = theme.textColorMain;
    
    UILabel* lbTotalLimited = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    lbTotalLimited.text = [NSString stringWithFormat:@"%@ %@%@ - %@%@", @"限额",
                           fiat_symbol, _adInfo[@"lowestLimit"], fiat_symbol, _adInfo[@"maxLimit"]];
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
    
    //  UI - 输入框末尾按钮
    _tfNumber.rightView = [self genTailerView:asset_symbol action:bUserBuy ? @"全部买入" : @"全部出售" tag:0];//TODO:2.9
    _tfNumber.rightViewMode = UITextFieldViewModeAlways;
    _tfTotal.rightView = [self genTailerView:fiat_symbol action:bUserBuy ? @"最大金额" : @"最大金额" tag:0];//TODO:2.9 fiat currency
    _tfTotal.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 交易数量
    UILabel* tradeAmount = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    tradeAmount.text = [NSString stringWithFormat:@"%@ %@ %@", @"交易数量", @"2333", asset_symbol];
    tradeAmount.textAlignment = NSTextAlignmentRight;
    tradeAmount.textColor = theme.textColorMain;
    
    //  UI - 实付款/实际到账
    UILabel* finalTotalTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:content];
    UILabel* finalTotalValue = [self auxGenLabel:[UIFont boldSystemFontOfSize:18.0f] superview:content];
    finalTotalTitle.text = bUserBuy ? @"实际付款" : @"实际到账";
    finalTotalTitle.textAlignment = NSTextAlignmentLeft;
    
    finalTotalValue.text = [NSString stringWithFormat:@"%@%@", fiat_symbol, @"534535"];//TODO:2.9 teatdata
    finalTotalValue.textColor = theme.textColorHighlight;
    finalTotalValue.textAlignment = NSTextAlignmentRight;
    
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
    
    //  自动关闭计时
    _autoCloseStartTs = ceil([[NSDate date] timeIntervalSince1970]);
    [self startAutoCloseTimer];
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
- (void)onButtomAutoCancelClicked
{
    [self stopAutoCloseTimer];
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

/*
 *  处理自动关闭定时器
 */
- (void)startAutoCloseTimer
{
    if (!_autoCloseTimer){
        _autoCloseTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                           target:self
                                                         selector:@selector(onAutoCloseTimerTick)
                                                         userInfo:nil
                                                          repeats:YES];
        [_autoCloseTimer fire];
    }
}

- (void)stopAutoCloseTimer
{
    if (_autoCloseTimer){
        [_autoCloseTimer invalidate];
        _autoCloseTimer = nil;
    }
}

- (void)onAutoCloseTimerTick
{
    NSTimeInterval ts = ceil([[NSDate date] timeIntervalSince1970]);
    NSInteger left_ts = (NSInteger)(_autoCloseStartTs + _autoCloseSeconds - ts);
    if (left_ts <= 0) {
        //  自动关闭
        [self onButtomAutoCancelClicked];
    } else {
        //  刷新 TODO:2.9 多语言
        [_autoCloseButton setTitle:[NSString stringWithFormat:@"%@%@", @(left_ts), @"秒后自动取消"] forState:UIControlStateNormal];
    }
}

#pragma mark- UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    //  TODO:2.9
//    [self onSubmitClicked];
    return YES;
}

@end
