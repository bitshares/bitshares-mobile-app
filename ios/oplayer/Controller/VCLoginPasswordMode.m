//
//  VCLoginPasswordMode.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import <QuartzCore/QuartzCore.h>

#import "VCLoginPasswordMode.h"
#import "ViewAdvTextFieldCell.h"
#import "BitsharesClientManager.h"

#import "MBProgressHUD.h"
#import "OrgUtils.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "MyNavigationController.h"
#import "AppCacheManager.h"
#import "WalletManager.h"

#import "VCBtsaiWebView.h"

#import <Crashlytics/Crashlytics.h>

//  ［账号+密码] + [登录]
enum
{
    kVcUser = 0,
    kVcLoginButton,
    
    kVcMax,
};

enum
{
    kVcSubUserAccount = 0,              //  帐号
    kVcSubUserPassowrd,                 //  密码
    kVcSubUserTradingPassword,          //  交易密码 - 直接登录时存在，导入已有钱包不显示。
    
    kVcSubUserMax
};

@interface VCLoginPasswordMode ()
{
    __weak VCBase*          _owner;                     //  REMARK：声明为 weak，否则会导致循环引用。
    BOOL                    _checkActivePermission;     //  是否导入钱包标记
    
    UITableView *           _mainTableView;
    
    ViewAdvTextFieldCell*   _cell_account;
    ViewAdvTextFieldCell*   _cell_password;
    ViewAdvTextFieldCell*   _cell_wallet_password;
    
    ViewBlockLabel*         _lbLogin;
}

@end

@implementation VCLoginPasswordMode

-(void)dealloc
{
    _owner = nil;
    
    _cell_account = nil;
    _cell_password = nil;
    _cell_wallet_password = nil;
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    
    _lbLogin = nil;
}

- (id)initWithOwner:(VCBase*)owner checkActivePermission:(BOOL)checkActivePermission
{
    self = [super init];
    if (self) {
        _owner = owner;
        _checkActivePermission = checkActivePermission;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 账号 & 密码 & 解锁密码
    _cell_account = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginCellAccountName", @"帐号 ")
                                                    placeholder:NSLocalizedString(@"kLoginTipsPlaceholderAccount", @"请输入 Bitshares 帐号名")];
    
    _cell_password = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginPassword", @"密码 ")
                                                     placeholder:NSLocalizedString(@"tip_placeholder_password", @"请输入密码")];
    //  TODO:6.0 因为有中文密码，默认不设置密码模式，允许输入中文。后期考虑是否按钮切换等？
    //    _cell_password.mainTextfield.secureTextEntry = YES;
    
    //  导入钱包则不需要交易密码了
    if (_checkActivePermission) {
        _cell_wallet_password = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginCellSetupTradePassword", @"解锁密码")
                                                                placeholder:NSLocalizedString(@"kLoginTipsPlaceholderTradePassword", @"设置新的解锁密码")];
        _cell_wallet_password.mainTextfield.secureTextEntry = YES;
        [_cell_wallet_password genHelpButton:self action:@selector(onTipButtonClicked:) tag:kVcSubUserTradingPassword];
        [_cell_wallet_password auxFastConditionsViewForWalletPassword];
    } else {
        _cell_wallet_password = nil;
    }
    
    //  UI - 主列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  登录按钮
    _lbLogin = [self createCellLableButton:NSLocalizedString(@"kBtnLogin", @"登录")];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([TempManager sharedTempManager].jumpToLoginVC){
        [TempManager sharedTempManager].jumpToLoginVC = NO;
        //  REMARK：清理堆栈
        UIViewController* root = [self.navigationController.viewControllers objectAtIndex:0];
        self.navigationController.viewControllers = [NSArray arrayWithObjects:root, self, nil];
    }
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (void)endInput
{
    [super endInput];
    [_cell_account endInput];
    [_cell_password endInput];
    if (_cell_wallet_password) {
        [_cell_wallet_password endInput];
    }
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endInput];
}

/**
 *  (private) 帐号模式导入 BTS 帐号。
 */
