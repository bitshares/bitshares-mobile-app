//
//  VCAssetCreateOrEdit.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetCreateOrEdit.h"
#import "ViewTipsInfoCell.h"

#import "VCSearchNetwork.h"

enum
{
    kVcSecBasic = 0,                    //  基本信息
    kVcSecSmartCoin,                    //  智能币
    kVcSecPermission,                   //  权限信息
    kVcSecTips,                         //  提示信息
    kVcSecCommit                        //  创建按钮
};

enum
{
    kPermissionActionDisablePermanently = 0,    //  永久禁用（不可再开启）
    kPermissionActionActivateLater,             //  暂不激活（后续可开启）
    kPermissionActionActivateNow                //  立即激活（创建后开启）
};

enum
{
    //  基本信息
    kVcSubAssetSymbol = 0,                      //  资产名称
    kVcSubAssetMaxSupply,                       //  最大供应量
    kVcSubAssetDesc,                            //  描述信息
    kVcSubAdvSwitch,                            //  高级设置
    kVcSubAssetPrecision,                       //  高级设置 > 精度
    
    //  智能币
    kVcSubSmartBackingAsset,                    //  高级设置 > 抵押资产
    kVcSubSmartFeedLifetime,                    //  高级设置 > 喂价有效期 单位：分钟
    kVcSubSmartMinFeedNumber,                   //  高级设置 > 最小有效喂价人数
    kVcSubSmartDelayForSettle,                  //  高级设置 > 强清延迟执行时间 单位：分钟
    kVcSubSmartPercentOffsetSettle,             //  高级设置 > 强清补偿百分比
    kVcSubSmartMaxSettleVolume,                 //  高级设置 > 每周期最大强清量百分比（每小时总量的百分比）
    
    //  权限
    kVcSubPermissionMarketFee,                  //  高级设置 > 开启手续费
    kVcSubPermissionMarketFeePercent,           //  高级设置 >>> 手续费百分比
    kVcSubPermissionMaxMarketFee,               //  高级设置 >>> 单币最大手续费
    kVcSubPermissionMarketFeeRewardPercent,     //  高级设置 >>> 手续费引荐人分成比例
    kVcSubPermissionMarketFeeSharingWhitelist,  //  高级设置 >>> 手续费引荐人分成白名单（仅白名单中注册的账号才可以享受分成。）
    
    kVcSubPermissionWhiteListed,                //  高级设置 > 白名单
    kVcSubPermissionOverrideTransfer,           //  高级设置 > 资产回收
    kVcSubPermissionNeedIssueApprove,           //  高级设置 > 需要发行人审核
    kVcSubPermissionDisableCondTransfer,        //  高级设置 > 禁止隐私转账
    kVcSubPermissionDisableForceSettle,         //  高级设置 > 禁止清算（仅对Smart币）
    kVcSubPermissionAllowGlobalSettle,          //  高级设置 > 允许发行人全局清算（仅对Smart币）
    kVcSubPermissionAllowWitnessFeed,           //  高级设置 > 允许见证人喂价（仅对Smart币）
    kVcSubPermissionAllowCommitteeFeed,         //  高级设置 > 允许理事会喂价（仅对Smart币）
    
    kVcSubTips,                                 //  提示信息
    kVcSubCommit,                               //  创建按钮
};

@interface VCAssetCreateOrEdit ()
{
    NSDictionary*           _edit_asset_options;        //  编辑基本信息（可为nil）
    NSDictionary*           _edit_bitasset_opts;        //  编辑智能币信息（可为nil）REMARK：如果这2项都为nil，则为创建资产。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    ViewTipsInfoCell*       _cell_tips;
    ViewBlockLabel*         _lbCommit;
    
    NSString*               _symbol;                    //  资产符号
    NSDecimalNumber*        _max_supply;                //  最大供应量
    NSInteger               _market_fee_percent;        //  交易手续费百分比
    NSDecimalNumber*        _max_market_fee;            //  单笔手续费最大值
    NSString*               _description;               //  描述信息
    NSInteger               _precision;                 //  资产精度
    NSDecimalNumber*        _max_supply_editable;       //  可编辑的最大供应量
    BOOL                    _enable_more_args;
    NSMutableDictionary*    _bitasset_options_args;     //  智能币相关参数（默认为空）
    uint32_t                _issuer_permissions;        //  权限
    uint32_t                _flags;                     //  激活标记
}

@end

@implementation VCAssetCreateOrEdit

