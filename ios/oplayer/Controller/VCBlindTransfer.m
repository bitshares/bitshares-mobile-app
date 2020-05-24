//
//  VCBlindTransfer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindTransfer.h"
#import "VCStealthTransferHelper.h"
#import "ViewBlindInputOutputItemCell.h"
#import "ViewEmptyInfoCell.h"

#import "VCBlindBackupReceipt.h"
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
    kVcSubInputTotalAmount = 0,
    kVcSubNetworkFee,
    kVcSubOutputTotalAmount,
    
    kVcSubMax
};

@interface VCBlindTransfer ()
{
    WsPromiseObject*            _result_promise;
    NSDictionary*               _curr_blind_asset;      //  当前选择的隐私收据关联的资产（所有隐私收据必须资产相同），收据列表为空时资产为 nil。
    
    UITableViewBase*            _mainTableView;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewEmptyInfoCell*          _cell_add_input;
    ViewEmptyInfoCell*          _cell_add_output;
    ViewBlockLabel*             _lbCommit;
    
    NSMutableArray*             _data_array_blind_input;
    NSMutableArray*             _data_array_blind_output;
    NSDictionary*               _auto_change_blind_output;
}

@end

@implementation VCBlindTransfer

-(void)dealloc
{
    _result_promise = nil;
    _curr_blind_asset = nil;
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
    _auto_change_blind_output = nil;
}

- (id)initWithBlindBalance:(id)blind_balance result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
        _curr_blind_asset = nil;
        _data_array_blind_output = [NSMutableArray array];
        _data_array_blind_input = [NSMutableArray array];
        _auto_change_blind_output = nil;
        if (blind_balance) {
            [self onSelectBlindBalanceDone:@[blind_balance]];
        }
    }
    return self;
}

