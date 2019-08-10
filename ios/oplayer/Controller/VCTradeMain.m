//
//  VCTradeMain.m
//  oplayer
//
//  Created by SYALON on 14-1-12.
//
//

#import "VCTradeMain.h"
#import "VCTradeHor.h"
#import "VCTransactionConfirm.h"
#import "VCImportAccount.h"
#import "WalletManager.h"
#import "ViewMarketTickerInfoCell.h"
#import "ViewTextFieldOwner.h"
#import "BitsharesClientManager.h"
#import "ViewBidAskCell.h"
#import "ViewAvailableAndFeeCell.h"
#import "ViewLimitOrderInfoCell.h"
#import "ViewEmptyInfoCell.h"
#import "AppCacheManager.h"
#import "VerticalAlignmentLabel.h"
#import "OrgUtils.h"
#import "TradingPair.h"
#import "ScheduleManager.h"

/**
 *  最新价格         高 xxx
 *  ～估算 涨幅      低  xxx
 *                 24H 量
 *  买盘            卖盘
 *  。。。。。。。。。。。
 *  买入/卖出
 *  BASE价（出的单价）
 *  QUOTE量（买的总数量）
 *  ----main button --
 */

enum
{
    kVcFormData = 0,            //  表单数据
    kVcFormAction,              //  表单行为：买卖按钮
    kVcFormUserOrder,           //  [可选] 当前委托，没登录则没有数据。
    
    kVcMainTableMax
};

enum
{
    kVcSubPriceCell = 0,        //  买入价
    kVcSubNumberCell,           //  买入量
    kVcSubTotalPrice,           //  交易额
    kVcSubAvailable,            //  可用余额
    
    kVcSubMax,
};

enum
{
    kTailerBtnTagBid1 = 0,      //  买1价
    kTailerBtnTagAsk1,          //  卖1价
    kTailerBtnTagPercent25,     //  25%
    kTailerBtnTagPercent50,     //  50%
    kTailerBtnTagPercent100,    //  100%
};

@interface VCTradeMain ()
{
    __weak VCTradeHor*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    TradingPair*                _tradingPair;
    NSDictionary*               _base;
    NSDictionary*               _quote;
    
    BOOL                        _isbuy;
    NSInteger                   _showOrderMaxNumber;    //  盘口 显示挂单行数
    CGFloat                     _showOrderLineHeight;   //  盘口 挂单行高
    
    VerticalAlignmentLabel*     _lbHeaderLatestPrice;
    VerticalAlignmentLabel*     _lbHeaderPercent;
    
    UITableViewBase*            _bidTableView;
    UITableViewBase*            _askTableView;
    
    UITableViewBase*            _mainTableView;
    MyTextField*                _tfPrice;
    MyTextField*                _tfNumber;
    MyTextField*                _tfTotal;               //  总成交金额
    ViewBlockLabel*             _lbBuyOrSell;
    ViewAvailableAndFeeCell*    _cellAvailable;         //  可用余额 & 交易手续费 cell
    
    ViewEmptyInfoCell*          _cellNoOrders;          //  无委托 cell
    
    NSMutableArray*             _bidDataArray;          //  买盘数据
    NSMutableArray*             _askDataArray;          //  卖盘数据
    NSDictionary*               _balanceData;           //  余额数据
    NSDecimalNumber*            _base_amount_n;         //  -> base 总资产总数量
    NSDecimalNumber*            _quote_amount_n;        //  -> quote 总资产数量
    
    NSMutableArray*             _userOrderDataArray;    //  用户当前委托数组
}

@end

@implementation VCTradeMain

- (void)dealloc
{
    _owner = nil;
    
    _base = nil;
    _quote = nil;
    
    _lbHeaderLatestPrice = nil;
    _lbHeaderPercent = nil;
    
    if (_bidTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_bidTableView];
        _bidTableView.delegate = nil;
        _bidTableView = nil;
    }
    if (_askTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_askTableView];
        _askTableView.delegate = nil;
        _askTableView = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    
    if (_tfPrice){
        _tfPrice.delegate = nil;
        _tfPrice = nil;
    }
    if (_tfNumber){
        _tfNumber.delegate = nil;
        _tfNumber = nil;
    }
    if (_tfTotal){
        _tfTotal.delegate = nil;
        _tfTotal = nil;
    }
    
    _cellAvailable = nil;
    _cellNoOrders = nil;
    
    _bidDataArray = nil;
    _askDataArray = nil;
    _balanceData = nil;
    _base_amount_n = nil;
    _quote_amount_n = nil;
}

- (id)initWithOwner:(VCTradeHor*)owner baseInfo:(NSDictionary*)base quoteInfo:(NSDictionary*)quote isbuy:(BOOL)isbuy
{
    self = [super init];
    if (self) {
        // Custom initialization
        _owner = owner;
        
        _tradingPair = [[TradingPair alloc] initWithBaseAsset:base quoteAsset:quote];
        
        _base = base;
        _quote = quote;
        
        _isbuy = isbuy;
        
        id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
        _showOrderMaxNumber = [[parameters objectForKey:@"order_book_num_trade"] integerValue] + 1;
        _showOrderLineHeight = 20.0f;   //  TODO:fowallet constants
        
        //  数据
        _balanceData = nil;
        _base_amount_n = nil;
        _quote_amount_n = nil;
        _bidDataArray = [NSMutableArray array];
        _askDataArray = [NSMutableArray array];
        
        _userOrderDataArray = [NSMutableArray array];
    }
    return self;
}

- (VerticalAlignmentLabel*)genHeaderViewLabel:(UIView*)parentView txt:(NSString*)string
{
    VerticalAlignmentLabel* label = [[VerticalAlignmentLabel alloc] initWithFrame:CGRectZero];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [ThemeManager sharedThemeManager].textColorMain;
    label.font = [UIFont systemFontOfSize:14];
    label.text = string;
    label.verticalAlignment = VerticalAlignmentBottom;
    [parentView addSubview:label];
    return label;
}

/**
 *  更新顶部最新价格和今日涨跌幅
 */
- (void)updateLatestPrice:(BOOL)isbuy
{
    NSString* latest;
    NSString* percent_change;
    NSDictionary* ticker_data = [[ChainObjectManager sharedChainObjectManager] getTickerData:[_base objectForKey:@"symbol"]
                                                                                       quote:[_quote objectForKey:@"symbol"]];
    if (ticker_data){
        latest = [OrgUtils formatFloatValue:[ticker_data[@"latest"] doubleValue] precision:_tradingPair.basePrecision];
        percent_change = [ticker_data objectForKey:@"percent_change"];
    }else{
        latest = @"--";
        percent_change = @"0";
    }
    
    if (latest){
        _lbHeaderLatestPrice.text = latest;
        if (isbuy){
            _lbHeaderLatestPrice.textColor = [ThemeManager sharedThemeManager].buyColor;
        }else{
            _lbHeaderLatestPrice.textColor = [ThemeManager sharedThemeManager].sellColor;
        }
        
        CGSize size1 = CGSizeMake(self.view.bounds.size.width, 9999);
        size1 = [latest sizeWithFont:_lbHeaderLatestPrice.font constrainedToSize:size1 lineBreakMode:UILineBreakModeWordWrap];
        
        CGSize origin_size = _lbHeaderPercent.bounds.size;
        _lbHeaderPercent.frame = CGRectMake(_lbHeaderLatestPrice.frame.origin.x + size1.width + 16, 0, origin_size.width, origin_size.height);
    }
    
    if (percent_change){
        double percent = [percent_change doubleValue];
        if (percent > 0.0f){
            _lbHeaderPercent.textColor = [ThemeManager sharedThemeManager].buyColor;
            _lbHeaderPercent.text = [NSString stringWithFormat:@"+%@%%", [OrgUtils formatFloatValue:percent precision:2]];
        }else if (percent < 0){
            _lbHeaderPercent.textColor = [ThemeManager sharedThemeManager].sellColor;
            _lbHeaderPercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2]];
        } else {
            _lbHeaderPercent.textColor = [ThemeManager sharedThemeManager].zeroColor;
            _lbHeaderPercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2]];
        }
    }
}