-(void)dealloc
{
    _cell_tips = nil;
    _lbCommit = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

/*
 *  初始化 智能币默认参数
 */
- (void)genDefaultSmartCoinArgs
{
    if (!_bitasset_options_args) {
        _bitasset_options_args = [NSMutableDictionary dictionary];
        [_bitasset_options_args setObject:@1440 forKey:@"feed_lifetime_sec"];
        [_bitasset_options_args setObject:@1 forKey:@"minimum_feeds"];
        [_bitasset_options_args setObject:@1440 forKey:@"force_settlement_delay_sec"];
        [_bitasset_options_args setObject:@5 forKey:@"force_settlement_offset_percent"];
        [_bitasset_options_args setObject:@5 forKey:@"maximum_force_settlement_volume"];
    }
}

/*
 *  初始化 资产默认参数
 */
- (void)genDefaultAssetArgs
{
    _symbol = @"";
    _max_supply = nil;
    _description = @"";
    [self updatePrecision:5];
    _issuer_permissions = ebat_issuer_permission_mask_uia;
    _flags = 0;
    
    _market_fee_percent = 0;
    _max_market_fee = nil;
}

- (void)updatePrecision:(NSInteger)precision
{
    assert(precision >= 0 && precision <= 12);
    _precision = precision;
    _max_supply_editable = [NSDecimalNumber decimalNumberWithMantissa:(unsigned long long)GRAPHENE_MAX_SHARE_SUPPLY
                                                             exponent:-_precision
                                                           isNegative:NO];
}

- (id)initWithEditAssetOptions:(NSDictionary*)asset_options editBitassetOpts:(NSDictionary*)bitasset_opts
{
    self = [super init];
    if (self) {
        _edit_asset_options = asset_options;
        _edit_bitasset_opts = bitasset_opts;
        
        _dataArray = [NSMutableArray array];
        //  TODO:4.0 各种默认参数
        _enable_more_args = NO;
        _bitasset_options_args = nil;
        [self genDefaultAssetArgs];
    }
    return self;
}


- (void)_buildRowTypeArray
{
    [_dataArray removeAllObjects];
    
    //  基本信息
    NSMutableArray* secBasic = [NSMutableArray array];
    [secBasic addObject:@(kVcSubAssetSymbol)];
    [secBasic addObject:@(kVcSubAssetMaxSupply)];
    [secBasic addObject:@(kVcSubAssetDesc)];
    [secBasic addObject:@(kVcSubAdvSwitch)];
    if (_enable_more_args){
        //  高级设置：资产精度
        [secBasic addObject:@(kVcSubAssetPrecision)];
    }
    [_dataArray addObject:@{@"type":@(kVcSecBasic), @"rows":secBasic}];
    
    if (_enable_more_args) {
        //  高级设置：智能币信息
        BOOL isSmartCorin = _bitasset_options_args != nil;
        NSMutableArray* secSmart = [NSMutableArray array];
        [secSmart addObject:@(kVcSubSmartBackingAsset)];
        if (isSmartCorin) {
            [secSmart addObject:@(kVcSubSmartFeedLifetime)];
            [secSmart addObject:@(kVcSubSmartMinFeedNumber)];
            [secSmart addObject:@(kVcSubSmartDelayForSettle)];
            [secSmart addObject:@(kVcSubSmartPercentOffsetSettle)];
            [secSmart addObject:@(kVcSubSmartMaxSettleVolume)];
        }
        [_dataArray addObject:@{@"type":@(kVcSecSmartCoin), @"rows":secSmart}];
        
        //  高级设置：权限信息
        NSMutableArray* secPermission = [NSMutableArray array];
        [secPermission addObject:@(kVcSubPermissionMarketFee)];
        //  激活手续费标记的情况下，设置手续费比例。
        if (_flags & ebat_charge_market_fee) {
            [secPermission addObject:@(kVcSubPermissionMarketFeePercent)];
            [secPermission addObject:@(kVcSubPermissionMaxMarketFee)];
            //  TODO:4.0 未完成
            //            [secPermission addObject:@(kVcSubPermissionMarketFeeRewardPercent)];
            //            [secPermission addObject:@(kVcSubPermissionMarketFeeSharingWhitelist)];
        }
        [secPermission addObject:@(kVcSubPermissionWhiteListed)];
        [secPermission addObject:@(kVcSubPermissionOverrideTransfer)];
        [secPermission addObject:@(kVcSubPermissionNeedIssueApprove)];
        [secPermission addObject:@(kVcSubPermissionDisableCondTransfer)];
        if (isSmartCorin) {
            [secPermission addObject:@(kVcSubPermissionDisableForceSettle)];
            [secPermission addObject:@(kVcSubPermissionAllowGlobalSettle)];
            [secPermission addObject:@(kVcSubPermissionAllowWitnessFeed)];
            [secPermission addObject:@(kVcSubPermissionAllowCommitteeFeed)];
        }
        [_dataArray addObject:@{@"type":@(kVcSecPermission), @"rows":secPermission}];
    }
    
    //  提示信息
    [_dataArray addObject:@{@"type":@(kVcSecTips), @"rows":@[@(kVcSubTips)]}];
    
    //  提交按钮
    [_dataArray addObject:@{@"type":@(kVcSecCommit), @"rows":@[@(kVcSubCommit)]}];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化数据
    [self _buildRowTypeArray];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 提示信息
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:@"【温馨提示】\n1、资产精度即资产支持的小数位数。\n2、资产精度创建后不可更改。\n3、资产创建手续费由资产名称长度决定。\n4、资产权限一旦永久禁用后则后续不可开启。"];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    //  UI - 提交按钮 TODO:4.0 lang
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcAssetMgrAssetCreateButton", @"创建")];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[_dataArray objectAtIndex:section] objectForKey:@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([[[[_dataArray objectAtIndex:indexPath.section] objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue]) {
        case kVcSubTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    return tableView.rowHeight;
}

#pragma mark- for switch action
-(void)onSwitchAction:(UISwitch*)pSwitch
{
    _enable_more_args = pSwitch.on;
    //  REMARK: 关闭高级参数设置也不恢复默认值，依然使用用户选择的参数。
    [self _buildRowTypeArray];
    [_mainTableView reloadData];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSInteger secType = [[[_dataArray objectAtIndex:section] objectForKey:@"type"] integerValue];
    switch (secType) {
        case kVcSecBasic:
        case kVcSecSmartCoin:
        case kVcSecPermission:
        {
            CGFloat fWidth = self.view.bounds.size.width;
            CGFloat xOffset = tableView.layoutMargins.left;
            
            UIView* myView = [[UIView alloc] init];
            myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 0, fWidth - xOffset * 2, 28)];
            titleLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
            titleLabel.backgroundColor = [UIColor clearColor];
            titleLabel.font = [UIFont boldSystemFontOfSize:16];
            
            switch (secType) {
                case kVcSecBasic:
                    titleLabel.text = NSLocalizedString(@"kVcAssetMgrSegInfoBasicInfo", @"基本信息");
                    break;
                case kVcSecPermission:
                    titleLabel.text = NSLocalizedString(@"kVcAssetMgrSegInfoPermissionInfo", @"权限信息");
                    break;
                case kVcSecSmartCoin:
                    titleLabel.text = NSLocalizedString(@"kVcAssetMgrSegInfoSmartCoinInfo", @"智能币信息");
                    break;
                default:
                    assert(false);
                    break;
            }
            
            [myView addSubview:titleLabel];
            
            return myView;
        }
            break;
        default:
            break;
    }
    return [[UIView alloc] init];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSInteger secType = [[[_dataArray objectAtIndex:section] objectForKey:@"type"] integerValue];
    switch (secType) {
        case kVcSecBasic:
        case kVcSecSmartCoin:
        case kVcSecPermission:
            return 28.0f;
        default:
            break;
    }
    return 10.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView* myView = [[UIView alloc] init];
    myView.backgroundColor = [UIColor clearColor];// [ThemeManager sharedThemeManager].appBackColor;
    return myView;
}

