//
//  VCOtcMcAssetTransfer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcMcAssetTransfer.h"
#import "ViewOtcMcAssetSwitchCell.h"
#import "ViewTipsInfoCell.h"
#import "OtcManager.h"

enum
{
    kVcSecFromTo = 0,       //  FROM TO信息CELL
    kVcSecTransferCoin,     //  划转币种
    kVcSecAmount,           //  划转数量
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

enum
{
    kTailerTagAssetName = 1,
    kTailerTagSpace,
    kTailerTagBtnAll
};

@interface VCOtcMcAssetTransfer ()
{
    WsPromiseObject*        _result_promise;
    
    NSDictionary*           _auth_info;
    EOtcUserType            _user_type;
    NSArray*                _asset_list;
    NSDictionary*           _curr_merchant_asset;
    NSDictionary*           _full_account_data;
    NSDictionary*           _merchant_detail;
    NSMutableDictionary*    _argsFromTo;
    NSDecimalNumber*        _nCurrBalance;
    
    UITableViewBase*        _mainTableView;
    UITableViewCellBase*    _cellAssetAvailable;
    MyTextField*            _tf_amount;
    
    ViewTipsInfoCell*       _cell_tips;
    ViewBlockLabel*         _lbCommit;
}

@end

@implementation VCOtcMcAssetTransfer

-(void)dealloc
{
    _result_promise = nil;
    _nCurrBalance = nil;
    _asset_list = nil;
    _curr_merchant_asset = nil;
    _cellAssetAvailable = nil;
    _auth_info = nil;
    if (_tf_amount){
        _tf_amount.delegate = nil;
        _tf_amount = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _lbCommit = nil;
}

- (id)initWithAuthInfo:(id)auth_info
             user_type:(EOtcUserType)user_type
       merchant_detail:(id)merchant_detail
            asset_list:(id)asset_list
   curr_merchant_asset:(id)curr_merchant_asset
     full_account_data:(id)full_account_data
           transfer_in:(BOOL)transfer_in
        result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
        _auth_info = auth_info;
        _user_type = user_type;
        _merchant_detail = merchant_detail;
        _asset_list = asset_list;
        _curr_merchant_asset = curr_merchant_asset;
        _full_account_data = full_account_data;
        _argsFromTo = [NSMutableDictionary dictionary];
        if (transfer_in) {
            //  个人到商家
            [_argsFromTo setObject:[_merchant_detail objectForKey:@"btsAccount"] forKey:@"from"];
            [_argsFromTo setObject:[_merchant_detail objectForKey:@"otcAccount"] forKey:@"to"];
            [_argsFromTo setObject:@NO forKey:@"bFromIsMerchant"];
        } else {
            //  商家到个人
            [_argsFromTo setObject:[_merchant_detail objectForKey:@"otcAccount"] forKey:@"from"];
            [_argsFromTo setObject:[_merchant_detail objectForKey:@"btsAccount"] forKey:@"to"];
            [_argsFromTo setObject:@YES forKey:@"bFromIsMerchant"];
        }
        [self _genCurrBalance];
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

/*
 *  切换资产 or 交换FROM/TO的时候需要更新余额
 */
- (void)_genCurrBalance
{
    if ([[_argsFromTo objectForKey:@"bFromIsMerchant"] boolValue]) {
        _nCurrBalance = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", [_curr_merchant_asset objectForKey:@"available"]]];
    } else {
        //  链上余额
        _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:[_curr_merchant_asset objectForKey:@"kExtChainAsset"]];
    }
}
- (void)_drawUI_Balance:(BOOL)not_enough
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    NSString* symbol = [_curr_merchant_asset objectForKey:@"assetSymbol"];
    if (not_enough) {
        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %@(%@)",
                                                    NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                                                    _nCurrBalance,
                                                    symbol,
                                                    NSLocalizedString(@"kOtcMcAssetTransferBalanceNotEnough", @"余额不足")];
        _cellAssetAvailable.detailTextLabel.textColor = theme.tintColor;
    } else {
        _cellAssetAvailable.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %@",
                                                    NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                                                    _nCurrBalance,
                                                    symbol];
        _cellAssetAvailable.detailTextLabel.textColor = theme.textColorMain;
    }
}