/**
 *  (private) 事件 - 数量百分比按钮点击
 */
- (void)processAmountPercentButtonClicked:(NSDecimalNumber*)n_percent
{
    if (!_balanceData){
        if (![[WalletManager sharedWalletManager] isWalletExist]){
            [OrgUtils makeToast:NSLocalizedString(@"kVcTradeTipPleaseLoginFirst", @"请先登录。")];
        }
        return;
    }
    
    if (_isbuy){
        //  买入：数量 = base的数量 / 单价    REMARK：如果单价为空则不处理。
        id str_price = _tfPrice.text;
        if (str_price && ![str_price isEqualToString:@""]){
            //  获取单价（<=0则不处理）
            NSDecimalNumber* n_price = [OrgUtils auxGetStringDecimalNumberValue:str_price];
            //  n_price > 0 判断
            if ([n_price compare:[NSDecimalNumber zero]] == NSOrderedDescending){
                //  !!! 精确计算 !!!
                
                //  保留小数位数 向下取整
                NSDecimalNumberHandler* floorHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                                              scale:_tradingPair.numPrecision
                                                                                                   raiseOnExactness:NO
                                                                                                    raiseOnOverflow:NO
                                                                                                   raiseOnUnderflow:NO
                                                                                                raiseOnDivideByZero:NO];
                NSDecimalNumber* buy_amount = [_base_amount_n decimalNumberByDividingBy:n_price withBehavior:floorHandler];
                buy_amount = [buy_amount decimalNumberByMultiplyingBy:n_percent withBehavior:floorHandler];
                
                //  设置数量
                _tfNumber.text = [OrgUtils formatFloatValue:buy_amount usesGroupingSeparator:NO];
                [self onPriceOrAmountChanged];
            }
        }
    }else{
        //  卖出：数量 = quote 的数量。
        
        //  !!! 精确计算 !!!
        
        //  保留小数位数 向下取整
        NSDecimalNumberHandler* floorHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                                      scale:_tradingPair.numPrecision
                                                                                           raiseOnExactness:NO
                                                                                            raiseOnOverflow:NO
                                                                                           raiseOnUnderflow:NO
                                                                                        raiseOnDivideByZero:NO];
        id sell_amount = [_quote_amount_n decimalNumberByMultiplyingBy:n_percent withBehavior:floorHandler];
        
        //  设置数量
        _tfNumber.text = [OrgUtils formatFloatValue:sell_amount usesGroupingSeparator:NO];
        [self onPriceOrAmountChanged];
    }
}

