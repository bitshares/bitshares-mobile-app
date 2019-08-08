//
//  VCTransfer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTransfer.h"
#import "BitsharesClientManager.h"

#import "VCSearchNetwork.h"
#import "VCTransactionConfirm.h"

#import "MBProgressHUD.h"
#import "OrgUtils.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "MyNavigationController.h"
#import "AppCacheManager.h"
#import "ViewTextFieldOwner.h"
#import "WalletManager.h"

enum
{
    kVcSubFrom = 0,             //  来自
    kVcSubTo,                   //  发往
    kVcSubAssetID,              //  转账资产
    
    kVcSubAssetAmountAvailable, //  转账数量可用余额
    kVcSubAssetAmountValue,     //  转账数量输入框
//    kVcSubAssetAmountSlider,    //  转账数量滑动输入
    
    kVcSubEmpty,                //  空行
    
    kVcSubMemo,                 //  备注
    
    kVcSubMax
};

@interface VCTransfer ()
{
    NSDictionary*           _default_asset;     //  默认转账资产
    NSDictionary*           _full_account_data; //  数据 - 帐号全数据（包含帐号、资产、挂单、债仓等所有信息）
    NSArray*                _asset_list;        //  数据 - 用户不为0的所有资产列表
    NSMutableDictionary*    _balances_hash;     //  数据 - 资产ID和对应的余额信息Hash。
    NSDictionary*           _fee_item;          //  手续费对象
    
    UITableViewBase*        _mainTableView;
    UITableViewCellBase*    _cellAssetAvailable;
    
    MyTextField*            _tf_amount;
    MyTextField*            _tf_memo;
    
    ViewBlockLabel*         _goto_submit;
    
    NSMutableDictionary*    _transfer_args;
    NSDecimalNumber*        _n_available;
}

@end

@implementation VCTransfer

