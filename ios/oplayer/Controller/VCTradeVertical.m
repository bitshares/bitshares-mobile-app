//
//  VCTradeVertical.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTradeVertical.h"
#import "VCSettlementOrders.h"
#import "VCImportAccount.h"
#import "VCUserOrders.h"

#import "ViewTradePercentButtonCell.h"
#import "ViewBlockLabel.h"
#import "ViewBidAskCellVer.h"
#import "VerticalAlignmentLabel.h"
#import "MySlider.h"
#import "ViewFillOrderCellVer.h"
#import "ViewTitleValueCell.h"

#import "MBProgressHUDSingleton.h"
#import "ScheduleManager.h"

enum
{
    kVcFormData = 0,            //  表单数据
    kVcFormAction,              //  表单行为：买卖按钮
    kVcMainTableMax
};

enum
{
    kVcSubPriceTitle = 0,
    kVcSubPriceCell,            //  买入价
    kVcSubNumberTitle,
    kVcSubNumberCell,           //  买入量
    kVcSubPercentButtons,       //  百分比按钮
    kVcSubTotalTitle,
    kVcSubTotalPrice,           //  交易额
    kVcSubEmpty,
    kVcSubAvailable,            //  可用余额
    kVcSubMarketFee,            //  市场手续费率
    
    kVcSubMax,
};

@interface VCTradeVertical ()
{
//    __weak MyNavigationController* _ref_navi_vc;
    TradingPair*    _tradingPair;
    BOOL            _selectBuy;
    BOOL            _haveAccountOnInit;
}
@end

#pragma mark- 竖版界面容器类
@implementation VCTradeVertical

- (void)dealloc
{
//    _ref_navi_vc = nil;
    //  取消所有订阅
    [[ScheduleManager sharedScheduleManager] sub_market_remove_all_monitor_orders:_tradingPair];
    [[ScheduleManager sharedScheduleManager] unsub_market_notify:_tradingPair];
    _tradingPair = nil;
}

- (id)initWithTradingPair:(TradingPair*)tradingPair selectBuy:(BOOL)selectBuy
{
    self = [super init];
    if (self) {
        //  确保智能资产信息已经初始化
        assert(tradingPair && tradingPair.bCoreMarketInited);
        _selectBuy = selectBuy;
        _tradingPair = tradingPair;
        //  REMARK：在初始化的时候判断帐号信息
        _haveAccountOnInit = [[WalletManager sharedWalletManager] isWalletExist];
    }
    return self;
}

- (NSInteger)getTitleDefaultSelectedIndex
{
    return _selectBuy ? 1 : 2;
}

- (NSArray*)getTitleStringArray
{
    NSMutableArray* ary = [NSMutableArray arrayWithObjects:
                           NSLocalizedString(@"kLabelTitleBuy", @"买入"),
                           NSLocalizedString(@"kLabelTitleSell", @"卖出"),
                           NSLocalizedString(@"kLabelOpenOrders", @"当前委托"),
                           nil];
    if (_tradingPair.isCoreMarket) {
        [ary addObject:NSLocalizedString(@"kVcOrderPageSettleOrders", @"清算单")];
    }
    return [ary copy];
}

- (NSArray*)getSubPageVCArray
{
    //  TODO:5.0 VCUserOrders 需要支持动态查询数据
    NSMutableArray* ary = [NSMutableArray arrayWithObjects:
                           [[VCTradeVerticalBuyOrSell alloc] initWithOwner:self tradingPair:_tradingPair isbuy:YES],
                           [[VCTradeVerticalBuyOrSell alloc] initWithOwner:self tradingPair:_tradingPair isbuy:NO],
                           [[VCUserOrders alloc] initWithOwner:self data:nil history:NO tradingPair:_tradingPair filter:YES],
                           nil];
    if (_tradingPair.isCoreMarket) {
        [ary addObject:[[VCSettlementOrders alloc] initWithOwner:self tradingPair:_tradingPair fullAccountInfo:nil]];
    }
    return [ary copy];
}

- (void)onRightButtonClicked
{
    UIBarButtonItem* barItem = (UIBarButtonItem*)self.navigationItem.rightBarButtonItem;
    [VcUtils processMyFavPairStateChanged:_tradingPair.quoteAsset
                                     base:_tradingPair.baseAsset
                          associated_view:(UIButton*)barItem.customView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //  REMARK：考虑在这里刷新登录状态，用登录vc的callback会延迟，会看到文字变化。
    [self onRefreshLoginStatus];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self resignAllFirstResponder];
    [super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
//    [_ref_navi_vc setDisablePopGesture:YES];
    //  添加通知：订阅的市场数据
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSubMarketNotifyNewData:) name:kBtsSubMarketNotifyNewData object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    //  移除通知：订阅的市场数据
//    [_ref_navi_vc setDisablePopGesture:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kBtsSubMarketNotifyNewData object:nil];
    [super viewDidDisappear:animated];
}

/**
 *  (private) 事件 - 处理登录成功事件
 */
- (void)onRefreshLoginStatus
{
    if (!_subvcArrays){
        return;
    }
    
    //  REMARK：界面创建就已经有帐号了，则不用刷新了。只有从该界面里进行登录才需要刷新。
    if (_haveAccountOnInit){
        return;
    }
    
    //  未登录
    if (![[WalletManager sharedWalletManager] isWalletExist]){
        return;
    }
    
    //  在交易界面完成了登录过程
    
    //  a、刷新可用余额
    [self onFullAccountInfoResponsed:[[WalletManager sharedWalletManager] getWalletAccountInfo]];
    
    //  b、刷新登录按钮状态
    for (VCTradeVerticalBuyOrSell* vc in _subvcArrays) {
        if (![vc isKindOfClass:[VCTradeVerticalBuyOrSell class]]) {
            continue;
        }
        [vc onRefreshLoginStatus];
    }
}

/**
 *  (private) 事件 - 刷新用户订单信息（用户在当前委托界面取消订单后需要刷新。）
 */