- (NSDecimalNumber*)calcNetworkFee:(NSDecimalNumber*)n_output_num
{
    if (!_curr_blind_asset) {
        //  尚未选择收据
        return nil;
    }
    if (!n_output_num) {
        n_output_num = [NSDecimalNumber decimalNumberWithMantissa:[_data_array_blind_output count] exponent:0 isNegative:NO];
    }
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id n_fee = [chainMgr getNetworkCurrentFee:ebo_blind_transfer kbyte:nil day:nil output:n_output_num];
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
    return NSLocalizedString(@"kVcStTipUiBlindTransfer", @"【温馨提示】\n隐私转账：在多个隐私账户之间进行转账操作。\n\n找零和赠与：收据总金额减去输出总金额的剩余金额，如果满足找零所需手续费，则会自动找零到我的隐私账户，否则会自动赠与给第一个隐私账户。");
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
    
    //  UI - 选择收据按钮
    _cell_add_input = [[ViewEmptyInfoCell alloc] initWithText:NSLocalizedString(@"kVcStBtnSelectReceipt", @"选择隐私收据") iconName:@"iconAdd"];
    _cell_add_input.showCustomBottomLine = YES;
    _cell_add_input.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_input.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_input.userInteractionEnabled = YES;
    _cell_add_input.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_input.lbText.textColor = theme.textColorHighlight;
    
    //  UI - 添加隐私收款信息按钮
    _cell_add_output = [[ViewEmptyInfoCell alloc] initWithText:NSLocalizedString(@"kVcStBtnAddBlindOutput", @"添加收款信息") iconName:@"iconAdd"];
    _cell_add_output.showCustomBottomLine = YES;
    _cell_add_output.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_output.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_output.userInteractionEnabled = YES;
    _cell_add_output.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_output.lbText.textColor = theme.textColorHighlight;
    
    //  UI - 提交按钮
    _lbCommit = [self createCellLableButton:NSLocalizedString(@"kVcStBtnBlindTransfer", @"隐私转账")];
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
            //  title + all blind output + [auto change]
            return 1 + [_data_array_blind_output count] + (_auto_change_blind_output ? 1 : 0);
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
                [cell setItem:[_data_array_blind_output safeObjectAtIndex:indexPath.row - 1] ?: _auto_change_blind_output];
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
            
            switch (indexPath.row) {
                case kVcSubInputTotalAmount:
                {
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleTotalInputReceiptAmount", @"收据总金额");
                    if (_curr_blind_asset) {
                        id n_total_input = [self calcBlindInputTotalAmount];
                        id n_total_output = [self calcBlindOutputTotalAmount];
                        id n_fee = [self calcNetworkFee:nil];
                        
                        id base_str = [NSString stringWithFormat:@"%@ %@",
                                       [OrgUtils formatFloatValue:n_total_input usesGroupingSeparator:NO],
                                       _curr_blind_asset[@"symbol"]];
                        
                        if (n_fee && [n_total_input compare:[n_total_output decimalNumberByAdding:n_fee]] < 0) {
                            cell.detailTextLabel.textColor = theme.tintColor;
                            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@(%@)",
                                                         base_str,
                                                         NSLocalizedString(@"kVcTradeTipAmountNotEnough", @"数量不足")];
                        } else {
                            cell.detailTextLabel.textColor = theme.textColorNormal;
                            cell.detailTextLabel.text = base_str;
                        }
                        
                    } else {
                        cell.detailTextLabel.text = @"--";
                    }
                }
                    break;
                case kVcSubOutputTotalAmount:
                {
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleTotalOutputAmount", @"转账总金额");
                    cell.detailTextLabel.textColor = theme.buyColor;
                    if (_curr_blind_asset) {
                        id str_amount = [OrgUtils formatFloatValue:[self calcBlindOutputTotalAmount] usesGroupingSeparator:NO];
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", str_amount, _curr_blind_asset[@"symbol"]];
                    } else {
                        cell.detailTextLabel.text = @"--";
                    }
                }
                    break;
                case kVcSubNetworkFee:
                {
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleNetworkFee", @"广播手续费");
                    id n_fee = [self calcNetworkFee:nil];
                    if (n_fee) {
                        id str_amount = [OrgUtils formatFloatValue:n_fee usesGroupingSeparator:NO];
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", str_amount, _curr_blind_asset[@"symbol"]];
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
 *  事件 - 移除某个隐私输入收据
 */
- (void)onButtonClicked_InputRemove:(UIButton*)button
{
    [_data_array_blind_input removeObjectAtIndex:button.tag - 1];
    if ([_data_array_blind_input count] <= 0) {
        [self onSelectBlindBalanceDone:nil];
    }
    [self onCalcAutoChange];
    [_mainTableView reloadData];
}

/*
 *  事件 - 移除某个隐私输出
 */
- (void)onButtonClicked_OutputRemove:(UIButton*)button
{
    [_data_array_blind_output removeObjectAtIndex:button.tag - 1];
    [self onCalcAutoChange];
    [_mainTableView reloadData];
}

/*
 *  (private) 计算自动找零。
 */
- (void)onCalcAutoChange
{
    _auto_change_blind_output = nil;
    
    //  没有任何输出：不找零。
    if ([_data_array_blind_output count] <= 0) {
        return;
    }
    
    //  预估手续费失败：不找零。
    id n_output_num = [NSDecimalNumber decimalNumberWithMantissa:[_data_array_blind_output count] + 1 exponent:0 isNegative:NO];
    id n_fee = [self calcNetworkFee:n_output_num];
    if (!n_fee) {
        return;
    }
    
    //  找零余额小于等于零，直接返回。
    id n_left_balance = [[[self calcBlindInputTotalAmount] decimalNumberBySubtracting:[self calcBlindOutputTotalAmount]] decimalNumberBySubtracting:n_fee];
    if ([n_left_balance compare:[NSDecimalNumber zero]] <= 0) {
        return;
    }
    
    //  计算自动找零地址。REMARK：从当前所有输入的收据获取收款地址。如果能转出收据，说明持有收据对应的私钥。
    //  优先寻找主地址、其次寻找子地址。
    NSString* change_public_key = nil;
    id accounts_hash = [[AppCacheManager sharedAppCacheManager] getAllBlindAccounts];
    assert(accounts_hash);
    for (id blind_balance in _data_array_blind_input) {
        NSString* public_key = [blind_balance objectForKey:@"real_to_key"];
        assert(public_key);
        id blind_account = [accounts_hash objectForKey:public_key];
        if (blind_account) {
            NSString* parent_key = [blind_account objectForKey:@"parent_key"];
            if (parent_key && ![parent_key isEqualToString:@""]) {
                //  子账号（继续循环）
                change_public_key = public_key;
            } else {
                //  主账号（中断循环）
                change_public_key = public_key;
                break;
            }
        }
    }
    //  生成找零输出对象。
    if (change_public_key) {
        _auto_change_blind_output = @{@"public_key":change_public_key, @"n_amount":n_left_balance, @"bAutoChange":@YES};
    }
}

- (void)onAddOneOutputClicked
{
    if ([_data_array_blind_input count] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrPleaseSelectReceiptFirst", @"请先选择隐私收据。")];
        return;
    }
    
    //  可配置：限制最大隐私输出数量
    int allow_maximum_blind_output = 5;
    if ([_data_array_blind_output count] >= allow_maximum_blind_output) {
        [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStTipErrReachedMaxBlindOutputNum", @"最多只能添加 %@ 个收款信息。"),
                             @(allow_maximum_blind_output)]];
        return;
    }
    
    //  REMARK：在主线程调用，否则VC弹出可能存在卡顿缓慢的情况。
    [self delay:^{
        assert(_curr_blind_asset);
        //  计算添加输出的时候，点击【全部】按钮的最大余额值，如果计算失败则会取消按钮显示。
        NSDecimalNumber* n_max_balance = nil;
        id n_output_num = [NSDecimalNumber decimalNumberWithMantissa:[_data_array_blind_output count] + 1 exponent:0 isNegative:NO];
        id n_fee = [self calcNetworkFee:n_output_num];
        if (n_fee) {
            NSDecimalNumber* n_inputs = [self calcBlindInputTotalAmount];
            NSDecimalNumber* n_outputs = [self calcBlindOutputTotalAmount];
            n_max_balance = [[n_inputs decimalNumberBySubtracting:n_outputs] decimalNumberBySubtracting:n_fee];
            if ([n_max_balance compare:[NSDecimalNumber zero]] < 0) {
                n_max_balance = [NSDecimalNumber zero];
            }
        }
        
        //  转到添加权限界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCBlindOutputAddOne* vc = [[VCBlindOutputAddOne alloc] initWithResultPromise:result_promise
                                                                               asset:_curr_blind_asset
                                                                       n_max_balance:n_max_balance];
        [self pushViewController:vc
                         vctitle:NSLocalizedString(@"kVcTitleAddBlindOutput", @"添加收款信息")
                       backtitle:kVcDefaultBackTitleName];
        [result_promise then:(^id(id json_data) {
            //  {@"public_key":public_key, @"n_amount":n_amount}
            assert(json_data);
            //  添加
            [_data_array_blind_output addObject:json_data];
            [self onCalcAutoChange];
            //  刷新
            [_mainTableView reloadData];
            return nil;
        })];
    }];
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
    } else {
        _curr_blind_asset = nil;
    }
    if (!_curr_blind_asset) {
        [_data_array_blind_output removeAllObjects];
    }
}

