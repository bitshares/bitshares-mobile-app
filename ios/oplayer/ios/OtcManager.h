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
 *  场外交易账号状态
 */
typedef enum EOtcUserStatus
{
    eous_default = 0,       //  默认值（初始化时的值）
    eous_normal,            //  正常
    eous_freeze,            //  冻结中
} EOtcUserStatus;

/*
 *  场外交易身份认证状态
 */
typedef enum EOtcUserIdVerifyStatus
{
    eovs_none = 0,          //  未认证
    eovs_kyc1,              //  1级认证
    eovs_kyc2,              //  2级认证
    eovs_kyc3,              //  3级认证
} EOtcUserIdVerifyStatus;

/*
 *  场外交易收款方式类型
 */
typedef enum EOtcPaymentMethodType
{
    eopmt_alipay = 1,       //  支付宝
    eopmt_bankcard,         //  银行卡
    eopmt_wechatpay         //  微信
} EOtcPaymentMethodType;

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
 *  用户订单类型
 */
typedef enum EOtcOrderType
{
    eoot_query_all = 0,     //  查询参数 - 全部
    eoot_query_sell = 1,    //  查询参数 - 出售
    eoot_query_buy = 2,     //  查询参数 - 购买
    eoot_data_sell = 2,     //  返回类型 - 出售
    eoot_data_buy = 1,      //  返回类型 - 购买
} EOtcOrderType;

/*
 *  用户订单状态 TODO:2.9 申诉中哪些状态呢？
 */
typedef enum EOtcOrderStatus
{
    eoos_all = 0,           //  全部
    eoos_pending,           //  进行中
    eoos_completed,         //  已完成
    eoos_cancelled,         //  已取消
} EOtcOrderStatus;

/*
 *  商家广告状态
 */
typedef enum EOtcAdStatus
{
    eoads_online = 1,       //  上架中
    eoads_offline = 2,      //  下架中
    eoads_deleted = 3,      //  删除
} EOtcAdStatus;

/*
 *  验证码业务类型
 */
typedef enum EOtcSmsType
{
    eost_id_verify = 1,     //  身份认证
    eost_change_phone,      //  更换手机号
    eost_new_order_notify,  //  新订单通知
} EOtcSmsType;

@class VCBase;

@interface OtcManager : NSObject

@property (nonatomic, strong) NSArray* asset_list_digital;  //  支持的数字资产列表

+ (OtcManager*)sharedOtcManager;

/*
 *  (public) 当前账号名
 */
- (NSString*)getCurrentBtsAccount;

/*
 *  (public) 获取当前法币信息
 */
- (NSDictionary*)getFiatCnyInfo;

/*
 *  (public) 是否支持指定资产判断
 */
- (BOOL)isSupportDigital:(NSString*)asset_name;

/*
 *  (public) 获取资产信息。OTC运营方配置的，非链上数据。
 */
- (NSDictionary*)getAssetInfo:(NSString*)asset_name;

/*
 *  (public) 转到OTC界面，会自动初始化必要信息。
 */
- (void)gotoOtc:(VCBase*)owner asset_name:(NSString*)asset_name ad_type:(EOtcAdType)ad_type;

/*
 *  (public) 显示OTC的错误信息。
 */
- (void)showOtcError:(id)error;

/*
 *  (public) 辅助方法 - 是否已认证判断
 */
- (BOOL)isIdVerifyed:(id)data;

/*
 *  (public) 查询OTC用户身份认证信息。
 *  bts_account_name    - BTS账号名
 */
- (WsPromise*)queryIdVerify:(NSString*)bts_account_name;

/*
 *  (public) 请求身份认证
 */
- (WsPromise*)idVerify:(id)args;

/*
 *  (public) 创建订单
 */
- (WsPromise*)createUserOrder:(NSString*)bts_account_name
                        ad_id:(NSString*)ad_id
                         type:(EOtcAdType)ad_type
                        price:(NSString*)price
                        total:(NSString*)total;

/*
 *  (public) 查询用户订单列表
 */
- (WsPromise*)queryUserOrders:(NSString*)bts_account_name
                         type:(EOtcOrderType)type
                       status:(EOtcOrderStatus)status
                         page:(NSInteger)page
                    page_size:(NSInteger)page_size;

/*
 *  (public) 查询订单详情
 */
- (WsPromise*)queryUserOrderDetails:(NSString*)bts_account_name order_id:(NSString*)order_id;

/*
 *  (public) 查询用户收款方式
 */
- (WsPromise*)queryPaymentMethods:(NSString*)bts_account_name;

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

/*
 *  (public) 查询广告详情。
 */
- (WsPromise*)queryAdDetails:(NSString*)ad_id;

/*
 *  (public) 锁定价格
 */
- (WsPromise*)lockPrice:(NSString*)bts_account_name ad_id:(NSString*)ad_id type:(EOtcAdType)ad_type price:(NSString*)price;

/*
 *  (public) 发送短信
 */
- (WsPromise*)sendSmsCode:(NSString*)bts_account_name phone:(NSString*)phone_number type:(EOtcSmsType)type;

@end
