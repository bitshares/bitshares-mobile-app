//
//  VCNewAccountPasswordConfirm.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
//#import <QuartzCore/QuartzCore.h>

#import "VCNewAccountPasswordConfirm.h"
#import "ViewAdvTextFieldCell.h"
#import "VCImportAccount.h"

enum
{
    kModifyAllPermissions = 0,  //  修改【账号权限】和【资金权限】
    kModifyOnlyActivePermission,//  仅修改【资金权限】
    kModifyOnlyOwnerPermission, //  仅修改【账号权限】
};

enum
{
    kVcAccountName = 0,
    kVcConfirmPassword,
    kVcModifyRange,             //  修改范围（仅修改密码时存在，注册账号则不存在。）
    kVcSubmit,
    
    kVcMax,
};

@interface VCNewAccountPasswordConfirm ()
{
    NSString*                       _new_account_name;      //  新账号名，注册时传递，修改密码则为nil。
    
    NSString*                       _curr_password;
    EBitsharesAccountPasswordLang   _curr_passlang;
    
    UITableView *                   _mainTableView;
    
    ViewAdvTextFieldCell*           _cell_account;
    ViewAdvTextFieldCell*           _cell_confirm_password;
    
    ViewBlockLabel*                 _lbSubmit;
    
    NSArray*                        _secTypeArray;          //  段类型数组
    NSInteger                       _curr_modify_range;
}

@end

@implementation VCNewAccountPasswordConfirm

-(void)dealloc
{
    _lbSubmit = nil;
    
    _cell_account = nil;
    _cell_confirm_password = nil;
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    
    _curr_password = nil;
    _new_account_name = nil;
    _secTypeArray = nil;
}

- (id)initWithPassword:(NSString*)password passlang:(EBitsharesAccountPasswordLang)passlang new_account_name:(NSString*)new_account_name
{
    self = [super init];
    if (self) {
        _curr_password = [password copy];
        _curr_passlang = passlang;
        _new_account_name = [new_account_name copy];
        _curr_modify_range = kModifyAllPermissions;
    }
    return self;
}

/*
 *  (private) 是否是注册账号
 */
- (BOOL)isRegisterAccount
{
    return _new_account_name != nil;
}

- (void)onBtnAgreementClicked
{
    //  TODO:2.9 url
    [self gotoWebView:[NSString stringWithFormat:@"%@%@", @"https://btspp.io/",
                       NSLocalizedString(@"userAgreementHtmlFileName", @"agreement html file")]
                title:NSLocalizedString(@"kVcTitleAgreement", @"用户协议和服务条款")];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    if ([self isRegisterAccount]) {
        [self showRightButton:NSLocalizedString(@"kBtnAppAgreement", @"服务条款") action:@selector(onBtnAgreementClicked)];
        
        _secTypeArray = @[
            @(kVcAccountName),
            @(kVcConfirmPassword),
            @(kVcSubmit)
        ];
        
        _cell_account = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kEditPasswordCellTItleYourNewAccountName", @"您的账号")
                                                        placeholder:@""];
        _cell_account.mainTextfield.text = _new_account_name;
    } else {
        _secTypeArray = @[
            @(kVcAccountName),
            @(kVcConfirmPassword),
            @(kVcModifyRange),
            @(kVcSubmit)
        ];
        
        _cell_account = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kEditPasswordCellTitleCurrAccountName", @"当前账号")
                                                        placeholder:@""];
        assert([[WalletManager sharedWalletManager] isWalletExist]);
        _cell_account.mainTextfield.text = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"][@"name"];
    }
    _cell_account.mainTextfield.userInteractionEnabled = NO;
    
    _cell_confirm_password = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kEditPasswordCellTitleVerifyPassword", @"验证密码")
                                                             placeholder:NSLocalizedString(@"kEditPasswordCellPlaceholderVerifyPassword", @"请输入上一步生成的密码")];
        //  测试
//    #ifdef DEBUG
//        _cell_confirm_password.mainTextfield.text = _curr_password;
//    #endif  //  DEBUG
    
    //  REMARK：英文用密码输入框，中文用明文输入框。
    //  TODO:5.0 为英文加密码框和眼睛？
    //    _cell_confirm_password.mainTextfield.secureTextEntry = _curr_passlang == ebap_lang_en;
    
    //  UI - 主列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    if ([self isRegisterAccount]) {
        _lbSubmit = [self createCellLableButton:NSLocalizedString(@"kLoginCellBtnAgreeAndReg", @"同意协议并注册")];
    } else {
        _lbSubmit = [self createCellLableButton:NSLocalizedString(@"kEditPasswordBtnSubmmit", @"修改")];
    }
}

