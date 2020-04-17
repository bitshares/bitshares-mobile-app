//
//  VCTransferFromBlind.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTransferFromBlind.h"
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
    kVcSecBlindOutput = 0,  //  隐私输出
    kVcSecAddOne,           //  新增按钮
    kVcSecToAccount,        //  目标账号
    kVcSecBalance,          //  转账总数量、可用数量、广播手续费
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

enum
{
    kVcSubTotalTransferAmount = 0,
    kVcSubNetworkFee,
    
    kVcSubMax
};

@interface VCTransferFromBlind ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _curr_selected_asset;   //  当前资产（可能为nil）
    NSDecimalNumber*            _nCurrBalance;
    
    UITableViewBase*            _mainTableView;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewEmptyInfoCell*          _cell_add_one;
    ViewBlockLabel*             _lbCommit;
    
    NSMutableArray*             _data_array_blind_output;
    NSDictionary*               _to_account;
}

@end

@implementation VCTransferFromBlind

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
    _cell_add_one = nil;
    _lbCommit = nil;
    _to_account = nil;
}

- (id)initWithBlindBalance:(id)blind_balance result_promise:(WsPromiseObject*)result_promise
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
        _result_promise = result_promise;
        _data_array_blind_output = [NSMutableArray array];
        if (blind_balance) {
            id amount = [[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"amount"];
            assert(amount);
            _curr_selected_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[amount objectForKey:@"asset_id"]];
            _nCurrBalance = [NSDecimalNumber decimalNumberWithMantissa:[[amount objectForKey:@"amount"] unsignedLongLongValue]
                                                              exponent:-[[_curr_selected_asset objectForKey:@"precision"] integerValue]
                                                            isNegative:NO];
            [_data_array_blind_output addObject:@{
                //  {@"public_key":public_key, @"n_amount":n_amount}
                @"public_key": blind_balance[@"real_to_key"],
                @"n_amount": _nCurrBalance,
                @"blind_balance": blind_balance
            }];
        } else {
            _curr_selected_asset = nil;
            _nCurrBalance = [NSDecimalNumber zero];
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
    //    return [_opExtraArgs objectForKey:@"kMsgTips"] ?: @"";
    return @"【温馨提示】\n隐私转账可同时转出多个隐私余额到指定公共账号。";
}

//- (void)onRightButtonClicked
//{
//    VCBlindBalance* vc = [[VCBlindBalance alloc] init];
//    //  TODO:6.0 lang
//    [self pushViewController:vc vctitle:@"隐私资产" backtitle:kVcDefaultBackTitleName];
//}

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
    _cell_add_one = [[ViewEmptyInfoCell alloc] initWithText:@"添加收据" iconName:@"iconAdd"];
    _cell_add_one.showCustomBottomLine = YES;
    _cell_add_one.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_one.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_one.userInteractionEnabled = YES;
    _cell_add_one.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_one.lbText.textColor = theme.textColorHighlight;
    
    _lbCommit = [self createCellLableButton:@"转出"];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kVcSecBlindOutput:
            //  title + all blind output
            return 1 + [_data_array_blind_output count];
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
        case kVcSecBlindOutput:
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
            
            id symbol = _curr_selected_asset[@"symbol"];
            
            switch (indexPath.row) {
                case kVcSubTotalTransferAmount:
                    cell.textLabel.text = @"转账总数量";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:[self calcBlindOutputTotalAmount] usesGroupingSeparator:NO], symbol];
                    break;
                case kVcSubNetworkFee:
                {
                    cell.textLabel.text = @"广播手续费";
                    id n_fee = [[ChainObjectManager sharedChainObjectManager] getNetworkCurrentFee:ebo_transfer_from_blind
                                                                                             kbyte:nil
                                                                                               day:nil
                                                                                            output:nil];
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
 *  事件 - 编辑某个输出
 */
- (void)onButtonClicked_Edit:(UIButton*)button
{
    //  TODO:6.0 edit
    [_data_array_blind_output removeObjectAtIndex:button.tag - 1];
    [_mainTableView reloadData];
}

- (void)onAddOneClicked
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
    //  REMARK：在主线程调用，否则VC弹出可能存在卡顿缓慢的情况。
    [self delay:^{
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCSelectBlindBalance* vc = [[VCSelectBlindBalance alloc] init];//TODO:6.0
        [self pushViewController:vc
                         vctitle:@"选择隐私收据"
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
    if ([_data_array_blind_output count] <= 0) {
        [OrgUtils makeToast:@"请添加要转出的隐私收据信息。"];
        return;
    }
    
    if (!_to_account) {
        [OrgUtils makeToast:@"请选择要转出的目标账号。"];
        return;
    }
    
    NSDecimalNumber* n_total = [self calcBlindOutputTotalAmount];
    if ([n_total compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:@"无效收据，余额信息为空。"];
        return;
    }
    
    id decrypted_memo = [[[_data_array_blind_output firstObject] objectForKey:@"blind_balance"] objectForKey:@"decrypted_memo"];
    assert(decrypted_memo);
    id asset_id = [[decrypted_memo objectForKey:@"amount"] objectForKey:@"asset_id"];
    id asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:asset_id];
    id n_fee = [[ChainObjectManager sharedChainObjectManager] getNetworkCurrentFee:ebo_transfer_from_blind kbyte:nil day:nil output:nil];
    
    if ([n_total compare:n_fee] <= 0) {
        [OrgUtils makeToast:@"收据金额太低，不足以支付手续费。"];
        return;
    }
    
    //  解锁钱包
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            [self transferFromBlindCore:_data_array_blind_output asset:asset n_total:n_total n_fee:n_fee];
        }
    }];
}