- (void)onAmountPercentButtonClicked:(UIButton*)sender
{
    switch (sender.tag) {
        case kTailerBtnTagBid1:
        {
            id data = [_bidDataArray safeObjectAtIndex:0];
            if (data){
                _tfPrice.text = [OrgUtils formatFloatValue:[[data objectForKey:@"price"] doubleValue]
                                                  precision:_tradingPair.displayPrecision
                                     usesGroupingSeparator:NO];
                [self onPriceOrAmountChanged];
            }
        }
            break;
        case kTailerBtnTagAsk1:
        {
            id data = [_askDataArray safeObjectAtIndex:0];
            if (data){
                _tfPrice.text = [OrgUtils formatFloatValue:[[data objectForKey:@"price"] doubleValue]
                                                  precision:_tradingPair.displayPrecision
                                     usesGroupingSeparator:NO];
                [self onPriceOrAmountChanged];
            }
        }
            break;
        case kTailerBtnTagPercent25:
            [self processAmountPercentButtonClicked:[NSDecimalNumber decimalNumberWithString:@"0.25"]];
            break;
        case kTailerBtnTagPercent50:
            [self processAmountPercentButtonClicked:[NSDecimalNumber decimalNumberWithString:@"0.5"]];
            break;
        case kTailerBtnTagPercent100:
            [self processAmountPercentButtonClicked:[NSDecimalNumber one]];
            break;
        default:
            break;
    }
}
- (UIButton*)genButtonForTailer:(NSString*)percent_name tag:(NSInteger)tag frame:(CGRect)frame
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn setTitle:percent_name forState:UIControlStateNormal];
    [btn setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onAmountPercentButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
//    btn.layer.borderWidth = 1;
//    btn.layer.borderColor = [UIColor lightGrayColor].CGColor;
//    btn.layer.cornerRadius = 1.0f;
//    btn.layer.masksToBounds = YES;
    btn.frame = frame;
    btn.tag = tag;  //  REMARK：绑定tag标记
    return btn;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor clearColor];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat fScreenWidth = screenRect.size.width;
    CGFloat fHalfWidth = fScreenWidth / 2.0f;
    
    CGFloat fHeaderLineHeight = 36.0f;
    
    //  REMARK：header view中，由于没有 最高、最低数据，暂时取消这2个字段，以后统计k线数据后再考虑添加。
    CGRect topHeaderRect = CGRectMake(0, 0, fScreenWidth, fHeaderLineHeight);
    UIView* topHeaderView = [[UIView alloc] initWithFrame:topHeaderRect];
    topHeaderView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:topHeaderView];
    
    _lbHeaderLatestPrice = [self genHeaderViewLabel:topHeaderView txt:@""];
    _lbHeaderLatestPrice.frame = CGRectMake(16, 0, fHalfWidth, fHeaderLineHeight - 4);
    _lbHeaderLatestPrice.font = [UIFont boldSystemFontOfSize:24];
    
    _lbHeaderPercent = [self genHeaderViewLabel:topHeaderView txt:@""];
    _lbHeaderPercent.frame = CGRectMake(fHalfWidth, 0, fHalfWidth, fHeaderLineHeight - 8);
    _lbHeaderPercent.font = [UIFont systemFontOfSize:14];
    
    //  更新最新成交价格
    [self updateLatestPrice:YES];
    
    //  买卖盘口
    CGRect bidRect = CGRectMake(0, topHeaderRect.size.height, screenRect.size.width/2.0f, _showOrderMaxNumber * _showOrderLineHeight);
    _bidTableView = [[UITableViewBase alloc] initWithFrame:bidRect style:UITableViewStylePlain];
    _bidTableView.delegate = self;
    _bidTableView.dataSource = self;
    _bidTableView.showsVerticalScrollIndicator = NO;
    _bidTableView.scrollEnabled = NO;
    _bidTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _bidTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_bidTableView];
    _bidTableView.hideAllLines = YES;
    
    CGRect askRect = CGRectMake(screenRect.size.width/2.0f, topHeaderRect.size.height, screenRect.size.width/2.0f, _showOrderMaxNumber * _showOrderLineHeight);
    _askTableView = [[UITableViewBase alloc] initWithFrame:askRect style:UITableViewStylePlain];
    _askTableView.delegate = self;
    _askTableView.dataSource = self;
    _askTableView.showsVerticalScrollIndicator = NO;
    _askTableView.scrollEnabled = NO;
    _askTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _askTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_askTableView];
    _askTableView.hideAllLines = YES;
    
    //  下面买卖cell表格
    CGFloat fContentIntervalSpace = 12.0f;  //  REMARK：各内容块之间间距。
    CGFloat offset = bidRect.origin.y + bidRect.size.height + fContentIntervalSpace;
    CGRect rect = CGRectMake(0, offset, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - 32 - offset - [self heightForBottomSafeArea]);
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    [self.view addSubview:_mainTableView];
//    _mainTableView.hideAllLines = YES;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    
    NSString* pricePlaceHolder = nil;
    NSString* numberPlaceHolder = nil;
    if (_isbuy){
        pricePlaceHolder = NSLocalizedString(@"kPlaceHolderBuyPrice", @"买入单价");
        numberPlaceHolder = NSLocalizedString(@"kPlaceHolderBuyAmount", @"买入数量");
    }else{
        pricePlaceHolder = NSLocalizedString(@"kPlaceHolderSellPrice", @"卖出单价");
        numberPlaceHolder = NSLocalizedString(@"kPlaceHolderSellAmount", @"卖出数量");
    }
    NSString* totalPlaceHolder = NSLocalizedString(@"kLableTotalPrice", @"交易额");
    
    CGRect tfrect = [self makeTextFieldRectFull];
    _tfPrice = [self createTfWithRect:tfrect keyboard:UIKeyboardTypeDecimalPad placeholder:pricePlaceHolder];
    _tfPrice.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tfPrice.showBottomLine = YES;
    _tfNumber = [self createTfWithRect:tfrect keyboard:UIKeyboardTypeDecimalPad placeholder:numberPlaceHolder];
    _tfNumber.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tfNumber.showBottomLine = YES;
    
    _tfTotal = [self createTfWithRect:tfrect keyboard:UIKeyboardTypeDecimalPad placeholder:totalPlaceHolder];
    _tfTotal.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tfTotal.showBottomLine = YES;
    
    _tfPrice.attributedPlaceholder = [[NSAttributedString alloc] initWithString:pricePlaceHolder
                                                                     attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                  NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tfNumber.attributedPlaceholder = [[NSAttributedString alloc] initWithString:numberPlaceHolder
                                                                      attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                   NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    _tfTotal.attributedPlaceholder = [[NSAttributedString alloc] initWithString:totalPlaceHolder
                                                                      attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                   NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    //  绑定输入事件（限制输入）
    [_tfPrice addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_tfNumber addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_tfTotal addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 买卖价格尾部辅助按钮
    UIView* price_tailer_view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200 + 14, 31)];
    //  subview 1
    UILabel* tailer_price = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 31)];
    tailer_price.lineBreakMode = NSLineBreakByTruncatingTail;
    tailer_price.numberOfLines = 1;
    tailer_price.textAlignment = NSTextAlignmentRight;
    tailer_price.backgroundColor = [UIColor clearColor];
    tailer_price.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    tailer_price.font = [UIFont systemFontOfSize:14];
    tailer_price.text = [_base objectForKey:@"symbol"];
    //  subview 2、3
    UIButton* btn5 = [self genButtonForTailer:NSLocalizedString(@"kTailerBtnBid1", @"买一价") tag:kTailerBtnTagBid1 frame:CGRectMake(80 + 6, 2, 62, 27)];
    UIButton* btn6 = [self genButtonForTailer:NSLocalizedString(@"kTailerBtnAsk1", @"卖一价") tag:kTailerBtnTagAsk1 frame:CGRectMake(140 + 12, 2, 62, 27)];
    [price_tailer_view addSubview:tailer_price];
    [price_tailer_view addSubview:btn5];
    [price_tailer_view addSubview:btn6];
    _tfPrice.rightView = price_tailer_view;
    _tfPrice.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 买卖数量尾部辅助按钮 REMARK：asset + 6 + 25% + 4 + 50% + 4 + 100
    UIView* amount_tailer_view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200 + 14, 31)];
    //  subview 1
    UILabel* tailer_num = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 31)];
    tailer_num.lineBreakMode = NSLineBreakByTruncatingTail;
    tailer_num.numberOfLines = 1;
    tailer_num.textAlignment = NSTextAlignmentRight;
    tailer_num.backgroundColor = [UIColor clearColor];
    tailer_num.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    tailer_num.font = [UIFont systemFontOfSize:14];
    tailer_num.text = [_quote objectForKey:@"symbol"];
    //  subview 2、3、4
    UIButton* btn1 = [self genButtonForTailer:@"25%" tag:kTailerBtnTagPercent25 frame:CGRectMake(80 + 6, 2, 40, 27)];
    UIButton* btn2 = [self genButtonForTailer:@"50%" tag:kTailerBtnTagPercent50 frame:CGRectMake(120 + 10, 2, 40, 27)];
    UIButton* btn3 = [self genButtonForTailer:@"100%" tag:kTailerBtnTagPercent100 frame:CGRectMake(160 + 14, 2, 40, 27)];
    [amount_tailer_view addSubview:tailer_num];
    [amount_tailer_view addSubview:btn1];
    [amount_tailer_view addSubview:btn2];
    [amount_tailer_view addSubview:btn3];
    _tfNumber.rightView = amount_tailer_view;
    _tfNumber.rightViewMode = UITextFieldViewModeAlways;
    
    //  交易额末尾单位
    UILabel* tailer_total_price = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 31)];
    tailer_total_price.lineBreakMode = NSLineBreakByTruncatingTail;
    tailer_total_price.numberOfLines = 1;
    tailer_total_price.textAlignment = NSTextAlignmentRight;
    tailer_total_price.backgroundColor = [UIColor clearColor];
    tailer_total_price.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    tailer_total_price.font = [UIFont systemFontOfSize:14];
    tailer_total_price.text = [_base objectForKey:@"symbol"];
    _tfTotal.rightView = tailer_total_price;
    _tfTotal.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 可用余额 & 手续费 CELL
    _cellAvailable = [[ViewAvailableAndFeeCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellAvailable.backgroundColor = [UIColor clearColor];
    _cellAvailable.hideTopLine = YES;
    _cellAvailable.hideBottomLine = YES;
    [self draw_ui_available_value:nil enough:YES];
    [_cellAvailable draw_market_fee:_isbuy ? _tradingPair.quoteAsset : _tradingPair.baseAsset account:nil];
    
    NSString* cell_btn_name = nil;
    if ([[WalletManager sharedWalletManager] isWalletExist]){
        if (_isbuy){
            cell_btn_name = [NSString stringWithFormat:@"%@%@", NSLocalizedString(@"kBtnBuy", @"买入"), [_quote objectForKey:@"symbol"]];
        }else{
            cell_btn_name = [NSString stringWithFormat:@"%@%@", NSLocalizedString(@"kBtnSell", @"卖出"), [_quote objectForKey:@"symbol"]];
        }
    }else{
        cell_btn_name = NSLocalizedString(@"kNormalCellBtnLogin", @"登录");
    }
    if (_isbuy){
        _lbBuyOrSell = [self createCellLableButton:cell_btn_name];
        UIColor* color = [ThemeManager sharedThemeManager].buyColor;
        _lbBuyOrSell.layer.borderColor = color.CGColor;
        _lbBuyOrSell.layer.backgroundColor = color.CGColor;
    }else{
        _lbBuyOrSell = [self createCellLableButton:cell_btn_name];
        UIColor* color = [ThemeManager sharedThemeManager].sellColor;
        _lbBuyOrSell.layer.borderColor = color.CGColor;
        _lbBuyOrSell.layer.backgroundColor = color.CGColor;
    }
    
    //  UI - 没有委托的空CELL
    _cellNoOrders = [[ViewEmptyInfoCell alloc] initWithText:NSLocalizedString(@"kLabelNoOrder", @"暂无记录") iconName:@"iconOrders"];
    _cellNoOrders.hideTopLine = YES;
    _cellNoOrders.hideBottomLine = YES;
}

- (void)draw_ui_available_value:(NSString*)value enough:(BOOL)enough
{
    [_cellAvailable draw_available:value enough:enough isbuy:_isbuy tradingPair:_tradingPair];
}

#pragma mark- parent call

/**
 *  (private) 生成当前交易对下的当前委托数据
 */
- (NSMutableArray*)genCurrentLimitOrderData:(NSArray*)limit_orders
{
    NSMutableArray* dataArray = [NSMutableArray array];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    for (id order in limit_orders) {
        id sell_price = [order objectForKey:@"sell_price"];
        id base = [sell_price objectForKey:@"base"];
        id quote = [sell_price objectForKey:@"quote"];
        id base_id = base[@"asset_id"];
        id quote_id = quote[@"asset_id"];
        
        BOOL issell;
        if ([base_id isEqualToString:_tradingPair.baseId] && [quote_id isEqualToString:_tradingPair.quoteId]){
            //  买单：卖出 CNY
            issell = NO;
        }else if ([base_id isEqualToString:_tradingPair.quoteId] && [quote_id isEqualToString:_tradingPair.baseId]){
            //  卖单：卖出 BTS
            issell = YES;
        }else{
            //  其他交易对的订单
            continue;
        }

        id base_asset = [chainMgr getChainObjectByID:base_id];
        id quote_asset = [chainMgr getChainObjectByID:quote_id];
        assert(base_asset);
        assert(quote_asset);
        
        NSInteger base_precision = [[base_asset objectForKey:@"precision"] integerValue];
        NSInteger quote_precision = [[quote_asset objectForKey:@"precision"] integerValue];
        double base_value = [OrgUtils calcAssetRealPrice:base[@"amount"] precision:base_precision];
        double quote_value = [OrgUtils calcAssetRealPrice:quote[@"amount"] precision:quote_precision];

        double price;
        NSString* price_str;
        NSString* amount_str;
        NSString* total_str;
        NSString* base_sym;
        NSString* quote_sym;
        //  REMARK: base 是卖出的资产，除以 base 则为卖价(每1个 base 资产的价格)。反正 base / quote 则为买入价。
        if (!issell){
            //  buy     price = base / quote
            price = base_value / quote_value;
            price_str = [OrgUtils formatFloatValue:price precision:base_precision];
            double total_real = [OrgUtils calcAssetRealPrice:order[@"for_sale"] precision:base_precision];
            double amount_real = total_real / price;
            amount_str = [OrgUtils formatFloatValue:amount_real precision:quote_precision];
            total_str = [OrgUtils formatAssetString:order[@"for_sale"] precision:base_precision];
            base_sym = [base_asset objectForKey:@"symbol"];
            quote_sym = [quote_asset objectForKey:@"symbol"];
        }else{
            //  sell    price = quote / base
            price = quote_value / base_value;
            price_str = [OrgUtils formatFloatValue:price precision:quote_precision];
            //            amount_str = [OrgUtils formatAmountString:order[@"for_sale"] asset:base_asset];
            amount_str = [OrgUtils formatAssetString:order[@"for_sale"] precision:base_precision];
            double for_sale_real = [OrgUtils calcAssetRealPrice:order[@"for_sale"] precision:base_precision];
            double total_real = price * for_sale_real;
            total_str = [OrgUtils formatFloatValue:total_real precision:quote_precision];
            base_sym = [quote_asset objectForKey:@"symbol"];
            quote_sym = [base_asset objectForKey:@"symbol"];
        }
        //  REMARK：特殊处理，如果按照 base or quote 的精度格式化出价格为0了，则扩大精度重新格式化。
        if ([price_str isEqualToString:@"0"]){
            price_str = [OrgUtils formatFloatValue:price precision:8];
        }

        [dataArray addObject:@{@"time":order[@"expiration"],
                               @"issell":@(issell),
                               @"price":price_str,
                               @"amount":amount_str,
                               @"total":total_str,
                               @"base_symbol":base_sym,
                               @"quote_symbol":quote_sym,
                               @"id": order[@"id"],
                               @"seller": order[@"seller"],
                               @"raw_order":order   //  原始数据
                               }];
    }
    //  按照ID降序排列
    [dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [[obj2 objectForKey:@"id"] compare:[obj1 objectForKey:@"id"]];
    })];
    return dataArray;
}

