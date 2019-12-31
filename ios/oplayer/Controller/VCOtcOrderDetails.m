//
//  VCOtcOrderDetails.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCOtcOrderDetails.h"
#import "OrgUtils.h"

#import "ViewOtcOrderDetailStatus.h"
#import "ViewOtcOrderDetailBasicInfo.h"
#import "ViewOtcPaymentIconAndTextCell.h"
#import "ViewTipsInfoCell.h"

#import "OtcManager.h"
#import "AsyncTaskManager.h"

#define fBottomButtonsViewHeight 60.0f

enum
{
    kVcSecOrderStatus = 0,  //  状态信息
    kVcSecOrderInfo,        //  订单基本信息：价格单价等
    kvcSecPaymentInfo,      //  收付款信息（用户买入时需要显示）
    kVcSecOrderDetailInfo,  //  订单详细信息：商家名、订单号等
    kVcSecCellTips,         //  转账时：附加系统提示
};

enum
{
    kVcSubMerchantRealName = 0, //  商家实名
    kVcSubMerchantNickName,     //  商家昵称
    kVcSubOrderID,              //  订单号
    kVcSubOrderTime,            //  下单日期
    kVcSubPaymentMethod,        //  付款方式 or 收款方式
    
    kVcSubPaymentTipsSameName,  //  相同名字账号付款提示
    kVcSubPaymentMethodSelect,  //  选择收款方式
    kVcSubPaymentRealName,      //  收款人
    kVcSubPaymentAccount,       //  收款账号（银行卡号、微信支付宝账号等）
    kVcSubPaymentBankName,      //  银行名（银行卡存在）
    kVcSubPaymentQrCode,        //  二维码（支付宝微信可能存在）
    
    kVcSubMcUserAccount,        //  用户账号（商家端）
};

@interface VCOtcOrderDetails ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _orderDetails;
    NSDictionary*               _authInfos;                 //  认证信息
    EOtcUserType                _user_type;                 //  用户 or 商家界面
    NSMutableDictionary*        _statusInfos;
    BOOL                        _orderStatusDirty;          //  订单状态是否更新过了
    
    NSInteger                   _timerID;                   //  买单付款倒计时
    
    NSDictionary*               _currSelectedPaymentMethod; //  买单情况下，当前选中的卖家收款方式。
    
    UITableViewBase*            _mainTableView;
    ViewOtcOrderDetailStatus*   _viewStatusCell;            //  状态信息CELL
    UIView*                     _pBottomActionsView;        //  底部按钮界面
    
    NSMutableArray*             _sectionDataArray;
    ViewTipsInfoCell*           _cell_tips;
    NSMutableArray*             _btnArray;
}

@end

@implementation VCOtcOrderDetails

-(void)dealloc
{
    [self _stopPaymentTimer];
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _viewStatusCell = nil;
    _pBottomActionsView = nil;
    _cell_tips = nil;
    _sectionDataArray = nil;
    _orderDetails = nil;
    _authInfos = nil;
    _btnArray = nil;
    _currSelectedPaymentMethod = nil;
    _result_promise = nil;
}

- (void)_stopPaymentTimer
{
    if (_timerID != 0) {
        [[AsyncTaskManager sharedAsyncTaskManager] removeSecondsTimer:_timerID];
        _timerID = 0;
    }
}

/*
 *  (private) 待付款定时器
 */
- (void)_onPaymentTimerTick:(NSInteger)left_ts
{
    if (left_ts > 0) {
        //  刷新
        if (_user_type == eout_normal_user) {
            [_statusInfos setObject:[NSString stringWithFormat:NSLocalizedString(@"kOtcOdPaymentTimeLimit", @"请在 %@ 内付款给卖家。"), [OtcManager fmtPaymentExpireTime:left_ts]] forKey:@"desc"];
        } else {
            [_statusInfos setObject:[NSString stringWithFormat:NSLocalizedString(@"kOtcOdMcPaymentTimeLimit", @"预计 %@ 内收到用户付款。"), [OtcManager fmtPaymentExpireTime:left_ts]] forKey:@"desc"];
        }
        [_viewStatusCell setItem:_statusInfos];
        [_viewStatusCell refreshText];
    } else {
        //  TODO:2.9 cancel? 未完成 定时器到了应该是直接刷新页面？
    }
}

- (id)initWithOrderDetails:(id)order_details auth:(id)auth_info user_type:(EOtcUserType)user_type
            result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _orderStatusDirty = NO;
        _result_promise = result_promise;
        _orderDetails = order_details;
        _authInfos = auth_info;
        _user_type = user_type;
        _sectionDataArray = [NSMutableArray array];
        _btnArray = [NSMutableArray array];
        _cell_tips = nil;
        _statusInfos = [[OtcManager auxGenOtcOrderStatusAndActions:order_details user_type:_user_type] mutableCopy];
        
        //  支付关闭定时器
        _timerID = 0;
        NSInteger expireDate = [_orderDetails[@"expireDate"] integerValue];
        if (expireDate > 0 && ![_statusInfos[@"sell"] boolValue] && [_orderDetails[@"status"] integerValue] == eoops_new) {
            NSInteger now_ts = (NSInteger)ceil([[NSDate date] timeIntervalSince1970]);
            NSInteger expire_ts = (NSInteger)[OtcManager parseTime:_orderDetails[@"ctime"]] + expireDate;
            if (now_ts < expire_ts) {
                _timerID = [[AsyncTaskManager sharedAsyncTaskManager] scheduledSecondsTimerWithEndTS:expire_ts callback:^(NSInteger left_ts) {
                    [self _onPaymentTimerTick:left_ts];
                }];
            }
        }
        
        _currSelectedPaymentMethod = nil;
        [self _initUIData];
    }
    return self;
}

