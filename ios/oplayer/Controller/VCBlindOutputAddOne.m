//
//  VCBlindOutputAddOne.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindOutputAddOne.h"

#import "VCBlindAccounts.h"
#import "VCSearchNetwork.h"
#import "ViewAdvTextFieldCell.h"

enum
{
    kVcSecBlindTo = 0,
    kVcSecBlindAmount,
    kVcSecAction,
    
    kVcSecMax
};

@interface VCBlindOutputAddOne ()
{
    NSDictionary*           _asset;
    NSDecimalNumber*        _n_max_balance;
    
    UITableViewBase*        _mainTableView;
    
    MyTextField*            _tf_authority;
    ViewAdvTextFieldCell*   _cell_amount;
    
    ViewBlockLabel*         _lbCommit;
    
    WsPromiseObject*        _result_promise;
}

@end

@implementation VCBlindOutputAddOne

-(void)dealloc
{
    if (_tf_authority){
        _tf_authority.delegate = nil;
        _tf_authority = nil;
    }
    _cell_amount = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbCommit = nil;
    _result_promise = nil;
    _asset = nil;
    _n_max_balance = nil;
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise asset:(NSDictionary*)asset n_max_balance:(NSDecimalNumber*)n_max_balance;
{
    self = [super init];
    if (self) {
        assert(asset);
        _result_promise = result_promise;
        _asset = asset;
        _n_max_balance = n_max_balance;
    }
    return self;
}

- (void)onMyBlindAccountClicked:(UIButton*)sender
{
    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    VCBlindAccounts* vc = [[VCBlindAccounts alloc] initWithResultPromise:result_promise];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleSelectBlindAccount", @"选择隐私账户") backtitle:kVcDefaultBackTitleName];
    [result_promise then:^id(id blind_account) {
        if (blind_account) {
            _tf_authority.text = [blind_account objectForKey:@"public_key"] ?: @"";
        }
        return nil;
    }];
}

- (void)onAmountTailerClicked:(UIButton*)sender
{
    assert(_n_max_balance);
    _cell_amount.mainTextfield.text = [OrgUtils formatFloatValue:_n_max_balance usesGroupingSeparator:NO];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    CGRect rect = [self makeTextFieldRect];
    
    NSString* placeHolderAuthority = NSLocalizedString(@"kVcStCellPlaceholderOutputAccountAddr", @"请输入您或他人的隐私账户");
    _tf_authority = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderAuthority];
    _tf_authority.updateClearButtonTintColor = YES;
    _tf_authority.showBottomLine = YES;
    _tf_authority.textColor = theme.textColorMain;
    _tf_authority.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderAuthority];
    
    //  UI - 管理者输入框末尾按钮
    //  TODO:6.0 扫一扫？
    UIButton* btnSearch = [UIButton buttonWithType:UIButtonTypeSystem];
    btnSearch.titleLabel.font = [UIFont systemFontOfSize:13];
    [btnSearch setTitle:NSLocalizedString(@"kVcStCellTailerButtonMyAccounts", @"联系人") forState:UIControlStateNormal];
    [btnSearch setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
    btnSearch.userInteractionEnabled = YES;
    btnSearch.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [btnSearch addTarget:self action:@selector(onMyBlindAccountClicked:) forControlEvents:UIControlEventTouchUpInside];
    btnSearch.frame = CGRectMake(0, 2, 96, 27);
    _tf_authority.rightView = btnSearch;
    _tf_authority.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 数量输入框
    _cell_amount = [[ViewAdvTextFieldCell alloc] initWithTitle:NSLocalizedString(@"kVcStCellTitleOutputAmount", @"数量")
                                                   placeholder:NSLocalizedString(@"kVcStCellPlaceholderOutputAmount", @"请输入输出数量")
                                              decimalPrecision:[[_asset objectForKey:@"precision"] integerValue]];
    if (_n_max_balance) {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           _n_max_balance,
                           _asset[@"symbol"]];
        _cell_amount.labelValue.text = value;
        [_cell_amount genTailerAssetNameAndButtons:_asset[@"symbol"]
                                      button_names:@[NSLocalizedString(@"kLabelSendAll", @"全部")]
                                            target:self
                                            action:@selector(onAmountTailerClicked:)];
    } else {
        [_cell_amount genTailerAssetName:_asset[@"symbol"]];
    }
    
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
    if (section == kVcSecBlindTo) {
        return 2;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcSecBlindTo) {
        if (indexPath.row == 0) {
            return 28.0f;
        }
    } else if (indexPath.section == kVcSecBlindAmount) {
        return _cell_amount.cellHeight;
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
        case kVcSecBlindTo:
        {
            switch (indexPath.row) {
                case 0:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleBlindAccount", @"隐私账户");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case 1:
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
                default:
                    break;
            }
        }
            break;
        case kVcSecBlindAmount:
            return _cell_amount;
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
    
    id str_authority = [NSString trim:_tf_authority.text];
    if (!str_authority || [str_authority isEqualToString:@""] || ![OrgUtils isValidBitsharesPublicKey:str_authority]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipPleaseInputValidBlindAccountAddr", @"请输入有效的公钥地址。")];
        return;
    }
    
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:_cell_amount.mainTextfield.text];
    if ([n_amount compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipPleaseInputOutputAmountValue", @"请输入输出数量。")];
        return;
    }
    
    [self onAddOneDone:str_authority n_amount:n_amount];
}

/**
 *  (private) 完成添加
 */
- (void)onAddOneDone:(NSString*)public_key n_amount:(NSDecimalNumber*)n_amount
{
    if (_result_promise) {
        [_result_promise resolve:@{@"public_key":public_key, @"n_amount":n_amount}];
    }
    [self closeOrPopViewController];
}

- (void)endInput
{
    [self.view endEditing:YES];
    if (_tf_authority) {
        [_tf_authority safeResignFirstResponder];
    }
    [_cell_amount endInput];
}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

@end
