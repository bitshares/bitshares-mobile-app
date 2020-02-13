//
//  VCAssetOpIssue.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetOpIssue.h"
#import "VCSearchNetwork.h"
#import "BitsharesClientManager.h"

enum
{
    kVcSectionInfo = 0,
    kVcSectionAction,
    kVcSectionMax
};

enum
{
    kVcSubToTitle = 0,      //  发行给
    kVcSubToValue,
    
    kVcSubAmountTextField,  //  发行数量输入框
    
    kVcSubEmpty,            //  空行（间隔用）
    
    kVcSubMemoTitle,        //  备注信息（标题）
    kVcSubMemoTextField,    //  备注信息输入框
    
    kVcSubMaxSupply,        //  最大发行量
    kVcSubCurSupply,        //  当前发行量
};

@interface VCAssetOpIssue ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _to_account;
    NSDictionary*               _asset;
    NSDictionary*               _dynamic_asset_data;
    NSInteger                   _precision;
    NSDecimalNumber*            _n_max_supply;
    NSDecimalNumber*            _n_cur_supply;
    NSDecimalNumber*            _n_balance;
    
    UITableViewBase*            _mainTableView;
    ViewBlockLabel*             _btnCommit;
    
    ViewTextFieldAmountCell*    _tf_amount;
    MyTextField*                _tf_memo;
    
    NSArray*                    _dataArray;
}

@end

@implementation VCAssetOpIssue

-(void)dealloc
{
    if (_tf_amount) {
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
    _to_account = nil;
    _asset = nil;
    _result_promise = nil;
}

- (id)initWithAsset:(NSDictionary*)asset dynamic_asset_data:(id)dynamic_asset_data result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        assert(asset);
        assert(dynamic_asset_data);
        _result_promise = result_promise;
        _to_account = nil;
        _asset = asset;
        _dynamic_asset_data = dynamic_asset_data;
        _precision = [[_asset objectForKey:@"precision"] integerValue];
        _n_max_supply = [NSDecimalNumber decimalNumberWithMantissa:[[[_asset objectForKey:@"options"] objectForKey:@"max_supply"] unsignedLongLongValue]
                                                          exponent:-_precision
                                                        isNegative:NO];
        _n_cur_supply = [NSDecimalNumber decimalNumberWithMantissa:[[_dynamic_asset_data objectForKey:@"current_supply"] unsignedLongLongValue]
                                                          exponent:-_precision
                                                        isNegative:NO];
        _n_balance = [_n_max_supply decimalNumberBySubtracting:_n_cur_supply];
        //  REMARK：发行出去之后又更新了最大供应量，则最大供应量可能小于当前供应量，则这里可能为负数。
        if ([_n_balance compare:[NSDecimalNumber zero]] < 0) {
            _n_balance = [NSDecimalNumber zero];
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  背景颜色
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 数量输入框
    _tf_amount = [[ViewTextFieldAmountCell alloc] initWithTitle:NSLocalizedString(@"kVcAssetOpCellTitleIssueAmount", @"发行数量")
                                                    placeholder:NSLocalizedString(@"kVcAssetOpCellPlaceholderIssueAmount", @"请输入发行数量")
                                                         tailer:[_asset objectForKey:@"symbol"]];
    _tf_amount.delegate = self;
    [self _drawUI_Balance:NO];
    
    //  UI - 备注输入框
    NSString* placeHolderMemo = NSLocalizedString(@"kVcTransferTipInputMemo", @"请输入备注信息（可选）");
    CGRect rect = [self makeTextFieldRect];
    _tf_memo = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderMemo];
    _tf_memo.updateClearButtonTintColor = YES;
    _tf_memo.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_memo.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderMemo];
    _tf_memo.showBottomLine = YES;
    
    _dataArray = [[[NSMutableArray array] ruby_apply:(^(id obj) {
        //  to
        [obj addObject:@(kVcSubToTitle)];
        [obj addObject:@(kVcSubToValue)];
        [obj addObject:@(kVcSubEmpty)];
        
        //  amount
        [obj addObject:@(kVcSubAmountTextField)];
        [obj addObject:@(kVcSubEmpty)];
        
        //  memo
        [obj addObject:@(kVcSubMemoTitle)];
        [obj addObject:@(kVcSubMemoTextField)];
        [obj addObject:@(kVcSubEmpty)];
        
        //  max & cur supply
        [obj addObject:@(kVcSubMaxSupply)];
        [obj addObject:@(kVcSubCurSupply)];
    })] copy];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi]
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
    
    //  按钮
    _btnCommit = [self createCellLableButton:NSLocalizedString(@"kVcAssetOpCellBtnNameIssueAsset", @"发行")];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self endInput];
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _tf_memo) {
        return YES;
    }
    return [OrgUtils isValidAmountOrPriceInput:textField.text range:range new_string:string precision:_precision];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _tf_memo) {
        [self endInput];
    } else {
        [_tf_memo becomeFirstResponder];
    }
    return YES;
}

