package bitshares

/**
 *  账号模式，密码语言枚举。
 */
enum class EBitsharesAccountPasswordLang(val value: Int) {
    ebap_lang_zh(0),    //  中文密码（16个汉字）
    ebap_lang_en(1),    //  英文密码（32个字符 A-Za-z0-9）
}

/**
 *  石墨烯网络HTLC支持的Hash类型。
 */
enum class EBitsharesHtlcHashType(val value: Int) {
    EBHHT_RMD160(0),
    EBHHT_SHA1(1),
    EBHHT_SHA256(2)
}

/*
 *  资产各种操作类型枚举 TODO:4.0 预测市场暂不考虑
 */
enum class EBitsharesAssetOpKind(val value: Int) {
    //  管理员的操作
    ebaok_view(0),                      //  资产详情
    ebaok_edit(1),                      //  资产编辑（基本信息）
    ebaok_issue(2),                     //  资产发行（仅UIA资产）
    ebaok_override_transfer(3),         //  强制回收（需要开启对应权限标记）
    ebaok_global_settle(4),             //  全局清算（仅Smart资产，并且需要开启对应权限标记）
    ebaok_claim_pool(5),                //  提取手续费池（除Core外的所有资产）
    ebaok_claim_fees(6),                //  提取交易手续费（除Core外的所有资产）
    ebaok_fund_fee_pool(7),             //  注资手续费池（除Core外的所有资产）
    ebaok_update_issuer(8),             //  变更所有者（需要owner权限，且UIA不能转移给理事会）
    ebaok_publish_feed(9),              //  发布喂价（仅Smart资产）
    ebaok_update_feed_producers(10),    //  更新喂价人员（仅Smart资产）
    ebaok_update_bitasset(11),          //  编辑智能币相关信息（仅Smart资产）

    //  资产持有者的操作
    ebaok_transfer(100),                //  转账（所有资产）
    ebaok_trade(101),                   //  交易（所有资产）
    ebaok_reserve(102),                 //  资产销毁（仅UIA资产）
    ebaok_settle(103),                  //  资产清算（仅Smart资产）
    ebaok_call_order_update(104),       //  调整债仓（仅Smart资产）
    ebaok_stake_vote(105),              //  锁仓投票（仅BTS）
    ebaok_more(106),                    //  虚拟按钮：更多
}

/**
 *  石墨烯网络资产的各种标记。
 */
enum class EBitsharesAssetFlags(val value: Int) {
    ebat_charge_market_fee(0x01),       //  收取交易手续费
    ebat_white_list(0x02),              //  要求资产持有人预先加入白名单
    ebat_override_authority(0x04),      //  发行人可将资产收回
    ebat_transfer_restricted(0x08),     //  所有转账必须通过发行人审核同意
    ebat_disable_force_settle(0x10),    //  禁止强制清算
    ebat_global_settle(0x20),           //  允许发行人进行全局强制清算（仅可设置permission，不可设置flags）
    ebat_disable_confidential(0x40),    //  禁止隐私交易
    ebat_witness_fed_asset(0x80),       //  允许见证人提供喂价（和理事会喂价不可同时激活）
    ebat_committee_fed_asset(0x100),    //  允许理事会成员提供喂价（和见证人喂价不可同时激活）

    //  UIA资产默认权限mask
    ebat_issuer_permission_mask_uia(ebat_charge_market_fee.value.or(ebat_white_list.value).or(ebat_override_authority.value).or(ebat_transfer_restricted.value).or(ebat_disable_confidential.value)),
    //  Smart资产扩展的权限mask
    ebat_issuer_permission_mask_smart_only(ebat_disable_force_settle.value.or(ebat_global_settle.value).or(ebat_witness_fed_asset.value).or(ebat_committee_fed_asset.value)),
    //  Smart资产默认权限mask
    ebat_issuer_permission_mask_smart(ebat_issuer_permission_mask_uia.value.or(ebat_issuer_permission_mask_smart_only.value)),
}

/**
 *  石墨烯账号黑白名单标记
 */
enum class EBitsharesWhiteListFlag(val value: Int) {
    ebwlf_no_listing(0x0),                                          //  无
    ebwlf_white_listed(0x1),                                        //  在白名单，不在黑名单中。
    ebwlf_black_listed(0x2),                                        //  在黑名单，不在白名单中。
    ebwlf_white_and_black_listed(ebwlf_white_listed.value.or(ebwlf_black_listed.value)) //  同时在黑白名单中
}

