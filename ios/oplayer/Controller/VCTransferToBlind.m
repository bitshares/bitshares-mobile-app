//
//  VCTransferToBlind.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCTransferToBlind.h"
#import "ViewBlindOutputInfoCell.h"

#import "VCSearchNetwork.h"
#import "VCBlindOutputAddOne.h"
#import "ViewTipsInfoCell.h"

#import "GraphenePublicKey.h"
#import "GraphenePrivateKey.h"

enum
{
    kVcSecOpAsst = 0,       //  要操作的资产
    kVcSecBlindOutput,      //  隐私输出
    kVcSecAddOne,           //  新增按钮
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

@interface VCTransferToBlind ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _curr_selected_asset;   //  当前选中资产
    NSDictionary*               _curr_balance_asset;    //  当前余额资产（输入数量对应的资产）REMARK：和选中资产可能不相同。
    NSDictionary*               _full_account_data;     //  REMARK：提取手续费池等部分操作该参数为nil。
    NSDecimalNumber*            _nCurrBalance;
    
    UITableViewBase*            _mainTableView;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewBlockLabel*             _lbAddOne;
    ViewBlockLabel*             _lbCommit;
    
    NSMutableArray*             _data_array_blind_output;
}

@end

@implementation VCTransferToBlind

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
    _lbAddOne = nil;
    _lbCommit = nil;
}

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
          op_extra_args:(id)op_extra_args
         result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
        _curr_selected_asset = curr_asset;
        _full_account_data = full_account_data;
        _data_array_blind_output = [NSMutableArray array];
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
    //    switch ([[_opExtraArgs objectForKey:@"kOpType"] integerValue]) {
    //        case ebaok_claim_pool:
    //        {
    //            //  REMARK：计算手续费池余额。
    //            ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    //            id core_asset = [chainMgr getChainObjectByID:chainMgr.grapheneCoreAssetID];
    //            assert(core_asset);
    //            _curr_balance_asset = core_asset;
    //            id dynamic_asset_data = [chainMgr getChainObjectByID:[_curr_selected_asset objectForKey:@"dynamic_asset_data_id"]];
    //            _nCurrBalance = [NSDecimalNumber decimalNumberWithMantissa:[[dynamic_asset_data objectForKey:@"fee_pool"] unsignedLongLongValue]
    //                                                              exponent:-[[_curr_balance_asset objectForKey:@"precision"] integerValue]
    //                                                            isNegative:NO];
    //        }
    //            break;
    //        default:
    //        {
    //  其他操作，从账号获取余额。
    assert(_full_account_data);
    _curr_balance_asset = _curr_selected_asset;
    _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_selected_asset];
    //        }
    //            break;
    //    }
}

//- (void)_drawUI_Balance:(BOOL)not_enough
//{
//    ThemeManager* theme = [ThemeManager sharedThemeManager];
//    NSString* symbol = [_curr_balance_asset objectForKey:@"symbol"];
//    if (not_enough) {
//        NSString* value = [NSString stringWithFormat:@"%@ %@ %@(%@)",
//                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
//                           _nCurrBalance,
//                           symbol,
//                           NSLocalizedString(@"kOtcMcAssetTransferBalanceNotEnough", @"余额不足")];
////        [_tf_amount drawUI_titleValue:value color:theme.tintColor];
//    } else {
//        NSString* value = [NSString stringWithFormat:@"%@ %@ %@",
//                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
//                           _nCurrBalance,
//                           symbol];
////        [_tf_amount drawUI_titleValue:value color:theme.textColorMain];
//    }
//}

