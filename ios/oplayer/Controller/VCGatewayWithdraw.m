//
//  VCGatewayWithdraw.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCGatewayWithdraw.h"
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

#import "Gateway/RuDEX.h"
#import "GatewayAssetItemData.h"

enum
{
    kVcFormData = 0,            //  表单数据
    kVcAuxData,                 //  附加数据
    kVcSubmit,                  //  提币按钮
    
    kVcMax
};

enum
{
    kVcSubAddrTitle = 0,
    kVcSubAddress,              //  提币地址
    
    kVcSubAssetAmountAvailable, //  提币数量可用余额
    kVcSubAssetAmountValue,     //  提币数量输入框
    
    kVcSubMemoTitle,
    kVcSubMemo,                 //  备注
    
    kVcSubMax
};

@interface VCGatewayWithdraw ()
{
    NSDictionary*           _fullAccountData;
    NSDictionary*           _intermediateAccount;
    NSDictionary*           _withdrawAssetItem;
    NSDictionary*           _gateway;
    
    UITableViewBase*        _mainTableView;
    
    UITableViewCellBase*    _cellAssetAvailable;
    UITableViewCellBase*    _cellFinalValue;
    
    MyTextField*            _tf_address;
    MyTextField*            _tf_amount;
    MyTextField*            _tf_memo;
    
    ViewBlockLabel*         _goto_submit;
    
    NSDictionary*           _asset;
    NSDecimalNumber*        _n_available;
    NSDecimalNumber*        _n_withdrawMinAmount;
    NSDecimalNumber*        _n_withdrawGateFee;
    NSInteger               _precision_amount;
    
    BOOL                    _bSupportMemo;
    NSMutableArray*         _data_type_array;
    NSMutableArray*         _aux_data_array;    //  附加信息字段数组
}

@end

@implementation VCGatewayWithdraw

-(void)dealloc
{
    if (_tf_address){
        _tf_address.delegate = nil;
        _tf_address = nil;
    }
    
    if (_tf_amount){
        _tf_amount.delegate = nil;
        _tf_amount = nil;
    }

    if (_tf_memo){
        _tf_memo.delegate = nil;
        _tf_memo = nil;
    }
    _asset = nil;
    _n_available = nil;
    _cellAssetAvailable = nil;
    _cellFinalValue = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _fullAccountData = nil;
    _intermediateAccount = nil;
    _withdrawAssetItem = nil;
    _gateway = nil;
}

/**
 *  (private) 刷新提币资产可用余额
 */
- (void)_refreshWithdrawAssetBalance:(id)fullAccountData
{
    if (fullAccountData){
        //  update
        _fullAccountData = fullAccountData;
    }else{
        //  use default value
        fullAccountData = _fullAccountData;
    }
    if (!_asset){
        return;
    }
    assert(fullAccountData);
    id asset_id = [_asset objectForKey:@"id"];
    unsigned long long asset_value = 0;
    for (id balance_item in [fullAccountData objectForKey:@"balances"]) {
        id asset_type = [balance_item objectForKey:@"asset_type"];
        if ([asset_type isEqualToString:asset_id]){
            asset_value = [[balance_item objectForKey:@"balance"] unsignedLongLongValue];
            break;
        }
    }
    _n_available = [NSDecimalNumber decimalNumberWithMantissa:asset_value
                                                     exponent:-_precision_amount
                                                   isNegative:NO];
}

