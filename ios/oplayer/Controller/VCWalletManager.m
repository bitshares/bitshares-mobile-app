//
//  VCWalletManager.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCWalletManager.h"
#import "VCSearchNetwork.h"
#import "VCImportAccount.h"
#import "VCBackupWallet.h"
#import "BitsharesClientManager.h"
#import "ViewWalletAccountInfoCell.h"
#import "OrgUtils.h"
#import "ScheduleManager.h"
#import "MyPopviewManager.h"

enum
{
    kVcAccountList = 0,             //  账号列表
    kVcBtnImportAccount,            //  导入账号
    kVcBtnBackupWallet,             //  备份钱包
    
    kVcMax
};

@interface VCWalletManager ()
{
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    ViewBlockLabel*         _btnImportAccount;
    ViewBlockLabel*         _btnBackupWallet;
}

@end

@implementation VCWalletManager

-(void)dealloc
{
    _btnImportAccount = nil;
    _btnBackupWallet = nil;
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
    }
    return self;
}

- (void)queryAllAccountInfos:(NSArray*)account_name_list
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    [[[api exec:@"lookup_account_names" params:@[account_name_list]] then:(^id(id data_array) {
        [self hideBlockView];
        [[ChainObjectManager sharedChainObjectManager] updateGrapheneObjectCache:data_array];
        [self onQueryAllAccountInfosResponse:data_array];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

- (void)onQueryAllAccountInfosResponse:(id)data_array
{
    assert(data_array);
    //  本地钱包文件快捷查询信息
    [[AppCacheManager sharedAppCacheManager] setWalletAccountDataList:data_array];
    //  更新列表数据
    [_dataArray removeAllObjects];
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    BOOL isLocked = [walletMgr isLocked];
    id currentAccoutName = [walletMgr getWalletAccountName];
    for (id account_info in data_array) {
        id name = [account_info objectForKey:@"name"];
        assert(name);
        BOOL isCurrent = [currentAccoutName isEqualToString:name];
        if (isLocked){
            //  锁定状态没法获取权限
            [_dataArray addObject:@{@"name":name, @"current":@(isCurrent), @"raw_json":account_info, @"locked":@(isLocked)}];
        }else{
            //  解锁状态下判断各种权限判断。
            id owner = [account_info objectForKey:@"owner"];
            id active = [account_info objectForKey:@"active"];
            id memo_key = [[account_info objectForKey:@"options"] objectForKey:@"memo_key"];
            
            EAccountPermissionStatus owner_status = [walletMgr calcPermissionStatus:owner];
            EAccountPermissionStatus active_status = [walletMgr calcPermissionStatus:active];
            BOOL haveMemoPermission = memo_key && [walletMgr havePrivateKey:memo_key];
            
            [_dataArray addObject:@{@"name":name, @"current":@(isCurrent), @"raw_json":account_info, @"locked":@(isLocked),
                                    @"owner_status":@(owner_status),
                                    @"active_status":@(active_status),
                                    @"haveMemoPermission":@(haveMemoPermission)}];
        }
    }
    //  按照 current 字段降序排列。即：当前账号排列在最前。
    [_dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [[obj2 objectForKey:@"current"] intValue] - [[obj1 objectForKey:@"current"] intValue];
    })];
    [_mainTableView reloadData];
}

- (void)refreshUI
{
    id ary = [NSMutableArray array];
    for (id item in _dataArray) {
        [ary addObject:[item objectForKey:@"raw_json"]];
    }
    [self onQueryAllAccountInfosResponse:ary];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化数据
    id account_list = [[WalletManager sharedWalletManager] getWalletAccountNameList];
    assert([account_list count] > 0);
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 行为按钮
    _btnImportAccount = [self createCellLableButton:NSLocalizedString(@"kWalletBtnImportMoreAccount", @"导入更多账号")];
    
    //  UI - 备份按钮
    _btnBackupWallet = [self createCellLableButton:NSLocalizedString(@"kWalletBtnBackup", @"备份钱包")];
    UIColor* backColor = [ThemeManager sharedThemeManager].textColorGray;
    _btnBackupWallet.layer.borderColor = backColor.CGColor;
    _btnBackupWallet.layer.backgroundColor = backColor.CGColor;
    
    //  查询
    [self queryAllAccountInfos:account_list];
}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([TempManager sharedTempManager].importToWalletDirty){
        [TempManager sharedTempManager].importToWalletDirty = NO;
        id account_list = [[WalletManager sharedWalletManager] getWalletAccountNameList];
        assert([account_list count] > 0);
        [self queryAllAccountInfos:account_list];
    }
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcAccountList:
            return [_dataArray count];
        default:
            break;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcAccountList:
        {
            //  权限
            if (![[WalletManager sharedWalletManager] isLocked]){
                CGFloat baseHeight = 8.0 + 28 * 2;
                return baseHeight;
            }else{
                return tableView.rowHeight;
            }
        }
            break;
            
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
    switch (indexPath.section) {
        case kVcAccountList:
        {
            static NSString* identify = @"id_wallet_account_cell";
            ViewWalletAccountInfoCell* cell = (ViewWalletAccountInfoCell *)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewWalletAccountInfoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.backgroundColor = [UIColor clearColor];
            }
            cell.showCustomBottomLine = YES;
            [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
            return cell;
        }
            break;
        case kVcBtnImportAccount:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnImportAccount cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcBtnBackupWallet:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnBackupWallet cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    assert(false);
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcAccountList:
                {
                    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                        if (unlocked){
                            id item = [_dataArray objectAtIndex:indexPath.row];
                            [self refreshUI];
                            [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                                               message:nil
                                                                                cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                                                 items:@[NSLocalizedString(@"kWalletBtnSetCurrent", @"设置为当前账号"),  NSLocalizedString(@"kWalletBtnRemoveAccount", @"删除该账号")]
                                                                              callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
                             {
                                 if (buttonIndex != cancelIndex){
                                     if (buttonIndex == 0){
                                         if ([[item objectForKey:@"current"] boolValue]){
                                             [OrgUtils makeToast:NSLocalizedString(@"kWalletTipsSwitchCurrentAccountDone", @"切换当前账号完毕。")];
                                         }else{
                                            [self onSetCurrentAccountClicked:[item objectForKey:@"name"]];
                                         }
                                     }else if (buttonIndex == 1){
                                         [self onRemoveAccountClicked:[item objectForKey:@"name"]];
                                     }else{
                                         assert(false);
                                     }
                                 }
                             }];
                        }
                    }];
                }
                break;
            case kVcBtnImportAccount:
            {
                [self onImportMoreAccountClicked];
            }
                break;
            case kVcBtnBackupWallet:
            {
                [self onBackupWalletClicked];
            }
                break;
            default:
                break;
        }
    }];
}