- (NSString*)genTransferTipsMessage
{
    //    return [_opExtraArgs objectForKey:@"kMsgTips"] ?: @"";
    return @"隐私转账 TODO:6.0";
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
  
    //  TODO:6.0
    _lbAddOne = [self createCellLableButton:@"新增"];
    _lbCommit = [self createCellLableButton:@"转账"];
    UIColor* backColor = [ThemeManager sharedThemeManager].textColorGray;
    _lbAddOne.layer.borderColor = backColor.CGColor;
    _lbAddOne.layer.backgroundColor = backColor.CGColor;
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecOpAsst) {
        return 2;
    } else if (section == kVcSecBlindOutput) {
        //  title + all blind output
        return 1 + [_data_array_blind_output count];
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
    if (section == kVcSecTips) {
        return 30.0f;
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
    switch (indexPath.section) {
        case kVcSecOpAsst:
        {
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            
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
                cell.textLabel.text = [_curr_selected_asset objectForKey:@"symbol"];
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

        case kVcSecTips:
            return _cell_tips;
            
        case kVcSecAddOne:
            {
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.backgroundColor = [UIColor clearColor];
                [self addLabelButtonToCell:_lbAddOne cell:cell leftEdge:tableView.layoutMargins.left];
                return cell;
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
    ENetworkSearchType kSearchType = enstAssetAll;
    //    switch ([[_opExtraArgs objectForKey:@"kOpType"] integerValue]) {
    //        case ebaok_settle:
    //            //            kSearchType = enstAssetSmart;
    //            return;                 //  REMARK：清算不可切换资产。需要动态查询是否黑天鹅等。后续考虑支持。TODO:5.0
    //            break;
    //        case ebaok_reserve:
    //            kSearchType = enstAssetUIA;
    //            break;
    //        case ebaok_claim_pool:      //  REMARK：提取手续费池不可切换资产。
    //            return;
    //        default:
    //            assert(false);
    //            break;
    //    }
    
    //  TODO:4.0 考虑默认备选列表？
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:kSearchType callback:^(id asset_info) {
        if (asset_info){
            NSString* new_id = [asset_info objectForKey:@"id"];
            NSString* old_id = [_curr_selected_asset objectForKey:@"id"];
            if (![new_id isEqualToString:old_id]) {
                _curr_selected_asset = asset_info;
                //  切换资产后重新输入
                [self _auxGenCurrBalanceAndBalanceAsset];
//                [_tf_amount clearInputTextValue];
//                [_tf_amount drawUI_newTailer:[_curr_balance_asset objectForKey:@"symbol"]];
//                [self _drawUI_Balance:NO];
                [_mainTableView reloadData];
            }
        }
    }];
    
    [self pushViewController:vc
                     vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
                   backtitle:kVcDefaultBackTitleName];
}

- (void)testTransferFromBlind
{
    NSInteger amount = 3100077;
    NSInteger fee = 500000;
    
    blind_factor_type blind;
    sha256((const unsigned char*)"abc", 3, blind.data);
    commitment_type commit = {0, };
    __bts_gen_pedersen_commit(&commit, &blind, amount);
    
    id prikey = [[NSData alloc] initWithBytes:blind.data length:sizeof(blind.data)];
    id wif_prikey = [OrgUtils genBtsWifPrivateKeyByPrivateKey32:prikey];
    id pubkey = [OrgUtils genBtsAddressFromWifPrivateKey:wif_prikey];
    id sign_key = @{wif_prikey:pubkey};
    
    id op = @{
        @"fee":@{@"asset_id":@"1.3.0",@"amount":@(fee)},
        @"amount":@{@"asset_id":@"1.3.0",@"amount":@(amount-fee)},
        @"to":@"1.2.64",//susu01 op_account[@"id"],
        @"blinding_factor":[[NSData alloc] initWithBytes:blind.data length:sizeof(blind.data)],
        @"inputs":@[@{
                         @"commitment":[[NSData alloc] initWithBytes:commit.data length:sizeof(commit.data)],
                         @"owner":@{
                                 @"weight_threshold":@1,
                                 @"account_auths":@[],
                                 @"key_auths":@[@[pubkey, @1]],
                                 @"address_auths":@[]
                         },
        }]
    };
//    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
//        if (unlocked) {
            [[[[BitsharesClientManager sharedBitsharesClientManager] transferFromBlind:op signPriKeyHash:sign_key] then:^id(id data) {
                NSLog(@"%@", data);
                return nil;
            }] catch:^id(id error) {
                NSLog(@"%@", error);
                return nil;
            }];
//        }
//    }];
}

- (NSDictionary*)genOneBlindOutput:(GraphenePublicKey*)to_public_key
                          n_amount:(NSDecimalNumber*)n_amount
                             asset:(id)asset
{
    assert(to_public_key);
    assert(n_amount);
    
    id one_time_key = [[GraphenePrivateKey alloc] initRandom];
    const secp256k1_prikey* one_time_key_secp256k1 = [one_time_key getKeyData];
    
    digest_sha512 secret;
    digest_sha256 child;
    blind_factor_type nonce;
    blind_factor_type blind_factor;
    
    [one_time_key getSharedSecret:to_public_key output:&secret];
    sha256(secret.data, sizeof(secret.data), child.data);
    sha256(one_time_key_secp256k1->data, sizeof(one_time_key_secp256k1->data), nonce.data);
    sha256(child.data, sizeof(child.data), blind_factor.data);
        
    //  生成 blind_output 子属性：承诺
    id amount = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:[asset[@"precision"] integerValue]]];
    uint64_t i_amount = [amount unsignedLongLongValue];
    commitment_type commitment = {0, };
    __bts_gen_pedersen_commit(&commitment, &blind_factor, i_amount);
    
    //  生成 blind_output 子属性：范围证明（仅多个输出时才需要，单个输出不需要。）
    id range_proof = nil;
    if ([_data_array_blind_output count] > 1) {
        unsigned char proof[5134];
        int proof_len = sizeof(proof);
        __bts_gen_range_proof_sign(0, &commitment, &blind_factor, &nonce, 0, 0, i_amount, proof, &proof_len);
        range_proof = [[NSData alloc] initWithBytes:proof length:proof_len];
    } else {
        range_proof = [NSData data];
    }
    
    //  生成 blind_output 子属性：owner
    id out_owner = @{
        @"weight_threshold":@1,
        @"account_auths":@[],
        @"key_auths":@[@[[[to_public_key child:&child] toWifString], @1]],
        @"address_auths":@[]
    };
    
    id blind_output = @{
        @"commitment": [[NSData alloc] initWithBytes:commitment.data length:sizeof(commitment.data)],
        @"range_proof": range_proof,
        @"owner": out_owner,
        @"stealth_memo": @{
                @"one_time_key": [[one_time_key getPublicKey] toWifString],
//                @"to": [to_public_key toWifString],
                @"encrypted_memo": [NSData data]//TODO:6.0
        }
    };
    
    id decrypted_memo = @{
        @"amount": @(i_amount),
        @"blinding_factor": [[NSData alloc] initWithBytes:blind_factor.data length:sizeof(blind_factor.data)],
        @"commitment": [[NSData alloc] initWithBytes:commitment.data length:sizeof(commitment.data)],
        @"check": @(*(uint32_t*)&secret.data[0])
    };

    id confirmation = @{
        @"one_time_key": [[one_time_key getPublicKey] toWifString],
        @"to": [to_public_key toWifString],
        @"encrypted_memo":decrypted_memo
        //            fc::aes_encrypt( secret, fc::raw::pack( conf_output.decrypted_memo ) );
    };
    
    return @{
        @"blind_output": blind_output,
        @"confirmation": confirmation,
        @"blind_factor": [[NSData alloc] initWithBytes:blind_factor.data length:sizeof(blind_factor.data)]
    };
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

- (void)onSubmitClicked
{
    if ([_data_array_blind_output count] <= 0) {
        [OrgUtils makeToast:@"请添加隐私输出地址和数量。"];
        return;
    }
    
    //  TODO:6.0 asset
    id core_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:@"1.3.0"];
    
    NSDecimalNumber* n_total = [NSDecimalNumber zero];
    for (id item in _data_array_blind_output) {
        n_total = [n_total decimalNumberByAdding:[item objectForKey:@"n_amount"]];
    }
    //  TODO:6.0 余额判断 >0 < max_balance
    
    NSMutableArray* output = [NSMutableArray array];
    for (id item in _data_array_blind_output) {
        [output addObject:[self genOneBlindOutput:[GraphenePublicKey fromWifPublicKey:[item objectForKey:@"public_key"]]
                                         n_amount:[item objectForKey:@"n_amount"]
                                            asset:core_asset]];
    }
    
    NSMutableArray* blind_outputs = [NSMutableArray array];
    const unsigned char* blinds[[output count]];
    NSInteger idx = 0;
    for (id value in output) {
        blinds[idx] = ((NSData*)[value objectForKey:@"blind_factor"]).bytes;
        ++idx;
        [blind_outputs addObject:[value objectForKey:@"blind_output"]];
    }
    blind_factor_type result = {0, };
    __bts_gen_pedersen_blind_sum(blinds, [output count], (uint32_t)[output count], &result);
    
    [blind_outputs sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        id c1 = [obj1 objectForKey:@"commitment"];
        id c2 = [obj2 objectForKey:@"commitment"];
        return [[c1 hex_encode] compare:[c2 hex_encode]];
    })];
 
    
    //  TODO:6.0
