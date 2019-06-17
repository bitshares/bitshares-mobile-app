//
//  GatewayBase.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"
#import "GatewayAssetItemData.h"

@class VCBase;

@protocol GatewayBaseInterface<NSObject>
@required

/**
 *  获取网关资产列表
 */
- (WsPromise*)queryCoinList;

/**
 *  处理资产信息，生成app标准格式。
 */
- (NSArray*)processCoinListData:(NSArray*)data_array balanceHash:(NSDictionary*)balanceHash;

/**
 *  请求充值地址
 */
- (WsPromise*)requestDepositAddress:(id)item fullAccountData:(id)fullAccountData vc:(VCBase*)vc;

/**
 *  验证地址、备注、数量是否有效
 */
- (WsPromise*)checkAddress:(id)item address:(NSString*)address memo:(NSString*)memo amount:(NSString*)amount;

/**
 *  (public) 查询提币网关中间账号以及转账需要备注的memo信息。
 */
- (WsPromise*)queryWithdrawIntermediateAccountAndFinalMemo:(GatewayAssetItemData*)appext
                                                   address:(NSString*)address
                                                      memo:(NSString*)memo
                                   intermediateAccountData:(NSDictionary*)intermediateAccountData;

@end

@interface GatewayBase : NSObject<GatewayBaseInterface>

@property (nonatomic, strong) NSDictionary* api_config_json;

- (id)initWithApiConfig:(NSDictionary*)api_config_json;

/**
 *  (protected) 从网关服务器API接口查询充值地址。（REMARK：仅需要查询时才调用。）
 *  成功返回json，失败返回err。
 */
- (WsPromise*)requestDepositAddressCore:(id)item
                                 appext:(GatewayAssetItemData*)appext
            request_deposit_address_url:(id)request_deposit_address_url
                      full_account_data:(id)full_account_data
                                     vc:(VCBase*)vc;

/**
 *  辅助 - 根据json的value获取对应的数字字符串。
 */
- (NSString*)auxValueToNumberString:(id)json_value zero_as_nil:(BOOL)zero_as_nil;

/**
 *  辅助 - 根据json的value获取对应的数字字符串，并返回两者中较小的值。
 */
- (NSString*)auxMinValue:(id)json_value01 value02:(id)json_value02 zero_as_nil:(BOOL)zero_as_nil;

@end
