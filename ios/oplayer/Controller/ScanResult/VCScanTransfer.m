//
//  VCScanTransfer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCScanTransfer.h"
#import "VCTransactionConfirm.h"
#import "VCPaySuccess.h"
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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  背景颜色
    self.view.backgroundColor = theme.appBackColor;
    
    //  收款账号信息
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
    _tf_amount = nil;
    _tf_memo = nil;
    
    BOOL bLockAmount = _default_amount && ![_default_amount isEqualToString:@""];
    BOOL bLockMemo = _default_memo && ![_default_memo isEqualToString:@""];
    
    //  - 金额输入框
    if (!bLockAmount) {
        NSString* placeHolderAmount = NSLocalizedString(@"kVcScanResultPlaceholderInputPayAmount", @"请输入付款金额");
        _tf_amount = [self createTfWithRect:[self makeTextFieldRectFull] keyboard:UIKeyboardTypeDecimalPad placeholder:placeHolderAmount];
        _tf_amount.showBottomLine = YES;
        
        _tf_amount.updateClearButtonTintColor = YES;
        _tf_amount.textColor = theme.textColorMain;
        _tf_amount.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderAmount];
        
        [_tf_amount addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        
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
    }
    
    //  - 备注输入框
    if (!bLockMemo) {
        NSString* placeHolderMemo = NSLocalizedString(@"kVcTransferTipInputMemo", @"请输入备注信息（可选）");
        CGRect rect = [self makeTextFieldRect];
        _tf_memo = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderMemo];
        _tf_memo.updateClearButtonTintColor = YES;
        _tf_memo.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _tf_memo.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderMemo];
        _tf_memo.showBottomLine = YES;
    }
    
    _dataArray = [[[NSMutableArray array] ruby_apply:(^(id obj) {
        //  amount
        if (bLockAmount) {
            [obj addObject:@(kVcSubAmountLocked)];
        } else {
            [obj addObject:@(kVcSubAmountTitle)];
            [obj addObject:@(kVcSubAmountTextField)];
            [obj addObject:@(kVcSubEmpty)];
        }
        //  memo
        if (bLockMemo) {
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
    
    //  按钮
    _btnCommit = [self createCellLableButton:NSLocalizedString(@"kVcScanResultBtnPayNow", @"立即支付")];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self endInput];
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != _tf_amount){
        return YES;
    }

    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:[[_asset objectForKey:@"precision"] integerValue]];
}

- (void)onTextFieldDidChange:(UITextField*)textField
{
    if (textField != _tf_amount){
        return;
    }
    
    //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
    [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _tf_amount && _tf_memo)
    {
        [_tf_memo becomeFirstResponder];
    }
    else
    {
        [self endInput];
    }
    return YES;
}

/**
 *  (private) 核心 确认交易，发送。
 */
-(void)onCommitCore
{
    [self endInput];
    
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            id p1 = [self get_full_account_data_and_asset_hash:[[WalletManager sharedWalletManager] getWalletAccountName]];
            id p2 = [[ChainObjectManager sharedChainObjectManager] queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
            [[[WsPromise all:@[p1, p2]] then:(^id(id data) {
//                [self hideBlockView];
                id full_userdata = [data objectAtIndex:0];
                if (![self _onPayCoreWithMask:full_userdata]) {
                    [self hideBlockView];
                }
                return nil;
            })] catch:(^id(id error) {
                [self hideBlockView];
                [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
                return nil;
            })];
        }
    }];
}

/**
 *  (private) 辅助 - 判断手续费是否足够，足够则返回需要消耗的手续费，不足则返回 nil。TODO:考虑重构
 *  fee_price_item      - 服务器返回的需要手续费值
 *  fee_asset_id        - 当前手续费资产ID
 *  asset               - 正在转账的资产
 *  n_amount            - 正在转账的数量
 */
- (id)_isFeeSufficient:(id)fee_price_item fee_asset:(id)fee_asset asset:(id)asset amount:(id)n_amount full_account_data:(id)full_account_data
{
    assert(fee_price_item);
    assert(fee_asset);
    assert(asset);
    assert(n_amount);
    id fee_asset_id = [fee_asset objectForKey:@"id"];
    assert([fee_asset_id isEqualToString:[fee_price_item objectForKey:@"asset_id"]]);
    
    //  1、转账消耗资产值（只有转账资产和手续费资产相同时候才设置）
    NSDecimalNumber* n_transfer_cost = [NSDecimalNumber zero];
    if ([asset[@"id"] isEqualToString:fee_asset_id]){
        n_transfer_cost = n_amount;
    }
    
    //  2、手续费消耗值
    NSDecimalNumber* n_fee_cost = [NSDecimalNumber decimalNumberWithMantissa:[[fee_price_item objectForKey:@"amount"] unsignedLongLongValue]
                                                                    exponent:-[fee_asset[@"precision"] integerValue]
                                                                  isNegative:NO];
    
    //  3、总消耗值
    id n_total_cost = [n_transfer_cost decimalNumberByAdding:n_fee_cost];
    
    //  4、获取手续费资产总的可用余额
    id n_available = [NSDecimalNumber zero];
    for (id balance_object in [full_account_data objectForKey:@"balances"]) {
        id asset_type = [balance_object objectForKey:@"asset_type"];
        if ([asset_type isEqualToString:fee_asset_id]){
            n_available = [NSDecimalNumber decimalNumberWithMantissa:[balance_object[@"balance"] unsignedLongLongValue]
                                                            exponent:-[fee_asset[@"precision"] integerValue]
                                                          isNegative:NO];
            break;
        }
    }
    
    //  5、判断：n_available < n_total_cost
    if ([n_available compare:n_total_cost] == NSOrderedAscending){
        //  不足：返回 nil。
        return nil;
    }
    
    //  足够（返回手续费值）
    return n_fee_cost;
}

