//
//  VCKLine.m
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCKLine.h"
#import "VCKlineIndexSetting.h"

#import "MKlineItemData.h"
#import "ViewTickerHeader.h"
#import "ViewKLineButtons.h"
#import "ViewKLine.h"
#import "ViewDeepGraph.h"
#import "ViewOrderBookCell.h"
#import "ViewTradeHistoryCell.h"

#import "VCTradeHor.h"

#import "NativeAppDelegate.h"
#import "ScheduleManager.h"
#import "OrgUtils.h"

enum
{
    kBottomButtonTagBuy = 0,    //  买
    kBottomButtonTagSell,       //  卖
    kBottomButtonTagFav,        //  收藏
    
    kBottomButtonTagMax
};

enum
{
    kVcKLineMain = 0,           //  K先上面固定行数区域部分（标题、时间周期按钮、K线、深度成交按钮）
    kVcDeepOrHistory,           //  下面可变区域部分（深度、成交历史）
    
    kVcMax
};

enum
{
    kVcSubRowHeaderView = 0,    //  基本信息
    kVcSubRowPeriodButtons,     //  行为按钮
    kVcSubRowKline,             //  k线主图
    kVcSubRowOrderBook,         //  盘口
    
    kVcSubRowMax
};

enum
{
    kLineButtonShowDeep = 0,    //  显示深度和盘口信息
    kLineButtonShowHistory      //  显示成交历史信息
};

@interface VCKLine ()
{
    TradingPair*            _tradingPair;
    
    UITableView*            _mainTableView;
    
    UIButton*               _btnFav;                    //  底部收藏按钮（交易界面收藏or取消返回K线界面需要刷新状态）
    
    ViewTickerHeader*       _viewTickerHeader;
    ViewKLineButtons*       _viewLineButtons;
    ViewKLine*              _viewKLine;
    ViewDeepGraph*          _viewDeepGraph;
    ViewOrderBookCell*      _viewOrderBookCell;
    ViewKLineButtons*       _viewLineButtonsDeepAndHistory;
    
    NSMutableArray*         _dataArrayHistory;          //  成交历史
    
    NSInteger               _currSecondPartyShowIndex;  //  第二行按钮当前选中索引
    
    NSDecimalNumber*        _feedPriceInfo;             //  喂价信息（有的交易对没有喂价）
}

@end

@implementation VCKLine

