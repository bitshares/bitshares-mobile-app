//
//  BitsharesClientManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "BitsharesClientManager.h"
#import "GrapheneApi.h"
#import "TransactionBuilder.h"
#import "GrapheneWebSocket.h"
#import "ChainObjectManager.h"
#import "GrapheneSerializer.h"
#import "WalletManager.h"

static BitsharesClientManager *_sharedBitsharesClientManager = nil;

@interface BitsharesClientManager()
{
}
@end

@implementation BitsharesClientManager

+(BitsharesClientManager *)sharedBitsharesClientManager
{
    @synchronized(self)
    {
        if(!_sharedBitsharesClientManager)
        {
            _sharedBitsharesClientManager = [[BitsharesClientManager alloc] init];
        }
        return _sharedBitsharesClientManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

- (void)dealloc
{
}

#pragma mark- private
- (WsPromise*)process_transaction:(TransactionBuilder*)tr
{
    return [[[tr set_required_fees:nil removeDuplicates:NO] then:(^id(id data) {
        return [tr broadcast];
    })] then:(^id(id data) {
        NSLog(@"tid:%@ broadcast callback notify data: %@", [tr transaction_id], data);
        //  TODO:fowallet 到这里就是交易广播成功 并且 回调已经执行了
        return data;
    })];
}

#pragma mark- api

/**
 *  创建理事会成员 REMARK：需要终身会员权限。    TODO：未完成
 */
- (WsPromise*)createMemberCommittee:(NSString*)committee_member_account_id url:(NSString*)url
{
    //  TODO:
    return nil;
}

/**
 *  创建见证人成员 REMARK：需要终身会员权限。    TODO：未完成
 */
- (WsPromise*)createWitness:(NSString*)witness_account_id url:(NSString*)url signkey:(NSString*)block_signing_key
{
    //  TODO:fowallet
    return nil;
}

/**
 *  OP - 转账
 */
- (WsPromise*)transfer:(NSDictionary*)transfer_op_data
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_transfer opdata:transfer_op_data];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[transfer_op_data objectForKey:@"from"]]];
    return [self process_transaction:tr];
}

/**
 *  OP - 更新帐号信息
 */
- (WsPromise*)accountUpdate:(NSDictionary*)account_update_op_data
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_account_update opdata:account_update_op_data];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[account_update_op_data objectForKey:@"account"]]];
    return [self process_transaction:tr];
}

/**
 *  OP - 升级帐号
 */
- (WsPromise*)accountUpgrade:(NSDictionary*)op_data
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_account_upgrade opdata:op_data];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[op_data objectForKey:@"account_to_upgrade"]]];
    return [self process_transaction:tr];
}

/**
 *  OP - 更新保证金（抵押借贷）
 */
- (WsPromise*)callOrderUpdate:(NSDictionary*)callorder_update_op
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_call_order_update opdata:callorder_update_op];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[callorder_update_op objectForKey:@"funding_account"]]];
    return [self process_transaction:tr];
}

/**
 *  OP - 创建限价单
 */
- (WsPromise*)createLimitOrder:(NSDictionary*)limit_order_op
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_limit_order_create opdata:limit_order_op];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[limit_order_op objectForKey:@"seller"]]];
    return [self process_transaction:tr];
}

/**
 *  OP - 取消限价单
 */
- (WsPromise*)cancelLimitOrders:(NSArray*)cancel_limit_order_op_array
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    for (id op in cancel_limit_order_op_array) {
        [tr add_operation:ebo_limit_order_cancel opdata:op];
        [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[op objectForKey:@"fee_paying_account"]]];
    }
    return [self process_transaction:tr];
}

/**
 *  OP - 创建待解冻金额
 */
- (WsPromise*)vestingBalanceCreate:(NSDictionary*)opdata
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_vesting_balance_create opdata:opdata];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[opdata objectForKey:@"creator"]]];
    return [self process_transaction:tr];
}

/**
 *  OP - 提取待解冻金额
 */
- (WsPromise*)vestingBalanceWithdraw:(NSDictionary*)opdata
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_vesting_balance_withdraw opdata:opdata];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[opdata objectForKey:@"owner"]]];
    return [self process_transaction:tr];
}