-(void)dealloc
{
    _fee_item = nil;
    _asset_list = nil;
    _full_account_data = nil;
    _balances_hash = nil;

    if (_tf_amount){
        _tf_amount.delegate = nil;
        _tf_amount = nil;
    }

    if (_tf_memo){
        _tf_memo.delegate = nil;
        _tf_memo = nil;
    }
    
    _transfer_args = nil;
    _n_available = nil;
    _cellAssetAvailable = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithUserFullInfo:(NSDictionary*)full_account_data defaultAsset:(NSDictionary*)defaultAsset
{
    self = [super init];
    if (self) {
        // Custom initialization
        _default_asset = defaultAsset;
        _full_account_data = full_account_data;
        _transfer_args = nil;
        _balances_hash = nil;
        _fee_item = nil;
        _asset_list = nil;
    }
    return self;
}

/**
 *  (private) 根据帐号fulldata信息初始化转账相关参数。
 */
- (void)genTransferDefaultArgs:(id)full_account_data
{
    //  保存当前帐号信息
    if (full_account_data){
        _full_account_data = full_account_data;
    }
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    //  初始化余额Hash(原来的是Array)
    _balances_hash = [NSMutableDictionary dictionary];
    for (id balance_object in [_full_account_data objectForKey:@"balances"]) {
        id asset_type = [balance_object objectForKey:@"asset_type"];
        id balance = [balance_object objectForKey:@"balance"];
        [_balances_hash setObject:@{@"asset_id":asset_type, @"amount":balance} forKey:asset_type];
    }
    id balances_list = [_balances_hash allValues];
    
    //  计算手续费对象（更新手续费资产的可用余额，即减去手续费需要的amount）
    _fee_item = [chainMgr estimateFeeObject:ebo_transfer balances:balances_list];
    id fee_asset_id = _fee_item[@"fee_asset_id"];
    id fee_balance = [_balances_hash objectForKey:fee_asset_id];
    if (fee_balance){
        unsigned long long fee = [[_fee_item objectForKey:@"amount"] unsignedLongLongValue];
        unsigned long long old = [[fee_balance objectForKey:@"amount"] unsignedLongLongValue];
        id new_balance;
        if (old >= fee){
            new_balance = @{@"asset_id":fee_asset_id, @"amount":@(old - fee)};
        }else{
            new_balance = @{@"asset_id":fee_asset_id, @"amount":@0};
        }
        [_balances_hash setObject:new_balance forKey:fee_asset_id];
    }
    
    //  获取余额不为0的资产列表
    id none_zero_balances = [balances_list ruby_select:(^BOOL(id balance_item) {
        return [[balance_item objectForKey:@"amount"] unsignedLongLongValue] != 0;
    })];
    
    //  如果资产列表为空，则添加默认值。{BTS:0}
    if ([none_zero_balances count] <= 0){
        id balance_object = @{@"asset_id":chainMgr.grapheneCoreAssetID, @"amount":@0};
        none_zero_balances = @[balance_object];
        [_balances_hash setObject:balance_object forKey:[balance_object objectForKey:@"asset_id"]];
    }
    
    //  获取资产详细信息列表
    _asset_list = [none_zero_balances ruby_map:(^id(id balance_item) {
        return [chainMgr getChainObjectByID:[balance_item objectForKey:@"asset_id"]];
    })];
    assert([_asset_list count] > 0);
    
    //  初始化转账默认参数：from、fee_asset
    id last_asset = nil;
    if (_transfer_args){
        //  REMARK：第二次调用该方法时才存在 last_asset，上次转账的资产。
        last_asset = [_transfer_args objectForKey:@"asset"];
    }
    _transfer_args = [NSMutableDictionary dictionary];
    id account_info = [_full_account_data objectForKey:@"account"];
    [_transfer_args setObject:@{@"id":account_info[@"id"], @"name":account_info[@"name"]} forKey:@"from"];
    if (!_default_asset){
        //  TODO:fowallet 默认值，优先选择CNY、没CNY选择BTS。TODO：USD呢？？
        _default_asset = [_asset_list ruby_find:(^BOOL(id src) {
            return [[src objectForKey:@"id"] isEqualToString:@"1.3.113"];
        })];
        if (!_default_asset){
            _default_asset = [_asset_list ruby_find:(^BOOL(id src) {
                return [[src objectForKey:@"id"] isEqualToString:@"1.3.0"];
            })];
        }
        if (!_default_asset){
            _default_asset = [_asset_list firstObject];
        }
    }
    id fee_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[_fee_item objectForKey:@"fee_asset_id"]];
    [_transfer_args setObject:fee_asset forKey:@"fee_asset"];
    
    //  设置当前资产
    [self setAsset:last_asset ? : _default_asset];
}

/**
 *  (private) 转账成功后刷新界面。
 */
- (void)refreshUI:(id)new_full_account_data
{
    _tf_amount.text = @"";
    _tf_memo.text = @"";
    [self genTransferDefaultArgs:new_full_account_data];
    [_mainTableView reloadData];
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_amount safeResignFirstResponder];
    [_tf_memo safeResignFirstResponder];
}

