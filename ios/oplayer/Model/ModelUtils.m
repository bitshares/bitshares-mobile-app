//
//  ModelUtils.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import "ModelUtils.h"

@implementation ModelUtils

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

@end