- (NSDictionary*)genBalanceInfos:(NSDictionary*)full_account_data
{
    id base_id = [_base objectForKey:@"id"];
    id quote_id = [_quote objectForKey:@"id"];
    
    NSMutableArray* new_balances_array = [NSMutableArray array];
    NSDictionary* base_balance = nil;
    NSDictionary* quote_balance = nil;
    
    //  初始化 base_balance 和 quote_balance 信息，并统计余额信息。（REMARK：get_account_balances 和 get_full_accounts 的余额信息 key 不一致。）
    id balances_array = [full_account_data objectForKey:@"balances"];
    NSInteger found_inc = 0;
    for (id balance in balances_array) {
        id asset_id = balance[@"asset_type"];
        id amount = balance[@"balance"];
        
        //  统一余额等 key 为：asset_id 和 amount。
        [new_balances_array addObject:@{@"asset_id":asset_id, @"amount":amount}];
        
        //  初始化 base 和 quote
        if (found_inc < 2){
            if ([asset_id isEqualToString:base_id]){
                base_balance = [new_balances_array lastObject];
                ++found_inc;
            }else if ([asset_id isEqualToString:quote_id]){
                quote_balance = [new_balances_array lastObject];
                ++found_inc;
            }
        }
    }
    
    //  用户没有对应的资产，则初始化默认值为 0。
    if (!base_balance){
        base_balance = @{@"asset_id":base_id, @"amount":@0};
    }
    if (!quote_balance){
        quote_balance = @{@"asset_id":quote_id, @"amount":@0};
    }
    
    //  计算手续费对象（如果手续资产是base或者quote之一，则更新资产的可用余额，即减去手续费需要的amount）
    id fee_item = [[ChainObjectManager sharedChainObjectManager] estimateFeeObject:ebo_limit_order_create
                                                                          balances:new_balances_array];
    id fee_asset_id = [fee_item objectForKey:@"fee_asset_id"];
    if ([fee_asset_id isEqualToString:base_id]){
        id new_balance = [base_balance mutableCopy];
        unsigned long long old = [[new_balance objectForKey:@"amount"] unsignedLongLongValue];
        unsigned long long fee = [[fee_item objectForKey:@"amount"] unsignedLongLongValue];
        if (old >= fee){
            [new_balance setObject:@(old - fee) forKey:@"amount"];
        }else{
            [new_balance setObject:@0 forKey:@"amount"];
        }
        [new_balance setObject:@(old) forKey:@"total_amount"];
        base_balance = [new_balance copy];
    }else if ([fee_asset_id isEqualToString:quote_id]){
        id new_balance = [quote_balance mutableCopy];
        unsigned long long old = [[new_balance objectForKey:@"amount"] unsignedLongLongValue];
        unsigned long long fee = [[fee_item objectForKey:@"amount"] unsignedLongLongValue];
        if (old >= fee){
            [new_balance setObject:@(old - fee) forKey:@"amount"];
        }else{
            [new_balance setObject:@0 forKey:@"amount"];
        }
        [new_balance setObject:@(old) forKey:@"total_amount"];
        quote_balance = [new_balance copy];
    }
    
    //  构造余额信息 {base:{asset_id, amount}, quote:{asset_id, amount}, all_balances:[{asset_id, amount}, ...], fee_item:{...}}
    return @{@"base":base_balance,
             @"quote":quote_balance,
             @"all_balances":[new_balances_array copy],
             @"fee_item":fee_item,
             @"full_account_data":full_account_data};
}

/**
 *  事件 - 用户数据刷新
 */
