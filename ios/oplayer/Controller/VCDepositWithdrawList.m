//
//  VCDepositWithdrawList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCDepositWithdrawList.h"
#import "BitsharesClientManager.h"
#import "ViewGatewayCoinInfoCell.h"
#import "VCGatewayDeposit.h"
#import "VCGatewayWithdraw.h"
#import "VCBtsaiWebView.h"
#import "OrgUtils.h"
#import "ScheduleManager.h"
#import "MyPopviewManager.h"

#import "Gateway/RuDEX.h"
#import "Gateway/OpenLedger.h"
#import "GatewayAssetItemData.h"

enum
{
    kVcGateway = 0, //  当前网关
    kVcCoinlist,    //  资产列表
    
    kVcMax
};

@interface VCDepositWithdrawList ()
{
    UITableViewBase*        _mainTableView;
    
    NSArray*                _gatewayArray;
    NSDictionary*           _currGateway;
    
    NSMutableDictionary*    _balanceDataHash;
    NSMutableDictionary*    _balanceDataNameHash;
    NSDictionary*           _fullAccountData;
    NSMutableArray*         _dataArray;
}

@end

@implementation VCDepositWithdrawList

-(void)dealloc
{
    _gatewayArray = nil;
    _currGateway = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _balanceDataHash = nil;
    _balanceDataNameHash = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        _dataArray = nil;
        _balanceDataHash = [NSMutableDictionary dictionary];
        _balanceDataNameHash = [NSMutableDictionary dictionary];
    }
    return self;
}

/**
 *  获取所有相关资产ID
 */
- (NSArray*)_extractAllAssetIdsFromFullAccountData:(id)fullAccountData
{
    if (!fullAccountData){
        return @[];
    }
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    id limit_orders = [fullAccountData objectForKey:@"limit_orders"];
    if (limit_orders && [limit_orders count] > 0){
        for (id order in limit_orders) {
            id sell_asset_id = order[@"sell_price"][@"base"][@"asset_id"];
            assert(sell_asset_id);
            [result setObject:@YES forKey:sell_asset_id];
        }
    }
    for (id balance_item in [fullAccountData objectForKey:@"balances"]) {
        id asset_type = [balance_item objectForKey:@"asset_type"];
        [result setObject:@YES forKey:asset_type];
    }
    return [result allKeys];
}

/**
 *  计算网关资产可用余额和冻结余额信息。
 */
- (void)_onCalcBalanceInfo
{
    [_balanceDataHash removeAllObjects];
    [_balanceDataNameHash removeAllObjects];
    
    //  计算所有资产的总挂单量信息
    NSMutableDictionary* limit_orders_values = [NSMutableDictionary dictionary];
    NSArray* limit_orders = [_fullAccountData objectForKey:@"limit_orders"];
    if (limit_orders){
        for (id order in limit_orders) {
            //  限价单卖 base 资产，卖的数量为 for_sale 字段。sell_price 只是价格信息。
            id sell_asset_id = order[@"sell_price"][@"base"][@"asset_id"];
            id sell_amount = [order objectForKey:@"for_sale"];
            //  所有挂单累加
            unsigned long long value = [limit_orders_values[sell_asset_id] unsignedLongLongValue];
            value += [sell_amount unsignedLongLongValue];
            [limit_orders_values setObject:@(value) forKey:sell_asset_id];
        }
    }
    
    //  遍历所有可用余额
    for (id balance_item in [_fullAccountData objectForKey:@"balances"]) {
        unsigned long long balance_value = [[balance_item objectForKey:@"balance"] unsignedLongLongValue];
        if (balance_value > 0){
            id asset_type = [balance_item objectForKey:@"asset_type"];
            id order_value = [limit_orders_values objectForKey:asset_type] ?: @0;
            [_balanceDataHash setObject:@{@"free":@(balance_value), @"order":order_value, @"asset_id":asset_type} forKey:asset_type];
        }
    }
    
    //  遍历所有挂单
    for (id asset_id in limit_orders_values) {
        //  已经存在添加了
        if ([_balanceDataHash objectForKey:asset_id]){
            continue;
        }
        //  添加仅挂单存在余额为0的条目。
        id order_value = [limit_orders_values objectForKey:asset_id];
        [_balanceDataHash setObject:@{@"free":@(0), @"order":order_value, @"asset_id":asset_id} forKey:asset_id];
    }
    
    //  填充 _balanceDataNameHash。
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    for (id asset_id in _balanceDataHash) {
        id obj = [chainMgr getChainObjectByID:asset_id];
        assert(obj);
        id item = [_balanceDataHash objectForKey:asset_id];
        assert(item);
        id asset_symbol = [[obj objectForKey:@"symbol"] uppercaseString];
        [_balanceDataNameHash setObject:item forKey:asset_symbol];
    }
}

