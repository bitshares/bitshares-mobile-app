//
//  VCScanTransfer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCScanTransfer.h"
#import "BitsharesClientManager.h"

enum
{
    kVcSectionInfo = 0,
    kVcSectionAction,
    kVcSectionMax
};

enum
{
    kVcSubAmountTitle = 0,  //  转账金额（标题） + 可用余额
    kVcSubAmountTextField,  //  转账金额输入框
    kVcSubAmountLocked,     //  转账金额（锁定的、不可编辑）
    
    kVcSubEmpty,            //  空行（间隔用）
    
    kVcSubMemoTitle,        //  备注信息（标题）
    kVcSubMemoTextField,    //  备注信息输入框
    kVcSubMemoLocked        //  备注信息（锁定的、不可编辑）
};

@interface VCScanTransfer ()
{
    NSDictionary*           _to_account;
    NSDictionary*           _asset;
    
    NSString*               _default_amount;
    NSString*               _default_memo;
    
    UITableViewBase*        _mainTableView;
    ViewBlockLabel*         _btnCommit;

    MyTextField*            _tf_amount;
    MyTextField*            _tf_memo;
    
    NSArray*                _dataArray;
}

@end

@implementation VCScanTransfer

-(void)dealloc
{
    if (_tf_amount){
        _tf_amount.delegate = nil;
        _tf_amount = nil;
    }
    if (_tf_memo) {
        _tf_memo.delegate = nil;
        _tf_memo = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _dataArray = nil;
    _btnCommit = nil;
    _default_amount = nil;
    _default_memo = nil;
    _to_account = nil;
    _asset = nil;
}

- (id)initWithTo:(NSDictionary*)to_account asset:(NSDictionary*)asset amount:(NSString*)amount memo:(NSString*)memo
{
    self = [super init];
    if (self) {
        assert(to_account);
        assert(asset);
        _to_account = to_account;
        _asset = asset;
        _default_amount = amount;
        _default_memo = memo;
    }
    return self;
}

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
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  背景颜色
    self.view.backgroundColor = theme.appBackColor;
    
    //  account basic infos
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    UILabel* headerAccountName = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width, 44)];
    headerAccountName.lineBreakMode = NSLineBreakByWordWrapping;
    headerAccountName.numberOfLines = 1;
    headerAccountName.contentMode = UIViewContentModeCenter;
    headerAccountName.backgroundColor = [UIColor clearColor];
    headerAccountName.textColor = [ThemeManager sharedThemeManager].buyColor;
    headerAccountName.textAlignment = NSTextAlignmentCenter;
    headerAccountName.font = [UIFont boldSystemFontOfSize:26];
    headerAccountName.text = [_to_account objectForKey:@"name"];
    [self.view addSubview:headerAccountName];
    
    UILabel* headerViewId = [[UILabel alloc] initWithFrame:CGRectMake(0, 44, screenRect.size.width, 22)];
    headerViewId.lineBreakMode = NSLineBreakByWordWrapping;
    headerViewId.numberOfLines = 1;
    headerViewId.contentMode = UIViewContentModeCenter;
    headerViewId.backgroundColor = [UIColor clearColor];
    headerViewId.textColor = [ThemeManager sharedThemeManager].textColorMain;
    headerViewId.textAlignment = NSTextAlignmentCenter;
    headerViewId.font = [UIFont boldSystemFontOfSize:14];
    
    headerViewId.text = [NSString stringWithFormat:@"#%@", [[[_to_account objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject]];
    [self.view addSubview:headerViewId];
    
    //  初始化UI
    NSString* placeHolderAmount = NSLocalizedString(@"kVcTransferTipInputSendAmount", @"请输入转账金额");
//    CGRect rect = [self makeTextFieldRect];
    _tf_amount = [self createTfWithRect:[self makeTextFieldRectFull] keyboard:UIKeyboardTypeDecimalPad placeholder:placeHolderAmount];
    _tf_amount.showBottomLine = YES;
    
    _tf_amount.updateClearButtonTintColor = YES;
    _tf_amount.textColor = theme.textColorMain;
    _tf_amount.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderAmount
                                                                       attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
                                                                                    NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    //  绑定输入事件（限制输入）
    [_tf_amount addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 转账数量尾部辅助按钮
    
    UILabel* tailer_total_price = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 31)];
    tailer_total_price.lineBreakMode = NSLineBreakByTruncatingTail;
    tailer_total_price.numberOfLines = 1;
    tailer_total_price.textAlignment = NSTextAlignmentRight;
    tailer_total_price.backgroundColor = [UIColor clearColor];
    tailer_total_price.textColor = [ThemeManager sharedThemeManager].textColorMain;
    tailer_total_price.font = [UIFont systemFontOfSize:14];
    tailer_total_price.text = [_asset objectForKey:@"symbol"];
    
    _tf_amount.rightView = tailer_total_price;
    _tf_amount.rightViewMode = UITextFieldViewModeAlways;
    
    
    NSString* placeHolderMemo = NSLocalizedString(@"kVcTransferTipInputMemo", @"请输入备注信息（可选）");
    CGRect rect = [self makeTextFieldRect];
    _tf_memo = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderMemo];
    
    //  设置属性颜色等
    _tf_memo.updateClearButtonTintColor = YES;
    _tf_memo.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_memo.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderMemo
                                                                     attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                  NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_memo.showBottomLine = YES;
    
    _dataArray = [[[NSMutableArray array] ruby_apply:(^(id obj) {
        //  amount
        if (_default_amount && ![_default_amount isEqualToString:@""]) {
            [obj addObject:@(kVcSubAmountLocked)];
        } else {
            [obj addObject:@(kVcSubAmountTitle)];
            [obj addObject:@(kVcSubAmountTextField)];
            [obj addObject:@(kVcSubEmpty)];
        }
        //  memo
        if (_default_memo && ![_default_memo isEqualToString:@""]) {
            [obj addObject:@(kVcSubMemoLocked)];
        } else {
            [obj addObject:@(kVcSubMemoTitle)];
            [obj addObject:@(kVcSubMemoTextField)];
        }
    })] copy];
    
    CGFloat offset = 66;
    _mainTableView = [[UITableViewBase alloc] initWithFrame:CGRectMake(0, offset,
                                                                       screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - offset)
                                                      style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  点击事件
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    
    
    _btnCommit = [self createCellLableButton:@"立即支付"];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self endInput];
}

