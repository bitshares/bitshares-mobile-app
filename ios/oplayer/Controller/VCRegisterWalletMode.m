//
//  VCRegisterPasswordMode.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import <QuartzCore/QuartzCore.h>

#import "VCRegisterWalletMode.h"
#import "BitsharesClientManager.h"

#import "ViewTextFieldOwner.h"
#import "ViewTipsInfoCell.h"

#import "MBProgressHUD.h"
#import "OrgUtils.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "MyNavigationController.h"
#import "AppCacheManager.h"

#import <Crashlytics/Crashlytics.h>

#import "VCBtsaiWebView.h"

//  ［账号+密码] + [登录]
enum
{
    kVcUser = 0,
    kVcLoginButton,
    kVcTips,
    
    kVcMax,
};

enum
{
    kVcSubAccountName = 0,      //  帐号
    kVcSubPassword,             //  密码
    kVcSubConfirmPassword,      //  确认密码
    kVcSubRefCode,              //  推荐码（选填）
    
    kVcSubMax
};

@interface VCRegisterWalletMode ()
{
    __weak VCBase*          _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableView *           _mainTableView;
    
    MyTextField*            _tf_username;
    MyTextField*            _tf_password;
    MyTextField*            _tf_confirm;
    MyTextField*            _tf_refcode;
    
    ViewBlockLabel*         _lbSubmit;
    ViewTipsInfoCell*       _cellTips;
}

@end

@implementation VCRegisterWalletMode

-(void)dealloc
{
    _cellTips = nil;
    
    _tf_username.delegate = nil;
    _tf_password.delegate = nil;
    _tf_confirm.delegate = nil;
    _tf_refcode.delegate = nil;
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithOwner:(VCBase*)owner
{
    self = [super init];
    if (self) {
        _owner = owner;
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
                              placeholder:NSLocalizedString(@"kLoginTipsPlaceholderAccount", @"请输入 Bitshares 帐号名")
                                   action:@selector(onTipButtonClicked:) tag:kVcSubAccountName];
    _tf_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                              placeholder:NSLocalizedString(@"kLoginTipsPlaceholderWalletPassword", @"8位以上钱包文件密码")
                                   action:@selector(onTipButtonClicked:) tag:kVcSubPassword];
    [_tf_password setSecureTextEntry:YES];
    _tf_confirm = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:NSLocalizedString(@"kLoginTipsPlaceholderConfirmPassword", @"请确认密码")];
    [_tf_confirm setSecureTextEntry:YES];
    _tf_refcode = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                             placeholder:NSLocalizedString(@"kLoginTipsPlaceholderInputRefCode", @"引荐人推荐码（选填）")
                                  action:@selector(onTipButtonClicked:) tag:kVcSubRefCode];
    
    //  颜色字号下划线
    _tf_username.updateClearButtonTintColor = YES;
    _tf_password.updateClearButtonTintColor = YES;
    _tf_confirm.updateClearButtonTintColor = YES;
    _tf_refcode.updateClearButtonTintColor = YES;
    _tf_username.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_password.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_confirm.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_refcode.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_username.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_username.placeholder
                                                                         attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                      NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_password.placeholder
                                                                         attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                      NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_confirm.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_confirm.placeholder
                                                                        attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                     NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_refcode.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_refcode.placeholder
                                                                        attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                     NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
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
    
    //  UI - 提示信息
    _cellTips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kLoginRegTipsWalletMode", @"提示：钱包密码对应格式要求可以点击问号查看。\n注意：BTS++是去中心化区块链应用，钱包文件和密码一旦丢失或遗忘将无法找回，建议您注册后将钱包文件做好备份，并妥善保管。※ 推荐使用钱包模式。")];
    _cellTips.hideBottomLine = YES;
    _cellTips.hideTopLine = YES;
    _cellTips.backgroundColor = [UIColor clearColor];
    
    _lbSubmit = [self createCellLableButton:NSLocalizedString(@"kLoginCellBtnAgreeAndReg", @"同意协议并注册")];
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
    [_tf_confirm safeResignFirstResponder];
    [_tf_refcode safeResignFirstResponder];
}

/**
 *  (public) 辅助 - 显示水龙头的时的错误信息，根据 code 进行错误显示便于处理语言国际化。
 */