- (BOOL)_onPayCoreWithMask:(NSDictionary*)full_account_data
{
    assert(full_account_data);
    id from_account = [full_account_data objectForKey:@"account"];
    assert(from_account);
    
    //  收款方不能为自己。
    if ([[from_account objectForKey:@"id"] isEqualToString:[_to_account objectForKey:@"id"]]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcScanResultPaySubmitTipsToIsMyself", @"收款方和支付账号相同。")];
        return NO;
    }
    
    //  1、检测付款金额参数是否正确、账户余额是否足够。
    id str_amount = _tf_amount ? _tf_amount.text : _default_amount;
    if (!str_amount || [str_amount isEqualToString:@""]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcScanResultPaySubmitTipsInputPayAmount", @"请输入付款金额。")];
        return NO;
    }
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    
    //  n_amount <= 0
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_amount compare:n_zero] <= 0){
        [OrgUtils makeToast:NSLocalizedString(@"kVcScanResultPaySubmitTipsInputPayAmount", @"请输入付款金额。")];
        return NO;
    }
    
    id pay_asset_id = [_asset objectForKey:@"id"];
    NSInteger pay_asset_precision = [_asset[@"precision"] integerValue];
    
    id balances_hash = [NSMutableDictionary dictionary];
    for (id balance_object in [full_account_data objectForKey:@"balances"]) {
        id asset_type = [balance_object objectForKey:@"asset_type"];
        id balance = [balance_object objectForKey:@"balance"];
        if ([pay_asset_id isEqualToString:asset_type]) {
            id n_balance = [NSDecimalNumber decimalNumberWithMantissa:[balance unsignedLongLongValue] exponent:-pay_asset_precision isNegative:NO];
            if ([n_balance compare:n_amount] < 0) {
                [OrgUtils makeToast:NSLocalizedString(@"kVcScanResultPaySubmitTipsNotEnough", @"余额不足。")];
                return NO;
            }
            id n_left = [n_balance decimalNumberBySubtracting:n_amount];
            id n_left_pow = [NSString stringWithFormat:@"%@", [n_left decimalNumberByMultiplyingByPowerOf10:pay_asset_precision]];
            [balances_hash setObject:@{@"asset_id":asset_type, @"amount":n_left_pow} forKey:asset_type];
        } else {
            [balances_hash setObject:@{@"asset_id":asset_type, @"amount":balance} forKey:asset_type];
        }
    }
    id balances_list = [balances_hash allValues];
    id fee_item = [[ChainObjectManager sharedChainObjectManager] estimateFeeObject:ebo_transfer balances:balances_list];
    
    //  2、检测备注信息
    NSString* str_memo = _tf_memo ? _tf_memo.text : _default_memo;
    if (!str_memo || str_memo.length == 0){
        str_memo = nil;
    }
    
    //  检测备注私钥相关信息
    id memo_object = [NSNull null];
    if (str_memo){
        id from_public_memo = [[from_account objectForKey:@"options"] objectForKey:@"memo_key"];
        if (!from_public_memo || [from_public_memo isEqualToString:@""]){
            [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipAccountNoMemoKey", @"帐号没有备注私钥，不支持填写备注信息。")];
            return NO;
        }
        id to_public = [[_to_account objectForKey:@"options"] objectForKey:@"memo_key"];
        memo_object = [[WalletManager sharedWalletManager] genMemoObject:str_memo from_public:from_public_memo to_public:to_public];
        if (!memo_object){
            [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipWalletNoMemoKey", @"没有备注私钥信息，不支持填写备注。")];
            return NO;
        }
    }

    //  --- 开始构造OP ---
    id n_amount_pow = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:pay_asset_precision]];
    id fee_asset_id = [fee_item objectForKey:@"fee_asset_id"];
    id op = @{
              @"fee":@{
                      @"amount":@0,
                      @"asset_id":fee_asset_id,
                      },
              @"from":from_account[@"id"],
              @"to":_to_account[@"id"],
              @"amount":@{
                      @"amount":@([n_amount_pow unsignedLongLongValue]),
                      @"asset_id":_asset[@"id"],
                      },
              @"memo":memo_object
              };
    //  --- 开始评估手续费 ---
    [[[[BitsharesClientManager sharedBitsharesClientManager] calcOperationFee:ebo_transfer opdata:op] then:(^id(id fee_price_item) {
        [self hideBlockView];
        //  判断手续费是否足够。
        id fee_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:fee_asset_id];
        id n_fee_cost = [self _isFeeSufficient:fee_price_item
                                     fee_asset:fee_asset
                                         asset:_asset amount:n_amount full_account_data:full_account_data];
        if (!n_fee_cost){
            [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
            return nil;
        }
        //  --- 弹框确认转账行为 ---
        //  弹确认框之前 设置参数
        NSMutableDictionary* transfer_args = [NSMutableDictionary dictionary];
        
        [transfer_args setObject:from_account forKey:@"from"];
        [transfer_args setObject:_to_account forKey:@"to"];
        [transfer_args setObject:_asset forKey:@"asset"];
        [transfer_args setObject:fee_asset forKey:@"fee_asset"];
        
        [transfer_args setObject:n_amount forKey:@"kAmount"];
        [transfer_args setObject:n_fee_cost forKey:@"kFeeCost"];

        id op_with_fee = [op mutableCopy];
        [op_with_fee setObject:fee_price_item forKey:@"fee"];
        [transfer_args setObject:[op_with_fee copy] forKey:@"kOpData"];            //  传递过去，避免再次构造。
        if (str_memo){
            [transfer_args setObject:str_memo forKey:@"kMemo"];
        }else{
            [transfer_args removeObjectForKey:@"kMemo"];
        }
        
        //  确保有权限发起普通交易，否则作为提案交易处理。
        [self GuardProposalOrNormalTransaction:ebo_transfer
                         using_owner_authority:NO
                      invoke_proposal_callback:NO
                                        opdata:[transfer_args objectForKey:@"kOpData"]
                                     opaccount:[full_account_data objectForKey:@"account"]
                                          body:^(BOOL isProposal, NSDictionary *proposal_create_args)
         {
             assert(!isProposal);
             // 有权限：转到交易确认界面。
             VCTransactionConfirm* vc = [[VCTransactionConfirm alloc] initWithTransferArgs:[transfer_args copy] callback:(^(BOOL isOk) {
                 if (isOk){
                     [self _processTransferCore:transfer_args full_account_data:full_account_data];
                 }else{
                     NSLog(@"cancel...");
                 }
             })];
             vc.title = NSLocalizedString(@"kVcTitleConfirmTransaction", @"请确认交易");
             vc.hidesBottomBarWhenPushed = YES;
             [self showModelViewController:vc tag:0];
         }];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
    return YES;
}

/**
 *  (private) 用户确认完毕 最后提交请求。
 */
- (void)_processTransferCore:(NSDictionary*)transfer_args full_account_data:(NSDictionary*)full_account_data
{
    id asset = [transfer_args objectForKey:@"asset"];
    assert(asset);
    id op_data = [transfer_args objectForKey:@"kOpData"];
    assert(op_data);
    //  请求网络广播
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[BitsharesClientManager sharedBitsharesClientManager] transfer:op_data] then:(^id(id tx_data) {
        [self hideBlockView];
        [OrgUtils logEvents:@"txPayTransferFullOK" params:@{@"asset":asset[@"symbol"]}];
        id amount_string = [NSString stringWithFormat:@"%@ %@", [transfer_args objectForKey:@"kAmount"], asset[@"symbol"]];
        VCPaySuccess* vc = [[VCPaySuccess alloc] initWithResult:tx_data
                                                     to_account:_to_account
                                                  amount_string:amount_string
                                             success_tip_string:nil];
        [self clearPushViewController:vc vctitle:@"" backtitle:kVcDefaultBackTitleName];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        [OrgUtils logEvents:@"txPayTransferFailed" params:@{@"asset":asset[@"symbol"]}];
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
                    cell.textLabel.text = NSLocalizedString(@"kVcScanResultPayLabelAmount", @"金额");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case kVcSubAmountTextField:
                {
                    assert(_tf_amount);
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
                    cell.textLabel.text = NSLocalizedString(@"kVcScanResultPayLabelAmount", @"金额");
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
                    cell.textLabel.text = NSLocalizedString(@"kVcScanResultPayLabelMemo", @"备注");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
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
                    cell.textLabel.text = NSLocalizedString(@"kVcScanResultPayLabelMemo", @"备注");
                    cell.detailTextLabel.text = _default_memo;
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
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
    if (_tf_amount) {
        [_tf_amount safeResignFirstResponder];
    }
    if (_tf_memo) {
        [_tf_memo safeResignFirstResponder];
    }
}

-(void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    [self endInput];
}

@end
