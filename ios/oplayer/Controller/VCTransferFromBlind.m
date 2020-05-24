//
//  VCTransferFromBlind.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTransferFromBlind.h"
#import "VCStealthTransferHelper.h"
#import "ViewBlindInputOutputItemCell.h"
#import "ViewEmptyInfoCell.h"

#import "VCPaySuccess.h"
#import "VCSelectBlindBalance.h"
#import "VCSearchNetwork.h"
#import "VCBlindOutputAddOne.h"
#import "ViewTipsInfoCell.h"

#import "GrapheneSerializer.h"
#import "GraphenePublicKey.h"
#import "GraphenePrivateKey.h"

enum
{
    kVcSecBlindInput = 0,   //  隐私输入
    kVcSecAddOne,           //  新增按钮
    kVcSecToAccount,        //  目标账号
    kVcSecBalance,          //  转账总数量、可用数量、广播手续费
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

enum
{
    kVcSubInputTotalAmount = 0,
    kVcSubNetworkFee,
    kVcSubActualAmount,
    
    kVcSubMax
};

@interface VCTransferFromBlind ()
{
    NSDictionary*               _curr_blind_asset;      //  当前选择的隐私收据关联的资产（所有隐私收据必须资产相同），收据列表为空时资产为 nil。
    
    UITableViewBase*            _mainTableView;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewEmptyInfoCell*          _cell_add_one;
    ViewBlockLabel*             _lbCommit;
    
