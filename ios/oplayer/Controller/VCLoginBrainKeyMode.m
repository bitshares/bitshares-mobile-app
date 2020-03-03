//
//  VCLoginBrainKeyMode.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import <QuartzCore/QuartzCore.h>

#import "VCLoginBrainKeyMode.h"
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
#import "MyTextView.h"

#import <Crashlytics/Crashlytics.h>

#import "HDWallet.h"

//  ［助记词+钱包密码] + [登录]
enum
{
    kVcUser = 0,
    kVcLoginButton,
    
    kVcMax,
};

enum
{
    kVcSubUserBrainKeyWorkds = 0,       //  助记词
    kVcSubUserTradingPassword,          //  交易密码（私钥模式必须启用）
    
    kVcSubUserMax
};

@interface VCLoginBrainKeyMode ()
{
    __weak VCBase*          _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    BOOL                    _checkActivePermission; //  登录时验证active权限。
    
    UITableView *           _mainTableView;
    
    MyTextView*             _tv_brain_key;
    ViewAdvTextFieldCell*   _cell_wallet_password;
    
    ViewBlockLabel*         _lbLogin;
}

@end

@implementation VCLoginBrainKeyMode

-(void)dealloc
{
    _owner = nil;
    
    if (_tv_brain_key){
        _tv_brain_key.delegate = nil;
        _tv_brain_key = nil;
    }
    _cell_wallet_password = nil;
    //    if (_tf_trade_password){
    //        _tf_trade_password.delegate = nil;
    //        _tf_trade_password = nil;
    //    }
    
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
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    _tv_brain_key = [[MyTextView alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width  - 32, 28 * 4)];
    _tv_brain_key.dataDetectorTypes = UIDataDetectorTypeAll;
    [_tv_brain_key setFont:[UIFont systemFontOfSize:16]];
    _tv_brain_key.placeholder = NSLocalizedString(@"kLoginTipsPlaceholderBrainKey", @"请输入助记词，每个单词之间按空格分割。");
    _tv_brain_key.backgroundColor = [UIColor clearColor];
    _tv_brain_key.dataDetectorTypes = UIDataDetectorTypeNone;
    _tv_brain_key.textColor = theme.textColorMain;
    _tv_brain_key.tintColor = theme.tintColor;
    
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
    
    [_tv_brain_key safeResignFirstResponder];
    if (_cell_wallet_password) {
        [_cell_wallet_password endInput];
    }
}

/**
 *  (private) 私钥模式导入 BTS 帐号。
 */
- (void)loginBitshares_AccountMode
{
    //  检测参数有效性
    NSString* pBrainKey = [NSString trim:_tv_brain_key.text];
    if ([self isStringEmpty:pBrainKey]){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsBrainKeyIncorrect", @"助记词不正确，请重新输入。")];
        return;
    }
    pBrainKey = [WalletManager normalizeBrainKey:pBrainKey];
    
    //  校验：交易密码
    NSString* pTradePassword = @"";
    if (_checkActivePermission){
        pTradePassword = [NSString trim:_cell_wallet_password.mainTextfield.text];
        if (!_cell_wallet_password.isAllConditionsMatched){
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsTradePasswordFmtIncorrect", @"解锁密码格式不正确，请重新输入。")];
            return;
        }
    }
    
    [self endInput];
    
    //  开始登录
    
    NSMutableDictionary* pub_pri_keys_hash = [NSMutableDictionary dictionary];
    
    //  根据BIP32、BIP39、BIP44规范，从助记词生成种子、和各种子私钥。
    HDWallet* hdk = [HDWallet fromMnemonic:pBrainKey];
    HDWallet* new_key_owner = [hdk deriveBitshares:EHDBPT_OWNER];
    HDWallet* new_key_active = [hdk deriveBitshares:EHDBPT_ACTIVE];
    HDWallet* new_key_memo = [hdk deriveBitshares:EHDBPT_MEMO];
    NSString* pri_key_owner = [new_key_owner toWifPrivateKey];
    NSString* pri_key_active = [new_key_active toWifPrivateKey];
    NSString* pri_key_memo = [new_key_memo toWifPrivateKey];
    NSString* pub_key_owner = [OrgUtils genBtsAddressFromWifPrivateKey:pri_key_owner];
    NSString* pub_key_active = [OrgUtils genBtsAddressFromWifPrivateKey:pri_key_active];
    NSString* pub_key_memo = [OrgUtils genBtsAddressFromWifPrivateKey:pri_key_memo];
    [pub_pri_keys_hash setObject:pri_key_owner forKey:pub_key_owner];
    [pub_pri_keys_hash setObject:pri_key_active forKey:pub_key_active];
    [pub_pri_keys_hash setObject:pri_key_memo forKey:pub_key_memo];
    
    //  REMARK：兼容轻钱包，根据序列生成私钥匙。
    for (NSInteger i = 0; i < 10; ++i) {
        NSString* pri_key = [WalletManager genPrivateKeyFromBrainKey:pBrainKey sequence:i];
        NSString* pub_key = [OrgUtils genBtsAddressFromWifPrivateKey:pri_key];
        [pub_pri_keys_hash setObject:pri_key forKey:pub_key];
    }
    
    //  从各种私钥登录。
    [VcUtils onLoginWithKeysHash:_owner
                            keys:[pub_pri_keys_hash copy]
           checkActivePermission:_checkActivePermission
                  trade_password:pTradePassword ?: @""
                      login_mode:kwmBrainKeyWithWallet
                      login_desc:@"login with brainkey"
         errMsgInvalidPrivateKey:NSLocalizedString(@"kLoginSubmitTipsBrainKeyIncorrect", @"助记词不正确，请重新输入。")
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
    [self endInput];
    return YES;
}

//#pragma mark- UITableView Delegate For Fast Login
//
//- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    return UITableViewCellEditingStyleDelete;
//}
//
//- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//    return nil;
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
//{
//    return 15.0f;
//}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcUser) {
        switch (indexPath.row) {
            case kVcSubUserBrainKeyWorkds:
                return _tv_brain_key.bounds.size.height;;
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
            case kVcSubUserBrainKeyWorkds:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryView = _tv_brain_key;
                return cell;
            }
                break;
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
