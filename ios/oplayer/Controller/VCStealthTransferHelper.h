//
//  VCStealthTransferHelper.h
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//  隐私交易相关辅助方法。

#import <Foundation/Foundation.h>

@class GraphenePublicKey;
@class VCBase;
@interface VCStealthTransferHelper : NSObject

/*
 *  (public) 生成隐私输出参数。
 */
+ (id)genBlindOutputs:(NSArray*)data_array_output asset:(NSDictionary*)asset input_blinding_factors:(NSArray*)input_blinding_factors;

/*
 *  (public) 生成隐私输入参数。成功返回数组，失败返回 nil。
 */
+ (NSArray*)genBlindInputs:(NSArray*)data_array_input
   output_blinding_factors:(NSMutableArray*)output_blinding_factors
                 sign_keys:(NSMutableDictionary*)sign_keys;

/*
 *  (public) 对盲化因子数组求和，所有的都作为【正】因子对待。
 */
+ (NSData*)blindSum:(NSArray*)blinding_factors_array;

/*
 *  (public) 选择收据（隐私交易的的 input 部分）
 */
+ (void)processSelectReceipts:(VCBase*)this_ callback:(void (^)(id new_blind_balance_array))callback;

@end