/**
 *  (public) 从网络计算手续费
 */
- (WsPromise*)calcOperationFee:(EBitsharesOperations)opcode opdata:(id)opdata
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:opcode opdata:opdata];
    
    return [[tr set_required_fees:nil removeDuplicates:NO] then:(^id(id data_array) {
        NSLog(@"%@", data_array);
        
        //  参考 set_required_fees 的请求部分，两组 promise all。
        id allfees = [data_array objectAtIndex:0];
        id op_fees = [allfees firstObject];
        
        assert([op_fees count] == 1);
        return [op_fees objectAtIndex:0];
    })];
}

/**
 *  (private) 返回包含手续费对象的 opdata。
 */
- (WsPromise*)_wrap_opdata_with_fee:(EBitsharesOperations)opcode opdata:(id)opdata
{
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        id opdata_fee = [opdata objectForKey:@"fee"];
        if (!opdata_fee || [[opdata_fee objectForKey:@"amount"] longLongValue] == 0){
            //  计算手续费
            [[[self calcOperationFee:opcode opdata:opdata] then:(^id(id fee_price_item) {
                id m_opdata = [opdata mutableCopy];
                [m_opdata setObject:fee_price_item forKey:@"fee"];
                resolve([m_opdata copy]);
                return nil;
            })] catch:(^id(id error) {
                reject(error);
                return nil;
            })];
        }else{
            //  有手续费直接返回。
            resolve(opdata);
        }
    }];
}

/**
 *  OP - 创建提案
 */
- (WsPromise*)proposalCreate:(EBitsharesOperations)opcode
                      opdata:(id)opdata
                   opaccount:(id)opaccount
        proposal_create_args:(id)proposal_create_args
{
    assert(opdata);
    assert(opaccount);
    assert(proposal_create_args);
    
    id kFeePayingAccount = [proposal_create_args objectForKey:@"kFeePayingAccount"];
    NSInteger kApprovePeriod = [[proposal_create_args objectForKey:@"kApprovePeriod"] integerValue];
    NSInteger kReviewPeriod = [[proposal_create_args objectForKey:@"kReviewPeriod"] integerValue];
    
    assert(kFeePayingAccount);
    assert(kApprovePeriod > 0);
    
    NSString* fee_paying_account_id = [kFeePayingAccount objectForKey:@"id"];
    assert(fee_paying_account_id);
    
    return [[self _wrap_opdata_with_fee:opcode opdata:opdata] then:(^id(id opdata_with_fee) {
        
        //  提案有效期
        NSUInteger proposal_lifetime_sec = kApprovePeriod + kReviewPeriod;
        
        //  提案审核期
        NSUInteger review_period_seconds = kReviewPeriod;
        
        //  获取全局参数
        id gp = [[ChainObjectManager sharedChainObjectManager] getObjectGlobalProperties];
        if (gp){
            id parameters = [gp objectForKey:@"parameters"];
            if (parameters){
                //  不能 超过最大值（当前值28天）
                NSUInteger maximum_proposal_lifetime = [[parameters objectForKey:@"maximum_proposal_lifetime"] unsignedIntegerValue];
                proposal_lifetime_sec = MIN(maximum_proposal_lifetime, proposal_lifetime_sec);
                
                //  不能低于最低值（当前值1小时）
                NSUInteger committee_proposal_review_period = [[parameters objectForKey:@"committee_proposal_review_period"] unsignedIntegerValue];
                review_period_seconds = MAX(committee_proposal_review_period, review_period_seconds);
            }
        }
        assert(proposal_lifetime_sec > 0);
        assert(review_period_seconds < proposal_lifetime_sec);
        
        //  过期时间戳
        NSTimeInterval now_sec = ceil([[NSDate date] timeIntervalSince1970]);
        uint32_t expiration_ts = (uint32_t)(now_sec + proposal_lifetime_sec);
        
        id op = @{
                  @"fee":@{@"amount":@0, @"asset_id":[ChainObjectManager sharedChainObjectManager].grapheneCoreAssetID},
                  @"fee_paying_account":fee_paying_account_id,
                  @"expiration_time":@(expiration_ts),
                  @"proposed_ops":@[@{@"op":@[@(opcode), opdata_with_fee]}],
                  };
        
        //  REMARK：理事会提案必须添加审核期。
        assert(![[opaccount objectForKey:@"id"] isEqualToString:BTS_GRAPHENE_COMMITTEE_ACCOUNT] || kReviewPeriod > 0);
        
        //  添加审核期
        if (kReviewPeriod > 0){
            id mutable_op = [op mutableCopy];
            [mutable_op setObject:@(review_period_seconds) forKey:@"review_period_seconds"];
            op = [mutable_op copy];
        }
        
        TransactionBuilder* tr = [[TransactionBuilder alloc] init];
        [tr add_operation:ebo_proposal_create opdata:op];
        [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:fee_paying_account_id]];
        return [self process_transaction:tr];
    })];
}