- (id)initWithFullAccountData:(NSDictionary*)fullAccountData
          intermediateAccount:(NSDictionary*)intermediateAccount
            withdrawAssetItem:(NSDictionary*)withdrawAssetItem
                      gateway:(id)gateway
{
    self = [super init];
    if (self) {
        // Custom initialization
        assert(fullAccountData && withdrawAssetItem && gateway);
        _fullAccountData = fullAccountData;
        //  REMRAK：open网关在这里可能为空，在最后请求的时候才得到网关账号信息。
        _intermediateAccount = intermediateAccount;
        _withdrawAssetItem = withdrawAssetItem;
        _gateway = gateway;
        GatewayAssetItemData* appext = [_withdrawAssetItem objectForKey:@"kAppExt"];
        assert(appext);
        id balance = appext.balance;
        assert(balance);
        if (![[balance objectForKey:@"iszero"] boolValue]){
            _asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[balance objectForKey:@"asset_id"]];
            assert(_asset);
            _precision_amount = [[_asset objectForKey:@"precision"] integerValue];
            [self _refreshWithdrawAssetBalance:nil];
        }else{
            _asset = nil;
            _precision_amount = 8;
            _n_available = [NSDecimalNumber zero];
        }
        
        //  表单行数数量和类型列表
        _bSupportMemo = appext.supportMemo;
        _data_type_array = [NSMutableArray array];
        [_data_type_array addObjectsFromArray:@[@(kVcSubAddrTitle), @(kVcSubAddress),  @(kVcSubAssetAmountAvailable),  @(kVcSubAssetAmountValue)]];
        if (_bSupportMemo){
            [_data_type_array addObjectsFromArray:@[@(kVcSubMemoTitle), @(kVcSubMemo)]];
        }
        
        //  附加信息数据
        _n_withdrawMinAmount = [NSDecimalNumber zero];
        _n_withdrawGateFee = [NSDecimalNumber zero];
        _aux_data_array = [NSMutableArray array];
        id symbol = appext.symbol;
        id withdrawMinAmount = appext.withdrawMinAmount;
        if (withdrawMinAmount && ![withdrawMinAmount isEqualToString:@""]){
            _n_withdrawMinAmount = [NSDecimalNumber decimalNumberWithString:withdrawMinAmount];
            [_aux_data_array addObject:@{@"title":NSLocalizedString(@"kVcDWCellMinWithdrawNumber", @"最小提币数量"),
                                         @"value":[NSString stringWithFormat:@"%@ %@", withdrawMinAmount, symbol]}];
        }
        id withdrawGateFee = appext.withdrawGateFee;
        if (withdrawGateFee && ![withdrawGateFee isEqualToString:@""]){
            _n_withdrawGateFee = [NSDecimalNumber decimalNumberWithString:withdrawGateFee];
            [_aux_data_array addObject:@{@"title":NSLocalizedString(@"kVcDWCellWithdrawFee", @"提币手续费"),
                                         @"value":[NSString stringWithFormat:@"%@ %@", withdrawGateFee, symbol]}];
        }
        if (_intermediateAccount){
            [_aux_data_array addObject:@{@"title":NSLocalizedString(@"kVcDWCellWithdrawGatewayAccount", @"网关账号"),
                                         @"value":[[_intermediateAccount objectForKey:@"account"] objectForKey:@"name"]}];
        }
        if (appext.withdrawMaxAmountOnce && ![appext.withdrawMaxAmountOnce isEqualToString:@""]){
            [_aux_data_array addObject:@{@"title":NSLocalizedString(@"kVcDWCellMaxWithdrawNumberOnce", @"单次最大提币数量"),
                                         @"value":[NSString stringWithFormat:@"%@ %@", appext.withdrawMaxAmountOnce, symbol]}];
        }
        if (appext.withdrawMaxAmount24Hours && ![appext.withdrawMaxAmount24Hours isEqualToString:@""]){
            [_aux_data_array addObject:@{@"title":NSLocalizedString(@"kVcDWCellMaxWithdrawNumber24Hours", @"24小时最大提币数量"),
                                         @"value":[NSString stringWithFormat:@"%@ %@", appext.withdrawMaxAmount24Hours, symbol]}];
        }
        
        assert([_aux_data_array count] > 0);
    }
    return self;
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_address safeResignFirstResponder];
    [_tf_amount safeResignFirstResponder];
    if (_tf_memo){
        [_tf_memo safeResignFirstResponder];
    }
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
    NSString* placeHolderAddress = NSLocalizedString(@"kVcDWCellWithdrawPlaceholderAddress", @"请输入或粘贴提币地址");
    NSString* placeHolderAmount = NSLocalizedString(@"kVcDWCellWithdrawPlaceholderAmount", @"请输入提币数量");
    NSString* placeHolderMemo =  NSLocalizedString(@"kVcDWCellWithdrawPlaceholderMemo", @"请输入备注（Memo）或标签(TAG)");
    CGRect rect = [self makeTextFieldRectFull];
    _tf_address = [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderAddress];
    _tf_amount = [self createTfWithRect:rect keyboard:UIKeyboardTypeDecimalPad placeholder:placeHolderAmount];
    _tf_memo = _bSupportMemo ? [self createTfWithRect:rect keyboard:UIKeyboardTypeDefault placeholder:placeHolderMemo] : nil;
    
    //  设置属性颜色等
    _tf_address.showBottomLine = YES;
    _tf_amount.showBottomLine = YES;
    if (_tf_memo){
        _tf_memo.showBottomLine = YES;
    }
    
    _tf_address.updateClearButtonTintColor = YES;
    _tf_address.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_address.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderAddress
                                                                        attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                     NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    _tf_amount.updateClearButtonTintColor = YES;
    _tf_amount.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _tf_amount.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderAmount
                                                                       attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                    NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    if (_tf_memo){
        _tf_memo.updateClearButtonTintColor = YES;
        _tf_memo.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _tf_memo.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolderMemo
                                                                         attributes:@{NSForegroundColorAttributeName:[ThemeManager sharedThemeManager].textColorGray,
                                                                                      NSFontAttributeName:[UIFont systemFontOfSize:17]}];
    }
    
    //  绑定输入事件（限制输入）
    [_tf_amount addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    //  UI - 提币数量尾部辅助按钮
    UIButton* btn100 = [UIButton buttonWithType:UIButtonTypeSystem];
    btn100.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn100 setTitle:NSLocalizedString(@"kLabelSendAll", @"全部") forState:UIControlStateNormal];
    [btn100 setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
    btn100.userInteractionEnabled = YES;
    [btn100 addTarget:self action:@selector(onAmountAllButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn100.frame = CGRectMake(6, 2, 40, 27);
    _tf_amount.rightView = btn100;
    _tf_amount.rightViewMode = UITextFieldViewModeAlways;
    
    //  提币资产总可用余额
    GatewayAssetItemData* appext = [_withdrawAssetItem objectForKey:@"kAppExt"];
    
    _cellAssetAvailable = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellAssetAvailable.backgroundColor = [UIColor clearColor];
    _cellAssetAvailable.hideBottomLine = YES;
    _cellAssetAvailable.accessoryType = UITableViewCellAccessoryNone;
    _cellAssetAvailable.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellAssetAvailable.textLabel.text = NSLocalizedString(@"kLableAvailable", @"可用");
    _cellAssetAvailable.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellAssetAvailable.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_n_available],
                                                appext.symbol];
    _cellAssetAvailable.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    //  实际到账
    _cellFinalValue = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellFinalValue.backgroundColor = [UIColor clearColor];
    _cellFinalValue.hideBottomLine = YES;
    _cellFinalValue.accessoryType = UITableViewCellAccessoryNone;
    _cellFinalValue.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellFinalValue.textLabel.text = NSLocalizedString(@"kVcDWCellWithdrawFinalValue", @"实际到账");
    _cellFinalValue.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellFinalValue.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    [self _refreshFinalValueUI:[NSDecimalNumber zero]];
    _cellFinalValue.detailTextLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    _cellFinalValue.detailTextLabel.textColor = [ThemeManager sharedThemeManager].buyColor;
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.hideAllLines = YES;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  提交按钮
    _goto_submit = [self createCellLableButton:NSLocalizedString(@"kVcDWWithdrawSubmitButton", @"提币")];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

/**
 *  (private) 转账成功后刷新界面。
 */
- (void)refreshUI:(id)new_full_account_data
{
    //  clear
    _tf_amount.text = @"";
    if (_tf_memo){
        _tf_memo.text = @"";
    }
    
    //  刷新可用余额数量
    [self _refreshWithdrawAssetBalance:new_full_account_data];
    
    //  刷新UI
    GatewayAssetItemData* appext = [_withdrawAssetItem objectForKey:@"kAppExt"];
    _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_n_available],
                                                appext.symbol];
    [self _refreshFinalValueUI:[NSDecimalNumber zero]];
    
    //  重新加载List
    [_mainTableView reloadData];
}

