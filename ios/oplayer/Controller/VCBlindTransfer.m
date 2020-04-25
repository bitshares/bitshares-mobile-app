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
    kVcSubOutputTotalAmount,
    kVcSubNetworkFee,
    
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
}

- (id)initWithBlindBalance:(id)blind_balance result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
        _curr_blind_asset = nil;
        _data_array_blind_output = [NSMutableArray array];
        _data_array_blind_input = [NSMutableArray array];
        if (blind_balance) {
            [self onSelectBlindBalanceDone:@[blind_balance]];
        }
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

- (NSString*)genTransferTipsMessage
{
    //  TODO:6.0
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
    _cell_add_input = [[ViewEmptyInfoCell alloc] initWithText:@"选择收据" iconName:@"iconAdd"];
    _cell_add_input.showCustomBottomLine = YES;
    _cell_add_input.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_input.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_input.userInteractionEnabled = YES;
    _cell_add_input.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_input.lbText.textColor = theme.textColorHighlight;
    
    _cell_add_output = [[ViewEmptyInfoCell alloc] initWithText:@"添加输出" iconName:@"iconAdd"];
    _cell_add_output.showCustomBottomLine = YES;
    _cell_add_output.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_output.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_output.userInteractionEnabled = YES;
    _cell_add_output.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_output.lbText.textColor = theme.textColorHighlight;
    
    _lbCommit = [self createCellLableButton:@"隐私转账"];
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
            
            switch (indexPath.row) {
                case kVcSubInputTotalAmount:
                {
                    cell.textLabel.text = @"收据总金额";//TODO:6.0
                    if (_curr_blind_asset) {
                        id str_amount = [OrgUtils formatFloatValue:[self calcBlindInputTotalAmount] usesGroupingSeparator:NO];
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", str_amount, _curr_blind_asset[@"symbol"]];
                    } else {
                        cell.detailTextLabel.text = @"--";
                    }
                }
                    break;
                case kVcSubOutputTotalAmount:
                {
                    cell.textLabel.text = @"输出总金额";
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
                    cell.textLabel.text = @"广播手续费";
                    id n_fee = [[ChainObjectManager sharedChainObjectManager] getNetworkCurrentFee:ebo_blind_transfer kbyte:nil day:nil output:(NSDecimalNumber*)[NSDecimalNumber numberWithUnsignedInteger:[_data_array_blind_output count]]];
                    if (n_fee) {
                        id str_amount = [OrgUtils formatFloatValue:n_fee usesGroupingSeparator:NO];
                        if (_curr_blind_asset) {
                            //  TODO:6.0 非 BTS 需要汇率换算 待处理
                            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", str_amount, _curr_blind_asset[@"symbol"]];
                        } else {
                            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@",
                                                         str_amount,
                                                         [ChainObjectManager sharedChainObjectManager].grapheneCoreAssetSymbol];
                        }
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
 *  事件 - 移除某个隐私输入收据
 */
- (void)onButtonClicked_InputRemove:(UIButton*)button
{
    [_data_array_blind_input removeObjectAtIndex:button.tag - 1];
    [_mainTableView reloadData];
}

/*
 *  事件 - 移除某个隐私输出
 */
- (void)onButtonClicked_OutputRemove:(UIButton*)button
{
    [_data_array_blind_output removeObjectAtIndex:button.tag - 1];
    [_mainTableView reloadData];
}

- (void)onAddOneOutputClicked
{
    if ([_data_array_blind_input count] <= 0) {
        [OrgUtils makeToast:@"请先选择隐私收据。"];
        return;
    }
    
    //  限制最大隐私输出数量
    int allow_maximum_blind_output = 10;
    if ([_data_array_blind_output count] >= allow_maximum_blind_output) {
        //  TODO:6.0 lang
        [OrgUtils makeToast:[NSString stringWithFormat:@"最多只能添加 %@ 个隐私输出。", @(allow_maximum_blind_output)]];
        return;
    }
    
    //  REMARK：在主线程调用，否则VC弹出可能存在卡顿缓慢的情况。
    [self delay:^{
        assert(_curr_blind_asset);
        //  转到添加权限界面
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCBlindOutputAddOne* vc = [[VCBlindOutputAddOne alloc] initWithResultPromise:result_promise asset:_curr_blind_asset];
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
            //  刷新
            [_mainTableView reloadData];
            return nil;
        })];
    }];
}

- (void)onSelectBlindBalanceDone:(id)new_blind_balance_array
{
    assert(new_blind_balance_array);
    [_data_array_blind_input removeAllObjects];
    [_data_array_blind_input addObjectsFromArray:new_blind_balance_array];
    //  TODO:6.0 更新asset
    
    if ([_data_array_blind_input count] > 0) {
        id amount = [[[_data_array_blind_input firstObject] objectForKey:@"decrypted_memo"] objectForKey:@"amount"];
        _curr_blind_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[amount objectForKey:@"asset_id"]];
    } else {
        _curr_blind_asset = nil;
    }
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
    
    id decrypted_memo = [[_data_array_blind_input firstObject] objectForKey:@"decrypted_memo"];
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
    //    if ([_nCurrBalance compare:n_total_output] < 0) {
    //        return;
    //    }
    
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
        for (id blind_balance in _data_array_blind_input) {
            [pAppCahce removeBlindBalance:blind_balance];
        }
        [pAppCahce saveWalletInfoToFile];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

@end
