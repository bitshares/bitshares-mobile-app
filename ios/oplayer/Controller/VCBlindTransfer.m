//
//  VCBlindTransfer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindTransfer.h"
#import "VCStealthTransferHelper.h"
#import "ViewBlindOutputInfoCell.h"
#import "ViewEmptyInfoCell.h"

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
    kVcSecAddOneInput,      //  添加输入按钮
    kVcSecBlindOutput,      //  隐私输出
    kVcSecAddOneOutput,     //  添加输入按钮
    kVcSecBalance,          //  转账总数量、可用数量、广播手续费
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

enum
{
    kVcSubAvailbleBalance = 0,
    kVcSubTotalTransferAmount,
    kVcSubNetworkFee,
    
    kVcSubMax
};

@interface VCBlindTransfer ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _curr_selected_asset;   //  当前选中资产
    NSDictionary*               _curr_balance_asset;    //  当前余额资产（输入数量对应的资产）REMARK：和选中资产可能不相同。
    NSDictionary*               _full_account_data;
    NSDecimalNumber*            _nCurrBalance;
    
    UITableViewBase*            _mainTableView;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewEmptyInfoCell*          _cell_add_input;
    ViewEmptyInfoCell*          _cell_add_output;
    ViewBlockLabel*             _lbCommit;
    
    NSMutableArray*             _data_array_blind_input;
    NSMutableArray*             _data_array_blind_output;
}

@end

@implementation VCBlindTransfer

-(void)dealloc
{
    _result_promise = nil;
    _nCurrBalance = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _cell_add_input = nil;
    _cell_add_output = nil;
    _lbCommit = nil;
    
    _data_array_blind_output = nil;
    _data_array_blind_input = nil;
}

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
        _curr_selected_asset = curr_asset;
        _full_account_data = full_account_data;
        _data_array_blind_output = [NSMutableArray array];
        _data_array_blind_input = [NSMutableArray array];
        [self _auxGenCurrBalanceAndBalanceAsset];
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

/*
 *  (private) 生成当前余额 以及 余额对应的资产。
 */
- (void)_auxGenCurrBalanceAndBalanceAsset
{
    assert(_full_account_data);
    _curr_balance_asset = _curr_selected_asset;
    _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_selected_asset];
}

