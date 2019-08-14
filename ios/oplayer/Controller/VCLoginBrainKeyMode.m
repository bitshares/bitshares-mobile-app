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
    MyTextField*            _tf_trade_password;
    
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
    
    CGRect rect = [self makeTextFieldRect];
    if (_checkActivePermission){
        _tf_trade_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                                        placeholder:NSLocalizedString(@"kLoginTipsPlaceholderTradePassword", @"请输入交易密码")
                                             action:@selector(onTipButtonClicked:) tag:kVcSubUserTradingPassword];
        [_tf_trade_password setSecureTextEntry:YES];
    }else{
        _tf_trade_password = nil;
    }
    
    if (_tf_trade_password){
        _tf_trade_password.updateClearButtonTintColor = YES;
        _tf_trade_password.textColor = theme.textColorMain;
        _tf_trade_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_trade_password.placeholder
                                                                                   attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
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
    
    [_tv_brain_key safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
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
        pTradePassword = [NSString trim:_tf_trade_password.text];
        if (![OrgUtils isValidBitsharesWalletPassword:pTradePassword]){
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsTradePasswordFmtIncorrect", @"交易密码格式不正确，请重新输入。")];
            return;
        }
    }
    
    [self.view endEditing:YES];
    [_tv_brain_key safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
    
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
    [VCCommonLogic onLoginWithKeysHash:_owner
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
    [self.view endEditing:YES];
    [_tv_brain_key safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
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
    if (indexPath.section == kVcUser && indexPath.row == 0){
        return _tv_brain_key.bounds.size.height;
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
    [_tv_brain_key safeResignFirstResponder];
    if (_tf_trade_password){
        [_tf_trade_password safeResignFirstResponder];
    }
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