- (void)onFullAccountDataResponsed:(id)full_account_data
{
    //  未登录的情况，待处理。TODO:fowallet
    if (!full_account_data){
        return;
    }
    
    //  1、保存余额信息、同步更新 base 数量 和 quote 数量。
    assert(full_account_data);
    _balanceData = [self genBalanceInfos:full_account_data];
    //  !!! 一定要同步更新 ！！！
    _base_amount_n = [NSDecimalNumber decimalNumberWithMantissa:[[[_balanceData objectForKey:@"base"] objectForKey:@"amount"] unsignedLongLongValue]
                                                       exponent:-_tradingPair.basePrecision isNegative:NO];
    _quote_amount_n = [NSDecimalNumber decimalNumberWithMantissa:[[[_balanceData objectForKey:@"quote"] objectForKey:@"amount"] unsignedLongLongValue]
                                                        exponent:-_tradingPair.quotePrecision isNegative:NO];
    
    //  刷新余额显示  买：显示 base 余额    卖：显示 quote 余额
    if (_isbuy){
        [self draw_ui_available_value:[OrgUtils formatAssetString:[[_balanceData objectForKey:@"base"] objectForKey:@"amount"] precision:_tradingPair.basePrecision]
                               enough:YES];
    }else{
        [self draw_ui_available_value:[OrgUtils formatAssetString:[[_balanceData objectForKey:@"quote"] objectForKey:@"amount"] precision:_tradingPair.quotePrecision]
                               enough:YES];
        
    }
    
    //  刷新手续费信息
    [_cellAvailable draw_market_fee:_isbuy ? _tradingPair.quoteAsset : _tradingPair.baseAsset
                            account:[full_account_data objectForKey:@"account"]];
    
    //  2、刷新交易额、可用余额等
    [self onPriceOrAmountChanged];
    
    //  3、当前委托信息
    if (_userOrderDataArray){
        [_userOrderDataArray removeAllObjects];
    }
    _userOrderDataArray = [self genCurrentLimitOrderData:[full_account_data objectForKey:@"limit_orders"]];
    
    //  3.1、订阅委托状态变化
    id order_ids = [_userOrderDataArray ruby_map:(^id(id order) {
        return order[@"id"];
    })];
    id account_id = [[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"id"];
    assert(account_id);
    [[ScheduleManager sharedScheduleManager] sub_market_monitor_orders:_tradingPair order_ids:order_ids account_id:account_id];
    
    //  4、刷新界面
    [_mainTableView reloadData];
}

- (void)onQueryOrderBookResponse:(id)merged_order_book
{
    //  更新显示精度
    [_tradingPair dynamicUpdateDisplayPrecision:merged_order_book];
    
    [_bidDataArray removeAllObjects];
    [_bidDataArray addObjectsFromArray:[merged_order_book objectForKey:@"bids"]];
    
    [_askDataArray removeAllObjects];
    [_askDataArray addObjectsFromArray:[merged_order_book objectForKey:@"asks"]];
    
    [_bidTableView reloadData];
    [_askTableView reloadData];
    
    //  价格输入框没有值的情况设置默认值 买界面-默认卖1价格 卖界面-默认买1价（参考huobi）
    id str_price = _tfPrice.text;
    if (!str_price || [str_price isEqualToString:@""]){
        id data = nil;
        if (_isbuy){
            data = [_askDataArray safeObjectAtIndex:0];
        }else{
            data = [_bidDataArray safeObjectAtIndex:0];
        }
        if (data){
            _tfPrice.text = [OrgUtils formatFloatValue:[[data objectForKey:@"price"] doubleValue]
                                              precision:_tradingPair.displayPrecision
                                 usesGroupingSeparator:NO];
            [self onPriceOrAmountChanged];
        }
    }
}

/**
 *  事件 - ticker数据更新
 */
- (void)onQueryTickerDataResponse:(id)data
{
    [self updateLatestPrice:YES];
}

/**
 *  事件 - 成交历史数据更新
 */
- (void)onQueryFillOrderHistoryResponsed:(id)data_array
{
    if (!data_array || [data_array count] <= 0){
        return;
    }
    //  更新最新成交价
    [self updateLatestPrice:![[[data_array firstObject] objectForKey:@"issell"] boolValue]];
}

/**
 *  事件 - 处理登录成功事件
 *  更改 登录按钮为 买卖按钮
 *  获取 个人信息
 */
- (void)onRefreshLoginStatus
{
    if (_isbuy){
        _lbBuyOrSell.text = [NSString stringWithFormat:@"%@%@", NSLocalizedString(@"kBtnBuy", @"买入"), [_quote objectForKey:@"symbol"]];
    }else{
        _lbBuyOrSell.text = [NSString stringWithFormat:@"%@%@", NSLocalizedString(@"kBtnSell", @"卖出"), [_quote objectForKey:@"symbol"]];
    }
}

- (void)resignAllFirstResponder
{
    [self.view endEditing:YES];
    [_tfNumber safeResignFirstResponder];
    [_tfPrice safeResignFirstResponder];
    [_tfTotal safeResignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != _tfPrice && textField != _tfNumber && textField != _tfTotal){
        return YES;
    }
    
    //  根据输入框不同，限制不同小数点位数。
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:textField == _tfNumber ? _tradingPair.numPrecision : _tradingPair.displayPrecision];
}

- (void)onTextFieldDidChange:(UITextField*)textField
{
    if (textField != _tfPrice && textField != _tfNumber && textField != _tfTotal){
        return;
    }
    
    //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
    [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
    
    //  处理事件
    if (textField != _tfTotal){
        [self onPriceOrAmountChanged];
    }else{
        [self onTotalFieldChanged];
    }
}

/**
 *  (private) 输入交易额变化，重新计算交易数量or价格。
 */
- (void)onTotalFieldChanged
{
    if (!_balanceData){
        return;
    }
    
    id str_price = _tfPrice.text;
    NSDecimalNumber* n_price = [OrgUtils auxGetStringDecimalNumberValue:str_price];
    
    //  交易额变化：固定价格，重新计算数量。
    if ([n_price compare:[NSDecimalNumber zero]] > 0){
        id str_total = _tfTotal.text;
        NSDecimalNumber* n_total = [OrgUtils auxGetStringDecimalNumberValue:str_total];
        NSDecimalNumberHandler* roundHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                                      scale:_tradingPair.quotePrecision
                                                                                           raiseOnExactness:NO
                                                                                            raiseOnOverflow:NO
                                                                                           raiseOnUnderflow:NO
                                                                                        raiseOnDivideByZero:NO];
        NSDecimalNumber* n_amount = [n_total decimalNumberByDividingBy:n_price withBehavior:roundHandler];
        
        //  刷新可用余额
        if (_isbuy){
            [self draw_ui_available_value:[OrgUtils formatFloatValue:_base_amount_n] enough:[_base_amount_n compare:n_total] >= 0];
        }else{
            [self draw_ui_available_value:[OrgUtils formatFloatValue:_quote_amount_n] enough:[_quote_amount_n compare:n_amount] >= 0];
        }
        
        //  交易数量
        if (!str_total || [str_total isEqualToString:@""]){
            _tfNumber.text = @"";
        }else{
            _tfNumber.text = [OrgUtils formatFloatValue:n_amount usesGroupingSeparator:NO];
        }
    }else{
        //  价格为0时，交易数量为空。
        _tfNumber.text = @"";
    }
}

/**
 *  (private) 输入的价格 or 数量发生变化，评估交易额。
 */
