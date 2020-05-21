//
//  VCCallOrderRanking.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCCallOrderRanking.h"
#import "BitsharesClientManager.h"
#import "ViewCallOrderInfoCell.h"
#import "MBProgressHUDSingleton.h"
#import "OrgUtils.h"
#import "TradingPair.h"

#import "VCBtsaiWebView.h"

@interface VCRankingList ()
{
    __weak VCBase*      _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    TradingPair*        _tradingPair;
    
    UITableViewBase*    _mainTableView;
    UILabel*            _lbEmpty;
    
    NSMutableArray*     _dataCallOrders;
    NSDecimalNumber*    _feedPriceInfo;
    NSDecimalNumber*    _nTotalSettlementAmount;
    NSDecimalNumber*    _mcr;
}

@end

@implementation VCRankingList

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbEmpty = nil;
    _dataCallOrders = nil;
    _feedPriceInfo = nil;
    _nTotalSettlementAmount = nil;
    _mcr = nil;
    _tradingPair = nil;
    _current_asset = nil;
    _owner = nil;
}

- (id)initWithOwner:(VCBase*)owner asset:(NSDictionary*)asset
{
    self = [super init];
    if (self) {
        // Custom initialization
        _owner = owner;
        _tradingPair = nil;
        _current_asset = asset;
        _dataCallOrders = [NSMutableArray array];
        _feedPriceInfo = nil;
        _nTotalSettlementAmount = [NSDecimalNumber zero];
        _mcr = nil;
    }
    return self;
}

/*
 *  事件 - 页VC切换。
 */
- (void)onControllerPageChanged
{
    [self queryCallOrderData];
}

