//
//  VCUserAssets.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCUserAssets.h"
#import "BitsharesClientManager.h"
#import "MBProgressHUDSingleton.h"
#import "ViewAssetInfoCell.h"
#import "WalletManager.h"
#import "VCUserActivity.h"
#import "VCVestingBalance.h"
#import "VCHtlcList.h"

#import "VCTransfer.h"
#import "VCTradeHor.h"
#import "VCTradeVertical.h"
#import "VCUserActivity.h"
#import "VCAssetOpCommon.h"
#import "VCAssetOpStakeVote.h"

#import "MBProgressHUD.h"
#import "OrgUtils.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "MyNavigationController.h"
#import "AppCacheManager.h"
#import "ViewTextFieldOwner.h"

@interface VCAccountInfoPages ()
{
    NSDictionary*   _userAssetDetailInfos;
    NSDictionary*   _assethash;
    NSDictionary*   _fullAccountInfo;
}

@end

@implementation VCAccountInfoPages

-(void)dealloc
{
    _userAssetDetailInfos = nil;
    _assethash = nil;
    _fullAccountInfo = nil;
}

- (NSArray*)getTitleStringArray
{
    return @[NSLocalizedString(@"kVcAssetPageAsset", @"资产"),
             NSLocalizedString(@"kVcAssetPageActivity", @"明细"),
             NSLocalizedString(@"kVcAssetPageHTLC", @"HTLC"),
             NSLocalizedString(@"kVcAssetPageVestingBalance", @"待解冻金额")];
}

- (NSArray*)getSubPageVCArray
{
    id vc01 = [[VCUserAssets alloc] initWithOwner:self assetDetailInfos:_userAssetDetailInfos assetHash:_assethash accountInfo:_fullAccountInfo];
    id vc02 = [[VCUserActivity alloc] initWithAccountInfo:_fullAccountInfo[@"account"]];
    id vc03 = [[VCHtlcList alloc] initWithOwner:self fullAccountInfo:_fullAccountInfo];
    id vc04 = [[VCVestingBalance alloc] initWithOwner:self fullAccountInfo:_fullAccountInfo];
    return @[vc01, vc02, vc03, vc04];
}

- (id)initWithUserAssetDetailInfos:(NSDictionary*)userAssetDetailInfos assetHash:(NSDictionary*)assetHash accountInfo:(NSDictionary*)accountInfo
{
    self = [super init];
    if (self) {
        _userAssetDetailInfos = userAssetDetailInfos;
        _assethash = assetHash;
        _fullAccountInfo = accountInfo;
    }
    return self;
}

- (void)onRightButtonClicked
{
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    
    id account = [_fullAccountInfo objectForKey:@"account"];
    id account_name = [account objectForKey:@"name"];
    if ([[pAppCache get_all_fav_accounts] objectForKey:account_name]){
        [pAppCache remove_fav_account:account_name];
        [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:[ThemeManager sharedThemeManager].textColorGray];
        [OrgUtils makeToast:NSLocalizedString(@"kTipsUnfollowed", @"已取消关注")];
        //  [统计]
        [OrgUtils logEvents:@"event_account_remove_fav" params:@{@"account":account_name}];
    }else{
        [pAppCache set_fav_account:@{@"name":account_name, @"id":[account objectForKey:@"id"]}];
        [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:[ThemeManager sharedThemeManager].textColorHighlight];
        [OrgUtils makeToast:NSLocalizedString(@"kTipsFollowed", @"关注成功")];
        //  [统计]
        [OrgUtils logEvents:@"event_account_add_fav" params:@{@"account":account_name}];
    }
    [pAppCache saveFavAccountsToFile];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  导航栏右边 收藏 和 区块浏览器 按钮
//    id btn1 = [self naviButtonWithImage:@"iconFav" action:@selector(onRightOrderButtonClicked) color:theme.textColorNormal];
//    id btn2 = [self naviButtonWithImage:@"iconFav" action:@selector(onRightUserButtonClicked) color:theme.textColorNormal];
//    [self.navigationItem setRightBarButtonItems:@[btn2, btn1]];
    
    id account_name = [[_fullAccountInfo objectForKey:@"account"] objectForKey:@"name"];
    
    //  他人帐号 关注/取消关注
    if (![[WalletManager sharedWalletManager] isMyselfAccount:account_name]){
        if ([[[AppCacheManager sharedAppCacheManager] get_all_fav_accounts] objectForKey:account_name]){
            [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:[ThemeManager sharedThemeManager].textColorHighlight];
        }else{
            [self showRightImageButton:@"iconFav" action:@selector(onRightButtonClicked) color:[ThemeManager sharedThemeManager].textColorGray];
        }
    }
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
            if ([vc isKindOfClass:[VCVestingBalance class]]){
                VCVestingBalance* vc_vesting_balance = (VCVestingBalance*)vc;
                [vc_vesting_balance queryVestingBalance];
            }else if ([vc isKindOfClass:[VCHtlcList class]]){
                VCHtlcList* vc_htlc_list = (VCHtlcList*)vc;
                [vc_htlc_list queryUserHTLCs];
            }
        }
    }
}