- (void)endInput
{
    [super endInput];
    [_cell_account endInput];
    [_cell_confirm_password endInput];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endInput];
}

/*
 *  (private) 通过水龙头注册账号
 */
- (void)onRegisterAccountCore
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  1、生成各种权限公钥。
    //  REMARK：这里memo单独分类出来，避免和active权限相同。
    id seed_owner = [NSString stringWithFormat:@"%@owner%@", _new_account_name, _curr_password];
    id seed_active = [NSString stringWithFormat:@"%@active%@", _new_account_name, _curr_password];
    id seed_memo = [NSString stringWithFormat:@"%@memo%@", _new_account_name, _curr_password];
    id owner_key = [OrgUtils genBtsAddressFromPrivateKeySeed:seed_owner];
    id active_key = [OrgUtils genBtsAddressFromPrivateKeySeed:seed_active];
    id memo_key = [OrgUtils genBtsAddressFromPrivateKeySeed:seed_memo];
    
    //  2、调用水龙头API注册
    [[OrgUtils asyncCreateAccountFromFaucet:_new_account_name
                                      owner:owner_key
                                     active:active_key
                                       memo:memo_key
                                    refcode:@""
                                       chid:kAppChannelID] then:(^id(id err_msg) {
        [self hideBlockView];
        
        if (err_msg && [err_msg isKindOfClass:[NSString class]]) {
            //  水龙头注册失败。
            [OrgUtils logEvents:@"faucetFailed" params:@{@"err":err_msg}];
            [OrgUtils makeToast:err_msg];
            return nil;
        } else {
            //  注册成功，直接重新登录。
            [OrgUtils logEvents:@"registerEvent" params:@{@"mode":@(kwmPasswordOnlyMode), @"desc":@"password"}];
            [[UIAlertViewManager sharedUIAlertViewManager] showMessage:NSLocalizedString(@"kLoginTipsRegFullOK", @"注册成功。")
                                                             withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                            completion:^(NSInteger buttonIndex) {
                //  转到登录界面。
                VCImportAccount* vc = [[VCImportAccount alloc] init];
                [self clearPushViewController:vc
                                      vctitle:NSLocalizedString(@"kVcTitleLogin", @"登录")
                                    backtitle:kVcDefaultBackTitleName];
            }];
        }
        return nil;
    })];
}

/*
 *  (private) 确定添加
 */
- (void)onSubmitClicked
{
    [self endInput];
    
    //  校验参数
    NSString* confirm_password = [NSString trim:_cell_confirm_password.mainTextfield.text];
    if (!confirm_password || ![confirm_password isEqualToString:_curr_password]){
        [OrgUtils makeToast:NSLocalizedString(@"kEditPasswordSubmitTipsConfirmFailed", @"密码验证失败，请重新输入。")];
        return;
    }
    
    if ([self isRegisterAccount]) {
        //  注册：新账号
        [self onRegisterAccountCore];
    } else {
        //  修改密码：先查询账号数据
        [[[self queryNewestAccountData] then:^id(id new_account_data) {
            //  二次确认
            [self _gotoAskUpdateAccount:new_account_data];
            return nil;
        }] catch:^id(id error) {
            [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            return nil;
        }];
    }
}

/*
 *  (private) 查询最新账号数据（如果需要更新memokey则从链上查询）
 */
- (WsPromise*)queryNewestAccountData
{
    id account_data = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(account_data);
    
    if (_curr_modify_range == kModifyAllPermissions || _curr_modify_range == kModifyOnlyActivePermission) {
        //  修改所有权限 or 修改资金权限的情况下，需要修改备注权限一起。则需要查询最新的账号数据。
        return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[ChainObjectManager sharedChainObjectManager] queryAccountData:account_data[@"id"]] then:(^id(id newestAccountData) {
                [self hideBlockView];
                if (newestAccountData && [newestAccountData objectForKey:@"id"] && [newestAccountData objectForKey:@"name"]) {
                    //  返回最新数据
                    resolve(newestAccountData);
                } else {
                    //  查询账号失败，返回nil。
                    reject(@NO);
                }
                return nil;
            })];
        }];
    } else {
        //  仅修改账号权限，则不用修改备注。不用获取最新账号数据。
        return [WsPromise resolve:account_data];
    }
}

/**
 *  (private) 请求二次确认修改账号权限信息。
 */
- (void)_gotoAskUpdateAccount:(id)new_account_data
{
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:NSLocalizedString(@"kEditPasswordSubmitSecondTipsAsk", @"请再次确认您已经保存好新的密码并且保存到了安全的地方。是否继续修改密码？")
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            // 解锁钱包or账号
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked){
                    [self _submitUpdateAccountCore:new_account_data];
                }
            }];
        }
    }];
}

