//
//  VCMarketInfo.m
//  oplayer
//
//  Created by SYALON on 14-1-12.
//
//

#import "VCMarketInfo.h"
#import "ViewMarketTickerInfoCell.h"

#import "VCKLine.h"
#import "VCTradeMain.h"
#import "VCTradeHor.h"

#import "MyTabBarController.h"

#import "AppCacheManager.h"
#import "OrgUtils.h"

#import "VCBtsaiWebView.h"

@interface VCMarketInfo ()
{
    __weak VCBase*          _owner;
    
    BOOL                    _favorites_market;      //  是否是自选市场
    NSMutableArray*         _favorites_asset_list;  //  自选列表（非自选市场该变量为nil。）
    NSDictionary*           _marketInfos;           //  市场信息配置（基本资产、引用资产、分组信息等）
    
    UITableViewBase*        _mainTableView;
    UILabel*                _lbEmptyOrder;          //  自选市场为空时的label。
}

@end

@implementation VCMarketInfo

- (void)dealloc
{
    _owner = nil;
    
    _favorites_asset_list = nil;
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    
    _lbEmptyOrder = nil;
}

- (id)initWithOwner:(VCBase*)owner marketInfo:(NSDictionary*)market_config_info
{
    self = [super init];
    if (self) {
        // Custom initialization
        _owner = owner;
        
        _mainTableView = nil;
        _lbEmptyOrder = nil;
        
        if (market_config_info){
            _favorites_market = NO;
            _favorites_asset_list = nil;
            _marketInfos = market_config_info;
        }else{
            _favorites_market = YES;
            _marketInfos = nil;
            _favorites_asset_list = nil;
            [self loadAllFavoritesMarkets];
        }
    }
    return self;
}

/**
 *  (public) 刷新自选市场
 */
- (void)onRefreshFavoritesMarket
{
    [self loadAllFavoritesMarkets];
}

/**
 *  (public) 刷新自定义交易对
 */
- (void)onRefreshCustomMarket
{
    //  自选列表不处理
    if (_favorites_market){
        return;
    }
    
    //  获取当前 base 信息
    id curr_base_symbol = _marketInfos[@"base"][@"symbol"];
    
    //  从合并后的列表筛选当前base对应的市场信息
    _marketInfos = [[[ChainObjectManager sharedChainObjectManager] getMergedMarketInfos] ruby_find:(^BOOL(id market) {
        return [curr_base_symbol isEqualToString:market[@"base"][@"symbol"]];
    })];
    assert(_marketInfos);
    
    //  重新加载
    [_mainTableView reloadData];
}

/**
 *  (public) 刷新UI（ticker数据变更）
 */
- (void)onRefreshTickerData
{
    [self reloadUI:YES];
}

- (void)reloadUI:(BOOL)reload
{
    if (!_mainTableView){
        return;
    }
    if (_favorites_market){
        _mainTableView.hidden = [_favorites_asset_list count] <= 0;
        _lbEmptyOrder.hidden = !_mainTableView.hidden;
    }
    if (reload){
        [_mainTableView reloadData];
    }
}

/**
 *  (private) 刷新自选市场列表
 */
- (void)loadAllFavoritesMarkets
{
    //  非自选市场不刷新。
    if (!_favorites_market){
        return;
    }
    
    //  加载数据
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    id favlist = [[[pAppCache get_all_fav_markets] allValues] sortedArrayUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [[obj1 objectForKey:@"base"] compare:[obj2 objectForKey:@"base"]];
    })];
    _favorites_asset_list = [NSMutableArray array];
    for (id fav_item in favlist) {
        id base_symbol = [fav_item objectForKey:@"base"];
        id quote_symbol = [fav_item objectForKey:@"quote"];
        //  是自定义交易对，则有效。
        if ([pAppCache is_custom_market:quote_symbol base:base_symbol]){
            [_favorites_asset_list addObject:fav_item];
            continue;
        }
        //  是默认交易对，则有效。
        if ([chainMgr isDefaultPair:base_symbol quote_symbol:quote_symbol]){
            [_favorites_asset_list addObject:fav_item];
            continue;
        }
        //  既不是自定义交易对、也不是默认交易对，则收藏无效了，则从收藏列表删除。（用户添加了自定义、然后收藏了、然后删除了自定义交易对）
        [pAppCache remove_fav_markets:quote_symbol base:base_symbol];
    }
    [pAppCache saveFavMarketsToFile];
    
    //  如果有UI界面则刷新。
    if (_lbEmptyOrder && _mainTableView){
        [self reloadUI:YES];
    }
}