- (EBitsharesAssetFlags)_permissionRowType2Feature:(NSInteger)rowType
{
    switch (rowType) {
        case kVcSubPermissionMarketFee:
            return ebat_charge_market_fee;
        case kVcSubPermissionWhiteListed:
            return ebat_white_list;
        case kVcSubPermissionOverrideTransfer:
            return ebat_override_authority;
        case kVcSubPermissionNeedIssueApprove:
            return ebat_transfer_restricted;
        case kVcSubPermissionDisableCondTransfer:
            return ebat_disable_confidential;
            
        case kVcSubPermissionDisableForceSettle:
            return ebat_disable_force_settle;
        case kVcSubPermissionAllowGlobalSettle:
            return ebat_global_settle;
        case kVcSubPermissionAllowWitnessFeed:
            return ebat_witness_fed_asset;
        case kVcSubPermissionAllowCommitteeFeed:
            return ebat_committee_fed_asset;
        default:
            assert(false);
            break;
    }
    //  not reached...
    return (EBitsharesAssetFlags)0;
}

- (void)_drawUI_onePermission:(UITableViewCellBase*)cell checkFeature:(EBitsharesAssetFlags)checkFeature
{
    //  TODO:4.0 lang
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    if (checkFeature == ebat_global_settle) {
        if (_issuer_permissions & checkFeature) {
            cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrPermissionStatusActivateNow", @"立即激活");
            cell.detailTextLabel.textColor = theme.buyColor;
        } else {
            cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrPermissionStatusDisablePermanently", @"永久禁用");
            cell.detailTextLabel.textColor = theme.textColorGray;
        }
    } else {
        if (_issuer_permissions & checkFeature) {
            if (_flags & checkFeature) {
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrPermissionStatusActivateNow", @"立即激活");
                cell.detailTextLabel.textColor = theme.buyColor;
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrPermissionStatusActivateLater", @"暂不激活");
                cell.detailTextLabel.textColor = theme.textColorMain;
            }
        } else {
            cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrPermissionStatusDisablePermanently", @"永久禁用");
            cell.detailTextLabel.textColor = theme.textColorGray;
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    NSInteger rowType = [[[[_dataArray objectAtIndex:indexPath.section] objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue];
    
    if (rowType == kVcSubTips) {
        return _cell_tips;
    }
    
    if (rowType == kVcSubCommit) {
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
    
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    cell.textLabel.textColor = theme.textColorNormal;
    cell.textLabel.font = [UIFont systemFontOfSize:15.0f];
    cell.detailTextLabel.textColor = theme.textColorMain;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:15.0f];
    cell.showCustomBottomLine = YES;
    
    switch (rowType) {
            //  基本信息
        case kVcSubAssetSymbol:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleAssetName", @"资产名称");
            if (_symbol && ![_symbol isEqualToString:@""]) {
                cell.detailTextLabel.text = _symbol;
                cell.detailTextLabel.textColor = theme.textColorMain;
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellPlaceholderAssetName", @"请输入资产名称");
                cell.detailTextLabel.textColor = theme.textColorGray;
            }
        }
            break;
        case kVcSubAssetMaxSupply:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleMaxSupply", @"最大供应量");
            if (_max_supply && [_max_supply compare:[NSDecimalNumber zero]] > 0) {
                cell.detailTextLabel.text = [OrgUtils formatFloatValue:_max_supply];
                cell.detailTextLabel.textColor = theme.textColorMain;
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellPlaceholderMaxSupply", @"请输入最大供应量");
                cell.detailTextLabel.textColor = theme.textColorGray;
            }
        }
            break;
        case kVcSubAssetDesc:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleAssetDesc", @"资产描述");
            if (_description && ![_description isEqualToString:@""]) {
                cell.detailTextLabel.text = _description;
                cell.detailTextLabel.textColor = theme.textColorMain;
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellPlaceholderAssetDesc", @"请输入描述（可选）");
                cell.detailTextLabel.textColor = theme.textColorGray;
            }
        }
            break;
        case kVcSubAdvSwitch:
        {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            
            UISwitch* pSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
            pSwitch.tintColor = theme.textColorGray;        //  边框颜色
            pSwitch.thumbTintColor = theme.textColorGray;   //  按钮颜色
            pSwitch.onTintColor = theme.textColorHighlight; //  开启时颜色
            
            pSwitch.on = _enable_more_args;
            [pSwitch addTarget:self action:@selector(onSwitchAction:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = pSwitch;
            
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleAdvSwitch", @"高级设置");
            return cell;
        }
            break;
        case kVcSubAssetPrecision:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleAssetPrecision", @"资产精度");
            cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetMgrCellValueAssetPrecision", @"%@ 位小数"), @(_precision)];
        }
            break;
            
            //  智能币选项
        case kVcSubSmartBackingAsset:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleSmartBackingAsset", @"借贷抵押资产");
            if (_bitasset_options_args) {
                cell.detailTextLabel.text = [[_bitasset_options_args objectForKey:@"short_backing_asset"] objectForKey:@"symbol"];
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellValueSmartBackingAssetNone", @"无");
            }
        }
            break;
        case kVcSubSmartFeedLifetime:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleSmartFeedLifeTime", @"喂价有效期");
            id value = [_bitasset_options_args objectForKey:@"feed_lifetime_sec"];
            if (value) {
                cell.detailTextLabel.textColor = theme.textColorMain;
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetMgrCellValueSmartMinN", @"%@ 分钟"), value];
            } else {
                cell.detailTextLabel.textColor = theme.textColorGray;
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellValueNotSet", @"未设置");
            }
        }
            break;
        case kVcSubSmartMinFeedNumber:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleSmartMinFeedNum", @"最少喂价数量");
            id value = [_bitasset_options_args objectForKey:@"minimum_feeds"];
            if (value) {
                cell.detailTextLabel.textColor = theme.textColorMain;
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", value];
            } else {
                cell.detailTextLabel.textColor = theme.textColorGray;
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellValueNotSet", @"未设置");
            }
        }
            break;
        case kVcSubSmartDelayForSettle:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleSmartDelayForSettle", @"强清延迟时间");
            id value = [_bitasset_options_args objectForKey:@"force_settlement_delay_sec"];
            if (value) {
                cell.detailTextLabel.textColor = theme.textColorMain;
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetMgrCellValueSmartMinN", @"%@ 分钟"), value];
            } else {
                cell.detailTextLabel.textColor = theme.textColorGray;
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellValueNotSet", @"未设置");
            }
        }
            break;
        case kVcSubSmartPercentOffsetSettle:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleSmartOffsetSettle", @"强清补偿比例");
            id value = [_bitasset_options_args objectForKey:@"force_settlement_offset_percent"];
            if (value) {
                cell.detailTextLabel.textColor = theme.textColorMain;
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%%", value];
            } else {
                cell.detailTextLabel.textColor = theme.textColorGray;
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellValueNotSet", @"未设置");
            }
        }
            break;
        case kVcSubSmartMaxSettleVolume:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitleSmartMaxSettleValuePerHour", @"每周期最大清算量");
            id value = [_bitasset_options_args objectForKey:@"maximum_force_settlement_volume"];
            if (value) {
                cell.detailTextLabel.textColor = theme.textColorMain;
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%%", value];
            } else {
                cell.detailTextLabel.textColor = theme.textColorGray;
                cell.detailTextLabel.text = NSLocalizedString(@"kVcAssetMgrCellValueNotSet", @"未设置");
            }
        }
            break;
            
            //  权限信息
        case kVcSubPermissionMarketFee:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermMarketFee", @"收取市场手续费");
            [self _drawUI_onePermission:cell checkFeature:ebat_charge_market_fee];
        }
            break;
        case kVcSubPermissionMarketFeePercent:
        {
            cell.textLabel.text = @"交易手续费比例";
            id value = [_bitasset_options_args objectForKey:@"market_fee_percent"];
            if (value) {
                cell.detailTextLabel.textColor = theme.textColorMain;
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%%", value];
            } else {
                cell.detailTextLabel.textColor = theme.textColorGray;
                cell.detailTextLabel.text = @"未设置";
            }
        }
            break;
        case kVcSubPermissionMaxMarketFee:
        {
            cell.textLabel.text = @"交易手续费最大值（单笔）";
            //            id value = [_bitasset_options_args objectForKey:@"max_market_fee"];
            //            if (value) {
            //                cell.detailTextLabel.textColor = theme.textColorMain;
            //                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%%", value];
            //            } else {
            //                cell.detailTextLabel.textColor = theme.textColorGray;
            //                cell.detailTextLabel.text = @"未设置";
            //            }    _market_fee_percent = 0;
        }
            break;
            
        case kVcSubPermissionWhiteListed:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermWhiteListed", @"需资产持有人在白名单中");
            [self _drawUI_onePermission:cell checkFeature:ebat_white_list];
        }
            break;
        case kVcSubPermissionOverrideTransfer:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermOverrideTransfer", @"发行人可回收资产");
            [self _drawUI_onePermission:cell checkFeature:ebat_override_authority];
        }
            break;
        case kVcSubPermissionNeedIssueApprove:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermNeedIssuerApprove", @"所有转账需发行人审核");
            [self _drawUI_onePermission:cell checkFeature:ebat_transfer_restricted];
        }
            break;
        case kVcSubPermissionDisableCondTransfer:
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermDisableCondTransfer", @"禁止隐私转账");
            [self _drawUI_onePermission:cell checkFeature:ebat_disable_confidential];
        }
            break;
            
        case kVcSubPermissionDisableForceSettle:    //  仅对Smart存在
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermDisableForceSettle", @"禁止强制清算");
            [self _drawUI_onePermission:cell checkFeature:ebat_disable_force_settle];
        }
            break;
        case kVcSubPermissionAllowGlobalSettle:     //  仅对Smart存在
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermAllowGlobalSettle", @"允许发行人全局清算");
            [self _drawUI_onePermission:cell checkFeature:ebat_global_settle];
        }
            break;
        case kVcSubPermissionAllowWitnessFeed:      //  仅对Smart存在
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermAllowWitnessFeed", @"允许见证人提供喂价");
            [self _drawUI_onePermission:cell checkFeature:ebat_witness_fed_asset];
        }
            break;
        case kVcSubPermissionAllowCommitteeFeed:    //  仅对Smart存在
        {
            cell.textLabel.text = NSLocalizedString(@"kVcAssetMgrCellTitlePermAllowCommitteeFeed", @"允许理事会成员提供喂价");
            [self _drawUI_onePermission:cell checkFeature:ebat_committee_fed_asset];
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
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        NSInteger rowType = [[[[_dataArray objectAtIndex:indexPath.section] objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue];
        //        //  基本信息
        //        kVcSubAssetSymbol = 0,              //  资产名称
        //        kVcSubAssetMaxSupply,               //  最大供应量
        //        kVcSubAssetDesc,                    //  描述信息
        //        kVcSubAdvSwitch,                    //  高级设置
        //        kVcSubAssetPrecision,               //  高级设置 > 精度
        //
        //        //  智能币
        //        kVcSubSmartBackingAsset,            //  高级设置 > 抵押资产
        //        kVcSubSmartFeedLifetime,            //  高级设置 > 喂价有效期 单位：分钟
        //        kVcSubSmartMinFeedNumber,           //  高级设置 > 最小有效喂价人数
        //        kVcSubSmartDelayForSettle,          //  高级设置 > 强清延迟执行时间 单位：分钟
        //        kVcSubSmartPercentOffsetSettle,     //  高级设置 > 强清补偿百分比
        //        kVcSubSmartMaxSettleVolume,         //  高级设置 > 每周期最大强清量百分比（每小时总量的百分比）
        //
        //        //  权限
        
        //
        //        kVcSubTips,                         //  提示信息
        //        kVcSubCommit,                       //  创建按钮
        switch (rowType) {
            case kVcSubAssetSymbol:
            {
                [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kVcAssetMgrCellTitleAssetName", @"资产名称")
                                                                  withTitle:nil
                                                                placeholder:NSLocalizedString(@"kVcAssetMgrCellPlaceholderAssetName", @"请输入资产名称")
                                                                 ispassword:NO
                                                                         ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                                      tfcfg:nil
                                                                 completion:(^(NSInteger buttonIndex, NSString *tfvalue)
                                                                             {
                    if (buttonIndex != 0){
                        //  TODO:4.0 有效性检测
                        _symbol = tfvalue;
                        [_mainTableView reloadData];
                    }
                })];
            }
                break;
            case kVcSubAssetMaxSupply:
                [self onAssetMaxSupplyClicked];
                break;
            case kVcSubAssetDesc:
            {
                [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kVcAssetMgrCellTitleAssetDesc", @"资产描述")
                                                                  withTitle:nil
                                                                placeholder:NSLocalizedString(@"kVcAssetMgrCellPlaceholderAssetDesc", @"请输入资产介绍")
                                                                 ispassword:NO
                                                                         ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                                      tfcfg:nil
                                                                 completion:(^(NSInteger buttonIndex, NSString *tfvalue)
                                                                             {
                    if (buttonIndex != 0){
                        _description = tfvalue;
                        [_mainTableView reloadData];
                    }
                })];
            }
                break;
            case kVcSubAssetPrecision:
                [self onAssetPrecisionClicked];
                break;
                
            case kVcSubSmartBackingAsset:
                [self onSmartBackingAssetClicked];
                break;
            case kVcSubSmartFeedLifetime:
                [self onSmartArgsClicked:NSLocalizedString(@"kVcAssetMgrInputTitleSmartFeedLifeTime", @"喂价有效期（分钟）")
                             placeholder:NSLocalizedString(@"kVcAssetMgrInputPlaceholderSmartFeedLifeTime", @"请输入过期时间")
                                args_key:@"feed_lifetime_sec"
                               max_value:nil];
                break;
            case kVcSubSmartMinFeedNumber:
                [self onSmartArgsClicked:NSLocalizedString(@"kVcAssetMgrCellTitleSmartMinFeedNum", @"最少喂价数量")
                             placeholder:NSLocalizedString(@"kVcAssetMgrInputPlaceholderSmartMinFeedNum", @"请输入最小喂价数")
                                args_key:@"minimum_feeds"
                               max_value:nil];
                break;
            case kVcSubSmartDelayForSettle:
                [self onSmartArgsClicked:NSLocalizedString(@"kVcAssetMgrInputTitleSmartDelayForSettle", @"强清延迟（分钟）")
                             placeholder:NSLocalizedString(@"kVcAssetMgrInputPlaceholderSmartDelayForSettle", @"请输入强清延迟")
                                args_key:@"force_settlement_delay_sec"
                               max_value:nil];
                break;
            case kVcSubSmartPercentOffsetSettle:
                [self onSmartArgsClicked:NSLocalizedString(@"kVcAssetMgrCellTitleSmartOffsetSettle", @"强清补偿比例")
                             placeholder:NSLocalizedString(@"kVcAssetMgrInputPlaceholderSmartOffsetSettle", @"请输入强清补偿")
                                args_key:@"force_settlement_offset_percent"
                               max_value:[NSDecimalNumber decimalNumberWithString:@"100"]];
                break;
            case kVcSubSmartMaxSettleVolume:
                [self onSmartArgsClicked:NSLocalizedString(@"kVcAssetMgrCellTitleSmartMaxSettleValuePerHour", @"每周期最大清算量")
                             placeholder:NSLocalizedString(@"kVcAssetMgrInputPlaceholderSmartMaxSettleValuePerHour", @"请输入每小强清百分比")
                                args_key:@"maximum_force_settlement_volume"
                               max_value:[NSDecimalNumber decimalNumberWithString:@"100"]];
                break;
                
            case kVcSubPermissionMarketFee:
                //                break; TODO:4.0 手续费
            case kVcSubPermissionWhiteListed:
            case kVcSubPermissionOverrideTransfer:
            case kVcSubPermissionNeedIssueApprove:
            case kVcSubPermissionDisableCondTransfer:
            case kVcSubPermissionDisableForceSettle:
            case kVcSubPermissionAllowGlobalSettle:
            case kVcSubPermissionAllowWitnessFeed:
            case kVcSubPermissionAllowCommitteeFeed:
                [self onSmartPermissionClicked:rowType];
                break;
                
            case kVcSubCommit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (BOOL)_isValidAssetSymbolName:(NSString*)symbol
{
    //  TODO:4.0 config GRAPHENE_MIN_ASSET_SYMBOL_LENGTH GRAPHENE_MAX_ASSET_SYMBOL_LENGTH
    if (!symbol) {
        return NO;
    }
    if (symbol.length < 3 || symbol.length > 16) {
        return NO;
    }
    //  TODO:4.0 有效性校验
    //    if( !isalpha( symbol.front(), loc ) )
    //        return false;
    //
    //    if( !isalnum( symbol.back(), loc ) )
    //        return false;
    //
    //    bool dot_already_present = false;
    //    for( const auto c : symbol )
    //    {
    //        if( (isalpha( c, loc ) && isupper( c, loc )) || isdigit( c, loc ) )
    //            continue;
    //
    //        if( c == '.' )
    //        {
    //            if( dot_already_present )
    //                return false;
    //
    //            dot_already_present = true;
    //            continue;
    //        }
    //
    //        return false;
    //    }
    //
    //    return true;
    //
    return YES;
}

/*
 *  (private) 事件 - 创建按钮点击
 */
- (void)onSubmitClicked
{
    //  各种条件校验
    if (![self _isValidAssetSymbolName:_symbol]) {
        [OrgUtils makeToast:@"请输入有效的资产名称。"];
        return;
    }
    
    NSDecimalNumber* zero = [NSDecimalNumber zero];
    if (!_max_supply || [_max_supply compare:zero] <= 0) {
        [OrgUtils makeToast:@"请输入最大供应量。"];
        return;
    }
    
    //    NSString*               _symbol;                    //  资产符号
    //    NSDecimalNumber*        _max_supply;                //  最大供应量
    //    NSString*               _description;               //  描述信息
    //    NSInteger               _precision;                 //  资产精度
    //    BOOL                    _enable_more_args;
    //    NSMutableDictionary*    _bitasset_options_args;     //  智能币相关参数（默认为空）
    //    uint32_t                _issuer_permissions;        //  权限
    //    uint32_t                _flags;                     //  激活标记
    
    //  TODO:4.0
    id bitasset_opts = nil;
    if (_bitasset_options_args) {
        //  智能币 - 附加校验
        id feed_lifetime_sec = [_bitasset_options_args objectForKey:@"feed_lifetime_sec"];
        if (!feed_lifetime_sec || [feed_lifetime_sec unsignedLongLongValue] == 0) {
            [OrgUtils makeToast:@"请输入喂价有效期。"];
            return;
        }
        
        id minimum_feeds = [_bitasset_options_args objectForKey:@"minimum_feeds"];
        if (!minimum_feeds || [minimum_feeds integerValue] == 0) {
            [OrgUtils makeToast:@"请输入最少喂价人数。"];
            return;
        }
        
        id force_settlement_delay_sec = [_bitasset_options_args objectForKey:@"force_settlement_delay_sec"];
        if (!force_settlement_delay_sec || [force_settlement_delay_sec unsignedLongLongValue] == 0) {
            [OrgUtils makeToast:@"请输入强清延迟执行时间。"];
            return;
        }
        
        id force_settlement_offset_percent = [_bitasset_options_args objectForKey:@"force_settlement_offset_percent"];
        if (!force_settlement_offset_percent || [force_settlement_offset_percent integerValue] == 0) {
            [OrgUtils makeToast:@"请输入强清补偿比例。"];
            return;
        }
        
        id maximum_force_settlement_volume = [_bitasset_options_args objectForKey:@"maximum_force_settlement_volume"];
        if (!maximum_force_settlement_volume || [maximum_force_settlement_volume integerValue] == 0) {
            [OrgUtils makeToast:@"请输入每周期内可强清的总数量比例。"];
            return;
        }
        
        uint32_t merged_flags = ebat_witness_fed_asset | ebat_committee_fed_asset;
        if ((_flags & merged_flags) == merged_flags) {
            [OrgUtils makeToast:@"不能同时激活见证人喂价和理事会成员喂价权限标记。"];
            return;
        }
        
        //  本地参数转换为链上参数
        bitasset_opts = @{
            @"feed_lifetime_sec":@([[_bitasset_options_args objectForKey:@"feed_lifetime_sec"] unsignedLongLongValue] * 60),
            @"minimum_feeds":@([[_bitasset_options_args objectForKey:@"minimum_feeds"] integerValue]),
            @"force_settlement_delay_sec":@([[_bitasset_options_args objectForKey:@"force_settlement_delay_sec"] unsignedLongLongValue] * 60),
            @"force_settlement_offset_percent":@([[_bitasset_options_args objectForKey:@"force_settlement_offset_percent"] integerValue] * GRAPHENE_1_PERCENT),
            @"maximum_force_settlement_volume":@([[_bitasset_options_args objectForKey:@"maximum_force_settlement_volume"] integerValue] * GRAPHENE_1_PERCENT),
            @"short_backing_asset":[[_bitasset_options_args objectForKey:@"short_backing_asset"] objectForKey:@"id"]
        };
    } else {
        //  非智能币 - 取消多余的标记
        _issuer_permissions = _issuer_permissions & ~ebat_issuer_permission_mask_smart_only;
        _flags = _flags & ~ebat_issuer_permission_mask_smart_only;
    }
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account);
    id uid = account[@"id"];
    
    id core_asset = [chainMgr getChainObjectByID:chainMgr.grapheneCoreAssetID];
    assert(core_asset);
    NSInteger core_precision = [[core_asset objectForKey:@"precision"] integerValue];
    
    id n_max_supply_pow = [NSString stringWithFormat:@"%@", [_max_supply decimalNumberByMultiplyingByPowerOf10:_precision]];
    unsigned long long l_max_supply_pow = [n_max_supply_pow unsignedLongLongValue];
    
    id n_core_asset_one_pow = [NSString stringWithFormat:@"%@", [[NSDecimalNumber one] decimalNumberByMultiplyingByPowerOf10:core_precision]];
    unsigned long long l_one_core_asset_pow = [n_core_asset_one_pow unsignedLongLongValue];
    
    id asset_options = @{
        @"max_supply":@(l_max_supply_pow),
        @"market_fee_percent":@0,
        @"max_market_fee":@0,
        @"issuer_permissions":@(_issuer_permissions),
        @"flags":@(_flags),
        //  REMARK: 避免手续费池被薅羊毛，默认兑换比例为供应量最大值。如果需要开启自定义资产支付广播手续费，稍后可设置为合适的值。
        @"core_exchange_rate":@{@"base":@{@"asset_id":chainMgr.grapheneCoreAssetID, @"amount":@(l_one_core_asset_pow)},
                                @"quote":@{@"asset_id":@"1.3.1", @"amount":@(l_max_supply_pow)}},
        @"whitelist_authorities":@[],
        @"blacklist_authorities":@[],
        @"whitelist_markets":@[],
        @"blacklist_markets":@[],
        @"description":_description ?: @""
    };
    
    id opdata = @{
        @"fee":@{@"asset_id":chainMgr.grapheneCoreAssetID, @"amount":@0},
        @"issuer":uid,
        @"symbol":_symbol,
        @"precision":@(_precision),
        @"common_options":asset_options,
        @"is_prediction_market":@NO,
    };
    if (_bitasset_options_args) {
        opdata = [[[opdata mutableCopy] ruby_apply:^(id mutable_opdata) {
            [mutable_opdata setObject:bitasset_opts forKey:@"bitasset_opts"];
        }] copy];
    }
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[BitsharesClientManager sharedBitsharesClientManager] calcOperationFee:ebo_asset_create opdata:opdata] then:(^id(id fee_price_item) {
        [self hideBlockView];
        NSString* price = [OrgUtils formatAssetAmountItem:fee_price_item];
        [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:[NSString stringWithFormat:@"创建 %@ 资产预计花费 %@，是否继续？", _symbol, price]
                                                               withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                              completion:^(NSInteger buttonIndex)
         {
            if (buttonIndex == 1)
            {
                //  --- 检测合法 执行请求 ---
                [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                    if (unlocked){
                        // TODO:4.0 args
                        [self onSubmitCore:opdata opaccount:account];
                        //                         [self gotoUpgradeToLifetimeMemberCore:op_data fee_item:fee_price_item account:account_info];
                    }
                }];
            }
        }];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)onSubmitCore:(id)opdata opaccount:(id)opaccount
{
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_asset_create
                     using_owner_authority:NO invoke_proposal_callback:NO
                                    opdata:opdata
                                 opaccount:opaccount
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] assetCreate:opdata] then:(^id(id data) {
            [self hideBlockView];
            [OrgUtils makeToast:@"创建资产成功。"];//TODO:4.0
            //  [统计]
            [OrgUtils logEvents:@"txAssetCreateFullOK" params:@{@"account":opaccount[@"id"]}];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txAssetCreateFailed" params:@{@"account":opaccount[@"id"]}];
            return nil;
        })];
    }];
}