@end

@interface VCUserAssets ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    UILabel*                _totalAssetsTitle;
    UILabel*                _totalAssetsValues;
    
    UITableView *           _mainTableView;
    
    NSDictionary*           _userAssetDetailInfos;
    NSDictionary*           _assethash;
    NSDictionary*           _accountInfo;
    
    NSMutableArray*         _assetDataArray;
    BOOL                    _isSelfAccount;
    
    BOOL                    _showAllAssets;
    
    NSString*               _displayEstimateAsset;  //  记账单位 默认CNY
    BOOL                    _needSecondExchange;    //  是否需要2次兑换，如果显示记账单位和核心评估基准资产不同则需要二次换算。即：目标资产->CNY->USD(或其他显示单位)
}

@end

@implementation VCUserAssets

-(void)dealloc
{
    _owner = nil;
    _totalAssetsTitle = nil;
    _totalAssetsValues = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _assethash = nil;
    _userAssetDetailInfos = nil;
    _assetDataArray = nil;
    _displayEstimateAsset = nil;
}

- (id)initWithOwner:(VCBase*)owner
   assetDetailInfos:(NSDictionary*)userAssetDetailInfos
          assetHash:(NSDictionary*)assetHash
        accountInfo:(NSDictionary*)accountInfo
{
    self = [super init];
    if (self) {
        _owner = owner;
        _userAssetDetailInfos = userAssetDetailInfos;
        _assethash = assetHash;
        _accountInfo = accountInfo;
        _assetDataArray = [NSMutableArray array];
        _showAllAssets = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  是否是自身帐号判断
    _isSelfAccount = [[WalletManager sharedWalletManager] isMyselfAccount:[[_accountInfo objectForKey:@"account"] objectForKey:@"name"]];
    
    //  合并资产信息并排序
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    NSMutableDictionary* call_orders_hash = nil;    //  key:debt_asset_id value:call_orders
    id limit_orders_values = [_userAssetDetailInfos objectForKey:@"onorderValuesHash"];
    id call_orders_values = [_userAssetDetailInfos objectForKey:@"callValuesHash"];
    id debt_values = [_userAssetDetailInfos objectForKey:@"debtValuesHash"];
    for (id asset in [[_userAssetDetailInfos objectForKey:@"validBalancesHash"] allValues]) {
        id asset_type = [asset objectForKey:@"asset_type"];
        id balance = [asset objectForKey:@"balance"];
        
        id asset_detail = [_assethash objectForKey:asset_type];
        NSAssert(asset_detail, @"data missing...");
        
        //  智能资产信息
        NSDictionary* bitasset_data = nil;
        NSString* bitasset_data_id = [asset_detail objectForKey:@"bitasset_data_id"];
        if (bitasset_data_id && ![bitasset_data_id isEqualToString:@""]) {
            bitasset_data = [chainMgr getChainObjectByID:bitasset_data_id];
        }
        
        id name = [asset_detail objectForKey:@"symbol"];
        id precision = [asset_detail objectForKey:@"precision"];
        
        id asset_final = [NSMutableDictionary dictionaryWithObjectsAndKeys:asset_type, @"id",
                          balance, @"balance",
                          name, @"name",
                          precision, @"precision", nil];
        
        //  资产类型（核心、智能、普通、预测市场）
        if ([asset_type isEqualToString:chainMgr.grapheneCoreAssetID]){
            [asset_final setObject:@"1" forKey:@"is_core"];
        }else{
            if (bitasset_data){
                if ([[bitasset_data objectForKey:@"is_prediction_market"] boolValue]) {
                    [asset_final setObject:@"1" forKey:@"is_prediction_market"];
                } else {
                    [asset_final setObject:@"1" forKey:@"is_smart"];
                }
            }else{
                [asset_final setObject:@"1" forKey:@"is_simple"];
            }
        }
        
        //  总挂单(0显示)
        unsigned long long limit_order_value = [[limit_orders_values objectForKey:asset_type] unsignedLongLongValue];
        [asset_final setObject:@(limit_order_value) forKey:@"limit_order_value"];
        
        //  总抵押(0不显示)
        NSInteger optional_number = 0;
        unsigned long long call_order_value = [[call_orders_values objectForKey:asset_type] unsignedLongLongValue];
        if (call_order_value > 0){
            optional_number++;
            [asset_final setObject:@(call_order_value) forKey:@"call_order_value"];
        }
        
        //  总债务(0不显示)
        unsigned long long debt_value = [[debt_values objectForKey:asset_type] unsignedLongLongValue];
        if (debt_value > 0){
            optional_number++;
            [asset_final setObject:@(debt_value) forKey:@"debt_value"];
            //  有债务则计算强平触发价
            if (!call_orders_hash){
                call_orders_hash = [NSMutableDictionary dictionary];
                for (id call_order in [_accountInfo objectForKey:@"call_orders"]) {
                    id debt_asset_id = [[[call_order objectForKey:@"call_price"] objectForKey:@"quote"] objectForKey:@"asset_id"];
                    [call_orders_hash setObject:call_order forKey:debt_asset_id];
                }
            }
            id asset_call_order = [call_orders_hash objectForKey:asset_type];
            assert(asset_call_order);
            id asset_call_price = [asset_call_order objectForKey:@"call_price"];
            id collateral_asset_id = [[asset_call_price objectForKey:@"base"] objectForKey:@"asset_id"];
            id collateral_asset = [_assethash objectForKey:collateral_asset_id];
            assert(collateral_asset);
            //  REMARK：collateral_asset_id 是 debt 的背书资产，那么用户的资产余额里肯定有 抵押中 的背书资产。
            NSInteger debt_precision = [[asset_detail objectForKey:@"precision"] integerValue];
            NSInteger collateral_precision = [[collateral_asset objectForKey:@"precision"] integerValue];
            assert(bitasset_data);
            id mcr = [[bitasset_data objectForKey:@"current_feed"] objectForKey:@"maintenance_collateral_ratio"];
            id trigger_price = [OrgUtils calcSettlementTriggerPrice:asset_call_order[@"debt"]
                                                         collateral:asset_call_order[@"collateral"]
                                                     debt_precision:debt_precision
                                               collateral_precision:collateral_precision
                                                              n_mcr:[NSDecimalNumber decimalNumberWithMantissa:[mcr unsignedLongLongValue]
                                                                                                      exponent:-3 isNegative:NO]
                                                            reverse:NO
                                                       ceil_handler:nil
                                               set_divide_precision:YES];
            optional_number++;
            [asset_final setObject:[OrgUtils formatFloatValue:trigger_price] forKey:@"trigger_price"];
        }
        
        //  设置优先级   1-BTS   2-智能货币（CNY等）    3-有抵押等（其实目前只有BTS可抵押，不排除以后有其他可抵押货币。） 4-其他资产
        int priority = 0;
        if ([asset_type isEqualToString:chainMgr.grapheneCoreAssetID]){
            priority = 1000;
        }else if ([[asset_detail objectForKey:@"issuer"] isEqualToString:@"1.2.0"]){
            priority = 100; //  REMARK：目前智能资产都是由 committee-account#1.2.0 帐号发行。
        }else if (call_order_value > 0){
            priority = 10;
        }
        [asset_final setObject:@(priority) forKey:@"kPriority"];
        [asset_final setObject:@(optional_number) forKey:@"optional_number"];
        
        [_assetDataArray addObject:asset_final];
    }
    //  按照优先级降序排列
    [_assetDataArray sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [[obj2 objectForKey:@"kPriority"] intValue] > [[obj1 objectForKey:@"kPriority"] intValue];
    }];
    
    //  总资产字符串
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    _totalAssetsTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, screenRect.size.width, 32)];
    _totalAssetsTitle.lineBreakMode = NSLineBreakByWordWrapping;
    _totalAssetsTitle.numberOfLines = 1;
    _totalAssetsTitle.contentMode = UIViewContentModeCenter;
    _totalAssetsTitle.backgroundColor = [UIColor clearColor];
    _totalAssetsTitle.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _totalAssetsTitle.textAlignment = NSTextAlignmentCenter;
    _totalAssetsTitle.font = [UIFont boldSystemFontOfSize:18];
    _totalAssetsTitle.text = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetTotalValue", @"总资产折合(%@)"), [[SettingManager sharedSettingManager] getEstimateAssetSymbol]];
    [self.view addSubview:_totalAssetsTitle];
    
    //  总资产值
    _totalAssetsValues = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, screenRect.size.width, 66)];
    _totalAssetsValues.lineBreakMode = NSLineBreakByWordWrapping;
    _totalAssetsValues.numberOfLines = 1;
    _totalAssetsValues.contentMode = UIViewContentModeCenter;
    _totalAssetsValues.backgroundColor = [UIColor clearColor];
    _totalAssetsValues.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _totalAssetsValues.textAlignment = NSTextAlignmentCenter;
    _totalAssetsValues.font = [UIFont boldSystemFontOfSize:20];
    _totalAssetsValues.text = NSLocalizedString(@"kVcAssetTipsEstimating", @"估算中...");
    [self.view addSubview:_totalAssetsValues];
    
    CGFloat offset = 32 + 56;
    
    //  UI-分隔线
    CGFloat fSepLineHeight = 0.5f;
    UIView* tmpSepLine = [[UIView alloc] initWithFrame:CGRectMake(0, offset-fSepLineHeight, screenRect.size.width, fSepLineHeight)];
    tmpSepLine.backgroundColor = [ThemeManager sharedThemeManager].textColorGray;
    [self.view addSubview:tmpSepLine];
    
    //  是否显示所有资产标记
    if ([_assetDataArray count] <= kAppUserAssetDefaultShowNum){
        _showAllAssets = YES;
    }else{
        //  REMARK：不全部显示，仅显示 kAppUserAssetDefaultShowNum - 1 条。
        _showAllAssets = NO;
    }
    
    //  各种资产
    CGRect rectTableView = CGRectMake(0, offset, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - 32 - offset - [self heightForBottomSafeArea]);
    _mainTableView = [[UITableView alloc] initWithFrame:rectTableView style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    [self.view addSubview:_mainTableView];
    
    //  请求（最新价格、执行估算）
    
    //  默认记账单位
    NSString* defaultEstimateAsset = [chainMgr getDefaultEstimateUnitSymbol];
    
    //  这个是显示计价单位
    _displayEstimateAsset = [[SettingManager sharedSettingManager] getEstimateAssetSymbol];
    _needSecondExchange = ![_displayEstimateAsset isEqualToString:defaultEstimateAsset];
    
    //  REMARK：
    //  1、所有资产对CNY进行估价，因为如果其他资产直接对USD等计价可能导致没有匹配的交易对，估值误差较大。比如 SEED/CNY 有估值，SEED/JPY 等直接计较则没估值。
    //  2、如果记账单位为USD等、则把CNY计价再转换为USD计价。
    NSMutableArray* pairs_list = [NSMutableArray array];
    for (id asset in _assetDataArray) {
        id quote = [asset objectForKey:@"name"];
        //  记账单位资产，本身不查询。即：CNY/CNY 不查询。
        if ([quote isEqualToString:defaultEstimateAsset]){
            continue;
        }
        [pairs_list addObject:@{@"base":defaultEstimateAsset, @"quote":quote}];
    }
    //  添加 二次兑换系数 查询 CNY到USD 的兑换系数 注意：这里以 _displayEstimateAsset 为 base 获取 ticker 数据。
    if (_needSecondExchange){
        [pairs_list addObject:@{@"base":_displayEstimateAsset, @"quote":defaultEstimateAsset}];
    }
    
    //  这里面引用的变量必须是 weak 的，不然该 vc 没法释放。
    __weak id this = self;
    [[[[ChainObjectManager sharedChainObjectManager] queryTickerDataByBaseQuoteSymbolArray:pairs_list] then:(^id(id success) {
        if (this){
            [this onEstimateDataReached];
        }else{
            NSLog(@"get_ticker all finish & vc have released...");
        }
        return nil;
    })] catch:(^id(id error) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetTipErrorEstimating", @"网络请求异常，估算失败，请稍后再试。")];
        return nil;
    })];
}

