//
//  VCLoginPasswordMode.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import <QuartzCore/QuartzCore.h>

#import "VCLoginPasswordMode.h"
#import "BitsharesClientManager.h"

#import "MBProgressHUD.h"
#import "OrgUtils.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
//#import "VCRegister.h"
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
    kVcSubUserEnableTradingPassword,    //  [仅登录时存在] 独立交易密码
    kVcSubUserTradingPassword,          //  [仅登录时存在] 交易密码
    
    kVcSubUserMax
};

@interface VCLoginPasswordMode ()
{
    __weak VCBase*          _owner;                     //  REMARK：声明为 weak，否则会导致循环引用。
    BOOL                    _checkActivePermission;     //  是否导入钱包标记
    
    UITableView *           _mainTableView;
    
    MyTextField*            _tf_username;
    MyTextField*            _tf_password;
    MyTextField*            _tf_trade_password;
    ViewBlockLabel*         _lbLogin;
    
    BOOL                    _enable_trade_password;     //  是否启用独立交易密码
}

@end

@implementation VCLoginPasswordMode

-(void)dealloc
{
    _owner = nil;
    
    if (_tf_username){
        _tf_username.delegate = nil;
        _tf_username = nil;
    }
    if (_tf_password){
        _tf_password.delegate = nil;
        _tf_password = nil;
    }
    if (_tf_trade_password){
        _tf_trade_password.delegate = nil;
        _tf_trade_password = nil;
    }
    
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
        _enable_trade_password = NO;    //  默认不启用独立交易密码
        _checkActivePermission = checkActivePermission;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor clearColor];
    
    CGRect rect = [self makeTextFieldRect];
    
    _tf_username = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                              placeholder:NSLocalizedString(@"kLoginTipsPlaceholderAccount", @"请输入 Bitshares 帐号名")];
    _tf_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                              placeholder:NSLocalizedString(@"tip_placeholder_password", @"请输入密码")];
    [_tf_password setSecureTextEntry:YES];
    //  导入钱包则不需要交易密码了
    if (_checkActivePermission){
        _tf_trade_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                                        placeholder:NSLocalizedString(@"kLoginTipsPlaceholderTradePassword", @"请输入交易密码")
                                             action:@selector(onTipButtonClicked:) tag:kVcSubUserTradingPassword];
        [_tf_trade_password setSecureTextEntry:YES];
    }else{
        _tf_trade_password = nil;
    }
    
    //  颜色字号下划线
    _tf_username.updateClearButtonTintColor = YES;
    _tf_password.updateClearButtonTintColor = YES;
    _tf_username.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_password.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_username.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_username.placeholder
                                                                         attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                      NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_password.placeholder
                                                                         attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                      NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    if (_tf_trade_password){
        _tf_trade_password.updateClearButtonTintColor = YES;
        _tf_trade_password.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _tf_trade_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_trade_password.placeholder
                                                                                   attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                                NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    }
    
    //  UI - 主列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  点击事件
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
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

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self.view endEditing:YES];
    
    [_tf_password safeResignFirstResponder];
    [_tf_username safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
}

/**
 *  (private) 帐号模式导入 BTS 帐号。
 */