- (id)_genPaymentRows:(id)payment_info target_array:(NSMutableArray*)target_array
{
    assert(payment_info);
    [target_array removeAllObjects];
    
    _currSelectedPaymentMethod = payment_info;
    [target_array addObject:@(kVcSubPaymentTipsSameName)];
    [target_array addObject:@(kVcSubPaymentMethodSelect)];
    [target_array addObject:@(kVcSubPaymentRealName)];
    [target_array addObject:@(kVcSubPaymentAccount)];
    
    if ([[payment_info objectForKey:@"type"] integerValue] == eopmt_bankcard) {
        //  开户银行
        NSString* bankName = [payment_info objectForKey:@"bankName"];
        if (bankName && ![bankName isEqualToString:@""]) {
            [target_array addObject:@(kVcSubPaymentBankName)];
        }
    } else {
        //  收款二维码 TODO:3.0 该版本考虑不支持二维码。不显示
        //        NSString* qrCode = [NSString stringWithFormat:@"%@", [payment_info objectForKey:@"qrCode"]];
        //        if (qrCode && ![qrCode isEqualToString:@""] && ![qrCode isEqualToString:@"0"]) {
        //            [target_array addObject:@(kVcSubPaymentQrCode)];
        //        }
    }
    
    return target_array;
}

/*
 *  (private) 动态初始化UI需要显示的字段信息按钮等数据。
 */
- (void)_initUIData
{
    //  clean
    _currSelectedPaymentMethod = nil;
    [_sectionDataArray removeAllObjects];
    [_btnArray removeAllObjects];
    
    //  UI - 订单基本状态
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderStatus)}];
    
    //  UI - 订单金额等基本信息
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderInfo)}];
    
    //  UI - 付款信息
    id payMethod = [_orderDetails objectForKey:@"payMethod"];
    if (payMethod && [payMethod isKindOfClass:[NSArray class]] && [payMethod count] > 0) {
        [_sectionDataArray addObject:@{@"type":@(kvcSecPaymentInfo),
                                       @"rows":[self _genPaymentRows:[payMethod firstObject] target_array:[NSMutableArray array]]}];
    }
    
    //  UI - 订单详细信息（订单号等）
    id orderDetailRows = [[[NSMutableArray array] ruby_apply:^(id obj) {
        if (_user_type == eout_normal_user) {
            [obj addObject:@(kVcSubMerchantRealName)];
            [obj addObject:@(kVcSubMerchantNickName)];
        } else {
            [obj addObject:@(kVcSubMcUserAccount)];
        }
        [obj addObject:@(kVcSubOrderID)];
        [obj addObject:@(kVcSubOrderTime)];
        //  收款方式 or 付款方式
        NSString* payAccount = [_orderDetails objectForKey:@"payAccount"];
        if (payAccount && ![payAccount isEqualToString:@""]) {
            [obj addObject:@(kVcSubPaymentMethod)];
        }
    }] copy];
    [_sectionDataArray addObject:@{@"type":@(kVcSecOrderDetailInfo), @"rows":orderDetailRows}];
    
    //  提示
    if ([[_statusInfos objectForKey:@"show_remark"] boolValue]) {
        if (!_cell_tips) {
            NSMutableArray* tips_array = [NSMutableArray array];
            NSString* remark = [_orderDetails objectForKey:@"remark"];
            if (remark && [remark isKindOfClass:[NSString class]] && ![remark isEqualToString:@""]) {
                [tips_array addObject:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"kOtcOdPaymentTipsMcRemarkPrefix", @"商家："), remark]];
            }
            [tips_array addObject:NSLocalizedString(@"kOtcOdPaymentTipsSystemMsg", @"系统：在转账过程中请勿备注BTC、USDT等信息，防止汇款被拦截、银行卡被冻结等问题。")];
            //  UI
            _cell_tips = [[ViewTipsInfoCell alloc] initWithText:[NSString stringWithFormat:@"%@", [tips_array componentsJoinedByString:@"\n\n"]]];
            _cell_tips.hideBottomLine = YES;
            _cell_tips.hideTopLine = YES;
            _cell_tips.backgroundColor = [UIColor clearColor];
        }
        [_sectionDataArray addObject:@{@"type":@(kVcSecCellTips)}];
    } else {
        _cell_tips = nil;
    }
    
    //  UI - 底部按钮数据
    id actions = [_statusInfos objectForKey:@"actions"];
    if (actions && [actions count] > 0) {
        [_btnArray addObjectsFromArray:actions];
    }
}

/*
 *  (private) 刷新UI
 */
- (void)_refreshUI:(id)new_order_detail
{
    _orderDetails = new_order_detail;
    _statusInfos = [[OtcManager auxGenOtcOrderStatusAndActions:_orderDetails user_type:_user_type] mutableCopy];
    [self _initUIData];
    //  刷新UI
    CGRect tableRect = [_btnArray count] > 0 ? [self rectWithoutNaviWithOffset:fBottomButtonsViewHeight] : [self rectWithoutNavi];
    [self _genBottomActionsView:fBottomButtonsViewHeight tableRect:tableRect];
    _mainTableView.frame = tableRect;
    [_mainTableView reloadData];
}

/*
 *  (private) 执行更新订单。确认付款/取消订单/商家退款（用户收到退款后取消订单）等
 */
- (void)_execUpdateOrderCore:(id)payAccount payChannel:(id)payChannel type:(EOtcOrderUpdateType)type
{
    [self _execUpdateOrderCore:payAccount payChannel:payChannel type:type signatureTx:nil];
}