/**
 *  事件 - 用户点击提币按钮
 */
-(void)gotoWithdrawCore
{
    NSString* str_address = _tf_address.text ?: @"";
    if ([str_address isEqualToString:@""]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTipsAddressCannotBeEmpty", @"提币地址不能为空。")];
        return;
    }
    
    NSString* str_amount = _tf_amount.text ?: @"";
    NSString* str_memo = @"";
    if (_bSupportMemo && _tf_memo){
        str_memo = _tf_memo.text ?: @"";
    }
    
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    id n_zero = [NSDecimalNumber zero];
    //  n_amount <= 0
    if ([n_amount compare:n_zero] != NSOrderedDescending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTipsPleaseInputAmount", @"请输入提币数量。")];
        return;
    }

    //  _n_available < n_amount
    if ([_n_available compare:n_amount] == NSOrderedAscending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTipsWithdrawAmountNotEnough", @"数量不足。")];
        return;
    }

    //  n_amount < _n_withdrawMinAmount
    if ([n_amount compare:_n_withdrawMinAmount] == NSOrderedAscending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTipsWithdrawLessThanMinNumber", @"不能小于最小提币数量。")];
        return;
    }
    
    //  n_final_value <= 0
    id n_final_value = [self _calcFinalValue:n_amount];
    if ([n_final_value compare:n_zero] != NSOrderedDescending){
        [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTipsFinalValueTooLow", @"实际到账数量太低。")];
        return;
    }
    
    NSString* from_public_memo = [[[_fullAccountData objectForKey:@"account"] objectForKey:@"options"] objectForKey:@"memo_key"];
    if (!from_public_memo || [from_public_memo isEqualToString:@""]){
        [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTipsNoMemoCannotWithdraw", @"账号没有备注私钥，不支持提币。")];
        return;
    }
    
    //  --- 参数大部分检测合法 执行请求 ---
    //  TODO:REMARK：解锁钱包，这里和其它交易不同，这里严格检查active权限，目前提案交易不支持，因为提案转账大部分都没有memokey，提币存在问题。
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        //  a、解锁钱包成功
        if (unlocked){
            if ([[WalletManager sharedWalletManager] havePrivateKey:from_public_memo]){
                //  安全提示（二次确认）：
                //  1、没有填写备注时提示是否缺失。
                //  2、填写了备注提示二次确认是否正确。
                NSString* tipMessage;
                if (_bSupportMemo){
                    if (![str_memo isEqualToString:@""]){
                        tipMessage = NSLocalizedString(@"kVcDWSubmitSecondConfirmMsg01", @"提币请求发出后将不可撤回，请确定您的提币地址和备注信息正确哦。");
                    }else{
                        tipMessage = NSLocalizedString(@"kVcDWSubmitSecondConfirmMsg02", @"您没有填写备注信息，是否继续提币？");
                    }
                }else{
                    tipMessage = NSLocalizedString(@"kVcDWSubmitSecondConfirmMsg03", @"提币请求发出后将不可撤回，请确定您的提币地址正确哦。");
                }
                [[UIAlertViewManager sharedUIAlertViewManager] showMessageEx:tipMessage
                                                                   withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                                cancelButton:NSLocalizedString(@"kBtnCancel", @"取消")
                                                                otherButtons:@[NSLocalizedString(@"kVcDWSubmitSecondBtnContinue", @"继续提币")]
                                                                  completion:^(NSInteger buttonIndex)
                 {
                     // b、继续提币确认
                     if (buttonIndex == 1){
                         [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
                         GatewayAssetItemData* appext = [_withdrawAssetItem objectForKey:@"kAppExt"];
                         id intermediateAccountData = _intermediateAccount ? [_intermediateAccount objectForKey:@"account"] : nil;
                         
                         // REMARK：查询提币所需信息（账号、memo等）该接口返回都promise不会发生reject，不用catch。
                         [[[_gateway objectForKey:@"api"] queryWithdrawIntermediateAccountAndFinalMemo:appext
                                                                                               address:str_address
                                                                                                  memo:str_memo
                                                                               intermediateAccountData:intermediateAccountData] then:(^id(id withdraw_info) {
                             if (!withdraw_info){
                                 [self hideBlockView];
                                 [OrgUtils makeToast:NSLocalizedString(@"kVcDWErrTipsRequestWithdrawAddrFailed", @"获取提币地址异常，请联系网关客服。")];
                                 return nil;
                             }
                             
                             id final_account = [withdraw_info objectForKey:@"intermediateAccount"];
                             id final_memo = [withdraw_info objectForKey:@"finalMemo"];
                             id final_account_data = [withdraw_info objectForKey:@"intermediateAccountData"];
                             assert(final_account && final_memo && final_account_data);
                             
                             // 继续验证用户输入的提币地址、数量、备注等是否正确。
                             [[[_gateway objectForKey:@"api"] checkAddress:_withdrawAssetItem address:str_address
                                                                      memo:final_memo
                                                                    amount:[NSString stringWithFormat:@"%@", n_amount]] then:(^id(id valid) {
                                 if (![valid boolValue]){
                                     [self hideBlockView];
                                     [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTipsInvalidAddress", @"提币地址无效。")];
                                     return nil;
                                 }
                                 // c、地址验证通过继续提币
                                 [self _processWithdrawCore:str_address
                                                     amount:n_amount
                                                 final_memo:final_memo
                                 final_intermediate_account:final_account_data
                                           from_public_memo:from_public_memo];
                                 return nil;
                             })];
                             return nil;
                         })];
                     }
                 }];
            }else{
                //  no memo private key
                [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTipsNoMemoCannotWithdraw", @"账号没有备注私钥，不支持提币。")];
            }
        }
    }];
}

/**
 *  (private) 各种参数校验通过，处理提币转账请求。
 */
- (void)_processWithdrawCore:(NSString*)address
                      amount:(NSDecimalNumber*)n_amount
                  final_memo:(NSString*)final_memo
  final_intermediate_account:(id)final_intermediate_account
            from_public_memo:(NSString*)from_public_memo
{
    assert(_asset);
    assert(final_memo);
    assert(final_intermediate_account);
    
    id to_account = final_intermediate_account;
    id to_public = [[to_account objectForKey:@"options"] objectForKey:@"memo_key"];
    id memo_object = [[WalletManager sharedWalletManager] genMemoObject:final_memo from_public:from_public_memo to_public:to_public];
    if (!memo_object){
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"kVcTransferSubmitTipWalletNoMemoKey", @"没有备注私钥信息，不支持填写备注。")];
        return;
    }
    
    //  --- 开始构造OP ---
    id from_account = [_fullAccountData objectForKey:@"account"];
    id n_amount_pow = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:_precision_amount]];
    id op = @{
              @"fee":@{
                      @"amount":@0,
                      @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID,
                      },
              @"from":from_account[@"id"],
              @"to":to_account[@"id"],
              @"amount":@{
                      @"amount":@([n_amount_pow unsignedLongLongValue]),
                      @"asset_id":_asset[@"id"],
                      },
              @"memo":memo_object
              };
    
    //  请求网络广播
    [[[[BitsharesClientManager sharedBitsharesClientManager] transfer:op] then:(^id(id data) {
        //  设置脏标记，返回网关列表需要刷新。
        [TempManager sharedTempManager].withdrawBalanceDirty = YES;
        id account_id = [from_account objectForKey:@"id"];
        [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_id] then:(^id(id full_data) {
            NSLog(@"withdraw & refresh: %@", full_data);
            [self hideBlockView];
            [self refreshUI:full_data];
            [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTxFullOK", @"申请提币成功。")];
            //  [统计]
            [OrgUtils logEvents:@"txGatewayWithdrawFullOK" params:@{@"account":account_id, @"asset":_asset[@"symbol"]}];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils makeToast:NSLocalizedString(@"kVcDWSubmitTxOK", @"申请提币成功，但刷新界面数据失败，请稍后再试。")];
            //  [统计]
            [OrgUtils logEvents:@"txGatewayWithdrawOK" params:@{@"account":account_id, @"asset":_asset[@"symbol"]}];
            return nil;
        })];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        //  [统计]
        [OrgUtils logEvents:@"txGatewayWithdrawFailed" params:@{@"asset":_asset[@"symbol"]}];
        return nil;
    })];
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
                                     precision:_precision_amount];
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
    id str_amount = _tf_amount.text;
    
    GatewayAssetItemData* appext = [_withdrawAssetItem objectForKey:@"kAppExt"];
    NSString* symbol = appext.symbol;

    //  无效输入
    if (!str_amount || [str_amount isEqualToString:@""]){
        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_n_available], symbol];
        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        return;
    }

    //  获取输入的数量
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:str_amount];
    
    //  _n_available < n_amount
    if ([_n_available compare:n_amount] == NSOrderedAscending){
        //  数量不足
        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@(%@)", [OrgUtils formatFloatValue:_n_available], symbol, NSLocalizedString(@"kVcTransferTipAmountNotEnough", @"数量不足")];
        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].tintColor;
    }else{
        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_n_available], symbol];
        _cellAssetAvailable.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    }
    
    [self _refreshFinalValueUI:n_amount];
}

