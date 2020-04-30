//
//  ModelUtils.h
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import <Foundation/Foundation.h>

@class TradingPair;

@interface ModelUtils : NSObject

/*
 *  (public) 资产 - 判断资产是否允许强清
 */
+ (BOOL)assetCanForceSettle:(id)asset_object;

/*
 *  (public) 资产 - 判断资产是否允许发行人全局清算
 */
+ (BOOL)assetCanGlobalSettle:(id)asset_object;

/*
 *  (public) 资产 - 判断资产是否允许隐私转账
 */
+ (BOOL)assetAllowConfidential:(id)asset_object;

/*
 *  (public) 资产 - 资产是否允许覆盖转账（强制转账）
 */
+ (BOOL)assetCanOverride:(id)asset_object;

/*
 *  (public) 资产 - 是否所有转账都需要发行人审核
 */
+ (BOOL)assetIsTransferRestricted:(id)asset_object;

/*
 *  (public) 资产 - 资产是否需要持有人属于白名单判断。
 */
+ (BOOL)assetNeedWhiteList:(id)asset_object;

/*
 *  (public) 资产 - 是否已经全局清算判断
 */
+ (BOOL)assetHasGlobalSettle:(id)bitasset_object;

/*
 *  (public) 资产 - 是否是智能币判断
 */
+ (BOOL)assetIsSmart:(id)asset;

/*
 *  (public) 资产 - 是否是链核心资产判断
 */
+ (BOOL)assetIsCore:(id)asset;

/*
 *  (public) 判断是否价格无效
 */
+ (BOOL)isNullPrice:(id)price;

/*
 *  (public) 根据汇率换算手续费。
 */
+ (NSDecimalNumber*)multiplyAndRoundupNetworkFee:(id)core_asset
                                           asset:(id)asset
                                      n_core_fee:(NSDecimalNumber*)n_core_fee
                              core_exchange_rate:(id)core_exchange_rate;

/*
 *  (public) 辅助方法 - 从full account data获取指定资产等余额信息，返回 NSDecimalNumber 对象，没有找到对应资产则返回 ZERO 对象。
 */
+ (NSDecimalNumber*)findAssetBalance:(NSDictionary*)full_account_data asset_id:(NSString*)asset_id asset_precision:(NSInteger)asset_precision;
+ (NSDecimalNumber*)findAssetBalance:(NSDictionary*)full_account_data asset:(NSDictionary*)asset;

/*
 *  (public) 从石墨烯ID列表获取依赖的ID列表。
 */
+ (NSArray*)collectDependence:(NSArray*)source_oid_list level_keys:(id)keystring_or_keyarray;

/*
 *  (public) 计算平均数
 */
+ (NSDecimalNumber*)calculateAverage:(NSDecimalNumber*)total n:(NSDecimalNumber*)n result_precision:(NSInteger)result_precision;

/*
 *  (public) 计算总数
 */
+ (NSDecimalNumber*)calTotal:(NSDecimalNumber*)avg n:(NSDecimalNumber*)n result_precision:(NSInteger)result_precision;

/*
 *  (public) 处理链上返回的限价单信息，方便UI显示。
 *  filterTradingPair - 筛选当前交易对相关订单，可为nil。
 */
+ (NSMutableArray*)processLimitOrders:(NSArray*)limit_orders filter:(TradingPair*)filterTradingPair;

@end