- (void)onEstimateDataReached
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    double total_estimate_value = 0;
    
    //  默认记账单位
    NSString* defaultEstimateAsset = [chainMgr getDefaultEstimateUnitSymbol];
    
    //  显示精度（以记账单位的精度为准）
    NSInteger display_precision = [[[chainMgr getAssetBySymbol:_displayEstimateAsset] objectForKey:@"precision"] integerValue];
    
    //  计算2次兑换比例，如果核心兑换和显示兑换资产不同，则需要2次兑换。
    double fSecondExchangeRate = 1.0f;
    if (_needSecondExchange){
        id ticker = [chainMgr getTickerData:_displayEstimateAsset quote:defaultEstimateAsset];
        assert(ticker);
        fSecondExchangeRate = [[ticker objectForKey:@"latest"] doubleValue];
    }
    
    //  1、估算所有资产
    for (id asset in _assetDataArray) {
        id quote = [asset objectForKey:@"name"];
        //  如果当前资产为基准资产则特殊计算
        if ([quote isEqualToString:defaultEstimateAsset]){
            //  基准资产的估算就是资产自身
            //  REMARK：评估资产总和 = 可用 + 抵押 + 冻结 - 负债。
            long long sum_balance = [[asset objectForKey:@"balance"] longLongValue] + [[asset objectForKey:@"call_order_value"] longLongValue] + [[asset objectForKey:@"limit_order_value"] longLongValue] - [[asset objectForKey:@"debt_value"] longLongValue];
            double fPrecision = pow(10, [[asset objectForKey:@"precision"] integerValue]);
            double estimate_value = sum_balance / fPrecision;
            //  二次兑换：CNY -> USD
            if (_needSecondExchange){
                estimate_value *= fSecondExchangeRate;
            }
            [asset setObject:@(estimate_value) forKey:@"estimate_value_real"];
            [asset setObject:[OrgUtils formatFloatValue:estimate_value precision:display_precision] forKey:@"estimate_value"];
            total_estimate_value += estimate_value;
        }else{
            //  计算资产相对于基准资产（CNY）的价值
            //{
            //  balance = 1075528;
            //  "call_order_value" = 3425318616854;
            //  id = "1.3.0";
            //  kPriority = 1000;
            //  "limit_order_value" = 0;
            //  name = BTS;
            //  precision = 5;
            //}
            //  REMARK：评估资产总和 = 可用 + 抵押 + 冻结 - 负债。
            id ticker = [chainMgr getTickerData:defaultEstimateAsset quote:quote];
            assert(ticker);
            long long sum_balance = [[asset objectForKey:@"balance"] longLongValue] + [[asset objectForKey:@"call_order_value"] longLongValue] + [[asset objectForKey:@"limit_order_value"] longLongValue] - [[asset objectForKey:@"debt_value"] longLongValue];
            double fPrecision = pow(10, [[asset objectForKey:@"precision"] integerValue]);
            //  当前 quote 为显示记账资产（USD），但可能不为核心兑换资产（CNY）
            double estimate_value;
            if (_needSecondExchange && [quote isEqualToString:_displayEstimateAsset]){
                estimate_value = sum_balance / fPrecision;
            }else{
                estimate_value = sum_balance / fPrecision * [[ticker objectForKey:@"latest"] doubleValue] * fSecondExchangeRate;
            }
            [asset setObject:@(estimate_value) forKey:@"estimate_value_real"];
            [asset setObject:[OrgUtils formatFloatValue:estimate_value precision:display_precision] forKey:@"estimate_value"];
            total_estimate_value += estimate_value;
        }
    }
    
    //  2、考虑排序（按照优先级降序排列、优先级相同则按照估值降序排列）
    [_assetDataArray sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        int p1 = [[obj1 objectForKey:@"kPriority"] intValue];
        int p2 = [[obj2 objectForKey:@"kPriority"] intValue];
        if (p1 > p2){
            return NSOrderedAscending;
        }else if (p1 < p2){
            return NSOrderedDescending;
        }else{
            id e1 = [obj1 objectForKey:@"estimate_value_real"];
            id e2 = [obj2 objectForKey:@"estimate_value_real"];
            return [e2 compare:e1];
        }
    }];
    
    //  3、重新刷新
    [_mainTableView reloadData];
    
    //  4、更新总资产折合
    _totalAssetsValues.text = [OrgUtils formatFloatValue:total_estimate_value precision:display_precision];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_showAllAssets){
        return [_assetDataArray count];
    }else{
        //  kAppUserAssetDefaultShowNum - 1条资产 + 1条按钮
        return kAppUserAssetDefaultShowNum;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //  显示全部资产 - 按钮
    if (!_showAllAssets && indexPath.row == kAppUserAssetDefaultShowNum - 1)
    {
        return tableView.rowHeight;
    }
    
    //  资产名   ~ 估算值
    //  可用资产 冻结资产
    //  [抵押资产 负债资产]
    //  [操作action按钮]
    
    //  基本高度
    CGFloat baseHeight = 8.0 + 28.0f * 2;
    
    //  动态高度(抵押、负债、强平)
    id asset = [_assetDataArray objectAtIndex:indexPath.row];
    NSInteger optional_rows = ([[asset objectForKey:@"optional_number"] integerValue] + 1) / 2;
    baseHeight += 28.0f * optional_rows;
    
    //  动态高度(操作按钮)
    if (_isSelfAccount){
        baseHeight += 28.0f;
    }
    
    return baseHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 16.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return [[UIView alloc] init];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!_showAllAssets && indexPath.row == kAppUserAssetDefaultShowNum - 1)
    {
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = NSLocalizedString(@"kVcAssetViewAllAssets", @"查看全部资产信息");
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        return cell;
    }
    else
    {
        static NSString* identify = @"id_userassets";
        
        ViewAssetInfoCell* cell = (ViewAssetInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
        if (!cell)
        {
            cell = [[ViewAssetInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:_isSelfAccount ? self : nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.showCustomBottomLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        cell.row = indexPath.row;
        [cell setItem:[_assetDataArray objectAtIndex:indexPath.row]];
        return cell;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //  显示全部资产 - 按钮
    if (!_showAllAssets && indexPath.row == kAppUserAssetDefaultShowNum - 1)
    {
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            _showAllAssets = YES;
            [_mainTableView reloadData];
        }];
    }
}

#pragma mark- for actions

- (void)onActionButtonClicked:(UIButton*)button row:(id)row
{
    switch (button.tag) {
        case ebaok_transfer:
            [self onButtonClicked_Transfer:button row:[row integerValue]];
            break;
        case ebaok_trade:
            [self onButtonClicked_Trade:button row:[row integerValue]];
            break;
        case ebaok_settle:
            [self onButtonClicked_AssetSettle:button row:[row integerValue]];
            break;
        case ebaok_reserve:
        {
            id value = NSLocalizedString(@"kVcAssetOpReserveEntrySafeTips", @"销毁操作会减少您对应的资产和资产当前流通量，该操作不可逆，请谨慎操作。是否继续？");
            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                                   withTitle:NSLocalizedString(@"kVcHtlcMessageTipsTitle", @"风险提示")
                                                                  completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self onButtonClicked_AssetReserve:button row:[row integerValue]];
                }
            }];
        }
            break;
        case ebaok_stake_vote:
        {
            [self onButtonClicked_AssetStakeVote:button row:[row integerValue]];
        }
            break;
        default:
            assert(false);
            break;
    }
}