/**
 * BTS石墨烯私钥类型定义
 * 参考：https://github.com/satoshilabs/slips/issues/49。
 */
enum class EHDBitsharesPermissionType(val value: Int) {
    ehdbpt_owner(0x0),                      //  所有者权限
    ehdbpt_active(0x1),                     //  资金权限
    ehdbpt_memo(0x2),                       //  备注权限
    ehdbpt_stealth_mainkey(0x3),            //  隐私主地址（OP：39、40、41）
    ehdbpt_stealth_childkey(0x4),           //  隐私主地址的派生子地址
}

/**
 *  待解冻金额解禁策略
 */
enum class EBitsharesVestingPolicy(val value: Int) {
    ebvp_linear_vesting_policy(0),          //  线性解禁
    ebvp_cdd_vesting_policy(1),             //  按币龄解禁
    ebvp_instant_vesting_policy(2)          //  立即解禁
}

/**
 *  区块数据对象类型ID号定义
 */
enum class EBitsharesObjectType(val value: Int) {
    ebot_null(0),
    ebot_base(1),
    ebot_account(2),
    ebot_asset(3),
    ebot_force_settlement(4),
    ebot_committee_member(5),          //  5
    ebot_witness(6),
    ebot_limit_order(7),               //  7
    ebot_call_order(8),                //  8
    ebot_custom(9),
    ebot_proposal(10),                 //  10
    ebot_operation_history(11),        //  11
    ebot_withdraw_permission(12),
    ebot_vesting_balance(13),
    ebot_worker(14),
    ebot_balance(15),
    ebot_htlc(16),
    ebot_custom_authority(17),          //  17
    ebot_ticket(18),                    //  18
}

/**
 *  各种交易操作枚举定义
 */
enum class EBitsharesOperations(val value: Int) {
    ebo_transfer(0),
    ebo_limit_order_create(1),
    ebo_limit_order_cancel(2),
    ebo_call_order_update(3),
    ebo_fill_order(4),
    ebo_account_create(5),
    ebo_account_update(6),
    ebo_account_whitelist(7),
    ebo_account_upgrade(8),
    ebo_account_transfer(9),
    ebo_asset_create(10),
    ebo_asset_update(11),
    ebo_asset_update_bitasset(12),
    ebo_asset_update_feed_producers(13),
    ebo_asset_issue(14),
    ebo_asset_reserve(15),
    ebo_asset_fund_fee_pool(16),
    ebo_asset_settle(17),
    ebo_asset_global_settle(18),
    ebo_asset_publish_feed(19),
    ebo_witness_create(20),
    ebo_witness_update(21),
    ebo_proposal_create(22),
    ebo_proposal_update(23),
    ebo_proposal_delete(24),
    ebo_withdraw_permission_create(25),
    ebo_withdraw_permission_update(26),
    ebo_withdraw_permission_claim(27),
    ebo_withdraw_permission_delete(28),
    ebo_committee_member_create(29),
    ebo_committee_member_update(30),
    ebo_committee_member_update_global_parameters(31),
    ebo_vesting_balance_create(32),
    ebo_vesting_balance_withdraw(33),
    ebo_worker_create(34),
    ebo_custom(35),
    ebo_assert(36),
    ebo_balance_claim(37),
    ebo_override_transfer(38),
    ebo_transfer_to_blind(39),
    ebo_blind_transfer(40),
    ebo_transfer_from_blind(41),
    ebo_asset_settle_cancel(42),
    ebo_asset_claim_fees(43),
    ebo_fba_distribute(44),        // VIRTUAL
    ebo_bid_collateral(45),
    ebo_execute_bid(46),           // VIRTUAL
    ebo_asset_claim_pool(47),
    ebo_asset_update_issuer(48),
    ebo_htlc_create(49),
    ebo_htlc_redeem(50),
    ebo_htlc_redeemed(51),         // VIRTUAL
    ebo_htlc_extend(52),
    ebo_htlc_refund(53),           // VIRTUAL
    ebo_custom_authority_create(54),
    ebo_custom_authority_update(55),
    ebo_custom_authority_delete(56),
    ebo_ticket_create(57),
    ebo_ticket_update(58),
}

