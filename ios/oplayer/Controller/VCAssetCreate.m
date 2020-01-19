//
//  VCAssetCreate.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetCreate.h"
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
    //  基本信息
    kVcSubAssetSymbol = 0,              //  资产名称
    kVcSubAssetMaxSupply,               //  最大供应量
    kVcSubAssetDesc,                    //  描述信息
    kVcSubAdvSwitch,                    //  高级设置
    kVcSubAssetPrecision,               //  高级设置 > 精度
    
    //  智能币
    kVcSubSmartBackingAsset,            //  高级设置 > 背书资产
    kVcSubSmartFeedLifetime,            //  高级设置 > 喂价有效期 单位：分钟
    kVcSubSmartMinFeedNumber,           //  高级设置 > 最小有效喂价人数
    kVcSubSmartDelayForSettle,          //  高级设置 > 强清延迟执行时间 单位：分钟
    kVcSubSmartPercentOffsetSettle,     //  高级设置 > 强清补偿百分比
    kVcSubSmartMaxSettleVolume,         //  高级设置 > 每周期最大强清量百分比（每小时总量的百分比）
    
    //  权限
    kVcSubPermissionMarketFee,          //  高级设置 > 开启手续费
    kVcSubPermissionWhiteListed,        //  高级设置 > 白名单
    kVcSubPermissionOverrideTransfer,   //  高级设置 > 资产回收
    kVcSubPermissionNeedIssueApprove,   //  高级设置 > 需要发行人审核
    kVcSubPermissionDisableCondTransfer,//  高级设置 > 禁止隐私转账
    kVcSubPermissionDisableForceSettle, //  高级设置 > 禁止清算（仅对Smart币）
    kVcSubPermissionAllowGlobalSettle,  //  高级设置 > 允许发行人全局清算（仅对Smart币）
    kVcSubPermissionAllowWitnessFeed,   //  高级设置 > 允许见证人喂价（仅对Smart币）
    kVcSubPermissionAllowCommitteeFeed, //  高级设置 > 允许理事会喂价（仅对Smart币）
    
    kVcSubTips,                         //  提示信息
    kVcSubCommit,                       //  创建按钮
};

@interface VCAssetCreate ()
{
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    ViewTipsInfoCell*       _cell_tips;
    ViewBlockLabel*         _lbCommit;
    
    BOOL                    _enable_more_args;
    NSDictionary*           _smart_backing_asset;       //  背书资产
    NSMutableDictionary*    _args_bitasset_options;     //  智能币参数
}

@end

@implementation VCAssetCreate

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

