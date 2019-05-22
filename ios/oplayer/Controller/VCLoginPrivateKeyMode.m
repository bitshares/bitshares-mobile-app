//
//  VCLoginPrivateKeyMode.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import <QuartzCore/QuartzCore.h>

#import "VCLoginPrivateKeyMode.h"
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
    kVcSubUserActivePrivateKey = 0,     //  资金私钥（私钥模式不需要帐号名）
    kVcSubUserTradingPassword,          //  交易密码（私钥模式必须启用）
    
    kVcSubUserMax
};

@interface VCLoginPrivateKeyMode ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    BOOL                    _checkActivePermission; //  登录时验证active权限。
    
    UITableView *           _mainTableView;
    
    MyTextField*            _tf_private_key;
    MyTextField*            _tf_trade_password;
    ViewBlockLabel*         _lbLogin;
}

@end

@implementation VCLoginPrivateKeyMode

@synthesize tmpPassword;

-(void)dealloc
{
    _owner = nil;
    
    if (_tf_private_key){
        _tf_private_key.delegate = nil;
        _tf_private_key = nil;
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
    
    _tf_private_key = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                                 placeholder:NSLocalizedString(@"kLoginTipsPlaceholderActiveKey", @"请输入资金权限私钥")
                                      action:@selector(onTipButtonClicked:) tag:kVcSubUserActivePrivateKey];
    if (_checkActivePermission){
        _tf_trade_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                                        placeholder:NSLocalizedString(@"kLoginTipsPlaceholderTradePassword", @"请输入交易密码")
                                             action:@selector(onTipButtonClicked:) tag:kVcSubUserTradingPassword];
        [_tf_trade_password setSecureTextEntry:YES];
    }else{
        _tf_trade_password = nil;
    }
    
    //  颜色字号下划线
    _tf_private_key.updateClearButtonTintColor = YES;
    _tf_private_key.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_private_key.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_private_key.placeholder
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
    if (self.tmpPassword)
    {
        _tf_private_key.text = self.tmpPassword;
        self.tmpPassword = nil;
    }
    //  TODO:fowallet _tf_trade_password
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
    
    [_tf_private_key safeResignFirstResponder];
//    [_tf_username safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
}

/**
 *  (private) 私钥模式导入 BTS 帐号。
 */