//    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    
//    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
//    if ([n_amount compare:n_zero] <= 0) {
//        [OrgUtils makeToast:@"请输入转账数量。"];
//        return;
//    }
//
//    if ([_nCurrBalance compare:n_amount] < 0) {
//        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipBalanceNotEnough", @"余额不足。")];
//        return;
//    }
  
    id s_total = [NSString stringWithFormat:@"%@", [n_total decimalNumberByMultiplyingByPowerOf10:[core_asset[@"precision"] integerValue]]];

    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    id op = @{
        @"fee":@{@"asset_id":@"1.3.0",@"amount":@0},
        @"amount":@{@"asset_id":@"1.3.0",@"amount":@([s_total unsignedLongLongValue])},
        @"from":op_account[@"id"],
        @"blinding_factor":[[NSData alloc] initWithBytes:result.data length:sizeof(result.data)],
        @"outputs":[blind_outputs copy]
    };
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[[BitsharesClientManager sharedBitsharesClientManager] transferToBlind:op] then:^id(id data) {
                [self hideBlockView];
                NSLog(@"%@", data);
                [OrgUtils makeToast:@"转账成功。"];
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                NSLog(@"%@", error);
                [OrgUtils showGrapheneError:error];
                return nil;
            }];
        }
    }];
    return;
    
    //            id value = [NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpSubmitAskReserve", @"您确认销毁 %@ %@ 吗？\n\n※ 此操作不可逆，请谨慎操作。"), n_amount, _curr_balance_asset[@"symbol"]];
    //            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
    //                                                                   withTitle:NSLocalizedString(@"kVcHtlcMessageTipsTitle", @"风险提示")
    //                                                                  completion:^(NSInteger buttonIndex)
    //             {
    //                if (buttonIndex == 1)
    //                {
    //                    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
    //                        if (unlocked) {
    //                            [self _execAssetReserveCore:n_amount];
    //                        }
    //                    }];
    //                }
    //            }];
    //        }
    //            break;
    
}