- (NSString*)genTransferTipsMessage
{
    //    return [_opExtraArgs objectForKey:@"kMsgTips"] ?: @"";
    return @"【温馨提示】\n隐私转账可同时指定多个隐私地址。";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    self.view.backgroundColor = theme.appBackColor;
    
    //  TODO:6.0 icon
//    [self showRightImageButton:@"iconProposal" action:@selector(onRightButtonClicked) color:theme.textColorNormal];
    
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
    
    //  TODO:6.0
    _cell_add_input = [[ViewEmptyInfoCell alloc] initWithText:@"添加收据" iconName:@"iconAdd"];
    _cell_add_input.showCustomBottomLine = YES;
    _cell_add_input.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_input.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_input.userInteractionEnabled = YES;
    _cell_add_input.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_input.lbText.textColor = theme.textColorHighlight;
    
    _cell_add_output = [[ViewEmptyInfoCell alloc] initWithText:@"添加输出地址" iconName:@"iconAdd"];
    _cell_add_output.showCustomBottomLine = YES;
    _cell_add_output.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_output.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_output.userInteractionEnabled = YES;
    _cell_add_output.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_output.lbText.textColor = theme.textColorHighlight;
    
    _lbCommit = [self createCellLableButton:@"转账"];
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
            //  title + all blind input
            return 1 + [_data_array_blind_input count];
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
        case kVcSecBlindInput:
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
            return 28.0f;       //  TODO:6.0
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
        case kVcSecAddOneInput:
        case kVcSecAddOneOutput:
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
            ViewBlindOutputInfoCell* cell = (ViewBlindOutputInfoCell*)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewBlindOutputInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            cell.showCustomBottomLine = NO;
            cell.passThreshold = 0;
            [cell setTagData:indexPath.row];
            if (indexPath.row == 0) {
                [cell setItem:@{@"title":@YES}];
            } else {
                [cell setItem:[_data_array_blind_input objectAtIndex:indexPath.row - 1]];
            }
            return cell;
        }
            break;
        case kVcSecBlindOutput:
        {
            static NSString* identify = @"id_blind_output_info";
            ViewBlindOutputInfoCell* cell = (ViewBlindOutputInfoCell*)[tableView dequeueReusableCellWithIdentifier:identify];
            if (!cell)
            {
                cell = [[ViewBlindOutputInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            cell.showCustomBottomLine = NO;
            cell.passThreshold = 0;
            [cell setTagData:indexPath.row];
            if (indexPath.row == 0) {
                [cell setItem:@{@"title":@YES}];
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
            
            id symbol = _curr_selected_asset[@"symbol"];
            
            switch (indexPath.row) {
                case kVcSubTotalTransferAmount:
                    cell.textLabel.text = @"转账总数量";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:[self calcBlindInputTotalAmount] usesGroupingSeparator:NO], symbol];
                    break;
                case kVcSubAvailbleBalance:
                    cell.textLabel.text = @"可用余额";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_nCurrBalance usesGroupingSeparator:NO], symbol];
                    break;
                case kVcSubNetworkFee:
                {
                    cell.textLabel.text = @"广播手续费";
                    id n_fee = [[ChainObjectManager sharedChainObjectManager] getNetworkCurrentFee:ebo_transfer_to_blind kbyte:nil day:nil output:(NSDecimalNumber*)[NSDecimalNumber numberWithUnsignedInteger:[_data_array_blind_output count]]];
                    if (n_fee) {
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_fee usesGroupingSeparator:NO], symbol];
                    } else {
                        cell.detailTextLabel.text = @"未知";
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
            
        case kVcSecAddOneInput:
            return _cell_add_input;
        case kVcSecAddOneOutput:
            return _cell_add_output;
            
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
            case kVcSecAddOneInput:
                [self onAddOneInputClicked];
                break;
            case kVcSecAddOneOutput:
                [self onAddOneOutputClicked];
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
 *  事件 - 编辑某个输出
 */
- (void)onButtonClicked_Edit:(UIButton*)button
{
    //  TODO:6.0 edit
    [_data_array_blind_output removeObjectAtIndex:button.tag - 1];
    [_mainTableView reloadData];
}

- (void)onAddOneOutputClicked
{
    //  限制最大隐私输出数量
    int allow_maximum_blind_output = 10;
    if ([_data_array_blind_output count] >= allow_maximum_blind_output) {
        //  TODO:6.0 lang
        [OrgUtils makeToast:[NSString stringWithFormat:@"最多只能添加 %@ 个隐私输出。", @(allow_maximum_blind_output)]];
        return;
    }
    
    //  REMARK：在主线程调用，否则VC弹出可能存在卡顿缓慢的情况。
    [self delay:^{
        //  转到添加权限界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCBlindOutputAddOne* vc = [[VCBlindOutputAddOne alloc] initWithResultPromise:result_promise asset:_curr_selected_asset];
        [self pushViewController:vc
                         vctitle:@"新增隐私输出"
                       backtitle:kVcDefaultBackTitleName];
        [result_promise then:(^id(id json_data) {
            //  {@"public_key":public_key, @"n_amount":n_amount}
            assert(json_data);
            //            id public_key = [json_data objectForKey:@"public_key"];
            //            assert(public_key);
            //            //  移除（重复的）
            //            for (id item in _data_array_blind_output) {
            //                if ([[item objectForKey:@"public_key"] isEqualToString:public_key]) {
            //                    [_data_array_blind_output removeObject:item];
            //                    break;
            //                }
            //            }
            //  添加
            [_data_array_blind_output addObject:json_data];
            //  根据权重降序排列
            //            [self _sort_permission_list];
            //  刷新
            [_mainTableView reloadData];
            return nil;
        })];
    }];
}

- (void)onAddOneInputClicked
{
    //  TODO:6.0 添加 收据
    
    //    //  限制最大隐私输出数量
    //    int allow_maximum_blind_output = 10;
    //    if ([_data_array_blind_output count] >= allow_maximum_blind_output) {
    //        //  TODO:6.0 lang
    //        [OrgUtils makeToast:[NSString stringWithFormat:@"最多只能添加 %@ 个隐私输出。", @(allow_maximum_blind_output)]];
    //        return;
    //    }
    //
    
    [VCStealthTransferHelper processSelectReceipts:self callback:^(id new_blind_balance_array) {
        assert(new_blind_balance_array);
        //  添加
        [_data_array_blind_input removeAllObjects];
        //  TODO:6.0 数据结构格式重新设计
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        for (id blind_balance in new_blind_balance_array) {
            id amount = [[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"amount"];
            id asset = [chainMgr getChainObjectByID:[amount objectForKey:@"asset_id"]];
            id n_balance = [NSDecimalNumber decimalNumberWithMantissa:[[amount objectForKey:@"amount"] unsignedLongLongValue]
                                                             exponent:-[[asset objectForKey:@"precision"] integerValue]
                                                           isNegative:NO];
            [_data_array_blind_input addObject:@{
                //  {@"public_key":public_key, @"n_amount":n_amount}
                @"public_key": blind_balance[@"real_to_key"],
                @"n_amount": n_balance,
                @"blind_balance": blind_balance
            }];
        }
        //  刷新
        [_mainTableView reloadData];
    }];
}

- (NSDecimalNumber*)calcBlindInputTotalAmount
{
    NSDecimalNumber* n_total = [NSDecimalNumber zero];
    for (id item in _data_array_blind_input) {
        n_total = [n_total decimalNumberByAdding:[item objectForKey:@"n_amount"]];
    }
    return n_total;
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
    //  检测输入参数有效性
    if ([_data_array_blind_input count] <= 0) {
        [OrgUtils makeToast:@"请添加要转出的隐私收据信息。"];
        return;
    }
    
    NSDecimalNumber* n_total_input = [self calcBlindInputTotalAmount];
    if ([n_total_input compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:@"无效收据，余额信息为空。"];
        return;
    }
    
    id decrypted_memo = [[[_data_array_blind_input firstObject] objectForKey:@"blind_balance"] objectForKey:@"decrypted_memo"];
    assert(decrypted_memo);
    id asset_id = [[decrypted_memo objectForKey:@"amount"] objectForKey:@"asset_id"];
    id asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:asset_id];
    
    id n_output_num = [NSDecimalNumber numberWithUnsignedInteger:[_data_array_blind_output count]];
    id n_fee = [[ChainObjectManager sharedChainObjectManager] getNetworkCurrentFee:ebo_blind_transfer kbyte:nil day:nil
                                                                            output:n_output_num];
    
    if ([n_total_input compare:n_fee] <= 0) {
        [OrgUtils makeToast:@"收据金额太低，不足以支付手续费。"];
        return;
    }
    
    if ([_data_array_blind_output count] <= 0) {
        [OrgUtils makeToast:@"请添加隐私输出地址和数量。"];
        return;
    }
    
    //  TODO:6.0 asset
//    id core_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:@"1.3.0"];
    
    NSDecimalNumber* n_total_output = [self calcBlindOutputTotalAmount];
    //  TODO:6.0 余额判断 >0 < max_balance
    if ([_nCurrBalance compare:n_total_output] < 0) {
        return;
    }
    
    //  TODO:6.0 输入大于输出的时候，自动找零。
    
    //  检测输出参数有效性
    if ([[n_fee decimalNumberByAdding:n_total_output] compare:n_total_input] != 0) {
        [OrgUtils makeToast:@"输入和输出金额不相等。"];
        return;
    }
    
    //  解锁钱包
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            [self blindTransferCore:asset n_total_input:n_total_input n_total_output:n_total_output n_fee:n_fee];
        }
    }];
}