- (void)onRefreshUserLimitOrderChanged
{
    //  订单信息发生变化了
    if ([TempManager sharedTempManager].userLimitOrderDirty){
        [TempManager sharedTempManager].userLimitOrderDirty = NO;
        //  未登录
        WalletManager* walletMgr = [WalletManager sharedWalletManager];
        if (![walletMgr isWalletExist]){
            return;
        }
        //  刷新
        id account_id = [[[walletMgr getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"id"];
        id full_account_data = [[ChainObjectManager sharedChainObjectManager] getFullAccountDataFromCache:account_id];
        if (full_account_data){
            [self onFullAccountInfoResponsed:full_account_data];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
//    _ref_navi_vc = [self myNavigationController];
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  添加自选按钮
    if ([[AppCacheManager sharedAppCacheManager] is_fav_market:_tradingPair.quoteAsset[@"id"] base:_tradingPair.baseAsset[@"id"]]){
        [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:theme.textColorHighlight];
    }else{
        [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:theme.textColorGray];
    }
    
    //  背景颜色
    self.view.backgroundColor = theme.appBackColor;
    
    //  事件 - 空白处点击
    [VcUtils addSpaceTapHandler:self body:^(id weak_self, UITapGestureRecognizer *tap) {
        [weak_self resignAllFirstResponder];
    }];
    
    //  get_order_book      - 没用到
    //  get_limit_orders
    //  get_call_orders     - 当前market是core资产时需要调用 quote.bitasset.options.short_backing_asset == base.id 或者 quote、base对调。
    //  get_settle_orders   - 当前market是core资产时需要调用
    
    //  !!! subscribe_to_market
    
    //  get_market_history
    //  get_fill_order_history
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //  优先查询智能背书资产信息（之后才考虑是否查询喂价、爆仓单等信息）
    [[[_tradingPair queryBitassetMarketInfo] then:(^id(id isCoreMarket) {
        GrapheneApi* api_db = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
        
        WalletManager* wallet_mgr = [WalletManager sharedWalletManager];
        id p0_full_info = [NSNull null];
        if ([wallet_mgr isWalletExist]){
            p0_full_info = [chainMgr queryUserLimitOrders:[wallet_mgr getWalletAccountInfo][@"account"][@"id"]];
        }
        
        //  获取参数
        id parameters = [chainMgr getDefaultParameters];
        NSInteger n_callorder = [parameters[@"trade_query_callorder_number"] integerValue];
        NSInteger n_limitorder = [parameters[@"trade_query_limitorder_number"] integerValue];
        NSInteger n_fillorder = [parameters[@"trade_query_fillorder_number"] integerValue];
        assert(n_callorder > 0 && n_limitorder > 0 && n_fillorder > 0);
        
        id p1 = [chainMgr queryLimitOrders:_tradingPair number:n_limitorder];
        id p2 = [api_db exec:@"get_ticker" params:@[_tradingPair.baseId, _tradingPair.quoteId]];
        id p3 = [chainMgr queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
        id p4 = [chainMgr queryCallOrders:_tradingPair number:n_callorder];
        id p5 = [chainMgr queryFillOrderHistory:_tradingPair number:n_fillorder];
        
        return [[WsPromise all:@[p0_full_info, p1, p2, p3, p4, p5]] then:(^id(id data) {
            [self hideBlockView];
            [self onInitPromiseResponse:data];
            //  继续订阅
            [[ScheduleManager sharedScheduleManager] sub_market_notify:_tradingPair
                                                           n_callorder:n_callorder
                                                          n_limitorder:n_limitorder
                                                           n_fillorder:n_fillorder];
            return nil;
        })];
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

/*
 *  (通知) 市场新的订阅数据
 */
- (void)onSubMarketNotifyNewData:(NSNotification*)notification
{
    if (!notification){
        return;
    }
    id userinfo = notification.userInfo;
    if (!userinfo){
        return;
    }
    //  过滤其他的交易对
    NSString* kCurrentPair = [userinfo objectForKey:@"kCurrentPair"];
    if (kCurrentPair && _tradingPair && ![kCurrentPair isEqualToString:_tradingPair.pair]) {
        return;
    }
    //  更新限价单
    id settlement_data = [userinfo objectForKey:@"kSettlementData"];
    [self onQueryOrderBookResponse:[userinfo objectForKey:@"kLimitOrders"] settlement_data:settlement_data];
    //  更新成交历史和Ticker
    [self onQueryFillOrderHistoryResponsed:[userinfo objectForKey:@"kFillOrders"]];
    //  更新帐号信息
    id fullUserData = [userinfo objectForKey:@"kFullAccountData"];
    if (fullUserData){
        [self onFullAccountInfoResponsed:fullUserData];
    }
}

- (void)onInitPromiseResponse:(id)data_array
{
    //  1、更新账户所有资产和当前委托信息
    id full_account_data = [data_array objectAtIndex:0];
    if (full_account_data && ![full_account_data isKindOfClass:[NSNull class]]){
        [self onFullAccountInfoResponsed:full_account_data];
    }else{
        [self onFullAccountInfoResponsed:nil];
    }
    
    //  2、更新 ticker 数据
    id get_ticker_data = [data_array objectAtIndex:2];
    if (get_ticker_data && ![get_ticker_data isKindOfClass:[NSNull class]]){
        [[ChainObjectManager sharedChainObjectManager] updateTickeraData:_tradingPair.baseId quote:_tradingPair.quoteId data:get_ticker_data];
        //  设置脏标记
        [TempManager sharedTempManager].tickerDataDirty = YES;
        [self onQueryTickerDataResponse:get_ticker_data];
    }
    
    //  3、更新盘口信息（普通盘口+爆仓单）
    [self onQueryOrderBookResponse:data_array[1] settlement_data:data_array[4]];
    //  4、更新成交记录
    [self onQueryFillOrderHistoryResponsed:data_array[5]];
}

- (void)onFullAccountInfoResponsed:(NSDictionary*)full_account_info
{
    if (_subvcArrays){
        for (VCTradeVerticalBuyOrSell* vc in _subvcArrays) {
            if (![vc isKindOfClass:[VCTradeVerticalBuyOrSell class]]) {
                continue;
            }
            [vc onFullAccountDataResponsed:full_account_info];
        }
    }
}

- (void)onQueryFillOrderHistoryResponsed:(id)data
{
    //  订阅市场返回的数据可能为 nil。
    if (!data){
        return;
    }
    if (_subvcArrays){
        for (VCTradeVerticalBuyOrSell* vc in _subvcArrays) {
            if (![vc isKindOfClass:[VCTradeVerticalBuyOrSell class]]) {
                continue;
            }
            [vc onQueryFillOrderHistoryResponsed:data];
        }
    }
}

- (void)onQueryOrderBookResponse:(id)normal_order_book settlement_data:(id)settlement_data
{
    //  订阅市场返回的数据可能为 nil。
    if (!normal_order_book){
        return;
    }
    if (_subvcArrays){
        id merged_order_book = [OrgUtils mergeOrderBook:normal_order_book settlement_data:settlement_data];
        for (VCTradeVerticalBuyOrSell* vc in _subvcArrays) {
            if (![vc isKindOfClass:[VCTradeVerticalBuyOrSell class]]) {
                continue;
            }
            [vc onQueryOrderBookResponse:merged_order_book];
        }
    }
}

- (void)onQueryTickerDataResponse:(id)data
{
    if (_subvcArrays){
        for (VCTradeVerticalBuyOrSell* vc in _subvcArrays) {
            if (![vc isKindOfClass:[VCTradeVerticalBuyOrSell class]]) {
                continue;
            }
            [vc onQueryTickerDataResponse:data];
        }
    }
}

- (void)resignAllFirstResponder
{
    [self endInput];
}

- (void)onPageChanged:(NSInteger)tag
{
    if (_subvcArrays){
        //  点击买入or卖出界面，刷新当前订单信息。
        id vc = [_subvcArrays safeObjectAtIndex:tag - 1];
        if (vc && [vc isKindOfClass:[VCTradeVerticalBuyOrSell class]]){
            [self onRefreshUserLimitOrderChanged];
        }
    }
    [super onPageChanged:tag];
}

@end

@interface VCTradeVerticalBuyOrSell ()
{
    __weak VCTradeVertical*     _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    TradingPair*                _tradingPair;
    BOOL                        _isBuy;
    
    NSObject*                   _animLock;              //  动画锁
    
    NSInteger                   _showOrderMaxNumber;    //  盘口行数
    NSInteger                   _showOrderLineHeight;   //  盘口每行高度
    CGFloat                     _fLatestPriceHeight;    //  最新价格显示高度
    
    UITableViewBase*            _mainTableView;         //  左边窗口
    MyTextField*                _tfPrice;
    MyTextField*                _tfNumber;
    MyTextField*                _tfTotal;               //  总成交金额
    ViewTradePercentButtonCell* _cellPercentButtons;    //  UI - 百分比按钮
    ViewBlockLabel*             _lbBuyOrSell;           //  UI - 买卖按钮
    ViewTitleValueCell*         _cellAvailable;         //  UI - 可用余额
    ViewTitleValueCell*         _cellMarketFee;         //  UI - 市场手续费
    
    VerticalAlignmentLabel*     _lbTickerPrice;         //  UI - 最新价格
    VerticalAlignmentLabel*     _lbTickerPercent;       //  UI - 最新涨跌幅
    
    UITableViewBase*            _historyTableView;      //  UI - 成交历史列表
    
    UIView*                     _viewOrderBookTitle;
    UITableViewBase*            _bidTableView;
    UITableViewBase*            _askTableView;
    NSDictionary*               _balanceData;           //  当前账户余额数据（未登录or初始化失败都为nil）
    
    NSMutableArray*             _bidDataArray;          //  买盘数据
    NSMutableArray*             _askDataArray;          //  卖盘数据
    double                      _fMaxQuoteValue;        //  买盘和卖盘所有数据中最大交易量（绘制深度图用）
    
    NSMutableArray*             _dataArrayHistory;      //  成交历史
    NSMutableDictionary*        _userOrderDataHash;     //  用户当前委托订单的hash
}

@end

#pragma mark- 竖版交易界面核心
@implementation VCTradeVerticalBuyOrSell

-(void)dealloc
{
    _owner = nil;
    _tradingPair = nil;
    
    _bidDataArray = nil;
    _askDataArray = nil;
    _balanceData = nil;
    _dataArrayHistory = nil;
    
    _lbTickerPrice = nil;
    _lbTickerPercent = nil;
    
    _viewOrderBookTitle = nil;
    if (_animLock){
        [[IntervalManager sharedIntervalManager] releaseLock:_animLock];
        _animLock = nil;
    }
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
    if (_historyTableView) {
        [[IntervalManager sharedIntervalManager] releaseLock:_historyTableView];
        _historyTableView.delegate = nil;
        _historyTableView = nil;
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
    _cellPercentButtons = nil;
    _cellAvailable = nil;
    _cellMarketFee = nil;
    _lbBuyOrSell = nil;
}

- (id)initWithOwner:(VCTradeVertical*)owner tradingPair:(TradingPair*)tradingPair isbuy:(BOOL)isbuy
{
    self = [super init];
    if (self) {
        _owner = owner;
        _tradingPair = tradingPair;
        _isBuy = isbuy;
        _animLock = [[NSObject alloc] init];
        
        _bidDataArray = [NSMutableArray array];
        _askDataArray = [NSMutableArray array];
        _balanceData = nil;
        
        _dataArrayHistory = [NSMutableArray array];
        _userOrderDataHash = [NSMutableDictionary dictionary];
        
        _showOrderMaxNumber = 20;//TODO:5.0 竖版不用横版等参数 [[parameters objectForKey:@"order_book_num_trade"] integerValue] + 1;
        _showOrderLineHeight = 28.0f;   //  TODO:fowallet constants
        _fLatestPriceHeight = 56.0f;
    }
    return self;
}

- (NSDictionary*)auxGenBalanceInfos:(NSDictionary*)full_account_data
{
    id base_id = _tradingPair.baseId;
    id quote_id = _tradingPair.quoteId;
    
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

/*
 *  (private) 辅助 - 获取 base 资产和 quote 资产余额。
 */
- (NSDecimalNumber*)auxBaseBalance
{
    assert(_balanceData && _tradingPair);
    return [NSDecimalNumber decimalNumberWithMantissa:[[[_balanceData objectForKey:@"base"] objectForKey:@"amount"] unsignedLongLongValue]
                                             exponent:-_tradingPair.basePrecision
                                           isNegative:NO];
}

- (NSDecimalNumber*)auxQuoteBalance
{
    assert(_balanceData && _tradingPair);
    return [NSDecimalNumber decimalNumberWithMantissa:[[[_balanceData objectForKey:@"quote"] objectForKey:@"amount"] unsignedLongLongValue]
                                             exponent:-_tradingPair.quotePrecision
                                           isNegative:NO];
}

/*
 *  事件 - 页面切换事件
 */
- (void)onControllerPageChanged
{
    //  ...
}

/*
 *  事件 - 数据响应 - 用户账号数据返回
 */
- (void)onFullAccountDataResponsed:(id)full_account_data
{
    //  未登录的情况，待处理。TODO:fowallet
    if (!full_account_data){
        return;
    }
    
    //  1、保存余额信息、同步更新 base 数量 和 quote 数量。
    assert(full_account_data);
    _balanceData = [self auxGenBalanceInfos:full_account_data];
    
    //  刷新余额显示  买：显示 base 余额    卖：显示 quote 余额
    if (_isBuy){
        [self draw_ui_available:[OrgUtils formatAssetString:[[_balanceData objectForKey:@"base"] objectForKey:@"amount"] precision:_tradingPair.basePrecision]
                         enough:YES];
    }else{
        [self draw_ui_available:[OrgUtils formatAssetString:[[_balanceData objectForKey:@"quote"] objectForKey:@"amount"] precision:_tradingPair.quotePrecision]
                         enough:YES];
        
    }
    
    //  刷新手续费信息
    [self draw_ui_market_fee:_isBuy ? _tradingPair.quoteAsset : _tradingPair.baseAsset
                     account:[full_account_data objectForKey:@"account"]];
    
    //  2、刷新交易额、可用余额等
    [self onPriceOrAmountChanged:NO];
    
    //  3、当前委托信息（过滤掉了非当前交易对的挂单）
    if (_userOrderDataHash){
        [_userOrderDataHash removeAllObjects];
    }
    for (id order in [full_account_data objectForKey:@"limit_orders"]) {
        id sell_price = [order objectForKey:@"sell_price"];
        id base_id = [[sell_price objectForKey:@"base"] objectForKey:@"asset_id"];
        id quote_id = [[sell_price objectForKey:@"quote"] objectForKey:@"asset_id"];
        if ([base_id isEqualToString:_tradingPair.baseId] && [quote_id isEqualToString:_tradingPair.quoteId]){
            //  买单：卖出 CNY
        }else if ([base_id isEqualToString:_tradingPair.quoteId] && [quote_id isEqualToString:_tradingPair.baseId]){
            //  卖单：卖出 BTS
        }else{
            //  其他交易对的订单
            continue;
        }
        [_userOrderDataHash setObject:order forKey:[order objectForKey:@"id"]];
    }
    
    //  4、刷新界面
    [_mainTableView reloadData];
}

/*
 *  事件 - 数据响应 - 盘口
 */
- (void)onQueryOrderBookResponse:(id)merged_order_book
{
    //  更新显示精度
    [_tradingPair dynamicUpdateDisplayPrecision:merged_order_book];
    
    BOOL bFirst = [_bidDataArray count] == 0 && [_askDataArray count] == 0;
    
    [_bidDataArray removeAllObjects];
    [_bidDataArray addObjectsFromArray:[merged_order_book objectForKey:@"bids"]];
    
    [_askDataArray removeAllObjects];
    [_askDataArray addObjectsFromArray:[merged_order_book objectForKey:@"asks"]];
    
    //  更新最大交易量的挂单
    _fMaxQuoteValue = 0.0f;
    NSInteger idx = 0;
    for (id item in _bidDataArray) {
        double value = [[item objectForKey:@"quote"] doubleValue];
        if (_fMaxQuoteValue < value) {
            _fMaxQuoteValue = value;
        }
        if (++idx >= _showOrderMaxNumber) {
            break;
        }
    }
    idx = 0;
    for (id item in _askDataArray) {
        double value = [[item objectForKey:@"quote"] doubleValue];
        if (_fMaxQuoteValue < value) {
            _fMaxQuoteValue = value;
        }
        if (++idx >= _showOrderMaxNumber) {
            break;
        }
    }
    
    [_bidTableView reloadData];
    [_askTableView reloadData];
    
    //  价格输入框没有值的情况设置默认值 买界面-默认卖1价格 卖界面-默认买1价（参考huobi）
    if (bFirst) {
        id str_price = _tfPrice.text;
        if (!str_price || [str_price isEqualToString:@""]){
            id data = nil;
            if (_isBuy){
                data = [_askDataArray safeObjectAtIndex:0];
            }else{
                data = [_bidDataArray safeObjectAtIndex:0];
            }
            if (data){
                _tfPrice.text = [OrgUtils formatFloatValue:[[data objectForKey:@"price"] doubleValue]
                                                 precision:_tradingPair.displayPrecision
                                     usesGroupingSeparator:NO];
                [self onPriceOrAmountChanged:NO];
            }
        }
    }
}

/*
 *  事件 - 数据响应 - Ticker数据
 */
- (void)onQueryTickerDataResponse:(id)data
{
    [self draw_ui_ticker_price_and_percent:YES];
}

/*
 *  事件 - 数据响应 - 历史成交记录
 */
- (void)onQueryFillOrderHistoryResponsed:(id)data_array
{
    if (!data_array || [data_array count] <= 0){
        return;
    }
    
    //  更新成交历史
    [_dataArrayHistory removeAllObjects];
    [_dataArrayHistory addObjectsFromArray:data_array];
    [_historyTableView reloadData];
    
    //  更新最新成交价
    [self draw_ui_ticker_price_and_percent:![[[data_array firstObject] objectForKey:@"issell"] boolValue]];
}

/*
 *  事件 - 处理登录成功事件
 *  更改 登录按钮为 买卖按钮
 *  获取 个人信息
 */
- (void)onRefreshLoginStatus
{
    if (_isBuy){
        _lbBuyOrSell.text = [NSString stringWithFormat:@"%@%@",
                             NSLocalizedString(@"kBtnBuy", @"买入"),
                             [_tradingPair.quoteAsset objectForKey:@"symbol"]];
    }else{
        _lbBuyOrSell.text = [NSString stringWithFormat:@"%@%@",
                             NSLocalizedString(@"kBtnSell", @"卖出"),
                             [_tradingPair.quoteAsset objectForKey:@"symbol"]];
    }
}

/*
 *  事件 - UI取消关闭键盘
 */
- (void)endInput
{
    [super endInput];
    [_tfNumber safeResignFirstResponder];
    [_tfPrice safeResignFirstResponder];
    [_tfTotal safeResignFirstResponder];
}

/*
 *  (private) 生成 orderbook 的标题栏。
 */
- (UIView*)genOrderBookTitleView
{
    UIView* myView = [[UIView alloc] init];
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    myView.backgroundColor = theme.appBackColor;
    
    CGFloat fHalfWidth = self.view.bounds.size.width / 2.0f;
    
    UILabel* lbOrderBookId = [ViewUtils auxGenLabel:[UIFont fontWithName:@"Helvetica" size:12.0f]
                                          superview:myView];
    lbOrderBookId.text = NSLocalizedString(@"kVcVerTradeLabelOrderBookID", @"档");
    lbOrderBookId.textAlignment = NSTextAlignmentLeft;
    lbOrderBookId.frame = CGRectMake(0, 0, fHalfWidth, _showOrderLineHeight);
    lbOrderBookId.textColor = theme.textColorGray;
    
    UILabel* lbOrderBookHeaderPrice = [ViewUtils auxGenLabel:[UIFont fontWithName:@"Helvetica" size:12.0f]
                                                   superview:myView];
    lbOrderBookHeaderPrice.text = NSLocalizedString(@"kLableBidPrice", @"价格");
    lbOrderBookHeaderPrice.textAlignment = NSTextAlignmentLeft;
    lbOrderBookHeaderPrice.frame = CGRectMake(26, 0, fHalfWidth, _showOrderLineHeight);
    lbOrderBookHeaderPrice.textColor = theme.textColorGray;
    
    UILabel* lbOrderBookHeaderAmount = [ViewUtils auxGenLabel:[UIFont fontWithName:@"Helvetica" size:12.0f]
                                                    superview:myView];
    lbOrderBookHeaderAmount.text = NSLocalizedString(@"kLableBidAmount", @"数量");
    lbOrderBookHeaderAmount.textAlignment = NSTextAlignmentRight;
    lbOrderBookHeaderAmount.frame = CGRectMake(0, 0, fHalfWidth, _showOrderLineHeight);
    lbOrderBookHeaderAmount.textColor = theme.textColorGray;
    //  添加约束 - 数量宽度和高度始终等于父视图宽度
    lbOrderBookHeaderAmount.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint* constraintAmountWidth = [NSLayoutConstraint constraintWithItem:lbOrderBookHeaderAmount
                                                                             attribute:NSLayoutAttributeWidth
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:myView
                                                                             attribute:NSLayoutAttributeWidth
                                                                            multiplier:1.0f
                                                                              constant:0];
    NSLayoutConstraint* constraintAmountHeight = [NSLayoutConstraint constraintWithItem:lbOrderBookHeaderAmount
                                                                              attribute:NSLayoutAttributeHeight
                                                                              relatedBy:NSLayoutRelationEqual
                                                                                 toItem:myView
                                                                              attribute:NSLayoutAttributeHeight
                                                                             multiplier:1.0f
                                                                               constant:0];
    [myView addConstraint:constraintAmountWidth];
    [myView addConstraint:constraintAmountHeight];
    
    return myView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    self.view.backgroundColor = theme.appBackColor;
    
    //  初始化 半屏宽度、页面内容部分高度、盘口高度
    CGFloat fHalfWidth = [[UIScreen mainScreen] bounds].size.width / 2.0f;
    CGFloat fContentHeight = [self rectWithoutNaviAndPageBar].size.height;
    CGFloat fBidAskHeight = (fContentHeight - _fLatestPriceHeight - _showOrderLineHeight) / 2.0f;
    
    //  初始化UI - 最新价格和涨跌幅
    _lbTickerPrice = [ViewUtils auxGenVerLabel:[UIFont boldSystemFontOfSize:24.0f]];
    _lbTickerPercent = [ViewUtils auxGenVerLabel:[UIFont systemFontOfSize:14]];
    [self.view addSubview:_lbTickerPrice];
    [self.view addSubview:_lbTickerPercent];
    [self draw_ui_ticker_price_and_percent:YES];
    
    _viewOrderBookTitle = [self genOrderBookTitleView];
    [self.view addSubview:_viewOrderBookTitle];
    
    //  初始化UI - 买卖盘口
    CGRect askRect = CGRectMake(fHalfWidth, _showOrderLineHeight, fHalfWidth, fBidAskHeight);
    _askTableView = [[UITableViewBase alloc] initWithFrame:askRect style:UITableViewStylePlain];
    _askTableView.delegate = self;
    _askTableView.dataSource = self;
    _askTableView.showsVerticalScrollIndicator = NO;
    _askTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _askTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_askTableView];
    _askTableView.hideAllLines = YES;
    //  初始化默认滚动位置 REMARK：需要先禁用预估高度
    _askTableView.estimatedSectionHeaderHeight = 0;
    _askTableView.estimatedSectionFooterHeight = 0;
    _askTableView.estimatedRowHeight = 0;
    [_askTableView setContentOffset:CGPointMake(0, MAX(_showOrderMaxNumber * _showOrderLineHeight - fBidAskHeight, 0)) animated:NO];
    
    CGRect bidRect = CGRectMake(fHalfWidth, _askTableView.bounds.size.height + _showOrderLineHeight + _fLatestPriceHeight, fHalfWidth, fBidAskHeight);
    _bidTableView = [[UITableViewBase alloc] initWithFrame:bidRect style:UITableViewStylePlain];
    _bidTableView.delegate = self;
    _bidTableView.dataSource = self;
    _bidTableView.showsVerticalScrollIndicator = NO;
    _bidTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _bidTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_bidTableView];
    _bidTableView.hideAllLines = YES;
    
    //  UI - 左边主窗口
    CGFloat fMainTableViewHeight = [self _auxCalcMainTableViewTotalHeight];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:CGRectMake(0, 0, fHalfWidth, fMainTableViewHeight) style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    [self.view addSubview:_mainTableView];
    _mainTableView.showsVerticalScrollIndicator = NO;
    _mainTableView.scrollEnabled = NO;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    
    //  UI - 成交历史
    _historyTableView = [[UITableViewBase alloc] initWithFrame:CGRectMake(0, fMainTableViewHeight, fHalfWidth, fContentHeight - fMainTableViewHeight)
                                                         style:UITableViewStylePlain];
    _historyTableView.delegate = self;
    _historyTableView.dataSource = self;
    [self.view addSubview:_historyTableView];
    _historyTableView.showsVerticalScrollIndicator = NO;
    _historyTableView.backgroundColor = [UIColor clearColor];
    _historyTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    
    //  UI - 左边各种输入框
    NSString* pricePlaceHolder = nil;
    NSString* numberPlaceHolder = nil;
    if (_isBuy){
        pricePlaceHolder = NSLocalizedString(@"kPlaceHolderBuyPrice", @"买入单价");
        numberPlaceHolder = NSLocalizedString(@"kPlaceHolderBuyAmount", @"买入数量");
    }else{
        pricePlaceHolder = NSLocalizedString(@"kPlaceHolderSellPrice", @"卖出单价");
        numberPlaceHolder = NSLocalizedString(@"kPlaceHolderSellAmount", @"卖出数量");
    }
    NSString* totalPlaceHolder = NSLocalizedString(@"kLableTotalPrice", @"交易额");
    
    //  UI - 各种输入框，仅高度属性需要，其他属性在添加到cell的时候会自动计算。
    CGFloat fTextFieldHeight = 38.0f;
    CGRect tfrect = CGRectMake(0, 0, 0, fTextFieldHeight);
    _tfPrice = [self createTfWithRect:tfrect keyboard:UIKeyboardTypeDecimalPad placeholder:pricePlaceHolder];
    _tfPrice.textColor = theme.textColorMain;
    _tfPrice.showRectBorder = YES;
    
    _tfNumber = [self createTfWithRect:tfrect keyboard:UIKeyboardTypeDecimalPad placeholder:numberPlaceHolder];
    _tfNumber.textColor = theme.textColorMain;
    _tfNumber.showRectBorder = YES;
    
    _tfTotal = [self createTfWithRect:tfrect keyboard:UIKeyboardTypeDecimalPad placeholder:totalPlaceHolder];
    _tfTotal.textColor = theme.textColorMain;
    _tfTotal.showRectBorder = YES;
    
    _tfPrice.updateClearButtonTintColor = YES;
    _tfNumber.updateClearButtonTintColor = YES;
    _tfTotal.updateClearButtonTintColor = YES;
    
    _tfPrice.attributedPlaceholder = [ViewUtils placeholderAttrString:pricePlaceHolder];
    _tfNumber.attributedPlaceholder = [ViewUtils placeholderAttrString:numberPlaceHolder];
    _tfTotal.attributedPlaceholder = [ViewUtils placeholderAttrString:totalPlaceHolder];
    
    //  绑定输入事件（限制输入）
    [_tfPrice addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_tfNumber addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_tfTotal addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 百分比按钮
    _cellPercentButtons = [[ViewTradePercentButtonCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil vc:self];
    
    //  UI - 可用余额 & 手续费 CELL
    _cellAvailable = [[ViewTitleValueCell alloc] init];
    _cellMarketFee = [[ViewTitleValueCell alloc] init];
    _cellAvailable.titleLabel.text = NSLocalizedString(@"kLableAvailable", @"可用");
    _cellMarketFee.titleLabel.text = NSLocalizedString(@"kVcVerTradeLabelMarketFee", @"手续费");
    _cellMarketFee.valueLabel.textColor = theme.textColorNormal;
    [self draw_ui_available:nil enough:YES];
    [self draw_ui_market_fee:_isBuy ? _tradingPair.quoteAsset : _tradingPair.baseAsset account:nil];
    
    //  UI - 交易按钮
    NSString* cell_btn_name = nil;
    if ([[WalletManager sharedWalletManager] isWalletExist]){
        if (_isBuy){
            cell_btn_name = [NSString stringWithFormat:@"%@%@", NSLocalizedString(@"kBtnBuy", @"买入"), _tradingPair.quoteAsset[@"symbol"]];
        }else{
            cell_btn_name = [NSString stringWithFormat:@"%@%@", NSLocalizedString(@"kBtnSell", @"卖出"), _tradingPair.quoteAsset[@"symbol"]];
        }
    }else{
        cell_btn_name = NSLocalizedString(@"kNormalCellBtnLogin", @"登录");
    }
    if (_isBuy){
        _lbBuyOrSell = [self createCellLableButton:cell_btn_name];
        UIColor* color = theme.buyColor;
        _lbBuyOrSell.layer.borderColor = color.CGColor;
        _lbBuyOrSell.layer.backgroundColor = color.CGColor;
    }else{
        _lbBuyOrSell = [self createCellLableButton:cell_btn_name];
        UIColor* color = theme.sellColor;
        _lbBuyOrSell.layer.borderColor = color.CGColor;
        _lbBuyOrSell.layer.backgroundColor = color.CGColor;
    }
}

/*
 *  (private) 更新顶部最新价格和今日涨跌幅
 */
- (void)draw_ui_ticker_price_and_percent:(BOOL)isbuy
{
    NSString* latest;
    NSString* percent_change;
    NSDictionary* ticker_data = [[ChainObjectManager sharedChainObjectManager] getTickerData:[_tradingPair.baseAsset objectForKey:@"symbol"]
                                                                                       quote:[_tradingPair.quoteAsset objectForKey:@"symbol"]];
    if (ticker_data){
        latest = [OrgUtils formatFloatValue:[ticker_data[@"latest"] doubleValue]
                                  precision:_tradingPair.displayPrecision
                      usesGroupingSeparator:NO];
        percent_change = [ticker_data objectForKey:@"percent_change"];
    }else{
        latest = @"--";
        percent_change = @"0";
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    if (latest){
        _lbTickerPrice.text = latest;
        if (isbuy){
            _lbTickerPrice.textColor = theme.buyColor;
        }else{
            _lbTickerPrice.textColor = theme.sellColor;
        }
    }
    
    if (percent_change){
        double percent = [percent_change doubleValue];
        if (percent > 0.0f){
            _lbTickerPercent.textColor = theme.buyColor;
            _lbTickerPercent.text = [NSString stringWithFormat:@"+%@%%", [OrgUtils formatFloatValue:percent precision:2]];
        }else if (percent < 0){
            _lbTickerPercent.textColor = theme.sellColor;
            _lbTickerPercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2]];
        } else {
            _lbTickerPercent.textColor = theme.zeroColor;
            _lbTickerPercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2]];
        }
    }
}

/*
 *  (private) 描绘UI - 可用余额
 */
- (void)draw_ui_available:(NSString*)value enough:(BOOL)enough
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  REMARK：竖版界面宽度较小，不显示金额不足等后缀，直接颜色区分。
    id symbol = [(_isBuy ? _tradingPair.baseAsset : _tradingPair.quoteAsset) objectForKey:@"symbol"];
    id value_str = [NSString stringWithFormat:@"%@%@", value ?: @"--", symbol];
    id value_color = enough ? theme.textColorNormal : theme.tintColor;
    
    _cellAvailable.titleLabel.textColor = value_color;
    _cellAvailable.valueLabel.text = value_str;
    _cellAvailable.valueLabel.textColor = value_color;
}

- (void)draw_ui_market_fee:(NSDictionary*)asset account:(NSDictionary*)account
{
    id market_fee_percent = [[asset objectForKey:@"options"] objectForKey:@"market_fee_percent"];
    if (market_fee_percent){
        id n_market_fee_percent = [NSDecimalNumber decimalNumberWithMantissa:[market_fee_percent unsignedLongLongValue]
                                                                    exponent:-2
                                                                  isNegative:NO];
        _cellMarketFee.valueLabel.text = [NSString stringWithFormat:@"%@%%", n_market_fee_percent];
    }else{
        _cellMarketFee.valueLabel.text = @"0%";
    }
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (!_balanceData) {
        [self _gotoLogin];
        return NO;
    }
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != _tfPrice && textField != _tfNumber && textField != _tfTotal){
        return YES;
    }
    
    //  根据输入框不同，限制不同小数点位数。
    NSInteger precision = 0;
    if (textField == _tfPrice) {
        precision = _tradingPair.displayPrecision;
    } else if (textField == _tfNumber) {
        precision = _tradingPair.quotePrecision;
    } else if (textField == _tfTotal) {
        precision = _tradingPair.basePrecision;
    } else {
        assert(false);
    }
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:precision];
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
        [self onPriceOrAmountChanged:NO];
    }else{
        [self onTotalFieldChanged:NO];
    }
}

/*
 *  (private) 事件 - 百分比按钮点击
 */
- (void)onPercentButtonClicked:(UIButton*)sender
{
    if (!_balanceData){
        [self _gotoLogin];
        return;
    }
    
    id n_percent = [NSDecimalNumber numberWithFloat:(sender.tag + 1) * 0.25f];

    NSInteger precision;
    NSDecimalNumber* n_value;
    if (_isBuy) {
        precision = _tradingPair.basePrecision;
        n_value = [self auxBaseBalance];
    } else {
        precision = _tradingPair.quotePrecision;
        n_value = [self auxQuoteBalance];
    }
    //  保留小数位数 向下取整
    NSDecimalNumberHandler* floorHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                                  scale:precision
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];

    id n_value_of_percent = [n_value decimalNumberByMultiplyingBy:n_percent withBehavior:floorHandler];

    if (_isBuy){
        //  更新总金额
        _tfTotal.text = [OrgUtils formatFloatValue:n_value_of_percent usesGroupingSeparator:NO];
        [self onTotalFieldChanged:YES];
    }else{
        //  更新数量
        _tfNumber.text = [OrgUtils formatFloatValue:n_value_of_percent usesGroupingSeparator:NO];
        [self onPriceOrAmountChanged:YES];
    }
}

/*
 *  (private) - 更新滑动条对应位置
 *  bSliderTriggered - 是否由滑块触发的总金额变更。
 */
- (void)updateSliderPosition:(BOOL)bSliderTriggered
{
    //    //  本身就是滑块触发的变更，则不用更新滑块位置了。
    //    if (bSliderTriggered) {
    //        return;
    //    }
    //  去掉滑块，体验不好。
}

/*
 *  (private) 总交易额发生变化
 *  固定价格 - 重新计算数量。
 *  bSliderTriggered - 是否由滑块触发的总金额变更。
 */
- (void)onTotalFieldChanged:(BOOL)bSliderTriggered
{
    if (!_balanceData){
        return;
    }
    
    NSDecimalNumber* n_price = [OrgUtils auxGetStringDecimalNumberValue:_tfPrice.text];
    //  1、价格为0时，交易数量为空。
    if ([n_price compare:[NSDecimalNumber zero]] <= 0) {
        _tfNumber.text = @"";
        [self updateSliderPosition:bSliderTriggered];
        return;
    }
    
    //  2、固定价格，重新计算数量。
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
    if (_isBuy){
        id n_base = [self auxBaseBalance];
        [self draw_ui_available:[OrgUtils formatFloatValue:n_base] enough:[n_base compare:n_total] >= 0];
    }else{
        id n_quote = [self auxQuoteBalance];
        [self draw_ui_available:[OrgUtils formatFloatValue:n_quote] enough:[n_quote compare:n_amount] >= 0];
    }
    
    //  交易数量
    if (!str_total || [str_total isEqualToString:@""]){
        _tfNumber.text = @"";
    }else{
        _tfNumber.text = [OrgUtils formatFloatValue:n_amount usesGroupingSeparator:NO];
    }
    [self updateSliderPosition:bSliderTriggered];
}

/*
 *  (private) 输入的价格 or 数量发生变化
 *  重新计算交易总额。
 *  bSliderTriggered - 是否由滑块触发的数量变更。
 */
- (void)onPriceOrAmountChanged:(BOOL)bSliderTriggered
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
    NSDecimalNumberHandler* roundHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:_isBuy ? NSRoundUp : NSRoundDown
                                                                                                  scale:_tradingPair.basePrecision
                                                                                       raiseOnExactness:NO
                                                                                        raiseOnOverflow:NO
                                                                                       raiseOnUnderflow:NO
                                                                                    raiseOnDivideByZero:NO];
    NSDecimalNumber* n_total = [n_price decimalNumberByMultiplyingBy:n_amount withBehavior:roundHandler];
    
    //  刷新可用余额
    if (_isBuy){
        id n_base = [self auxBaseBalance];
        [self draw_ui_available:[OrgUtils formatFloatValue:n_base] enough:[n_base compare:n_total] >= 0];
    }else{
        id n_quote = [self auxQuoteBalance];
        [self draw_ui_available:[OrgUtils formatFloatValue:n_quote] enough:[n_quote compare:n_amount] >= 0];
    }
    
    //  总金额
    if (!str_price || [str_price isEqualToString:@""] || !str_amount || [str_amount isEqualToString:@""]){
        _tfTotal.text = @"";
    }else{
        _tfTotal.text = [OrgUtils formatFloatValue:n_total usesGroupingSeparator:NO];
    }
    [self updateSliderPosition:bSliderTriggered];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView == _mainTableView) {
        return kVcMainTableMax;
    } else {
        return 1;
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
            default:
                break;
        }
        //  not reached...
        return 1;
    }
    if (tableView == _historyTableView) {
        return [_dataArrayHistory count];
    } else {
        //  REMARK：盘口（固定行数 即使数据不足）
        return _showOrderMaxNumber;
    }
}

