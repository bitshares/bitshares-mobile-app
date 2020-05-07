//
//  VCStealthTransferHelper.h
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//  隐私交易相关辅助方法。

#import <Foundation/Foundation.h>

/*
 *  APP隐私收据区块编号key字段名定义。
 */
#define kAppBlindReceiptBlockNum                @"abrbn"

/*
 *  隐私账户助记词校验码前缀。
 */
#define kAppBlindAccountBrainKeyCheckSumPrefix  @"StealthTransfer"

@class GraphenePublicKey;
@class VCBase;
@interface VCStealthTransferHelper : NSObject

/*
 *  (public) 尝试解析隐私收据字符串为 json 格式。不是有效的收据则返回nil，成功返回 json 对象。
 *  支持两种收据字符串：
 *  1、APP收据字符串。
 *  2、cli命令行钱包收据字符串。
 */
+ (id)guessBlindReceiptString:(NSString*)base58_string;

/*
 *  (public) 根据 to_public_key 和 数量生成一个【隐私输出】。
 */
+ (NSDictionary*)genOneBlindOutput:(GraphenePublicKey*)to_public_key
                          n_amount:(NSDecimalNumber*)n_amount
                             asset:(id)asset
                     num_of_output:(NSUInteger)num_of_output
                 used_blind_factor:(NSData*)used_blind_factor;

/*
 *  (public) 生成隐私输出参数。
 */
+ (id)genBlindOutputs:(NSArray*)data_array_output asset:(NSDictionary*)asset input_blinding_factors:(NSArray*)input_blinding_factors;

/*
 *  (public) 生成隐私输入参数。成功返回数组，失败返回 nil。
 *  extra_pub_pri_hash - 附近私钥Hash KEY：WIF_PUB_KEY   VALUE：GraphenePrivateKey*
 */
+ (NSArray*)genBlindInputs:(NSArray*)data_array_input
   output_blinding_factors:(NSMutableArray*)output_blinding_factors
                 sign_keys:(NSMutableDictionary*)sign_keys
        extra_pub_pri_hash:(NSDictionary*)extra_pub_pri_hash;

/*
 *  (public) 对盲化因子数组求和，所有的都作为【正】因子对待。
 */
+ (NSData*)blindSum:(NSArray*)blinding_factors_array;

/*
 *  (public) 选择收据（隐私交易的的 input 部分）
 */
+ (void)processSelectReceipts:(VCBase*)this_
     curr_blind_balance_arary:(NSArray*)curr_blind_balance_arary
                     callback:(void (^)(id new_blind_balance_array))callback;

@end
