//
//  VCPermissionAddOne.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCPermissionAddOne.h"
#import "VCSearchNetwork.h"

enum
{
    kVcSecBase = 0,
    kVcSecAction,
    
    kVcSecMax
};

enum
{
    kVcSubAuthorityTitle = 0,
    kVcSubAuthorityInput,
    kVcSubThresholdTitle,
    kVcSubThresholdInput,
    kVcSubMax
};

@interface VCPermissionAddOne ()
{
    UITableViewBase*        _mainTableView;
    
    MyTextField*            _tf_authority;
    MyTextField*            _tf_threshold;
    
    ViewBlockLabel*         _lbCommit;
    
    WsPromiseObject*        _result_promise;
}

@end

@implementation VCPermissionAddOne

-(void)dealloc
{
    if (_tf_authority){
        _tf_authority.delegate = nil;
        _tf_authority = nil;
    }
    if (_tf_threshold){
        _tf_threshold.delegate = nil;
        _tf_threshold = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbCommit = nil;
    _result_promise = nil;
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise;
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
    }
    return self;
}

- (void)onSearchAccountClicked:(UIButton*)sender
{
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAccount callback:^(id account_info) {
        if (account_info){
            _tf_authority.text = [account_info objectForKey:@"name"];
        }
    }];
    [self pushViewController:vc
                     vctitle:NSLocalizedString(@"kVcTitleAddOneSearchAccount", @"搜索账号")
                   backtitle:kVcDefaultBackTitleName];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    CGRect rect = [self makeTextFieldRect];
    
    NSString* placeHolderAuthority = NSLocalizedString(@"kVcPermissionAddOnePlaceholderAuthority", @"账号或公钥");
    NSString* placeHolderThreshold = NSLocalizedString(@"kVcPermissionAddOnePlaceholderWeight", @"权重（1-65535）");
    
    _tf_authority = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderAuthority];
    _tf_authority.updateClearButtonTintColor = YES;
    _tf_authority.showBottomLine = YES;
    _tf_authority.textColor = theme.textColorMain;
    _tf_authority.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderAuthority];
    
    _tf_threshold = [self createTfWithRect:rect keyboard:UIKeyboardTypeNumberPad placeholder:placeHolderThreshold];
    _tf_threshold.updateClearButtonTintColor = YES;
    _tf_threshold.showBottomLine = YES;
    _tf_threshold.textColor = theme.textColorMain;
    _tf_threshold.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderThreshold];
    
    //  UI - 管理者输入框末尾按钮
    UIButton* btnSearch = [UIButton buttonWithType:UIButtonTypeSystem];
    btnSearch.titleLabel.font = [UIFont systemFontOfSize:13];
    [btnSearch setTitle:NSLocalizedString(@"kVcPermissionAddOneBtnSearchAccount", @"搜索账号") forState:UIControlStateNormal];
    [btnSearch setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
    btnSearch.userInteractionEnabled = YES;
    btnSearch.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [btnSearch addTarget:self action:@selector(onSearchAccountClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnSearch.frame = CGRectMake(0, 2, 96, 27);
    _tf_authority.rightView = btnSearch;
    _tf_authority.rightViewMode = UITextFieldViewModeAlways;
    
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
    
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcPermissionAddOneBtnDone", @"确定")];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self endInput];
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != _tf_threshold){
        return YES;
    }
    return [OrgUtils isValidAuthorityThreshold:string];
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _tf_authority)
    {
        [_tf_threshold becomeFirstResponder];
    }
    else
    {
        [self endInput];
    }
    return YES;
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecBase) {
        return kVcSubMax;
    } else {
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcSecBase) {
        if (indexPath.row == kVcSubAuthorityTitle || indexPath.row == kVcSubThresholdTitle) {
            return 28.0f;
        }
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
        case kVcSecBase:
        {
            switch (indexPath.row) {
                case kVcSubAuthorityTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kVcPermissionAddOneTitleAuthority", @"管理者");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case kVcSubAuthorityInput:
                {
                    assert(_tf_authority);
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @" ";
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_authority];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                case kVcSubThresholdTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kVcPermissionAddOneTitleWeight", @"权重");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case kVcSubThresholdInput:
                {
                    assert(_tf_threshold);
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @" ";
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_threshold];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        default:
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
    
    id str_authority = [NSString trim:_tf_authority.text];
    if (!str_authority || [str_authority isEqualToString:@""]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionAddOneDoneTipsInvalidAuthority", @"请输入有效的账号或公钥。")];
        return;
    }
    id str_threshold = _tf_threshold.text;
    id n_threshold = [OrgUtils auxGetStringDecimalNumberValue:str_threshold];
    id n_min_threshold = [NSDecimalNumber decimalNumberWithString:@"1"];
    id n_max_threshold = [NSDecimalNumber decimalNumberWithString:@"65535"];
    if ([n_threshold compare:n_min_threshold] < 0 || [n_threshold compare:n_max_threshold] > 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionAddOneDoneTipsInvalidWeight", @"请输入有效的权重值，范围 1 - 65535。")];
        return;
    }
    
    NSInteger i_threshold = [n_threshold integerValue];
    
    //  判断输入的是账号还是公钥
    if ([OrgUtils isValidBitsharesPublicKey:str_authority]) {
        [self onAddOneDone:str_authority
                      name:str_authority
                 isaccount:NO
                 threshold:i_threshold];
    } else {
        //  无效公钥，判断是不是有效的账号名orID。
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[ChainObjectManager sharedChainObjectManager] queryAccountData:str_authority] then:(^id(id accountData) {
            [self hideBlockView];
            if (accountData && [accountData objectForKey:@"id"] && [accountData objectForKey:@"name"]) {
                id new_oid = [accountData objectForKey:@"id"];
                id account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
                assert(account);
                if ([[account objectForKey:@"id"] isEqualToString:new_oid]) {
                    [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionAddOneDontTipsCantAddSelf", @"不能添加自身账号。")];
                } else {
                    [self onAddOneDone:new_oid
                                  name:[accountData objectForKey:@"name"]
                             isaccount:YES
                             threshold:i_threshold];
                }
            } else {
                [OrgUtils makeToast:NSLocalizedString(@"kVcPermissionAddOneDoneTipsInvalidAuthority", @"请输入有效的账号或公钥。")];
            }
            return nil;
        })];
    }
}

/**
 *  (private) 完成添加
 */
- (void)onAddOneDone:(NSString*)key name:(NSString*)name isaccount:(BOOL)isaccount threshold:(NSInteger)threshold
{
    if (_result_promise) {
        [_result_promise resolve:@{@"key":key, @"name":name, @"isaccount":@(isaccount), @"threshold":@(threshold)}];
    }
    [self closeOrPopViewController];
}

- (void)endInput
{
    [self.view endEditing:YES];
    if (_tf_authority) {
        [_tf_authority safeResignFirstResponder];
    }
    if (_tf_threshold) {
        [_tf_threshold safeResignFirstResponder];
    }
}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

@end
