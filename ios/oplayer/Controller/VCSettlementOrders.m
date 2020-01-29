//
//  VCSettlementOrders.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCSettlementOrders.h"
#import "ViewLimitOrderInfoCell.h"
#import "OrgUtils.h"

@interface VCSettlementOrders ()
{
    TradingPair*            _tradingPair;
    NSDictionary*           _fullAccountInfo;
    
    __weak VCBase*          _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCSettlementOrders

-(void)dealloc
{
    _owner = nil;
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _fullAccountInfo = nil;
    _tradingPair = nil;
}

- (id)initWithOwner:(VCBase*)owner tradingPair:(TradingPair*)tradingPair fullAccountInfo:(NSDictionary*)fullAccountInfo
{
    self = [super init];
    if (self){
        _owner = owner;
        _tradingPair = tradingPair;
        _fullAccountInfo = fullAccountInfo;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onQuerySettlementOrdersResponsed:(NSArray*)data_array
{
    [_dataArray removeAllObjects];
    if (data_array && [data_array count] > 0){
        //{
        //    balance =     {
        //        amount = 2019367;
        //        "asset_id" = "1.3.113";
        //    };
        //    id = "1.4.7725";
        //    owner = "1.2.139653";
        //    "settlement_date" = "2020-01-27T09:51:30";
        //},
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        for (id settle_order in data_array) {
            //  获取清算资产信息
            id settle_asset = [chainMgr getChainObjectByID:[[settle_order objectForKey:@"balance"] objectForKey:@"asset_id"]];
            assert(settle_asset);
            NSInteger settle_asset_precision = [[settle_asset objectForKey:@"precision"] integerValue];
            
            //  获取背书资产信息
            id bitasset_data = [chainMgr getChainObjectByID:[settle_asset objectForKey:@"bitasset_data_id"]];
            id short_backing_asset_id = [[bitasset_data objectForKey:@"options"] objectForKey:@"short_backing_asset"];
            id sba_asset = [chainMgr getChainObjectByID:short_backing_asset_id];
            assert(sba_asset);
            NSInteger sba_asset_precision = [[sba_asset objectForKey:@"precision"] integerValue];
            
            //  计算喂价
            id n_feed_price = [OrgUtils calcPriceFromPriceObject:bitasset_data[@"current_feed"][@"settlement_price"]
                                                         base_id:short_backing_asset_id
                                                  base_precision:sba_asset_precision
                                                 quote_precision:settle_asset_precision
                                                          invert:NO
                                                    roundingMode:NSRoundDown
                                            set_divide_precision:YES];
            
            //  获取强清补偿系数
            NSDecimalNumber* n_one = [NSDecimalNumber one];
            id force_settlement_offset_percent = [bitasset_data[@"options"] objectForKey:@"force_settlement_offset_percent"];
            id n_force_settlement_offset_percent_add1 = [[NSDecimalNumber decimalNumberWithMantissa:[force_settlement_offset_percent unsignedLongLongValue]
                                                                                           exponent:-4
                                                                                         isNegative:NO] decimalNumberByAdding:n_one];
            
            //  计算清算价格 = 喂价 * （1 + 补偿系数）
            NSDecimalNumber* n_settle_price = [n_force_settlement_offset_percent_add1 decimalNumberByMultiplyingBy:n_feed_price];
            
            //  自动计算base资产
            NSString* settle_asset_symbol = settle_asset[@"symbol"];
            NSString* sba_asset_symbol = sba_asset[@"symbol"];
            
            NSString* baseAssetSymbol;
            if (_tradingPair) {
                baseAssetSymbol = [_tradingPair.baseAsset objectForKey:@"symbol"];
            } else {
                baseAssetSymbol = [VcUtils calcBaseAsset:settle_asset_symbol asset_symbol02:sba_asset_symbol];
            }
            
            BOOL issell;
            double price;
            NSString* price_str;
            NSString* amount_str;
            NSString* total_str;
            NSString* base_sym;
            NSString* quote_sym;
            
            id n_balance = [NSDecimalNumber decimalNumberWithMantissa:[settle_order[@"balance"][@"amount"] unsignedLongLongValue]
                                                             exponent:-settle_asset_precision
                                                           isNegative:NO];
            
            if ([baseAssetSymbol isEqualToString:settle_asset_symbol]) {
                //  买入 BTS/CNY [清算]
                issell = NO;
                price = [n_settle_price doubleValue];
                price_str = [OrgUtils formatFloatValue:price precision:settle_asset_precision];
                
                id n_total = n_balance;
                id n_amount = [ModelUtils calculateAverage:n_total n:n_settle_price result_precision:sba_asset_precision];
                
                amount_str = [OrgUtils formatFloatValue:n_amount usesGroupingSeparator:NO];
                total_str = [OrgUtils formatFloatValue:n_total usesGroupingSeparator:NO];
                
                base_sym = settle_asset_symbol;
                quote_sym = sba_asset_symbol;
            } else {
                //  卖出 CNY/BTS [清算]
                issell = YES;
                n_settle_price = [n_one decimalNumberByDividingBy:n_settle_price];
                price = [n_settle_price doubleValue];
                price_str = [OrgUtils formatFloatValue:price precision:sba_asset_precision];
                
                id n_amount = n_balance;
                id n_total = [ModelUtils calTotal:n_settle_price n:n_amount result_precision:sba_asset_precision];
                
                amount_str = [OrgUtils formatFloatValue:n_amount usesGroupingSeparator:NO];
                total_str = [OrgUtils formatFloatValue:n_total usesGroupingSeparator:NO];
                
                base_sym = sba_asset_symbol;
                quote_sym = settle_asset_symbol;
            }
            
            //  REMARK：特殊处理，如果按照 base or quote 的精度格式化出价格为0了，则扩大精度重新格式化。
            if ([price_str isEqualToString:@"0"]){
                price_str = [OrgUtils formatFloatValue:price precision:8];
            }
            
            [_dataArray addObject:@{@"time":settle_order[@"settlement_date"],
                                    @"issettle":@YES,
                                    @"issell":@(issell),
                                    @"price":price_str,
                                    @"amount":amount_str,
                                    @"total":total_str,
                                    @"base_symbol":base_sym,
                                    @"quote_symbol":quote_sym,
                                    @"id": settle_order[@"id"],
                                    @"seller": settle_order[@"owner"],
                                    @"raw_order": settle_order  //  原始数据
            }];
        }
    }
    
    //  根据ID升序排列
    if ([_dataArray count] > 0){
        [_dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSInteger id1 = [[[[obj1 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            NSInteger id2 = [[[[obj2 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            return id1 - id2;
        })];
    }
    
    //  更新显示
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

- (void)querySettlementOrders
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //  TODO:4.0 limit number?
    WsPromise* p1;
    if (_tradingPair) {
        assert(_tradingPair.smartAssetId);
        p1 = [chainMgr querySettlementOrders:_tradingPair.smartAssetId number:100];
    } else {
        p1 = [chainMgr querySettlementOrdersByAccount:[[_fullAccountInfo objectForKey:@"account"] objectForKey:@"name"] number:100];
    }
    [[p1 then:^id(id data_array) {
        [_owner hideBlockView];
        //  查询依赖
        NSMutableDictionary* ids = [NSMutableDictionary dictionary];
        for (id item in data_array) {
            [ids setObject:@YES forKey:[[item objectForKey:@"balance"] objectForKey:@"asset_id"]];
            [ids setObject:@YES forKey:[item objectForKey:@"owner"]];
        }
        id ids01_array = [ids allKeys];
        return [[chainMgr queryAllGrapheneObjects:ids01_array] then:^id(id data) {
            //  查询智能资产信息
            id ids02_array = [ModelUtils collectDependence:ids01_array level_keys:@[@"bitasset_data_id"]];
            return [[chainMgr queryAllGrapheneObjectsSkipCache:ids02_array] then:^id(id data) {
                //  查询背书资产信息
                id ids03_array = [ModelUtils collectDependence:ids02_array level_keys:@[@"options", @"short_backing_asset"]];
                return [[chainMgr queryAllGrapheneObjects:ids03_array] then:^id(id data) {
                    [self onQuerySettlementOrdersResponsed:data_array];
                    return nil;
                }];
            }];
        }];
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kVcOrderTipNoSettleOrder", @"没有任何清算单")];
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
    return [_dataArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28 + 24 * 2;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_settle_order_info_cell";
    ViewLimitOrderInfoCell* cell = (ViewLimitOrderInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewLimitOrderInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
    [cell setTagData:indexPath.row];
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
