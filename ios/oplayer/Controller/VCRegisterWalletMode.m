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

#import "ViewAdvTextFieldCell.h"
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
    
    ViewAdvTextFieldCell*   _cell_account;
    ViewAdvTextFieldCell*   _cell_password;
    ViewAdvTextFieldCell*   _cell_confirm;
    ViewAdvTextFieldCell*   _cell_refcode;
    
    ViewBlockLabel*         _lbSubmit;
    ViewTipsInfoCell*       _cellTips;
}

@end

@implementation VCRegisterWalletMode

-(void)dealloc
{
    _cellTips = nil;
    
    _cell_account = nil;
    _cell_password = nil;
    _cell_confirm = nil;
    _cell_refcode = nil;
    
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
    
    //  UI - 账号输入框
    _cell_account = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginCellAccountName", @"帐号 ")
                                                    placeholder:NSLocalizedString(@"kRegTipsPlaceholderNewAccount", @"请输入新的账号名")];
    [_cell_account auxFastConditionsViewForAccountNameFormat];
    
    //  UI - 密码输入框
    _cell_password = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kRegCellLabelWalletPassword", @"钱包密码")
                                                     placeholder:NSLocalizedString(@"kRegTipsPlaceholderNewWalletPassword", @"请输入新的钱包密码")];
    _cell_password.mainTextfield.secureTextEntry = YES;
    [_cell_password auxFastConditionsViewForWalletPassword];
    
    //  UI - 确认密码
    _cell_confirm = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginCellConfirmPassword", @"确认密码")
                                                    placeholder:NSLocalizedString(@"kLoginTipsPlaceholderConfirmPassword", @"请确认密码")];
    _cell_confirm.mainTextfield.secureTextEntry = YES;
    
    //  UI - 推荐码
    _cell_refcode = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginCellLabelRefCode", @"推荐码")
                                                    placeholder:NSLocalizedString(@"kLoginTipsPlaceholderInputRefCode", @"引荐人推荐码（选填）")];
    [_cell_refcode genHelpButton:self action:@selector(onTipButtonClicked:) tag:kVcSubRefCode];
    
    //  UI - 主列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
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

- (void)endInput
{
    [super endInput];
    [_cell_account endInput];
    [_cell_password endInput];
    [_cell_confirm endInput];
    [_cell_refcode endInput];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endInput];
}

/**
 *  (private) 帐号模式注册。
 */
- (void)process_register
{
    NSString* username = [NSString trim:_cell_account.mainTextfield.text];
    NSString* password = [NSString trim:_cell_password.mainTextfield.text];
    NSString* confirm_password = [NSString trim:_cell_confirm.mainTextfield.text];
    NSString* refcode = [NSString trim:_cell_refcode.mainTextfield.text];
    
    //  检测参数有效性
    if (!_cell_account.isAllConditionsMatched) {
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountFmtIncorrect", @"帐号格式不正确，请重新输入。")];
        return;
    }
    if (!_cell_password.isAllConditionsMatched) {
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsPasswordFmtIncorrect", @"密码格式不正确，请重新输入。")];
        return;
    }
    if (!confirm_password || !password || ![confirm_password isEqualToString:password]){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsConfirmPasswordFailed", @"两次输入到密码不一致，请重新输入。")];
        return;
    }
    
    //  隐藏键盘
    [self endInput];
    
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
        id private_memo = [WalletManager randomPrivateKeyWIF];
        
        id owner_key = [OrgUtils genBtsAddressFromWifPrivateKey:private_owner];
        id active_key = [OrgUtils genBtsAddressFromWifPrivateKey:private_active];
        id memo_key = [OrgUtils genBtsAddressFromWifPrivateKey:private_memo];
        
        [[OrgUtils asyncCreateAccountFromFaucet:username
                                          owner:owner_key
                                         active:active_key
                                           memo:memo_key
                                        refcode:refcode
                                           chid:kAppChannelID] then:(^id(id err_msg) {
            //  注册失败
            if (err_msg && [err_msg isKindOfClass:[NSString class]]) {
                [_owner hideBlockView];
                //  [统计]
                [OrgUtils logEvents:@"faucetFailed" params:@{@"err":err_msg}];
                [OrgUtils makeToast:err_msg];
                return nil;
            }
            
            //  3、注册成功
            id full_wallet_bin = [[WalletManager sharedWalletManager] genFullWalletData:username
                                                                       private_wif_keys:@[private_active, private_owner, private_memo]
                                                                        wallet_password:password];
            //  查询完整帐号信息
            [[[chainMgr queryFullAccountInfo:username retry_num:3] then:(^id(id new_full_account_data) {
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
                [_owner showMessageAndClose:NSLocalizedString(@"kLoginTipsRegFullOK", @"注册成功。")];
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

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    //  TODO:5.0
    //    if (textField == _tf_username)
    //    {
    //        [_tf_password becomeFirstResponder];
    //    }
    //    else
    //    {
    //        [self.view endEditing:YES];
    //        [_tf_username safeResignFirstResponder];
    //        [_tf_password safeResignFirstResponder];
    //        [_tf_confirm safeResignFirstResponder];
    //        [_tf_refcode safeResignFirstResponder];
    //    }
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
            [_owner gotoQaView:@"qa_refcode"
                         title:NSLocalizedString(@"kVcTitleWhatIsRefcode", @"什么是推荐码？")];
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
    } else if (indexPath.section == kVcUser) {
        switch (indexPath.row) {
            case kVcSubAccountName:
                return _cell_account.cellHeight;
            case kVcSubPassword:
                return _cell_password.cellHeight;
            case kVcSubConfirmPassword:
                return _cell_confirm.cellHeight;
            case kVcSubRefCode:
                return _cell_refcode.cellHeight;
            default:
                break;
        }
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
                return _cell_account;
                
            case kVcSubPassword:
                return _cell_password;
                
            case kVcSubConfirmPassword:
                return _cell_confirm;
                
            case kVcSubRefCode:
                return _cell_refcode;
                
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

@end
