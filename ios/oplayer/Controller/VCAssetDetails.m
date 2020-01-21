//
//  VCAssetDetails.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetDetails.h"

enum
{
    kVcSecBasicInfo = 0,    //  基本信息
    kVcSecPermissions,      //  权限信息
    kVcSecSettlement,       //  清算信息
    kVcSecSmartCoin         //  智能币信息
};

enum
{
    kVcSubAssetName = 0,    //  资产名字
    kVcSubIssuer,           //  发行人
    kVcSubPrecision,        //  资产精度
    kVcSubCurSupply,        //  当前供应量
    kVcSubMaxSupply,        //  最大供应量
    kVcSubConSupply,        //  隐私供应量
    kVcSubFee,              //  市场手续费
    kVcSubFeeReferrerRatio, //  引荐人分成比例
    kVcSubMaxFee,           //  手续费上限
    kVcSubFeePool,          //  手续费资金池余额
    kVcSubAccumulatedFees,  //  发行人未申领收入
    
    //  TODO:4.0 todo
};

@interface VCAssetDetails ()
{
    NSString*               _asset_id;
    NSDictionary*           _asset;
    NSDictionary*           _bitasset_data;
    NSDictionary*           _dynamic_asset_data;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
}

@end

@implementation VCAssetDetails

-(void)dealloc
{
    _asset_id = nil;
    _asset = nil;
    _bitasset_data = nil;
    _dynamic_asset_data = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _dataArray = nil;
}