- (void)onAddOneInputClicked
{
    [VCStealthTransferHelper processSelectReceipts:self
                          curr_blind_balance_arary:_data_array_blind_input
                                          callback:^(id new_blind_balance_array) {
        //  添加
        [self onSelectBlindBalanceDone:new_blind_balance_array];
        [self onCalcAutoChange];
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
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipSubmitPleaseSelectReceipt", @"请添加要转出的隐私收据信息。")];
        return;
    }
    
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    NSDecimalNumber* n_total_input = [self calcBlindInputTotalAmount];
    assert([n_total_input compare:n_zero] > 0);
    
    if ([_data_array_blind_output count] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStTipSubmitPleaseAddBlindOutput", @"请添加收款信息。")];
        return;
    }
    NSDecimalNumber* n_total_output = [self calcBlindOutputTotalAmount];
    assert([n_total_output compare:n_zero] > 0);
    
    assert(_curr_blind_asset);
    NSDecimalNumber* n_gift = nil;
    NSDecimalNumber* n_fee = nil;
    NSMutableArray* final_blind_output_array = nil;
    if (_auto_change_blind_output) {
        id n_output_num = [NSDecimalNumber decimalNumberWithMantissa:[_data_array_blind_output count] + 1 exponent:0 isNegative:NO];
        n_fee = [self calcNetworkFee:n_output_num];
        //  REMARK：如果已经有找零信息了，则手续费计算肯定是成功的。
        assert(n_fee);
        //  找零 = 总输入 - 总输出 - 手续费
        assert([[_auto_change_blind_output objectForKey:@"n_amount"] compare:[[n_total_input decimalNumberBySubtracting:n_total_output] decimalNumberBySubtracting:n_fee]] == 0);
        //  合并找零输出到总输出列表中。
        final_blind_output_array = [_data_array_blind_output mutableCopy];
        [final_blind_output_array addObject:_auto_change_blind_output];
    } else {
        n_fee = [self calcNetworkFee:nil];
        if (!n_fee) {
            [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStTipErrCannotBlindTransferInvalidCER", @"资产 %@ 手续费汇率未正确设置，不可转账。"),
                                 _curr_blind_asset[@"symbol"]]];
            return;
        }
        //  自动赠与（找零金额不足支持1个output的手续费时，考虑自动赠与给第一个output。）
        n_gift = [[n_total_input decimalNumberBySubtracting:n_total_output] decimalNumberBySubtracting:n_fee];
        if ([n_gift compare:n_zero] < 0) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrTotalInputReceiptNotEnough", @"收据总金额不足。")];
            return;
        }
        //  REMARK：gift 应该小于一个 output 的手续费，当然这里也应该小于总的手续费。
        assert([n_gift compare:n_fee] <= 0);
        //  余额刚好为0，不用赠与。
        if ([n_gift compare:n_zero] == 0) {
            n_gift = nil;
        }
        //  计算最终输出列表
        if (n_gift) {
            //  赠与给第一个输出。
            id mut_first_output = [[_data_array_blind_output firstObject] mutableCopy];
            [mut_first_output setObject:[[mut_first_output objectForKey:@"n_amount"] decimalNumberByAdding:n_gift] forKey:@"n_amount"];
            final_blind_output_array = [NSMutableArray array];
            [final_blind_output_array addObject:[mut_first_output copy]];
            //  添加其他输出
            if ([_data_array_blind_output count] > 1) {
                for (NSInteger i = 1; i < [_data_array_blind_output count]; ++i) {
                    [final_blind_output_array addObject:[_data_array_blind_output objectAtIndex:i]];
                }
            }
        } else {
            //  无赠与、无找零，直接默认输出。
            final_blind_output_array = _data_array_blind_output;
        }
    }
    
    //  二次确认
    NSString* value;
    NSString* symbol = [_curr_blind_asset objectForKey:@"symbol"];
    if (_auto_change_blind_output) {
        value = [NSString stringWithFormat:NSLocalizedString(@"kVcStTipAskConfrimBlindTransferWithAutoChange", @"您确定往 %1$@ 个隐私账户转账 %2$@ %3$@ 吗?\n\n自动找零 %4$@ %5$@\n\n广播手续费：%6$@ %6$@"),
                 @([_data_array_blind_output count]),
                 n_total_output, symbol,
                 [_auto_change_blind_output objectForKey:@"n_amount"], symbol,
                 n_fee, symbol];
    } else if (n_gift) {
        value = [NSString stringWithFormat:NSLocalizedString(@"kVcStTipAskConfrimBlindTransferWithAutoGift", @"您确定往 %1$@ 个隐私账户转账 %2$@ %3$@ 吗?\n\n自动赠与 %4$@ %5$@\n\n广播手续费：%6$@ %6$@"),
                 @([_data_array_blind_output count]),
                 n_total_output, symbol,
                 n_gift, symbol,
                 n_fee, symbol];
    } else {
        value = [NSString stringWithFormat:NSLocalizedString(@"kVcStTipAskConfrimBlindTransfer", @"您确定往 %1$@ 个隐私账户转账 %2$@ %3$@ 吗?n\n广播手续费：%4$@ %5$@"),
                 @([_data_array_blind_output count]),
                 n_total_output, symbol,
                 n_fee, symbol];
    }
    
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            //  解锁钱包
            [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
                if (unlocked) {
                    [self blindTransferCore:_curr_blind_asset
                                     inputs:[_data_array_blind_input copy]
                                    outputs:[final_blind_output_array copy]
                                      n_fee:n_fee];
                }
            }];
        }
    }];
}

