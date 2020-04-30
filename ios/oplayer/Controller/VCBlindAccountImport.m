//
//  VCBlindAccountImport.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindAccountImport.h"

#import "HDWallet.h"
#import "ViewAdvTextFieldCell.h"

enum
{
    kVcSecAliasName = 0,
    kVcSecBlindPassword,
    kVcSecAction,
    
    kVcSecMax
};

@interface VCBlindAccountImport ()
{
    UITableViewBase*        _mainTableView;
    
    ViewAdvTextFieldCell*   _cell_alias_name;
    ViewAdvTextFieldCell*   _cell_password;
    
    ViewBlockLabel*         _lbCommit;
    
    WsPromiseObject*        _result_promise;
}

@end

@implementation VCBlindAccountImport

-(void)dealloc
{
    _cell_alias_name = nil;
    _cell_password = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbCommit = nil;
    _result_promise = nil;
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 别名输入
    _cell_alias_name = [[ViewAdvTextFieldCell alloc] initWithTitle:@"别名" placeholder:@"为隐私账户设置一个别名"];
    
    //  UI - 密码输入
    _cell_password = [[ViewAdvTextFieldCell alloc] initWithTitle:@"密码"
                                                     placeholder:@"请输入隐私账户密码"];
    
    //  UI - 列表
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  点击事件
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    _lbCommit = [self createCellLableButton:@"导入"];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self endInput];
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
    return kVcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcSecAliasName) {
        return _cell_alias_name.cellHeight;
    } else if (indexPath.section == kVcSecBlindPassword) {
        return _cell_password.cellHeight;
    }
    return tableView.rowHeight;
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
    switch (indexPath.section) {
        case kVcSecAliasName:
            return _cell_alias_name;
            
        case kVcSecBlindPassword:
            return _cell_password;
            
        case kVcSecAction:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
    }
    assert(false);
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcSecAction){
            [self onSubmitClicked];
        }
    }];
}

- (void)onSubmitClicked
{
    [self endInput];
    
    //  TODO:6.0 lang
    id str_alias_name = [NSString trim:_cell_alias_name.mainTextfield.text];
    if (!str_alias_name || [str_alias_name isEqualToString:@""]){
        [OrgUtils makeToast:@"请输入隐私账户别名。"];
        return;
    }
    
    id str_password = [NSString trim:_cell_password.mainTextfield.text];
    if (!str_password || [str_password  isEqualToString:@""]) {
        [OrgUtils makeToast:@"请输入隐私账户密码。"];
        return;
    }
    
    //  开始导入
    HDWallet* hdk = [HDWallet fromMnemonic:str_password];
    HDWallet* main_key = [hdk deriveBitshares:EHDBPT_STEALTH_MAINKEY];
    id wif_main_pri_key = [main_key toWifPrivateKey];
    id wif_main_pub_key = [OrgUtils genBtsAddressFromWifPrivateKey:wif_main_pri_key];
    
    id blind_account = @{
        @"public_key": wif_main_pub_key,
        @"alias_name": str_alias_name,
        @"parent_key": @""
    };
    
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    assert([walletMgr isWalletExist] && ![walletMgr isPasswordMode]);
    //  解锁钱包
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            //  隐私交易主地址导入钱包
            AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
            
            id full_wallet_bin = [walletMgr walletBinImportAccount:nil privateKeyWifList:@[wif_main_pri_key]];
            assert(full_wallet_bin);
            [pAppCache appendBlindAccount:blind_account autosave:NO];
            [pAppCache updateWalletBin:full_wallet_bin];
            [pAppCache autoBackupWalletToWebdir:NO];
            
            //  重新解锁（即刷新解锁后的账号信息）。
            id unlockInfos = [walletMgr reUnlock];
            assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
            
            //  导入成功
            if (_result_promise) {
                [_result_promise resolve:blind_account];
            }
            [self closeOrPopViewController];
        }
    }];
}

- (void)endInput
{
    [self.view endEditing:YES];
    [_cell_alias_name endInput];
    [_cell_password endInput];
}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

@end