+ (void)showFaucetRegisterError:(id)response
{
    if (!response){
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return;
    }
    NSInteger code = [[response objectForKey:@"status"] integerValue];
    if (code != 0){
        switch (code) {
            case 10:
                [OrgUtils makeToast:NSLocalizedString(@"kLoginFaucetTipsInvalidArguments", @"参数无效。")];
                break;
            case 20:
                [OrgUtils makeToast:NSLocalizedString(@"kLoginFaucetTipsInvalidAccountFmt", @"帐号格式无效。")];
                break;
            case 30:
                [OrgUtils makeToast:NSLocalizedString(@"kLoginFaucetTipsAccountAlreadyExist", @"帐号已经存在。")];
                break;
            case 40:
                [OrgUtils makeToast:NSLocalizedString(@"kLoginFaucetTipsUnknownError", @"未知错误，广播失败。")];
                break;
            case 41:
                [OrgUtils makeToast:NSLocalizedString(@"kLoginFaucetTipsDeviceRegTooMany", @"该设备注册帐号数量过多。")];
                break;
            case 42:
                [OrgUtils makeToast:NSLocalizedString(@"kLoginFaucetTipsDeviceRegTooFast", @"注册太频繁，请稍后再试。")];
                break;
            case 999:
                [OrgUtils makeToast:NSLocalizedString(@"kLoginFaucetTipsServerMaintence", @"服务器维护中。")];
                break;
            default:
                [OrgUtils makeToast:[response objectForKey:@"msg"]];
                break;
        }
    }
}

/**
 *  (private) 帐号模式注册。
 */
