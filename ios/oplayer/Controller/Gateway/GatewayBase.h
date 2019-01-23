//
//  GatewayBase.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"

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
 *  验证地址是否有效
 */
- (WsPromise*)checkAddress:(id)item address:(NSString*)address;

@end

@interface GatewayBase : NSObject<GatewayBaseInterface>

@property (nonatomic, strong) NSDictionary* api_config_json;

- (id)initWithApiConfig:(NSDictionary*)api_config_json;

/**
 *  (protected) 从网关服务器API接口查询充值地址。（REMARK：仅需要查询时才调用。）
 *  成功返回json，失败返回err。
 */
- (WsPromise*)requestDepositAddressCore:(id)item
                                 appext:(id)appext
            request_deposit_address_url:(id)request_deposit_address_url
                      full_account_data:(id)full_account_data
                                     vc:(VCBase*)vc;

@end
