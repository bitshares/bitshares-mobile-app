//
//  VCAssetManager.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetManager.h"
#import "ViewAssetBasicInfoCell.h"

#import "VCAssetCreateOrEdit.h"
#import "VCAssetDetails.h"
#import "VCAssetOpIssue.h"
#import "VCAssetOpCommon.h"
#import "VCAssetOpGlobalSettle.h"

@interface VCAssetManager ()
{
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCAssetManager

-(void)dealloc
{
    _dataArray = nil;
    _lbEmpty = nil;
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
    }
    return self;
}

- (void)onQueryMyIssuedAssetsResponsed:(id)data_array
{
    [_dataArray removeAllObjects];
    
    //  兼容错误数据
    if (!data_array || ![data_array isKindOfClass:[NSArray class]]) {
        data_array = @[];
    }
    
    //  添加到列表
    [_dataArray addObjectsFromArray:data_array];
    
    [self refreshView];
}

- (void)refreshView
{
    _mainTableView.hidden = [_dataArray count] <= 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

- (void)queryMyIssuedAssets
{
    id account_name = [[WalletManager sharedWalletManager] getWalletAccountName];
    assert(account_name);
    
    //  TODO:4.0 limit config
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[chainMgr queryAssetsByIssuer:account_name
                              start:[NSString stringWithFormat:@"1.%@.0", @(ebot_asset)]
                              limit:100] then:^id(id data_array)
      {
        NSMutableDictionary* issuerHash = [NSMutableDictionary dictionary];
        NSMutableArray* bitasset_data_id_list = [NSMutableArray array];
        NSMutableArray* dynamic_asset_data_id_list = [NSMutableArray array];
        if (!data_array || ![data_array isKindOfClass:[NSArray class]]) {
            data_array = @[];
        }
        for (id asset in data_array) {
            [issuerHash setObject:@YES forKey:[asset objectForKey:@"issuer"]];
            NSString* bitasset_data_id = [asset objectForKey:@"bitasset_data_id"];
            if (bitasset_data_id && ![bitasset_data_id isEqualToString:@""]) {
                [bitasset_data_id_list addObject:bitasset_data_id];
            }
            NSString* dynamic_asset_data_id = [asset objectForKey:@"dynamic_asset_data_id"];
            assert(dynamic_asset_data_id);
            [dynamic_asset_data_id_list addObject:dynamic_asset_data_id];
        }
        //  全部都查询都忽略缓存
        [bitasset_data_id_list addObjectsFromArray:[issuerHash allKeys]];
        id p1 = [chainMgr queryAllGrapheneObjectsSkipCache:bitasset_data_id_list];
        id p2 = [chainMgr queryAllGrapheneObjectsSkipCache:dynamic_asset_data_id_list];
        return [[WsPromise all:@[p1, p2]] then:^id(id data) {
            [self hideBlockView];
            [self onQueryMyIssuedAssetsResponsed:data_array];
            return nil;
        }];
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

- (void)onAddNewAssetClicked
{
    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    VCAssetCreateOrEdit* vc = [[VCAssetCreateOrEdit alloc] initWithEditAsset:nil
                                                            editBitassetOpts:nil
                                                              result_promise:result_promise];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleAssetOpCreate", @"创建资产") backtitle:kVcDefaultBackTitleName];
    [result_promise then:^id(id dirty) {
        //  刷新UI
        if (dirty && [dirty boolValue]) {
            [self queryMyIssuedAssets];
        }
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右上角新增按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onAddNewAssetClicked)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    _mainTableView.hidden = NO;
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kVcAssetMgrEmptyList", @"未发行任何资产，点击右上角创建资产。")];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    //  查询
    [self queryMyIssuedAssets];
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
    CGFloat baseHeight = 8.0 + 28 * 2 + 24 * 2;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ViewAssetBasicInfoCell* cell = [[ViewAssetBasicInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.showCustomBottomLine = YES;
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        [self _onCellClicked:[_dataArray objectAtIndex:indexPath.row]];
    }];
}

- (void)_onCellClicked:(id)asset
{
    assert(asset);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    NSString* bitasset_data_id = [asset objectForKey:@"bitasset_data_id"];
    id bitasset_data = nil;
    if (bitasset_data_id && ![bitasset_data_id isEqualToString:@""]) {
        bitasset_data = [chainMgr getChainObjectByID:bitasset_data_id];
    }
    
    id list = [[[NSMutableArray array] ruby_apply:^(id ary) {
        //[ary addObject:@{@"type":@(ebaok_view), @"title":NSLocalizedString(@"kVcAssetMgrCellActionViewDetail", @"资产详情")}];//TODO:7.0 暂时去掉
        [ary addObject:@{@"type":@(ebaok_edit), @"title":NSLocalizedString(@"kVcAssetMgrCellActionUpdateAsset", @"更新资产")}];
        if (bitasset_data) {
            [ary addObject:@{@"type":@(ebaok_update_bitasset), @"title":NSLocalizedString(@"kVcAssetMgrCellActionUpdateBitasset", @"更新智能币")}];
            //  允许发行人强制清算
            if ([ModelUtils assetCanGlobalSettle:asset]) {
                [ary addObject:@{@"type":@(ebaok_global_settle), @"title":NSLocalizedString(@"kVcAssetMgrCellActionGlobalSettle", @"全局清算")}];
            }
        } else {
            [ary addObject:@{@"type":@(ebaok_issue), @"title":NSLocalizedString(@"kVcAssetMgrCellActionIssueAsset", @"发行资产")}];
        }
        //  非核心资产，都可以提取手续费池。
        if (![[asset objectForKey:@"id"] isEqualToString:chainMgr.grapheneCoreAssetID]) {
            [ary addObject:@{@"type":@(ebaok_claim_pool), @"title":NSLocalizedString(@"kVcAssetMgrCellActionClaimFeePool", @"提取手续费池")}];
        }
        //  提取资产交易手续费
        [ary addObject:@{@"type":@(ebaok_claim_fees), @"title":NSLocalizedString(@"kVcAssetMgrCellActionClaimMarketFees", @"提取市场手续费")}];
    }] copy];
    
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:nil
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:list
                                                           key:@"title"
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            id item = [list objectAtIndex:buttonIndex];
            
            switch ([[item objectForKey:@"type"] integerValue]) {
                case ebaok_view:
                {
                    VCAssetDetails* vc = [[VCAssetDetails alloc] initWithAssetID:asset[@"id"]
                                                                           asset:asset
                                                                   bitasset_data:bitasset_data
                                                              dynamic_asset_data:[chainMgr getChainObjectByID:[asset objectForKey:@"dynamic_asset_data_id"]]];
                    [self pushViewController:vc vctitle:[NSString stringWithFormat:NSLocalizedString(@"kVcTitleAssetOpViewDetail", @"%@ 详情"),
                                                         asset[@"symbol"]] backtitle:kVcDefaultBackTitleName];
                }
                    break;
                case ebaok_edit:
                {
                    //  查询黑白名单中各种ID依赖。编辑黑白名单列表需要显示名称。
                    id options = [asset objectForKey:@"options"];
                    NSMutableDictionary* ids_hash = [NSMutableDictionary dictionary];
                    for (id oid in [options objectForKey:@"whitelist_authorities"]) {
                        [ids_hash setObject:@YES forKey:oid];
                    }
                    for (id oid in [options objectForKey:@"blacklist_authorities"]) {
                        [ids_hash setObject:@YES forKey:oid];
                    }
                    for (id oid in [options objectForKey:@"whitelist_markets"]) {
                        [ids_hash setObject:@YES forKey:oid];
                    }
                    for (id oid in [options objectForKey:@"blacklist_markets"]) {
                        [ids_hash setObject:@YES forKey:oid];
                    }
                    [VcUtils simpleRequest:self
                                   request:[chainMgr queryAllGrapheneObjects:[ids_hash allKeys]]
                                  callback:^(id result_hash) {
                        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
                        VCAssetCreateOrEdit* vc = [[VCAssetCreateOrEdit alloc] initWithEditAsset:asset
                                                                                editBitassetOpts:nil
                                                                                  result_promise:result_promise];
                        [self pushViewController:vc
                                         vctitle:NSLocalizedString(@"kVcTitleAssetOpUpdateBasic", @"更新资产")
                                       backtitle:kVcDefaultBackTitleName];
                        [result_promise then:^id(id dirty) {
                            //  刷新UI
                            if (dirty && [dirty boolValue]) {
                                [self queryMyIssuedAssets];
                            }
                            return nil;
                        }];
                    }];
                }
                    break;
                case ebaok_update_bitasset:
                {
                    if ([ModelUtils assetHasGlobalSettle:bitasset_data]) {
                        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetMgrActionTipsAlreadyGsCannotUpdateBitasset", @"该资产已经触发全局清算，不可更新智能币。")];
                        return;
                    }
                    
                    //  查询背书资产名称依赖
                    [VcUtils guardGrapheneObjectDependence:self object_ids:bitasset_data[@"options"][@"short_backing_asset"] body:^{
                        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
                        VCAssetCreateOrEdit* vc = [[VCAssetCreateOrEdit alloc] initWithEditAsset:asset
                                                                                editBitassetOpts:bitasset_data
                                                                                  result_promise:result_promise];
                        [self pushViewController:vc
                                         vctitle:NSLocalizedString(@"kVcTitleAssetOpUpdateBitasset", @"更新智能币")
                                       backtitle:kVcDefaultBackTitleName];
                        [result_promise then:^id(id dirty) {
                            //  刷新UI
                            if (dirty && [dirty boolValue]) {
                                [self queryMyIssuedAssets];
                            }
                            return nil;
                        }];
                    }];
                }
                    break;
                case ebaok_issue:
                {
                    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
                    VCAssetOpIssue* vc = [[VCAssetOpIssue alloc] initWithAsset:asset
                                                            dynamic_asset_data:[chainMgr getChainObjectByID:[asset objectForKey:@"dynamic_asset_data_id"]]
                                                                result_promise:result_promise];
                    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleAssetOpIssue", @"发行资产") backtitle:kVcDefaultBackTitleName];
                    [result_promise then:^id(id dirty) {
                        //  刷新UI
                        if (dirty && [dirty boolValue]) {
                            [self queryMyIssuedAssets];
                        }
                        return nil;
                    }];
                }
                    break;
                case ebaok_global_settle:
                {
                    if ([ModelUtils assetHasGlobalSettle:bitasset_data]) {
                        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetMgrActionTipsAlreadyGsCannotGsAgain", @"该资产已经触发全局清算，不可重复执行全局清算操作。")];
                        return;
                    }
                    
                    //  查询背书资产名称依赖
                    [VcUtils guardGrapheneObjectDependence:self object_ids:bitasset_data[@"options"][@"short_backing_asset"] body:^{
                        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
                        VCAssetOpGlobalSettle* vc = [[VCAssetOpGlobalSettle alloc] initWithCurrAsset:asset
                                                                                       bitasset_data:bitasset_data 
                                                                                      result_promise:result_promise];
                        [self pushViewController:vc
                                         vctitle:NSLocalizedString(@"kVcTitleAssetGlobalSettle", @"全局清算")
                                       backtitle:kVcDefaultBackTitleName];
                        [result_promise then:^id(id dirty) {
                            //  刷新UI
                            if (dirty && [dirty boolValue]) {
                                [self queryMyIssuedAssets];
                            }
                            return nil;
                        }];
                    }];
                }
                    break;
                case ebaok_claim_pool:
                {
                    [VcUtils guardGrapheneObjectDependence:self object_ids:[asset objectForKey:@"dynamic_asset_data_id"] body:^{
                        id opArgs = @{
                            @"kOpType":@(ebaok_claim_pool),
                            @"kMsgTips":NSLocalizedString(@"kVcAssetOpClaimFeePoolUiTips", @"【温馨提示】\n资产手续费池可用于抵扣网络广播手续费，如果手续费池余额不足，则不能抵扣。"),
                            @"kMsgAmountPlaceholder":NSLocalizedString(@"kVcAssetOpClaimFeePoolCellPlaceholderAmount", @"请输入提取数量"),
                            @"kMsgBtnName":NSLocalizedString(@"kVcAssetOpClaimFeePoolBtnName", @"提取"),
                            @"kMsgSubmitInputValidAmount":NSLocalizedString(@"kVcAssetOpClaimFeePoolSubmitTipsPleaseInputAmount", @"请输入要提取的资产数量。"),
                            @"kMsgSubmitOK":NSLocalizedString(@"kVcAssetOpClaimFeePoolSubmitTipOK", @"提取成功。")
                        };
                        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
                        VCAssetOpCommon* vc = [[VCAssetOpCommon alloc] initWithCurrAsset:asset
                                                                       full_account_data:nil
                                                                           op_extra_args:opArgs
                                                                          result_promise:result_promise];
                        [self pushViewController:vc
                                         vctitle:NSLocalizedString(@"kVcTitleAssetClaimFeePool", @"提取手续费池")
                                       backtitle:kVcDefaultBackTitleName];
                        [result_promise then:^id(id dirty) {
                            //  刷新UI
                            if (dirty && [dirty boolValue]) {
                                [self queryMyIssuedAssets];
                            }
                            return nil;
                        }];
                    }];
                }
                    break;
                case ebaok_claim_fees:
                {
                    [VcUtils guardGrapheneObjectDependence:self object_ids:[asset objectForKey:@"dynamic_asset_data_id"] body:^{
                        id opArgs = @{
                            @"kOpType":@(ebaok_claim_fees),
                            @"kMsgTips":NSLocalizedString(@"kVcAssetOpClaimMarketFeesUiTips", @"【温馨提示】\n提取资产的市场交易手续费所得收入。"),
                            @"kMsgAmountPlaceholder":NSLocalizedString(@"kVcAssetOpClaimMarketFeesCellPlaceholderAmount", @"请输入提取数量"),
                            @"kMsgBtnName":NSLocalizedString(@"kVcAssetOpClaimMarketFeesBtnName", @"提取"),
                            @"kMsgSubmitInputValidAmount":NSLocalizedString(@"kVcAssetOpClaimMarketFeesSubmitTipsPleaseInputAmount", @"请输入要提取的资产数量。"),
                            @"kMsgSubmitOK":NSLocalizedString(@"kVcAssetOpClaimMarketFeesSubmitTipOK", @"提取成功。")
                        };
                        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
                        VCAssetOpCommon* vc = [[VCAssetOpCommon alloc] initWithCurrAsset:asset
                                                                       full_account_data:nil
                                                                           op_extra_args:opArgs
                                                                          result_promise:result_promise];
                        [self pushViewController:vc
                                         vctitle:NSLocalizedString(@"kVcTitleAssetClaimMarketFees", @"提取市场手续费")
                                       backtitle:kVcDefaultBackTitleName];
                        [result_promise then:^id(id dirty) {
                            //  刷新UI
                            if (dirty && [dirty boolValue]) {
                                [self queryMyIssuedAssets];
                            }
                            return nil;
                        }];
                    }];
                }
                    break;
                default:
                    break;
            }
            
        }
    }];
}

@end