- (void)_drawUI_newTailerAssetName:(NSString*)asset_symbol
{
    UILabel* lbAsset = nil;
    UILabel* lbSpace = nil;
    UIButton* btn = nil;
    for (UIView* view in _tf_amount.rightView.subviews) {
        switch (view.tag) {
            case kTailerTagAssetName:
                lbAsset = (UILabel*)view;
                lbAsset.text = asset_symbol;
                break;
            case kTailerTagSpace:
                lbSpace = (UILabel*)view;
                break;
            case kTailerTagBtnAll:
                btn = (UIButton*)view;
                break;
            default:
                break;
        }
        if (lbAsset && lbSpace && btn) {
            [self _resetTailerViewFrame:lbAsset space:lbSpace btn:btn tailer_view:lbAsset.superview];
            break;
        }
    }
}

- (void)_resetTailerViewFrame:(UILabel*)lbAsset space:(UILabel*)lbSpace btn:(UIButton*)btn tailer_view:(UIView*)tailer_view
{
    CGFloat fHeight = 31.0f;
    CGFloat fSpace = 12.0f;
    
    CGSize size1 = [ViewUtils auxSizeWithLabel:btn.titleLabel];
    CGSize size2 = [ViewUtils auxSizeWithLabel:lbSpace];
    CGSize size3 = [ViewUtils auxSizeWithLabel:lbAsset];
    
    CGFloat fWidth = size1.width + size2.width + size3.width + fSpace * 3;
    
    tailer_view.frame = CGRectMake(0, 0, fWidth, fHeight);
    lbAsset.frame = CGRectMake(fSpace * 1, 0, size3.width, fHeight);
    lbSpace.frame = CGRectMake(fSpace * 2 + size3.width, 0, size2.width, fHeight);
    btn.frame = CGRectMake(fSpace * 3 + size3.width + size2.width, 0, size1.width, fHeight);
}

- (UIView*)genTailerView:(NSString*)asset_symbol action:(NSString*)action
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UIView* tailer_view = [[UIView alloc] initWithFrame:CGRectZero];
    
    UILabel* lbAsset = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:13] superview:tailer_view];
    UILabel* lbSpace = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:tailer_view];
    lbAsset.text = asset_symbol;
    lbSpace.text = @"|";
    lbAsset.textColor = theme.textColorMain;
    lbSpace.textColor = theme.textColorGray;
    lbAsset.textAlignment = NSTextAlignmentRight;
    
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.titleLabel.font = [UIFont systemFontOfSize:13];
    [btn setTitle:action forState:UIControlStateNormal];
    [btn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onButtonTailerClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    
    //  设置TAG
    lbAsset.tag = kTailerTagAssetName;
    lbSpace.tag = kTailerTagSpace;
    btn.tag = kTailerTagBtnAll;
    
    //  设置 frame
    [self _resetTailerViewFrame:lbAsset space:lbSpace btn:btn tailer_view:tailer_view];
    
    [tailer_view addSubview:lbAsset];
    [tailer_view addSubview:lbSpace];
    [tailer_view addSubview:btn];
    
    return tailer_view;
}

/*
 *  事件 - 全部 按钮点击
 */
- (void)onButtonTailerClicked:(UIButton*)sender
{
    id new_value = _nCurrBalance;
    if ([new_value compare:[NSDecimalNumber zero]] < 0) {
        new_value = [NSDecimalNumber zero];
    }
    _tf_amount.text = [OrgUtils formatFloatValue:_nCurrBalance usesGroupingSeparator:NO];
    [self onAmountChanged];
}

