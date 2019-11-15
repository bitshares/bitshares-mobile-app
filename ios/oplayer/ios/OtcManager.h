//
//  OtcManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//  管理场外交易相关数据请求等。

#import <Foundation/Foundation.h>
#import "WsPromise.h"

/*
 *  资产类型
 */
typedef enum EOtcAssetType
{
    eoat_fiat = 1,          //  法币
    eoat_digital = 2        //  数字货币
} EOtcAssetType;

/*
 *  商家广告类型
 */
typedef enum EOtcAdType
{
    eoadt_merchant_sell = 1,                //  商家出售（用户购买）
    eoadt_merchant_buy = 2,                 //  商家购买（用户出售）
    
    eoadt_user_sell = eoadt_merchant_buy,   //  用户出售（商家购买）
    eoadt_user_buy = eoadt_merchant_sell    //  用户购买（商家出售）
} EOtcAdType;

/*
 *  商家广告状态
 */
typedef enum EOtcAdStatus
{
    eoads_online = 1,       //  上架中
    eoads_offline = 2,      //  下架中
    eoads_deleted = 3,      //  删除
} EOtcAdStatus;

@interface OtcManager : NSObject

+ (OtcManager*)sharedOtcManager;

/*
 *  (public) 查询OTC用户身份认证信息。
 *  bts_account_name    - BTS账号名
 */
- (WsPromise*)queryIdVerify:(NSString*)bts_account_name;

/*
 *  (public) 查询OTC支持的数字资产列表（bitCNY、bitUSD、USDT等）
 *  asset_type - 资产类型 默认值：eoat_digital
 */
- (WsPromise*)queryAssetList;
- (WsPromise*)queryAssetList:(EOtcAssetType)asset_type;

/*
 *  (public) 查询OTC商家广告列表。
 *  ad_status   - 广告状态 默认值：eoads_online
 *  ad_type     - 状态类型
 *  asset_name  - OTC数字资产名字（CNY、USD、GDEX.USDT等）
 *  page        - 页号
 *  page_size   - 每页数量
 */
- (WsPromise*)queryAdList:(EOtcAdType)ad_type asset_name:(NSString*)asset_name page:(NSInteger)page page_size:(NSInteger)page_size;
- (WsPromise*)queryAdList:(EOtcAdStatus)ad_status type:(EOtcAdType)ad_type asset_name:(NSString*)asset_name
                     page:(NSInteger)page page_size:(NSInteger)page_size;

@end