- (CGFloat)_auxCalcMainTableViewRowHeight:(NSInteger)row
{
    switch (row) {
        case kVcSubPriceTitle:
        case kVcSubNumberTitle:
        case kVcSubTotalTitle:
            return 28.0f;
        case kVcSubPercentButtons:
            return 44.0f;
        case kVcSubEmpty:
            return 16.0f;
        case kVcSubAvailable:
        case kVcSubMarketFee:
            return 26.0f;
        default:
            break;
    }
    //  其他行默认高度
    return 44.0f;
}

- (CGFloat)_auxCalcMainTableViewTotalHeight
{
    CGFloat h = 0;
    for (NSInteger i = kVcSubPriceTitle; i < kVcSubMax; ++i) {
        h += [self _auxCalcMainTableViewRowHeight:i];
    }
    h += 44.0f;
    return h;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _mainTableView){
        if (indexPath.section == kVcFormData) {
            return [self _auxCalcMainTableViewRowHeight:indexPath.row];
        } else {
            return 44.0f;
        }
    }
    if (tableView == _historyTableView) {
        return 28.0f;
    }
    return _showOrderLineHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (tableView == _historyTableView) {
        return 48.0f;
    }
    return 0.01f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (tableView == _historyTableView) {
        CGFloat fWidth = self.view.bounds.size.width;
        CGFloat fOffsetX = tableView.layoutMargins.left;
        UIView* myView = [[UIView alloc] init];
        myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(fOffsetX, 16, fWidth - fOffsetX * 2, 32)];
        titleLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        titleLabel.text = NSLocalizedString(@"kVcVerTradeLabelTradeHistory", @"交易历史");
        [myView addSubview:titleLabel];
        return myView;
    }
    return [[UIView alloc] init];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //  REMARK：重置下盘口header的边距。在 viewDidLoad 中获取到的margin值不正确。
    CGFloat fHalfWidth = self.view.bounds.size.width / 2.0f;
    CGFloat fOffsetMargin = tableView.layoutMargins.left;
    CGFloat fHalfWidthWithoutMargin = fHalfWidth - fOffsetMargin * 2;
    _viewOrderBookTitle.frame = CGRectMake(fHalfWidth + fOffsetMargin, 0, fHalfWidthWithoutMargin, _showOrderLineHeight);
    _lbTickerPrice.frame = CGRectMake(fHalfWidth + fOffsetMargin,
                                      _askTableView.bounds.size.height + _showOrderLineHeight + 3,
                                      fHalfWidthWithoutMargin, 32);
    _lbTickerPercent.frame = CGRectMake(fHalfWidth + fOffsetMargin,
                                        _askTableView.bounds.size.height + _showOrderLineHeight + 32 - 3,
                                        fHalfWidthWithoutMargin, _fLatestPriceHeight - 32);
    
    if (tableView == _mainTableView){
        switch (indexPath.section) {
            case kVcFormData:
            {
                switch (indexPath.row) {
                    case kVcSubPriceTitle:
                    case kVcSubTotalTitle:
                    case kVcSubNumberTitle:
                    {
                        ViewTitleValueCell* cell = [[ViewTitleValueCell alloc] init];
                        cell.titleLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                        switch (indexPath.row) {
                            case kVcSubPriceTitle:
                                cell.titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcVerTradeLabelPrice", @"价格 %@"),
                                                        [_tradingPair.baseAsset objectForKey:@"symbol"]];
                                break;
                            case kVcSubNumberTitle:
                                cell.titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcVerTradeLabelAmount", @"数量 %@"),
                                                        [_tradingPair.quoteAsset objectForKey:@"symbol"]];
                                break;
                            case kVcSubTotalTitle:
                                cell.titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcVerTradeLabelTotal", @"交易额 %@"),
                                                        [_tradingPair.baseAsset objectForKey:@"symbol"]];
                                break;
                            default:
                                break;
                        }
                        cell.hideBottomLine = YES;
                        return cell;
                    }
                        break;
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
                        
                    case kVcSubEmpty:
                    {
                        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                        cell.backgroundColor = [UIColor clearColor];
                        cell.accessoryType = UITableViewCellAccessoryNone;
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.textLabel.text = @" ";
                        cell.hideBottomLine = YES;
                        return cell;
                    }
                        break;
                    case kVcSubAvailable:
                        return _cellAvailable;
                        
                    case kVcSubMarketFee:
                        return _cellMarketFee;
                        
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
                    case kVcSubPercentButtons:
                        return _cellPercentButtons;
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
                [self addLabelButtonToCell:_lbBuyOrSell cell:cell leftEdge:tableView.layoutMargins.left width_factor:0.5f];
                return cell;
            }
                break;
            default:
                break;
        }
        
        //  not reached...
        return nil;
    }
    
    if (tableView == _historyTableView) {
        ViewFillOrderCellVer* cell = [[ViewFillOrderCellVer alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.backgroundColor = [UIColor clearColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.numPrecision = _tradingPair.numPrecision;
        cell.displayPrecision = _tradingPair.displayPrecision;
        [cell setItem:[_dataArrayHistory objectAtIndex:indexPath.row]];
        cell.hideTopLine = YES;
        cell.hideBottomLine = YES;
        return cell;
    }
    
    BOOL isbuy = tableView == _bidTableView;
    
    ViewBidAskCellVer* cell = nil;
    
    if (isbuy)
    {
        static NSString* bid_identify = @"id_bid_identify";
        
        cell = (ViewBidAskCellVer *)[tableView dequeueReusableCellWithIdentifier:bid_identify];
        if (!cell)
        {
            cell = [[ViewBidAskCellVer alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:bid_identify isbuy:isbuy];
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    else
    {
        static NSString* ask_identify = @"id_ask_identify";
        
        cell = (ViewBidAskCellVer *)[tableView dequeueReusableCellWithIdentifier:ask_identify];
        if (!cell)
        {
            cell = [[ViewBidAskCellVer alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:ask_identify isbuy:isbuy];
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    //  REMARK：这个最大值只取前5行的最大值，即使数据有20行甚至更多。
    NSInteger realShowNum = _showOrderMaxNumber;
    cell.numPrecision = _tradingPair.numPrecision;
    cell.displayPrecision = _tradingPair.displayPrecision;
    
    NSInteger dataIndex = indexPath.row;
    if (!isbuy) {
        //  卖盘，数据倒序显示。
        dataIndex = realShowNum - indexPath.row - 1;
    }
    [cell setRowID:dataIndex maxSum:_fMaxQuoteValue];
    
    id data = [self auxGetBitAskDataItem:indexPath isAsk:!isbuy];
    if (data){
        cell.userLimitOrderHash = _userOrderDataHash;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }else{
        cell.userLimitOrderHash = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    [cell setItem:data];
    
    return cell;
}

- (id)auxGetBitAskDataItem:(NSIndexPath*)indexPath isAsk:(BOOL)isAsk
{
    if (isAsk) {
        //  卖盘，数据倒序显示。
        return [_askDataArray safeObjectAtIndex:_showOrderMaxNumber - indexPath.row - 1];
    } else {
        //  买盘，数据正常显示。
        return [_bidDataArray safeObjectAtIndex:indexPath.row];
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //  1、买盘cell点击
    if (tableView == _bidTableView){
        id data = [self auxGetBitAskDataItem:indexPath isAsk:NO];
        if (data){
            _tfPrice.text = [OrgUtils formatFloatValue:[[data objectForKey:@"price"] doubleValue]
                                             precision:_tradingPair.displayPrecision
                                 usesGroupingSeparator:NO];
            [self onPriceOrAmountChanged:NO];
            NSLog(@"bid click: %@", data);
        }
        return;
    }
    //  2、卖盘cell点击
    if (tableView == _askTableView){
        id data = [self auxGetBitAskDataItem:indexPath isAsk:YES];
        if (data){
            _tfPrice.text = [OrgUtils formatFloatValue:[[data objectForKey:@"price"] doubleValue]
                                             precision:_tradingPair.displayPrecision
                                 usesGroupingSeparator:NO];
            [self onPriceOrAmountChanged:NO];
            NSLog(@"ask click: %@", data);
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
                //  登录
                [self _gotoLogin];
            }
        }];
        return;
    }
    return;
}

/*
 *  (private) 转到登录界面
 */
- (void)_gotoLogin
{
    if ([[WalletManager sharedWalletManager] isWalletExist]){
        return;
    }
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:_animLock body:^{
        //  REMARK：这里不用 GuardWalletExist，仅跳转登录界面，登录后停留在交易界面，而不是登录后执行买卖操作。
        //  如果当前按钮显示的是买卖，那么应该继续处理，但这里按钮显示的就是登录，那么仅执行登录处理。
        VCImportAccount* vc = [[VCImportAccount alloc] init];
        [_owner pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleLogin", @"登录") backtitle:kVcDefaultBackTitleName];
    }];
}

/*
 *  (private) 交易核心 处理买卖操作
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
    NSDecimalNumberHandler* roundHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:_isBuy ? NSRoundUp : NSRoundDown
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
    
    if (_isBuy){
        //  买的总金额
        //  _base_amount_n < n_total
        if ([[self auxBaseBalance] compare:n_total] == NSOrderedAscending){
            [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitTotalNotEnough", @"金额不足")];
            return;
        }
        
        //  TODO:5.0 fowallet 买价太高预警 !!!!
    }else{
        //  _quote_amount_n < n_amount
        if ([[self auxQuoteBalance] compare:n_amount] == NSOrderedAscending){
            [OrgUtils makeToast:NSLocalizedString(@"kVcTradeSubmitAmountNotEnough", @"数量不足")];
            return;
        }
        
        //  TODO:5.0 fowallet 卖价太低预警 !!!
    }
    
    //  --- 参数校验完毕开始执行请求 ---
    [_owner GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self processBuyOrSellActionCore:n_price amount:n_amount total:n_total];
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
    if (_isBuy){
        //  执行买入    base减少 -> quote增加
        
        //  得到数量（向上取整）
        id n_gain_total = [n_amount decimalNumberByMultiplyingByPowerOf10:_tradingPair.quotePrecision withBehavior:ceilHandler];
        min_to_receive = @{@"asset_id":_tradingPair.quoteId, @"amount":[NSString stringWithFormat:@"%@", n_gain_total]};
        
        //  卖出数量等于 买的总花费金额 = 单价*买入数量（向下取整）  REMARK：这里 n_total <= _base_amount_n
        id n_buy_total = [n_total decimalNumberByMultiplyingByPowerOf10:_tradingPair.basePrecision withBehavior:floorHandler];
        amount_to_sell = @{@"asset_id":_tradingPair.baseId, @"amount":[NSString stringWithFormat:@"%@", n_buy_total]};
    }else{
        //  执行卖出    quote减少 -> base增加
        
        //  卖出数量不能超过总数量（向下取整）                   REMARK：这里 n_amount <= _quote_amount_n
        id n_sell_amount = [n_amount decimalNumberByMultiplyingByPowerOf10:_tradingPair.quotePrecision withBehavior:floorHandler];
        amount_to_sell = @{@"asset_id":_tradingPair.quoteId, @"amount":[NSString stringWithFormat:@"%@", n_sell_amount]};
        
        //  得到数量等于 单价*卖出数量（向上取整）
        id n_gain_total = [n_total decimalNumberByMultiplyingByPowerOf10:_tradingPair.basePrecision withBehavior:ceilHandler];
        min_to_receive = @{@"asset_id":_tradingPair.baseId, @"amount":[NSString stringWithFormat:@"%@", n_gain_total]};
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
            _tfTotal.text = @"";
            //  获取新的限价单ID号
            id new_order_id = [OrgUtils extractNewObjectID:tx_data];
            [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:seller] then:(^id(id full_data) {
                [_owner hideBlockView];
                //  刷新（调用owner的方法刷新、买/卖界面都需要刷新。）
                [_owner onFullAccountInfoResponsed:full_data];
                //  获取刚才新创建的限价单
                id new_order = nil;
                if (new_order_id){
                    new_order = [_userOrderDataHash objectForKey:new_order_id];
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
                             params:@{@"account":seller, @"isbuy":@(_isBuy),
                                      @"base":_tradingPair.baseAsset[@"symbol"],
                                      @"quote":_tradingPair.quoteAsset[@"symbol"]}];
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
                             params:@{@"account":seller, @"isbuy":@(_isBuy),
                                      @"base":_tradingPair.baseAsset[@"symbol"],
                                      @"quote":_tradingPair.quoteAsset[@"symbol"]}];
                return nil;
            })];
            return nil;
        })] catch:(^id(id error) {
            [_owner hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txCreateLimitOrderFailed"
                         params:@{@"account":seller, @"isbuy":@(_isBuy),
                                  @"base":_tradingPair.baseAsset[@"symbol"],
                                  @"quote":_tradingPair.quoteAsset[@"symbol"]}];
            return nil;
        })];
    }];
}

@end
