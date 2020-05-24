//
//  VCTransferToBlind.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTransferToBlind.h"
#import "VCStealthTransferHelper.h"
#import "ViewBlindInputOutputItemCell.h"

#import "VCBlindBackupReceipt.h"
#import "VCSearchNetwork.h"
#import "VCBlindOutputAddOne.h"
#import "ViewTipsInfoCell.h"
#import "ViewEmptyInfoCell.h"

enum
{
    kVcSecOpAsst = 0,       //  要操作的资产
    kVcSecBlindOutput,      //  隐私输出
    kVcSecAddOne,           //  新增按钮
    kVcSecBalance,          //  转账总数量、可用数量、广播手续费
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

enum
{
    kVcSubAvailbleBalance = 0,
    kVcSubNetworkFee,
    kVcSubOutputTotalAmount,
    
    kVcSubMax
};

@interface VCTransferToBlind ()
{
    NSDictionary*               _curr_asset;            //  当前资产
    NSDictionary*               _full_account_data;
    NSDecimalNumber*            _nCurrBalance;
    
    UITableViewBase*            _mainTableView;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewEmptyInfoCell*          _cell_add_one;
    ViewBlockLabel*             _lbCommit;
    
    NSMutableArray*             _data_array_blind_output;
}

@end

@implementation VCTransferToBlind

-(void)dealloc
{
    _nCurrBalance = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _cell_add_one = nil;
    _lbCommit = nil;
}

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
{
    self = [super init];
    if (self) {
        assert(curr_asset);
        assert([ModelUtils assetAllowConfidential:curr_asset]);
        assert(![ModelUtils assetIsTransferRestricted:curr_asset]);
        assert(![ModelUtils assetNeedWhiteList:curr_asset]);
        assert(full_account_data);
        _curr_asset = curr_asset;
        _full_account_data = full_account_data;
        _data_array_blind_output = [NSMutableArray array];
        _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_asset];
    }
    return self;
}