- (void)_execUpdateOrderCore:(id)payAccount payChannel:(id)payChannel type:(EOtcOrderUpdateType)type signatureTx:(id)signatureTx
{
    assert(![[WalletManager sharedWalletManager] isLocked]);
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    OtcManager* otc = [OtcManager sharedOtcManager];
    NSString* userAccount = [otc getCurrentBtsAccount];
    NSString* orderId = _orderDetails[@"orderId"];
    WsPromise* p1;
    if (_user_type == eout_normal_user) {
        p1 = [otc updateUserOrder:userAccount order_id:orderId payAccount:payAccount payChannel:payChannel type:type];
    } else {
        p1 = [otc updateMerchantOrder:userAccount order_id:orderId payAccount:payAccount payChannel:payChannel type:type
                          signatureTx:signatureTx];
    }
    [[p1 then:^id(id data) {
        //  设置：订单状态已变更标记
        _orderStatusDirty = YES;
        //  停止付款计时器
        [self _stopPaymentTimer];
        //  更新状态成功、刷新界面。
        WsPromise* queryPromise;
        if (_user_type == eout_normal_user) {
            queryPromise = [otc queryUserOrderDetails:userAccount order_id:orderId];
        } else {
            queryPromise = [otc queryMerchantOrderDetails:userAccount order_id:orderId];
        }
        return [queryPromise then:^id(id details_responsed) {
            //  获取新订单数据成功
            [self hideBlockView];
            [self _refreshUI:[details_responsed objectForKey:@"data"]];
            return nil;
        }];
    }] catch:^id(id error) {
        [self hideBlockView];
        [otc showOtcError:error];
        return nil;
    }];
}

/*
 *  (private) 执行转币
 */
- (void)_execTransferCore
{
    //  解锁：需要check资金权限，提案等不支持。
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            NSString* userAccount = [[OtcManager sharedOtcManager] getCurrentBtsAccount];
            NSString* otcAccount = _orderDetails[@"otcAccount"];
            NSString* assetSymbol = _orderDetails[@"assetSymbol"];
            NSString* args_amount = [NSString stringWithFormat:@"%@", _orderDetails[@"quantity"]];
            
            //  REMARK：转账memo格式：F(发币)T(退币) + 订单号后10位
            NSString* orderId = _orderDetails[@"orderId"];
            NSString* args_memo_str = [NSString stringWithFormat:@"F%@", [orderId substringFromIndex:MAX((NSInteger)orderId.length - 10, 0)]];
            
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            
            ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
            id p1 = [chainMgr queryFullAccountInfo:userAccount];
            id p2 = [chainMgr queryAccountData:otcAccount];
            id p3 = [chainMgr queryAssetData:assetSymbol];
            //  TODO:2.9 100? args
            id p4 = [chainMgr queryAccountHistoryByOperations:userAccount optype_array:@[@(ebo_transfer)] limit:100];
            [[[WsPromise all:@[p1, p2, p3, p4]] then:^id(id promise_data_array) {
                id full_from_account = [promise_data_array safeObjectAtIndex:0];
                id to_account = [promise_data_array safeObjectAtIndex:1];
                id asset = [promise_data_array safeObjectAtIndex:2];
                id his_data_array = [promise_data_array safeObjectAtIndex:3];
                
                if (!full_from_account || !to_account || !asset) {
                    [self hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kOtcOdOrderDataException", @"订单数据异常，请联系客服。")];
                    return nil;
                }
                
                NSString* real_from_id = [[full_from_account objectForKey:@"account"] objectForKey:@"id"];
                NSString* real_to_id = [to_account objectForKey:@"id"];
                NSDecimalNumber* real_amount = [NSDecimalNumber decimalNumberWithString:args_amount];
                NSString* real_asset_id = [asset objectForKey:@"id"];
                NSInteger real_asset_precision = [[asset objectForKey:@"precision"] integerValue];
                
                //  检测是否已经转币了。
                BOOL bMatched = NO;
                if (his_data_array && [his_data_array count] > 0) {
                    for (id his_object in his_data_array) {
                        id op = [his_object objectForKey:@"op"];
                        assert([[op safeObjectAtIndex:0] integerValue] == ebo_transfer);
                        
                        id opdata = [op safeObjectAtIndex:1];
                        if (!opdata) {
                            continue;
                        }
                        
                        // 1、检测from、to、amount是否匹配
                        NSString* from_id = [opdata objectForKey:@"from"];
                        NSString* to_id = [opdata objectForKey:@"to"];
                        if (![from_id isEqualToString:real_from_id] || ![to_id isEqualToString:real_to_id]) {
                            continue;
                        }
                        
                        // 2、检测转币数量是否匹配
                        id op_amount = [opdata objectForKey:@"amount"];
                        if (![real_asset_id isEqualToString:[op_amount objectForKey:@"asset_id"]]) {
                            continue;
                        }
                        id n_op_amount = [NSDecimalNumber decimalNumberWithMantissa:[[op_amount objectForKey:@"amount"] unsignedLongLongValue]
                                                                           exponent:-real_asset_precision
                                                                         isNegative:NO];
                        if ([real_amount compare:n_op_amount] != NSOrderedSame) {
                            continue;
                        }
                        
                        // 3、检测memo中订单号信息是否匹配
                        id memo_object = [opdata objectForKey:@"memo"];
                        if (!memo_object) {
                            continue;
                        }
                        NSString* plain_memo = [[WalletManager sharedWalletManager] decryptMemoObject:memo_object];
                        if (!plain_memo) {
                            continue;
                        }
                        if ([plain_memo isEqualToString:args_memo_str]) {
                            bMatched = YES;
                            break;
                        }
                    }
                }
                
                if (bMatched) {
                    //  已转过币了：仅更新订单状态
                    [self _execUpdateOrderCore:nil
                                    payChannel:nil
                                          type:eoout_to_transferred];
                } else {
                    //  转币 & 更新订单状态
                    [[[[BitsharesClientManager sharedBitsharesClientManager] simpleTransfer2:full_from_account
                                                                                          to:to_account
                                                                                       asset:asset
                                                                                      amount:args_amount
                                                                                        memo:args_memo_str
                                                                             memo_extra_keys:nil
                                                                               sign_pub_keys:nil
                                                                                   broadcast:YES] then:^id(id data)
                      {
                        id err = [data objectForKey:@"err"];
                        if (err) {
                            //  错误
                            [self hideBlockView];
                            [OrgUtils makeToast:err];
                        } else {
                            //  转币成功：更新订单状态
                            [self _execUpdateOrderCore:nil
                                            payChannel:nil
                                                  type:eoout_to_transferred];
                        }
                        return nil;
                    }] catch:^id(id error) {
                        [self hideBlockView];
                        [OrgUtils showGrapheneError:error];
                        return nil;
                    }];
                }
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
                return nil;
            }];
        }
    }];
}