- (id)initWithAssetID:(NSString*)asset_id asset:(id)asset bitasset_data:(id)bitasset_data dynamic_asset_data:(id)dynamic_asset_data
{
    self = [super init];
    if (self) {
        assert(asset_id);
        _asset_id = asset_id;
        _asset = asset;
        _bitasset_data = bitasset_data;
        _dynamic_asset_data = dynamic_asset_data;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onQueryAssetInfosResponsed:(id)asset dynamic_asset_data:(id)dynamic_asset_data bitasset_data:(id)bitasset_data
{
    assert(asset);
    _asset = asset;
    _dynamic_asset_data = dynamic_asset_data;
    _bitasset_data = bitasset_data;
    //  刷新
    [self _auxGenSectionArray];
    [_mainTableView reloadData];
}

- (void)queryAssetInfos
{
    if ([_dataArray count] > 0) {
        return;
    }
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    [[[chainMgr queryAllGrapheneObjects:@[_asset_id]] then:^id(id data) {
        id asset = [chainMgr getChainObjectByID:_asset_id];
        assert(asset);
        NSMutableArray* list = [NSMutableArray array];
        NSString* issuer = [asset objectForKey:@"issuer"];
        NSString* bitasset_data_id = [asset objectForKey:@"bitasset_data_id"];
        NSString* dynamic_asset_data_id = [asset objectForKey:@"dynamic_asset_data_id"];
        [list addObject:issuer];
        [list addObject:dynamic_asset_data_id];
        if (bitasset_data_id && ![bitasset_data_id isEqualToString:@""]) {
            [list addObject:bitasset_data_id];
        }
        //  查询依赖
        return [[chainMgr queryAllGrapheneObjectsSkipCache:list] then:^id(id data) {
            [self hideBlockView];
            id dynamic_asset_data = [chainMgr getChainObjectByID:dynamic_asset_data_id];
            id bitasset_data = nil;
            if (bitasset_data_id && ![bitasset_data_id isEqualToString:@""]) {
                bitasset_data = [chainMgr getChainObjectByID:bitasset_data_id];
            }
            [self onQueryAssetInfosResponsed:asset dynamic_asset_data:dynamic_asset_data bitasset_data:bitasset_data];
            return nil;
        }];
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

- (void)_auxGenSectionArray
{
    if (!_asset) {
        return;
    }
    [_dataArray removeAllObjects];
    [_dataArray addObject:@[
        @(kVcSubAssetName),
        @(kVcSubIssuer),
        @(kVcSubPrecision),
        @(kVcSubCurSupply),
        @(kVcSubMaxSupply),
        @(kVcSubConSupply),
        @(kVcSubFee),
        @(kVcSubFeeReferrerRatio),
        @(kVcSubMaxFee),
        @(kVcSubFeePool),
        @(kVcSubAccumulatedFees)
    ]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化字段数组
    [self _auxGenSectionArray];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  查询
    [self queryAssetInfos];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_dataArray objectAtIndex:section] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
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
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.showCustomBottomLine = YES;
    cell.textLabel.textColor = theme.textColorMain;
    cell.textLabel.font = [UIFont systemFontOfSize:14.0f];
    cell.detailTextLabel.textColor = theme.textColorNormal;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0f];
    
    NSInteger precision = [[_asset objectForKey:@"precision"] integerValue];
    NSInteger rowType = [[[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] integerValue];
    switch (rowType) {
        case kVcSubAssetName:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleAssetName", @"资产名称");
            cell.detailTextLabel.text = [_asset objectForKey:@"symbol"];
        }
            break;
        case kVcSubIssuer:
        {
            cell.textLabel.text = @"发行人";
            cell.detailTextLabel.text = [[chainMgr getChainObjectByID:[_asset objectForKey:@"issuer"]] objectForKey:@"name"];
        }
            break;
        case kVcSubPrecision:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleAssetPrecision", @"资产精度");
            cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetMgrCellValueAssetPrecision", @"%@ 位小数"), @(precision)];
        }
            break;
        case kVcSubCurSupply:
        {
            assert(_dynamic_asset_data);
            id n_current_supply = [NSDecimalNumber decimalNumberWithMantissa:[[_dynamic_asset_data objectForKey:@"current_supply"] unsignedLongLongValue]
                                                                    exponent:-precision
                                                                  isNegative:NO];
            cell.textLabel.text = @"当前供应量";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_current_supply], _asset[@"symbol"]];
            cell.detailTextLabel.textColor = theme.buyColor;
        }
            break;
        case kVcSubMaxSupply:
        {
            id n_max_supply = [NSDecimalNumber decimalNumberWithMantissa:[[[_asset objectForKey:@"options"] objectForKey:@"max_supply"] unsignedLongLongValue]
                                                                exponent:-precision
                                                              isNegative:NO];
            
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleMaxSupply", @"最大供应量");
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_max_supply], _asset[@"symbol"]];
        }
            break;
        case kVcSubConSupply:
        {
            assert(_dynamic_asset_data);
            id n_confidential_supply = [NSDecimalNumber decimalNumberWithMantissa:[[_dynamic_asset_data objectForKey:@"confidential_supply"] unsignedLongLongValue]
                                                                         exponent:-precision
                                                                       isNegative:NO];
            
            cell.textLabel.text = @"隐私供应量";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_confidential_supply], _asset[@"symbol"]];
        }
            break;
        case kVcSubFee:
        {
            id n_market_fee_percent = [NSDecimalNumber decimalNumberWithMantissa:[[[_asset objectForKey:@"options"] objectForKey:@"market_fee_percent"] unsignedLongLongValue]
                                                                        exponent:-2
                                                                      isNegative:NO];
            cell.textLabel.text = @"市场手续费率";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:n_market_fee_percent
                                                                                 usesGroupingSeparator:NO]];
            
            if ([n_market_fee_percent compare:[NSDecimalNumber zero]] > 0) {
                cell.detailTextLabel.textColor = theme.buyColor;
            } else {
                cell.detailTextLabel.textColor = theme.textColorNormal;
            }
        }
            break;
        case kVcSubFeeReferrerRatio:
        {
            id reward_percent = [[[_asset objectForKey:@"options"] objectForKey:@"extensions"] objectForKey:@"reward_percent"];
            id n_reward_percent = [NSDecimalNumber decimalNumberWithMantissa:[reward_percent unsignedLongLongValue]
                                                                    exponent:-2
                                                                  isNegative:NO];
            cell.textLabel.text = @"市场手续费引荐奖励";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:n_reward_percent
                                                                                 usesGroupingSeparator:NO]];
            if ([n_reward_percent compare:[NSDecimalNumber zero]] > 0) {
                cell.detailTextLabel.textColor = theme.buyColor;
            } else {
                cell.detailTextLabel.textColor = theme.textColorNormal;
            }
        }
            break;
        case kVcSubMaxFee:
        {
            id n_max_market_fee = [NSDecimalNumber decimalNumberWithMantissa:[[[_asset objectForKey:@"options"] objectForKey:@"max_market_fee"] unsignedLongLongValue]
                                                                    exponent:-precision
                                                                  isNegative:NO];
            
            cell.textLabel.text = @"市场手续费上限";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_max_market_fee], _asset[@"symbol"]];
        }
            break;
        case kVcSubFeePool:
        {
            assert(_dynamic_asset_data);
            id core_asset = [chainMgr getChainObjectByID:chainMgr.grapheneCoreAssetID];
            assert(core_asset);
            id n_fee_pool = [NSDecimalNumber decimalNumberWithMantissa:[[_dynamic_asset_data objectForKey:@"fee_pool"] unsignedLongLongValue]
                                                              exponent:-[[core_asset objectForKey:@"precision"] integerValue]
                                                            isNegative:NO];
            cell.textLabel.text = @"手续费资金池余额";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_fee_pool], core_asset[@"symbol"]];
        }
            break;
        case kVcSubAccumulatedFees:
        {
            assert(_dynamic_asset_data);
            id n_accumulated_fees = [NSDecimalNumber decimalNumberWithMantissa:[[_dynamic_asset_data objectForKey:@"accumulated_fees"] unsignedLongLongValue]
                                                                      exponent:-precision
                                                                    isNegative:NO];
            cell.textLabel.text = @"发行人未申领收入";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_accumulated_fees], _asset[@"symbol"]];
        }
            break;
        default:
            break;
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