/*
 *  操作 - 资产清算
 */
- (void)onButtonClicked_AssetSettle:(UIButton*)button row:(NSInteger)row
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    id clicked_asset = [_assetDataArray objectAtIndex:row];
    assert(clicked_asset);
    id oid = clicked_asset[@"id"];
    id curAsset = [chainMgr getChainObjectByID:oid];
    id bitasset_data_id = [curAsset objectForKey:@"bitasset_data_id"];
    
    id p1 = [chainMgr queryFullAccountInfo:[[_accountInfo objectForKey:@"account"] objectForKey:@"id"]];
    id p2 = [chainMgr queryAllGrapheneObjectsSkipCache:@[oid]];
    id p3 = [chainMgr queryBackingAsset:curAsset];
    
    [VcUtils simpleRequest:_owner
                   request:[WsPromise all:@[p1, p2, p3]]
                  callback:^(id data_array) {
        id full_account = [data_array objectAtIndex:0];
        id result_hash = [data_array objectAtIndex:1];
        id backing_asset = [data_array objectAtIndex:2];
        assert(backing_asset);
        id newAsset = [result_hash objectForKey:oid];
        assert(newAsset);
        id newBitassetData = [chainMgr getChainObjectByID:bitasset_data_id];
        assert(newBitassetData);
        
        //  资产未禁止强清操作 或 全局清算了 才可进行清算操作。
        BOOL hasAlreadyGlobalSettled = [ModelUtils assetHasGlobalSettle:newBitassetData];
        if (![ModelUtils assetCanForceSettle:newAsset] && !hasAlreadyGlobalSettled) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpSettleTipsDisableSettle", @"该资产禁止清算。")];
            return;
        }
        
        if ([[newBitassetData objectForKey:@"is_prediction_market"] boolValue]) {
            //  预测市场：必须全局清算之后才可以进行清算操作。
            if (!hasAlreadyGlobalSettled) {
                [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpSettleTipsMustGlobalSettleFirst", @"预测市场全局清算完成之后才可以进行清算操作。")];
                return;
            }
        } else {
            //  普通智能币
            //  1、需要有喂价数据才可以进行清算操作。
            //  2、如果已经黑天鹅了也可以进行清算操作。
            if ([ModelUtils isNullPrice:[[newBitassetData objectForKey:@"current_feed"] objectForKey:@"settlement_price"]] &&
                !hasAlreadyGlobalSettled) {
                [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpSettleTipsNoFeedData", @"该资产没有有效的喂价，不可清算。")];
                return;
            }
        }
        
        NSString* settleMsgTips;
        if (hasAlreadyGlobalSettled) {
            id n_price = [OrgUtils calcPriceFromPriceObject:[newBitassetData objectForKey:@"settlement_price"]
                                                    base_id:[newAsset objectForKey:@"id"]
                                             base_precision:[[newAsset objectForKey:@"precision"] integerValue]
                                            quote_precision:[[backing_asset objectForKey:@"precision"] integerValue]
                                                     invert:NO
                                               roundingMode:NSRoundDown
                                       set_divide_precision:YES];
            NSString* global_settle_price = [NSString stringWithFormat:@"%@ %@/%@",
                                             [OrgUtils formatFloatValue:n_price usesGroupingSeparator:NO],
                                             backing_asset[@"symbol"], newAsset[@"symbol"]];
            settleMsgTips = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpSettleUiTipsAlreadyGs", @"【温馨提示】\n1、清算操作强制把清算资产换回背书资产。此操作不可撤销，请谨慎操作。\n2、该资产已经触发全局清算，清算操作将立即执行。\n3、清算价 = %@"), global_settle_price];
        } else {
            id options = [newBitassetData objectForKey:@"options"];
            
            NSInteger force_settlement_delay_sec = [[options objectForKey:@"force_settlement_delay_sec"] integerValue];
            id s_delay_hour = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpSettleDelayHoursN", @"%@小时"),
                               @((int)(force_settlement_delay_sec / 3600))];
            
            NSInteger force_settlement_offset_percent = [[options objectForKey:@"force_settlement_offset_percent"] integerValue];
            id n_force_settlement_offset_percent = [NSDecimalNumber decimalNumberWithMantissa:force_settlement_offset_percent
                                                                                     exponent:-4
                                                                                   isNegative:NO];
            id n_final = [n_force_settlement_offset_percent decimalNumberByAdding:[NSDecimalNumber one]];
            
            settleMsgTips = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpSettleUiTips", @"【温馨提示】\n1、清算操作强制把清算资产换回背书资产。此操作不可撤销，请谨慎操作。\n2、发起清算后将在%@后排队执行，并以当时的清算价格成交。\n3、清算价 = 成交时的喂价 × %@"),
                             s_delay_hour,
                             n_final];
        }
        id opArgs = @{
            @"kOpType":@(button.tag),
            @"kMsgTips":settleMsgTips,
            @"kMsgAmountPlaceholder":NSLocalizedString(@"kVcAssetOpSettleCellPlaceholderAmount", @"请输入清算数量"),
            @"kMsgBtnName":NSLocalizedString(@"kVcAssetOpSettleBtnName", @"发起清算"),
            @"kMsgSubmitInputValidAmount":NSLocalizedString(@"kVcAssetOpSettleSubmitTipsPleaseInputAmount", @"请输入要清算的资产数量。"),
            @"kMsgSubmitOK":NSLocalizedString(@"kVcAssetOpSettleSubmitTipSettleOK", @"发起清算成功。")
        };
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCAssetOpCommon* vc = [[VCAssetOpCommon alloc] initWithCurrAsset:[[ChainObjectManager sharedChainObjectManager] getChainObjectByID:clicked_asset[@"id"]]
                                                       full_account_data:full_account
                                                           op_extra_args:opArgs
                                                          result_promise:result_promise];
        [_owner pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleAssetOpSettle", @"发起清算") backtitle:kVcDefaultBackTitleName];
        [result_promise then:^id(id dirty) {
            //  刷新UI
            if (dirty && [dirty boolValue]) {
                //  TODO:5.0 考虑刷新界面
            }
            return nil;
        }];
    }];
}