/*
 *  (private) 事件 - 最大供应量点击
 */
- (void)onAssetMaxSupplyClicked
{
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:NSLocalizedString(@"kVcAssetMgrCellTitleMaxSupply", @"最大供应量")
                                                      withTitle:nil
                                                    placeholder:NSLocalizedString(@"kVcAssetMgrCellPlaceholderMaxSupply", @"请输入最大供应量")
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:(^(SCLTextView *tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.iDecimalPrecision = 0;
    })
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue)
                                                                 {
        if (buttonIndex != 0){
            NSDecimalNumber* n_value = [OrgUtils auxGetStringDecimalNumberValue:tfvalue];
            if ([n_value compare:[NSDecimalNumber zero]] == 0) {
                _max_supply = nil;
            } else {
                if ([n_value compare:_max_supply_editable] > 0) {
                    n_value = _max_supply_editable;
                }
                _max_supply = n_value;
            }
            [_mainTableView reloadData];
        }
    })];
}

/*
 *  (private) 事件 - 资产精度点击（ 0 - 12 位小数）
 */
- (void)onAssetPrecisionClicked
{
    //  TODO:4.0 lang
    NSMutableArray* data_list = [NSMutableArray array];
    NSInteger default_select = -1;
    for (NSInteger i = 0; i <= 12; ++i) {
        id name = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetMgrCellValueAssetPrecision", @"%@ 位小数"), @(i)];
        if (i == _precision){
            default_select = [data_list count];
        }
        [data_list addObject:@{@"name":name, @"value":@(i)}];
    }
    [[[MyPopviewManager sharedMyPopviewManager] showModernListView:self.navigationController
                                                           message:NSLocalizedString(@"kVcAssetMgrCellTitleAssetPrecision", @"资产精度")
                                                             items:data_list
                                                           itemkey:@"name"
                                                      defaultIndex:default_select] then:(^id(id result) {
        if (result){
            [self updatePrecision:[[result objectForKey:@"value"] integerValue]];
            //  REMARK：更改了资产精度，则清除用户之前设置的最大供应量。
            if (_max_supply && [_max_supply compare:_max_supply_editable] > 0) {
                _max_supply = nil;
            }
            [_mainTableView reloadData];
        }
        return nil;
    })];
}