- (void)_transferCoinToUserAndUpadteOrder:(BOOL)return_coin_to_user
                               payAccount:(id)payAccount
                               payChannel:(id)payChannel
                                     type:(EOtcOrderUpdateType)type
{
    OtcManager* otc = [OtcManager sharedOtcManager];
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[otc queryMerchantMemoKey:[otc getCurrentBtsAccount]] then:^id(id responsed) {
                id priKey = [responsed optString:@"data"] ?: @"";
                id pubKey = [OrgUtils genBtsAddressFromWifPrivateKey:priKey];
                if (!pubKey) {
                    [self hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kTxInvalidMemoPriKey", @"备注私钥无效。")];
                    return nil;
                }
                id memo_extra_keys = @{pubKey:priKey};
                [[[self _genTransferTransactionObject:return_coin_to_user memo_extra_keys:memo_extra_keys] then:^id(id tx_data) {
                    id err = [tx_data objectForKey:@"err"];
                    if (err) {
                        //  错误
                        [self hideBlockView];
                        [OrgUtils makeToast:err];
                    } else {
                        //  转账签名成功
                        id tx = [tx_data objectForKey:@"tx"];
                        assert(tx);
                        //  更新订单状态
                        [self _execUpdateOrderCore:payAccount payChannel:payChannel type:type signatureTx:tx];
                    }
                    return nil;
                }] catch:^id(id error) {
                    [self hideBlockView];
                    [OrgUtils showGrapheneError:error];
                    return nil;
                }];
                return nil;
            }] catch:^id(id error) {
                [self hideBlockView];
                [otc showOtcError:error];
                return nil;
            }];
        }
    }];
}

/*
 *  (private) 生成转账数据结构。商家已签名的。
 */
- (WsPromise*)_genTransferTransactionObject:(BOOL)return_coin_to_user memo_extra_keys:(id)memo_extra_keys
{
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    assert(![walletMgr isLocked]);
    
    NSString* userAccount = _orderDetails[@"userAccount"];
    NSString* otcAccount = _orderDetails[@"otcAccount"];
    NSString* assetSymbol = _orderDetails[@"assetSymbol"];
    NSString* args_amount = [NSString stringWithFormat:@"%@", _orderDetails[@"quantity"]];
    
    //  REMARK：转账memo格式：F(发币)T(退币) + 订单号后10位
    NSString* orderId = _orderDetails[@"orderId"];
    NSString* prefix = return_coin_to_user ? @"T" : @"F";
    NSString* args_memo_str = [NSString stringWithFormat:@"%@%@", prefix, [orderId substringFromIndex:MAX((NSInteger)orderId.length - 10, 0)]];
    
    //  获取用户自身的KEY进行签名。
    id active_permission = [[[walletMgr getWalletAccountInfo] objectForKey:@"account"] objectForKey:@"active"];
    id sign_pub_keys = [walletMgr getSignKeys:active_permission assert_enough_permission:NO];
    
    return [[BitsharesClientManager sharedBitsharesClientManager] simpleTransfer:otcAccount
                                                                              to:userAccount
                                                                           asset:assetSymbol
                                                                          amount:args_amount
                                                                            memo:args_memo_str
                                                                 memo_extra_keys:memo_extra_keys
                                                                   sign_pub_keys:sign_pub_keys
                                                                       broadcast:NO];
}

