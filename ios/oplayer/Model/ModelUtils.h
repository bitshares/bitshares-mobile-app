//
//  ModelUtils.h
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import <Foundation/Foundation.h>

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
 *  (public) 资产 - 是否已经全局清算判断
 */
+ (BOOL)assetHasGlobalSettle:(id)bitasset_object;

/*
 *  (public) 判断是否价格无效
 */
+ (BOOL)isNullPrice:(id)price;

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

@end