- (void)_drawUI_Balance:(BOOL)not_enough
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    NSString* symbol = [_asset objectForKey:@"symbol"];
    if (not_enough) {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@(%@)",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           [OrgUtils formatFloatValue:_n_balance],
                           symbol,
                           NSLocalizedString(@"kOtcMcAssetTransferBalanceNotEnough", @"余额不足")];
        [_tf_amount drawUI_titleValue:value color:theme.tintColor];
    } else {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           [OrgUtils formatFloatValue:_n_balance],
                           symbol];
        [_tf_amount drawUI_titleValue:value color:theme.textColorMain];
    }
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    [self endInput];
    
    if (!_to_account) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpSubmitTipsIssuePleaseSelectTargetAccount", @"请选择发行目标账号。")];
        return;
    }
    
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_amount compare:n_zero] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpSubmitTipsIssuePleaseInputIssueAmount", @"请输入发行数量。")];
        return;
    }
    
    //  _n_balance < n_amount
    if ([_n_balance compare:n_amount] < 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpSubmitTipsIssueNotEnough", @"超过剩余可发行数量。")];
        return;
    }
    
    //  获取备注(memo)信息
    NSString* str_memo = _tf_memo.text;
    if (!str_memo || str_memo.length == 0){
        str_memo = nil;
    }
    
    //  --- 参数大部分检测合法 执行请求 ---
    id value = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpSubmitAskIssue", @"您确认发行 %@ %@ 给 %@ 吗？"),
                [OrgUtils formatFloatValue:n_amount], _asset[@"symbol"], _to_account[@"name"]];
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            id from = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
            assert(from);
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked){
                    [self _processIssueAssetCore:from to:_to_account asset:_asset amount:n_amount memo:str_memo];
                }
            }];
        }
    }];
}

