//
//  VCOtcMcHome.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcHome.h"

#import "VCOtcUserAuthInfos.h"
#import "VCOtcMcAssetList.h"
#import "VCOtcMcAdList.h"
#import "VCOtcOrders.h"

#import "VCOtcReceiveMethods.h"
#import "VCOtcMcPaymentMethods.h"

#import "ViewOtcMcMerchantBasicCell.h"

enum
{
    kVcSecMerchantBasic = 0,    //  基本信息
    //    kVcSecMerchantStatistics,   //  统计信息（成交单数等）
    kVcSecActions,              //  各种管理入口
    kVcSecReceiveAndPayment,    //  收付款管理
};

enum
{
    kVcSubBasicInfo = 0,        //  基本信息
    
    kVcSubStatistics,           //  统计信息
    
    kVcSubOtcAsset,             //  OTC资产
    kVcSubOtcAd,                //  我的广告
    kVcSubOtcOrder,             //  商家订单
    
    kVcSubReceiveMethods,       //  收款方式
    kVcSubPaymentMethods        //  付款方式
};

@interface VCOtcMcHome ()
{
    NSDictionary*           _progress_info;     //  申请状态进度
    NSMutableDictionary*    _merchant_detail;   //  商家详情（已同意之后才有，否则为nil。）
    
    UITableViewBase*        _mainTableView;
    NSArray*                _dataArray;
}

@end

@implementation VCOtcMcHome