- (void)loginBitshares_AccountMode
{
    NSString* username = [NSString trim:_tf_username.text];
    NSString* password = [NSString trim:_tf_password.text];
    
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
    if (_tf_trade_password){
        trade_password = [NSString trim:_tf_trade_password.text];
        if (_enable_trade_password && ![OrgUtils isValidBitsharesWalletPassword:trade_password]){
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsTradePasswordFmtIncorrect", @"交易密码格式不正确，请重新输入。")];
            return;
        }
    }
    
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    [_tf_username safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
    
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
        
        //  登录or导入成功
        if (!_checkActivePermission){
            //  导入现有钱包
            id active_private_wif = [OrgUtils genBtsWifPrivateKey:active_seed];
            id owner_seed = [NSString stringWithFormat:@"%@owner%@", pUsername, pPassword];
            id owner_private_wif = [OrgUtils genBtsWifPrivateKey:owner_seed];
    
            //  导入账号到钱包BIN文件中
            id full_wallet_bin = [[WalletManager sharedWalletManager] walletBinImportAccount:pUsername
                                                                           privateKeyWifList:@[active_private_wif, owner_private_wif]];
            assert(full_wallet_bin);
            [[AppCacheManager sharedAppCacheManager] updateWalletBin:full_wallet_bin];
            [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
            //  重新解锁（即刷新解锁后的账号信息）。
            id unlockInfos = [[WalletManager sharedWalletManager] reUnlock];
            assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
            
            //  返回
            [TempManager sharedTempManager].importToWalletDirty = YES;
            [_owner.myNavigationController tempDisableDragBack];
            [OrgUtils showMessageUseHud:NSLocalizedString(@"kWalletImportSuccess", @"导入完成")
                                   time:1
                                 parent:_owner.navigationController.view
                        completionBlock:^{
                            [_owner.myNavigationController tempEnableDragBack];
                            [_owner.navigationController popViewControllerAnimated:YES];
                        }];
        }else{
            //  登录账号
            if (_enable_trade_password){
                //  简化钱包模式
                id active_private_wif = [OrgUtils genBtsWifPrivateKey:active_seed];
                id owner_seed = [NSString stringWithFormat:@"%@owner%@", pUsername, pPassword];
                id owner_private_wif = [OrgUtils genBtsWifPrivateKey:owner_seed];
                assert(owner_private_wif);
                assert(active_private_wif);
                id full_wallet_bin = [[WalletManager sharedWalletManager] genFullWalletData:pUsername
                                                                           private_wif_keys:@[active_private_wif, owner_private_wif]
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
            }else{
                //  普通帐号模式
                [[AppCacheManager sharedAppCacheManager] setWalletInfo:kwmPasswordOnlyMode
                                                           accountInfo:full_data
                                                           accountName:pUsername
                                                         fullWalletBin:nil];
                //  导入成功 用帐号密码 直接解锁。
                id unlockInfos = [[WalletManager sharedWalletManager] unLock:pPassword];
                assert(unlockInfos &&
                       [[unlockInfos objectForKey:@"unlockSuccess"] boolValue] &&
                       [[unlockInfos objectForKey:@"haveActivePermission"] boolValue]);
                //  [统计]
                [OrgUtils logEvents:@"loginEvent" params:@{@"mode":@(kwmPasswordOnlyMode), @"desc":@"password"}];
            }
            
            //  返回
            [_owner.myNavigationController tempDisableDragBack];
            [OrgUtils showMessageUseHud:NSLocalizedString(@"kLoginTipsLoginOK", @"登录成功。")
                                   time:1
                                 parent:_owner.navigationController.view
                        completionBlock:^{
                            [_owner.myNavigationController tempEnableDragBack];
                            [_owner.navigationController popViewControllerAnimated:YES];
                        }];
        }
        return nil;
    })] catch:(^id(id error) {
        [_owner hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    })];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _tf_username)
    {
        [_tf_password becomeFirstResponder];
    }
    else
    {
        [self.view endEditing:YES];
        [_tf_username safeResignFirstResponder];
        [_tf_password safeResignFirstResponder];
    }
    //  TODO:fowallet _tf_trade_password
    return YES;
}

#pragma mark- UITableView Delegate For Fast Login

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 15.0f;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcUser){
        if (!_checkActivePermission){
            return kVcSubUserMax - 2;
        }else{
            if (_enable_trade_password){
                return kVcSubUserMax;
            }else{
                return kVcSubUserMax - 1;
            }
        }
    }else{
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == kVcLoginButton){
        return tableView.sectionFooterHeight;
    }else{
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcUser)
    {
        switch (indexPath.row) {
            case kVcSubUserAccount:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kLoginCellAccountName", @"帐号 ");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_username;
                return cell;
            }
                break;
            case kVcSubUserPassowrd:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kLoginPassword", @"密码 ");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_password;
                return cell;
            }
                break;
            case kVcSubUserEnableTradingPassword:
            {
                assert(_checkActivePermission);
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.showCustomBottomLine = YES;
                
                UISwitch* pSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
                pSwitch.tintColor = [ThemeManager sharedThemeManager].textColorGray;        //  边框颜色
                pSwitch.thumbTintColor = [ThemeManager sharedThemeManager].textColorGray;   //  按钮颜色
                pSwitch.onTintColor = [ThemeManager sharedThemeManager].textColorHighlight; //  开启时颜色
                
                pSwitch.tag = indexPath.row;
                pSwitch.on = _enable_trade_password;
                [pSwitch addTarget:self action:@selector(onSwitchAction:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = pSwitch;
                
                cell.textLabel.text = NSLocalizedString(@"kLoginCellSetupTradePassword", @"设置交易密码");
                return cell;
            }
                break;
            case kVcSubUserTradingPassword:
            {
                assert(_checkActivePermission);
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.showCustomBottomLine = YES;
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kLoginCellTradePassword", @"交易密码");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_trade_password;
                return cell;
            }
                break;
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

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    [_tf_username safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
}

#pragma mark- for switch action
-(void)onSwitchAction:(UISwitch*)pSwitch
{
    _enable_trade_password = pSwitch.on;
    _tf_trade_password.text = @"";  //  clear
    [_mainTableView reloadData];
    
    //  TODO:
 //   [[AppCacheManager sharedAppCacheManager] setSavePassword:pSwitch.on];
}

#pragma mark- tip button
- (void)onTipButtonClicked:(UIButton*)button
{
    switch (button.tag) {
        case kVcSubUserTradingPassword:
        {
            //  [统计]
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_trading_password"}];
            VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"https://btspp.io/qam.html#qa_trading_password"];
            vc.title = NSLocalizedString(@"kVcTitleWhatIsTradePassowrd", @"什么是交易密码？");
            [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
            break;
            
        default:
            break;
    }
}

@end