- (void)onPriceOrAmountChanged
{
    if (!_balanceData){
        return;
    }
    
    id str_price = _tfPrice.text;
    id str_amount = _tfNumber.text;
    
    //  获取单价、数量，然后计算交易额总价。
    
    //  !!! 精确计算 !!!
    NSDecimalNumber* n_price = [OrgUtils auxGetStringDecimalNumberValue:str_price];
    NSDecimalNumber* n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    
    //  保留小数位数 买入行为：总金额向上取整 卖出行为：向下取整
    NSDecimalNumberHandler* roundHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:_isbuy ? NSRoundUp : NSRoundDown
                                                                                                  scale:_tradingPair.basePrecision
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];
    NSDecimalNumber* n_total = [n_price decimalNumberByMultiplyingBy:n_amount withBehavior:roundHandler];
    
    //  刷新可用余额
    if (_isbuy){
        [self draw_ui_available_value:[OrgUtils formatFloatValue:_base_amount_n] enough:[_base_amount_n compare:n_total] >= 0];
    }else{
        [self draw_ui_available_value:[OrgUtils formatFloatValue:_quote_amount_n] enough:[_quote_amount_n compare:n_amount] >= 0];
    }
    
    //  总金额
    if (!str_price || [str_price isEqualToString:@""] || !str_amount || [str_amount isEqualToString:@""]){
        _tfTotal.text = @"";
    }else{
        _tfTotal.text = [OrgUtils formatFloatValue:n_total usesGroupingSeparator:NO];
    }
}

#pragma mark- TableView delegate method

- (NSMutableArray*)getDataArrayFromTableView:(UITableView*)tableView
{
    return tableView == _bidTableView ? _bidDataArray : _askDataArray;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_balanceData){
        return kVcMainTableMax;
    }else{
        //  未登录则没有当前委托信息
        return kVcMainTableMax - 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == _mainTableView){
        switch (section) {
            case kVcFormData:
                return kVcSubMax;
            case kVcFormAction:
                return 1;
            case kVcFormUserOrder:
                if ([_userOrderDataArray count] <= 0){
                    //  Empty Cell
                    return 1;
                }else{
                    return [_userOrderDataArray count];
                }
            default:
                break;
        }
        //  not reached...
        return 1;
    }
    //  REMARK：显示固定行数，即使数据不存在。
    return _showOrderMaxNumber;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _mainTableView){
        if (indexPath.section == kVcFormData && indexPath.row == kVcSubAvailable){
            return tableView.rowHeight;     //  REMARK：可用余额
        }
        if (indexPath.section == kVcFormUserOrder){
            if ([_userOrderDataArray count] <= 0){
                //  Empty Cell
                return 60.0f;
            }else{
                return 8.0 + 28 + 24 * 2;   //  当前委托 高度参考 VCUserOrders 界面。
            }
        }
        return tableView.rowHeight;
    }
    return _showOrderLineHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == kVcFormUserOrder){
        return 64.0f;
    }else{
        return 0.01f;
    }
}

/**
 *  (private) 查看全部订单按钮点击
 */