- (void)queryCallOrderData
{
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //    get_call_orders && get_full_accounts
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    //  1、债仓
    id p1 = [api exec:@"get_call_orders" params:@[[_current_asset objectForKey:@"id"], @100]];
    //  2、智能币信息（REMARK：不查询缓存）
    NSString* bitasset_data_id = [_current_asset objectForKey:@"bitasset_data_id"];
    id p2 = [[chainMgr queryAllGrapheneObjectsSkipCache:@[bitasset_data_id]] then:^id(id resultHash) {
        return [resultHash objectForKey:bitasset_data_id];
    }];
    //  3、清算单
    id p3 = [chainMgr querySettlementOrders:[_current_asset objectForKey:@"id"] number:100];
    
    //  查询
    [[[WsPromise all:@[p1, p2, p3]] then:(^id(id data_array) {
        //  相关依赖账号
        NSMutableDictionary* idHash = [NSMutableDictionary dictionary];
        for (id callorder in data_array[0]) {
            [idHash setObject:@YES forKey:[callorder objectForKey:@"borrower"]];
        }
        //  背书资产依赖
        NSString* short_backing_asset = [[[data_array objectAtIndex:1] objectForKey:@"options"] objectForKey:@"short_backing_asset"];
        [idHash setObject:@YES forKey:short_backing_asset];
        //  查询依赖
        return [[chainMgr queryAllGrapheneObjects:[idHash allKeys]] then:(^id(id resultHash) {
            [self onQueryCallOrderResponsed:data_array];
            [_owner hideBlockView];
            return nil;
        })];
    })] catch:(^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)onQueryCallOrderResponsed:(id)data_array
{
    //  1、计算喂价
    id bitasset_data = [data_array[1] copy];
    assert(bitasset_data);
    id short_backing_asset_id = [bitasset_data objectForKey:@"options"][@"short_backing_asset"];
    assert([[bitasset_data objectForKey:@"asset_id"] isEqualToString:[_current_asset objectForKey:@"id"]]);
    _tradingPair = [[TradingPair alloc] initWithBaseID:[bitasset_data objectForKey:@"asset_id"] quoteId:short_backing_asset_id];
    _feedPriceInfo = [_tradingPair calcShowFeedInfo:@[bitasset_data]];
    
    //  2、计算清算价格以及总清算量等信息
    _nTotalSettlementAmount = [self calcTotalSettlementAmounts:data_array[2] bitasset_data:bitasset_data feed_price:_feedPriceInfo];
    
    //  3、抵押单列表
    NSDecimalNumber* n_left_settlement = _nTotalSettlementAmount;
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    [_dataCallOrders removeAllObjects];
    for (id callorder in data_array[0]) {
        id n_collateral = [NSDecimalNumber decimalNumberWithMantissa:[[callorder objectForKey:@"collateral"] unsignedLongLongValue]
                                                            exponent:-_tradingPair.quotePrecision
                                                          isNegative:NO];
        id n_debt = [NSDecimalNumber decimalNumberWithMantissa:[[callorder objectForKey:@"debt"] unsignedLongLongValue]
                                                      exponent:-_tradingPair.basePrecision
                                                    isNegative:NO];
        BOOL will_be_settlement = [n_left_settlement compare:n_zero] > 0;
        
        [_dataCallOrders addObject:@{
            @"callorder": callorder,
            @"n_collateral": n_collateral,
            @"n_debt": n_debt,
            @"will_be_settlement": @(will_be_settlement)
        }];
        
        //  递减
        n_left_settlement = [n_left_settlement decimalNumberBySubtracting:n_collateral];
    }
    
    //  计算MCR
    id mcr = [[bitasset_data objectForKey:@"current_feed"] objectForKey:@"maintenance_collateral_ratio"];
    _mcr = [NSDecimalNumber decimalNumberWithMantissa:[mcr unsignedLongLongValue] exponent:-3 isNegative:NO];
    
    //  动态设置UI的可见性（没有抵押信息的情况几乎不存在）
    if ([_dataCallOrders count] > 0){
        _mainTableView.hidden = NO;
        _lbEmpty.hidden = YES;
        [_mainTableView reloadData];
    }else{
        _mainTableView.hidden = YES;
        _lbEmpty.hidden = NO;
    }
}

/*
 *  (private) 计算总清算量
 */
- (NSDecimalNumber*)calcTotalSettlementAmounts:(NSArray*)settlement_orders
                                 bitasset_data:(id)bitasset_data
                                    feed_price:(NSDecimalNumber*)feed_price
{
    assert(settlement_orders);
    assert(bitasset_data);
    
    NSDecimalNumber* n_total_settle_amount = [NSDecimalNumber zero];
    
    if (feed_price && [feed_price compare:[NSDecimalNumber zero]] > 0) {
        //  获取清算资产信息
        id settle_asset = _current_asset;
        NSInteger settle_asset_precision = [[settle_asset objectForKey:@"precision"] integerValue];
        //  获取背书资产信息
        id short_backing_asset_id = [bitasset_data objectForKey:@"options"][@"short_backing_asset"];
        id sba_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:short_backing_asset_id];
        assert(sba_asset);
        NSInteger sba_asset_precision = [[sba_asset objectForKey:@"precision"] integerValue];
        //  获取强清补偿系数
        NSDecimalNumber* n_one = [NSDecimalNumber one];
        id force_settlement_offset_percent = [bitasset_data[@"options"] objectForKey:@"force_settlement_offset_percent"];
        id n_force_settlement_offset_percent_add1 = [[NSDecimalNumber decimalNumberWithMantissa:[force_settlement_offset_percent unsignedLongLongValue]
                                                                                       exponent:-4
                                                                                     isNegative:NO] decimalNumberByAdding:n_one];
        
        //  计算清算价格 = 喂价 * （1 + 补偿系数）
        NSDecimalNumber* n_settle_price = [n_force_settlement_offset_percent_add1 decimalNumberByMultiplyingBy:feed_price];
        
        //  计算清算总金额
        NSDecimalNumber* n_settle_total = [NSDecimalNumber zero];
        for (id settle_order in settlement_orders) {
            id n_balance = [NSDecimalNumber decimalNumberWithMantissa:[settle_order[@"balance"][@"amount"] unsignedLongLongValue]
                                                             exponent:-settle_asset_precision
                                                           isNegative:NO];
            n_settle_total = [n_settle_total decimalNumberByAdding:n_balance];
        }
        n_total_settle_amount = [ModelUtils calculateAverage:n_settle_total n:n_settle_price result_precision:sba_asset_precision];
    }
    return n_total_settle_amount;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    // Do any additional setup after loading the view.
    CGRect rect = [self rectWithoutNaviAndPageBar];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kVcTipsNoCallOrder", @"还没有用户进行抵押")];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataCallOrders count];
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    //  没有数据的时候则没有 header view
    if ([_dataCallOrders count] <= 0){
        return 0.01f;
    }
    return 44.0f;
}

/**
 *  (private) 帮助按钮点击
 */
- (void)onTipButtonClicked:(UIButton*)sender
{
    if (!_owner){
        return;
    }
    [_owner gotoQaView:@"qa_feedprice"
                 title:NSLocalizedString(@"kVcTitleWhatIsFeedPrice", @"什么是喂价？")];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if ([_dataCallOrders count] <= 0){
        return [[UIView alloc] init];
    }else{
        CGFloat fWidth = self.view.bounds.size.width;
        CGFloat xOffset = tableView.layoutMargins.left;
        UIView* myView = [[UIView alloc] init];
        myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 44)];
        titleLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        
        //  当前喂价
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        id bitasset_data = [chainMgr getChainObjectByID:[_current_asset objectForKey:@"bitasset_data_id"]];
        assert(bitasset_data);
        id short_backing_asset = [chainMgr getChainObjectByID:[[bitasset_data objectForKey:@"options"] objectForKey:@"short_backing_asset"]];
        assert(short_backing_asset);
        
        NSString* str_feed_price = _feedPriceInfo ? [OrgUtils formatFloatValue:_feedPriceInfo] : @"--";
        titleLabel.text = [NSString stringWithFormat:@"%@ %@ %@/%@",
                           NSLocalizedString(@"kVcFeedCurrentFeedPrice", @"当前喂价"),
                           str_feed_price, _current_asset[@"symbol"], short_backing_asset[@"symbol"]];
        
        [myView addSubview:titleLabel];
        
        //  是否有帮助按钮
        UIButton* btnTips = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
        CGSize btn_size = btn_image.size;
        [btnTips setBackgroundImage:btn_image forState:UIControlStateNormal];
        btnTips.userInteractionEnabled = YES;
        [btnTips addTarget:self action:@selector(onTipButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        btnTips.frame = CGRectMake(fWidth - btn_image.size.width - xOffset, (44 - btn_size.height) / 2, btn_size.width, btn_size.height);
        btnTips.tag = section;
        btnTips.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
        
        [myView addSubview:btnTips];
        
        return myView;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28.0f * 3;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_callorder_rank";
    
    ViewCallOrderInfoCell* cell = (ViewCallOrderInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewCallOrderInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
    }
    
    cell.debt_precision = _tradingPair.basePrecision;
    cell.collateral_precision = _tradingPair.quotePrecision;
    cell.mcr = _mcr;
    cell.showCustomBottomLine = YES;
    cell.feedPriceInfo = _feedPriceInfo;
    [cell setItem:[_dataCallOrders objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id item = [[_dataCallOrders objectAtIndex:indexPath.row] objectForKey:@"callorder"];
        assert(item);
        [VcUtils viewUserAssets:_owner account:[item objectForKey:@"borrower"]];
    }];
}

@end