/**
 *  重新排列交易对
 */
- (void)reloadTradingPairs
{
    //  TODO:fowallet 自定义交易对 fav了，然后删除了，fav列表需要显示么...
    
//    if (_array_data){
//        [_array_data removeAllObjects];
//    }else{
//        _array_data = [NSMutableArray array];
//    }
//    id custom_markets = [[AppCacheManager sharedAppCacheManager] get_all_custom_markets];
//    if ([custom_markets count] <= 0){
//        return;
//    }
//    NSMutableDictionary* market_hash = [NSMutableDictionary dictionary];
//    for (id market in [[ChainObjectManager sharedChainObjectManager] getDefaultMarketInfos]) {
//        id base = market[@"base"];
//        market_hash[base[@"symbol"]] = base;
//    }
//    for (id custom_item in [custom_markets allValues]) {
//        id base_symbol = custom_item[@"base"];
//        id market_base = market_hash[base_symbol];
//        //  无效数据（用户添加之后，官方删除了部分市场可能存在该情况。TODO:fowallet 考虑从缓存移除。）
//        if (!market_base){
//            continue;
//        }
//        id quote = custom_item[@"quote"];
//        [_array_data addObject:@{@"base":market_base, @"quote":quote}];
//    }
//    //  排序
//    [_array_data sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
//        return [obj1[@"quote"][@"symbol"] compare:obj2[@"quote"][@"symbol"]];
//    })];
}

/**
 *  (public) 响应：初始化行情所有ticker数据更新完毕。
 */