- (void)onAllOrderButtonClicked:(UIButton*)sender
{
    if (!_owner){
        return;
    }
    [self GuardWalletExist:^{
        id uid = [[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"id"];
        [VCCommonLogic viewUserLimitOrders:_owner account:uid tradingPair:_tradingPair];
    }];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == kVcFormUserOrder){
        CGFloat fWidth = self.view.bounds.size.width;
        CGFloat xOffset = tableView.layoutMargins.left;
        UIView* myView = [[UIView alloc] init];
        myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 64)];
        titleLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:20];
        titleLabel.text = NSLocalizedString(@"kLabelOpenOrders", @"当前委托");
        [myView addSubview:titleLabel];

        UIButton* allOrderButton = [UIButton buttonWithType:UIButtonTypeCustom];
        allOrderButton.frame = CGRectMake(fWidth - xOffset - 120, 0, 120, 64);
        allOrderButton.backgroundColor = [UIColor clearColor];
        [allOrderButton setTitle:NSLocalizedString(@"kLabelAllOrders", @"全部") forState:UIControlStateNormal];
        [allOrderButton setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
        allOrderButton.titleLabel.font = [UIFont systemFontOfSize:16.0];
        allOrderButton.userInteractionEnabled = YES;
        allOrderButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [allOrderButton addTarget:self action:@selector(onAllOrderButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [myView addSubview:allOrderButton];
        
        return myView;
    }else{
        return [[UIView alloc] init];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _mainTableView){
        switch (indexPath.section) {
            case kVcFormData:
            {
                switch (indexPath.row) {
                    case kVcSubPriceCell:
                    {
                        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                        cell.backgroundColor = [UIColor clearColor];
                        cell.accessoryType = UITableViewCellAccessoryNone;
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.textLabel.text = @" ";
                        [_mainTableView attachTextfieldToCell:cell tf:_tfPrice];
                        return cell;
                    }
                        break;
                    case kVcSubNumberCell:
                    {
                        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                        cell.backgroundColor = [UIColor clearColor];
                        cell.accessoryType = UITableViewCellAccessoryNone;
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.textLabel.text = @" ";
                        [_mainTableView attachTextfieldToCell:cell tf:_tfNumber];
                        return cell;
                    }
                        break;
                    case kVcSubAvailable:
                    {
                        return _cellAvailable;
                    }
                        break;
                    case kVcSubTotalPrice:
                    {
                        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                        cell.backgroundColor = [UIColor clearColor];
                        cell.accessoryType = UITableViewCellAccessoryNone;
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.textLabel.text = @" ";
                        [_mainTableView attachTextfieldToCell:cell tf:_tfTotal];
                        return cell;
                        
                    }
                        break;
                    default:
                        break;
                }
            }
                break;
            case kVcFormAction:
            {
                //  买入/卖出/登录
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.hideBottomLine = YES;
                cell.hideTopLine = YES;
                cell.backgroundColor = [UIColor clearColor];
                [self addLabelButtonToCell:_lbBuyOrSell cell:cell leftEdge:tableView.layoutMargins.left];
                return cell;
            }
                break;
            case kVcFormUserOrder:
            {
                if ([_userOrderDataArray count] <= 0){
                    //  Empty Cell
                    return _cellNoOrders;
                }else{
                    static NSString* identify = @"id_trading_limitorders";
                    ViewLimitOrderInfoCell* cell = (ViewLimitOrderInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
                    if (!cell)
                    {
                        cell = [[ViewLimitOrderInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    cell.showCustomBottomLine = YES;
                    [cell setTagData:indexPath.row];
                    [cell setItem:[_userOrderDataArray objectAtIndex:indexPath.row]];
                    return cell;
                }
            }
                break;
            default:
                break;
        }
        
        //  not reached...
        return nil;
    }
    
    BOOL isbuy = tableView == _bidTableView;
    
    ViewBidAskCell* cell = nil;
    
    if (isbuy)
    {
        static NSString* bid_identify = @"id_bid_identify";
        
        cell = (ViewBidAskCell *)[tableView dequeueReusableCellWithIdentifier:bid_identify];
        if (!cell)
        {
            cell = [[ViewBidAskCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:bid_identify isbuy:isbuy];
//            cell.backgroundColor = [ThemeManager sharedThemeManager].contentBackColor;
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    else
    {
        static NSString* ask_identify = @"id_ask_identify";
        
        cell = (ViewBidAskCell *)[tableView dequeueReusableCellWithIdentifier:ask_identify];
        if (!cell)
        {
            cell = [[ViewBidAskCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:ask_identify isbuy:isbuy];
//            cell.backgroundColor = [ThemeManager sharedThemeManager].contentBackColor;
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    //  REMARK：这个最大值只取前5行的最大值，即使数据有20行甚至更多。
    double _bid_max_sum = 0;
    double _ask_max_sum = 0;
    NSInteger realShowNum = _showOrderMaxNumber - 1;
    if ([_bidDataArray count] >= realShowNum){
        _bid_max_sum = [[[_bidDataArray objectAtIndex:realShowNum - 1] objectForKey:@"sum"] doubleValue];
    }else if ([_bidDataArray count] > 0){
        _bid_max_sum = [[[_bidDataArray lastObject] objectForKey:@"sum"] doubleValue];
    }
    if ([_askDataArray count] >= realShowNum){
        _ask_max_sum = [[[_askDataArray objectAtIndex:realShowNum - 1] objectForKey:@"sum"] doubleValue];
    }else if ([_askDataArray count] > 0){
        _ask_max_sum = [[[_askDataArray lastObject] objectForKey:@"sum"] doubleValue];
    }
    cell.numPrecision = _tradingPair.numPrecision;
    cell.displayPrecision = _tradingPair.displayPrecision;
    [cell setRowID:indexPath.row maxSum:fmax(_bid_max_sum, _ask_max_sum)];
    if (indexPath.row != 0){
        NSDictionary* data = [[self getDataArrayFromTableView:tableView] safeObjectAtIndex:indexPath.row - 1];
        if (data){
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
        }else{
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        [cell setItem:data];
    }else{
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //  1、买盘cell点击
    if (tableView == _bidTableView){
        if (indexPath.row != 0){
            id data = [_bidDataArray safeObjectAtIndex:indexPath.row - 1];
            if (data){
                _tfPrice.text = [OrgUtils formatFloatValue:[[data objectForKey:@"price"] doubleValue]
                                                  precision:_tradingPair.displayPrecision
                                     usesGroupingSeparator:NO];
                [self onPriceOrAmountChanged];
                NSLog(@"bid click: %@", [_bidDataArray safeObjectAtIndex:indexPath.row - 1]);
            }
        }
        return;
    }
    //  2、卖盘cell点击
    if (tableView == _askTableView){
        if (indexPath.row != 0){
            id data = [_askDataArray safeObjectAtIndex:indexPath.row - 1];
            if (data){
                _tfPrice.text = [OrgUtils formatFloatValue:[[data objectForKey:@"price"] doubleValue]
                                                  precision:_tradingPair.displayPrecision
                                     usesGroupingSeparator:NO];
                [self onPriceOrAmountChanged];
                NSLog(@"ask click: %@", [_askDataArray safeObjectAtIndex:indexPath.row - 1]);
            }
        }
        return;
    }
    //  3、买卖/登录 按钮点击
    if (tableView == _mainTableView && indexPath.section == kVcFormAction && _owner)
    {
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            if ([[WalletManager sharedWalletManager] isWalletExist]){
                //  处理交易行为
                [self onBuyOrSellActionClicked];
            }else{
                //  REMARK：这里不用 GuardWalletExist，仅跳转登录界面，登录后停留在交易界面，而不是登录后执行买卖操作。
                //  如果当前按钮显示的是买卖，那么应该继续处理，但这里按钮显示的就是登录，那么仅执行登录处理。
                VCImportAccount* vc = [[VCImportAccount alloc] init];
                vc.title = NSLocalizedString(@"kVcTitleLogin", @"登录");
                [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
            }
        }];
        return;
    }
    return;
}

/**
 *  核心 处理买卖操作
 */
- (void)onBuyOrSellActionClicked
{
    //  TODO:fowallet 数据尚未初始化完毕，请稍后。是否需要提示
    if (!_balanceData){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitTipNoData", @"正在获取数据，请稍后。")];
        return;
    }
    
    //  TODO:fowallet 不足的时候否直接提示显示？？？
    if (![[[_balanceData objectForKey:@"fee_item"] objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }

    id str_price = _tfPrice.text;
    id str_amount = _tfNumber.text;
    
    if (!str_price || [str_price isEqualToString:@""]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitTipPleaseInputPrice", @"请输入价格")];
        return;
    }
    if (!str_amount || [str_amount isEqualToString:@""]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitTipPleaseInputAmount", @"请输入数量")];
        return;
    }
    
    //  获取单价、数量、总价
    
    //  !!! 精确计算 !!!
    NSDecimalNumber* n_price = [OrgUtils auxGetStringDecimalNumberValue:str_price];
    NSDecimalNumber* n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    
    //  <= 0 判断，只有 大于 才为 NSOrderedDescending。
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_price compare:n_zero] != NSOrderedDescending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitTipPleaseInputPrice", @"请输入价格")];
        return;
    }
    
    if ([n_amount compare:n_zero] != NSOrderedDescending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitTipPleaseInputAmount", @"请输入数量")];
        return;
    }
    
    //  小数位数同 base 资产精度相同：
    //  买入行为：总金额向上取整
    //  卖出行为：向下取整
    NSDecimalNumberHandler* roundHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:_isbuy ? NSRoundUp : NSRoundDown
                                                                                                  scale:_tradingPair.basePrecision
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];
    NSDecimalNumber* n_total = [n_price decimalNumberByMultiplyingBy:n_amount withBehavior:roundHandler];
    
    if ([n_total compare:n_zero] != NSOrderedDescending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitTotalTooLow", @"交易额太低")];
        return;
    }
    
    if (_isbuy){
        //  买的总金额
        //  _base_amount_n < n_total
        if ([_base_amount_n compare:n_total] == NSOrderedAscending){
            [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitTotalNotEnough", @"金额不足")];
            return;
        }
        
        //  TODO:fowallet 买价太高预警 !!!!
    }else{
        //  _quote_amount_n < n_amount
        if ([_quote_amount_n compare:n_amount] == NSOrderedAscending){
            [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitAmountNotEnough", @"数量不足")];
            return;
        }
        
        //  TODO:fowallet 卖价太低预警 !!!
    }
    
    //  --- 参数校验完毕开始执行请求 ---
    [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self processBuyOrSellActionCore:n_price amount:n_amount total:n_total];
            //  TODO:fowallet !!! 是否二次确认。！！！慎重考虑。
            //            [self delay:^{
            //                VCTransactionConfirm* vc = [[VCTransactionConfirm alloc] init];
            //                vc.title = NSLocalizedString(@"kVcTitleConfirmTransaction", @"请确认交易");
            //                vc.hidesBottomBarWhenPushed = YES;
            //                [_owner showModelViewController:vc tag:0];
            //            }];
        }
    }];
}

- (void)processBuyOrSellActionCore:(NSDecimalNumber*)n_price amount:(NSDecimalNumber*)n_amount total:(NSDecimalNumber*)n_total
{
    //  忽略
    (void)n_price;
    
    NSDictionary* amount_to_sell;
    NSDictionary* min_to_receive;
    
    //  0位小数、向上取整
    NSDecimalNumberHandler* ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                 scale:0
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
    
    //  0位小数、向下取整
    NSDecimalNumberHandler* floorHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                                  scale:0
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];
    if (_isbuy){
        //  执行买入    base减少 -> quote增加
        
        //  得到数量（向上取整）
        id n_gain_total = [n_amount decimalNumberByMultiplyingByPowerOf10:_tradingPair.quotePrecision withBehavior:ceilHandler];
        min_to_receive = @{@"asset_id":_quote[@"id"], @"amount":[NSString stringWithFormat:@"%@", n_gain_total]};

        //  卖出数量等于 买的总花费金额 = 单价*买入数量（向下取整）  REMARK：这里 n_total <= _base_amount_n
        id n_buy_total = [n_total decimalNumberByMultiplyingByPowerOf10:_tradingPair.basePrecision withBehavior:floorHandler];
        amount_to_sell = @{@"asset_id":_base[@"id"], @"amount":[NSString stringWithFormat:@"%@", n_buy_total]};
    }else{
        //  执行卖出    quote减少 -> base增加
        
        //  卖出数量不能超过总数量（向下取整）                   REMARK：这里 n_amount <= _quote_amount_n
        id n_sell_amount = [n_amount decimalNumberByMultiplyingByPowerOf10:_tradingPair.quotePrecision withBehavior:floorHandler];
        amount_to_sell = @{@"asset_id":_quote[@"id"], @"amount":[NSString stringWithFormat:@"%@", n_sell_amount]};
        
        //  得到数量等于 单价*卖出数量（向上取整）
        id n_gain_total = [n_total decimalNumberByMultiplyingByPowerOf10:_tradingPair.basePrecision withBehavior:ceilHandler];
        min_to_receive = @{@"asset_id":_base[@"id"], @"amount":[NSString stringWithFormat:@"%@", n_gain_total]};
    }
    
    //  构造限价单 op 结构体
    id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    id seller = [account objectForKey:@"id"];
    assert(seller);
    id fee_item = [_balanceData objectForKey:@"fee_item"];

    NSTimeInterval now_sec = ceil([[NSDate date] timeIntervalSince1970]);
    uint32_t expiration_ts = (uint32_t)(now_sec + 64281600);    //  两年后：64281600 = 3600*24*31*12*2

    id op = @{
              @"fee":@{
                      @"amount":@0,
                      @"asset_id":fee_item[@"fee_asset_id"],    //  手续费资产ID
                      },
              @"seller":seller,                                 //  买卖帐号
              @"amount_to_sell":amount_to_sell,                 //  卖出数量
              @"min_to_receive":min_to_receive,                 //  得到数量
              @"expiration":@(expiration_ts),                   //  订单过期日期时间戳
              @"fill_or_kill":@NO,
              };

    //  确保有权限发起普通交易，否则作为提案交易处理。
    [_owner GuardProposalOrNormalTransaction:ebo_limit_order_create
                       using_owner_authority:NO
                    invoke_proposal_callback:NO
                                      opdata:op
                                   opaccount:account
                                        body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
         assert(!isProposal);
         //  请求网络广播
         [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
         [[[[BitsharesClientManager sharedBitsharesClientManager] createLimitOrder:op] then:(^id(id tx_data) {
             // 刷新UI（清除输入框）
             _tfNumber.text = @"";
             //  获取新的限价单ID号
             id new_order_id = [OrgUtils extractNewObjectID:tx_data];
             [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:seller] then:(^id(id full_data) {
                 [_owner hideBlockView];
                 //  刷新（调用owner的方法刷新、买/卖界面都需要刷新。）
                 [_owner onFullAccountInfoResponsed:full_data];
                 //  获取刚才新创建的限价单
                 id new_order = nil;
                 if (new_order_id){
                     new_order = [_userOrderDataArray ruby_find:(^BOOL(id order) {
                         return [[order objectForKey:@"id"] isEqualToString:new_order_id];
                     })];
                 }
                 if (new_order || !new_order_id){
                     //  尚未成交则添加到监控
                     if (new_order_id){
                         id account_id = [[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"id"];
                         assert(account_id);
                         [[ScheduleManager sharedScheduleManager] sub_market_monitor_orders:_tradingPair order_ids:@[new_order_id] account_id:account_id];
                     }
                     [OrgUtils makeToast:NSLocalizedString(@"kVcTradeTipTxCreateFullOK", @"下单成功")];
                 }else{
                     [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcTradeTipTxCreateFullOKWithID", @"下单成功，订单 #%@ 已成交。"), new_order_id]];
                 }
                 //  [统计]
                 [OrgUtils logEvents:@"txCreateLimitOrderFullOK"
                                params:@{@"account":seller, @"isbuy":@(_isbuy), @"base":_base[@"symbol"], @"quote":_quote[@"symbol"]}];
                 return nil;
             })] catch:(^id(id error) {
                 //  刷新失败也添加到监控
                 if (new_order_id){
                     id account_id = [[[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"id"];
                     assert(account_id);
                     [[ScheduleManager sharedScheduleManager] sub_market_monitor_orders:_tradingPair order_ids:@[new_order_id] account_id:account_id];
                 }
                 [_owner hideBlockView];
                 [OrgUtils makeToast:NSLocalizedString(@"kVcTradeTipTxCreateOK", @"下单成功，但刷新失败，请稍后再试。")];
                 //  [统计]
                 [OrgUtils logEvents:@"txCreateLimitOrderOK"
                                params:@{@"account":seller, @"isbuy":@(_isbuy), @"base":_base[@"symbol"], @"quote":_quote[@"symbol"]}];
                 return nil;
             })];
             return nil;
         })] catch:(^id(id error) {
             [_owner hideBlockView];
             [OrgUtils showGrapheneError:error];
             //  [统计]
             [OrgUtils logEvents:@"txCreateLimitOrderFailed"
                            params:@{@"account":seller, @"isbuy":@(_isbuy), @"base":_base[@"symbol"], @"quote":_quote[@"symbol"]}];
             return nil;
         })];
     }];
}

/**
 *  (private) 取消订单
 */
- (void)onButtonClicked_CancelOrder:(UIButton*)button
{
    id order = [_userOrderDataArray objectAtIndex:button.tag];
    NSLog(@"cancel : %@", order[@"id"]);
    
    id raw_order = [order objectForKey:@"raw_order"];
    id extra_balance = @{raw_order[@"sell_price"][@"base"][@"asset_id"]:raw_order[@"for_sale"]};
    id fee_item = [[ChainObjectManager sharedChainObjectManager] getFeeItem:ebo_limit_order_cancel
                                                          full_account_data:[_balanceData objectForKey:@"full_account_data"]
                                                              extra_balance:extra_balance];
    
    assert(fee_item);
    if (![[fee_item objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }
    [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            //  TODO:fowallet !!! 取消订单是否二次确认。
            [self processCancelOrderCore:order fee_item:fee_item];
        }
    }];
}

- (void)processCancelOrderCore:(id)order fee_item:(id)fee_item
{
    assert(order);
    assert(_balanceData);
    id order_id = order[@"id"];
    id fee_asset_id = [fee_item objectForKey:@"fee_asset_id"];
    id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    id account_id = [account objectForKey:@"id"];
    id op = @{
              @"fee":@{@"amount":@0, @"asset_id":fee_asset_id},
              @"fee_paying_account":account_id,
              @"order":order_id
              };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [_owner GuardProposalOrNormalTransaction:ebo_limit_order_cancel
                       using_owner_authority:NO
                    invoke_proposal_callback:NO
                                      opdata:op
                                   opaccount:account
                                        body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
         assert(!isProposal);
         //  请求网络广播
         [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
         [[[[BitsharesClientManager sharedBitsharesClientManager] cancelLimitOrders:@[op]] then:(^id(id data) {
             [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_id] then:(^id(id full_data) {
                 NSLog(@"cancel order & refresh: %@", full_data);
                 [_owner hideBlockView];
                 //  刷新（调用owner的方法刷新、买/卖界面都需要刷新。）
                 [_owner onFullAccountInfoResponsed:full_data];
                 [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcOrderTipTxCancelFullOK", @"订单 #%@ 已取消。"), order_id]];
                 //  [统计]
                 [OrgUtils logEvents:@"txCancelLimitOrderFullOK" params:@{@"account":account_id}];
                 return nil;
             })] catch:(^id(id error) {
                 [_owner hideBlockView];
                 [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcOrderTipTxCancelOK", @"订单 #%@ 已取消，但刷新界面失败，请稍后再试。"), order_id]];
                 //  [统计]
                 [OrgUtils logEvents:@"txCancelLimitOrderOK" params:@{@"account":account_id}];
                 return nil;
             })];
             return nil;
         })] catch:(^id(id error) {
             [_owner hideBlockView];
             [OrgUtils showGrapheneError:error];
             //  [统计]
             [OrgUtils logEvents:@"txCancelLimitOrderFailed" params:@{@"account":account_id}];
             return nil;
         })];
     }];
}

@end