- (void)onAmountAllButtonClicked:(UIButton*)sender
{
    _tf_amount.text = [OrgUtils formatFloatValue:_n_available usesGroupingSeparator:NO];
    [self onAmountChanged];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化UI
    NSString* placeHolderAmount = NSLocalizedString(@"kVcTransferTipInputSendAmount", @"请输入转账金额");
    NSString* placeHolderMemo = NSLocalizedString(@"kVcTransferTipInputMemo", @"请输入备注信息（可选）");
    CGRect rect = [self makeTextFieldRect];
    _tf_amount = [self createTfWithRect:rect keyboard:UIKeyboardTypeDecimalPad placeholder:placeHolderAmount];
    _tf_memo = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderMemo];
    
    //  设置属性颜色等
    _tf_memo.updateClearButtonTintColor = YES;
    _tf_memo.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_memo.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderMemo
                                                                       attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                    NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_amount.updateClearButtonTintColor = YES;
    _tf_amount.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_amount.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderAmount
                                                                       attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                    NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    
    //  绑定输入事件（限制输入）
    [_tf_amount addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 转账数量尾部辅助按钮
    UIButton* btn100 = [UIButton buttonWithType:UIButtonTypeSystem];
    btn100.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn100 setTitle:NSLocalizedString(@"kLabelSendAll", @"全部") forState:UIControlStateNormal];
    [btn100 setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
    btn100.userInteractionEnabled = YES;
    [btn100 addTarget:self action:@selector(onAmountAllButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn100.frame = CGRectMake(6, 2, 40, 27);
    _tf_amount.rightView = btn100;
    _tf_amount.rightViewMode = UITextFieldViewModeAlways;
    
    //  待转账资产总可用余额
    _cellAssetAvailable = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellAssetAvailable.backgroundColor = [UIColor clearColor];
    _cellAssetAvailable.hideBottomLine = YES;
    _cellAssetAvailable.accessoryType = UITableViewCellAccessoryNone;
    _cellAssetAvailable.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellAssetAvailable.textLabel.text = NSLocalizedString(@"kLableAvailable", @"可用");
    _cellAssetAvailable.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellAssetAvailable.textLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    _cellAssetAvailable.detailTextLabel.text = @"";
    _cellAssetAvailable.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.hideAllLines = YES;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  初始化相关参数
    [self genTransferDefaultArgs:nil];
    
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  发送按钮
    _goto_submit = [self createCellLableButton:NSLocalizedString(@"kLabelSendBtn", @"发送")];
}

/**
 *  设置待转账资产：更新可用余额等信息
 */
- (void)setAsset:(NSDictionary*)new_asset
{
    [_transfer_args setObject:new_asset forKey:@"asset"];
    
    id new_asset_id = [new_asset objectForKey:@"id"];
    id balance = [[_balances_hash objectForKey:new_asset_id] objectForKey:@"amount"];
    
    _n_available = [NSDecimalNumber decimalNumberWithMantissa:[balance unsignedLongLongValue]
                                                     exponent:-[[new_asset objectForKey:@"precision"] integerValue]
                                                   isNegative:NO];
    
    //  更新可用余额
    _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", [OrgUtils formatFloatValue:_n_available], [new_asset objectForKey:@"symbol"]];
    
    //  切换资产清除当前输入的数量
    _tf_amount.text = @"";
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

-(void)gotoTransfer
{
    //  TODO:fowallet 不足的时候否直接提示显示？？？
    if (![[_fee_item objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }
    
    id from = [_transfer_args objectForKey:@"from"];
    assert(from);
    id asset = [_transfer_args objectForKey:@"asset"];
    assert(asset);
    id to = [_transfer_args objectForKey:@"to"];
    if (!to){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipSelectTo", @"请选择收款帐号。")];
        return;
    }
    if ([[from objectForKey:@"id"] isEqualToString:[to objectForKey:@"id"]]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipFromToIsSame", @"收款账号和发送账号不能相同。")];
        return;
    }
    
    //  TODO:fowallet to在黑名单中 风险提示。
    
    id str_amount = _tf_amount.text;
    if (!str_amount || [str_amount isEqualToString:@""]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipPleaseInputAmount", @"请输入转账金额")];
        return;
    }
    
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    
    //  <= 0 判断，只有 大于 才为 NSOrderedDescending。
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_amount compare:n_zero] != NSOrderedDescending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipPleaseInputAmount", @"请输入转账金额")];
        return;
    }
    
    //  _n_available < n_amount
    if ([_n_available compare:n_amount] == NSOrderedAscending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipAmountNotEnough", @"数量不足")];
        return;
    }
    
    //  获取备注(memo)信息
    NSString* str_memo = _tf_memo.text;
    if (!str_memo || str_memo.length == 0){
        str_memo = nil;
    }
    
    //  检测备注私钥相关信息
    NSString* from_public_memo = nil;
    WalletManager* walletMgr = nil;
    if (str_memo){
        walletMgr = [WalletManager sharedWalletManager];
        id full_account_data = [walletMgr getWalletAccountInfo];
        from_public_memo = [[[full_account_data objectForKey:@"account"] objectForKey:@"options"] objectForKey:@"memo_key"];
        if (!from_public_memo || [from_public_memo isEqualToString:@""]){
            [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipAccountNoMemoKey", @"帐号没有备注私钥，不支持填写备注信息。")];
            return;
        }
    }
    
    //  --- 参数大部分检测合法 执行请求 ---
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self _processTransferCore:from to:to asset:asset amount:n_amount memo:str_memo from_public_memo:from_public_memo];
        }
    }];
}

