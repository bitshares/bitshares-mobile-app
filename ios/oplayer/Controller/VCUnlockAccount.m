//
//  VCUnlockAccount.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import <QuartzCore/QuartzCore.h>

#import "VCUnlockAccount.h"
#import "BitsharesClientManager.h"
#import "WalletManager.h"
#import "OrgUtils.h"

#import <Crashlytics/Crashlytics.h>

@interface VCUnlockAccount ()
{
    UnlockCallback          _callback;
    
    UITableView *           _mainTableView;
    
    MyTextField*            _tf_password;
    ViewBlockLabel*         _lbLogin;
}

@end

@implementation VCUnlockAccount

-(void)dealloc
{
    _callback = nil;
    
    if (_tf_password){
        _tf_password.delegate = nil;
        _tf_password = nil;
    }
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    
    _lbLogin = nil;
}

- (id)initWithUnlockCallback:(UnlockCallback)callback
{
    self = [super init];
    if (self) {
        _callback = callback;
    }
    return self;
}

- (void)onCancelButtonClicked:(id)sender
{
    [self closeModelViewController:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  导航条按钮
    [self showLeftButton:NSLocalizedString(@"kBtnCancel", @"取消") action:@selector(onCancelButtonClicked:)];
    
    //  帐号信息
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
    
    NSString* placeHolder = @"";
    switch ([[WalletManager sharedWalletManager] getWalletMode]) {
        case kwmPasswordOnlyMode:
            placeHolder = NSLocalizedString(@"unlockTipsPleaseInputAccountPassword", @"请输入帐号密码");
            break;
        case kwmPasswordWithWallet:
        case kwmPrivateKeyWithWallet:
        case kwmBrainKeyWithWallet:
            placeHolder = NSLocalizedString(@"unlockTipsPleaseInputTradePassword", @"请输入交易密码");
            break;
        case kwmFullWalletMode:
            placeHolder = NSLocalizedString(@"unlockTipsPleaseInputWalletPassword", @"请输入钱包密码");
            break;
        default:
            assert(false);
            break;
    }
    _tf_password = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolder];
    _tf_password.secureTextEntry = YES;
    _tf_password.updateClearButtonTintColor = YES;
    _tf_password.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_password.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolder
                                                                     attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                  NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
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
    
    //  登录按钮
    _lbLogin = [self createCellLableButton:@"解锁"];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //  解锁回调
    if (_callback){
        [self delay:^{
            _callback(![[WalletManager sharedWalletManager] isLocked]);
        }];
    }
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onUnlockButtonCLicked
{
    NSString* password = [NSString trim:_tf_password.text];
    
    if ([self isStringEmpty:password])
    {
        [OrgUtils showMessage:NSLocalizedString(@"kMsgPasswordCannotBeNull", @"密码不能为空，请重新输入。")
                    withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")];
        return;
    }
    
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    
    //  执行解锁逻辑
    id unlockInfos = [[WalletManager sharedWalletManager] unLock:password];
    if ([[unlockInfos objectForKey:@"unlockSuccess"] boolValue] && [[unlockInfos objectForKey:@"haveActivePermission"] boolValue]){
        //  解锁完成，关闭VC。
        [self closeModelViewController:nil];
    }else{
        [OrgUtils makeToast:[unlockInfos objectForKey:@"err"]];
    }
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
    return YES;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
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
    }
    else
    {
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
        if (indexPath.section == 1){
            [self onUnlockButtonCLicked];
        }
    }];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
    [_tf_password safeResignFirstResponder];
}

@end