/**
 *  石墨烯预算项目类型
 */
enum class EBitsharesWorkType(val value: Int) {
    ebwt_refund(0),
    ebwt_vesting(1),
    ebwt_burn(2),
}

/**
 *  石墨烯权限类型
 */
enum class EBitsharesPermissionType(val value: Int) {
    ebpt_owner(0),          //  账号权限
    ebpt_active(1),         //  资金权限
    ebpt_memo(2),           //  备注权限
    ebpt_custom(3),         //  BSIP40自定义权限
}

/*
 *  石墨烯提案创建者所属安全等级（仅APP客户端存在）
 */
enum class EBitsharesProposalSecurityLevel(val value: Int) {
    ebpsl_whitelist(0),                 //  白名单成员发起（TODO:2.8暂时不支持白名单。）
    ebpsl_multi_sign_member_lv0(1),     //  待授权账号的直接多签成员发起的提案
    ebpsl_multi_sign_member_lv1(2),     //  多签自身也是多签管理（则由子账号发起，最多支持2级。）
    ebpsl_unknown(3),                   //  陌生账号发起
}

/*
 *  喂价者类型
 */
enum class EBitsharesFeedPublisherType(val value: Int) {
    ebfpt_witness(0),           //  由见证人喂价
    ebfpt_committee(1),         //  由理事会喂价
    ebfpt_custom(2),             //  指定喂价者
}

const val BTS_ADDRESS_PREFIX: String = "BTS"

//  BTS公钥地址前缀长度 = strlen(BTS_ADDRESS_PREFIX)
const val BTS_ADDRESS_PREFIX_LENGTH: Int = 3

//  交易过期时间？
const val BTS_CHAIN_EXPIRE_IN_SECS: Int = 15

//  TODO:4.0 大部分参数可通过 get_config 接口返回。
//  BTS主网公链ID（正式网络）
const val BTS_NETWORK_CHAIN_ID: String = "4018d7844c78f6a6c41c6a552b898022310fc5dec06da467ee7905a8dad512c8"

//  BTS主网核心资产名称（正式网络）
const val BTS_NETWORK_CORE_ASSET: String = "BTS"

//  BTS主网核心资产ID号
const val BTS_NETWORK_CORE_ASSET_ID: String = "1.3.0"

//  BTS网络全局属性对象ID号
const val BTS_GLOBAL_PROPERTIES_ID: String = "2.0.0"

//  BTS石墨烯特殊账号
//  0:理事会账号
const val BTS_GRAPHENE_COMMITTEE_ACCOUNT = "1.2.0"

const val BTS_GRAPHENE_WITNESS_ACCOUNT = "1.2.1"

//  4:空账号（隐私交易可能需要由该账号支付手续费等）
const val BTS_GRAPHENE_TEMP_ACCOUNT = "1.2.4"

//  5:代理给自己
const val BTS_GRAPHENE_PROXY_TO_SELF = "1.2.5"

//  黑名单意见账号：btspp-team
const val BTS_GRAPHENE_ACCOUNT_BTSPP_TEAM = "1.2.1031560"

//  资产最大供应量
const val GRAPHENE_MAX_SHARE_SUPPLY = 1000000000000000L
const val GRAPHENE_100_PERCENT = 10000
const val GRAPHENE_1_PERCENT = (GRAPHENE_100_PERCENT / 100)

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
const val BTS_DYNAMIC_GLOBAL_PROPERTIES_ID: String = "2.1.0"


/**
 *  各种交易操作枚举定义
 */
enum class VotingTypes(val value: Int) {
    committees(0),               //  理事会
    witnesses(1),                //  见证人
    workers(2),                  //  worker
}

/**
 *  HTLC合约部署方式
 */
enum class EHtlcDeployMode(val value: Int) {
    EDM_PREIMAGE(0),               //  根据原像部署
    EDM_HASHCODE(1),               //  根据Hash部署
}

/**
 *  OTC 订单状态
 */
enum class OtcOrderStatus(val value: Int) {
    STARTING(0),               //  进行中
    FINISHED(1),               //  已完成
    CANCELED(2)                //  已取消
}

/**
 *  OTC 付款方式
 */
enum class OtcPaymentMethods(val value: Int) {
    ALIPAY(0),               //  支付宝
    BANKCARD(1),             //  银行卡
}
