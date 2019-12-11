//
//  VCOtcMcHome.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcHome.h"

#import "VCOtcMcAssetList.h"
#import "VCOtcMcAdList.h"
#import "VCOtcOrders.h"

#import "VCOtcReceiveMethods.h"

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
    UITableViewBase*        _mainTableView;
    NSArray*                _dataArray;
}

@end

@implementation VCOtcMcHome

-(void)dealloc
{
    _dataArray = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}
//
//- (void)onQueryUserOrdersResponsed:(id)responsed
//{
//    id records = [[responsed objectForKey:@"data"] objectForKey:@"records"];
//    [_dataArray removeAllObjects];
//    if (records) {
//        [_dataArray addObjectsFromArray:records];
//    }
//    [self refreshView];
//}
//
//- (void)queryUserOrders
//{
//    OtcManager* otc = [OtcManager sharedOtcManager];
//    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
//    [[[otc queryUserOrders:[otc getCurrentBtsAccount] type:eoot_query_all status:eoos_all page:0 page_size:50] then:^id(id data) {
//        [self hideBlockView];
//        [self onQueryUserOrdersResponsed:data];
//        return nil;
//    }] catch:^id(id error) {
//        [self hideBlockView];
//        [otc showOtcError:error];
//        return nil;
//    }];
//}

//- (id)init
//{
//    self = [super init];
//    if (self) {
//    }
//    return self;
//}

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
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
        cell.showCustomBottomLine = YES;
        //  TODO:3.0
        [cell setItem:@{@"merchantNickname":@"秦佳仙承兑", @"ctime":@"2019-11-26T13:29:51.000+0000"}];
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
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = @"统计分析";//TODO:
        }
            break;
            
        case kVcSubOtcAsset:
            cell.textLabel.text = @"OTC资产";//TODO:
            break;
        case kVcSubOtcAd:
            cell.textLabel.text = @"OTC广告";//TODO:
            break;
        case kVcSubOtcOrder:
            cell.textLabel.text = @"OTC订单";//TODO:
            break;
            
        case kVcSubReceiveMethods:
            cell.textLabel.text = @"收款方式";//TODO:
            break;
        case kVcSubPaymentMethods:
            cell.textLabel.text = @"付款方式";//TODO:
            break;
            
        default:
            assert(false);
            break;
    }
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id secinfos = [_dataArray objectAtIndex:indexPath.section];
        NSInteger rowType = [[[secinfos objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue];
        switch (rowType) {
            case kVcSubBasicInfo:
//                cell.textLabel.text = @"基本信息";//TODO:
                break;
                
            case kVcSubStatistics:
//                cell.textLabel.text = @"统计分析";//TODO:
                break;
                
            case kVcSubOtcAsset:
//                cell.textLabel.text = @"OTC资产";//TODO:
                break;
            case kVcSubOtcAd:
//                cell.textLabel.text = @"OTC广告";//TODO:
                break;
            case kVcSubOtcOrder:
//                cell.textLabel.text = @"OTC订单";//TODO:
                break;
                
            case kVcSubReceiveMethods:
//                cell.textLabel.text = @"收款方式";//TODO:
                break;
            case kVcSubPaymentMethods:
//                cell.textLabel.text = @"付款方式";//TODO:
                break;
                
            default:
                assert(false);
                break;
        }
    }];
}

@end