- (void)transferFromBlindCore:(NSArray*)blind_balance_array asset:(id)asset n_total:(id)n_total n_fee:(id)n_fee
{
    assert(blind_balance_array && [blind_balance_array count] > 0);
    //@"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //@"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //@"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //@"decrypted_memo": @{
    //    @"amount": @{@"asset_id": @"1.3.0", @"amount": @12300000},              //  转账用，显示用。
    //    @"blinding_factor": @"",                                                //  转账用
    //    @"commitment": @"",                                                     //  转账用
    //    @"check": @331,                                                         //  导入check用，显示用。
    //}
    
    NSMutableDictionary* sign_keys = [NSMutableDictionary dictionary];
    NSMutableArray* inputs = [NSMutableArray array];
    
    const unsigned char* blinds[[blind_balance_array count]];
    
    NSInteger idx = 0;
    for (id item in blind_balance_array) {
        id blind_balance = [item objectForKey:@"blind_balance"];
        id to_pub = [blind_balance objectForKey:@"real_to_key"];
        GraphenePrivateKey* to_pri = [[WalletManager sharedWalletManager] getGraphenePrivateKeyByPublicKey:to_pub];
        if (!to_pri) {
            [OrgUtils makeToast:@"缺少收据私钥。"];//TODO:6.0 recp id
            return;
        }
        
        GraphenePublicKey* one_time_key = [GraphenePublicKey fromWifPublicKey:[blind_balance objectForKey:@"one_time_key"]];
        assert(one_time_key);
        
        digest_sha512 secret = {0, };
        if (![to_pri getSharedSecret:one_time_key output:&secret]) {
            [OrgUtils makeToast:@"无效收据。"];//TODO:6.0 recp id
            return;
        }
        digest_sha256 child = {0, };
        sha256(secret.data, sizeof(secret.data), child.data);
        GraphenePrivateKey* child_prikey = [to_pri child:&child];
        id child_to_pub = [[child_prikey getPublicKey] toWifString];
        
        id decrypted_memo = [blind_balance objectForKey:@"decrypted_memo"];
        id input = @{
            @"commitment":[[decrypted_memo objectForKey:@"commitment"] hex_decode],
            @"owner":@{
                    @"weight_threshold":@1,
                    @"account_auths":@[],
                    @"key_auths":@[@[child_to_pub, @1]],
                    @"address_auths":@[]
            },
        };
        [inputs addObject:input];
        
        blinds[idx] = [[decrypted_memo objectForKey:@"blinding_factor"] hex_decode].bytes;//TODO:6.0 NSData release???
        ++idx;
        
        [sign_keys setObject:child_to_pub forKey:[child_prikey toWifString]];
    }
    
    [inputs sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        id c1 = [obj1 objectForKey:@"commitment"];
        id c2 = [obj2 objectForKey:@"commitment"];
        return [[c1 hex_encode] compare:[c2 hex_encode]];
    })];
    
    blind_factor_type result = {0, };
    __bts_gen_pedersen_blind_sum(blinds, [inputs count], (uint32_t)[inputs count], &result);//TODO:6.0 args check
    
    NSInteger precision = [[asset objectForKey:@"precision"] integerValue];
    
    id n_transfer_amount = [n_total decimalNumberBySubtracting:n_fee];
    id transfer_amount = [NSString stringWithFormat:@"%@", [n_transfer_amount decimalNumberByMultiplyingByPowerOf10:precision]];
    id fee_amount = [NSString stringWithFormat:@"%@", [n_fee decimalNumberByMultiplyingByPowerOf10:precision]];
    
    id op = @{
        @"fee":@{@"asset_id":asset[@"id"], @"amount":@([fee_amount unsignedLongLongValue])},
        @"amount":@{@"asset_id":asset[@"id"], @"amount":@([transfer_amount unsignedLongLongValue])},
        @"to":_to_account[@"id"],
        @"blinding_factor":[[NSData alloc] initWithBytes:result.data length:sizeof(result.data)],
        @"inputs":[inputs copy]
    };
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  REMARK：该操作不涉及账号，不需要处理提案的情况。仅n个私钥签名即可。
    [[[[BitsharesClientManager sharedBitsharesClientManager] transferFromBlind:op signPriKeyHash:sign_keys] then:^id(id data) {
        NSLog(@"%@", data);
        [self hideBlockView];
        [OrgUtils makeToast:@"转出成功。"];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

@end
