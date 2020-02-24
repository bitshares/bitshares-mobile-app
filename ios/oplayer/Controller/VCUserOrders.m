//
//  VCUserOrders.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCUserOrders.h"
#import "BitsharesClientManager.h"
#import "ViewLimitOrderInfoCell.h"
#import "OrgUtils.h"
#import "ScheduleManager.h"
#import "VCSettlementOrders.h"
#import "MBProgressHUDSingleton.h"

@interface VCUserOrdersPages ()
{
    TradingPair*    _tradingPair;
    NSDictionary*   _userFullInfo;
    NSArray*        _tradeHistory;
}

@end

@implementation VCUserOrdersPages

-(void)dealloc
{
    _userFullInfo = nil;
    _tradeHistory = nil;
    _tradingPair = nil;
}

- (NSArray*)getTitleStringArray
{
    return @[NSLocalizedString(@"kVcOrderPageOpenOrders", @"当前订单"),
             NSLocalizedString(@"kVcOrderPageHistory", @"历史订单"),
             NSLocalizedString(@"kVcOrderPageSettleOrders", @"清算单")];
}

- (NSArray*)getSubPageVCArray
{
    id vc01 = [[VCUserOrders alloc] initWithOwner:self data:_userFullInfo history:NO tradingPair:_tradingPair filter:NO];
    id vc02 = [[VCUserOrders alloc] initWithOwner:self data:_tradeHistory history:YES tradingPair:_tradingPair filter:NO];
    id vc03 = [[VCSettlementOrders alloc] initWithOwner:self tradingPair:nil fullAccountInfo:_userFullInfo];
    return @[vc01, vc02, vc03];
}

- (id)initWithUserFullInfo:(NSDictionary*)userFullInfo tradeHistory:(NSArray*)tradeHistory tradingPair:(TradingPair*)tradingPair;
{
    self = [super init];
    if (self) {
        _userFullInfo = userFullInfo;
        _tradeHistory = tradeHistory;
        _tradingPair = tradingPair;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
}

- (void)onPageChanged:(NSInteger)tag
{
    NSLog(@"onPageChanged: %@", @(tag));
    
    //  gurad
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    //  query
    if (_subvcArrays){
        id vc = [_subvcArrays safeObjectAtIndex:tag - 1];
        if (vc){
            if ([vc isKindOfClass:[VCSettlementOrders class]]){
                VCSettlementOrders* vc_settlement_orders = (VCSettlementOrders*)vc;
                [vc_settlement_orders querySettlementOrders];
            }
        }
    }
}

@end

@interface VCUserOrders ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    TradingPair*            _tradingPair;
    BOOL                    _filterWithTradingPair;
    
    BOOL                    _isHistory;
    NSDictionary*           _assetBasePriority;                 //  asset资产作为 base 交易对的优先级。
    
    NSDictionary*           _fullUserData;                      //  用户信息
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmptyOrder;
}

@end

@implementation VCUserOrders

/**
 *  (private) 生成历史订单列表信息
 */