/**
 *  事件 - 设置当前账号
 */
- (void)onSetCurrentAccountClicked:(NSString*)accountName
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中…")];
    [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:accountName] then:(^id(id full_data) {
        [self hideBlockView];
        //  设置当前账号
        id full_wallet_bin = [[WalletManager sharedWalletManager] walletBinImportAccount:accountName privateKeyWifList:nil];
        assert(full_wallet_bin);
        [[AppCacheManager sharedAppCacheManager] updateWalletBin:full_wallet_bin];
        [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:YES];
        [[AppCacheManager sharedAppCacheManager] setWalletCurrentAccount:accountName
                                                         fullAccountData:full_data];
        //  重新解锁（即刷新解锁后的账号信息）。
        id unlockInfos = [[WalletManager sharedWalletManager] reUnlock];
        assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
        [self refreshUI];
        [OrgUtils makeToast:NSLocalizedString(@"kWalletTipsSwitchCurrentAccountDone", @"切换当前账号完毕。")];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

/**
 *  事件 - 删除该账号
 */
- (void)onRemoveAccountClicked:(NSString*)accountName
{
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    
    //  即将移除的账号
    id account_data_hash = [walletMgr getAllAccountDataHash:YES];
    if ([account_data_hash count] <= 1){
        [OrgUtils makeToast:NSLocalizedString(@"kWalletTipsRemoveKeepOne", @"钱包中至少保留一个账号。")];
        return;
    }
    
    id account_data = [account_data_hash objectForKey:accountName];
    assert(account_data);
    
    //  如果删除当前账号（那么删除之后需要设置新的当前账号）
    NSString* newCurrentName = nil;
    BOOL deleteCurrentAccount = [[walletMgr getWalletAccountName] isEqualToString:accountName];
    if (deleteCurrentAccount){
        for (id item in _dataArray) {
            id name = [item objectForKey:@"name"];
            assert(name);
            if (![name isEqualToString:accountName]){
                newCurrentName = name;
                break;
            }
        }
    }
    
    //  要移除的账号的所有公钥
    NSMutableDictionary* remove_account_pubkeys = [WalletManager getAllPublicKeyFromAccountData:account_data result:nil];
    
    //  其他账号的所有公钥
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    for (id name in account_data_hash) {
        if ([name isEqualToString:accountName]){
            continue;
        }
        id account = [account_data_hash objectForKey:name];
        assert(account);
        [WalletManager getAllPublicKeyFromAccountData:account result:result];
    }
    
    //  筛选最终要移除的公钥：remove_account_pubkeys - result
    BOOL will_delete_privatekey = NO;
    NSMutableArray* final_remove_pubkey = [NSMutableArray array];
    for (id pubkey in remove_account_pubkeys) {
        if (![[result objectForKey:pubkey] boolValue]){
            [final_remove_pubkey addObject:pubkey];
            if ([walletMgr havePrivateKey:pubkey]){
                will_delete_privatekey = YES;
            }
        }
    }
    
    //  删除
    if (will_delete_privatekey){
        [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kWalletTipsWarmMessage", @"删除账号将会连同账号关联的私钥信息一起删除，请确认您已经做好备份。是否继续删除？")
                                                               withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                              completion:^(NSInteger buttonIndex)
         {
             if (buttonIndex == 1)
             {
                 [self removeAccountCore:accountName pubkeyList:[final_remove_pubkey copy] newCurrentName:newCurrentName];
             }
         }];
    }else{
        [self removeAccountCore:accountName pubkeyList:[final_remove_pubkey copy] newCurrentName:newCurrentName];
    }
}

/**
 *  移除账号核心。
 */
- (void)removeAccountCore:(NSString*)accountName pubkeyList:(NSArray*)pubkeyList newCurrentName:(NSString*)newCurrentName
{
    if (newCurrentName){
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中…")];
        [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:newCurrentName] then:(^id(id full_data) {
            [self hideBlockView];
            [self removeAccountCore2:accountName pubkeyList:pubkeyList newFullAccountData:full_data];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            return nil;
        })];
    }else{
        [self removeAccountCore2:accountName pubkeyList:pubkeyList newFullAccountData:nil];
    }
}

- (void)removeAccountCore2:(NSString*)accountName pubkeyList:(NSArray*)pubkeyList newFullAccountData:(NSDictionary*)newFullAccountData
{
    //  移除账号核心
    id full_wallet_bin = [[WalletManager sharedWalletManager] walletBinRemoveAccount:accountName pubkeyList:pubkeyList];
    assert(full_wallet_bin);
    [[AppCacheManager sharedAppCacheManager] updateWalletBin:full_wallet_bin];
    [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:YES];
    //  如果删除了当前账号，需要重新设置。
    if (newFullAccountData){
        [[AppCacheManager sharedAppCacheManager] setWalletCurrentAccount:newFullAccountData[@"account"][@"name"]
                                                         fullAccountData:newFullAccountData];
    }
    
    //  重新解锁（即刷新解锁后的账号信息）。
    id unlockInfos = [[WalletManager sharedWalletManager] reUnlock];
    assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
    
    //  提示
    [OrgUtils makeToast:NSLocalizedString(@"kWalletTipsRemoveAccountDone", @"账号已删除。")];
    
    //  重新查询&刷新界面
    id account_list = [[WalletManager sharedWalletManager] getWalletAccountNameList];
    assert([account_list count] > 0);
    [self queryAllAccountInfos:account_list];
}

/**
 *  事件 - 备份钱包按钮点击
 */
- (void)onBackupWalletClicked
{
    VCBackupWallet* vc = [[VCBackupWallet alloc] init];
    vc.title = NSLocalizedString(@"kVcTitleBackupWallet", @"备份钱包");
    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

/**
 *  事件 - 点击导入账号
 */
- (void)onImportMoreAccountClicked
{
    NSInteger wallet_import_account_max_num = [[[ChainObjectManager sharedChainObjectManager] getDefaultParameters][@"wallet_import_account_max_num"] integerValue];
    if ([_dataArray count] >= wallet_import_account_max_num){
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kWalletTipsMaxImportAccount", @"最多只能导入 %@ 个账号。"), @(wallet_import_account_max_num)]];
        return;
    }
    
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            //  解锁完毕刷新UI
            [self refreshUI];
            [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                               message:nil
                                                                cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                                 items:@[NSLocalizedString(@"kWalletBtnImportMultiSignedAccount", @"导入多签账号"), NSLocalizedString(@"kWalletBtnImportNormalAccount", @"导入普通账号")]
                                                              callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
             {
                 if (buttonIndex != cancelIndex){
                     if (buttonIndex == 0){
                         [self onImportMultiSignAccountClicked];
                     }else if (buttonIndex ==1){
                         [self onImportNormalAccountClicked];
                     }else{
                         assert(false);
                     }
                 }
             }];
        }
    }];
}