- (void)process_register
{
    NSString* username = [NSString trim:_tf_username.text];
    NSString* password = [NSString trim:_tf_password.text];
    NSString* confirm_password = [NSString trim:_tf_confirm.text];
    NSString* refcode = [NSString trim:_tf_refcode.text];
    
    //  检测参数有效性
    if (![OrgUtils isValidBitsharesAccountName:username]){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountFmtIncorrect", @"帐号格式不正确，请重新输入。")];
        return;
    }
    if (![OrgUtils isValidBitsharesWalletPassword:password]){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsPasswordFmtIncorrect", @"密码格式不正确，请重新输入。")];
        return;
    }
    if (!confirm_password || !password || ![confirm_password isEqualToString:password]){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsConfirmPasswordFailed", @"两次输入到密码不一致，请重新输入。")];
        return;
    }
    
    //  隐藏键盘
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    [_tf_username safeResignFirstResponder];
    [_tf_confirm safeResignFirstResponder];
    [_tf_refcode safeResignFirstResponder];
    
    //   --- 开始注册 ---
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  1、查询名字是否被占用。
    username = [username lowercaseString];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [[[chainMgr isAccountExistOnBlockChain:username] then:(^id(id bExist) {
        if ([bExist boolValue])
        {
            [_owner hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountAlreadyExist", @"帐号名已存在，请重新输入。")];
            return nil;
        }
        
        //  2、调用水龙头API注册
        id private_owner = [WalletManager randomPrivateKeyWIF];
        id private_active = [WalletManager randomPrivateKeyWIF];
//        id private_memo = [WalletManager randomPrivateKeyWIF];
        
        id owner_key = [OrgUtils genBtsAddressFromWifPrivateKey:private_owner];
        id active_key = [OrgUtils genBtsAddressFromWifPrivateKey:private_active];
//        id memo_key = [OrgUtils genBtsAddressFromWifPrivateKey:private_memo];
        
        id args = @{
                    @"account_name":username,
                    @"owner_key":owner_key,
                    @"active_key":active_key,
                    @"memo_key":active_key,
                    @"chid":@(kAppChannelID),
                    @"referrer_code":refcode
                    };
        [[OrgUtils asyncPostUrl:[chainMgr getFinalFaucetURL]
                           args:args] then:(^id(id response) {
            //  注册失败
            if (!response || [[response objectForKey:@"status"] integerValue] != 0){
                [_owner hideBlockView];
                //  [统计]
                [OrgUtils logEvents:@"faucetFailed" params:response ? : @{}];
                [[self class] showFaucetRegisterError:response];
                return nil;
            }
            
            //  3、注册成功
            id full_wallet_bin = [[WalletManager sharedWalletManager] genFullWalletData:username
                                                                       private_wif_keys:@[private_active, private_owner]
                                                                        wallet_password:password];
            //  查询完整帐号信息
            [[[chainMgr queryFullAccountInfo:username] then:(^id(id new_full_account_data) {
                [_owner hideBlockView];
                if (!new_full_account_data || [new_full_account_data isKindOfClass:[NSNull class]])
                {
                    [[AppCacheManager sharedAppCacheManager] setWalletInfo:kwmFullWalletMode
                                                               accountInfo:nil
                                                               accountName:username
                                                             fullWalletBin:full_wallet_bin];
                    [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                    [OrgUtils makeToast:NSLocalizedString(@"kLoginTipsWalletModeRegOK", @"注册成功，但获取帐号信息失败，请重新启动APP。")];
                    return nil;
                }
                
                //  保存钱包信息
                [[AppCacheManager sharedAppCacheManager] setWalletInfo:kwmFullWalletMode
                                                           accountInfo:new_full_account_data
                                                           accountName:username
                                                         fullWalletBin:full_wallet_bin];
                [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                
                //  导入成功 用交易密码 直接解锁。
                id unlockInfos = [[WalletManager sharedWalletManager] unLock:password];
                assert(unlockInfos &&
                       [[unlockInfos objectForKey:@"unlockSuccess"] boolValue] &&
                       [[unlockInfos objectForKey:@"haveActivePermission"] boolValue]);
                //  [统计]
                [OrgUtils logEvents:@"registerEvent" params:@{@"mode":@(kwmFullWalletMode), @"desc":@"wallet"}];
                
                //  修改导航栏（直接返回最外层，跳过注册界面。）
                UIViewController* root = [_owner.navigationController.viewControllers firstObject];
                assert(root != _owner);
                _owner.navigationController.viewControllers = [NSArray arrayWithObjects:root, _owner, nil];
                
                //  返回
                [_owner.myNavigationController tempDisableDragBack];
                [OrgUtils showMessageUseHud:NSLocalizedString(@"kLoginTipsRegFullOK", @"注册成功。")
                                       time:1
                                     parent:_owner.navigationController.view
                            completionBlock:^{
                                [_owner.myNavigationController tempEnableDragBack];
                                [_owner.navigationController popViewControllerAnimated:YES];
                            }];
                
                return nil;
            })] catch:(^id(id error) {
                [_owner hideBlockView];
                [[AppCacheManager sharedAppCacheManager] setWalletInfo:kwmFullWalletMode
                                                           accountInfo:nil
                                                           accountName:username
                                                         fullWalletBin:full_wallet_bin];
                [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                [OrgUtils makeToast:NSLocalizedString(@"kLoginTipsWalletModeRegOK", @"注册成功，但获取帐号信息失败，请重新启动APP。")];
                return nil;
            })];
            return nil;
        })];
        return nil;
    })] catch:(^id(id error) {
        [_owner hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
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
        [_tf_confirm safeResignFirstResponder];
        [_tf_refcode safeResignFirstResponder];
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

#pragma mark- tip button
- (void)onTipButtonClicked:(UIButton*)button
{
    switch (button.tag) {
        case kVcSubAccountName:
            [OrgUtils showMessage:NSLocalizedString(@"kLoginRegTipsAccountFormat", @"帐号由【小写字母】、【数字】、【-】、【.】号组成，且必须字母开头、字母或数字结尾。")];
            break;
        case kVcSubPassword:
            [OrgUtils showMessage:NSLocalizedString(@"kLoginRegTipsWalletPasswordFormat", @"8位以上字符，且必须包含大小写和数字。")];
            break;
        case kVcSubRefCode:
        {
            [OrgUtils logEvents:@"qa_tip_click" params:@{@"qa":@"qa_refcode"}];
            VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"https://btspp.io/qam.html#qa_refcode"];
            vc.title = NSLocalizedString(@"kVcTitleWhatIsRefcode", @"什么是推荐码？");
            [_owner pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
            break;
        default:
            break;
    }
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcTips){
        return [_cellTips calcCellDynamicHeight:tableView.layoutMargins.left];
    }
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcUser){
        return kVcSubMax;
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
            case kVcSubAccountName:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.showCustomBottomLine = YES;
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kLoginCellAccountName", @"帐号 ");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_username;
                return cell;
            }
                break;
            case kVcSubPassword:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.showCustomBottomLine = YES;
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kLoginPassword", @"密码 ");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_password;
                return cell;
            }
                break;
            case kVcSubConfirmPassword:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.showCustomBottomLine = YES;
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kLoginCellConfirmPassword", @"确认密码");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_confirm;
                return cell;
            }
                break;
            case kVcSubRefCode:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.showCustomBottomLine = YES;
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kLoginCellLabelRefCode", @"推荐码");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_refcode;
                return cell;
            }
                break;
            default:
                break;
        }
    }else if (indexPath.section == kVcLoginButton)
    {
        //  注册
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.hideBottomLine = YES;
        cell.hideTopLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbSubmit cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }else{
        return _cellTips;
    }
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcLoginButton){
            [self process_register];
        }
    }];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    [_tf_username safeResignFirstResponder];
    [_tf_confirm safeResignFirstResponder];
    [_tf_refcode safeResignFirstResponder];
}

@end