- (NSMutableArray*)genTradeHistoryData:(NSArray*)history_list
{
    NSMutableArray* dataArray = [NSMutableArray array];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    //  - 历史委托
    for (id history in history_list) {
        id fill_info = [[history objectForKey:@"op"] objectAtIndex:1];
        id pays = [fill_info objectForKey:@"pays"];
        id receives = [fill_info objectForKey:@"receives"];
        //  是否是爆仓单
        id order_id = [fill_info objectForKey:@"order_id"];
        BOOL isCallOrder = [[[order_id componentsSeparatedByString:@"."] objectAtIndex:1] integerValue] == ebot_call_order;
        
        id pays_asset = [chainMgr getChainObjectByID:[pays objectForKey:@"asset_id"]];
        id receives_asset = [chainMgr getChainObjectByID:[receives objectForKey:@"asset_id"]];
        assert(pays_asset);
        assert(receives_asset);
        
        NSInteger pays_priority = [[_assetBasePriority objectForKey:[pays_asset objectForKey:@"symbol"]] integerValue];
        NSInteger receives_priority = [[_assetBasePriority objectForKey:[receives_asset objectForKey:@"symbol"]] integerValue];
        
        NSInteger pays_precision = [[pays_asset objectForKey:@"precision"] integerValue];
        NSInteger receives_precision = [[receives_asset objectForKey:@"precision"] integerValue];
        
        double pays_value = [OrgUtils calcAssetRealPrice:pays[@"amount"] precision:pays_precision];
        double receives_value = [OrgUtils calcAssetRealPrice:receives[@"amount"] precision:receives_precision];
        
        BOOL issell;
        double price;
        NSString* price_str;
        NSString* amount_str;
        NSString* total_str;
        NSString* pays_sym;
        NSString* receives_sym;
        //  REMARK: pays 是卖出的资产，除以 pays 则为卖价(每1个 pays 资产的价格)。反正 pays / receives 则为买入价。
        if (pays_priority > receives_priority){
            //  buy     price = pays / receives
            issell = NO;
            price = pays_value / receives_value;
            price_str = [OrgUtils formatFloatValue:price precision:pays_precision];
            
            amount_str = [OrgUtils formatAssetString:receives[@"amount"] precision:receives_precision];
            total_str = [OrgUtils formatAssetString:pays[@"amount"] precision:pays_precision];
            
            pays_sym = [pays_asset objectForKey:@"symbol"];
            receives_sym = [receives_asset objectForKey:@"symbol"];
        }else{
            //  sell    price = receives / pays
            issell = YES;
            price = receives_value / pays_value;
            price_str = [OrgUtils formatFloatValue:price precision:receives_precision];
            
            amount_str = [OrgUtils formatAssetString:pays[@"amount"] precision:pays_precision];
            total_str = [OrgUtils formatAssetString:receives[@"amount"] precision:receives_precision];
            
            pays_sym = [receives_asset objectForKey:@"symbol"];
            receives_sym = [pays_asset objectForKey:@"symbol"];
        }
        //  REMARK：特殊处理，如果按照 pays or receives 的精度格式化出价格为0了，则扩大精度重新格式化。
        if ([price_str isEqualToString:@"0"]){
            price_str = [OrgUtils formatFloatValue:price precision:8];
        }
        //  构造可变对象，方便后面更新 block_time 字段。
        id data_item = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        @YES, @"ishistory",
                        @(issell), @"issell",
                        price_str, @"price",
                        amount_str, @"amount",
                        total_str, @"total",
                        pays_sym, @"base_symbol",
                        receives_sym, @"quote_symbol",
                        history[@"id"], @"id",
                        history[@"block_num"], @"block_num",
                        fill_info[@"account_id"], @"seller",
                        @(isCallOrder), @"iscall",
                        nil];
        [dataArray addObject:data_item];
    }
    [dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSDecimalNumber* n1 = [NSDecimalNumber decimalNumberWithString:[[[obj1 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject]];
        NSDecimalNumber* n2 = [NSDecimalNumber decimalNumberWithString:[[[obj2 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject]];
        return [n2 compare:n1];
    })];
    return dataArray;
}

-(void)dealloc
{
    _owner = nil;
    _assetBasePriority = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _tradingPair = nil;
}

/*
 *  事件 - 页面切换
 */
- (void)onControllerPageChanged
{
    if (!_filterWithTradingPair) {
        return;
    }
    //  尚未登录
    if (![[WalletManager sharedWalletManager] isWalletExist]) {
        return;
    }
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    id uid = [op_account objectForKey:@"id"];
    //  查询用户所有订单
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [[[chainMgr queryFullAccountInfo:uid] then:^id(id full_account_data) {
        //  查询所有订单相关依赖
        NSMutableDictionary* asset_id_hash = [NSMutableDictionary dictionary];
        id limit_orders = [full_account_data objectForKey:@"limit_orders"];
        if (limit_orders && [limit_orders count] > 0){
            for (id order in limit_orders) {
                id sell_price = [order objectForKey:@"sell_price"];
                [asset_id_hash setObject:@YES forKey:[[sell_price objectForKey:@"base"] objectForKey:@"asset_id"]];
                [asset_id_hash setObject:@YES forKey:[[sell_price objectForKey:@"quote"] objectForKey:@"asset_id"]];
            }
        }
        return [[chainMgr queryAllGrapheneObjects:[asset_id_hash allKeys]] then:^id(id data) {
            [_owner hideBlockView];
            [self refreshWithFullUserData:full_account_data reloadView:YES];
            return nil;
        }];
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

- (id)initWithOwner:(VCBase*)owner data:(id)data history:(BOOL)history tradingPair:(TradingPair*)tradingPair filter:(BOOL)filterWithTradingPair
{
    self = [super init];
    if (self) {
        _owner = owner;
        _isHistory = history;
        _tradingPair = tradingPair;
        _filterWithTradingPair = filterWithTradingPair;
        _fullUserData = nil;
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        _assetBasePriority = [chainMgr genAssetBasePriorityHash];
        if (_isHistory){
            _dataArray = [self genTradeHistoryData:data];
        }else{
            //  刷新数据
            [self refreshWithFullUserData:data reloadView:NO];
        }
    }
    return self;
}

/**
 * (private) 处理查询区块头信息返回结果
 */
- (void)onQueryAllBlockHeaderInfosResponsed:(id)data
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    for (id data in _dataArray) {
        id block_num = [data objectForKey:@"block_num"];
        id block_header = [chainMgr getBlockHeaderInfoByBlockNumber:block_num];
        assert(block_header);
        [data setObject:[block_header objectForKey:@"timestamp"] ?: @"" forKey:@"block_time"];
    }
    
    [self refreshView];
}

/**
 *  (private) 刷新数据
 */
- (void)refreshWithFullUserData:(id)full_user_info reloadView:(BOOL)reload
{
    if (full_user_info) {
        _dataArray = [ModelUtils processLimitOrders:[full_user_info objectForKey:@"limit_orders"]
                                             filter:_filterWithTradingPair ? _tradingPair : nil];
    } else {
        _dataArray = [NSMutableArray array];
    }
    //  计算手续费对象
    _fullUserData = full_user_info;
    if (reload){
        [self refreshView];
    }
}

- (void)refreshView
{
    _mainTableView.hidden = [_dataArray count] <= 0;
    _lbEmptyOrder.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  查询历史交易的时间戳信息
    if (_isHistory && [_dataArray count] > 0){
        //  查询 block header 信息，获取交易历史的时间戳。
        NSMutableDictionary* block_num_hash = [NSMutableDictionary dictionary];
        for (id data in _dataArray) {
            block_num_hash[[data objectForKey:@"block_num"]] = @YES;
        }
        NSArray* block_num_list = [block_num_hash allKeys];
        //  这里面引用的变量必须是 weak 的，不然该 vc 没法释放。 TODO:fowallet api catch
        __weak id this = self;
        [[[[ChainObjectManager sharedChainObjectManager] queryAllBlockHeaderInfos:block_num_list skipQueryCache:NO] then:(^id(id data) {
            if (this){
                [this onQueryAllBlockHeaderInfosResponsed:data];
            }else{
                //  查询结束 vc 已经释放了，则直接忽略。
                NSLog(@"vc released...");
            }
            return nil;
        })] catch:(^id(id error) {
            //  TODO:fowallet 请求异常直接忽略？？
            return nil;
        })];
    }
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    _mainTableView.hidden = [_dataArray count] <= 0;
    
    //  UI - 空
    _lbEmptyOrder = [[UILabel alloc] initWithFrame:rect];
    _lbEmptyOrder.lineBreakMode = NSLineBreakByWordWrapping;
    _lbEmptyOrder.numberOfLines = 1;
    _lbEmptyOrder.contentMode = UIViewContentModeCenter;
    _lbEmptyOrder.backgroundColor = [UIColor clearColor];
    _lbEmptyOrder.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _lbEmptyOrder.textAlignment = NSTextAlignmentCenter;
    _lbEmptyOrder.font = [UIFont boldSystemFontOfSize:13];
    if (_isHistory){
        _lbEmptyOrder.text = NSLocalizedString(@"kVcOrderTipNoHistory", @"近期没有交易记录");
    }else{
        _lbEmptyOrder.text = NSLocalizedString(@"kVcOrderTipNoOpenOrder", @"当前没有任何订单");
    }
    [self.view addSubview:_lbEmptyOrder];
    _lbEmptyOrder.hidden = !_mainTableView.hidden;
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

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_userlimitorders";
    ViewLimitOrderInfoCell* cell = (ViewLimitOrderInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewLimitOrderInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify
                                                          vc:_isHistory ? nil : self];
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

#pragma mark- for actions

- (void)processCancelOrderCore:(id)order fee_item:(id)fee_item
{
    assert(_fullUserData);
    
    id order_id = order[@"id"];
    id fee_asset_id = [fee_item objectForKey:@"fee_asset_id"];
    id account_id = [[_fullUserData objectForKey:@"account"] objectForKey:@"id"];
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
                                   opaccount:[_fullUserData objectForKey:@"account"]
                                        body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        //  请求网络广播
        [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] cancelLimitOrders:@[op]] then:(^id(id data) {
            //  订单取消了：设置待更新标记
            if (_tradingPair){
                [[ScheduleManager sharedScheduleManager] sub_market_monitor_order_update:_tradingPair updated:YES];
                //  设置订单变化标记
                [TempManager sharedTempManager].userLimitOrderDirty = YES;
            }
            [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_id] then:(^id(id full_data) {
                NSLog(@"cancel order & refresh: %@", full_data);
                [_owner hideBlockView];
                //  刷新
                [self refreshWithFullUserData:full_data reloadView:YES];
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

- (void)onButtonClicked_CancelOrder:(UIButton*)button
{
    if (_isHistory){
        return;
    }
    
    assert(_fullUserData);
    
    id order = [_dataArray objectAtIndex:button.tag];
    NSLog(@"cancel : %@", order[@"id"]);
    
    id raw_order = [order objectForKey:@"raw_order"];
    id extra_balance = @{raw_order[@"sell_price"][@"base"][@"asset_id"]:raw_order[@"for_sale"]};
    
    id fee_item = [[ChainObjectManager sharedChainObjectManager] getFeeItem:ebo_limit_order_cancel
                                                          full_account_data:_fullUserData
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

@end