/*
 *  (private) 事件 - 具体的权限信息点击
 */
- (void)onSmartPermissionClicked:(NSInteger)rowType
{
    //  TODO:4.0 lang
    NSArray* items;
    NSInteger defaultIndex = 0;
    uint32_t feature = [self _permissionRowType2Feature:rowType];
    
    if (rowType == kVcSubPermissionAllowGlobalSettle) {
        items = @[
            @{@"title":NSLocalizedString(@"kVcAssetMgrPermissionActionDisablePermanently", @"永久禁用（不可再开启）"),
              @"type":@(kPermissionActionDisablePermanently)},
            @{@"title":NSLocalizedString(@"kVcAssetMgrPermissionActionActivateNow", @"立即激活（创建后开启）"),
              @"type":@(kPermissionActionActivateNow)},
        ];
        if (_issuer_permissions & feature) {
            defaultIndex = 1;
        } else {
            defaultIndex = 0;
        }
    } else {
        items = @[
            @{@"title":NSLocalizedString(@"kVcAssetMgrPermissionActionDisablePermanently", @"永久禁用（不可再开启）"),
              @"type":@(kPermissionActionDisablePermanently)},
            @{@"title":NSLocalizedString(@"kVcAssetMgrPermissionActionActivateLater", @"暂不激活（后续可开启）"),
              @"type":@(kPermissionActionActivateLater)},
            @{@"title":NSLocalizedString(@"kVcAssetMgrPermissionActionActivateNow", @"立即激活（创建后开启）"),
              @"type":@(kPermissionActionActivateNow)},
        ];
        if (_issuer_permissions & feature) {
            if (_flags & feature) {
                defaultIndex = 2;
            } else {
                defaultIndex = 1;
            }
        } else {
            defaultIndex = 0;
        }
    }
    [[[MyPopviewManager sharedMyPopviewManager] showModernListView:self.navigationController
                                                           message:nil
                                                             items:items
                                                           itemkey:@"title"
                                                      defaultIndex:defaultIndex] then:(^id(id result) {
        if (result){
            switch ([[result objectForKey:@"type"] integerValue]) {
                case kPermissionActionDisablePermanently:
                {
                    //  取消 permission 和 flags
                    _issuer_permissions = _issuer_permissions & ~feature;
                    _flags = _flags & ~feature;
                    //  刷新
                    [_mainTableView reloadData];
                }
                    break;
                case kPermissionActionActivateLater:
                {
                    //  开启 permission，取消 flags。
                    _issuer_permissions = _issuer_permissions | feature;
                    _flags = _flags & ~feature;
                    //  刷新
                    [_mainTableView reloadData];
                }
                    break;
                case kPermissionActionActivateNow:
                {
                    //  同时开启 permission 和 flags。
                    _issuer_permissions = _issuer_permissions | feature;
                    _flags = _flags | feature;
                    //  REMARK：全局清算不可设置flag。
                    if (feature == ebat_global_settle) {
                        _flags = _flags & ~feature;
                    }
                    //  刷新
                    [_mainTableView reloadData];
                }
                    break;
                default:
                    break;
            }
        }
        return nil;
    })];
}