- (NSDecimalNumber*)calcNetworkFee:(NSDecimalNumber*)n_output_num
{
    if (!n_output_num) {
        n_output_num = [NSDecimalNumber decimalNumberWithMantissa:[_data_array_blind_output count] exponent:0 isNegative:NO];
    }
    id n_fee = [[ChainObjectManager sharedChainObjectManager] getNetworkCurrentFee:ebo_transfer_to_blind
                                                                             kbyte:nil
                                                                               day:nil
                                                                            output:n_output_num];
    assert(n_fee);
    return n_fee;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (NSString*)genTransferTipsMessage
{
    return NSLocalizedString(@"kVcStTipUiTransferToBlind", @"【温馨提示】\n隐私转入：从比特股公开账号向隐私账户转账。并且可同时向多个隐私账户转账。\n\n如果是通过提案进行隐私转账，则不会生成隐私收据，在提案生效后直接输入创建提案时对应区块编号进行导入即可。");
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
    
    //  UI - 添加隐私收款信息按钮
    _cell_add_one = [[ViewEmptyInfoCell alloc] initWithText:NSLocalizedString(@"kVcStBtnAddBlindOutput", @"添加收款信息") iconName:@"iconAdd"];
    _cell_add_one.showCustomBottomLine = YES;
    _cell_add_one.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_one.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_one.userInteractionEnabled = YES;
    _cell_add_one.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_one.lbText.textColor = theme.textColorHighlight;
    
    //  UI - 提交按钮
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcStBtnTransferToBlind", @"隐私转入")];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcSecOpAsst:
            return 2;
        case kVcSecBlindOutput:
            //  title + all blind output
            return 1 + [_data_array_blind_output count];
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
        case kVcSecOpAsst:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
        case kVcSecBlindOutput:
        {
            if (indexPath.row == 0) {
                return 28.0f;   //  title
            } else {
                return 32.0f;
            }
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
        case kVcSecOpAsst:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = theme.textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = NSLocalizedString(@"kOtcMcAssetTransferCellLabelAsset", @"资产");
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                cell.textLabel.text = [_curr_asset objectForKey:@"symbol"];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.textLabel.textColor = theme.textColorMain;
            }
            return cell;
        }
            break;
        case kVcSecBlindOutput:
        {
            static NSString* identify = @"id_blind_output_info";
            ViewBlindInputOutputItemCell* cell = (ViewBlindInputOutputItemCell*)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewBlindInputOutputItemCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                           reuseIdentifier:identify
                                                                        vc:self
                                                                    action:@selector(onButtonClicked_OutputRemove:)];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            cell.showCustomBottomLine = NO;
            cell.itemType = kBlindItemTypeOutput;
            [cell setTagData:indexPath.row];
            if (indexPath.row == 0) {
                [cell setItem:@{@"title":@YES, @"num":@([_data_array_blind_output count])}];
            } else {
                [cell setItem:[_data_array_blind_output objectAtIndex:indexPath.row - 1]];
            }
            return cell;
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
            
            id symbol = _curr_asset[@"symbol"];
            
            switch (indexPath.row) {
                case kVcSubAvailbleBalance:
                {
                    NSDecimalNumber* n_total = [self calcBlindOutputTotalAmount];
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleAvailableBalance", @"可用余额");
                    id base_str = [NSString stringWithFormat:@"%@ %@",
                                   [OrgUtils formatFloatValue:_nCurrBalance usesGroupingSeparator:NO],
                                   symbol];
                    
                    NSDecimalNumber* n_max_balance = _nCurrBalance;
                    if ([[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID isEqualToString:[_curr_asset objectForKey:@"id"]]) {
                        //  转账资产和手续费资产相同，则扣除对应手续费。
                        id n_core_fee = [self calcNetworkFee:nil];
                        n_max_balance = [n_max_balance decimalNumberBySubtracting:n_core_fee];
                    }
                    
                    if ([n_max_balance compare:n_total] < 0) {
                        cell.detailTextLabel.textColor = theme.tintColor;
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@(%@)",
                                                     base_str,
                                                     NSLocalizedString(@"kVcTradeTipAmountNotEnough", @"数量不足")];
                    } else {
                        cell.detailTextLabel.textColor = theme.textColorNormal;
                        cell.detailTextLabel.text = base_str;
                    }
                }
                    break;
                case kVcSubOutputTotalAmount:
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleTotalOutputAmount", @"转账总金额");
                    cell.detailTextLabel.textColor = theme.buyColor;
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:[self calcBlindOutputTotalAmount] usesGroupingSeparator:NO], symbol];
                    break;
                case kVcSubNetworkFee:
                {
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleNetworkFee", @"广播手续费");
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:[self calcNetworkFee:nil]
                                                                                          usesGroupingSeparator:NO],
                                                 [ChainObjectManager sharedChainObjectManager].grapheneCoreAssetSymbol];
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
            case kVcSecOpAsst:
                [self onSelectAssetClicked];
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

- (void)onSelectAssetClicked
{
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
        if (asset_info){
            if (![ModelUtils assetAllowConfidential:asset_info]) {
                [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStTipErrForbidBlindTransfer", @"资产 %@ 已禁止隐私转账。"),
                                     asset_info[@"symbol"]]];
            } else if ([ModelUtils assetIsTransferRestricted:asset_info]) {
                [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStTipErrForbidNormalTransfer", @"资产 %@ 禁止转账。"),
                                     asset_info[@"symbol"]]];
            } else if ([ModelUtils assetNeedWhiteList:asset_info]) {
                [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStTipErrNeedWhiteList", @"资产 %@ 已开启白名单，禁止隐私转账。"),
                                     asset_info[@"symbol"]]];
            } else {
                NSString* new_id = [asset_info objectForKey:@"id"];
                NSString* old_id = [_curr_asset objectForKey:@"id"];
                if (![new_id isEqualToString:old_id]) {
                    _curr_asset = asset_info;
                    //  切换资产：更新余额、清空当前收款人、更新手续费
                    _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_asset];
                    [_data_array_blind_output removeAllObjects];
                    [_mainTableView reloadData];
                }
            }
        }
    }];
    
    [self pushViewController:vc
                     vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
                   backtitle:kVcDefaultBackTitleName];
}

