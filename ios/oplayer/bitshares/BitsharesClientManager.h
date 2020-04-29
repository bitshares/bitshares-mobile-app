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

/*
 *  OP - 执行单个 operation 的交易。（可指定是否需要 owner 权限。）
 */
- (WsPromise*)runSingleTransaction:(NSDictionary*)opdata
                            opcode:(EBitsharesOperations)opcode
                fee_paying_account:(NSString*)fee_paying_account
          require_owner_permission:(BOOL)require_owner_permission;

- (WsPromise*)runSingleTransaction:(NSDictionary*)opdata
                            opcode:(EBitsharesOperations)opcode
                fee_paying_account:(NSString*)fee_paying_account;

/**
 *  创建理事会成员 TODO：未完成
 */
- (WsPromise*)createMemberCommittee:(NSString*)committee_member_account_id url:(NSString*)url;

/**
 *  创建见证人成员 REMARK：需要终身会员权限。    TODO：未完成
 */
- (WsPromise*)createWitness:(NSString*)witness_account_id url:(NSString*)url signkey:(NSString*)block_signing_key;

/*
 *  OP - 转账（简化版）
 */
- (WsPromise*)simpleTransfer:(NSString*)from_name
                          to:(NSString*)to_name
                       asset:(NSString*)asset_name
                      amount:(NSString*)amount
                        memo:(NSString*)memo
             memo_extra_keys:(id)memo_extra_keys
               sign_pub_keys:(NSArray*)sign_pub_keys
                   broadcast:(BOOL)broadcast;

- (WsPromise*)simpleTransfer2:(id)full_from_account
                           to:(id)to_account
                        asset:(id)asset
                       amount:(NSString*)amount
                         memo:(NSString*)memo
              memo_extra_keys:(id)memo_extra_keys
                sign_pub_keys:(NSArray*)sign_pub_keys
                    broadcast:(BOOL)broadcast;

- (WsPromise*)transfer:(NSDictionary*)transfer_op_data;

/**
 *  更新帐号信息（投票 TODO:fowallet 目前仅支持修改new_options)
 */
- (WsPromise*)accountUpdate:(NSDictionary*)account_update_op_data;
/**
 *  OP - 升级帐号
 */
- (WsPromise*)accountUpgrade:(NSDictionary*)op_data;
/*
 *  OP - 转移账号
 */
- (WsPromise*)accountTransfer:(NSDictionary*)op_data;

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
 *  OP - 创建提案
 */
- (WsPromise*)proposalCreate:(NSArray*)opcode_data_object_array
                   opaccount:(id)opaccount
        proposal_create_args:(id)proposal_create_args;

/**
 *  OP - 更新提案（添加授权or移除授权）
 */
- (WsPromise*)proposalUpdate:(NSDictionary*)opdata;

/**
 *  OP -创建资产。
 */
- (WsPromise*)assetCreate:(NSDictionary*)opdata;

/**
 *  OP -全局清算资产。
 */
- (WsPromise*)assetGlobalSettle:(NSDictionary*)opdata;

/**
 *  OP -清算资产。
 */
- (WsPromise*)assetSettle:(NSDictionary*)opdata;

/**
 *  OP -更新资产基本信息。
 */
- (WsPromise*)assetUpdate:(NSDictionary*)opdata;

/**
 *  OP -更新智能币相关信息。
 */
- (WsPromise*)assetUpdateBitasset:(NSDictionary*)opdata;

/**
 *  OP -更新智能币的喂价人员信息。
 */
- (WsPromise*)assetUpdateFeedProducers:(NSDictionary*)opdata;

/**
 *  OP -销毁资产（减少当前供应量）REMARK：不能对智能资产进行操作。
 */
- (WsPromise*)assetReserve:(NSDictionary*)opdata;

/**
 *  OP -发行资产给某人
 */
- (WsPromise*)assetIssue:(NSDictionary*)opdata;

/**
 *  OP -提取资产等手续费池资金
 */
- (WsPromise*)assetClaimPool:(NSDictionary*)opdata;

/**
 *  OP - 更新资产发行者
 */
- (WsPromise*)assetUpdateIssuer:(NSDictionary*)opdata;

/**
 *  OP - 断言
 */
- (WsPromise*)assert:(NSDictionary*)opdata;

/**
 *  OP - 转入隐私账号
 */
- (WsPromise*)transferToBlind:(NSDictionary*)opdata;

/**
 *  OP - 从隐私账号转出
 */
- (WsPromise*)transferFromBlind:(NSDictionary*)opdata signPriKeyHash:(NSDictionary*)signPriKeyHash;

/**
 *  OP - 隐私转账
 */
- (WsPromise*)blindTransfer:(NSDictionary*)opdata signPriKeyHash:(NSDictionary*)signPriKeyHash;

/**
 *  OP - 验证隐私收据有效性。REMARK：构造一个 transfer_from_blind 请求 + 一个必定失败的断言 请求。获取错误信息。
 */
- (WsPromise*)verifyBlindReceipt:(NSDictionary*)opdata signPriKeyHash:(NSDictionary*)signPriKeyHash;

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