/**
 *  (private) 辅助 - 判断手续费是否足够，足够则返回需要消耗的手续费，不足则返回 nil。
 *  fee_price_item      - 服务器返回的需要手续费值
 *  fee_asset_id        - 当前手续费资产ID
 *  asset               - 正在转账的资产
 *  n_amount            - 正在转账的数量
 */
- (id)_isFeeSufficient:(id)fee_price_item fee_asset_id:(NSString*)fee_asset_id asset:(id)asset amount:(id)n_amount
{
    assert(fee_price_item);
    assert(fee_asset_id);
    assert(asset);
    assert(n_amount);
    assert([fee_asset_id isEqualToString:[fee_price_item objectForKey:@"asset_id"]]);
    
    //  1、转账消耗资产值（只有转账资产和手续费资产相同时候才设置）
    NSDecimalNumber* n_transfer_cost = [NSDecimalNumber zero];
    if ([asset[@"id"] isEqualToString:fee_asset_id]){
        n_transfer_cost = n_amount;
    }
    
    //  2、手续费消耗值
    id fee_asset = _transfer_args[@"fee_asset"];
    assert(fee_asset);
    NSDecimalNumber* n_fee_cost = [NSDecimalNumber decimalNumberWithMantissa:[[fee_price_item objectForKey:@"amount"] unsignedLongLongValue]
                                                                    exponent:-[fee_asset[@"precision"] integerValue]
                                                                  isNegative:NO];
    
    //  3、总消耗值
    id n_total_cost = [n_transfer_cost decimalNumberByAdding:n_fee_cost];
    
    //  4、获取手续费资产总的可用余额
    id n_available = [NSDecimalNumber zero];
    for (id balance_object in [_full_account_data objectForKey:@"balances"]) {
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

-(void)_processTransferCore:(id)from
                         to:(id)to
                      asset:(id)asset
                     amount:(id)n_amount
                       memo:(NSString*)memo
           from_public_memo:(NSString*)from_public_memo
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //  构造请求
    id fetch_to = memo ? [[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:to[@"id"]] : [NSNull null];
    [[[WsPromise all:@[fetch_to]] then:(^id(id data_array) {
        //  生成 memo 对象。
        id memo_object = [NSNull null];
        if (memo){
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
        id fee_asset_id = [_fee_item objectForKey:@"fee_asset_id"];
        id op = @{
                  @"fee":@{
                          @"amount":@0,
                          @"asset_id":fee_asset_id,
                          },
                  @"from":from[@"id"],
                  @"to":to[@"id"],
                  @"amount":@{
                          @"amount":@([n_amount_pow unsignedLongLongValue]),
                          @"asset_id":asset[@"id"],
                          },
                  @"memo":memo_object
                  };
        //  --- 开始评估手续费 ---
        [[[[BitsharesClientManager sharedBitsharesClientManager] calcOperationFee:ebo_transfer opdata:op] then:(^id(id fee_price_item) {
            [self hideBlockView];
            //  判断手续费是否足够。
            id n_fee_cost = [self _isFeeSufficient:fee_price_item fee_asset_id:fee_asset_id asset:asset amount:n_amount];
            if (!n_fee_cost){
                [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
                return nil;
            }
            //  --- 弹框确认转账行为 ---
            //  弹确认框之前 设置参数
            [_transfer_args setObject:n_amount forKey:@"kAmount"];
            [_transfer_args setObject:n_fee_cost forKey:@"kFeeCost"];
            
            id op_with_fee = [op mutableCopy];
            [op_with_fee setObject:fee_price_item forKey:@"fee"];
            [_transfer_args setObject:[op_with_fee copy] forKey:@"kOpData"];            //  传递过去，避免再次构造。
            if (memo){
                [_transfer_args setObject:memo forKey:@"kMemo"];
            }else{
                [_transfer_args removeObjectForKey:@"kMemo"];
            }
            //  确保有权限发起普通交易，否则作为提案交易处理。
            [self GuardProposalOrNormalTransaction:ebo_transfer
                             using_owner_authority:NO
                          invoke_proposal_callback:NO
                                            opdata:[_transfer_args objectForKey:@"kOpData"]
                                         opaccount:[_full_account_data objectForKey:@"account"]
                                              body:^(BOOL isProposal, NSDictionary *proposal_create_args)
             {
                 assert(!isProposal);
                 // 有权限：转到交易确认界面。
                 VCTransactionConfirm* vc = [[VCTransactionConfirm alloc] initWithTransferArgs:[_transfer_args copy] callback:(^(BOOL isOk) {
                     if (isOk){
                         [self _processTransferCore];
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
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

/**
 *  (private) 用户确认完毕 最后提交请求。
 */
- (void)_processTransferCore
{
    id asset = [_transfer_args objectForKey:@"asset"];
    assert(asset);
    id op_data = [_transfer_args objectForKey:@"kOpData"];
    assert(op_data);
    
    //  请求网络广播
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[BitsharesClientManager sharedBitsharesClientManager] transfer:op_data] then:(^id(id data) {
        id account_id = [[_full_account_data objectForKey:@"account"] objectForKey:@"id"];
        [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_id] then:(^id(id full_data) {
            NSLog(@"transfer & refresh: %@", full_data);
            [self hideBlockView];
            [self refreshUI:full_data];
            [OrgUtils makeToast:NSLocalizedString(@"kVcTransferTipTxTransferFullOK", @"发送成功。")];
            //  [统计]
            [OrgUtils logEvents:@"txTransferFullOK" params:@{@"account":account_id, @"asset":asset[@"symbol"]}];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"kVcTransferTipTxTransferOK", @"发送成功，但刷新界面数据失败，请稍后再试。")];
            //  [统计]
            [OrgUtils logEvents:@"txTransferOK" params:@{@"account":account_id, @"asset":asset[@"symbol"]}];
            return nil;
        })];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        //  [统计]
        [OrgUtils logEvents:@"txTransferFailed" params:@{@"asset":asset[@"symbol"]}];
        return nil;
    })];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField != _tf_amount){
        return YES;
    }
    
    id asset = [_transfer_args objectForKey:@"asset"];
    assert(asset);
    
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:[[asset objectForKey:@"precision"] integerValue]];
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
    id asset = [_transfer_args objectForKey:@"asset"];
    assert(asset);
    
    id str_amount = _tf_amount.text;
    
    //  无效输入
    if (!str_amount || [str_amount isEqualToString:@""]){
        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", [OrgUtils formatFloatValue:_n_available], [asset objectForKey:@"symbol"]];
        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        return;
    }
    
    //  获取输入的数量
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    
    //  _n_available < n_amount
    if ([_n_available compare:n_amount] == NSOrderedAscending){
        //  数量不足
        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@%@(%@)", [OrgUtils formatFloatValue:_n_available], [asset objectForKey:@"symbol"], NSLocalizedString(@"kVcTransferTipAmountNotEnough", @"数量不足")];
        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].tintColor;
    }else{
        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", [OrgUtils formatFloatValue:_n_available], [asset objectForKey:@"symbol"]];
        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    }
}

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _tf_amount)
    {
        [_tf_memo becomeFirstResponder];
    }
    else
    {
        [self.view endEditing:YES];
        [_tf_amount safeResignFirstResponder];
        [_tf_memo safeResignFirstResponder];
    }
    return YES;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return kVcSubMax;
    else
        return 1;
}

//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
//{
////    if (section == 2){
////        return 160.0;
////    }
//    return tableView.sectionHeaderHeight;
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
//{
//    if (section == 0){
//        return 20.0f;
//    }
//    return tableView.sectionFooterHeight;
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        //  TODO:fowallet color
        switch (indexPath.row) {
            case kVcSubFrom:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kVcTransferCellFrom", @"来自帐号");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.detailTextLabel.text = [[_transfer_args objectForKey:@"from"] objectForKey:@"name"];
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
                break;
            case kVcSubTo:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.textLabel.text = NSLocalizedString(@"kVcTransferCellTo", @"发往帐号");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                
                NSString* str = [[_transfer_args objectForKey:@"to"] objectForKey:@"name"];
                if (!str || [str length] == 0){
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorGray;
                    cell.detailTextLabel.text = NSLocalizedString(@"kVcTransferTipSelectToAccount", @"请选择收款帐号");
                }else{
                    cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;//TODO:color
                    cell.detailTextLabel.text = str;
                }
                
                return cell;
            }
                break;
            case kVcSubAssetID:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.textLabel.text = NSLocalizedString(@"kVcTransferCellAsset", @"转账资产");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                id asset = [_transfer_args objectForKey:@"asset"];
                assert(asset);
                cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.detailTextLabel.text = [asset objectForKey:@"symbol"];
                return cell;
            }
                break;
            case kVcSubAssetAmountAvailable:
            {
                return _cellAssetAvailable;
            }
                break;
            case kVcSubAssetAmountValue:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kVcTransferCellAmount", @"转账数量");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_amount;
                cell.showCustomBottomLine = YES;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
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
            case kVcSubMemo:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kVcTransferCellMemo", @"备注信息");
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                cell.accessoryView = _tf_memo;
                cell.showCustomBottomLine = YES;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
                break;
            default:
                break;
        }
    }else{
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.hideBottomLine = YES;
        cell.hideTopLine = YES;
        cell.backgroundColor = [UIColor clearColor];
        [self addLabelButtonToCell:_goto_submit cell:cell leftEdge:tableView.layoutMargins.left];
        return cell;
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0){
        [self resignAllFirstResponder];
        
        //  表单数据项点击
        switch (indexPath.row) {
            case kVcSubTo:
            {
                VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAccount callback:^(id account_info) {
                    if (account_info){
                        //  TODO:fowallet
                        NSLog(@"select: %@", account_info);
                        [_transfer_args setObject:account_info forKey:@"to"];
                        [_mainTableView reloadData];
                    }
                }];
                [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleSelectToAccount", @"搜索目标帐号") backtitle:kVcDefaultBackTitleName];
                //  TODO:log
            }
                break;
            case kVcSubAssetID:
                [self onSelectAssetClicked];
                break;
            default:
                break;
        }
    }else{
        [self resignAllFirstResponder];
        
        //  表单行为按钮点击
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self delay:^{
                [self gotoTransfer];
            }];
        }];
    }
}

/**
 *  (private) 选择转账资产
 */
- (void)onSelectAssetClicked
{
    id curr_asset = [_transfer_args objectForKey:@"asset"];
    assert(curr_asset);
    id curr_symbol = [curr_asset objectForKey:@"symbol"];
    
    NSInteger defaultIndex = 0;
    NSInteger idx = 0;
    for (id asset in _asset_list) {
        if ([[asset objectForKey:@"symbol"] isEqualToString:curr_symbol]){
            defaultIndex = idx;
            break;
        }
        ++idx;
    }
    [[[MyPopviewManager sharedMyPopviewManager] showModernListView:self.navigationController
                                                           message:NSLocalizedString(@"kVcTransferTipSelectAsset", @"请选择要转账的资产")
                                                             items:_asset_list
                                                           itemkey:@"symbol"
                                                      defaultIndex:defaultIndex] then:(^id(id result) {
        if (result){
            id select_symbol = [result objectForKey:@"symbol"];
            if (![select_symbol isEqualToString:curr_symbol]){
                [self setAsset:result];
                [_mainTableView reloadData];
            }
        }
        return nil;
    })];
}

@end