- (NSString*)genTransferTipsMessage
{
    if ([[_argsFromTo objectForKey:@"bFromIsMerchant"] boolValue]) {
        return NSLocalizedString(@"kOtcMcAssetCellTipsTransferOut", @"【温馨提示】\n从商家账号转账给个人账号，需要平台协同处理，划转成功后请耐心等待。");
    } else {
        return NSLocalizedString(@"kOtcMcAssetCellTipsTransferIn", @"【温馨提示】\n从个人账号直接转账给商家账号。");
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  初始化UI
    _cellAssetAvailable = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    _cellAssetAvailable.backgroundColor = [UIColor clearColor];
    _cellAssetAvailable.hideBottomLine = YES;
    _cellAssetAvailable.accessoryType = UITableViewCellAccessoryNone;
    _cellAssetAvailable.selectionStyle = UITableViewCellSelectionStyleNone;
    _cellAssetAvailable.textLabel.text = NSLocalizedString(@"kOtcMcAssetTransferCellLabelAmount", @"数量");
    _cellAssetAvailable.textLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellAssetAvailable.textLabel.textColor = theme.textColorMain;
    _cellAssetAvailable.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
    _cellAssetAvailable.detailTextLabel.textColor = theme.textColorMain;
    [self _drawUI_Balance:NO];
    
    NSString* placeHolderAmount = NSLocalizedString(@"kOtcMcAssetTransferTfAmountPlaeholder", @"请输入划转数量");
    _tf_amount = [self createTfWithRect:[self makeTextFieldRectFull] keyboard:UIKeyboardTypeDecimalPad placeholder:placeHolderAmount];
    _tf_amount.updateClearButtonTintColor = YES;
    _tf_amount.showBottomLine = YES;
    _tf_amount.textColor = theme.textColorMain;
    _tf_amount.attributedPlaceholder = [ViewUtils placeholderAttrString:placeHolderAmount];
    
    //  绑定输入事件（限制输入）
    [_tf_amount addTarget:self action:@selector(onTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _tf_amount.rightView = [self genTailerView:[_curr_merchant_asset objectForKey:@"assetSymbol"]
                                        action:NSLocalizedString(@"kLabelSendAll", @"全部")];
    _tf_amount.rightViewMode = UITextFieldViewModeAlways;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 提示信息
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:[self genTransferTipsMessage]];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kOtcMcAssetSubmitBtnName", @"划转")];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_amount safeResignFirstResponder];
}

#pragma mark- for UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:[[_curr_merchant_asset objectForKey:@"kExtPrecision"] integerValue]];
}

- (void)onTextFieldDidChange:(UITextField*)textField
{
    //  更新小数点为APP默认小数点样式（可能和输入法中下小数点不同，比如APP里是`.`号，而输入法则是`,`号。
    [OrgUtils correctTextFieldDecimalSeparatorDisplayStyle:textField];
    [self onAmountChanged];
}

/**
 *  (private) 划转数量发生变化。
 */
- (void)onAmountChanged
{
    [self _drawUI_Balance:[_nCurrBalance compare:[OrgUtils auxGetStringDecimalNumberValue:_tf_amount.text]] < 0];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecTransferCoin || section == kVcSecAmount) {
        return 2;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecFromTo:
            return 72.0f;
        case kVcSecTransferCoin:
        case kVcSecAmount:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
        case kVcSecTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
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
        case kVcSecFromTo:
        {
            ViewOtcMcAssetSwitchCell* cell = [[ViewOtcMcAssetSwitchCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                                             reuseIdentifier:nil
                                                                                          vc:self];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            [cell setItem:_argsFromTo];
            return cell;
        }
            break;
        case kVcSecTransferCoin:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = NSLocalizedString(@"kOtcMcAssetTransferCellLabelAsset", @"资产");
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.textLabel.text = [_curr_merchant_asset objectForKey:@"assetSymbol"];
            }
            return cell;
        }
            break;
        case kVcSecAmount:
        {
            if (indexPath.row == 0) {
                return _cellAssetAvailable;
            } else {
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
        }
            break;
        case kVcSecTips:
        {
            return _cell_tips;
        }
            break;
        case kVcSecSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    //  not reached.
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcSecTransferCoin:
                [self onSelectAssetClicked];
                break;
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (void)onSelectAssetClicked
{
    id list = [_asset_list ruby_map:^id(id src) {
        return [src objectForKey:@"assetSymbol"];
    }];
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:NSLocalizedString(@"kOtcMcAssetSubmitAskSelectTransferAsset", @"请选择划转资产")
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:list
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            id select_asset_symbol = [list objectAtIndex:buttonIndex];
            NSString* current_asset_symbol = [_curr_merchant_asset objectForKey:@"assetSymbol"];
            if (![current_asset_symbol isEqualToString:select_asset_symbol]) {
                _curr_merchant_asset = [_asset_list objectAtIndex:buttonIndex];
                //  切换资产后重新输入
                [self _genCurrBalance];
                _tf_amount.text = @"";
                [self _drawUI_newTailerAssetName:[_curr_merchant_asset objectForKey:@"assetSymbol"]];
                [self _drawUI_Balance:NO];
                [self refreshView];
            }
        }
    }];
}

- (void)onSubmitClicked
{
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:_tf_amount.text];
    
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_amount compare:n_zero] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipPleaseInputAmount", @"请输入划转金额。")];
        return;
    }
    
    if ([_nCurrBalance compare:n_amount] < 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipBalanceNotEnough", @"余额不足。")];
        return;
    }
    
    if ([[_argsFromTo objectForKey:@"bFromIsMerchant"] boolValue]) {
        id value = [NSString stringWithFormat:NSLocalizedString(@"kOtcMcAssetSubmitAskTransferOut", @"您确认转出 %@ %@ 到个人账号吗？"),
                    n_amount, _curr_merchant_asset[@"assetSymbol"]];
        [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                               withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                              completion:^(NSInteger buttonIndex)
         {
            if (buttonIndex == 1)
            {
                [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                    if (unlocked) {
                        [self _execTransferOut:n_amount];
                    }
                }];
            }
        }];
    } else {
        id value = [NSString stringWithFormat:NSLocalizedString(@"kOtcMcAssetSubmitAskTransferIn", @"您确认转入 %@ %@ 到商家账号吗？"),
                    n_amount, _curr_merchant_asset[@"assetSymbol"]];
        [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                               withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                              completion:^(NSInteger buttonIndex)
         {
            if (buttonIndex == 1)
            {
                [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                    if (unlocked) {
                        [self _execTransferIn:n_amount];
                    }
                }];
            }
        }];
    }
}