/**
 *  OP - 更新提案（添加授权or移除授权）
 */
- (WsPromise*)proposalUpdate:(NSDictionary*)opdata
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_proposal_update opdata:opdata];
    
    //  获取所有需要签名的KEY
    WalletManager* walletMgr = [WalletManager sharedWalletManager];
    NSDictionary* idAccountDataHash = [walletMgr getAllAccountDataHash:NO];
    for (id account_id in [opdata objectForKey:@"active_approvals_to_add"]) {
        id account_data = [idAccountDataHash objectForKey:account_id];
        assert(account_data);
        [tr addSignKeys:[walletMgr getSignKeys:[account_data objectForKey:@"active"]]];
    }
    for (id account_id in [opdata objectForKey:@"active_approvals_to_remove"]) {
        id account_data = [idAccountDataHash objectForKey:account_id];
        assert(account_data);
        [tr addSignKeys:[walletMgr getSignKeys:[account_data objectForKey:@"active"]]];
    }
    for (id account_id in [opdata objectForKey:@"owner_approvals_to_add"]) {
        id account_data = [idAccountDataHash objectForKey:account_id];
        assert(account_data);
        [tr addSignKeys:[walletMgr getSignKeys:[account_data objectForKey:@"owner"]]];
    }
    for (id account_id in [opdata objectForKey:@"owner_approvals_to_remove"]) {
        id account_data = [idAccountDataHash objectForKey:account_id];
        assert(account_data);
        [tr addSignKeys:[walletMgr getSignKeys:[account_data objectForKey:@"owner"]]];
    }
    for (id pubKey in [opdata objectForKey:@"key_approvals_to_add"]) {
        assert([walletMgr havePrivateKey:pubKey]);
        [tr addSignKey:pubKey];
    }
    for (id pubKey in [opdata objectForKey:@"key_approvals_to_remove"]) {
        assert([walletMgr havePrivateKey:pubKey]);
        [tr addSignKey:pubKey];
    }
    //  手续费支付账号也需要签名
    [tr addSignKeys:[walletMgr getSignKeysFromFeePayingAccount:[opdata objectForKey:@"fee_paying_account"]]];
    
    return [self process_transaction:tr];
}

/**
 *  OP - 更新资产发行者
 */
- (WsPromise*)assetUpdateIssuer:(NSDictionary*)opdata
{
    //  TODO:待测试
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_asset_update_issuer opdata:opdata];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[opdata objectForKey:@"issuer"]
                                                                  requireOwnerPermission:YES]];
    return [self process_transaction:tr];
}

/**
 *  OP - 创建HTLC合约
 */
- (WsPromise*)htlcCreate:(NSDictionary*)opdata
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_htlc_create opdata:opdata];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[opdata objectForKey:@"from"]]];
    return [self process_transaction:tr];
}

/**
 *  OP - 提取HTLC合约
 */
- (WsPromise*)htlcRedeem:(NSDictionary*)opdata
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_htlc_redeem opdata:opdata];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[opdata objectForKey:@"redeemer"]]];
    return [self process_transaction:tr];
}

/**
 *  OP - 扩展HTLC合约有效期
 */
- (WsPromise*)htlcExtend:(NSDictionary*)opdata
{
    TransactionBuilder* tr = [[TransactionBuilder alloc] init];
    [tr add_operation:ebo_htlc_extend opdata:opdata];
    [tr addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:[opdata objectForKey:@"update_issuer"]]];
    return [self process_transaction:tr];
}

@end
