//
//  ModelUtils.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import "ModelUtils.h"
#import "ChainObjectManager.h"

@implementation ModelUtils

/*
 *  (public) 资产 - 判断资产是否允许强清
 */
+ (BOOL)assetCanForceSettle:(id)asset_object
{
    NSInteger flags = [[[asset_object objectForKey:@"options"] objectForKey:@"flags"] integerValue];
    if ((flags & ebat_disable_force_settle) != 0) {
        return NO;
    }
    return YES;
}

/*
 *  (public) 资产 - 判断资产是否允许发行人全局清算
 */
+ (BOOL)assetCanGlobalSettle:(id)asset_object
{
    NSInteger issuer_permissions = [[[asset_object objectForKey:@"options"] objectForKey:@"issuer_permissions"] integerValue];
    return (issuer_permissions & ebat_global_settle) != 0;
}

/*
 *  (public) 资产 - 是否已经全局清算判断
 */
+ (BOOL)assetHasGlobalSettle:(id)bitasset_object
{
    return ![self isNullPrice:[bitasset_object objectForKey:@"settlement_price"]];
}

/*
 *  (public) 判断是否价格无效
 */
+ (BOOL)isNullPrice:(id)price
{
    if ([[[price objectForKey:@"base"] objectForKey:@"amount"] unsignedLongLongValue] == 0 ||
        [[[price objectForKey:@"quote"] objectForKey:@"amount"] unsignedLongLongValue] == 0) {
        return YES;
    }
    return NO;
}

/*
 *  (public) 辅助方法 - 从full account data获取指定资产等余额信息，返回 NSDecimalNumber 对象，没有找到对应资产则返回 ZERO 对象。
 */
+ (NSDecimalNumber*)findAssetBalance:(NSDictionary*)full_account_data asset_id:(NSString*)asset_id asset_precision:(NSInteger)asset_precision
{
    assert(full_account_data);
    assert(asset_id);
    id balances = [full_account_data objectForKey:@"balances"];
    if (balances) {
        for (id balance_object in balances) {
            if ([asset_id isEqualToString:[balance_object objectForKey:@"asset_type"]]) {
                return [NSDecimalNumber decimalNumberWithMantissa:[[balance_object objectForKey:@"balance"] unsignedLongLongValue]
                                                         exponent:-asset_precision
                                                       isNegative:NO];
            }
        }
    }
    return [NSDecimalNumber zero];
}

+ (NSDecimalNumber*)findAssetBalance:(NSDictionary*)full_account_data asset:(NSDictionary*)asset
{
    assert(asset);
    return [self findAssetBalance:full_account_data
                         asset_id:[asset objectForKey:@"id"]
                  asset_precision:[[asset objectForKey:@"precision"] integerValue]];
}

/*
 *  (public) 从石墨烯ID列表获取依赖的ID列表。
 */
+ (NSArray*)collectDependence:(NSArray*)source_oid_list level_keys:(id)keystring_or_keyarray
{
    if ([keystring_or_keyarray isKindOfClass:[NSString class]]) {
        keystring_or_keyarray = @[keystring_or_keyarray];
    }
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    NSMutableDictionary* id_hash = [NSMutableDictionary dictionary];
    for (id oid in source_oid_list) {
        id obj = [chainMgr getChainObjectByID:oid];
        assert(obj);
        id target_obj = obj;
        for (id level_key in keystring_or_keyarray) {
            assert([target_obj isKindOfClass:[NSDictionary class]]);
            target_obj = [target_obj objectForKey:level_key];
            if (!target_obj) {
                break;
            }
        }
        if (target_obj && [target_obj isKindOfClass:[NSString class]]) {
            [id_hash setObject:@YES forKey:target_obj];;
        }
    }
    return [id_hash allKeys];
}

/*
 *  (public) 计算平均数
 */
+ (NSDecimalNumber*)calculateAverage:(NSDecimalNumber*)total n:(NSDecimalNumber*)n result_precision:(NSInteger)result_precision
{
    NSDecimalNumberHandler* handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                             scale:result_precision
                                                                                  raiseOnExactness:NO
                                                                                   raiseOnOverflow:NO
                                                                                  raiseOnUnderflow:NO
                                                                               raiseOnDivideByZero:NO];
    
    return [total decimalNumberByDividingBy:n withBehavior:handler];
}

/*
 *  (public) 计算总数
 */
+ (NSDecimalNumber*)calTotal:(NSDecimalNumber*)avg n:(NSDecimalNumber*)n result_precision:(NSInteger)result_precision
{
    NSDecimalNumberHandler* handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                             scale:result_precision
                                                                                  raiseOnExactness:NO
                                                                                   raiseOnOverflow:NO
                                                                                  raiseOnUnderflow:NO
                                                                               raiseOnDivideByZero:NO];
    
    return [avg decimalNumberByMultiplyingBy:n withBehavior:handler];
}

@end
