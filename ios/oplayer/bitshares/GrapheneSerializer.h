//
//  GrapheneSerializer.h
//  Serialize for graphene operation.
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>

@interface T_Base : NSObject

+ (NSData*)encode_to_bytes:(id)opdata;
+ (id)encode_to_object:(id)opdata;

/**
 *  (public) 注册可序列化的类型。REMARK：所有复合类型都必须注册，基本类型不用注册。
 */
+ (void)registerAllType;

@end

/***
 *  以下为基本数据类型。
 */
@interface T_uint8 : T_Base
@end

@interface T_uint16 : T_Base
@end

@interface T_uint32 : T_Base
@end

@interface T_uint64 : T_Base
@end

@interface T_int64 : T_Base
@end

@interface T_varint32 : T_Base
@end

@interface T_string : T_Base
@end

@interface T_bool : T_Base
@end

@interface T_void : T_Base
@end

@interface T_future_extensions : T_void
@end

@interface T_object_id_type : T_Base
@end

@interface T_vote_id : T_Base
@end

@interface T_public_key : T_Base
@end

@interface T_address : T_Base
@end

@interface T_time_point_sec : T_uint32
@end

/***
 *  以下为动态扩展类型。
 */

@interface Tm_protocol_id_type : T_Base
@end

@interface Tm_extension : T_Base
@end

@interface Tm_array : T_Base
@end

@interface Tm_map : T_Base
@end

@interface Tm_set : T_Base
@end

@interface Tm_bytes : T_Base
@end

@interface Tm_optional : T_Base
@end

@interface Tm_static_variant : T_Base
@end

/***
 *  以下为复合数据类型（大部分op都是为复合类型）。
 */

/**
 *  资产对象
 */
@interface T_asset : T_Base
@end

/**
 *  转账的备注对象
 */
@interface T_memo_data : T_Base
@end

/**
 *  OP - 转账
 */
@interface T_transfer : T_Base
@end

/**
 *  OP - 创建限价单
 */
@interface T_limit_order_create : T_Base
@end

/**
 *  OP - 取消限价单
 */
@interface T_limit_order_cancel : T_Base
@end

/**
 *  OP - 更新保证金（抵押借贷）
 */
@interface T_call_order_update : T_Base
@end

/**
 *  OP - 账号创建、更新相关
 */
@interface T_authority : T_Base
@end

@interface T_account_options : T_Base
@end

@interface T_account_create : T_Base
@end

@interface T_account_update : T_Base
@end

@interface T_account_upgrade : T_Base
@end

/**
 *  OP - 待解冻金额相关
 */
@interface T_linear_vesting_policy_initializer : T_Base
@end

@interface T_cdd_vesting_policy_initializer : T_Base
@end

@interface T_vesting_balance_create : T_Base
@end

@interface T_vesting_balance_withdraw : T_Base
@end

/**
 *  OP - 提案相关
 */
@interface T_op_wrapper : T_Base
@end

@interface T_proposal_create : T_Base
@end

@interface T_proposal_update : T_Base
@end

@interface T_proposal_delete : T_Base
@end

/**
 *  OP - 资产相关操作
 */
@interface T_asset_update_issuer : T_Base
@end

/**
 *  OP - HTLC相关
 */
@interface T_htlc_create : T_Base
@end

@interface T_htlc_redeem : T_Base
@end

@interface T_htlc_extend : T_Base
@end

/**
 *  特殊OP - 操作类型和操作对象。
 */
@interface T_operation : T_Base
@end

/**
 *  交易对象（未签名的）
 */
@interface T_transaction : T_Base
@end

/**
 *  交易对象（已签名的）
 */
@interface T_signed_transaction : T_transaction
@end