/**
 *  (private) 计算实际到账数量
 */
- (NSDecimalNumber*)_calcFinalValue:(NSDecimalNumber*)amount
{
    assert(amount);
    id n_final_value = [amount decimalNumberBySubtracting:_n_withdrawGateFee];
    if ([n_final_value compare:[NSDecimalNumber zero]] == NSOrderedAscending){
        n_final_value = [NSDecimalNumber zero];
    }
    return n_final_value;
}

/**
 *  (private) 刷新实际到账数量
 */
- (void)_refreshFinalValueUI:(NSDecimalNumber*)amount
{
    GatewayAssetItemData* appext = [_withdrawAssetItem objectForKey:@"kAppExt"];
    _cellFinalValue.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [self _calcFinalValue:amount],
                                            appext.backSymbol];
}

#pragma mark- UITextFieldDelegate delegate method
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _tf_address)
    {
        [_tf_amount becomeFirstResponder];
    }
    else if (textField == _tf_amount && _bSupportMemo && _tf_memo)
    {
        [_tf_memo becomeFirstResponder];
    }else{
        [self resignAllFirstResponder];
    }
    return YES;
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcFormData)
        return [_data_type_array count];
    else if (section == kVcAuxData)
        return [_aux_data_array count];
    else
        return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcFormData:
        {
            switch ([[_data_type_array objectAtIndex:indexPath.row] integerValue]) {
                case kVcSubMemoTitle:
                case kVcSubAddrTitle:
                case kVcSubAssetAmountAvailable:
                    return 28.0f;
                default:
                    break;
            }
        }
            break;
        case kVcAuxData:
            return 28.0f;
        default:
            break;
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section != kVcSubmit){
        return 0.01f;
    }
    return 20.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcFormData)
    {
        switch ([[_data_type_array objectAtIndex:indexPath.row] integerValue]) {
            case kVcSubAddrTitle:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.hideBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kVcDWCellWithdrawAddress", @"提币地址");
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                return cell;
            }
                break;
            case kVcSubAddress:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                [_mainTableView attachTextfieldToCell:cell tf:_tf_address];
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
                [_mainTableView attachTextfieldToCell:cell tf:_tf_amount];
                cell.accessoryView = _tf_amount;
                cell.hideTopLine = YES;
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
                cell.textLabel.text = NSLocalizedString(@"kVcDWCellWithdrawMemo", @"备注信息");
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                return cell;
            }
                break;
            case kVcSubMemo:
            {
                assert(_tf_memo);
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                [_mainTableView attachTextfieldToCell:cell tf:_tf_memo];
                cell.hideTopLine = YES;
                cell.hideBottomLine = YES;
                return cell;
            }
                break;
            default:
                break;
        }
    }else if (indexPath.section == kVcAuxData){
        id aux_data = [_aux_data_array objectAtIndex:indexPath.row];
        UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.text = [aux_data objectForKey:@"title"];
        cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorGray;
        cell.textLabel.font = [UIFont systemFontOfSize:13.0];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.hideTopLine = YES;
        cell.hideBottomLine = YES;
        cell.detailTextLabel.text = [aux_data objectForKey:@"value"];
        cell.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0];
        return cell;
    }else{
        if (indexPath.row == 0){
            return _cellFinalValue;
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
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == kVcSubmit && indexPath.row != 0){
        //  表单行为按钮点击
        [self resignAllFirstResponder];
        [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
            [self delay:^{
                [self gotoWithdrawCore];
            }];
        }];
    }
}

@end