    NSMutableArray*             _data_array_blind_input;
    NSDictionary*               _to_account;
    NSDecimalNumber*            _nFee;
}

@end

@implementation VCTransferFromBlind

-(void)dealloc
{
    _curr_blind_asset = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _cell_add_one = nil;
    _lbCommit = nil;
    _to_account = nil;
}

- (id)initWithBlindBalance:(id)blind_balance
{
    self = [super init];
    if (self) {
        //@"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
        //@"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
        //@"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
        //@"decrypted_memo": @{
        //    @"amount": @{@"asset_id": @"1.3.0", @"amount": @12300000},              //  转账用，显示用。
        //    @"blinding_factor": @"",                                                //  转账用
        //    @"commitment": @"",                                                     //  转账用
        //    @"check": @331,                                                         //  导入check用，显示用。
        //}
        _to_account = nil;
        _data_array_blind_input = [NSMutableArray array];
        _curr_blind_asset = nil;
        _nFee = nil;
        if (blind_balance) {
            [self onSelectBlindBalanceDone:@[blind_balance]];
        }
    }
    return self;
}

- (NSDecimalNumber*)calcNetworkFee
{
    if (!_curr_blind_asset) {
        //  尚未选择收据
        return nil;
    }
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id n_fee = [chainMgr getNetworkCurrentFee:ebo_transfer_from_blind kbyte:nil day:nil output:nil];
    id asset_id = [_curr_blind_asset objectForKey:@"id"];
    if (![asset_id isEqualToString:chainMgr.grapheneCoreAssetID]) {
        id core_exchange_rate = [[_curr_blind_asset objectForKey:@"options"] objectForKey:@"core_exchange_rate"];
        n_fee = [ModelUtils multiplyAndRoundupNetworkFee:[chainMgr getChainObjectByID:chainMgr.grapheneCoreAssetID]
                                                   asset:_curr_blind_asset
                                              n_core_fee:n_fee
                                      core_exchange_rate:core_exchange_rate];
        if (!n_fee) {
            //  汇率数据异常
            return nil;
        }
    }
    return n_fee;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (NSString*)genTransferTipsMessage
{
    return NSLocalizedString(@"kVcStTipUiTransferFromBlind", @"【温馨提示】\n隐私转出：从隐私账户向比特股公开账号转账。");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    self.view.backgroundColor = theme.appBackColor;
    
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
    
    //  UI - 选择隐私收据按钮
    _cell_add_one = [[ViewEmptyInfoCell alloc] initWithText:NSLocalizedString(@"kVcStBtnSelectReceipt", @"选择隐私收据") iconName:@"iconAdd"];
    _cell_add_one.showCustomBottomLine = YES;
    _cell_add_one.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_one.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_one.userInteractionEnabled = YES;
    _cell_add_one.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_one.lbText.textColor = theme.textColorHighlight;
    
    //  UI - 提交按钮
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcStBtnTransferFromBlind", @"隐私转出")];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcSecBlindInput:
            //  title + all blind output
            return 1 + [_data_array_blind_input count];
        case kVcSecToAccount:
            return 2;
        case kVcSecBalance:
            return kVcSubMax;
        default:
            break;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecBlindInput:
        {
            if (indexPath.row == 0) {
                return 28.0f;   //  title
            } else {
                return 32.0f;
            }
        }
            break;
        case kVcSecToAccount:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
        case kVcSecBalance:
            return 28.0f;
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
    switch (section) {
        case kVcSecAddOne:
            return 0.01f;
        case kVcSecBalance:
            return 0.01f;
        default:
            break;
    }
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
        case kVcSecBlindInput:
        {
            static NSString* identify = @"id_blind_input_info";
            ViewBlindInputOutputItemCell* cell = (ViewBlindInputOutputItemCell*)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewBlindInputOutputItemCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                           reuseIdentifier:identify
                                                                        vc:self
                                                                    action:@selector(onButtonClicked_InputRemove:)];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            cell.showCustomBottomLine = NO;
            cell.itemType = kBlindItemTypeInput;
            [cell setTagData:indexPath.row];
            if (indexPath.row == 0) {
                [cell setItem:@{@"title":@YES, @"num":@([_data_array_blind_input count])}];
            } else {
                [cell setItem:[_data_array_blind_input objectAtIndex:indexPath.row - 1]];
            }
            return cell;
        }
            break;
        case kVcSecToAccount:
        {
            if (indexPath.row == 0) {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.hideBottomLine = YES;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"kVcAssetOpCellTitleIssueTargetAccount", @"目标账户");
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.textColor = theme.textColorMain;
                return cell;
            } else {
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
        }
            break;
        case kVcSecBalance:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = theme.textColorGray;
            cell.detailTextLabel.textColor = theme.textColorNormal;
            cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.hideTopLine = YES;
            cell.hideBottomLine = YES;
            
            switch (indexPath.row) {
                case kVcSubInputTotalAmount:
                {
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleTotalInputReceiptAmount", @"收据总金额");
                    if (_curr_blind_asset) {
                        id str_amount = [OrgUtils formatFloatValue:[self calcBlindInputTotalAmount] usesGroupingSeparator:NO];
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", str_amount, _curr_blind_asset[@"symbol"]];
                    } else {
                        cell.detailTextLabel.text = @"--";
                    }
                }
                    break;
                case kVcSubNetworkFee:
                {
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleNetworkFee", @"广播手续费");
                    if (_nFee) {
                        id str_amount = [OrgUtils formatFloatValue:_nFee usesGroupingSeparator:NO];
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", str_amount, _curr_blind_asset[@"symbol"]];
                    } else {
                        cell.detailTextLabel.text = @"--";
                    }
                }
                    break;
                case kVcSubActualAmount:
                {
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleActualAmount", @"实际到账");
                    cell.detailTextLabel.textColor = theme.buyColor;
                    if (_nFee) {
                        NSDecimalNumber* n_total = [self calcBlindInputTotalAmount];
                        id n_final = [n_total decimalNumberBySubtracting:_nFee];
                        id n_zero = [NSDecimalNumber zero];
                        if ([n_final compare:n_zero] < 0) {
                            n_final = n_zero;
                        }
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@",
                                                     [OrgUtils formatFloatValue:n_final usesGroupingSeparator:NO],
                                                     _curr_blind_asset[@"symbol"]];
                    } else {
                        cell.detailTextLabel.text = @"--";
                    }
                }
                    break;
                default:
                    break;
            }
            return cell;
        }
            break;
            
        case kVcSecTips:
            return _cell_tips;
            
        case kVcSecAddOne:
            return _cell_add_one;
            
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
            case kVcSecToAccount:
            {
                if (indexPath.row == 1) {
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
            }
                break;
            case kVcSecAddOne:
                [self onAddOneClicked];
                break;
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

/**
 *  事件 - 移除某个隐私输入收据
 */
- (void)onButtonClicked_InputRemove:(UIButton*)button
{
    [_data_array_blind_input removeObjectAtIndex:button.tag - 1];
    if ([_data_array_blind_input count] <= 0) {
        [self onSelectBlindBalanceDone:nil];
    }
    [_mainTableView reloadData];
}

- (void)onSelectBlindBalanceDone:(id)new_blind_balance_array
{
    [_data_array_blind_input removeAllObjects];
    if (new_blind_balance_array && [new_blind_balance_array count] > 0) {
        [_data_array_blind_input addObjectsFromArray:new_blind_balance_array];
    }
    if ([_data_array_blind_input count] > 0) {
        id amount = [[[_data_array_blind_input firstObject] objectForKey:@"decrypted_memo"] objectForKey:@"amount"];
        _curr_blind_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[amount objectForKey:@"asset_id"]];
        assert(_curr_blind_asset);
    } else {
        _curr_blind_asset = nil;
    }
    //  重新计算手续费
    _nFee = [self calcNetworkFee];
}

- (void)onAddOneClicked
{
    [VCStealthTransferHelper processSelectReceipts:self
                          curr_blind_balance_arary:_data_array_blind_input
                                          callback:^(id new_blind_balance_array) {
        assert(new_blind_balance_array);
        //  添加
        [self onSelectBlindBalanceDone:new_blind_balance_array];
        //  刷新
        [_mainTableView reloadData];
    }];
}