/**
 *  (private) 修改权限核心
 */
- (void)_submitUpdateAccountCore:(id)new_account_data
{
    assert(new_account_data);
    id uid = new_account_data[@"id"];
    id account_name = new_account_data[@"name"];
    
    BOOL using_owner_authority = NO;
    NSMutableArray* new_private_wif_list = [NSMutableArray array];
    
    //  构造OPDATA
    id op_data = [NSMutableDictionary dictionary];
    op_data[@"fee"] = @{@"amount":@0, @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID};
    op_data[@"account"] = uid;
    
    //  修改资金权限 和 备注权限
    if (_curr_modify_range == kModifyAllPermissions || _curr_modify_range == kModifyOnlyActivePermission) {
        //  生成 active 公私钥。
        id seed_active = [NSString stringWithFormat:@"%@active%@", account_name, _curr_password];
        id public_key_active = [OrgUtils genBtsAddressFromPrivateKeySeed:seed_active];
        
        //  修改资金权限
        id authority_active = @{
            @"weight_threshold":@(1),
            @"account_auths":@[],
            @"key_auths":@[@[public_key_active, @1]],
            @"address_auths":@[],
        };
        [op_data setObject:authority_active forKey:@"active"];
        
        //  修改备注权限
        id account_options = [new_account_data objectForKey:@"options"];
        id new_options = @{
            @"memo_key":public_key_active,
            @"voting_account":[account_options objectForKey:@"voting_account"],
            @"num_witness":[account_options objectForKey:@"num_witness"],
            @"num_committee":[account_options objectForKey:@"num_committee"],
            @"votes":[account_options objectForKey:@"votes"]
        };
        [op_data setObject:new_options forKey:@"new_options"];
        
        //  保存资金权限私钥
        [new_private_wif_list addObject:[OrgUtils genBtsWifPrivateKey:seed_active]];
    }
    
    //  修改账户权限
    if (_curr_modify_range == kModifyAllPermissions || _curr_modify_range == kModifyOnlyOwnerPermission) {
        //  签名需要权限标记
        using_owner_authority = YES;
        
        //  生成 owner 公私钥。
        id seed_owner = [NSString stringWithFormat:@"%@owner%@", account_name, _curr_password];
        id public_key_owner = [OrgUtils genBtsAddressFromPrivateKeySeed:seed_owner];
        
        //  修改账户权限
        id authority_owner = @{
            @"weight_threshold":@(1),
            @"account_auths":@[],
            @"key_auths":@[@[public_key_owner, @1]],
            @"address_auths":@[],
        };
        [op_data setObject:authority_owner forKey:@"owner"];
        
        //  保存账户权限私钥
        [new_private_wif_list addObject:[OrgUtils genBtsWifPrivateKey:seed_owner]];
    }
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_account_update
                     using_owner_authority:using_owner_authority invoke_proposal_callback:NO
                                    opdata:op_data
                                 opaccount:new_account_data
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] accountUpdate:op_data] then:(^id(id data) {
            if ([[WalletManager sharedWalletManager] isPasswordMode]) {
                //  密码模式：修改权限之后直接退出重新登录。
                [self hideBlockView];
                //  [统计]
                [OrgUtils logEvents:@"txUpdateAccountPermissionFullOK" params:@{@"account":uid, @"mode":@"password"}];
                [[UIAlertViewManager sharedUIAlertViewManager] showMessage:NSLocalizedString(@"kVcPermissionEditSubmitOkRelogin", @"权限修改成功，请重新登录。")
                                                                 withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                                completion:^(NSInteger buttonIndex) {
                    //  注销
                    [[WalletManager sharedWalletManager] processLogout];
                    //  转到重新登录界面。
                    VCImportAccount* vc = [[VCImportAccount alloc] init];
                    [self clearPushViewController:vc
                                          vctitle:NSLocalizedString(@"kVcTitleLogin", @"登录")
                                        backtitle:kVcDefaultBackTitleName];
                }];
            } else {
                //  导入新密码对应私钥到当前钱包中
                WalletManager* walletMgr = [WalletManager sharedWalletManager];
                AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
                id full_wallet_bin = [walletMgr walletBinImportAccount:nil
                                                     privateKeyWifList:[new_private_wif_list copy]];
                assert(full_wallet_bin);
                [pAppCache updateWalletBin:full_wallet_bin];
                [pAppCache autoBackupWalletToWebdir:NO];
                id unlockInfos = [walletMgr reUnlock];
                assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
                
                //  钱包模式：修改权限之后刷新账号信息即可。（可能当前账号不在拥有完整的active权限。）
                [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:uid] then:(^id(id full_data) {
                    [self hideBlockView];
                    //  更新账号信息
                    [pAppCache updateWalletAccountInfo:full_data];
                    //  [统计]
                    [OrgUtils logEvents:@"txUpdateAccountPermissionFullOK" params:@{@"account":uid, @"mode":@"wallet"}];
                    //  提示并退出
                    [[UIAlertViewManager sharedUIAlertViewManager] showMessage:NSLocalizedString(@"kVcPermissionEditSubmitOK02", @"修改权限成功。")
                                                                     withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                                    completion:^(NSInteger buttonIndex) {
                        //  直接返回最外层
                        [self.navigationController popToRootViewControllerAnimated:YES];
                    }];
                    return nil;
                })] catch:(^id(id error) {
                    [self hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionEditSubmitOKAndRelaunchApp", @"修改权限成功，但刷新账号信息失败，请退出重新启动APP。")];
                    //  [统计]
                    [OrgUtils logEvents:@"txUpdateAccountPermissionOK" params:@{@"account":uid, @"mode":@"wallet"}];
                    return nil;
                })];
            }
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txUpdateAccountPermissionFailed" params:@{@"account":uid}];
            return nil;
        })];
    }];
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self endInput];
    return YES;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_secTypeArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([[_secTypeArray objectAtIndex:indexPath.section] integerValue]) {
        case kVcAccountName:
            return _cell_account.cellHeight;
        case kVcConfirmPassword:
            return _cell_confirm_password.cellHeight;
        default:
            break;
    }
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
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
    switch ([[_secTypeArray objectAtIndex:indexPath.section] integerValue]) {
        case kVcAccountName:
            return _cell_account;
            
        case kVcConfirmPassword:
            return _cell_confirm_password;
            
        case kVcModifyRange:
        {
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.showCustomBottomLine = YES;
            
            cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.textLabel.textColor = theme.textColorMain;
            cell.textLabel.text = NSLocalizedString(@"kEditPasswordCellTitleEditRange", @"修改范围");
            
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.detailTextLabel.textColor = theme.textColorMain;
            switch (_curr_modify_range) {
                case kModifyAllPermissions:
                    cell.detailTextLabel.text = NSLocalizedString(@"kEditPasswordCellValueEditRangeOwnerAndActive", @"账号和资金权限");
                    break;
                case kModifyOnlyActivePermission:
                    cell.detailTextLabel.text = NSLocalizedString(@"kEditPasswordCellValueEditRangeOnlyActive", @"仅资金权限");
                    break;
                case kModifyOnlyOwnerPermission:
                    cell.detailTextLabel.text = NSLocalizedString(@"kEditPasswordCellValueEditRangeOnlyOwner", @"仅账号权限");
                    break;
                default:
                    cell.detailTextLabel.text = @"";
                    break;
            }
            return cell;
        }
            break;
        case kVcSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbSubmit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    //  not reached...
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch ([[_secTypeArray objectAtIndex:indexPath.section] integerValue]) {
            case kVcModifyRange:
                [self onModifyRangeClicked];
                break;
            case kVcSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (void)onModifyRangeClicked
{
    [self endInput];
    
    id items = @[
        @{@"title":NSLocalizedString(@"kEditPasswordEditRangeListOwnerAndActive", @"修改账号和资金权限"),
          @"type":@(kModifyAllPermissions)},
        @{@"title":NSLocalizedString(@"kEditPasswordEditRangeListOnlyActive", @"仅修改资金权限"),
          @"type":@(kModifyOnlyActivePermission)},
        @{@"title":NSLocalizedString(@"kEditPasswordEditRangeListOnlyOwner", @"仅修改账号权限"),
          @"type":@(kModifyOnlyOwnerPermission)},
    ];
    
    NSInteger defaultIndex = 0;
    for (id item in items) {
        if ([[item objectForKey:@"type"] integerValue] == _curr_modify_range) {
            break;
        }
        ++defaultIndex;
    }
    
    [[[MyPopviewManager sharedMyPopviewManager] showModernListView:self.navigationController
                                                           message:nil
                                                             items:items
                                                           itemkey:@"title"
                                                      defaultIndex:defaultIndex] then:(^id(id result) {
        if (result){
            NSInteger range = [[result objectForKey:@"type"] integerValue];
            if (range != _curr_modify_range) {
                _curr_modify_range = range;
                [_mainTableView reloadData];
            }
        }
        return nil;
    })];
}

@end