//- (void)onAmountAllButtonClicked:(UIButton*)sender
//{
//    _tf_amount.text = @"33";//TODO: [OrgUtils formatFloatValue:_n_available usesGroupingSeparator:NO];
//    [self onAmountChanged];
//}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != _tf_amount){
        return YES;
    }
    
    return YES;
    //  TODO:
//    id asset = [_transfer_args objectForKey:@"asset"];
//    assert(asset);
//
//    return [OrgUtils isValidAmountOrPriceInput:textField.text
//                                         range:range
//                                    new_string:string
//                                     precision:[[asset objectForKey:@"precision"] integerValue]];
}

- (void)onTextFieldDidChange:(UITextField*)textField
{
    if (textField != _tf_amount){
        return;
    }
    
    //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
    [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
    
    [self onAmountChanged];
}

/**
 *  (private) 转账数量发生变化。
 */
- (void)onAmountChanged
{
    //  TODO：xxx
    
//    id asset = [_transfer_args objectForKey:@"asset"];
//    assert(asset);
//
//    id str_amount = _tf_amount.text;
//
//    //  无效输入
//    if (!str_amount || [str_amount isEqualToString:@""]){
//        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", [OrgUtils formatFloatValue:_n_available], [asset objectForKey:@"symbol"]];
//        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//        return;
//    }
//
//    //  获取输入的数量
//    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
//
//    //  _n_available < n_amount
//    if ([_n_available compare:n_amount] == NSOrderedAscending){
//        //  数量不足
//        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@%@(%@)", [OrgUtils formatFloatValue:_n_available], [asset objectForKey:@"symbol"], NSLocalizedString(@"kVcTransferTipAmountNotEnough", @"数量不足")];
//        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].tintColor;
//    }else{
//        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", [OrgUtils formatFloatValue:_n_available], [asset objectForKey:@"symbol"]];
//        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
//    }
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self endInput];
    //  TODO:memo tf
//    if (textField == _tf_amount)
//    {
//        [_tf_preimage_or_hash becomeFirstResponder];
//    }
//    else
//    {
//        [self.view endEditing:YES];
//        [_tf_amount safeResignFirstResponder];
//        [_tf_preimage_or_hash safeResignFirstResponder];
//    }
    return YES;
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    [self endInput];
    
    //  确认界面由于时间经过可能又被 lock 了。
    [self GuardWalletUnlocked:^(BOOL unlocked) {
//        if (unlocked){
//            _bResultCannelled = NO;
//            [self closeModelViewController:nil];
//        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcSectionMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSectionInfo)
        return [_dataArray count];
    else
        return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcSectionInfo) {
        switch ([[_dataArray objectAtIndex:indexPath.row] integerValue]) {
            case kVcSubAmountTitle:
            case kVcSubMemoTitle:
                return 28.0f;
            case kVcSubEmpty:
                return 12.0f;
            default:
                break;
        }
    }
    return tableView.rowHeight;
}

///**
// *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
// */
//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
//{
//    return 10.0f;
//}
//- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//    return @" ";
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
//{
//    return 10.0f;
//}
//- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
//{
//    return @" ";
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSectionInfo:
        {
            switch ([[_dataArray objectAtIndex:indexPath.row] integerValue]) {
                case kVcSubAmountTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @"金额";//TODO: NSLocalizedString(@"kVcDWCellWithdrawAddress", @"提币地址");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    
                    cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.detailTextLabel.text = @"可用 33CNY";
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
                    return cell;
                }
                    break;
                case kVcSubAmountTextField:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @" ";
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_amount];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                case kVcSubAmountLocked:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.showCustomBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    cell.textLabel.text = @"金额";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", _default_amount, _asset[@"symbol"]];
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
                    
                    return cell;
                }
                    break;
                    
                case kVcSubEmpty:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @" ";
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;

                case kVcSubMemoTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @"备注";//TODO: NSLocalizedString(@"kVcDWCellWithdrawAddress", @"提币地址");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;

                }
                    break;
                case kVcSubMemoTextField:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @" ";
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_memo];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                case kVcSubMemoLocked:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.showCustomBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    cell.textLabel.text = @"备注";
                    cell.detailTextLabel.text = _default_memo;
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
                    
                    return cell;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case kVcSectionAction:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_btnCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == kVcSectionAction){
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self onCommitCore];
        }];
    }
}

- (void)endInput
{
    [self.view endEditing:YES];
    [_tf_amount safeResignFirstResponder];
    [_tf_memo safeResignFirstResponder];
}

//- (BOOL)textFieldShouldReturn:(UITextField*)textField
//{
//    [self endInput];
//    return YES;
//}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

@end