/**
 *  事件 - 移除某个隐私输出
 */
- (void)onButtonClicked_OutputRemove:(UIButton*)button
{
    [_data_array_blind_output removeObjectAtIndex:button.tag - 1];
    //  刷新UI
    [_mainTableView reloadData];
}

- (void)onAddOneClicked
{
    //  可配置：限制最大隐私输出数量
    int allow_maximum_blind_output = 5;
    if ([_data_array_blind_output count] >= allow_maximum_blind_output) {
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStTipErrReachedMaxBlindOutputNum", @"最多只能添加 %@ 个收款信息。"),
                             @(allow_maximum_blind_output)]];
        return;
    }
    
    //  REMARK：在主线程调用，否则VC弹出可能存在卡顿缓慢的情况。
    [self delay:^{
        //  计算添加输出的时候，点击【全部】按钮的最大余额值，如果计算失败则会取消按钮显示。
        NSDecimalNumber* n_max_balance = [_nCurrBalance decimalNumberBySubtracting:[self calcBlindOutputTotalAmount]];
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        if ([chainMgr.grapheneCoreAssetID isEqualToString:[_curr_asset objectForKey:@"id"]]) {
            //  REMARK：转账资产是core资产时候，需要扣除手续费。
            id n_output_num = [NSDecimalNumber decimalNumberWithMantissa:[_data_array_blind_output count] + 1 exponent:0 isNegative:NO];
            id n_fee = [self calcNetworkFee:n_output_num];
            n_max_balance = [n_max_balance decimalNumberBySubtracting:n_fee];
        }
        if ([n_max_balance compare:[NSDecimalNumber zero]] < 0) {
            n_max_balance = [NSDecimalNumber zero];
        }
        
        //  转到添加权限界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCBlindOutputAddOne* vc = [[VCBlindOutputAddOne alloc] initWithResultPromise:result_promise
                                                                               asset:_curr_asset
                                                                       n_max_balance:n_max_balance];
        [self pushViewController:vc
                         vctitle:NSLocalizedString(@"kVcTitleAddBlindOutput", @"添加收款信息")
                       backtitle:kVcDefaultBackTitleName];
        [result_promise then:(^id(id json_data) {
            assert(json_data);
            //  添加
            [_data_array_blind_output addObject:json_data];
            //  刷新
            [_mainTableView reloadData];
            return nil;
        })];
    }];
}

- (NSDecimalNumber*)calcBlindOutputTotalAmount
{
    NSDecimalNumber* n_total = [NSDecimalNumber zero];
    for (id item in _data_array_blind_output) {
        n_total = [n_total decimalNumberByAdding:[item objectForKey:@"n_amount"]];
    }
    return n_total;
}

