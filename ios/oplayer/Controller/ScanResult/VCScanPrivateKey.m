//
//  VCScanPrivateKey.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCScanPrivateKey.h"
#import "BitsharesClientManager.h"

enum
{
    kVcSectionBaseInfo = 0,
    kVcSectionWalletPassword,   //  [可选] 钱包密码、交易解密、解锁密码
    kVcSectionSubmit,
    
    kVcSectionMax
};

@interface VCScanPrivateKey ()
{
    NSString*               _priKey;
    NSString*               _pubKey;
    NSDictionary*           _fullAccountData;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;
    
    MyTextField*            _tf_wallet_password;
    
    NSArray*                _dataArray;
    NSMutableArray*         _secTypeArray;
}

@end

@implementation VCScanPrivateKey

-(void)dealloc
{
    if (_tf_wallet_password){
        _tf_wallet_password.delegate = nil;
        _tf_wallet_password = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _dataArray = nil;
    _secTypeArray = nil;
    _btnCommit = nil;
}

- (id)initWithPriKey:(NSString*)priKey pubKey:(NSString*)pubKey fullAccountData:(NSDictionary*)fullAccountData;
{
    self = [super init];
    if (self) {
        _priKey = priKey;
        _pubKey = pubKey;
        _fullAccountData = fullAccountData;
    }
    return self;
}

#pragma mark- tip button
- (void)onTipButtonClicked:(UIButton*)button
{
    if (button.tag == 1) {
        [OrgUtils showMessage:NSLocalizedString(@"kLoginRegTipsWalletPasswordFormat", @"8位以上字符，且必须包含大小写和数字。")];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    id account = [_fullAccountData objectForKey:@"account"];
    assert(account);
    
    NSMutableArray* priKeyTypeArray = [NSMutableArray array];
    id owner_key_auths = [[account objectForKey:@"owner"] objectForKey:@"key_auths"];
    if (owner_key_auths && [owner_key_auths count] > 0){
        for (id pair in owner_key_auths) {
            assert([pair count] == 2);
            id key = [pair firstObject];
            if ([key isEqualToString:_pubKey]){
                [priKeyTypeArray addObject:NSLocalizedString(@"kVcScanResultPriKeyTypeOwner", @"账号私钥")];
                break;
            }
        }
    }
    id active_key_auths = [[account objectForKey:@"active"] objectForKey:@"key_auths"];
    if (active_key_auths && [active_key_auths count] > 0){
        for (id pair in active_key_auths) {
            assert([pair count] == 2);
            id key = [pair firstObject];
            if ([key isEqualToString:_pubKey]){
                [priKeyTypeArray addObject:NSLocalizedString(@"kVcScanResultPriKeyTypeActive", @"资金私钥")];
                break;
            }
        }
    }
    id memo_key = [[account objectForKey:@"options"] objectForKey:@"memo_key"];
    if (memo_key && [memo_key isEqualToString:_pubKey]){
        [priKeyTypeArray addObject:NSLocalizedString(@"kVcScanResultPriKeyTypeMemo", @"备注私钥")];
    }
    assert([priKeyTypeArray count] > 0);
    
    _secTypeArray = [NSMutableArray array];
    _dataArray = @[
                   @{@"name":@"ID", @"value":[account objectForKey:@"id"]},
                   @{@"name":NSLocalizedString(@"kAccount", @"账号"), @"value":[account objectForKey:@"name"]},
                   @{@"name":NSLocalizedString(@"kVcScanResultPriKeyTypeTitle", @"私钥类型"), @"value":[priKeyTypeArray componentsJoinedByString:@" "], @"highlight":@YES},
                   ];
    [_secTypeArray addObject:@(kVcSectionBaseInfo)];
    
    CGRect rect = [self makeTextFieldRect];
    
    //  wallet password
    if ([self _needWalletPasswordField]) {
        [_secTypeArray addObject:@(kVcSectionWalletPassword)];
        _tf_wallet_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                                         placeholder:NSLocalizedString(@"kLoginTipsPlaceholderWalletPassword", @"8位以上钱包文件密码")
                                              action:@selector(onTipButtonClicked:) tag:1];
        _tf_wallet_password.secureTextEntry = YES;
        _tf_wallet_password.updateClearButtonTintColor = YES;
        _tf_wallet_password.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _tf_wallet_password.attributedPlaceholder = [ViewUtils placeholderAttrString:_tf_wallet_password.placeholder];
    } else {
        //  已经是钱包模式（or交易密码的模式）下不用在再次设置。
        _tf_wallet_password = nil;
    }

    [_secTypeArray addObject:@(kVcSectionSubmit)];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  点击事件
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  按钮
    NSString* btn_str;
    if ([[WalletManager sharedWalletManager] isPasswordMode]) {
        btn_str = NSLocalizedString(@"kVcScanResultPriKeyBtnCreateAndImport", @"升级钱包模式并导入私钥");
    } else {
        btn_str = NSLocalizedString(@"kVcScanResultPriKeyBtnImportNow", @"立即导入");
    }
    _btnCommit = [self createCellLableButton:btn_str];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self endInput];
}

/**
 *  (private) 是否需要钱包密码字段
 */