- (void)onButtomButtonClicked:(UIButton*)sender
{
    UIAlertViewManager* alertMgr = [UIAlertViewManager sharedUIAlertViewManager];
    
    switch (sender.tag) {
        case eooot_transfer:
        {
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdUserAskTransferMessage", @"确定转币给商家。是否继续？")
                              withTitle:NSLocalizedString(@"kOtcOdUserAskTransferTitle", @"确认转币")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self _execTransferCore];
                }
            }];
        }
            break;
        case eooot_contact_customer_service:
        {
            [[OtcManager sharedOtcManager] gotoSupportPage:self];
        }
            break;
        case eooot_confirm_received_money:
        {
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdUserConfirmReceiveMoneyMessage", @"我确认已登录收款账户查看，并核对收款无误。是否放行？")
                              withTitle:NSLocalizedString(@"kOtcOdUserConfirmReceiveMoneyTitle", @"确认放行")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                        if (unlocked) {
                            [self _execUpdateOrderCore:_orderDetails[@"payAccount"]
                                            payChannel:_orderDetails[@"payChannel"]
                                                  type:eoout_to_received_money];
                        }
                    }];
                }
            }];
        }
            break;
            
        case eooot_cancel_order:
        {
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdUserConfirmCancelOrderMessage", @"※ 如果您已经付款给商家，请不要取消订单！！！\n\n注：若用户当日累计取消3笔订单，会限制当日下单功能。是否继续？")
                              withTitle:NSLocalizedString(@"kOtcOdUserConfirmCancelOrderTitle", @"确认取消订单")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                        if (unlocked) {
                            [self _execUpdateOrderCore:nil
                                            payChannel:nil
                                                  type:eoout_to_cancel];
                        }
                    }];
                }
            }];
        }
            break;
        case eooot_confirm_paid:
        {
            if (!_currSelectedPaymentMethod) {
                [OrgUtils makeToast:NSLocalizedString(@"kOtcMgrErrOrderNoPaymentMethod", @"商家未添加收款方式。")];
                return;
            }
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdUserConfirmPaidMoneyMessage", @"我确认已按要求付款给商家。\n注：恶意点击将会被冻结账号。\n是否继续？")
                              withTitle:NSLocalizedString(@"kOtcOdUserConfirmPaidMoneyTitle", @"确认付款")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                        if (unlocked) {
                            [self _execUpdateOrderCore:_currSelectedPaymentMethod[@"account"]
                                            payChannel:_currSelectedPaymentMethod[@"type"]
                                                  type:eoout_to_paied];
                        }
                    }];
                }
            }];
        }
            break;
        case eooot_confirm_received_refunded:
        {
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdUserConfirmReceiveRefundMessage", @"我确认已登录原付款账户查看，并核对退款无误。是否继续？")
                              withTitle:NSLocalizedString(@"kOtcOdUserConfirmReceiveRefundTitle", @"确认收到退款")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                        if (unlocked) {
                            [self _execUpdateOrderCore:_orderDetails[@"payAccount"]
                                            payChannel:_orderDetails[@"payChannel"]
                                                  type:eoout_to_refunded_confirm];
                        }
                    }];
                }
            }];
        }
            break;
            //  商家
        case eooot_mc_cancel_sell_order:
        {
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdMerchantConfirmReturnAssetMessage", @"我由于个人原因无法接单，同意退币给用户。\n\n注：确定后将直接转帐给用户。拒绝接单将会影响您的订单完成率。是否继续？")
                              withTitle:NSLocalizedString(@"kOtcOdMerchantConfirmReturnAssetTitle", @"确认退币")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self _transferCoinToUserAndUpadteOrder:YES payAccount:nil payChannel:nil type:eoout_to_mc_return];
                }
            }];
        }
            break;
        case eooot_mc_confirm_paid:
        {
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdMerchantConfirmPaidMoneyMessage", @"我确认已按要求付款给用户。\n注：恶意点击将会被冻结账号。\n是否继续？")
                              withTitle:NSLocalizedString(@"kOtcOdMerchantConfirmPaidMoneyTitle", @"确认付款")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                        if (unlocked) {
                            [self _execUpdateOrderCore:_currSelectedPaymentMethod[@"account"]
                                            payChannel:_currSelectedPaymentMethod[@"type"]
                                                  type:eoout_to_mc_paied];
                        }
                    }];
                }
            }];
        }
            break;
        case eooot_mc_confirm_received_money:
        {
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdMerchantConfirmReceiveMoneyMessage", @"我确认已登录收款账户查看，并核对收款无误。是否放行？")
                              withTitle:NSLocalizedString(@"kOtcOdMerchantConfirmReceiveMoneyTitle", @"确认放行")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self _transferCoinToUserAndUpadteOrder:NO
                                                 payAccount:_orderDetails[@"payAccount"]
                                                 payChannel:_orderDetails[@"payChannel"]
                                                       type:eoout_to_mc_received_money];
                }
            }];
        }
            break;
        case eooot_mc_cancel_buy_order:
        {
            [alertMgr showCancelConfirm:NSLocalizedString(@"kOtcOdMerchantConfirmRefundMoneyMessage", @"我确认已从原路径退款给用户。\n\n注：拒绝接单将会影响您的订单完成率。恶意点击将直接冻结账号。是否继续？")
                              withTitle:NSLocalizedString(@"kOtcOdMerchantConfirmRefundMoneyTitle", @"确认退款")
                             completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                        if (unlocked) {
                            [self _execUpdateOrderCore:_orderDetails[@"payAccount"]
                                            payChannel:_orderDetails[@"payChannel"]
                                                  type:eoout_to_mc_cancel];
                        }
                    }];
                }
            }];
        }
            break;
        default:
            assert(false);
            break;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  背景颜色
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 主表格
    CGRect tableRect = [_btnArray count] > 0 ? [self rectWithoutNaviWithOffset:fBottomButtonsViewHeight] : [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:tableRect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.hideAllLines = YES;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 状态信息
    _viewStatusCell = [[ViewOtcOrderDetailStatus alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:nil
                                                                   vc:self];
    _viewStatusCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _viewStatusCell.accessoryType = UITableViewCellAccessoryNone;
    _viewStatusCell.backgroundColor = [UIColor clearColor];
    _viewStatusCell.showCustomBottomLine = YES;
    
    //  UI - 底部按钮
    _pBottomActionsView = nil;
    [self _genBottomActionsView:fBottomButtonsViewHeight tableRect:tableRect];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (_result_promise) {
        [_result_promise resolve:@(_orderStatusDirty)];
        _result_promise = nil;
    }
}

/*
 *  (private) 创建底部按钮视图
 */
- (void)_genBottomActionsView:(CGFloat)fHeight tableRect:(CGRect)tableRect
{
    if (_pBottomActionsView) {
        [_pBottomActionsView removeFromSuperview];
        _pBottomActionsView = nil;
    }
    if ([_btnArray count] > 0) {
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        assert([_btnArray count] <= 2);
        _pBottomActionsView = [[UIView alloc] initWithFrame:CGRectMake(0,
                                                                       tableRect.size.height,
                                                                       tableRect.size.width,
                                                                       fHeight + [self heightForBottomSafeArea])];
        [self.view addSubview:_pBottomActionsView];
        _pBottomActionsView.backgroundColor = theme.tabBarColor;
        CGFloat fBottomTotalWidth = tableRect.size.width;
        CGFloat fBtnBorderWidth = 12.0f;                                    //  边距
        CGFloat fTotalSpace = ([_btnArray count] + 1) * fBtnBorderWidth;    //  总间隔（2边+中间按钮间隔）
        CGFloat fBtnHeight = 38.0f;                                         //  按钮高度
        
        NSInteger btnIndex = 0;
        CGFloat fBtnOffsetX = fBtnBorderWidth;
        for (id btnInfo in _btnArray) {
            CGFloat fBtnWidth;
            if ([_btnArray count] == 1) {
                fBtnWidth = fBottomTotalWidth - fTotalSpace;                //  1个按钮 100%
            } else {
                if (btnIndex == 0) {
                    fBtnWidth = (fBottomTotalWidth - fTotalSpace) * 0.4;    //  2个按钮的第一个按钮
                } else {
                    fBtnWidth = (fBottomTotalWidth - fTotalSpace) * 0.6;    //  2个按钮的第二个按钮
                }
            }
            
            UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            btn.tag = [[btnInfo objectForKey:@"type"] integerValue];
            btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
            //  TODO:2.9 others button confirm?
            switch (btn.tag) {
                    //  卖单
                case eooot_transfer:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnTransfer", @"立即转币") forState:UIControlStateNormal];
                    break;
                case eooot_contact_customer_service:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnCustomerService", @"联系客服") forState:UIControlStateNormal];
                    break;
                case eooot_confirm_received_money:
                    [btn setTitle:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kOtcOdBtnConfirmReceivedMoney", @"放行"), _orderDetails[@"assetSymbol"]] forState:UIControlStateNormal];
                    break;
                    //  买单
                case eooot_cancel_order:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnCancelOrder", @"取消订单") forState:UIControlStateNormal];
                    break;
                case eooot_confirm_paid:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnConfirmPaid", @"我已付款成功") forState:UIControlStateNormal];
                    break;
                case eooot_confirm_received_refunded:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnConfirmReceivedRefunded", @"我已收到退款") forState:UIControlStateNormal];
                    break;
                    //  商家
                case eooot_mc_cancel_sell_order:
                case eooot_mc_cancel_buy_order:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnMcCancelOrder", @"无法接单") forState:UIControlStateNormal];
                    break;
                case eooot_mc_confirm_paid:
                    [btn setTitle:NSLocalizedString(@"kOtcOdBtnConfirmPaid", @"我已付款成功") forState:UIControlStateNormal];
                    break;
                case eooot_mc_confirm_received_money:
                    [btn setTitle:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kOtcOdBtnConfirmReceivedMoney", @"放行"), _orderDetails[@"assetSymbol"]] forState:UIControlStateNormal];
                    break;
                default:
                    break;
            }
            [btn setTitleColor:theme.textColorPercent forState:UIControlStateNormal];
            btn.userInteractionEnabled = YES;
            [btn addTarget:self action:@selector(onButtomButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            btn.frame = CGRectMake(fBtnOffsetX, (fHeight  - fBtnHeight) / 2, fBtnWidth, fBtnHeight);
            btn.backgroundColor = [btnInfo objectForKey:@"color"];
            [_pBottomActionsView addSubview:btn];
            
            fBtnOffsetX += fBtnWidth + fBtnBorderWidth;
            ++btnIndex;
        }
    }
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_sectionDataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id secInfos = [_sectionDataArray objectAtIndex:section];
    switch ([[secInfos objectForKey:@"type"] integerValue]) {
        case kVcSecOrderStatus:
        case kVcSecOrderInfo:
        case kVcSecCellTips:
            return 1;
        default:
            break;
    }
    return [[secInfos objectForKey:@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id secInfos = [_sectionDataArray objectAtIndex:indexPath.section];
    switch ([[secInfos objectForKey:@"type"] integerValue]) {
        case kVcSecOrderStatus:
        case kVcSecOrderInfo:
            return 80.0f;
        case kVcSecCellTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    //  默认值
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

/*
 *  (private) 复制按钮点击
 */
- (void)onCopyButtonClicked:(UIButton*)sender
{
    NSString* value = nil;
    switch (sender.tag) {
        case kVcSubMerchantRealName:
            value = [_orderDetails objectForKey:@"payRealName"] ?: @"";
            break;
        case kVcSubOrderID:
            value = [_orderDetails objectForKey:@"orderId"] ?: @"";
            break;
        case kVcSubPaymentRealName:
            value = [_currSelectedPaymentMethod objectForKey:@"realName"];
            break;
        case kVcSubPaymentAccount:
            value = [_currSelectedPaymentMethod objectForKey:@"account"];
            break;
        case kVcSubMcUserAccount:
            value = [_orderDetails objectForKey:@"userAccount"] ?: @"";
            break;
        default:
            value = [NSString stringWithFormat:@"unknown tag: %@", @(sender.tag)];
            assert(false);
            break;
    }
    if (value) {
        [UIPasteboard generalPasteboard].string = [value copy];
        [OrgUtils makeToast:NSLocalizedString(@"kOtcOdCopiedTips", @"已复制")];
    }
}

- (UIButton*)genCopyButton:(NSInteger)tag
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage* btn_image = [UIImage templateImageNamed:@"iconCopy"];
    CGSize btn_size = btn_image.size;
    [btn setBackgroundImage:btn_image forState:UIControlStateNormal];
    btn.userInteractionEnabled = YES;
    [btn addTarget:self action:@selector(onCopyButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    btn.frame = CGRectMake(0, (44 - btn_size.height) / 2, btn_size.width, btn_size.height);
    btn.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
    btn.tag = tag;
    return btn;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id secInfos = [_sectionDataArray objectAtIndex:indexPath.section];
    switch ([[secInfos objectForKey:@"type"] integerValue]) {
        case kVcSecOrderStatus:
        {
            assert(_viewStatusCell);
            [_viewStatusCell setItem:_statusInfos];
            return _viewStatusCell;
        }
            break;
        case kVcSecOrderInfo:
        {
            ViewOtcOrderDetailBasicInfo* cell = [[ViewOtcOrderDetailBasicInfo alloc] initWithStyle:UITableViewCellStyleValue1
                                                                                   reuseIdentifier:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            [cell setItem:_orderDetails];
            return cell;
        }
            break;
        case kVcSecOrderDetailInfo:
        case kvcSecPaymentInfo:
        {
            NSInteger rowType = [[[secInfos objectForKey:@"rows"] objectAtIndex:indexPath.row] integerValue];
            
            //  REMARK：付款方式单独样式的 view
            if (rowType == kVcSubPaymentMethod) {
                ViewOtcPaymentIconAndTextCell* cell = [[ViewOtcPaymentIconAndTextCell alloc] init];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.showCustomBottomLine = YES;
                cell.userType = _user_type;
                cell.bUserSell = [[_statusInfos objectForKey:@"sell"] boolValue];
                [cell setItem:_orderDetails];
                return cell;
            }
            
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor clearColor];
            cell.showCustomBottomLine = YES;
            cell.textLabel.textColor = theme.textColorNormal;
            cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
            cell.detailTextLabel.textColor = theme.textColorMain;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
            
            switch (rowType) {
                case kVcSubMerchantRealName:
                {
                    cell.textLabel.text = NSLocalizedString(@"kOtcOdCellLabelMcRealName", @"商家姓名");
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"payRealName"] ?: @"";
                    cell.accessoryView = [self genCopyButton:rowType];
                }
                    break;
                case kVcSubMerchantNickName:
                {
                    cell.textLabel.text = NSLocalizedString(@"kOtcOdCellLabelMcNickName", @"商家昵称");
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"merchantsNickname"] ?: @"";
                }
                    break;
                case kVcSubOrderID:
                {
                    cell.textLabel.text = NSLocalizedString(@"kOtcOdCellLabelOrderID", @"订单编号");
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"orderId"] ?: @"";
                    cell.accessoryView = [self genCopyButton:rowType];
                }
                    break;
                case kVcSubOrderTime:
                {
                    cell.textLabel.text = NSLocalizedString(@"kOtcOdCellLabelOrderDate", @"下单日期");
                    cell.detailTextLabel.text = [OtcManager fmtOrderDetailTime:[_orderDetails objectForKey:@"ctime"]];
                }
                    break;
                case kVcSubMcUserAccount:
                {
                    cell.textLabel.text = NSLocalizedString(@"kOtcOdCellLabelUserAccount", @"用户账号");
                    cell.detailTextLabel.text = [_orderDetails objectForKey:@"userAccount"] ?: @"";
                    cell.accessoryView = [self genCopyButton:rowType];
                }
                    break;
                    
                case kVcSubPaymentTipsSameName:
                {
                    assert(_currSelectedPaymentMethod);
                    NSString* realname = nil;
                    if (_authInfos) {
                        realname = [_authInfos optString:@"realName"];
                    }
                    if (realname && realname.length >= 2) {
                        realname = [NSString stringWithFormat:@"*%@", [realname substringFromIndex:1]];
                    }
                    if (realname) {
                        realname = [NSString stringWithFormat:@"(%@)", realname];
                    }
                    
                    id pminfos = [OtcManager auxGenPaymentMethodInfos:_currSelectedPaymentMethod[@"account"]
                                                                 type:_currSelectedPaymentMethod[@"type"]
                                                             bankname:nil];
                    
                    NSString* finalString;
                    NSString* colorString;
                    if (realname) {
                        finalString = [NSString stringWithFormat:NSLocalizedString(@"kOtcOdCellPaymentSameNameTips01", @"请使用本人%@的%@向以下账户自行转账"), realname, [pminfos objectForKey:@"name"]];
                        colorString = realname;
                    } else {
                        finalString = [NSString stringWithFormat:NSLocalizedString(@"kOtcOdCellPaymentSameNameTips02", @"请使用本人名字的%@向以下账户自行转账"), [pminfos objectForKey:@"name"]];
                        colorString = NSLocalizedString(@"kOtcOdCellPaymentSameNameTitle", @"本人名字");
                    }
                    
                    //  着色显示
                    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:finalString];
                    NSRange range = [finalString rangeOfString:colorString];
                    [attrString addAttribute:NSForegroundColorAttributeName
                                       value:theme.sellColor
                                       range:range];
                    cell.textLabel.attributedText = attrString;
                }
                    break;
                case kVcSubPaymentMethodSelect:
                {
                    assert(_currSelectedPaymentMethod);
                    
                    id pminfos = [OtcManager auxGenPaymentMethodInfos:_currSelectedPaymentMethod[@"account"]
                                                                 type:_currSelectedPaymentMethod[@"type"]
                                                             bankname:_currSelectedPaymentMethod[@"bankName"]];
                    
                    cell.imageView.image = [UIImage imageNamed:pminfos[@"icon"]];
                    cell.textLabel.text = pminfos[@"name"];
                    
                    //  多种方式可选
                    if ([[_orderDetails objectForKey:@"payMethod"] count] > 1) {
                        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                        
                        cell.detailTextLabel.text = NSLocalizedString(@"kOtcAdCellTipClickSwitchPayment", @"点此切换付款方式");
                        cell.detailTextLabel.textColor = theme.textColorGray;
                    }
                }
                    break;
                case kVcSubPaymentRealName:
                {
                    assert(_currSelectedPaymentMethod);
                    cell.textLabel.text = NSLocalizedString(@"kOtcAdCellLabelPmReceiveRealName", @"收款人");
                    cell.detailTextLabel.text = [_currSelectedPaymentMethod objectForKey:@"realName"];
                    cell.accessoryView = [self genCopyButton:rowType];
                }
                    break;
                case kVcSubPaymentAccount:
                {
                    assert(_currSelectedPaymentMethod);
                    cell.textLabel.text = NSLocalizedString(@"kOtcAdCellLabelPmReceiveAccount", @"收款账号");
                    cell.detailTextLabel.text = [_currSelectedPaymentMethod objectForKey:@"account"];
                    cell.accessoryView = [self genCopyButton:rowType];
                }
                    break;
                case kVcSubPaymentBankName:
                {
                    assert(_currSelectedPaymentMethod);
                    cell.textLabel.text = NSLocalizedString(@"kOtcAdCellLabelPmReceiveBankName", @"开户银行");
                    cell.detailTextLabel.text = [_currSelectedPaymentMethod objectForKey:@"bankName"];
                }
                    break;
                case kVcSubPaymentQrCode:
                {
                    assert(_currSelectedPaymentMethod);
                    cell.textLabel.text = NSLocalizedString(@"kOtcAdCellLabelPmReceiveQrcode", @"收款二维码");
                    cell.detailTextLabel.text = NSLocalizedString(@"kOtcAdCellTipClickViewQrcode", @"点此查看二维码");
                    cell.detailTextLabel.textColor = theme.textColorGray;
                    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                    //  icon
                    UIImageView* view = [[UIImageView alloc] initWithImage:[UIImage templateImageNamed:@"iconOtcQrcode"]];
                    view.tintColor = theme.textColorGray;
                    cell.accessoryView = view;
                }
                    break;
                default:
                    assert(false);
                    break;
            }
            
            return cell;
        }
            break;
        case kVcSecCellTips:
        {
            assert(_cell_tips);
            return _cell_tips;
        }
            break;
        default:
            assert(false);
            break;
    }
    
    //  not reached...
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        id secInfos = [_sectionDataArray objectAtIndex:indexPath.section];
        switch ([[secInfos objectForKey:@"type"] integerValue]) {
            case kvcSecPaymentInfo:
            {
                id rowInfos = [[secInfos objectForKey:@"rows"] objectAtIndex:indexPath.row];
                switch ([rowInfos integerValue]) {
                    case kVcSubPaymentMethodSelect:
                        [self _onSelectPaymentMethodClicked];
                        break;
                    case kVcSubPaymentQrCode:
                        [self _onViewPaymentQrCodeClicked];
                        break;
                    default:
                        break;
                }
            }
                break;
            default:
                break;
        }
    }];
}

/*
 *  (private) 事件 - 选择商家收款方式点击
 */
- (void)_onSelectPaymentMethodClicked
{
    id payMethod = [_orderDetails objectForKey:@"payMethod"];
    if ([payMethod count] > 1) {
        id nameList = [payMethod ruby_map:^id(id src) {
            id pminfos = [OtcManager auxGenPaymentMethodInfos:src[@"account"]
                                                         type:src[@"type"]
                                                     bankname:src[@"bankName"]];
            return [pminfos objectForKey:@"name_with_short_account"];
        }];
        [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                           message:NSLocalizedString(@"kOtcAdCellSelectMcReceiveMethodTitle", @"请选择商家收款方式")
                                                            cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                             items:nameList
                                                          callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
         {
            if (buttonIndex != cancelIndex){
                id selectedPaymentMethod = [payMethod objectAtIndex:buttonIndex];
                NSString* new_id = [NSString stringWithFormat:@"%@", selectedPaymentMethod[@"id"]];
                NSString* old_id = [NSString stringWithFormat:@"%@", _currSelectedPaymentMethod[@"id"]];
                if (![new_id isEqualToString:old_id]) {
                    // 更新商家收款方式相关字段
                    for (id sec in _sectionDataArray) {
                        if ([[sec objectForKey:@"type"] integerValue] == kvcSecPaymentInfo) {
                            [self _genPaymentRows:selectedPaymentMethod
                                     target_array:[sec objectForKey:@"rows"]];
                            [_mainTableView reloadData];
                            break;
                        }
                    }
                }
            }
        }];
    }
}

/*
 *  (private) 事件 - 点击查看二维码
 */
- (void)_onViewPaymentQrCodeClicked
{
    //  TODO:3.0 暂时不支持查看二维码
    [OrgUtils makeToast:[NSString stringWithFormat:@"view qr code: %@", [_currSelectedPaymentMethod objectForKey:@"qrCode"]]];
}

/*
 *  (public) 用户点击电话按钮联系对方
 */
- (void)onPhoneButtonClicked:(UIButton*)sender
{
    NSString* phone = [_orderDetails objectForKey:@"phone"];
    if (phone && [phone isKindOfClass:[NSString class]] && ![phone isEqualToString:@""]) {
#if TARGET_IPHONE_SIMULATOR
        [OrgUtils makeToast:[NSString stringWithFormat:@"call: %@", phone]];
#else
        NSURL* phoneUrl = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", phone]];
        [[UIApplication sharedApplication] openURL:phoneUrl];
#endif  //  TARGET_IPHONE_SIMULATOR
    }
}

@end