/*
 *  (private) 事件 - 点击抵押资产
 */
- (void)onSmartBackingAssetClicked
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    //  TODO:4.0 lang
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:@"请选择抵押资产"
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:@[@"无", chainMgr.grapheneCoreAssetSymbol, @"自定义"]
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            switch (buttonIndex) {
                case 0: //  取消
                {
                    _bitasset_options_args = nil;
                    //  取消智能币相关标记
                    _issuer_permissions = _issuer_permissions & ~ebat_issuer_permission_mask_smart_only;
                    _flags = _flags & ~ebat_issuer_permission_mask_smart_only;
                    [self _buildRowTypeArray];
                    [_mainTableView reloadData];
                }
                    break;
                case 1: //  BTS
                {
                    [self genDefaultSmartCoinArgs];
                    [_bitasset_options_args setObject:@{@"id":chainMgr.grapheneCoreAssetID, @"symbol":chainMgr.grapheneCoreAssetSymbol}
                                               forKey:@"short_backing_asset"];
                    //  添加智能币相关标记（flags不变）
                    _issuer_permissions = _issuer_permissions | ebat_issuer_permission_mask_smart_only;
                    [self _buildRowTypeArray];
                    [_mainTableView reloadData];
                }
                    break;
                case 2: //  自定义
                {
                    //  TODO:4.0 type
                    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
                        if (asset_info){
                            [self genDefaultSmartCoinArgs];
                            [_bitasset_options_args setObject:asset_info forKey:@"short_backing_asset"];
                            //  添加智能币相关标记（flags不变）
                            _issuer_permissions = _issuer_permissions | ebat_issuer_permission_mask_smart_only;
                            [self _buildRowTypeArray];
                            [_mainTableView reloadData];
                        }
                    }];
                    //    vc.title = @"资产查询";//TODO:4.0 lang
                    [self pushViewController:vc
                                     vctitle:@"搜索抵押物"
                                   backtitle:kVcDefaultBackTitleName];
                }
                    break;
                default:
                    break;
            }
        }
    }];
}