- (void)queryFullAccountDataAndCoinList
{
    assert(_fullAccountData);
    
    id account_data = [_fullAccountData objectForKey:@"account"];
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    id p1  = [[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_data[@"id"]];
    id p2 = [[_currGateway objectForKey:@"api"] queryCoinList];
    
    [[[WsPromise all:@[p1, p2]] then:(^id(id data_array) {
        id asset_ids = [self _extractAllAssetIdsFromFullAccountData:[data_array firstObject]];
        return [[[ChainObjectManager sharedChainObjectManager] queryAllAssetsInfo:asset_ids] then:(^id(id data) {
            [self hideBlockView];
            [self onQueryResponsed:data_array];
            return nil;
        })];
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)onQueryResponsed:(NSArray*)data_array
{
    assert(data_array && [data_array count] == 2);
    _fullAccountData = [data_array firstObject];
    //  refresh balance & on-order values
    [self _onCalcBalanceInfo];
    
    if (_dataArray){
        [_dataArray removeAllObjects];
    }else{
        _dataArray = [NSMutableArray array];
    }
    
    id data_coin_list = [data_array lastObject];
    if (!data_coin_list || [data_coin_list isKindOfClass:[NSNull class]] || [data_coin_list count] <= 0){
        data_coin_list = nil;
    }else{
        id processed_data = [[_currGateway objectForKey:@"api"] processCoinListData:data_coin_list
                                                                        balanceHash:_balanceDataNameHash];
        if (processed_data){
            [_dataArray addObjectsFromArray:processed_data];
        }
    }
    
    //  刷新UI显示
    [_mainTableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    assert([[WalletManager sharedWalletManager] isWalletExist]);
    _fullAccountData = [[WalletManager sharedWalletManager] getWalletAccountInfo];
    
    //  TODO:1.6 动态加载配置数据
    _gatewayArray = @[
                      //    TODO:2.5 open的新api还存在部分bug，open那边再进行修复，待修复完毕之后再开放该功能。
//                      @{
//                          //    API reference: https://github.com/bitshares/bitshares-ui/files/3068123/OL-gateways-api.pdf
//                          @"name":@"OpenLedger",
//                          @"api":[[OpenLedger alloc] initWithApiConfig:@{
//                                                                         @"base":@"https://gateway.openledger.io",
//                                                                         @"assets":@"/assets",
//                                                                         @"exchanges":@"/exchanges",
//                                                                         @"request_deposit_address":@"/exchanges/%@/transfer/source/prototype",
//                                                                         @"validate":@"/exchanges/%@/transfer/destination",
//                                                                         }],
//                          @"helps":@[
//                                  @{@"title":NSLocalizedString(@"kVcDWHelpTitleSupport", @"帮助"), @"value":@"https://openledger.freshdesk.com", @"url":@YES},
//                                  ],
//                          },
                      @{
                          @"name":@"GDEX",
                          @"api":[[GatewayBase alloc] initWithApiConfig:@{
                                                                          @"base":@"https://api.gdex.io/adjust",
                                                                          @"coin_list":@"/coins",
                                                                          @"active_wallets":@"/active-wallets",
                                                                          @"trading_pairs":@"/trading-pairs",
                                                                          @"request_deposit_address":@"/simple-api/initiate-trade",
                                                                          @"check_address":@"/wallets/%@/address-validator",
                                                                          }],
                          @"helps":@[
                                  @{@"title":NSLocalizedString(@"kVcDWHelpTitleSupport", @"帮助"),
                                    @"value":@"https://support.gdex.io/", @"url":@YES},
                                  @{@"title":NSLocalizedString(@"kVcDWHelpTitleQQ", @"客服QQ"),
                                    @"value":@"602573197"},
                                  @{@"title":NSLocalizedString(@"kVcDWHelpTitleTelegram", @"电报"),
                                    @"value":@"https://t.me/GDEXer", @"url":@YES}
                                  ],
                          },
                      @{
                          //    API reference: https://docs.google.com/document/d/196hdHb1BTGdmuVi_w74y7lt4Acl0mqt8P02Xg4GSkcI/edit
                          @"name":@"RuDEX",
                          @"api":[[RuDEX alloc] initWithApiConfig:@{
                                                                    @"base":@"https://gateway.rudex.org/api/v0_3",
                                                                    @"coin_list":@"/coins",
                                                                    @"request_deposit_address":@"/wallets/%@/new-deposit-address",
                                                                    @"check_address":@"/wallets/%@/check-address",
                                                                    }],
                          @"helps":@[
                                  @{@"title":NSLocalizedString(@"kVcDWHelpTitleSupport", @"帮助"),
                                    @"value":@"https://rudex.freshdesk.com", @"url":@YES},
                                  @{@"title":@"Twitter",
                                    @"value":@"https://twitter.com/rudex_bitshares", @"url":@YES},
                                  @{@"title":NSLocalizedString(@"kVcDWHelpTitleTelegram", @"电报"),
                                    @"value":@"https://t.me/BitSharesDEX_RU", @"url":@YES},
                                  ],
                          },
                      ];
    
    assert([_gatewayArray count] > 0);
    id defaultGatewayName = NSLocalizedString(@"appDepositWithdrawDefaultGateway", @"defaultGatewayName");
    for (id gateway in _gatewayArray) {
        if ([[gateway objectForKey:@"name"] isEqualToString:defaultGatewayName]){
            _currGateway = gateway;
            break;
        }
    }
    if (!_currGateway){
        _currGateway = [_gatewayArray firstObject];
    }
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  查询
    [self queryFullAccountDataAndCoinList];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    //  REMARK：提币之后余额发生变化，需要刷新列表。
    if ([TempManager sharedTempManager].withdrawBalanceDirty){
        [TempManager sharedTempManager].withdrawBalanceDirty = NO;
        [self queryFullAccountDataAndCoinList];
    }
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (kVcGateway == section){
        id helps = [_currGateway objectForKey:@"helps"];
        if (helps && [helps count] > 0){
            return 1 + [helps count];
        }
        return 1;
    }else{
        if (_dataArray && [_dataArray count] == 0){
            //  show gateway error infos
            return 1;
        }else{
            return _dataArray ? [_dataArray count] : 0;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (kVcGateway == indexPath.section){
        if (indexPath.row == 0){
            return tableView.rowHeight;
        }else{
            return 28.0f;
        }
    }else{
        if (_dataArray && [_dataArray count] == 0){
            return tableView.rowHeight;
        }else{
            CGFloat baseHeight = 40.0 + 28.0;
            
            return baseHeight;
        }
    }
}

/**
 *  (private) 帮助按钮点击
 */
- (void)onTipButtonClicked:(UIButton*)sender
{
    //  [统计]
    [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_deposit_withdraw"}];
    VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"https://btspp.io/qam.html#qa_deposit_withdraw"];
    vc.title = NSLocalizedString(@"kVcTitleWhatIsGatewayAssets", @"什么是网关资产？");
    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == kVcGateway){
        return 0.01f;
    }
    return 44.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == kVcGateway){
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
        titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcDWHelpGatewayAssets", @"网关资产(%@个)"), @(_dataArray ? [_dataArray count] : 0)];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcGateway){
        if (indexPath.row == 0){
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.text = NSLocalizedString(@"kVcDWCellLabelCurrGateway", @"当前网关");
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
            cell.detailTextLabel.text = [_currGateway objectForKey:@"name"];
            return cell;
        }else{
            id helps = [_currGateway objectForKey:@"helps"];
            assert(helps && [helps count] > 0);
            id help_row = [helps objectAtIndex:indexPath.row - 1];
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.text = [help_row objectForKey:@"title"];
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.textLabel.font = [UIFont systemFontOfSize:14.0];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.detailTextLabel.text = [help_row objectForKey:@"value"];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0];
            return cell;
        }
    }else{
        if (_dataArray && [_dataArray count] == 0){
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = NSLocalizedString(@"kVcDWTipsGatewayNotAvailable", @"当前网关不可用。");
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.font = [UIFont boldSystemFontOfSize:13];
            return cell;
        }else{
            static NSString* identify = @"id_gateway_coin_cell";
            ViewGatewayCoinInfoCell* cell = (ViewGatewayCoinInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewGatewayCoinInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            [cell setTagData:indexPath.row];
            [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
            return cell;
        }
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == kVcGateway){
        if (indexPath.row == 0){
            [VCCommonLogic showPicker:self
                         object_lists:_gatewayArray
                                  key:@"name"
                                title:NSLocalizedString(@"kVcDWTipsSelectGateway", @"请选择要进行充提的网关")
                             callback:^(id selectItem)
             {
                 if (selectItem && ![selectItem[@"name"] isEqualToString:_currGateway[@"name"]]){
                     _currGateway = selectItem;
                     [self queryFullAccountDataAndCoinList];
                 }
             }];
        }else{
            id helps = [_currGateway objectForKey:@"helps"];
            assert(helps && [helps count] > 0);
            id help_row = [helps objectAtIndex:indexPath.row - 1];
            //  复制内容
            [UIPasteboard generalPasteboard].string = help_row[@"value"];
            [OrgUtils makeToast:NSLocalizedString(@"kVcDWTipsCopyOK", @"已复制")];
        }
    }
}

- (void)onButtonDepositClicked:(UIButton*)sender
{
    assert(sender.tag < [_dataArray count]);
    id item = [_dataArray objectAtIndex:sender.tag];
    assert(item);
    GatewayAssetItemData* appext = [item objectForKey:@"kAppExt"];
    assert(appext);
    
    if (!appext.enableDeposit){
        [OrgUtils makeToast:NSLocalizedString(@"kVcDWTipsDisableDeposit", @"该资产暂停充币。")];
        return;
    }
    
    //  获取充币地址
    [[[_currGateway objectForKey:@"api"] requestDepositAddress:item
                                               fullAccountData:_fullAccountData
                                                            vc:self] then:(^id(id err_or_desposit_item) {
        //  错误处理
        if ([err_or_desposit_item isKindOfClass:[NSString class]]){
            [OrgUtils makeToast:err_or_desposit_item];
            return nil;
        }
        assert([err_or_desposit_item isKindOfClass:[NSDictionary class]]);
        //  转到充币界面。
        VCGatewayDeposit* vc = [[VCGatewayDeposit alloc] initWithUserFullInfo:_fullAccountData
                                                              depositAddrItem:err_or_desposit_item
                                                             depositAssetItem:item];
        vc.title = [NSString stringWithFormat:NSLocalizedString(@"kVcTitleDeposit", @"%@充币"), appext.symbol];
        [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        return nil;
    })];
}

- (WsPromise*)_queryGatewayIntermediateAccountInfo:(GatewayAssetItemData*)appext
{
    id intermediateAccount = appext.intermediateAccount;
    return [WsPromise promise:(^(WsResolveHandler resolve, WsRejectHandler reject) {
        if (intermediateAccount && ![intermediateAccount isEqualToString:@""]){
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:intermediateAccount] then:(^id(id full_data) {
                [self hideBlockView];
                if (!full_data || [full_data isKindOfClass:[NSNull class]])
                {
                    resolve(NSLocalizedString(@"kVcDWWithdrawQueryGatewayAccountFailed", @"获取网关中间账号信息异常。"));
                    return nil;
                }
                resolve(full_data);
                return nil;
            })] catch:(^id(id error) {
                [self hideBlockView];
                resolve(NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。"));
                return nil;
            })];
        }else{
            //  null full account data
            resolve(nil);
        }
    })];
}

- (void)onButtonWithdrawClicked:(UIButton*)sender
{
    assert(sender.tag < [_dataArray count]);
    id item = [_dataArray objectAtIndex:sender.tag];
    assert(item);
    GatewayAssetItemData* appext = [item objectForKey:@"kAppExt"];
    assert(appext);
    if (!appext.enableWithdraw){
        [OrgUtils makeToast:NSLocalizedString(@"kVcDWTipsDisableWithdraw", @"该资产暂停提币。")];
        return;
    }
    [[self _queryGatewayIntermediateAccountInfo:appext] then:(^id(id err_nil_full_data) {
        //  错误处理
        if (err_nil_full_data && [err_nil_full_data isKindOfClass:[NSString class]]){
            [OrgUtils makeToast:err_nil_full_data];
            return nil;
        }
        VCGatewayWithdraw* vc = [[VCGatewayWithdraw alloc] initWithFullAccountData:_fullAccountData
                                                               intermediateAccount:err_nil_full_data    //  nullable
                                                                 withdrawAssetItem:item
                                                                           gateway:_currGateway];
        vc.title = [NSString stringWithFormat:NSLocalizedString(@"kVcTitleWithdraw", @"%@提币"), appext.symbol];
        [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        return nil;
    })];
}

@end