/**
 *  事件 - 点击导入多签账号
 */
- (void)onImportMultiSignAccountClicked
{
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAccount callback:^(id account_info) {
        if (account_info){
            WalletManager* walletMgr = [WalletManager sharedWalletManager];
            NSString* accountName = account_info[@"name"];
            if ([[walletMgr getAllAccountDataHash:YES] objectForKey:accountName]){
                [OrgUtils makeToast:NSLocalizedString(@"kWalletTipsDuplicated", @"账号已经存在，不用重复导入。")];
            }else{
                //  查询要导入的账号信息。
                [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中…")];
                [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:accountName] then:(^id(id full_data) {
                    [self hideBlockView];
                    assert(full_data);
                    id account = [full_data objectForKey:@"account"];
                    assert(account);
                    if ([WalletManager isMultiSignAccount:account]){
                        //  导入账号到钱包BIN文件中
                        id full_wallet_bin = [walletMgr walletBinImportAccount:accountName privateKeyWifList:nil];
                        assert(full_wallet_bin);
                        [[AppCacheManager sharedAppCacheManager] updateWalletBin:full_wallet_bin];
                        [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:YES];
                        //  重新解锁（即刷新解锁后的账号信息）。
                        id unlockInfos = [[WalletManager sharedWalletManager] reUnlock];
                        assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
                        //  提示信息
                        [OrgUtils makeToast:NSLocalizedString(@"kWalletImportSuccess", @"导入完成")];
                        //  重新查询&刷新界面
                        id account_list = [[WalletManager sharedWalletManager] getWalletAccountNameList];
                        assert([account_list count] > 0);
                        [self queryAllAccountInfos:account_list];
                    }else{
                        //  非多签账号，不支持导入。
                        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kWalletTipsNotMultiSignAccount", @"%@ 不是多签账号，不能导入。"), accountName]];
                    }
                    return nil;
                })] catch:(^id(id error) {
                    [self hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
                    return nil;
                })];
            }
        }
    }];
    [self pushViewController:vc
                     vctitle:NSLocalizedString(@"kVcTitleSelectMultiSigndAccount", @"选择多签管理账号")
                   backtitle:kVcDefaultBackTitleName];
}

/**
 *  事件 - 点击导入普通账号
 */
- (void)onImportNormalAccountClicked
{
    VCImportAccount* vc = [[VCImportAccount alloc] init];
    vc.checkActivePermission = NO;
    vc.title = NSLocalizedString(@"kVcTitleImportAccount", @"导入帐号");
    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

@end
