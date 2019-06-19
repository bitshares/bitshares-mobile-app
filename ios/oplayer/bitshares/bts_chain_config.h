//
//  bts_chain_config.h
//  oplayer
//
//  Created by Aonichan on 16/1/15.
//
//

#ifndef __bts_chain_config__
#define __bts_chain_config__

/**
 *  石墨烯网络HTLC支持的Hash类型。
 */
typedef enum EBitsharesHtlcHashType
{
    EBHHT_RMD160 = 0,
    EBHHT_SHA1,
    EBHHT_SHA256
} EBitsharesHtlcHashType;

/**
 *  石墨烯账号黑白名单标记
 */
typedef enum EBitsharesWhiteListFlag
{
    ebwlf_no_listing = 0x0,                                                 //  无
    ebwlf_white_listed = 0x1,                                               //  在白名单，不在黑名单中。
    ebwlf_black_listed = 0x2,                                               //  在黑名单，不在白名单中。
    ebwlf_white_and_black_listed = ebwlf_white_listed | ebwlf_black_listed  //  同时在黑白名单中
} EBitsharesWhiteListFlag;

/**
 *  待解冻金额解禁策略
 */
typedef enum EBitsharesVestingPolicy
{
    ebvp_linear_vesting_policy = 0,         //  线性解禁
    ebvp_cdd_vesting_policy,                //  按币龄解禁
    ebvp_instant_vesting_policy             //  立即解禁
} EBitsharesVestingPolicy;

/**
 *  石墨烯网络投票类型定义
 */
typedef enum EBitsharesVoteType
{
    ebvt_committee = 0,             //  理事会
    ebvt_witness,                   //  见证人
    ebvt_worker                     //  预算项目
} EBitsharesVoteType;

/**
 *  石墨烯预算项目类型
 */
typedef enum EBitsharesWorkType
{
    ebwt_refund = 0,                //  refund
    ebwt_vesting,                   //  vesting
    ebwt_burn                       //  burn
} EBitsharesWorkType;

/**
 *  区块数据对象类型ID号定义
 */
typedef enum EBitsharesObjectType
{
    ebot_null = 0,
    ebot_base,
    ebot_account,
    ebot_asset,
    ebot_force_settlement,
    ebot_committee_member,          //  5
    ebot_witness,
    ebot_limit_order,               //  7
    ebot_call_order,                //  8
    ebot_custom,
    ebot_proposal,                  //  10
    ebot_operation_history,         //  11
    ebot_withdraw_permission,
    ebot_vesting_balance,
    ebot_worker,
    ebot_balance,
    ebot_htlc,                      //  16
} EBitsharesObjectType;

/**
 *  各种交易操作枚举定义
 */
typedef enum EBitsharesOperations
{
    ebo_transfer = 0,
    ebo_limit_order_create = 1,
    ebo_limit_order_cancel = 2,
    ebo_call_order_update = 3,
    ebo_fill_order = 4,
    ebo_account_create = 5,
    ebo_account_update = 6,
    ebo_account_whitelist = 7,
    ebo_account_upgrade = 8,
    ebo_account_transfer = 9,
    ebo_asset_create = 10,
    ebo_asset_update = 11,
    ebo_asset_update_bitasset = 12,
    ebo_asset_update_feed_producers = 13,
    ebo_asset_issue = 14,
    ebo_asset_reserve = 15,
    ebo_asset_fund_fee_pool = 16,
    ebo_asset_settle = 17,
    ebo_asset_global_settle = 18,
    ebo_asset_publish_feed = 19,
    ebo_witness_create = 20,
    ebo_witness_update = 21,
    ebo_proposal_create = 22,
    ebo_proposal_update = 23,
    ebo_proposal_delete = 24,
    ebo_withdraw_permission_create = 25,
    ebo_withdraw_permission_update = 26,
    ebo_withdraw_permission_claim = 27,
    ebo_withdraw_permission_delete = 28,
    ebo_committee_member_create = 29,
    ebo_committee_member_update = 30,
    ebo_committee_member_update_global_parameters = 31,
    ebo_vesting_balance_create = 32,
    ebo_vesting_balance_withdraw = 33,
    ebo_worker_create = 34,
    ebo_custom = 35,
    ebo_assert = 36,
    ebo_balance_claim = 37,
    ebo_override_transfer = 38,
    ebo_transfer_to_blind = 39,
    ebo_blind_transfer = 40,
    ebo_transfer_from_blind = 41,
    ebo_asset_settle_cancel = 42,
    ebo_asset_claim_fees = 43,
    ebo_fba_distribute = 44,        // VIRTUAL
    ebo_bid_collateral = 45,
    ebo_execute_bid = 46,           // VIRTUAL
    ebo_asset_claim_pool = 47,
    ebo_asset_update_issuer = 48,
    ebo_htlc_create = 49,
    ebo_htlc_redeem = 50,
    ebo_htlc_redeemed = 51,         // VIRTUAL
    ebo_htlc_extend = 52,
    ebo_htlc_refund = 53,           // VIRTUAL
} EBitsharesOperations;

//  BTS公钥地址前缀
#define BTS_ADDRESS_PREFIX                  "BTS"

//  BTS公钥地址前缀长度 = strlen(BTS_ADDRESS_PREFIX)
//#define BTS_ADDRESS_PREFIX_LENGTH           3

//  交易过期时间？
#define BTS_CHAIN_EXPIRE_IN_SECS            15

//  BTS主网公链ID（正式网络）
#define BTS_NETWORK_CHAIN_ID                "4018d7844c78f6a6c41c6a552b898022310fc5dec06da467ee7905a8dad512c8"

//  BTS主网核心资产名称（正式网络）
#define BTS_NETWORK_CORE_ASSET              "BTS"

//  BTS主网核心资产ID号
#define BTS_NETWORK_CORE_ASSET_ID           @"1.3.0"

//  BTS网络全局属性对象ID号
#define BTS_GLOBAL_PROPERTIES_ID            @"2.0.0"

//  BTS石墨烯特殊账号
//  0:理事会账号
#define BTS_GRAPHENE_COMMITTEE_ACCOUNT      @"1.2.0"

//  4:空账号（隐私交易可能需要由该账号支付手续费等）
#define BTS_GRAPHENE_TEMP_ACCOUNT           @"1.2.4"

//  5:代理给自己
#define BTS_GRAPHENE_PROXY_TO_SELF          @"1.2.5"

//  黑名单意见账号：btspp-team
#define BTS_GRAPHENE_ACCOUNT_BTSPP_TEAM     @"1.2.1031560"

//  BTS网络动态全局信息对象ID号
//  格式：
//    {"id"=>"2.1.0",
//        "head_block_number"=>28508814,
//        "head_block_id"=>"01b3028ec48c120a4f856cc8b931f2ccfb41ec79",
//        "time"=>"2018-07-07T06:16:57",
//        "current_witness"=>"1.6.22",
//        "next_maintenance_time"=>"2018-07-07T07:00:00",
//        "last_budget_time"=>"2018-07-07T06:00:00",
//        "witness_budget"=>86500000,
//        "accounts_registered_this_interval"=>5,
//        "recently_missed_count"=>0,
//        "current_aslot"=>28662531,
//        "recent_slots_filled"=>"340282366920938463463374607431768211455",
//        "dynamic_flags"=>0,
//        "last_irreversible_block_num"=>28508796}}
#define BTS_DYNAMIC_GLOBAL_PROPERTIES_ID    @"2.1.0"

#endif /* __bts_chain_config__ */