/*
 *  操作 - 资产销毁
 */
- (void)onButtonClicked_AssetReserve:(UIButton*)button row:(NSInteger)row
{
    id clicked_asset = [_assetDataArray objectAtIndex:row];
    assert(clicked_asset);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    [VcUtils simpleRequest:_owner
                   request:[chainMgr queryFullAccountInfo:[[_accountInfo objectForKey:@"account"] objectForKey:@"id"]]
                  callback:^(id full_account) {
        
        id opArgs = @{
            @"kOpType":@(button.tag),
            @"kMsgTips":NSLocalizedString(@"kVcAssetOpReserveUiTips", @"【温馨提示】\n销毁会减少当前流通量。此操作不可逆，请谨慎操作。"),
            @"kMsgAmountPlaceholder":NSLocalizedString(@"kVcAssetOpReserveCellPlaceholderAmount", @"请输入销毁数量"),
            @"kMsgBtnName":NSLocalizedString(@"kVcAssetOpReserveBtnName", @"立即销毁"),
            @"kMsgSubmitInputValidAmount":NSLocalizedString(@"kVcAssetOpReserveSubmitTipsPleaseInputAmount", @"请输入要销毁的资产数量。"),
            @"kMsgSubmitOK":NSLocalizedString(@"kVcAssetOpReserveSubmitTipOK", @"销毁成功。")
        };
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCAssetOpCommon* vc = [[VCAssetOpCommon alloc] initWithCurrAsset:[chainMgr getChainObjectByID:clicked_asset[@"id"]]
                                                       full_account_data:full_account
                                                           op_extra_args:opArgs
                                                          result_promise:result_promise];
        [_owner pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleAssetOpReserve", @"销毁资产") backtitle:kVcDefaultBackTitleName];
        [result_promise then:^id(id dirty) {
            //  刷新UI
            if (dirty && [dirty boolValue]) {
                //  TODO:5.0 考虑刷新界面
            }
            return nil;
        }];
    }];
}

/*
 *  操作 - 资产锁仓投票
 */
- (void)onButtonClicked_AssetStakeVote:(UIButton*)button row:(NSInteger)row
{
    id clicked_asset = [_assetDataArray objectAtIndex:row];
    assert(clicked_asset);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    [VcUtils simpleRequest:_owner
                   request:[chainMgr queryFullAccountInfo:[[_accountInfo objectForKey:@"account"] objectForKey:@"id"]]
                  callback:^(id full_account) {
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCAssetOpStakeVote* vc = [[VCAssetOpStakeVote alloc] initWithCurrAsset:[chainMgr getChainObjectByID:clicked_asset[@"id"]]
                                                             full_account_data:full_account
                                                                result_promise:result_promise];
        
        [_owner pushViewController:vc
                           vctitle:NSLocalizedString(@"kVcTitleAssetOpStakeVoteCreateTicket", @"创建锁仓")
                         backtitle:kVcDefaultBackTitleName];
        [result_promise then:^id(id dirty) {
            //  刷新UI
            if (dirty && [dirty boolValue]) {
                //  TODO:5.0 考虑刷新界面
            }
            return nil;
        }];
    }];
}

/*
 *  操作 - 转账
 */
- (void)onButtonClicked_Transfer:(UIButton*)button row:(NSInteger)row
{
    //  获取资产
    id clicked_asset = [_assetDataArray objectAtIndex:row];
    assert(clicked_asset);
    id default_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[clicked_asset objectForKey:@"id"]];
    
    //  转到转账界面
    
    //  TODO:fowallet id p2 = [[ChainObjectManager sharedChainObjectManager] queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
    
    VCTransfer* vc = [[VCTransfer alloc] initWithUserFullInfo:_accountInfo defaultAsset:default_asset];
    vc.title = NSLocalizedString(@"kVcTitleTransfer", @"转账");
    assert(_owner);
    [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

/*
 *  操作 - 交易
 */
- (void)onButtonClicked_Trade:(UIButton*)button row:(NSInteger)row
{
    //  获取设置界面的计价货币资产。
    NSString* estimateAssetSymbol = [[SettingManager sharedSettingManager] getEstimateAssetSymbol];
    assert(estimateAssetSymbol);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    //  优先获取计价资产对应的 base 市场信息。
    NSDictionary* baseMarket = nil;
    id defaultMarketInfoList = [chainMgr getDefaultMarketInfos];
    for (id market in defaultMarketInfoList) {
        id symbol = [[market objectForKey:@"base"] objectForKey:@"symbol"];
        if ([estimateAssetSymbol isEqualToString:symbol]){
            baseMarket = market;
            break;
        }
    }
    
    //  如果计价资产没对应的 base 市场，则获取第一个默认的 CNY 基本市场。（因为：计价资产有许多个，包括欧元等，但 base 市场只有 CNY、USD、BTS 三个而已。）
    if (!baseMarket){
        baseMarket = [defaultMarketInfoList firstObject];
    }
    
    //  转到交易界面
    id base = [chainMgr getAssetBySymbol:[[baseMarket objectForKey:@"base"] objectForKey:@"symbol"]];
    id clicked_asset = [_assetDataArray objectAtIndex:row];
    assert(clicked_asset);
    id quote = [chainMgr getChainObjectByID:[clicked_asset objectForKey:@"id"]];
    
    //  REMARK：如果 base 和 quote 相同则特殊处理。CNY/CNY USD/USD BTS/BTS
    id base_symbol = [base objectForKey:@"symbol"];
    id quote_symbol = [quote objectForKey:@"symbol"];
    if ([base_symbol isEqualToString:quote_symbol]){
        //  特殊处理
        if ([quote_symbol isEqualToString:chainMgr.grapheneCoreAssetSymbol]){
            //  修改 base
            base_symbol = [[chainMgr getDefaultParameters] objectForKey:@"core_default_exchange_asset"];
            assert(base_symbol);
            base = [chainMgr getAssetBySymbol:base_symbol];
        }else{
            //  修改 quote
            quote_symbol = chainMgr.grapheneCoreAssetSymbol;
            quote = [chainMgr getAssetBySymbol:quote_symbol];
        }
    }
    
    TradingPair* tradingPair = [[TradingPair alloc] initWithBaseAsset:base quoteAsset:quote];
    
    [VcUtils simpleRequest:_owner request:[tradingPair queryBitassetMarketInfo] callback:^(id data) {
        VCBase* vc;
        if ([[SettingManager sharedSettingManager] isEnableHorTradeUI]) {
            vc = [[VCTradeHor alloc] initWithTradingPair:tradingPair selectBuy:YES];
        } else {
            vc = [[VCTradeVertical alloc] initWithTradingPair:tradingPair selectBuy:YES];
        }
        vc.title = [NSString stringWithFormat:@"%@/%@", quote_symbol, base_symbol];
        assert(_owner);
        [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
    }];
}

@end