/*
 *  (private) 转出 - 从商家账号转到个人账号
 */
- (void)_execTransferOut:(NSDecimalNumber*)n_amount
{
    //  获取用户自身的KEY进行签名。
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    assert(![walletMgr isLocked]);
    id active_permission = [[[walletMgr getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"active"];
    id sign_pub_keys = [walletMgr getSignKeys:active_permission assert_enough_permission:NO];
    //  TODO:2.9 手续费不足判断？
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[BitsharesClientManager sharedBitsharesClientManager] simpleTransfer:[_argsFromTo objectForKey:@"from"]
                                                                         to:[_argsFromTo objectForKey:@"to"]
                                                                      asset:[_curr_merchant_asset objectForKey:@"assetSymbol"]
                                                                     amount:[NSString stringWithFormat:@"%@", n_amount]
                                                                       memo:nil
                                                            memo_extra_keys:nil
                                                              sign_pub_keys:sign_pub_keys
                                                                  broadcast:NO] then:^id(id tx_data) {
        id err = [tx_data objectForKey:@"err"];
        if (err) {
            //  构造签名数据结构错误
            [self hideBlockView];
            [OrgUtils makeToast:err];
        } else {
            //  转账签名成功
            id tx = [tx_data objectForKey:@"tx"];
            assert(tx);
            //  调用平台API进行转出操作
            OtcManager* otc = [OtcManager sharedOtcManager];
            [[[otc queryMerchantAssetExport:[otc getCurrentBtsAccount] signatureTx:tx] then:^id(id data) {
                [self hideBlockView];
                [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipTransferOutOK", @"转出请求已提交，请耐心等待平台处理，请勿重复操作。")];
                //  返回上一个界面并刷新
                if (_result_promise) {
                    [_result_promise resolve:@YES];
                }
                [self closeOrPopViewController];
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [otc showOtcError:error];
                return nil;
            }];
        }
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

/*
 *  (private) 转入 - 从个人账号转入商家账号
 */
- (void)_execTransferIn:(NSDecimalNumber*)n_amount
{
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[[BitsharesClientManager sharedBitsharesClientManager] simpleTransfer:[_argsFromTo objectForKey:@"from"]
                                                                         to:[_argsFromTo objectForKey:@"to"]
                                                                      asset:[_curr_merchant_asset objectForKey:@"assetSymbol"]
                                                                     amount:[NSString stringWithFormat:@"%@", n_amount]
                                                                       memo:nil
                                                            memo_extra_keys:nil
                                                              sign_pub_keys:nil
                                                                  broadcast:YES] then:^id(id data) {
        [self hideBlockView];
        id err = [data objectForKey:@"err"];
        if (err) {
            //  错误
            [OrgUtils makeToast:err];
        } else {
            [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipTransferInOK", @"转入成功。")];
            //  返回上一个界面并刷新
            if (_result_promise) {
                [_result_promise resolve:@YES];
            }
            [self closeOrPopViewController];
        }
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

#pragma mark- for actions

- (void)onButtonClicked_Switched:(UIButton*)sender
{
    //  交换FROM TO
    if ([[_argsFromTo objectForKey:@"bFromIsMerchant"] boolValue]) {
        [_argsFromTo setObject:@NO forKey:@"bFromIsMerchant"];
    } else {
        [_argsFromTo setObject:@YES forKey:@"bFromIsMerchant"];
    }
    NSString* tmp = [_argsFromTo objectForKey:@"from"];
    [_argsFromTo setObject:[_argsFromTo objectForKey:@"to"] forKey:@"from"];
    [_argsFromTo setObject:tmp forKey:@"to"];
    //  刷新UI
    [_cell_tips updateLabelText:[self genTransferTipsMessage]];
    //  刷新余额
    [self _genCurrBalance];
    _tf_amount.text = @"";
    [self _drawUI_Balance:NO];
    //  刷新列表
    [_mainTableView reloadData];
}

@end