- (void)marketTickerDataInitDone
{
    //  REMARK：ticker 数据初始化完毕，简单刷新列表即可。
    [_mainTableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
	// Do any additional setup after loading the view.
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGRect rect = CGRectMake(0, 0, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - [self heightForTabBar] - 32 - [self heightForBottomSafeArea]);
    
    //  UI - 主列表
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    _mainTableView.hideAllLines = YES;
    
    //  UI - 空标签（仅自选市场为空时显示）
    if (_favorites_market){
        _lbEmptyOrder = [[UILabel alloc] initWithFrame:rect];
        _lbEmptyOrder.lineBreakMode = NSLineBreakByWordWrapping;
        _lbEmptyOrder.numberOfLines = 1;
        _lbEmptyOrder.contentMode = UIViewContentModeCenter;
        _lbEmptyOrder.backgroundColor = [UIColor clearColor];
        _lbEmptyOrder.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbEmptyOrder.textAlignment = NSTextAlignmentCenter;
        _lbEmptyOrder.font = [UIFont boldSystemFontOfSize:13];
        _lbEmptyOrder.text = NSLocalizedString(@"kLabelNoFavMarket", @"没有任何自选");
        [self.view addSubview:_lbEmptyOrder];
    }
    
    //  设置UI是否可见
    [self reloadUI:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    //  ...
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_favorites_market){
        //  自选市场
        return 1;
    }else{
        return [[_marketInfos objectForKey:@"group_list"] count];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_favorites_market){
        return [_favorites_asset_list count];
    }else{
        return [[[[_marketInfos objectForKey:@"group_list"] objectAtIndex:section] objectForKey:@"quote_list"] count];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 54.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (_favorites_market){
        //  自选市场
        return 16.0f;
    }else{
        return 44.0f;
    }
}

/**
 *  (private) 介绍按钮点击
 */
- (void)onIntroButtonClicked:(UIButton*)sender
{
    if (!_owner){
        return;
    }
    
    NSLog(@"intro clicked: %@", @(sender.tag));
    //  [统计]
    [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_gateway"}];
    VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"https://btspp.io/qam.html#qa_gateway"];
    vc.title = NSLocalizedString(@"kVcTitleWhatIsGateway", @"什么是网关？");
    [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (_favorites_market){
        return [[UIView alloc] init];
    }else{
        CGFloat fWidth = self.view.bounds.size.width;
        
        UIView* myView = [[UIView alloc] init];
        myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, fWidth - 24, 44)];    //  REMARK：12 和 ViewMarketTickerInfoCell 里控件边距一致。
        titleLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        
        id group_key = [_marketInfos[@"group_list"] objectAtIndex:section][@"group_key"];
        id group_info = [[ChainObjectManager sharedChainObjectManager] getGroupInfoFromGroupKey:group_key];
        titleLabel.text = NSLocalizedString([group_info objectForKey:@"name_key"], @"分区名字");
        
        [myView addSubview:titleLabel];
        
        //  是否有介绍按钮
        if ([[group_info objectForKey:@"intro"] boolValue]){
            UIButton* introButton = [UIButton buttonWithType:UIButtonTypeSystem];
            introButton.titleLabel.font = [UIFont systemFontOfSize:13];
            introButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
            [introButton setTitle:NSLocalizedString(@"kLabelGroupIntroduction", @"介绍 >") forState:UIControlStateNormal];
            [introButton setTitleColor:[ThemeManager sharedThemeManager].textColorGray forState:UIControlStateNormal];
            introButton.userInteractionEnabled = YES;
            [introButton addTarget:self action:@selector(onIntroButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            introButton.frame = CGRectMake(fWidth - 120 - 12, 0, 120, 44);
            introButton.tag = section;
            [myView addSubview:introButton];
        }
        
        return myView;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"vcmarketinfo";
    
    ViewMarketTickerInfoCell* cell = nil;//TODO:fowallet reuse??(ViewMarketTickerInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewMarketTickerInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
    }
    
    id group_info = nil;
    id base_symbol;
    id quote_symbol;
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    //  获取资产名
    if (_favorites_market){
        id fav_items = [_favorites_asset_list objectAtIndex:indexPath.row];
        base_symbol = [fav_items objectForKey:@"base"];
        quote_symbol = [fav_items objectForKey:@"quote"];
    }else{
        id group = [[_marketInfos objectForKey:@"group_list"] objectAtIndex:indexPath.section];
        group_info = [chainMgr getGroupInfoFromGroupKey:[group objectForKey:@"group_key"]];
        base_symbol = [[_marketInfos objectForKey:@"base"] objectForKey:@"symbol"];
        quote_symbol = [[group objectForKey:@"quote_list"] objectAtIndex:indexPath.row];
    }
    
    //  获取资产信息
    id base = [chainMgr getAssetBySymbol:base_symbol];
    id quote = [chainMgr getAssetBySymbol:quote_symbol];
    
    //  market 信息
    id base_market = [chainMgr getDefaultMarketInfoByBaseSymbol:base_symbol];
    id base_market_name = [[base_market objectForKey:@"base"] objectForKey:@"name"];
    
    //  获取行情数据
    id item;
    NSDictionary* ticker_data = [chainMgr getTickerData:base_symbol quote:quote_symbol];
    if (ticker_data){
        item = @{@"quote":quote, @"base":base, @"base_market_name":base_market_name, @"ticker_data":ticker_data};
    }else{
        item = @{@"quote":quote, @"base":base, @"base_market_name":base_market_name};
    }
    
    [cell setGroupInfo:group_info];
    [cell setItem:item];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        
        id base_symbol;
        id quote_symbol;
        
        if (_favorites_market){
            id fav_items = [_favorites_asset_list objectAtIndex:indexPath.row];
            base_symbol = [fav_items objectForKey:@"base"];
            quote_symbol = [fav_items objectForKey:@"quote"];
        }else{
            base_symbol = [[_marketInfos objectForKey:@"base"] objectForKey:@"symbol"];
            quote_symbol = [[[[_marketInfos objectForKey:@"group_list"] objectAtIndex:indexPath.section] objectForKey:@"quote_list"] objectAtIndex:indexPath.row];
        }

        id base = [[ChainObjectManager sharedChainObjectManager] getAssetBySymbol:base_symbol];
        id quote = [[ChainObjectManager sharedChainObjectManager] getAssetBySymbol:quote_symbol];
        
        VCKLine* vc = [[VCKLine alloc] initWithBaseAsset:base quoteAsset:quote];
        vc.title = [NSString stringWithFormat:@"%@/%@", [quote objectForKey:@"symbol"], [base objectForKey:@"symbol"]];
        
        assert(_owner);
        [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
    }];
}

#pragma mark- switch theme
- (void)switchTheme
{
    if (_mainTableView){
        [_mainTableView reloadData];
    }
    if (_lbEmptyOrder){
        _lbEmptyOrder.textColor = [ThemeManager sharedThemeManager].textColorMain;
    }
}

#pragma mark- switch language
- (void)switchLanguage
{
    if (_mainTableView){
        [_mainTableView reloadData];
    }
    if (_lbEmptyOrder){
        _lbEmptyOrder.text = NSLocalizedString(@"kLabelNoFavMarket", @"没有任何自选");
    }
}

@end
