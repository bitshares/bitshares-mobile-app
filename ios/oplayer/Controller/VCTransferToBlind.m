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

#import "VCSearchNetwork.h"
#import "VCBlindOutputAddOne.h"
#import "ViewTipsInfoCell.h"
#import "ViewEmptyInfoCell.h"

#import "GrapheneSerializer.h"
#import "GraphenePublicKey.h"
#import "GraphenePrivateKey.h"

//#import "HDWallet.h"

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
    kVcSubOutputTotalAmount,
    kVcSubNetworkFee,
    
    kVcSubMax
};

@interface VCTransferToBlind ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _curr_selected_asset;   //  当前选中资产
    NSDictionary*               _curr_balance_asset;    //  当前余额资产（输入数量对应的资产）REMARK：和选中资产可能不相同。
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
    return @"【温馨提示】\n隐私转账可同时指定多个隐私地址。";
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
    _cell_add_one = [[ViewEmptyInfoCell alloc] initWithText:@"添加输出" iconName:@"iconAdd"];
    _cell_add_one.showCustomBottomLine = YES;
    _cell_add_one.accessoryType = UITableViewCellAccessoryNone;
    _cell_add_one.selectionStyle = UITableViewCellSelectionStyleBlue;
    _cell_add_one.userInteractionEnabled = YES;
    _cell_add_one.imgIcon.tintColor = theme.textColorHighlight;
    _cell_add_one.lbText.textColor = theme.textColorHighlight;
    
    _lbCommit = [self createCellLableButton:@"隐私转入"];
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
                
                //                cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
                //                cell.detailTextLabel.text = @"可用 332323.3323 TEST";//   TODO:6.0
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
            
            id symbol = _curr_selected_asset[@"symbol"];
            
            switch (indexPath.row) {
                case kVcSubAvailbleBalance:
                    cell.textLabel.text = @"可用余额";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:_nCurrBalance usesGroupingSeparator:NO], symbol];
                    break;
                case kVcSubOutputTotalAmount:
                    cell.textLabel.text = @"输出总金额";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:[self calcBlindOutputTotalAmount] usesGroupingSeparator:NO], symbol];
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

/**
 *  事件 - 移除某个隐私输出
 */
- (void)onButtonClicked_OutputRemove:(UIButton*)button
{
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
//    HDWallet* hdk = [HDWallet fromMnemonic:@"A"];
//    HDWallet* new_key = [hdk deriveBitsharesStealthChildKey:1];
//    id new_pri = [new_key toWifPrivateKey];
//    id new_pri_p = [OrgUtils genBtsAddressFromWifPrivateKey:new_pri];
//
//    HDWallet* new_key2 = [hdk deriveBitsharesStealthChildKey:0];
//    id new_pri2 = [new_key2 toWifPrivateKey];
//    id new_pri_p2 = [OrgUtils genBtsAddressFromWifPrivateKey:new_pri2];
//
//    NSLog(@"");
//    return;
    
    //  TODO:6.0 DEBUG 临时清空
//    AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
//    for (id vi in [[pAppCahce getAllBlindBalance] allValues]) {
//        [pAppCahce removeBlindBalance:vi];
//    }
//    [pAppCahce saveStealthReceiptToFile];
//    return;
    
    if ([_data_array_blind_output count] <= 0) {
        [OrgUtils makeToast:@"请添加隐私输出地址和数量。"];
        return;
    }
    
    //  TODO:6.0 asset
    id core_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:@"1.3.0"];
    
    NSDecimalNumber* n_total = [self calcBlindOutputTotalAmount];
    if ([n_total compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:@"输出金额不能为空。"];
        return;
    }
    
    //  TODO:6.0 余额判断 >0 < max_balance
    if ([_nCurrBalance compare:n_total] < 0) {
        [OrgUtils makeToast:@"余额不足。"];
        return;
    }
    
    //  生成隐私输出
    id blind_output_args = [VCStealthTransferHelper genBlindOutputs:_data_array_blind_output
                                                              asset:core_asset
                                             input_blinding_factors:nil];
    //  生成所有隐私输出承诺盲因子之和。
    id receipt_array = [blind_output_args objectForKey:@"receipt_array"];
    id blinding_factor = [VCStealthTransferHelper blindSum:[receipt_array ruby_map:^id(id src) {
        return [src objectForKey:@"blind_factor"];
    }]];
    
    //  构造OP
    id s_total = [NSString stringWithFormat:@"%@", [n_total decimalNumberByMultiplyingByPowerOf10:[core_asset[@"precision"] integerValue]]];
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    id op = @{
        @"fee":@{@"asset_id":@"1.3.0",@"amount":@0},
        @"amount":@{@"asset_id":@"1.3.0",@"amount":@([s_total unsignedLongLongValue])},
        @"from":op_account[@"id"],
        @"blinding_factor":blinding_factor,
        @"outputs":blind_output_args[@"blind_outputs"]
    };
    
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[[BitsharesClientManager sharedBitsharesClientManager] transferToBlind:op] then:^id(id data) {
                [self hideBlockView];
                NSLog(@"%@", data);
                [OrgUtils makeToast:@"转账成功。"];
                //  保存
                //  TODO:6.0 仅转给自己地址的收据自动导入，转给他人的不自动转入。
                //  TODO:6.0 是否提示备份？数据丢失后如何处理。
                AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
                for (id item in receipt_array) {
                    [pAppCahce appendBlindBalance:[item objectForKey:@"blind_balance"]];
                }
                [pAppCahce saveWalletInfoToFile];
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

@end