- (BOOL)_needWalletPasswordField
{
    EWalletMode mode = [[WalletManager sharedWalletManager] getWalletMode];
    if (mode == kwmNoWallet || mode == kwmPasswordOnlyMode) {
        return YES;
    } else {
        return NO;
    }
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    //  验证交易密码有效性（如果存在）
    NSString* pTradePassword = nil;
    if (_tf_wallet_password) {
        pTradePassword = [NSString trim:_tf_wallet_password.text];
        if (![OrgUtils isValidBitsharesWalletPassword:pTradePassword]){
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsTradePasswordFmtIncorrect", @"解锁密码格式不正确，请重新输入。")];
            return;
        }
    }

    [self endInput];
    
    //  多种情况：
    //  1 - 尚未登录（直接采用私钥+钱包密码登录）     * 设置钱包密码   REMARK：check完整active权限。
    //  2 - 已经用密码模式登录（升级到钱包模式并导入） * 设置钱包密码
    //  3 - 已经钱包模式（直接导入）                * 不设置钱包密码，直接解锁即可。
    //  4 - 私钥已经存在（同直接导入，会自动过滤。）   * 不设置钱包密码，直接解锁即可。
    switch ([[WalletManager sharedWalletManager] getWalletMode]) {
        case kwmNoWallet:
        {
            assert(pTradePassword);
            EImportToWalletStatus status = [[WalletManager sharedWalletManager] createNewWallet:_fullAccountData
                                                                                    import_keys:@{_pubKey:_priKey}
                                                                              append_memory_key:NO
                                                                        extra_account_name_list:nil
                                                                                wallet_password:pTradePassword
                                                                                     login_mode:kwmPrivateKeyWithWallet
                                                                                     login_desc:@"private key with wallet"];
            if (status == EITWS_NO_PERMISSION) {
                [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsPrivateKeyIncorrect", @"私钥不正确，请重新输入。")];
            } else if (status == EITWS_PARTIAL_PERMISSION) {
                [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsPermissionNotEnoughAndCannotBeImported", @"资金权限不足，不可导入。")];
            } else if (status == EITWS_OK) {
                [self showMessageAndClose:NSLocalizedString(@"kWalletImportSuccess", @"导入完成")];
            } else {
                assert(NO);
            }
        }
            break;
        case kwmPasswordOnlyMode:
        {
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked){
                    id current_account_data = [[WalletManager sharedWalletManager] getWalletAccountInfo];
                    assert(current_account_data);
                    EImportToWalletStatus status = [[WalletManager sharedWalletManager] createNewWallet:current_account_data
                                                                                            import_keys:@{_pubKey:_priKey}
                                                                                      append_memory_key:YES
                                                                                extra_account_name_list:@[_fullAccountData[@"account"][@"name"]]
                                                                                        wallet_password:pTradePassword
                                                                                             login_mode:kwmPasswordWithWallet
                                                                                             login_desc:@"scan upgrade password+wallet"];
                    assert(status == EITWS_OK);
                    [self showMessageAndClose:NSLocalizedString(@"kWalletImportSuccess", @"导入完成")];
                }
            }];
        }
            break;
        default:
        {
            //  钱包模式 or 交易密码模式，直接解锁然后导入私钥匙。
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked){
                    WalletManager* walletMgr = [WalletManager sharedWalletManager];
                    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
                    
                    //  导入账号到现有钱包BIN文件中
                    id full_wallet_bin = [walletMgr walletBinImportAccount:[[_fullAccountData objectForKey:@"account"] objectForKey:@"name"]
                                                         privateKeyWifList:@[_priKey]];
                    assert(full_wallet_bin);
                    [pAppCache updateWalletBin:full_wallet_bin];
                    [pAppCache autoBackupWalletToWebdir:NO];
                    //  重新解锁（即刷新解锁后的账号信息）。
                    id unlockInfos = [walletMgr reUnlock];
                    assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
                    
                    //  REMARK：导入到现有钱包不用判断导入结果，总是成功。
                    [self showMessageAndClose:NSLocalizedString(@"kWalletImportSuccess", @"导入完成")];
                }
            }];
        }
            break;
    }
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_secTypeArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([[_secTypeArray objectAtIndex:section] integerValue] == kVcSectionBaseInfo)
        return [_dataArray count];
    else
        return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([[_secTypeArray objectAtIndex:indexPath.section] integerValue]) {
        case kVcSectionBaseInfo:
        {
            id item = [_dataArray objectAtIndex:indexPath.row];
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = [item objectForKey:@"name"];
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.detailTextLabel.text = [item objectForKey:@"value"];
            if ([[item objectForKey:@"highlight"] boolValue]){
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
            }else{
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            }
            return cell;
        }
            break;
        case kVcSectionWalletPassword:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = NSLocalizedString(@"kLoginCellWalletPassword", @"钱包密码 ");
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.accessoryView = _tf_wallet_password;
            return cell;
        }
            break;
        case kVcSectionSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ([[_secTypeArray objectAtIndex:indexPath.section] integerValue] == kVcSectionSubmit){
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self onCommitCore];
        }];
    }
}

- (void)endInput
{
    [self.view endEditing:YES];
    if (_tf_wallet_password) {
        [_tf_wallet_password safeResignFirstResponder];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    [self endInput];
    return YES;
}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

@end
