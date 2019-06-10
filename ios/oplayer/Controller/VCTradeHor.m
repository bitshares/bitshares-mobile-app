//
//  VCTradeHor.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTradeHor.h"
#import "VCTradeMain.h"
#import "OrgUtils.h"
#import "BitsharesClientManager.h"
#import "WalletManager.h"
#import "TempManager.h"
#import "TradingPair.h"
#import "ScheduleManager.h"

@interface VCTradeHor ()
{
    BOOL            _haveAccountOnInit; //  REMARK：再界面初始化的时候是否存在帐号信息，永远判断是否登录等。
    
    TradingPair*    _tradingPair;
    
    NSDictionary*   _base;
    NSDictionary*   _quote;
    BOOL            _selectBuy;         //  是否默认选中购买标签，否则选中卖出标签。
}
@end

@implementation VCTradeHor

- (void)dealloc
{
    //  取消所有订阅
    [[ScheduleManager sharedScheduleManager] sub_market_remove_all_monitor_orders:_tradingPair];
    [[ScheduleManager sharedScheduleManager] unsub_market_notify:_tradingPair];
    _tradingPair = nil;
    _base = nil;
    _quote = nil;
}

- (id)initWithBaseInfo:(NSDictionary*)base quoteInfo:(NSDictionary*)quote selectBuy:(BOOL)selectBuy
{
    self = [super init];
    if (self) {
        // Custom initialization
        _base = base;
        _quote = quote;
        _selectBuy = selectBuy;
        
        _tradingPair = [[TradingPair alloc] initWithBaseAsset:base quoteAsset:quote];
        
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
    return @[NSLocalizedString(@"kLabelTitleBuy", @"买入"), NSLocalizedString(@"kLabelTitleSell", @"卖出")];
}

- (NSArray*)getSubPageVCArray
{
    return @[[[VCTradeMain alloc] initWithOwner:self baseInfo:_base quoteInfo:_quote isbuy:YES],
             [[VCTradeMain alloc] initWithOwner:self baseInfo:_base quoteInfo:_quote isbuy:NO],
             ];
}

- (void)onRightButtonClicked
{
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    
    id quote_symbol = [_quote objectForKey:@"symbol"];
    id base_symbol = [_base objectForKey:@"symbol"];
    if ([pAppCache is_fav_market:quote_symbol base:base_symbol]){
        //  取消自选、灰色五星、提示信息
        [pAppCache remove_fav_markets:quote_symbol base:base_symbol];
        [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:[ThemeManager sharedThemeManager].textColorGray];
        [OrgUtils makeToast:NSLocalizedString(@"kTipsAddFavDelete", @"删除自选成功")];
        //  [统计]
        [OrgUtils logEvents:@"event_market_remove_fav" params:@{@"base":base_symbol, @"quote":quote_symbol}];
    }else{
        //  添加自选、高亮五星、提示信息
        [pAppCache set_fav_markets:quote_symbol base:base_symbol];
        [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:[ThemeManager sharedThemeManager].textColorHighlight];
        [OrgUtils makeToast:NSLocalizedString(@"kTipsAddFavSuccess", @"添加自选成功")];
        //  [统计]
        [OrgUtils logEvents:@"event_market_add_fav" params:@{@"base":base_symbol, @"quote":quote_symbol}];
    }
    [pAppCache saveFavMarketsToFile];
    
    //  标记：自选列表需要更新
    [TempManager sharedTempManager].favoritesMarketDirty = YES;
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
    for (VCTradeMain* vc in _subvcArrays) {
        [vc onRefreshLoginStatus];
    }
}

/**
 *  (private) 事件 - 刷新用户订单信息
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
    
    //  添加自选按钮
    if ([[AppCacheManager sharedAppCacheManager] is_fav_market:[_quote objectForKey:@"symbol"] base:[_base objectForKey:@"symbol"]]){
        [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:[ThemeManager sharedThemeManager].textColorHighlight];
    }else{
        [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:[ThemeManager sharedThemeManager].textColorGray];
    }
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  点击事件
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  get_order_book      - 没用到
    //  get_limit_orders
    //  get_call_orders     - 当前market是core资产时需要调用 quote.bitasset.options.short_backing_asset == base.id 或者 quote、base对调。
    //  get_settle_orders   - 当前market是core资产时需要调用
    
    //  !!! subscribe_to_market
    
    //  get_market_history
    //  get_fill_order_history
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    __weak typeof(self) weak_self = self;
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    //  优先查询智能背书资产信息（之后才考虑是否查询喂价、爆仓单等信息）
    [[[chainMgr queryShortBackingAssetInfos:@[_tradingPair.baseId, _tradingPair.quoteId]] then:(^id(id sba_hash) {
        //  更新智能资产信息
        [_tradingPair RefreshCoreMarketFlag:sba_hash];
        
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
        id p2 = [api_db exec:@"get_ticker" params:@[[_base objectForKey:@"id"], [_quote objectForKey:@"id"]]];
        id p3 = [chainMgr queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
        id p4 = [chainMgr queryCallOrders:_tradingPair number:n_callorder];
        
        return [[WsPromise all:@[p0_full_info, p1, p2, p3, p4]] then:(^id(id data) {
            [self hideBlockView];
            if (weak_self){
                [weak_self onInitPromiseResponse:data];
                //  继续订阅
                [[ScheduleManager sharedScheduleManager] sub_market_notify:_tradingPair
                                                               n_callorder:n_callorder
                                                              n_limitorder:n_limitorder
                                                               n_fillorder:n_fillorder];
            }
            return nil;
        })];
    })] catch:(^id(id error) {
        [self hideBlockView];
        if (weak_self){
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        }
        return nil;
    })];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //  REMARK：考虑在这里刷新登录状态，用登录vc的callback会延迟，会看到文字变化。
    [self onRefreshLoginStatus];
    //  REMARK：用户在 订单管理 界面取消了订单，则这里需要刷新。
    [self onRefreshUserLimitOrderChanged];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    //  添加通知：订阅的市场数据
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSubMarketNotifyNewData:) name:kBtsSubMarketNotifyNewData object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    //  移除通知：订阅的市场数据
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kBtsSubMarketNotifyNewData object:nil];
    [super viewDidDisappear:animated];
}

/**
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

- (void)onInitPromiseResponse:(id)data
{
    //  1、更新账户所有资产和当前委托信息
    id full_account_data = [data objectAtIndex:0];
    if (full_account_data && ![full_account_data isKindOfClass:[NSNull class]]){
        [self onFullAccountInfoResponsed:full_account_data];
    }else{
        [self onFullAccountInfoResponsed:nil];
    }
    
    //  2、更新 ticker 数据
    id get_ticker_data = [data objectAtIndex:2];
    if (get_ticker_data && ![get_ticker_data isKindOfClass:[NSNull class]]){
        [[ChainObjectManager sharedChainObjectManager] updateTickeraData:_base[@"id"] quote:_quote[@"id"] data:get_ticker_data];
        //  设置脏标记
        [TempManager sharedTempManager].tickerDataDirty = YES;
        [self onQueryTickerDataResponse:get_ticker_data];
    }
    
    //  3、更新盘口信息（普通盘口+爆仓单）
    [self onQueryOrderBookResponse:data[1] settlement_data:data[4]];
}

- (void)onFullAccountInfoResponsed:(NSDictionary*)full_account_info
{
    if (_subvcArrays){
        for (VCTradeMain* vc in _subvcArrays) {
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
        for (VCTradeMain* vc in _subvcArrays) {
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
        for (VCTradeMain* vc in _subvcArrays) {
            [vc onQueryOrderBookResponse:merged_order_book];
        }
    }
}

- (void)onQueryTickerDataResponse:(id)data
{
    if (_subvcArrays){
        for (VCTradeMain* vc in _subvcArrays) {
            [vc onQueryTickerDataResponse:data];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self resignAllFirstResponder];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
//    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    
    if (_subvcArrays){
        for (VCTradeMain* vc in _subvcArrays) {
            [vc resignAllFirstResponder];
        }
    }
}

@end
