//
//  VCRegisterEntry.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import "VCRegisterEntry.h"
#import "VCNewAccountPassword.h"
#import "ViewAdvTextFieldCell.h"
#import "ViewTipsInfoCell.h"
#import "OrgUtils.h"

//  ［账号+密码] + [登录]
enum
{
    kVcUser = 0,
    kVcLoginButton,
    //    kVcTips,
    
    kVcMax,
};

enum
{
    kVcSubAccountName = 0,      //  帐号
    
    kVcSubMax
};

@interface VCRegisterEntry ()
{
    UITableView *           _mainTableView;
    
    ViewAdvTextFieldCell*   _cell_account;
    
    ViewBlockLabel*         _lbSubmit;
    //    ViewTipsInfoCell*       _cellTips;
}

@end

@implementation VCRegisterEntry

-(void)dealloc
{
    //    _cellTips = nil;
    _cell_account = nil;
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 账号输入框
    _cell_account = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kLoginCellAccountName", @"帐号 ")
                                                    placeholder:NSLocalizedString(@"kRegTipsPlaceholderNewAccount", @"请输入新的账号名")];
    [_cell_account auxFastConditionsViewForAccountNameFormat];
    
    //  UI - 主列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //    _cellTips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kLoginRegTipsAccountMode", @"提示：账号密码对应格式要求可以点击问号查看。\n注意：BTS++是去中心化区块链应用密码一旦丢失或遗忘将无法找回，请务必妥善保管。")];
    //    _cellTips.hideBottomLine = YES;
    //    _cellTips.hideTopLine = YES;
    //    _cellTips.backgroundColor = [UIColor clearColor];
    
    _lbSubmit = [self createCellLableButton:NSLocalizedString(@"kEditPasswordBtnNext", @"下一步")];
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
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endInput];
}

/**
 *  (private) 下一步。
 */
- (void)process_next_step
{
    //  检测参数有效性
    if (!_cell_account.isAllConditionsMatched) {
        [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountFmtIncorrect", @"帐号格式不正确，请重新输入。")];
        return;
    }
    
    id new_account_name = [_cell_account.mainTextfield.text lowercaseString];
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    [[[[ChainObjectManager sharedChainObjectManager] isAccountExistOnBlockChain:new_account_name] then:^id(id bExist) {
        [self hideBlockView];
        if ([bExist boolValue]) {
            [OrgUtils makeToast:NSLocalizedString(@"kLoginSubmitTipsAccountAlreadyExist", @"帐号名已存在，请重新输入。")];
        } else {
            VCNewAccountPassword* vc = [[VCNewAccountPassword alloc] initWithNewAccountName:new_account_name];
            [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleBackupYourPassword", @"备份密码") backtitle:kVcDefaultBackTitleName];
        }
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self endInput];
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
            case kVcSubAccountName:
                return _cell_account.cellHeight;
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

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcUser)
    {
        switch (indexPath.row) {
            case kVcSubAccountName:
                return _cell_account;
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
        //    }else{
        //        return _cellTips;
    }
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcLoginButton){
            [self process_next_step];
        }
    }];
}

@end