- (void)dealloc
{
    //  取消订阅
    [[ScheduleManager sharedScheduleManager] unsub_market_notify:_tradingPair];
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithBaseAsset:(NSDictionary*)baseAsset quoteAsset:(NSDictionary*)quoteAsset
{
    self = [super init];
    if (self) {
        // Custom initialization
        _tradingPair = [[TradingPair alloc] initWithBaseAsset:baseAsset quoteAsset:quoteAsset];
        _dataArrayHistory = [NSMutableArray array];
        _currSecondPartyShowIndex = kLineButtonShowDeep;
        _feedPriceInfo = nil;
    }
    return self;
}

- (void)onQueryTodayInfoResponsed:(id)one_kdata
{
    MKlineItemData* model = nil;
    if (one_kdata && ![one_kdata isKindOfClass:[NSNull class]] && [one_kdata count] > 0){
        model = [MKlineItemData parseData:one_kdata[0]
                                   fillto:nil
                                  base_id:_tradingPair.baseId
                           base_precision:_tradingPair.basePrecision
                          quote_precision:_tradingPair.quotePrecision
                              ceilHandler:nil
                           percentHandler:nil];
    }
    [_viewTickerHeader refreshInfos:model feedPrice:_feedPriceInfo];
}

- (void)onQueryKdataResponsed:(id)data_array
{
    //  TODO:fowallet 这个返回的数据不包含 成交量为 0的数据，如果24h量为了，这里面没显示。
    //  TODO:fowallet !!!!
    assert(data_array);
    [_viewKLine refreshCandleLayer:data_array];
}

- (void)onButtomButtonClicked:(UIButton*)sender
{
    assert(sender.tag != kBottomButtonTagFav);
    VCTradeHor* vc = [[VCTradeHor alloc] initWithBaseInfo:_tradingPair.baseAsset
                                                quoteInfo:_tradingPair.quoteAsset
                                                selectBuy:sender.tag == kBottomButtonTagBuy];
    vc.title = [NSString stringWithFormat:@"%@/%@", [_tradingPair.quoteAsset objectForKey:@"symbol"], [_tradingPair.baseAsset objectForKey:@"symbol"]];
    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

/**
 *  (private) 事件 - 收藏按钮点击（参考交易界面右上角按钮对应逻辑）
 */
- (void)onButtomFavButtonClicked:(UIButton*)sender
{
    assert(sender.tag == kBottomButtonTagFav);
    
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    
    id quote_symbol = [_tradingPair.quoteAsset objectForKey:@"symbol"];
    id base_symbol = [_tradingPair.baseAsset objectForKey:@"symbol"];
    if ([pAppCache is_fav_market:quote_symbol base:base_symbol]){
        //  取消自选、灰色五星、提示信息
        [pAppCache remove_fav_markets:quote_symbol base:base_symbol];
        sender.tintColor = [ThemeManager sharedThemeManager].textColorGray;
        [OrgUtils makeToast:NSLocalizedString(@"kTipsAddFavDelete", @"删除自选成功")];
        //  [统计]
        [OrgUtils logEvents:@"event_market_remove_fav" params:@{@"base":base_symbol, @"quote":quote_symbol}];
    }else{
        //  添加自选、高亮五星、提示信息
        [pAppCache set_fav_markets:quote_symbol base:base_symbol];
        sender.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
        [OrgUtils makeToast:NSLocalizedString(@"kTipsAddFavSuccess", @"添加自选成功")];
        //  [统计]
        [OrgUtils logEvents:@"event_market_add_fav" params:@{@"base":base_symbol, @"quote":quote_symbol}];
    }
    [pAppCache saveFavMarketsToFile];
    
    //  标记：自选列表需要更新
    [TempManager sharedTempManager].favoritesMarketDirty = YES;
}

- (NSString*)getPeriodName:(EKlineDatePeriodType)ekdptType
{
    switch (ekdptType) {
        case ekdpt_timeline:
            return NSLocalizedString(@"kLabelEkdptLine", @"分时");
        case ekdpt_1m:
            return NSLocalizedString(@"kLabelEkdpt1min", @"1分");
        case ekdpt_5m:
            return NSLocalizedString(@"kLabelEkdpt5min", @"5分");
        case ekdpt_15m:
            return NSLocalizedString(@"kLabelEkdpt15min", @"15分");
        case ekdpt_30m:
            return NSLocalizedString(@"kLabelEkdpt30min", @"30分");
        case ekdpt_1h:
            return NSLocalizedString(@"kLabelEkdpt1hour", @"1小时");
        case ekdpt_4h:
            return NSLocalizedString(@"kLabelEkdpt4hour", @"4小时");
        case ekdpt_1d:
            return NSLocalizedString(@"kLabelEkdpt1day", @"日线");
        case ekdpt_1w:
            return NSLocalizedString(@"kLabelEkdpt1week", @"周线");
        default:
            break;
    }
    assert(NO);
    return nil;
}

/**
 *  (private) 初始化K线时间周期按钮信息
 */
- (NSDictionary*)genLineButtonArgs_Periods
{
    id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
    assert(parameters);
    
    id kline_period_ary = parameters[@"kline_period_ary"];
    assert(kline_period_ary);
    
    NSInteger kline_period_default = [parameters[@"kline_period_default"] integerValue];
    assert(kline_period_default >= 0 && kline_period_default < [kline_period_ary count]);
    
    NSMutableArray* buttonArray = [NSMutableArray array];
    for (id ekdpt_value in kline_period_ary) {
        NSInteger ekdpt = [ekdpt_value integerValue];
        NSString* name = [self getPeriodName:(EKlineDatePeriodType)ekdpt];
        if (!name){
            continue;
        }
        [buttonArray addObject:@{@"name":name, @"value":@(ekdpt)}];
    }
    
    //  更多 - 按钮
    [buttonArray addObject:@{@"name":NSLocalizedString(@"kLabelEkdptBtnMore", @"更多◢"), @"value":@(kBTS_KLINE_MORE_BUTTON_VALUE), @"disable_selected":@YES}];
    
    //  指标 - 按钮
    [buttonArray addObject:@{@"name":NSLocalizedString(@"kLabelEkdptBtnIndex", @"指标"), @"value":@(kBTS_KLINE_INDEX_BUTTON_VALUE), @"disable_selected":@YES}];
    
    return @{@"button_list":buttonArray, @"default_value":@([[kline_period_ary objectAtIndex:kline_period_default] integerValue])};
}

//- (void)onFLipMarketClicked
//{
//      TODO:flip pairs and request again...
//    [self _queryInitData];
//}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
  
    CGFloat safeHeight = [self heightForBottomSafeArea];
    CGFloat fBottomViewHeight = 60.0f;
    
    //  UI - 列表
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat tableViewHeight = screenRect.size.height - [self heightForStatusAndNaviBar] - fBottomViewHeight - safeHeight;
    CGRect rectTableView = CGRectMake(0, 0, screenRect.size.width, tableViewHeight);
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rectTableView style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.showsVerticalScrollIndicator = NO;                   //  不显示滚动条
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 子界面 顶部基本信息
    _viewTickerHeader = [[ViewTickerHeader alloc] initWithTradingPair:_tradingPair];
    
    //  UI - 子界面 时间周期按钮 //TODO:height
    _viewLineButtons = [[ViewKLineButtons alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 32)
                                                  button_infos:[self genLineButtonArgs_Periods]
                                                         owner:self action:@selector(onSliderButtonClicked:)];
    
    //  UI - 子界面 K线主界面
    _viewKLine = [[ViewKLine alloc] initWithWidth:self.view.bounds.size.width
                                        baseAsset:_tradingPair.baseAsset
                                       quoteAsset:_tradingPair.quoteAsset];
    
    //  UI - 子界面 深度和成交历史按钮 //TODO:fowallet height
    _viewLineButtonsDeepAndHistory = [[ViewKLineButtons alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 32)
                                                                button_infos:@{@"button_list":@[@{@"name":NSLocalizedString(@"kLabelBtnDepth", @"深度"), @"value":@(kLineButtonShowDeep)}, @{@"name":NSLocalizedString(@"kLabelBtnMarketTrades", @"成交"), @"value":@(kLineButtonShowHistory)}],
                                                                               @"default_value":@(_currSecondPartyShowIndex)}
                                                                       owner:self action:@selector(onSliderButtonClicked_DeepAndHistory:)];
    
    //  UI - 子界面 深度信息
    _viewDeepGraph = [[ViewDeepGraph alloc] initWithWidth:self.view.bounds.size.width tradingPair:_tradingPair];
    
    //  UI - 子界面 买卖盘口信息
    _viewOrderBookCell = [[ViewOrderBookCell alloc] initWithTradingPair:_tradingPair];
    
    //  UI - 顶部按钮：买入、卖出、收藏
    UIView* pBottomView = [[UIView alloc] initWithFrame:CGRectMake(0, tableViewHeight, screenRect.size.width, fBottomViewHeight + safeHeight)];
    [self.view addSubview:pBottomView];
    pBottomView.backgroundColor = [ThemeManager sharedThemeManager].tabBarColor;
    
    //  底部按钮尺寸
    CGFloat fBottomBuySellWidth = screenRect.size.width * 0.75;
    CGFloat fBottomButtonWidth = fBottomBuySellWidth / 2 - 12;
    CGFloat fBottomButton = 44.0f;
    
    //  - 买
    UIButton* btnBottomBuy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnBottomBuy.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    btnBottomBuy.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [btnBottomBuy setTitle:NSLocalizedString(@"kLabelTitleBuy", @"买入") forState:UIControlStateNormal];
    [btnBottomBuy setTitleColor:[ThemeManager sharedThemeManager].textColorPercent forState:UIControlStateNormal];
    btnBottomBuy.userInteractionEnabled = YES;
    [btnBottomBuy addTarget:self action:@selector(onButtomButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnBottomBuy.frame = CGRectMake(12, (fBottomViewHeight  - fBottomButton) / 2, fBottomButtonWidth, fBottomButton);
    btnBottomBuy.tag = kBottomButtonTagBuy;
    btnBottomBuy.backgroundColor = [ThemeManager sharedThemeManager].buyColor;
    [pBottomView addSubview:btnBottomBuy];
    
    //  - 卖
    UIButton* btnBottomSell = [UIButton buttonWithType:UIButtonTypeSystem];
    btnBottomSell.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    btnBottomSell.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [btnBottomSell setTitle:NSLocalizedString(@"kLabelTitleSell", @"卖出") forState:UIControlStateNormal];
    [btnBottomSell setTitleColor:[ThemeManager sharedThemeManager].textColorPercent forState:UIControlStateNormal];
    btnBottomSell.userInteractionEnabled = YES;
    [btnBottomSell addTarget:self action:@selector(onButtomButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnBottomSell.frame = CGRectMake(12 + fBottomButtonWidth + 12, (fBottomViewHeight  - fBottomButton) / 2, fBottomButtonWidth, fBottomButton);
    btnBottomSell.tag = kBottomButtonTagSell;
    btnBottomSell.backgroundColor = [ThemeManager sharedThemeManager].sellColor;
    [pBottomView addSubview:btnBottomSell];
    
    //  - 收藏
    _btnFav = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* image = [UIImage templateImageNamed:@"iconFav"];
    [_btnFav setBackgroundImage:image forState:UIControlStateNormal];
    _btnFav.frame = CGRectMake(fBottomBuySellWidth + (screenRect.size.width - fBottomBuySellWidth - image.size.width) / 2,
                              (fBottomViewHeight - image.size.height) / 2,
                              image.size.width, image.size.height);
    _btnFav.userInteractionEnabled = YES;
    [_btnFav addTarget:self action:@selector(onButtomFavButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    _btnFav.tag = kBottomButtonTagFav;
    [self _refreshFavButtonStatus];
    [pBottomView addSubview:_btnFav];
    
    //  k线测试数据
    
    //  TODO:fowallet 开始加载测试数据
    _viewKLine.ekdptType = ekdpt_15m;   //  TODO:fowallet 900s 15m
    
    //  查询数据
    [self _queryInitData];
}

- (void)_queryInitData
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    //  优先查询智能背书资产信息（之后才考虑是否查询喂价、爆仓单等信息）
    [[[chainMgr queryShortBackingAssetInfos:@[_tradingPair.baseId, _tradingPair.quoteId]] then:(^id(id sba_hash) {
        //  更新智能资产信息
        [_tradingPair RefreshCoreMarketFlag:sba_hash];
        
        //  1、查询K线基本数据
        id parameters = [chainMgr getDefaultParameters];
        id kline_period_ary = parameters[@"kline_period_ary"];
        assert(kline_period_ary);
        NSInteger kline_period_default = [parameters[@"kline_period_default"] integerValue];
        assert(kline_period_default >= 0 && kline_period_default < [kline_period_ary count]);
        NSInteger kline_period_default_value = [[kline_period_ary objectAtIndex:kline_period_default] integerValue];
        NSInteger default_query_seconds = [self getDatePeriodSeconds:(EKlineDatePeriodType)kline_period_default_value];
        NSInteger now = [[NSDate date] timeIntervalSince1970];
        id snow = [OrgUtils formatBitsharesTimeString:now];
        id sbgn = [OrgUtils formatBitsharesTimeString:now-default_query_seconds*kBTS_KLINE_MAX_SHOW_CANDLE_NUM];
        //    id sbgn = [OrgUtils formatBitsharesTimeString:now-86400*200];
        
        id api_history = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_history;
        //  TODO:fowallet 这个方法一次最多返回200条数据，如果 kBTS_KLINE_MAX_SHOW_CANDLE_NUM 设置为300，那么返回的数据可能不包含近期100条。需要多次请求
        WsPromise* initKdata = [api_history exec:@"get_market_history"
                                          params:@[_tradingPair.baseId, _tradingPair.quoteId, @(default_query_seconds), sbgn, snow]];
        
        id sbgn1 = [OrgUtils formatBitsharesTimeString:now-86400*1];
        
        //  2、查询最高最低价格等信息
        WsPromise* initToday = [api_history exec:@"get_market_history"
                                          params:@[_tradingPair.baseId, _tradingPair.quoteId, @86400, sbgn1, snow]];
        
        //  获取参数
        NSInteger n_callorder = [parameters[@"kline_query_callorder_number"] integerValue];
        NSInteger n_limitorder = [parameters[@"kline_query_limitorder_number"] integerValue];
        NSInteger n_fillorder = [parameters[@"kline_query_fillorder_number"] integerValue];
        assert(n_callorder > 0 && n_limitorder > 0 && n_fillorder > 0);
        
        //  3、查询成交记录信息
        WsPromise* promiseHistory = [chainMgr queryFillOrderHistory:_tradingPair number:n_fillorder];
        
        //  4、查询限价单信息
        WsPromise* promiseLimitOrders = [chainMgr queryLimitOrders:_tradingPair number:n_limitorder];
        
        //  5、查询爆仓单和喂价信息
        WsPromise* promiseCallOrders = [chainMgr queryCallOrders:_tradingPair number:n_callorder];
        
        //  执行查询
        return [[WsPromise all:@[initKdata, initToday, promiseHistory, promiseLimitOrders, promiseCallOrders]] then:(^id(id data_array) {
            [self hideBlockView];
            id settlement_data = data_array[4];
            [self onQueryFeedPriceInfoResponsed:settlement_data];
            [self onQueryTodayInfoResponsed:data_array[1]];
            [self onQueryKdataResponsed:data_array[0]];
            [self onQueryOrderBookResponsed:data_array[3] settlement_data:settlement_data];
            [self onQueryFillOrderHistoryResponsed:data_array[2]];
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

- (void)_refreshFavButtonStatus
{
    if (_btnFav){
        if ([[AppCacheManager sharedAppCacheManager] is_fav_market:[_tradingPair.quoteAsset objectForKey:@"symbol"]
                                                              base:[_tradingPair.baseAsset objectForKey:@"symbol"]]){
            _btnFav.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
        }else{
            _btnFav.tintColor = [ThemeManager sharedThemeManager].textColorGray;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self _refreshFavButtonStatus];
}

- (void)viewDidDisappear:(BOOL)animated
{
    //  移除通知：订阅的市场数据
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kBtsSubMarketNotifyNewData object:nil];
    [super viewDidDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    //  添加通知：订阅的市场数据
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSubMarketNotifyNewData:) name:kBtsSubMarketNotifyNewData object:nil];
}

- (void)onSubMarketNotifyNewData:(NSNotification*)notification
{
    if (!notification){
        return;
    }
    id userinfo = notification.userInfo;
    if (!userinfo){
        return;
    }
    id settlement_data = [userinfo objectForKey:@"kSettlementData"];
    //  更新喂价信息
    [self onQueryFeedPriceInfoResponsed:settlement_data];
    //  更新限价单
    [self onQueryOrderBookResponsed:[userinfo objectForKey:@"kLimitOrders"] settlement_data:settlement_data];
    //  更新成交历史
    id fillOrders = [userinfo objectForKey:@"kFillOrders"];
    if (fillOrders){
        [_viewTickerHeader refreshTickerData];
        [self onQueryFillOrderHistoryResponsed:fillOrders];
    }
}

- (void)onQueryFeedPriceInfoResponsed:(id)feed_infos
{
    //  获取显示用喂价信息（可能为nil）
    _feedPriceInfo = [feed_infos objectForKey:@"feed_price_market"];
    [_viewTickerHeader refreshFeedPrice:_feedPriceInfo];
}

- (void)onQueryOrderBookResponsed:(NSDictionary*)normal_order_book settlement_data:(id)settlement_data
{
    //  订阅市场返回的数据可能为 nil。
    if (!normal_order_book){
        return;
    }
    
    //  初始化显示精度
    [_tradingPair dynamicUpdateDisplayPrecision:normal_order_book];
    
    //  刷新深度图和盘口信息
    id merged_order_book = [OrgUtils mergeOrderBook:normal_order_book settlement_data:settlement_data];
    [_viewDeepGraph refreshDeepGraph:merged_order_book];
    [_viewOrderBookCell onQueryOrderBookResponsed:merged_order_book];
}

- (void)onQueryFillOrderHistoryResponsed:(NSArray*)data_array
{
    //  订阅市场返回的数据可能为 nil。
    if (!data_array){
        return;
    }
    [_dataArrayHistory removeAllObjects];
    [_dataArrayHistory addObjectsFromArray:data_array];
    //  刷新
    [self _reloadDeepAndHistorySection];
}

- (void)queryKdata:(NSInteger)seconds ekdptType:(EKlineDatePeriodType)ekdptType
{
    //  TODO:fowallet 开始加载测试数据
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    NSInteger now = [[NSDate date] timeIntervalSince1970];
    id snow = [OrgUtils formatBitsharesTimeString:now];
    id sbgn = [OrgUtils formatBitsharesTimeString:now-seconds*kBTS_KLINE_MAX_SHOW_CANDLE_NUM];
    //    id sbgn = [OrgUtils formatBitsharesTimeString:now-86400*200];
    id api_history = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_history;
    //  TODO:fowallet 这个方法一次最多返回200条数据，如果 kBTS_KLINE_MAX_SHOW_CANDLE_NUM 设置为300，那么返回的数据可能不包含近期100条。需要多次请求
    WsPromise* initTest = [api_history exec:@"get_market_history" params:@[_tradingPair.baseId, _tradingPair.quoteId, @(seconds), sbgn, snow]];
    [[initTest then:(^id(id data) {
        [self hideBlockView];
        _viewKLine.ekdptType = ekdptType;

//        //  生成测试数据json
//        NSError* err = nil;
//        NSData* data1 = [NSJSONSerialization dataWithJSONObject:data
//                                                       options:NSJSONReadingAllowFragments
//                                                         error:&err];
//        id json = [[NSString alloc] initWithData:data1 encoding:NSUTF8StringEncoding];
                
        [self onQueryKdataResponsed:data];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        //  TODO:fowallet show error
        return nil;
    })];
}

/**
 *  获取K线时间周期对应的秒数
 */
- (NSInteger)getDatePeriodSeconds:(EKlineDatePeriodType)ekdpt
{
    switch (ekdpt) {
        case ekdpt_timeline:
            return 60;  //  分时图就是分钟线的收盘价连接的点。
        case ekdpt_1m:
            return 60;
        case ekdpt_5m:
            return 300;
        case ekdpt_15m:
            return 900;
        case ekdpt_30m:
            return 1800;
        case ekdpt_1h:
            return 3600;
        case ekdpt_4h:
            return 14400;
        case ekdpt_1d:
            return 86400;
        case ekdpt_1w:
            return 604800;
        default:
            break;
    }
    //  not reached...
    assert(false);
    return 0;
}

/**
 *  (private) 指标按钮点击
 */
- (void)_onIndexButtonClicked
{
    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    VCKlineIndexSetting* vc = [[VCKlineIndexSetting alloc] initWithResultPromise:result_promise];
    vc.title = NSLocalizedString(@"kVcTitleKlineIndexSetting", @"K线指标设置");
    vc.hidesBottomBarWhenPushed = YES;
    [self showModelViewController:vc tag:0];
    [result_promise then:(^id(id cancel) {
        if (![cancel boolValue]){
            [_viewKLine refreshUI];
        }
        return nil;
    })];
}

- (void)_onMoreButtonClicked:(UIButton*)sender
{
    id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
    assert(parameters);
    id kline_period_ary = parameters[@"kline_period_ary"];
    assert(kline_period_ary);
    NSMutableDictionary* kline_period_existed_hash = [NSMutableDictionary dictionary];
    for (id ekdpt_value in kline_period_ary) {
        [kline_period_existed_hash setObject:@YES forKey:@([ekdpt_value integerValue])];
    }
    
    id all_periods = @[@(ekdpt_timeline), @(ekdpt_1m), @(ekdpt_5m), @(ekdpt_15m), @(ekdpt_30m),
                       @(ekdpt_1h), @(ekdpt_4h), @(ekdpt_1d), @(ekdpt_1w)];
    
    NSMutableArray* more_list = [NSMutableArray array];
    EKlineDatePeriodType currentType = _viewKLine.ekdptType;
    NSInteger defaultIndex = 0;
    
    for (id period in all_periods) {
        if (![kline_period_existed_hash objectForKey:period]){
            EKlineDatePeriodType type = (EKlineDatePeriodType)[period integerValue];
            if (type == currentType){
                defaultIndex = [more_list count];
            }
            [more_list addObject:@{@"name":[self getPeriodName:type], @"value":period}];
        }
    }
    
    [[[MyPopviewManager sharedMyPopviewManager] showModernListView:self.navigationController
                                                           message:nil
                                                             items:more_list
                                                           itemkey:@"name"
                                                      defaultIndex:defaultIndex] then:(^id(id result) {
        if (result){
            [_viewLineButtons selectButton:sender
                                   newText:[NSString stringWithFormat:@"%@%@", result[@"name"], NSLocalizedString(@"kLabelEkdptMoreSuffix", "◢")]];
            EKlineDatePeriodType ekdpt = (EKlineDatePeriodType)[[result objectForKey:@"value"] integerValue];
            [self queryKdata:[self getDatePeriodSeconds:ekdpt] ekdptType:ekdpt];
        }
        return nil;
    })];
}

/**
 *  K线周期按钮点击事件
 */
- (void)onSliderButtonClicked:(UIButton*)sender
{
    NSLog(@"tag:%@", @(sender.tag));
    NSInteger tag = sender.tag;
    switch (tag) {
        case kBTS_KLINE_INDEX_BUTTON_VALUE:
            [self _onIndexButtonClicked];
            break;
        case kBTS_KLINE_MORE_BUTTON_VALUE:
            [self _onMoreButtonClicked:sender];
            break;
        default:
        {
            [_viewLineButtons updateButtonText:kBTS_KLINE_MORE_BUTTON_VALUE
                                       newText:NSLocalizedString(@"kLabelEkdptBtnMore", @"更多◢")];
            EKlineDatePeriodType ekdpt = (EKlineDatePeriodType)tag;
            [self queryKdata:[self getDatePeriodSeconds:ekdpt] ekdptType:ekdpt];
        }
            break;
    }
}

- (void)onSliderButtonClicked_DeepAndHistory:(UIButton*)sender
{
    NSInteger tag = sender.tag;
    if (tag != _currSecondPartyShowIndex){
        _currSecondPartyShowIndex = tag;
        [self _reloadDeepAndHistorySection];
    }
}

- (void)_reloadDeepAndHistorySection
{
    [UIView performWithoutAnimation:(^{
        CGPoint old_offset = _mainTableView.contentOffset;
        [_mainTableView reloadSections:[NSIndexSet indexSetWithIndex:kVcDeepOrHistory] withRowAnimation:UITableViewRowAnimationNone];
        [_mainTableView setContentOffset:old_offset animated:NO];
    })];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcKLineMain){
        return kVcSubRowMax;
    }else{
        switch (_currSecondPartyShowIndex) {
            case kLineButtonShowDeep:
                return 2;
            case kLineButtonShowHistory:
            {
                if ([_dataArrayHistory count] > 0){
                    //  增加一行标题栏
                    return [_dataArrayHistory count] + 1;
                }else{
                    return 0;
                }
            }
                break;
            default:
                assert(false);
                break;
        }
        //  not reached...
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcKLineMain){
        switch (indexPath.row) {
            case kVcSubRowHeaderView:
                return 24 * 3;
            case kVcSubRowPeriodButtons:
                return _viewLineButtons.bounds.size.height;
            case kVcSubRowKline:
                return _viewKLine.fSquareHeight + _viewKLine.fTimeAxisHeight;
            case kVcSubRowOrderBook:
                return _viewLineButtonsDeepAndHistory.bounds.size.height;
            default:
                break;
        }
        return tableView.rowHeight;
    }else{
        switch (_currSecondPartyShowIndex) {
            case kLineButtonShowDeep:
            {
                if (indexPath.row == 0){
                    return _viewDeepGraph.fCellTotalHeight;
                }else{
                    return _viewOrderBookCell.cellTotalHeight;
                }
            }
                break;
            case kLineButtonShowHistory:
                return 32;
            default:
                assert(false);
                break;
        }
        //  not reached...
        return tableView.rowHeight;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcKLineMain){
        switch (indexPath.row) {
            case kVcSubRowHeaderView:
            {
                return _viewTickerHeader;
            }
                break;
            case kVcSubRowPeriodButtons:
            {
                return _viewLineButtons;
            }
                break;
            case kVcSubRowKline:
            {
                return _viewKLine;
            }
                break;
            case kVcSubRowOrderBook:
            {
                return _viewLineButtonsDeepAndHistory;
            }
                break;
            default:
                assert(false);
                break;
        }
        //  not reach...
        return nil;
    }else{
        switch (_currSecondPartyShowIndex) {
            case kLineButtonShowDeep:
            {
                if (indexPath.row == 0){
                    return _viewDeepGraph;
                }else{
                    return _viewOrderBookCell;
                }
            }
                break;
            case kLineButtonShowHistory:
            {
                static NSString* id_trade_his_identify = @"id_kline_his_identify";
                ViewTradeHistoryCell* cell = (ViewTradeHistoryCell *)[tableView dequeueReusableCellWithIdentifier:id_trade_his_identify];
                if (!cell)
                {
                    cell = [[ViewTradeHistoryCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:id_trade_his_identify];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                }
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                cell.displayPrecision = _tradingPair.displayPrecision;
                cell.numPrecision = _tradingPair.numPrecision;
                if (indexPath.row == 0){
                    //  REMARK：标题栏
                    [cell setItem:@{@"title":@"1", @"price_asset":[_tradingPair.baseAsset objectForKey:@"symbol"], @"amount_asset":[_tradingPair.quoteAsset objectForKey:@"symbol"]}];
                }else{
                    [cell setItem:[_dataArrayHistory objectAtIndex:indexPath.row - 1]];
                }
                return cell;
            }
                break;
            default:
                assert(false);
                break;
        }
        //  not reached...
        return nil;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        //   TODO:fowallet clicked...
    }];
}

@end