-(void)dealloc
{
    _progress_info = nil;
    _merchant_detail = nil;
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithProgressInfo:(id)progress_info merchantDetail:(id)merchant_detail
{
    self = [super init];
    if (self) {
        assert(merchant_detail);
        _progress_info = progress_info;
        _merchant_detail = [merchant_detail mutableCopy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  TODO:3.0 config
    _dataArray = @[
        @{@"type":@(kVcSecMerchantBasic), @"rows":@[@(kVcSubBasicInfo)]},
        @{@"type":@(kVcSecActions), @"rows":@[@(kVcSubOtcAsset), @(kVcSubOtcAd), @(kVcSubOtcOrder)]},
        @{@"type":@(kVcSecReceiveAndPayment), @"rows":@[@(kVcSubReceiveMethods), @(kVcSubPaymentMethods)]}
    ];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
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
    //  TODO:3.0
    id secinfos = [_dataArray objectAtIndex:indexPath.section];
    NSInteger rowType = [[[secinfos objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue];
    switch (rowType) {
        case kVcSubBasicInfo:
            return 60.0f;
        default:
            break;
    }
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
    id secinfos = [_dataArray objectAtIndex:indexPath.section];
    NSInteger rowType = [[[secinfos objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue];
    if (rowType == kVcSubBasicInfo) {
        ViewOtcMcMerchantBasicCell* cell = [[ViewOtcMcMerchantBasicCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                                             reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.backgroundColor = [UIColor clearColor];
        cell.showCustomBottomLine = YES;
        [cell setItem:_merchant_detail];
        return cell;
    }
    
    
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    cell.backgroundColor = [UIColor clearColor];
    cell.showCustomBottomLine = YES;
    
    switch (rowType) {
        case kVcSubBasicInfo:
            assert(false);
            break;
            
        case kVcSubStatistics:
        {
            //  TODO:3.0 暂时不支持统计分析数据
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = NSLocalizedString(@"kOtcMcHomeCellLabelTitleStatistics", @"统计分析");
        }
            break;
            
        case kVcSubOtcAsset:
            cell.textLabel.text = NSLocalizedString(@"kOtcMcHomeCellLabelTitleAsset", @"商家资产");
            cell.imageView.image = [UIImage templateImageNamed:@"iconOtcMcAsset"];
            break;
        case kVcSubOtcAd:
            cell.textLabel.text = NSLocalizedString(@"kOtcMcHomeCellLabelTitleAd", @"商家广告");
            cell.imageView.image = [UIImage templateImageNamed:@"iconOtcMcAd"];
            break;
        case kVcSubOtcOrder:
            cell.textLabel.text = NSLocalizedString(@"kOtcMcHomeCellLabelTitleOrder", @"商家订单");
            cell.imageView.image = [UIImage templateImageNamed:@"iconOtcOrder"];
            break;
            
        case kVcSubReceiveMethods:
            cell.textLabel.text = NSLocalizedString(@"kOtcMcHomeCellLabelTitleReceiveMethod", @"收款方式");
            cell.imageView.image = [UIImage templateImageNamed:@"iconOtcReceive"];
            break;
        case kVcSubPaymentMethods:
            cell.textLabel.text = NSLocalizedString(@"kOtcMcHomeCellLabelTitlePaymentMethod", @"付款方式");
            cell.imageView.image = [UIImage templateImageNamed:@"iconOtcPayment"];
            break;
            
        default:
            assert(false);
            break;
    }
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        [[OtcManager sharedOtcManager] guardUserIdVerified:self
                                                 auto_hide:YES
                                         askForIdVerifyMsg:nil
                                                  callback:^(id auth_info)
         {
            id secinfos = [_dataArray objectAtIndex:indexPath.section];
            NSInteger rowType = [[[secinfos objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue];
            switch (rowType) {
                case kVcSubBasicInfo:
                {
                    VCBase* vc = [[VCOtcUserAuthInfos alloc] initWithAuthInfo:auth_info];
                    [self pushViewController:vc
                                     vctitle:NSLocalizedString(@"kVcTitleOtcAuthInfos", @"认证信息")
                                   backtitle:kVcDefaultBackTitleName];
                }
                    break;
                    
                case kVcSubStatistics:
                    break;
                    
                case kVcSubOtcAsset:
                    [self gotoOtcAssetClicked:auth_info];
                    break;
                case kVcSubOtcAd:
                {
                    //  TODO:3.0 激活代码临时放在这里
                    if ([[_merchant_detail objectForKey:@"status"] integerValue] == eoms_not_active ||
                        [[_merchant_detail objectForKey:@"level"] integerValue] <= 0) {
                        [self processMerchantActive:auth_info];
                    } else {
                        [self gotoOtcAdClicked:auth_info];
                    }
                }
                    break;
                case kVcSubOtcOrder:
                    [self gotoOtcOrderClicked:auth_info];
                    break;
                    
                case kVcSubReceiveMethods:
                {
                    VCBase* vc = [[VCOtcReceiveMethods alloc] initWithAuthInfo:auth_info user_type:eout_merchant];
                    [self pushViewController:vc
                                     vctitle:NSLocalizedString(@"kVcTitleOtcReceiveMethodsList", @"收款方式")
                                   backtitle:kVcDefaultBackTitleName];
                }
                    break;
                case kVcSubPaymentMethods:
                {
                    VCBase* vc = [[VCOtcMcPaymentMethods alloc] initWithAuthInfo:auth_info merchant_detail:_merchant_detail];
                    [self pushViewController:vc
                                     vctitle:NSLocalizedString(@"kVcTitleOtcMcPaymentMethodsList", @"付款方式")
                                   backtitle:kVcDefaultBackTitleName];
                }
                    break;
                    
                default:
                    assert(false);
                    break;
            }
        }];
    }];
}

- (void)gotoOtcAssetClicked:(id)auth_info
{
    VCBase* vc = [[VCOtcMcAssetList alloc] initWithAuthInfo:auth_info user_type:eout_merchant merchant_detail:_merchant_detail];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleOtcMcAsset", @"商家资产") backtitle:kVcDefaultBackTitleName];
}

- (void)gotoOtcAdClicked:(id)auth_info
{
    VCBase* vc = [[VCOtcMcAdListPages alloc] initWithAuthInfo:auth_info user_type:eout_merchant merchant_detail:_merchant_detail];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleOtcMcAd", @"商家广告") backtitle:kVcDefaultBackTitleName];
}

- (void)gotoOtcOrderClicked:(id)auth_info
{
    VCBase* vc = [[VCOtcOrdersPages alloc] initWithAuthInfo:auth_info user_type:eout_merchant];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleOtcMcOrder", @"商家订单") backtitle:kVcDefaultBackTitleName];
}

- (void)processMerchantActive:(id)auth_info
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //  查询商家制度
    OtcManager* otc = [OtcManager sharedOtcManager];
    [[[otc merchantPolicy:[otc getCurrentBtsAccount]] then:^id(id responsed) {
        [self hideBlockView];
        
        id data = [responsed objectForKey:@"data"];
        id merchantPolicyList = [data objectForKey:@"merchantPolicyList"];
        if (!merchantPolicyList || [merchantPolicyList count] <= 0) {
            [OrgUtils makeToast:NSLocalizedString(@"kOtcMgrMcActiveNoPolicy", @"商家制度未分配，请稍后再试。")];
            return nil;
        }
        
        id assetSymbol = [data objectForKey:@"mortgageAssetSymbol"];
        
        //  按照保证金升序排列
        NSMutableArray* mutableMerchantPolicyList = [merchantPolicyList mutableCopy];
        [mutableMerchantPolicyList sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [[obj1 objectForKey:@"mortgage"] integerValue] > [[obj2 objectForKey:@"mortgage"] integerValue];
        }];
        
        //  选择第一个保证金最低的商家制度
        id firstMerchantPolicy = [mutableMerchantPolicyList firstObject];
        assert(firstMerchantPolicy);
        
        //  提示信息
        id msg = [NSString stringWithFormat:NSLocalizedString(@"kOtcMgrMcActiveAskMessage", @"该功能需要先激活商家账号后才可使用，激活需要 %@%@ 作为保证金，可在商家资产里转入。"),
                  firstMerchantPolicy[@"mortgage"],
                  assetSymbol];
        
        //  激活提示
        [[UIAlertViewManager sharedUIAlertViewManager] showMessageEx:msg
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                        cancelButton:NSLocalizedString(@"kBtnCancel", @"取消")
                                                        otherButtons:@[NSLocalizedString(@"kOtcMgrMcActiveAskBtnActiveNow", @"立即激活")]
                                                          completion:^(NSInteger buttonIndex)
         {
            if (buttonIndex == 1) {
                [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                    if (unlocked) {
                        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
                        OtcManager* otc = [OtcManager sharedOtcManager];
                        [[[otc merchantActive:[otc getCurrentBtsAccount]] then:^id(id data) {
                            [self hideBlockView];
                            if ([[data objectForKey:@"data"] boolValue]) {
                                [OrgUtils makeToast:NSLocalizedString(@"kOtcMgrMcActiveTipsOK", @"激活成功。")];
                                //  本地设置已激活标记
                                [_merchant_detail setObject:@(eoms_activated) forKey:@"status"];
                                //  TODO:2.9 商家等级暂时设置为 1
                                [_merchant_detail setObject:@(1) forKey:@"level"];
                                [_mainTableView reloadData];
                            } else {
                                //  激活失败
                                [OrgUtils makeToast:NSLocalizedString(@"kOtcMgrMcActiveFailedTipMessage", @"激活失败，请往商家账号转入足够的保证金。")];
                            }
                            return nil;
                        }] catch:^id(id error) {
                            [self hideBlockView];
                            [otc showOtcError:error];
                            return nil;
                        }];
                    }
                }];
            }
        }];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

@end
