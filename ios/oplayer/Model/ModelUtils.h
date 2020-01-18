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
 *  (public) 辅助方法 - 从full account data获取指定资产等余额信息，返回 NSDecimalNumber 对象，没有找到对应资产则返回 ZERO 对象。
 */
+ (NSDecimalNumber*)findAssetBalance:(NSDictionary*)full_account_data asset_id:(NSString*)asset_id asset_precision:(NSInteger)asset_precision;
+ (NSDecimalNumber*)findAssetBalance:(NSDictionary*)full_account_data asset:(NSDictionary*)asset;

@end