/*
 *  (private) 事件 - 智能币部分参数输入
 */
- (void)onSmartArgsClicked:(NSString*)args_title
               placeholder:(NSString*)args_placeholder
                  args_key:(NSString*)args_key max_value:(NSDecimalNumber*)max_value
{
    assert(args_title);
    assert(args_placeholder);
    assert(args_key);
    
    [[UIAlertViewManager sharedUIAlertViewManager] showInputBox:args_title
                                                      withTitle:nil
                                                    placeholder:args_placeholder
                                                     ispassword:NO
                                                             ok:NSLocalizedString(@"kBtnOK", @"确定")
                                                          tfcfg:(^(SCLTextView *tf) {
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.iDecimalPrecision = 0;
    })
                                                     completion:(^(NSInteger buttonIndex, NSString *tfvalue)
                                                                 {
        if (buttonIndex != 0){
            assert(_bitasset_options_args);
            NSDecimalNumber* n_value = [OrgUtils auxGetStringDecimalNumberValue:tfvalue];
            if ([n_value compare:[NSDecimalNumber zero]] == 0) {
                [_bitasset_options_args removeObjectForKey:args_key];
            } else {
                if (max_value && [n_value compare:max_value] > 0) {
                    n_value = max_value;
                }
                [_bitasset_options_args setObject:[NSString stringWithFormat:@"%@", n_value] forKey:args_key];
            }
            [_mainTableView reloadData];
        }
    })];
}

@end
