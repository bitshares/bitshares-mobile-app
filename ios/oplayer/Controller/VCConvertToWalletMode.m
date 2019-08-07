//
//  VCConvertToWalletMode.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import <QuartzCore/QuartzCore.h>

#import "VCConvertToWalletMode.h"
#import "BitsharesClientManager.h"
#import "WalletManager.h"
#import "OrgUtils.h"

#import <Crashlytics/Crashlytics.h>

@interface VCConvertToWalletMode ()
{
    BtsppCloseCallback      _callback;
    
    UITableView*            _mainTableView;
    
    MyTextField*            _tf_password;
    MyTextField*            _tf_wallet_password;
    ViewBlockLabel*         _lbCreate;
}

@end

@implementation VCConvertToWalletMode

-(void)dealloc
{
    if (_tf_password){
        _tf_password.delegate = nil;
        _tf_password = nil;
    }
    if (_tf_wallet_password){
        _tf_wallet_password.delegate = nil;
        _tf_wallet_password = nil;
    }
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbCreate = nil;
    _callback = nil;
}

- (id)initWithCallback:(BtsppCloseCallback)callback
{
    self = [super init];
    if (self) {
        _callback = callback;
    }
    return self;
}

//- (void)onCancelButtonClicked:(id)sender
//{
//    [self closeModelViewController:nil];
//}

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
    
    assert([[WalletManager sharedWalletManager] isPasswordMode]);
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  导航条按钮
//    [self showLeftButton:NSLocalizedString(@"kBtnCancel", @"取消") action:@selector(onCancelButtonClicked:)];
    
    //  account basic infos
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    id wallet_info = [[WalletManager sharedWalletManager] getWalletAccountInfo];
    
    UILabel* headerAccountName = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width, 44)];
    headerAccountName.lineBreakMode = NSLineBreakByWordWrapping;
    headerAccountName.numberOfLines = 1;
    headerAccountName.contentMode = UIViewContentModeCenter;
    headerAccountName.backgroundColor = [UIColor clearColor];
    headerAccountName.textColor = [ThemeManager sharedThemeManager].textColorMain;
    headerAccountName.textAlignment = NSTextAlignmentCenter;
    headerAccountName.font = [UIFont boldSystemFontOfSize:26];
    headerAccountName.text = [[wallet_info objectForKey:@"account"] objectForKey:@"name"];
    [self.view addSubview:headerAccountName];
    
    UILabel* headerViewId = [[UILabel alloc] initWithFrame:CGRectMake(0, 44, screenRect.size.width, 22)];
    headerViewId.lineBreakMode = NSLineBreakByWordWrapping;
    headerViewId.numberOfLines = 1;
    headerViewId.contentMode = UIViewContentModeCenter;
    headerViewId.backgroundColor = [UIColor clearColor];
    headerViewId.textColor = [ThemeManager sharedThemeManager].textColorMain;
    headerViewId.textAlignment = NSTextAlignmentCenter;
    headerViewId.font = [UIFont boldSystemFontOfSize:14];
    headerViewId.text = [NSString stringWithFormat:@"#%@", [[[[wallet_info objectForKey:@"account"] objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject]];
    [self.view addSubview:headerViewId];
    
    CGRect rect = [self makeTextFieldRect];
    
    //  account password
    NSString* placeHolder = NSLocalizedString(@"unlockTipsPleaseInputAccountPassword", @"请输入帐号密码");
    _tf_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolder];
    _tf_password.secureTextEntry = YES;
    _tf_password.updateClearButtonTintColor = YES;
    _tf_password.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolder
                                                                     attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                  NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    //  wallet password
    _tf_wallet_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault
                                     placeholder:NSLocalizedString(@"kLoginTipsPlaceholderWalletPassword", @"8位以上钱包文件密码")
                                          action:@selector(onTipButtonClicked:) tag:1];
    _tf_wallet_password.secureTextEntry = YES;
    _tf_wallet_password.updateClearButtonTintColor = YES;
    _tf_wallet_password.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_wallet_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_tf_wallet_password.placeholder
                                                                                attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                             NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    //  tableview list
    CGFloat offset = 66;
    _mainTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, offset,
                                                                   screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - offset)
                                                  style:UITableViewStyleGrouped];
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    [self.view addSubview:_mainTableView];
    
    //  点击事件
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  创建钱包
    _lbCreate = [self createCellLableButton:NSLocalizedString(@"kNormalCellBtnCreateWallet", @"创建钱包")];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    //  回调
    if (_callback){
        [self delay:^{
            _callback();
        }];
    }
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    [_tf_wallet_password safeResignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onSubmitButtonClicked
{
    NSString* password = [NSString trim:_tf_password.text];
    NSString* wallet_password = [NSString trim:_tf_wallet_password.text];
    
    if ([self isStringEmpty:password])
    {
        [OrgUtils makeToast:NSLocalizedString(@"kMsgPasswordCannotBeNull", @"密码不能为空，请重新输入。")];
        return;
    }
    
    if (![OrgUtils isValidBitsharesWalletPassword:wallet_password]){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsWalletPasswordFmtIncorrect", @"钱包密码格式不正确，请重新输入。")];
        return;
    }
    
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    [_tf_wallet_password safeResignFirstResponder];
    
    //  1、再次验证账号密码是否正确
    id fullAccountData = [[WalletManager sharedWalletManager] getWalletAccountInfo];
    assert(fullAccountData);
    id accountName = [[[fullAccountData objectForKey:@"account"] objectForKey:@"name"] copy];
    
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    id currUnlockInfos = [walletMgr unLock:password];
    if (!(currUnlockInfos &&
          [[currUnlockInfos objectForKey:@"unlockSuccess"] boolValue] &&
          [[currUnlockInfos objectForKey:@"haveActivePermission"] boolValue])){
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountPasswordIncorrect", @"密码不正确，请重新输入。")];
        return;
    }
    
    //  2、验证通过，开始创建钱包文件。
    id active_seed = [NSString stringWithFormat:@"%@active%@", accountName, password];
    id active_private_wif = [OrgUtils genBtsWifPrivateKey:active_seed];
    id owner_seed = [NSString stringWithFormat:@"%@owner%@", accountName, password];
    id owner_private_wif = [OrgUtils genBtsWifPrivateKey:owner_seed];
    assert(owner_private_wif);
    assert(active_private_wif);
    id full_wallet_bin = [walletMgr genFullWalletData:accountName
                                     private_wif_keys:@[active_private_wif, owner_private_wif]
                                      wallet_password:wallet_password];
    assert(full_wallet_bin);
    
    //  3、保存钱包信息
    [[AppCacheManager sharedAppCacheManager] setWalletInfo:kwmPasswordWithWallet
                                               accountInfo:fullAccountData
                                               accountName:accountName
                                             fullWalletBin:full_wallet_bin];
    [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
    
    //  4、导入成功 用钱包密码 直接解锁。
    id unlockInfos = [walletMgr unLock:wallet_password];
    assert(unlockInfos &&
           [[unlockInfos objectForKey:@"unlockSuccess"] boolValue] &&
           [[unlockInfos objectForKey:@"haveActivePermission"] boolValue]);
    
    //  [统计]
    [OrgUtils logEvents:@"convertEvent" params:@{@"mode":@(kwmPasswordWithWallet), @"desc":@"password+wallet"}];
    
    //  转换成功 - 关闭界面
    [self.myNavigationController tempDisableDragBack];
    [OrgUtils showMessageUseHud:NSLocalizedString(@"kLblTipsConvertToWalletModeDone", @"创建钱包完毕。")
                           time:1
                         parent:self.navigationController.view
                completionBlock:^{
                    [self.myNavigationController tempEnableDragBack];
                    [self.navigationController popViewControllerAnimated:YES];
                }];
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _tf_password)
    {
        [_tf_wallet_password becomeFirstResponder];
    }
    else
    {
        [self.view endEditing:YES];
        [_tf_wallet_password safeResignFirstResponder];
    }
    return YES;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    //  password & submit
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    //  account password & wallet password
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0){
        if (indexPath.row == 0){
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = NSLocalizedString(@"kLoginPassword", @"密码 ");
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.accessoryView = _tf_password;
            return cell;
        }else{
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
    }else{
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.hideBottomLine = YES;
        cell.hideTopLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_lbCreate cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == 1){
            [self onSubmitButtonClicked];
        }
    }];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    [_tf_wallet_password safeResignFirstResponder];
}

@end