- (id)init
{
    self = [super init];
    if (self) {
        _dataArray = [NSMutableArray array];
        _enable_more_args = NO;
        _smart_backing_asset = nil;
        _args_bitasset_options = [NSMutableDictionary dictionary];
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
        BOOL isSmartCorin = _smart_backing_asset != nil;
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
    _lbCommit = [self createCellLableButton:@"创建"];
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
                    titleLabel.text = @"基本信息";
                    break;
                case kVcSecPermission:
                    titleLabel.text = @"权限信息";
                    break;
                case kVcSecSmartCoin:
                    titleLabel.text = @"智能币信息";
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
            cell.textLabel.text = @"资产名称";
            cell.detailTextLabel.text = @"USD";
        }
            break;
        case kVcSubAssetMaxSupply:
        {
            cell.textLabel.text = @"最大供应量";
            cell.detailTextLabel.text = @"232333333 USD";
        }
            break;
        case kVcSubAssetDesc:
        {
            cell.textLabel.text = @"资产介绍";
            cell.detailTextLabel.text = @"巴拉巴拉用于xxxx用途";
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
            
            cell.textLabel.text = @"高级设置";
            return cell;
        }
            break;
        case kVcSubAssetPrecision:
        {
            cell.textLabel.text = @"资产精度";
            cell.detailTextLabel.text = @"5 位小数";
        }
            break;
            
            //  智能币选项
        case kVcSubSmartBackingAsset:
        {
            cell.textLabel.text = @"借贷抵押资产";
            if (_smart_backing_asset) {
                cell.detailTextLabel.text = [_smart_backing_asset objectForKey:@"symbol"];
            } else {
                cell.detailTextLabel.text = @"无";
            }
        }
            break;
        case kVcSubSmartFeedLifetime:
        {
            cell.textLabel.text = @"喂价有效期（分钟）";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubSmartMinFeedNumber:
        {
            cell.textLabel.text = @"最少喂价数量";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubSmartDelayForSettle:
        {
            cell.textLabel.text = @"强制清算延迟时间（分钟）";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubSmartPercentOffsetSettle:
        {
            cell.textLabel.text = @"强制清算补偿百分比";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubSmartMaxSettleVolume:
        {
            cell.textLabel.text = @"每周期最大清算量百分比（总量的百分比，每小时）";
            cell.detailTextLabel.text = @"";
        }
            break;
            
            //  权限信息
        case kVcSubPermissionMarketFee:
        {
            cell.textLabel.text = @"收取市场手续费";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubPermissionWhiteListed:
        {
            cell.textLabel.text = @"需资产持有人在白名单中";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubPermissionOverrideTransfer:
        {
            cell.textLabel.text = @"发行人可回收资产";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubPermissionNeedIssueApprove:
        {
            cell.textLabel.text = @"所有转账需发行人审核";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubPermissionDisableCondTransfer:
        {
            cell.textLabel.text = @"禁止隐私转账";
            cell.detailTextLabel.text = @"";
        }
            break;
            
        case kVcSubPermissionDisableForceSettle:    //  仅对Smart存在
        {
            cell.textLabel.text = @"禁止强制清算";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubPermissionAllowGlobalSettle:     //  仅对Smart存在
        {
            cell.textLabel.text = @"允许发行人全局清算";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubPermissionAllowWitnessFeed:      //  仅对Smart存在
        {
            cell.textLabel.text = @"允许见证人提供喂价";
            cell.detailTextLabel.text = @"";
        }
            break;
        case kVcSubPermissionAllowCommitteeFeed:    //  仅对Smart存在
        {
            cell.textLabel.text = @"允许理事会成员提供喂价";
            cell.detailTextLabel.text = @"";
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
        //        kVcSubSmartBackingAsset,            //  高级设置 > 背书资产
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
                break;
            case kVcSubAssetMaxSupply:
                break;
            case kVcSubAssetDesc:
                break;
            case kVcSubAssetPrecision:
                break;
                
            case kVcSubSmartBackingAsset:
                [self onSmartBackingAssetClicked];
                break;
            case kVcSubSmartFeedLifetime:
                break;
            case kVcSubSmartMinFeedNumber:
                break;
            case kVcSubSmartDelayForSettle:
                break;
            case kVcSubSmartPercentOffsetSettle:
                break;
            case kVcSubSmartMaxSettleVolume:
                break;
                
            case kVcSubPermissionMarketFee:
                break;
            case kVcSubPermissionWhiteListed:
            case kVcSubPermissionOverrideTransfer:
            case kVcSubPermissionNeedIssueApprove:
            case kVcSubPermissionDisableCondTransfer:
            case kVcSubPermissionDisableForceSettle:
            case kVcSubPermissionAllowGlobalSettle:
            case kVcSubPermissionAllowWitnessFeed:
            case kVcSubPermissionAllowCommitteeFeed:
                break;
                
            case kVcSubCommit:
                break;
            default:
                break;
        }
    }];
}

- (void)onSmartBackingAssetClicked
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    //  TODO:4.0 lang
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:@"请选择背书资产"
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:@[@"无", chainMgr.grapheneCoreAssetSymbol, @"自定义"]
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            switch (buttonIndex) {
                case 0: //  取消
                {
                    _smart_backing_asset = nil;
                    [self _buildRowTypeArray];
                    [_mainTableView reloadData];
                }
                    break;
                case 1: //  BTS
                {
                    _smart_backing_asset = @{@"id":chainMgr.grapheneCoreAssetID, @"symbol":chainMgr.grapheneCoreAssetSymbol};
                    [self _buildRowTypeArray];
                    [_mainTableView reloadData];
                }
                    break;
                case 2: //  自定义
                {
                    //  TODO:4.0 type
                    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
                        if (asset_info){
                            _smart_backing_asset = asset_info;
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

@end