- (void)onSubmitClicked
{
    NSInteger i_output_count = [_data_array_blind_output count];
    if (i_output_count <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipSubmitPleaseAddBlindOutput", @"请添加收款信息。")];
        return;
    }
    
    NSDecimalNumber* n_total = [self calcBlindOutputTotalAmount];
    assert([n_total compare:[NSDecimalNumber zero]] > 0);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    NSDecimalNumber* n_max_balance = _nCurrBalance;
    id n_core_fee = [self calcNetworkFee:nil];
    if ([chainMgr.grapheneCoreAssetID isEqualToString:[_curr_asset objectForKey:@"id"]]) {
        n_max_balance = [n_max_balance decimalNumberBySubtracting:n_core_fee];
    }
    if ([n_max_balance compare:n_total] < 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipSubmitBalanceNotEnough", @"余额不足。")];
        return;
    }
    
    //  生成隐私输出
    id blind_output_args = [VCStealthTransferHelper genBlindOutputs:_data_array_blind_output
                                                              asset:_curr_asset
                                             input_blinding_factors:nil];
    //  生成所有隐私输出承诺盲因子之和。
    id receipt_array = [blind_output_args objectForKey:@"receipt_array"];
    id blinding_factor = [VCStealthTransferHelper blindSum:[receipt_array ruby_map:^id(id src) {
        return [src objectForKey:@"blind_factor"];
    }]];
    
    //  构造OP
    id s_total = [NSString stringWithFormat:@"%@", [n_total decimalNumberByMultiplyingByPowerOf10:[_curr_asset[@"precision"] integerValue]]];
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    
    id core_asset = [chainMgr getChainObjectByID:chainMgr.grapheneCoreAssetID];
    assert(core_asset);
    id s_fee = [NSString stringWithFormat:@"%@", [n_core_fee decimalNumberByMultiplyingByPowerOf10:[core_asset[@"precision"] integerValue]]];
    
    id op = @{
        @"fee":@{@"asset_id":core_asset[@"id"], @"amount":@([s_fee unsignedLongLongValue])},
        @"amount":@{@"asset_id":_curr_asset[@"id"], @"amount":@([s_total unsignedLongLongValue])},
        @"from":op_account[@"id"],
        @"blinding_factor":blinding_factor,
        @"outputs":blind_output_args[@"blind_outputs"]
    };
    
    NSString* value;
    if (i_output_count > 1) {
        value = [NSString stringWithFormat:NSLocalizedString(@"kVcStTipAskConfrimTransferToBlindN", @"您确定往 %1$@ 个隐私账户合计转入 %2$@ %3$@ 吗？\n\n广播手续费：%4$@ %5$@"),
                 @(i_output_count),
                 n_total,
                 _curr_asset[@"symbol"],
                 n_core_fee, core_asset[@"symbol"]];
    } else {
        value = [NSString stringWithFormat:NSLocalizedString(@"kVcStTipAskConfrimTransferToBlind1", @"您确定往隐私账户转入 %@ %@ 吗？\n\n广播手续费：%@ %@"),
                 n_total,
                 _curr_asset[@"symbol"],
                 n_core_fee, core_asset[@"symbol"]];
    }
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked) {
                    //  确保有权限发起普通交易，否则作为提案交易处理。
                    [self GuardProposalOrNormalTransaction:ebo_transfer_to_blind
                                     using_owner_authority:NO invoke_proposal_callback:NO
                                                    opdata:op
                                                 opaccount:op_account
                                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
                     {
                        assert(!isProposal);
                        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
                        [[[[BitsharesClientManager sharedBitsharesClientManager] transferToBlind:op] then:^id(id tx_data) {
                            [self hideBlockView];
                            
                            //  自动导入【我的】收据
                            WalletManager* walletMgr = [WalletManager sharedWalletManager];
                            AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
                            for (id item in receipt_array) {
                                id blind_balance = [item objectForKey:@"blind_balance"];
                                assert(blind_balance);
                                //  REMARK：有隐私账号私钥的收据即为我自己的收据。
                                id real_to_key = [blind_balance objectForKey:@"real_to_key"];
                                if (real_to_key && [walletMgr havePrivateKey:real_to_key]) {
                                    [pAppCahce appendBlindBalance:blind_balance];
                                }
                            }
                            [pAppCahce saveWalletInfoToFile];
                            
                            //  统计
                            [OrgUtils logEvents:@"txTransferToBlindFullOK" params:@{@"asset":_curr_asset[@"symbol"]}];
                            
                            //  转到备份收据界面
                            VCBlindBackupReceipt* vc = [[VCBlindBackupReceipt alloc] initWithTrxResult:tx_data];
                            [self clearPushViewController:vc
                                                  vctitle:NSLocalizedString(@"kVcTitleBackupBlindReceipt", @"备份收据")
                                                backtitle:kVcDefaultBackTitleName];
                            return nil;
                        }] catch:^id(id error) {
                            [self hideBlockView];
                            NSLog(@"%@", error);
                            [OrgUtils showGrapheneError:error];
                            return nil;
                        }];
                    }];
                }
            }];
        }
    }];
}

@end