-(void)_processIssueAssetCore:(id)from
                           to:(id)to
                        asset:(id)asset
                       amount:(id)n_amount
                         memo:(NSString*)memo
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //  构造请求
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id fetch_to = memo ? [chainMgr queryFullAccountInfo:to[@"id"]] : [NSNull null];
    [[[WsPromise all:@[fetch_to]] then:(^id(id data_array) {
        //  生成 memo 对象。
        id memo_object = [NSNull null];
        if (memo){
            id from_public_memo = [[from objectForKey:@"options"] objectForKey:@"memo_key"];
            id to_full_account_data = data_array[0];
            id to_public = [[[to_full_account_data objectForKey:@"account"] objectForKey:@"options"] objectForKey:@"memo_key"];
            memo_object = [[WalletManager sharedWalletManager] genMemoObject:memo from_public:from_public_memo to_public:to_public];
            if (!memo_object){
                [self hideBlockView];
                [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipWalletNoMemoKey", @"没有备注私钥信息，不支持填写备注。")];
                return nil;
            }
        }
        //  --- 开始构造OP ---
        id n_amount_pow = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:[asset[@"precision"] integerValue]]];
        id fee_asset_id = chainMgr.grapheneCoreAssetID;
        id op = @{
            @"fee":@{
                    @"amount":@0,
                    @"asset_id":fee_asset_id,
            },
            @"issuer":from[@"id"],
            @"asset_to_issue":@{
                    @"amount":@([n_amount_pow unsignedLongLongValue]),
                    @"asset_id":asset[@"id"],
            },
            @"issue_to_account":to[@"id"],
            @"memo":memo_object
        };
        
        //  确保有权限发起普通交易，否则作为提案交易处理。
        [self GuardProposalOrNormalTransaction:ebo_asset_issue
                         using_owner_authority:NO
                      invoke_proposal_callback:NO
                                        opdata:op
                                     opaccount:from
                                          body:^(BOOL isProposal, NSDictionary *proposal_create_args)
         {
            assert(!isProposal);
            //  请求网络广播
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[[BitsharesClientManager sharedBitsharesClientManager] assetIssue:op] then:(^id(id data) {
                [self hideBlockView];
                //  发行成功
                [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpSubmitTipsIssueOK", @"发行成功。")];
                //  [统计]
                [OrgUtils logEvents:@"txAssetIssueFullOK"
                             params:@{@"issuer":from}];
                //  返回上一个界面并刷新
                if (_result_promise) {
                    [_result_promise resolve:@YES];
                }
                [self closeOrPopViewController];
                return nil;
            })] catch:(^id(id error) {
                [self hideBlockView];
                [OrgUtils showGrapheneError:error];
                //  [统计]
                [OrgUtils logEvents:@"txAssetIssueFailed"
                             params:@{@"issuer":from}];
                return nil;
            })];
        }];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
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
            case kVcSubToTitle:
            case kVcSubMemoTitle:
                return 28.0f;
            case kVcSubAmountTextField:
                return 28.0f + 44.0f;
            case kVcSubEmpty:
                return 12.0f;
            case kVcSubMaxSupply:
            case kVcSubCurSupply:
                return 28.0f;
            default:
                break;
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
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    switch (indexPath.section) {
        case kVcSectionInfo:
        {
            switch ([[_dataArray objectAtIndex:indexPath.row] integerValue]) {
                case kVcSubToTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kVcAssetOpCellTitleIssueTargetAccount", @"目标账户");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = theme.textColorMain;
                    return cell;
                }
                    break;
                case kVcSubToValue:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.showCustomBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                    if (_to_account) {
                        cell.textLabel.textColor = theme.buyColor;
                        cell.textLabel.text = [_to_account objectForKey:@"name"];
                        cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0f];
                        cell.detailTextLabel.textColor = theme.textColorMain;
                        cell.detailTextLabel.text = [_to_account objectForKey:@"id"];
                    } else {
                        cell.textLabel.textColor = theme.textColorGray;
                        cell.textLabel.text = NSLocalizedString(@"kVcAssetOpCellValueIssueTargetAccountDefault", @"请选择目标账户");
                        cell.detailTextLabel.text = @"";
                    }
                    return cell;
                }
                    break;
                    
                case kVcSubAmountTextField:
                    return _tf_amount;
                    
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
                    cell.textLabel.text = NSLocalizedString(@"kVcAssetOpCellTitleIssueMemo", @"备注信息");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = theme.textColorMain;
                    return cell;
                }
                    break;
                case kVcSubMemoTextField:
                {
                    assert(_tf_memo);
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = @" ";
                    cell.textLabel.textColor = theme.textColorMain;
                    [_mainTableView attachTextfieldToCell:cell tf:_tf_memo];
                    cell.hideTopLine = YES;
                    cell.hideBottomLine = YES;
                    return cell;
                }
                    break;
                    
                case kVcSubMaxSupply:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kVcAssetOpCellTitleMaxSupply", @"最大发行量");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_n_max_supply], _asset[@"symbol"]];
                    return cell;
                }
                    break;
                case kVcSubCurSupply:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.hideBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kVcAssetOpCellTitleCurSupply", @"当前发行量");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_n_cur_supply], _asset[@"symbol"]];
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
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcSectionAction){
            [self onCommitCore];
        } else {
            switch ([[_dataArray objectAtIndex:indexPath.row] integerValue]) {
                case kVcSubToValue:
                {
                    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAccount callback:^(id account_info) {
                        if (account_info){
                            _to_account = account_info;
                            [_mainTableView reloadData];
                        }
                    }];
                    [self pushViewController:vc
                                     vctitle:NSLocalizedString(@"kVcTitleSelectToAccount", @"搜索目标帐号")
                                   backtitle:kVcDefaultBackTitleName];
                }
                    break;
                default:
                    break;
            }
        }
    }];
}

- (void)endInput
{
    [self.view endEditing:YES];
    [_tf_amount endInput];
    if (_tf_memo) {
        [_tf_memo safeResignFirstResponder];
    }
}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

#pragma mark- for ViewTextFieldAmountCellDelegate
- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onAmountChanged:(NSDecimalNumber*)newValue
{
    [self onAmountChanged:newValue];
}

- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onTailerClicked:(UIButton*)sender
{
    [_tf_amount setInputTextValue:[OrgUtils formatFloatValue:_n_balance usesGroupingSeparator:NO]];
    [self onAmountChanged:nil];
}

/*
 *  (private) 数量发生变化。
 */
- (void)onAmountChanged:(NSDecimalNumber*)newValue
{
    if (!newValue) {
        newValue = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    }
    [self _drawUI_Balance:[_n_balance compare:newValue] < 0];
}

@end
