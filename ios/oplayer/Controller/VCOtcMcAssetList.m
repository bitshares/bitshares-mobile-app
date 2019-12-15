//
//  VCOtcMcAssetList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcAssetList.h"
#import "ViewOtcMcAssetInfoCell.h"
#import "OtcManager.h"
#import "VCOtcMcAssetTransfer.h"

@interface VCOtcMcAssetList ()
{
    NSDictionary*           _auth_info;
    EOtcUserType            _user_type;
    NSDictionary*           _merchant_detail;
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCOtcMcAssetList

-(void)dealloc
{
    _auth_info = nil;
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithAuthInfo:(id)auth_info user_type:(EOtcUserType)user_type merchant_detail:(id)merchant_detail
{
    self = [super init];
    if (self) {
        _auth_info = auth_info;
        _user_type = user_type;
        _merchant_detail = merchant_detail;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onQueryOtcAssetsResponsed:(id)merchantAssetList chainAssets:(id)chainAssets
{
    [_dataArray removeAllObjects];
    
    if (merchantAssetList && [merchantAssetList count] > 0) {
        
        NSMutableDictionary* chain_asset_map = [NSMutableDictionary dictionary];
        if (chainAssets) {
            for (id asset in chainAssets) {
                id symbol = [asset objectForKey:@"symbol"];
                if (symbol) {
                    [chain_asset_map setObject:asset forKey:symbol];
                }
            }
        }
        
        for (id item in merchantAssetList) {
            id chain_asset = [chain_asset_map objectForKey:[item objectForKey:@"assetSymbol"]];
            assert(chain_asset);
            //  OTC服务器数据错误则可能导致链上资产不存在。
            if (chain_asset) {
                id mitem = [item mutableCopy];
                [mitem setObject:@([[chain_asset objectForKey:@"precision"] integerValue]) forKey:@"kExtPrecision"];
                [mitem setObject:chain_asset forKey:@"kExtChainAsset"];
                [_dataArray addObject:mitem];
            }
        }
    }
    
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

- (void)queryOtcAssets
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[otc queryMerchantOtcAsset:[otc getCurrentBtsAccount]] then:^id(id responsed) {
        id merchantAssetList = [responsed objectForKey:@"data"];
        NSMutableArray* assetSymbolList = [NSMutableArray array];
        if (merchantAssetList && [merchantAssetList isKindOfClass:[NSArray class]] && [merchantAssetList count] > 0) {
            for (id item in merchantAssetList) {
                [assetSymbolList addObject:[item objectForKey:@"assetSymbol"]];
            }
        }
        if ([assetSymbolList count] > 0) {
            //  查询资产信息和个人账号余额信息
            [[[[ChainObjectManager sharedChainObjectManager] queryAssetDataList:assetSymbolList] then:^id(id chain_assets) {
                [self hideBlockView];
                [self onQueryOtcAssetsResponsed:merchantAssetList chainAssets:chain_assets];
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
                [self onQueryOtcAssetsResponsed:nil chainAssets:nil];
                return nil;
            }];
        } else {
            [self hideBlockView];
            [self onQueryOtcAssetsResponsed:nil chainAssets:nil];
        }
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    _mainTableView.hidden = NO;
    
    //  UI - 空 TODO:2.9
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何资产"];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    //  查询
    [self queryOtcAssets];
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
    ViewOtcMcAssetInfoCell* cell = [[ViewOtcMcAssetInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil vc:self];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
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

- (void)onButtonClicked_TransferIn:(UIButton*)button
{
    id item = [_dataArray objectAtIndex:button.tag];
    [self gotoOtcMcAssetTransfer:YES curr_merchant_asset:item];
}

- (void)onButtonClicked_TransferOut:(UIButton*)button
{
    id item = [_dataArray objectAtIndex:button.tag];
    [self gotoOtcMcAssetTransfer:NO curr_merchant_asset:item];
}

- (void)gotoOtcMcAssetTransfer:(BOOL)transfer_in curr_merchant_asset:(id)curr_merchant_asset
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    id p1 = [[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:[[OtcManager sharedOtcManager] getCurrentBtsAccount]];
    [[p1 then:^id(id full_account_data) {
        [self hideBlockView];
        //  转到划转界面
        //  TODO:2.9 lang
        VCBase* vc = [[VCOtcMcAssetTransfer alloc] initWithAuthInfo:_auth_info
                                                          user_type:_user_type
                                                    merchant_detail:_merchant_detail
                                                         asset_list:_dataArray
                                                curr_merchant_asset:curr_merchant_asset
                                                  full_account_data:full_account_data
                                                        transfer_in:transfer_in];
        [self pushViewController:vc vctitle:@"划转" backtitle:kVcDefaultBackTitleName];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

@end
