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
    NSString* pPublicKey = [OrgUtils genBtsAddressFromWifPrivateKey:pPrivateKey];
    if (!pPublicKey){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsInvalidPrivateKey", @"私钥数据无效，请重新输入。")];
        return;
    }
    
    [VCCommonLogic onLoginWithKeysHash:_owner
                                  keys:@{pPublicKey:pPrivateKey}
                 checkActivePermission:_checkActivePermission
                        trade_password:pTradePassword ?: @""
                            login_mode:kwmPrivateKeyWithWallet
                            login_desc:@"login with privatekey"
               errMsgInvalidPrivateKey:NSLocalizedString(@"kLoginSubmitTipsPrivateKeyIncorrect", @"私钥不正确，请重新输入。")
       errMsgActivePermissionNotEnough:NSLocalizedString(@"kLoginSubmitTipsPermissionNotEnoughAndCannotBeImported", @"资金权限不足，不可导入。")];
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
            VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"https://btspp.io/qam.html#qa_active_privatekey"];
            vc.title = NSLocalizedString(@"kVcTitleWhatIsActivePrivateKey", @"什么是资金私钥？");
            [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
            break;
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