- (void)blindTransferCore:(id)asset
            n_total_input:(NSDecimalNumber*)n_total_input
           n_total_output:(NSDecimalNumber*)n_total_output
                    n_fee:(NSDecimalNumber*)n_fee
{
    //  根据隐私收据生成 blind_input 参数。同时返回所有相关盲因子以及签名KEY。
    id sign_keys = [NSMutableDictionary dictionary];
    id input_blinding_factors = [NSMutableArray array];
    id inputs = [VCStealthTransferHelper genBlindInputs:_data_array_blind_input
                                output_blinding_factors:input_blinding_factors
                                              sign_keys:sign_keys];
    
    //  生成隐私输出，和前面的输入盲因子相关联。
    id blind_output_args = [VCStealthTransferHelper genBlindOutputs:_data_array_blind_output
                                                        asset:asset
                                       input_blinding_factors:[input_blinding_factors copy]];
    
    //  构造OP
    NSInteger precision = [[asset objectForKey:@"precision"] integerValue];
    id fee_amount = [NSString stringWithFormat:@"%@", [n_fee decimalNumberByMultiplyingByPowerOf10:precision]];
    
    id op = @{
        @"fee":@{@"asset_id":asset[@"id"], @"amount":@([fee_amount unsignedLongLongValue])},
        @"inputs":[inputs copy],
        @"outputs": blind_output_args[@"blind_outputs"]
    };
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  REMARK：该操作不涉及账号，不需要处理提案的情况。仅n个私钥签名即可。
    [[[[BitsharesClientManager sharedBitsharesClientManager] blindTransfer:op signPriKeyHash:sign_keys] then:^id(id data) {
        NSLog(@"%@", data);
        [self hideBlockView];
        [OrgUtils makeToast:@"隐私转账成功。"];
        //  删除已提取的收据。
        AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
        for (id item in _data_array_blind_input) {
            id blind_balance = [item objectForKey:@"blind_balance"];
            [pAppCahce removeBlindBalance:blind_balance];
        }
        [pAppCahce saveStealthReceiptToFile];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

@end
