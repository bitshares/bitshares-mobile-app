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
#import "ViewAdvTextFieldCell.h"

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
    
    ViewAdvTextFieldCell*   _cell_private_key;
    ViewAdvTextFieldCell*   _cell_wallet_password;
    ViewBlockLabel*         _lbLogin;
}

@end

@implementation VCLoginPrivateKeyMode

-(void)dealloc
{
    _owner = nil;
    
    _cell_private_key = nil;
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
    
    self.view.backgroundColor = [UIColor clearColor];
    
    //    CGRect rect = [self makeTextFieldRect];
    
    _cell_private_key = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginCellActivePrivateKey", @"资金私钥 ")
                                                        placeholder:NSLocalizedString(@"kLoginTipsPlaceholderActiveKey", @"请输入资金权限私钥")];
    [_cell_private_key genHelpButton:self action:@selector(onTipButtonClicked:) tag:kVcSubUserActivePrivateKey];
    //  TODO:5.0 private key 格式？
    //        [_cell_private_key genFormatConditonsView:^(ViewFormatConditons *formatConditonsView) {
    //        }];
    
    if (_checkActivePermission){
        _cell_wallet_password = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginCellSetupTradePassword", @"解锁密码")
                                                                placeholder:NSLocalizedString(@"kLoginTipsPlaceholderTradePassword", @"设置新的解锁密码")];
        _cell_wallet_password.mainTextfield.secureTextEntry = YES;
        [_cell_wallet_password genHelpButton:self action:@selector(onTipButtonClicked:) tag:kVcSubUserTradingPassword];
        [_cell_wallet_password auxFastConditionsViewForWalletPassword];
    }else{
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
    [_cell_private_key endInput];
    if (_cell_wallet_password) {
        [_cell_wallet_password endInput];
    }
}

/**
 *  (private) 私钥模式导入 BTS 帐号。
 */
- (void)loginBitshares_AccountMode
{
    NSString* pPrivateKey = [NSString trim:_cell_private_key.mainTextfield.text];
    NSString* pTradePassword = @"";
    
    //  检测参数有效性
    if (_checkActivePermission){
        pTradePassword = [NSString trim:_cell_wallet_password.mainTextfield.text];
        if (!_cell_wallet_password.isAllConditionsMatched) {
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsTradePasswordFmtIncorrect", @"解锁密码格式不正确，请重新输入。")];
            return;
        }
    }
    
    [self endInput];
    
    //  开始登录
    pPrivateKey = pPrivateKey ? pPrivateKey : @"";
    NSString* pPublicKey = [OrgUtils genBtsAddressFromWifPrivateKey:pPrivateKey];
    if (!pPublicKey){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsInvalidPrivateKey", @"私钥数据无效，请重新输入。")];
        return;
    }
    
    [VcUtils onLoginWithKeysHash:_owner
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
    //  TODO:5.0
    //    if (textField == _tf_private_key && _tf_trade_password)
    //    {
    //        [_tf_trade_password becomeFirstResponder];
    //    }
    //    else
    //    {
    [self endInput];
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
            case kVcSubUserActivePrivateKey:
                return _cell_private_key.cellHeight;
            case kVcSubUserTradingPassword:
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
                return _cell_private_key;
                
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

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endInput];
}

#pragma mark- tip button
- (void)onTipButtonClicked:(UIButton*)button
{
    switch (button.tag) {
        case kVcSubUserActivePrivateKey:
        {
            [_owner gotoQaView:@"qa_active_privatekey"
                         title:NSLocalizedString(@"kVcTitleWhatIsActivePrivateKey", @"什么是资金私钥？")];
        }
            break;
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