- (void)blindTransferCore:(id)asset
                   inputs:(NSArray*)blind_balance_array
                  outputs:(NSArray*)blind_output_array
                    n_fee:(NSDecimalNumber*)n_fee
{
    assert(asset);
    assert(blind_balance_array && [blind_balance_array count] > 0);
    assert(blind_output_array && [blind_output_array count] > 0);
    assert(n_fee);
    
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
    
    //  生成隐私输出，和前面的输入盲因子相关联。
    id blind_output_args = [VCStealthTransferHelper genBlindOutputs:blind_output_array
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
    [[[[BitsharesClientManager sharedBitsharesClientManager] blindTransfer:op signPriKeyHash:sign_keys] then:^id(id tx_data) {
        [self hideBlockView];
        
        //  更新收据信息
        WalletManager* walletMgr = [WalletManager sharedWalletManager];
        AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
        //  a、删除已经提取的收据。
        for (id blind_balance in blind_balance_array) {
            [pAppCahce removeBlindBalance:blind_balance];
        }
        //  b、自动导入【我的】收据
        for (id item in [blind_output_args objectForKey:@"receipt_array"]) {
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
        [OrgUtils logEvents:@"txBlindTransferFullOK" params:@{@"asset":asset[@"symbol"]}];
        
        //  转到备份收据界面
        VCBlindBackupReceipt* vc = [[VCBlindBackupReceipt alloc] initWithTrxResult:tx_data];
        [self clearPushViewController:vc vctitle:NSLocalizedString(@"kVcTitleBackupBlindReceipt", @"备份收据") backtitle:kVcDefaultBackTitleName];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

@end