- (void)loginBitshares_AccountMode
{
    NSString* username = [NSString trim:_cell_account.mainTextfield.text];
    NSString* password = [NSString trim:_cell_password.mainTextfield.text];
    
    //  检测参数有效性
    if ([self isStringEmpty:username])
    {
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountIsEmpty", @"帐号名不能为空，请重新输入。")];
        return;
    }
    if ([self isStringEmpty:password])
    {
        [OrgUtils makeToast:NSLocalizedString(@"kMsgPasswordCannotBeNull", @"密码不能为空，请重新输入。")];
        return;
    }
    NSString* trade_password = @"";
    if (_cell_wallet_password) {
        trade_password = [NSString trim:_cell_wallet_password.mainTextfield.text];
        if (!_cell_wallet_password.isAllConditionsMatched){
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsTradePasswordFmtIncorrect", @"解锁密码格式不正确，请重新输入。")];
            return;
        }
    }
    
    [self endInput];
    
    //  开始登录/导入账号
    NSString* pUsername = username ? [username lowercaseString] : @"";
    NSString* pPassword = password ? password : @"";
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  查询帐号是否存在
    [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:pUsername] then:(^id(id full_data) {
        [_owner hideBlockView];
        
        if (!full_data || [full_data isKindOfClass:[NSNull class]])
        {
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountIsNotExist", @"帐号名不存在，请重新输入。")];
            return nil;
        }
        
        NSLog(@"%@", full_data);
        
        //  获取active权限数据
        id account_active = [[full_data objectForKey:@"account"] objectForKey:@"active"];
        assert(account_active);
        
        //  根据密码计算active私钥
        id active_seed = [NSString stringWithFormat:@"%@active%@", pUsername, pPassword];
        id calc_bts_active_address = [OrgUtils genBtsAddressFromPrivateKeySeed:active_seed];
        
        //  权限检查
        EAccountPermissionStatus status = [WalletManager calcPermissionStatus:account_active privateKeysHash:@{calc_bts_active_address:@YES}];
        //  a、无任何权限，不导入。
        if (status == EAPS_NO_PERMISSION){
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountPasswordIncorrect", @"密码不正确，请重新输入。")];
            return nil;
        }
        //  b、部分权限，仅在导入钱包可以，直接登录时不支持。
        if (_checkActivePermission && status == EAPS_PARTIAL_PERMISSION){
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountPasswordPermissionNotEnough", @"该密码权限不足。")];
            return nil;
        }
        
        //  生成各种权限公私
        id active_private_wif = [OrgUtils genBtsWifPrivateKey:active_seed];
        id owner_seed = [NSString stringWithFormat:@"%@owner%@", pUsername, pPassword];
        id owner_private_wif = [OrgUtils genBtsWifPrivateKey:owner_seed];
        id memo_seed = [NSString stringWithFormat:@"%@memo%@", pUsername, pPassword];
        id memo_private_wif = [OrgUtils genBtsWifPrivateKey:memo_seed];
        assert(owner_private_wif);
        assert(active_private_wif);
        assert(memo_private_wif);
        
        //  登录or导入成功
        if (!_checkActivePermission){
            //  导入现有钱包
            
            //  导入账号到钱包BIN文件中
            id full_wallet_bin = [[WalletManager sharedWalletManager] walletBinImportAccount:pUsername
                                                                           privateKeyWifList:@[active_private_wif,
                                                                                               owner_private_wif,
                                                                                               memo_private_wif]];
            assert(full_wallet_bin);
            [[AppCacheManager sharedAppCacheManager] updateWalletBin:full_wallet_bin];
            [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
            //  重新解锁（即刷新解锁后的账号信息）。
            id unlockInfos = [[WalletManager sharedWalletManager] reUnlock];
            assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
            
            //  返回
            [TempManager sharedTempManager].importToWalletDirty = YES;
            [_owner showMessageAndClose:NSLocalizedString(@"kWalletImportSuccess", @"导入完成")];
        }else{
            //  登录账号 - 简化钱包模式
            id full_wallet_bin = [[WalletManager sharedWalletManager] genFullWalletData:pUsername
                                                                       private_wif_keys:@[active_private_wif, owner_private_wif, memo_private_wif]
                                                                        wallet_password:trade_password];
            
            //  保存钱包信息
            [[AppCacheManager sharedAppCacheManager] setWalletInfo:kwmPasswordWithWallet
                                                       accountInfo:full_data
                                                       accountName:pUsername
                                                     fullWalletBin:full_wallet_bin];
            [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
            //  导入成功 用交易密码 直接解锁。
            id unlockInfos = [[WalletManager sharedWalletManager] unLock:trade_password];
            assert(unlockInfos &&
                   [[unlockInfos objectForKey:@"unlockSuccess"] boolValue] &&
                   [[unlockInfos objectForKey:@"haveActivePermission"] boolValue]);
            //  [统计]
            [OrgUtils logEvents:@"loginEvent" params:@{@"mode":@(kwmPasswordWithWallet), @"desc":@"password+wallet"}];
            
            //  返回
            [_owner showMessageAndClose:NSLocalizedString(@"kLoginTipsLoginOK", @"登录成功。")];
        }
        return nil;
    })] catch:(^id(id error) {
        [_owner hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    })];
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    //  TODO:5.0 输入框事件是否代理给 vc 待处理
    //    if (textField == _tf_username)
    //    {
    //        [_tf_password becomeFirstResponder];
    //    }
    //    else
    //    {
    //        [self.view endEditing:YES];
    //        [_tf_username safeResignFirstResponder];
    //        [_tf_password safeResignFirstResponder];
    //    }
    //  TODO:fowallet _tf_trade_password
    return YES;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcUser) {
        switch (indexPath.row) {
            case kVcSubUserAccount:
                return _cell_account.cellHeight;
            case kVcSubUserPassowrd:
                return _cell_password.cellHeight;
            case kVcSubUserTradingPassword:
                assert(_checkActivePermission);
                return _cell_wallet_password.cellHeight;
            default:
                break;
        }
    }
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcUser){
        if (!_checkActivePermission){
            //  REMARK：导入到已有钱包时，不需要钱包密码字段。
            return kVcSubUserMax - 1;
        }else{
            return kVcSubUserMax;
        }
    }else{
        return 1;
    }
}

///**
// *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
// */
//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
//{
//    return 10.0f;
//}
//- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//    return @" ";
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
//{
//    return 10.0f;
//}
//- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
//{
//    return @" ";
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcUser)
    {
        switch (indexPath.row) {
            case kVcSubUserAccount:
                return _cell_account;
            case kVcSubUserPassowrd:
                return _cell_password;
            case kVcSubUserTradingPassword:
                assert(_checkActivePermission);
                return _cell_wallet_password;
            default:
                break;
        }
        return nil;
        
    }else
    {
        //  登录
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.hideBottomLine = YES;
        cell.hideTopLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbLogin cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcLoginButton){
            [self loginBitshares_AccountMode];
        }
    }];
}

#pragma mark- tip button
- (void)onTipButtonClicked:(UIButton*)button
{
    switch (button.tag) {
        case kVcSubUserTradingPassword:
        {
            [_owner gotoQaView:@"qa_trading_password"
                         title:NSLocalizedString(@"kVcTitleWhatIsTradePassowrd", @"什么是解锁密码？")];
        }
            break;
            
        default:
            break;
    }
}

@end
