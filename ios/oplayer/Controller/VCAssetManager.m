//
//  VCAssetManager.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetManager.h"
#import "ViewAssetBasicInfoCell.h"

#import "VCAssetCreate.h"
#import "VCAssetDetails.h"
#import "VCAssetOpIssue.h"

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
        //  账号名和预测市场等信息允许查询缓存
        [bitasset_data_id_list addObjectsFromArray:[issuerHash allKeys]];
        id p1 = [chainMgr queryAllGrapheneObjects:bitasset_data_id_list];
        //  供应量等数据跳过缓存
        id p2 = [chainMgr queryAllGrapheneObjectsSkipCache:dynamic_asset_data_id_list];
        return [[WsPromise all:@[p1, p2]] then:^id(id data) {
            [self hideBlockView];
            [self onQueryMyIssuedAssetsResponsed:data_array];
            return nil;
        }];
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

- (void)onAddNewAssetClicked
{
    //  TODO:4.0 lang
    VCAssetCreate* vc = [[VCAssetCreate alloc] init];
    [self pushViewController:vc vctitle:@"创建资产" backtitle:kVcDefaultBackTitleName];
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
    
    //  TODO:4.0 lang
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"尚未发行任何资产。"];
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

    //  TODO:4.0 lang
    id list = [[[NSMutableArray array] ruby_apply:^(id ary) {
        [ary addObject:@{@"type":@(ebaok_view), @"title":@"详情"}];
        [ary addObject:@{@"type":@(ebaok_edit), @"title":@"编辑"}];
        if (!bitasset_data) {
            [ary addObject:@{@"type":@(ebaok_issue), @"title":@"发行"}];
        }
    }] copy];
    
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:NSLocalizedString(@"kOtcAdSwitchAssetTips", @"请选择要交易的资产")
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
                    //  TODO:4.0 lang
                    [self pushViewController:vc vctitle:[NSString stringWithFormat:@"%@ 详情", asset[@"symbol"]] backtitle:kVcDefaultBackTitleName];
                }
                    break;
                case ebaok_edit:
                {
                    //  TODO:4.0
                }
                    break;
                case ebaok_issue:
                {
                    VCAssetOpIssue* vc = [[VCAssetOpIssue alloc] initWithAsset:asset
                                                            dynamic_asset_data:[chainMgr getChainObjectByID:[asset objectForKey:@"dynamic_asset_data_id"]]];
                    [self pushViewController:vc vctitle:@"发行资产" backtitle:kVcDefaultBackTitleName];
                }
                    break;
                default:
                    break;
            }
            
        }
    }];
}

@end