- (NSDecimalNumber*)calcBlindInputTotalAmount
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    NSDecimalNumber* n_total = [NSDecimalNumber zero];
    for (id blind_balance in _data_array_blind_input) {
        id decrypted_memo = [blind_balance objectForKey:@"decrypted_memo"];
        id amount = [decrypted_memo objectForKey:@"amount"];
        id asset = [chainMgr getChainObjectByID:[amount objectForKey:@"asset_id"]];
        assert(asset);
        id n_amount = [NSDecimalNumber decimalNumberWithMantissa:[[amount objectForKey:@"amount"] unsignedLongLongValue]
                                                        exponent:-[[asset objectForKey:@"precision"] integerValue]
                                                      isNegative:NO];
        n_total = [n_total decimalNumberByAdding:n_amount];
    }
    return n_total;
}

- (void)onSubmitClicked
{
    if ([_data_array_blind_input count] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipSubmitPleaseSelectReceipt", @"请添加要转出的隐私收据信息。")];
        return;
    }
    
    if (!_to_account) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrPleaseSelectToPublicAccount", @"请选择要转出的目标账号。")];
        return;
    }
    
    NSDecimalNumber* n_total = [self calcBlindInputTotalAmount];
    assert([n_total compare:[NSDecimalNumber zero]] > 0);
    
    assert(_curr_blind_asset);
    if (!_nFee) {
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStTipErrCannotBlindTransferInvalidCER", @"资产 %@ 手续费汇率未正确设置，不可转账。"),
                             _curr_blind_asset[@"symbol"]]];
        return;
    }
    
    if ([n_total compare:_nFee] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrTotalInputReceiptLowThanNetworkFee", @"收据金额太低，不足以支付手续费。")];
        return;
    }
    
    //  解锁钱包
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            [self transferFromBlindCore:_data_array_blind_input asset:_curr_blind_asset n_total:n_total n_fee:_nFee];
        }
    }];
}

- (void)transferFromBlindCore:(NSArray*)blind_balance_array asset:(id)asset n_total:(id)n_total n_fee:(id)n_fee
{
    assert(blind_balance_array && [blind_balance_array count] > 0);
    
    //  根据隐私收据生成 blind_input 参数。同时返回所有相关盲因子以及签名KEY。
    id sign_keys = [NSMutableDictionary dictionary];
    id input_blinding_factors = [NSMutableArray array];
    id inputs = [VCStealthTransferHelper genBlindInputs:blind_balance_array
                                output_blinding_factors:input_blinding_factors
                                              sign_keys:sign_keys
                                     extra_pub_pri_hash:nil];
    if (!inputs) {
        return;
    }
    
    //  所有盲因子求和
    id blinding_factor = [VCStealthTransferHelper blindSum:input_blinding_factors];
    
    //  构造OP
    NSInteger precision = [[asset objectForKey:@"precision"] integerValue];
    id n_transfer_amount = [n_total decimalNumberBySubtracting:n_fee];
    id transfer_amount = [NSString stringWithFormat:@"%@", [n_transfer_amount decimalNumberByMultiplyingByPowerOf10:precision]];
    id fee_amount = [NSString stringWithFormat:@"%@", [n_fee decimalNumberByMultiplyingByPowerOf10:precision]];
    
    id op = @{
        @"fee":@{@"asset_id":asset[@"id"], @"amount":@([fee_amount unsignedLongLongValue])},
        @"amount":@{@"asset_id":asset[@"id"], @"amount":@([transfer_amount unsignedLongLongValue])},
        @"to":_to_account[@"id"],
        @"blinding_factor":blinding_factor,
        @"inputs":inputs
    };
    
    id amount_string = [NSString stringWithFormat:@"%@ %@", n_transfer_amount, asset[@"symbol"]];
    
    id value = [NSString stringWithFormat:NSLocalizedString(@"kVcStTipAskConfrimTransferFromBlind", @"您确定从隐私账户转出 %@ 到 %@ 账号吗？\n\n广播手续费：%@ %@"),
                amount_string,
                _to_account[@"name"],
                n_fee, asset[@"symbol"]];
    
    //  二次确认
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            
            //  REMARK：该操作不涉及账号，不需要处理提案的情况。仅n个私钥签名即可。
            [[[[BitsharesClientManager sharedBitsharesClientManager] transferFromBlind:op
                                                                        signPriKeyHash:sign_keys] then:^id(id tx_data) {
                [self hideBlockView];
                //  删除已提取的收据。
                AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
                for (id blind_balance in blind_balance_array) {
                    [pAppCahce removeBlindBalance:blind_balance];
                }
                [pAppCahce saveWalletInfoToFile];
                
                //  统计
                [OrgUtils logEvents:@"txTransferFromBlindFullOK" params:@{@"asset":asset[@"symbol"]}];
                
                //  转到结果界面。
                VCPaySuccess* vc = [[VCPaySuccess alloc] initWithResult:tx_data
                                                             to_account:_to_account
                                                          amount_string:amount_string
                                                     success_tip_string:NSLocalizedString(@"kVcStTipLabelTransferFromBlindSuccess", @"从隐私转出成功")];
                [self clearPushViewController:vc vctitle:@"" backtitle:kVcDefaultBackTitleName];
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [OrgUtils showGrapheneError:error];
                return nil;
            }];
        }
    }];
}

@end
