//
//  BitsharesClientManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"
#import "Extension.h"
#import "BinSerializer.h"

#include "bts_wallet_core.h"

@interface BitsharesClientManager : NSObject

+ (BitsharesClientManager*)sharedBitsharesClientManager;

#pragma mark- api
/**
 *  创建理事会成员 TODO：未完成
 */
- (WsPromise*)createMemberCommittee:(NSString*)committee_member_account_id url:(NSString*)url;

/**
 *  创建见证人成员 REMARK：需要终身会员权限。    TODO：未完成
 */
- (WsPromise*)createWitness:(NSString*)witness_account_id url:(NSString*)url signkey:(NSString*)block_signing_key;

- (WsPromise*)transfer:(NSDictionary*)transfer_op_data;
/**
 *  更新帐号信息（投票 TODO:fowallet 目前仅支持修改new_options)
 */
- (WsPromise*)accountUpdate:(NSDictionary*)account_update_op_data;
/**
 *  OP - 升级帐号
 */
- (WsPromise*)accountUpgrade:(NSDictionary*)op_data;
- (WsPromise*)callOrderUpdate:(NSDictionary*)callorder_update_op;
- (WsPromise*)createLimitOrder:(NSDictionary*)limit_order_op;
- (WsPromise*)cancelLimitOrders:(NSArray*)cancel_limit_order_op_array;

/**
 *  OP - 创建待解冻金额
 */
- (WsPromise*)vestingBalanceCreate:(NSDictionary*)opdata;

/**
 *  OP - 提取待解冻金额
 */
- (WsPromise*)vestingBalanceWithdraw:(NSDictionary*)opdata;

/**
 *  计算手续费
 */
- (WsPromise*)calcOperationFee:(EBitsharesOperations)opcode opdata:(id)opdata;

/**
 *  创建提案
 */
- (WsPromise*)proposalCreate:(EBitsharesOperations)opcode
                      opdata:(id)opdata
                   opaccount:(id)opaccount
        proposal_create_args:(id)proposal_create_args;

/**
 *  OP - 更新提案（添加授权or移除授权）
 */
- (WsPromise*)proposalUpdate:(NSDictionary*)opdata;

/**
 *  OP - 更新资产发行者
 */
- (WsPromise*)assetUpdateIssuer:(NSDictionary*)opdata;

/**
 *  OP - 创建HTLC合约
 */
- (WsPromise*)htlcCreate:(NSDictionary*)opdata;

/**
 *  OP - 提取HTLC合约
 */
- (WsPromise*)htlcRedeem:(NSDictionary*)opdata;

/**
 *  OP - 扩展HTLC合约有效期
 */
- (WsPromise*)htlcExtend:(NSDictionary*)opdata;

@end