- (void)loginBitshares_AccountMode
{
    NSString* pPrivateKey = [NSString trim:_tf_private_key.text];
    NSString* pTradePassword = @"";
    
    //  检测参数有效性
    if (_checkActivePermission){
        pTradePassword = [NSString trim:_tf_trade_password.text];
        if (![OrgUtils isValidBitsharesWalletPassword:pTradePassword]){
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsTradePasswordFmtIncorrect", @"交易密码格式不正确，请重新输入。")];
            return;
        }
    }
    
    [self.view endEditing:YES];
    [_tf_private_key safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
    
    //  开始登录
    pPrivateKey = pPrivateKey ? pPrivateKey : @"";
    pTradePassword = pTradePassword ? pTradePassword : @"";
    
    //  从WIF私钥获取公钥
    NSString* calc_bts_active_address = [OrgUtils genBtsAddressFromWifPrivateKey:pPrivateKey];
    if (!calc_bts_active_address){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsInvalidPrivateKey", @"私钥数据无效，请重新输入。")];
        return;
    }
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[chainMgr queryAccountDataHashFromKeys:@[calc_bts_active_address]] then:(^id(id account_data_hash) {
        if ([account_data_hash count] <= 0){
            [_owner hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsPrivateKeyIncorrect", @"私钥不正确，请重新输入。")];
            return nil;
        }
        id account_data_list = [account_data_hash allValues];
        //  TODO:一个私钥关联多个账号
        if ([account_data_list count] >= 2){
            NSString* name_join_strings = [[account_data_list ruby_map:(^id(id src) {
                return [src objectForKey:@"name"];
            })] componentsJoinedByString:@","];
            CLS_LOG(@"ONE KEY %@ ACCOUNTS: %@", @([account_data_list count]), name_join_strings);
        }
        //  默认选择第一个账号
        id account_data = [account_data_list firstObject];
        return [[chainMgr queryFullAccountInfo:account_data[@"id"]] then:(^id(id full_data) {
            [_owner hideBlockView];
            
            if (!full_data || [full_data isKindOfClass:[NSNull class]])
            {
                //  这里的帐号信息应该存在，因为帐号ID是通过 get_key_references 返回的。
                [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsQueryAccountFailed", @"查询帐号信息失败，请稍后再试。")];
                return nil;
            }
            
            //  获取账号数据
            id account = [full_data objectForKey:@"account"];
            NSString* accountName = account[@"name"];
            
            //  验证Active权限，导入钱包时不验证。
            if (_checkActivePermission){
                //  获取active权限数据
                id account_active = [account objectForKey:@"active"];
                assert(account_active);
                
                //  检测权限是否足够签署需要active权限的交易。
                EAccountPermissionStatus status = [WalletManager calcPermissionStatus:account_active
                                                                      privateKeysHash:@{calc_bts_active_address:pPrivateKey}];
                if (status == EAPS_NO_PERMISSION){
                    [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsPrivateKeyIncorrect", @"私钥不正确，请重新输入。")];
                    return nil;
                }else if (status == EAPS_PARTIAL_PERMISSION){
                    [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsPrivateKeyPermissionNotEnough", @"该私钥权限不足。")];
                    return nil;
                }
            }
            
            if (!_checkActivePermission){
                //  导入账号到现有钱包BIN文件中
                id full_wallet_bin = [[WalletManager sharedWalletManager] walletBinImportAccount:accountName
                                                                               privateKeyWifList:@[pPrivateKey]];
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
                //  创建完整钱包模式
                id full_wallet_bin = [[WalletManager sharedWalletManager] genFullWalletData:accountName
                                                                                     active:pPrivateKey owner:nil memo:nil
                                                                            wallet_password:pTradePassword];
                
                //  保存钱包信息
                [[AppCacheManager sharedAppCacheManager] setWalletInfo:kwmPrivateKeyWithWallet
                                                           accountInfo:full_data
                                                           accountName:accountName
                                                         fullWalletBin:full_wallet_bin];
                [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                //  导入成功 用交易密码 直接解锁。
                id unlockInfos = [[WalletManager sharedWalletManager] unLock:pTradePassword];
                assert(unlockInfos &&
                       [[unlockInfos objectForKey:@"unlockSuccess"] boolValue] &&
                       [[unlockInfos objectForKey:@"haveActivePermission"] boolValue]);
                //  [统计]
                [OrgUtils logEvents:@"loginEvent" params:@{@"mode":@(kwmPrivateKeyWithWallet), @"desc":@"privatekey"}];
                
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
        })];
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
    if (textField == _tf_private_key && _tf_trade_password)
    {
        [_tf_trade_password becomeFirstResponder];
    }
    else
    {
        [self.view endEditing:YES];
        [_tf_private_key safeResignFirstResponder];
        if (_tf_trade_password){
            [_tf_trade_password safeResignFirstResponder];
        }
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
    //    if ([self getSectionType:section] == kVcFastLogin){
    //        return NSLocalizedString(@"tip_click_account_to_login", @"点击以下账号可直接快速登录、滑动可删除。");
    //    }
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
            return kVcSubUserMax - 1;
        }else{
            return kVcSubUserMax;
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
            case kVcSubUserActivePrivateKey:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kLoginCellActivePrivateKey", @"资金私钥 ");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_private_key;
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
    [_tf_private_key safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
}

#pragma mark- tip button
- (void)onTipButtonClicked:(UIButton*)button
{
    switch (button.tag) {
        case kVcSubUserActivePrivateKey:
        {
            //  [统计]
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_active_privatekey"}];
            VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"http://btspp.io/qam.html#qa_active_privatekey"];
            vc.title = NSLocalizedString(@"kVcTitleWhatIsActivePrivateKey", @"什么是资金私钥？");
            [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
            break;
        case kVcSubUserTradingPassword:
        {
            //  [统计]
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_trading_password"}];
            VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"http://btspp.io/qam.html#qa_trading_password"];
            vc.title = NSLocalizedString(@"kVcTitleWhatIsTradePassowrd", @"什么是交易密码？");
            [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
            break;
            
        default:
            break;
    }
}

@end