/*
 *  (private) 执行清算操作
 */
- (void)_execAssetSettleCore:(NSDecimalNumber*)n_amount
{
    //    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    //    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    //    assert(op_account);
    //
    //    id n_amount_pow = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:[_curr_balance_asset[@"precision"] integerValue]]];
    //    id op = @{
    //        @"fee":@{@"amount":@0, @"asset_id":chainMgr.grapheneCoreAssetID},
    //        @"account":op_account[@"id"],
    //        @"amount":@{@"amount":@([n_amount_pow unsignedLongLongValue]), @"asset_id":_curr_balance_asset[@"id"]}
    //    };
    //
    //    //  确保有权限发起普通交易，否则作为提案交易处理。
    //    [self GuardProposalOrNormalTransaction:ebo_asset_settle
    //                     using_owner_authority:NO
    //                  invoke_proposal_callback:NO
    //                                    opdata:op
    //                                 opaccount:op_account
    //                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
    //     {
    //        assert(!isProposal);
    //        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    //        [[[[BitsharesClientManager sharedBitsharesClientManager] assetSettle:op] then:(^id(id data) {
    //            [self hideBlockView];
    //            [OrgUtils makeToast:[_opExtraArgs objectForKey:@"kMsgSubmitOK"] ?: @""];
    //            //  [统计]
    //            [OrgUtils logEvents:@"txAssetSettleFullOK" params:@{@"account":op_account[@"id"]}];
    //            //  返回上一个界面并刷新
    //            if (_result_promise) {
    //                [_result_promise resolve:@YES];
    //            }
    //            [self closeOrPopViewController];
    //            return nil;
    //        })] catch:(^id(id error) {
    //            [self hideBlockView];
    //            [OrgUtils showGrapheneError:error];
    //            //  [统计]
    //            [OrgUtils logEvents:@"txAssetSettleFailed" params:@{@"account":op_account[@"id"]}];
    //            return nil;
    //        })];
    //    }];
}

@end
