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
 *  API认证方式
 */
typedef enum EOtcAuthFlag
{
    eoaf_none = 0,                          //  无需认证
    eoaf_sign,                              //  Active私钥签名认证
    eoaf_token                              //  Token认证
} EOtcAuthFlag;

/*
 *  错误码
 */
typedef enum EOtcErrorCode
{
    eoerr_ok = 0,                           //  正常
    eoerr_too_often = 1012,                 //  请求太频繁
    eoerr_not_login = 2011,                 //  未登录
    eoerr_order_cancel_to_go_online = 5001, //  取消订单数量太多？TODO:2.9
    //  TODO:2.9 其他待添加
} EOtcErrorCode;

/*
 *  场外交易用户类型
 */
typedef enum EOtcUserType
{
    eout_normal_user = 0,   //  普通用户
    eout_merchant           //  商家
} EOtcUserType;

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
 *  场外交易收款方式状态
 */
typedef enum EOtcPaymentMethodStatus
{
    eopms_enable = 1,       //  已开启
    eopms_disable           //  已禁用
} EOtcPaymentMethodStatus;

/*
 *  商家广告类型
 */
typedef enum EOtcAdType
{
    eoadt_all = 0,                          //  所有广告
    
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
 *  用户订单查询状态 TODO:2.9 申诉中哪些状态呢？
 */
typedef enum EOtcOrderStatus
{
    eoos_all = 0,           //  查询全部
    eoos_pending,           //  查询进行中
    eoos_completed,         //  查询已完成
    eoos_cancelled,         //  查询已取消
} EOtcOrderStatus;

/*
 *  用户订单进度状态，数据库 status 字段。
 */
typedef enum EOtcOrderProgressStatus
{
    eoops_new = 1,                  //  订单已创建
    eoops_already_paid = 2,         //  已付款
    eoops_already_transferred = 3,  //  已转币
    eoops_already_confirmed = 4,    //  区块已确认 TODO:2.9 确认中还是已确认？待审核，描述也需要对应调整。
    eoops_refunded = 5,             //  已退款
    eoops_refund_failed = 6,        //  退款失败
    eoops_completed = 7,            //  交易成功
    eoops_cancelled = 8,            //  失败订单（包括取消订单）
    eoops_chain_failed = 9,         //  区块操作失败（异常了）
    eoops_return_assets = 10,       //  退币中
} EOtcOrderProgressStatus;

/*
 *  用户更新订单类型。
 */
typedef enum EOtcOrderUpdateType
{
    eoout_to_paied = 1,             //  买单：确认付款
    eoout_to_cancel = 2,            //  买单：取消订单
    eoout_to_refunded_confirm = 3,  //  买单：商家退款&用户确认&取消订单
    eoout_to_transferred = 4,       //  卖单：用户确认转币
    eoout_to_received_money = 5,    //  卖单：确认收款 TODO:2.9 不确定
} EOtcOrderUpdateType;

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

/*
 *  用户订单对应的各种可操作事件类型。仅客户端用，服务器不存在。
 */
typedef enum EOtcOrderOperationType
{
    eooot_transfer = 0,                 //  卖单：立即转币
    eooot_contact_customer_service,     //  卖单：联系客服
    eooot_confirm_received_money,       //  卖单：确认收款（放行资产给商家）
    
    eooot_cancel_order,                 //  买单：取消订单
    eooot_confirm_paid,                 //  买单：我已付款成功
    eooot_confirm_received_refunded,    //  买单：确认收到商家退款 & 取消订单
} EOtcOrderOperationType;

#pragma mark- merchant enum

/*
 *  商家：申请进度
 */
typedef enum EOtcMcProgress
{
    eomp_default = 0,                   //  未申请：默认值
    eomp_applying,                      //  申请中
    eomp_approved,                      //  已同意
    eomp_rejected,                      //  已拒绝
    eomp_activated,                     //  已激活
} EOtcMcProgress;

@class VCBase;

@interface OtcManager : NSObject

@property (nonatomic, strong) NSArray* asset_list_digital;  //  支持的数字资产列表

+ (OtcManager*)sharedOtcManager;

/*
 *  (public) 解析 OTC 服务器返回的时间字符串，格式：2019-11-26T13:29:51.000+0000。
 */
+ (NSTimeInterval)parseTime:(NSString*)time;

/*
 *  格式化：场外交易订单列表日期显示格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
 */
+ (NSString*)fmtOrderListTime:(NSString*)time;

/*
 *  格式化：场外交易订单详情日期显示格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
 */
+ (NSString*)fmtOrderDetailTime:(NSString*)time;

/*
 *  格式化：格式化商家加入日期格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
 */
+ (NSString*)fmtMerchantTime:(NSString*)time;

/*
 *  格式化：场外交易订单倒计时时间。
 */
+ (NSString*)fmtPaymentExpireTime:(NSInteger)left_ts;

/*
 *  (public) 辅助 - 获取收款方式名字图标等。
 */
+ (NSDictionary*)auxGenPaymentMethodInfos:(NSString*)account type:(id)type bankname:(NSString*)bankname;

/*
 *  (public) 辅助 - 根据订单当前状态获取主状态、状态描述、以及可操作按钮等信息。
 */
+ (NSDictionary*)auxGenUserOrderStatusAndActions:(id)order;

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
 *  (public) 确保已经进行认证认证。
 */
- (void)guardUserIdVerified:(VCBase*)owner
                  auto_hide:(BOOL)auto_hide
          askForIdVerifyMsg:(NSString*)askForIdVerifyMsg
                   callback:(void (^)(id auth_info))verifyed_callback;

/*
 *  (public) 请求私钥授权登录。
 */
- (void)handleOtcUserLogin:(VCBase*)owner login_callback:(void (^)())login_callback;

/*
 *  (public) 处理用户注销账号。需要清理token等信息。
 */
- (void)processLogout;

/*
 *  (public) 是否是未登录错误判断。
 */
- (BOOL)isOtcUserNotLoginError:(id)error;

/*
 *  (public) 显示OTC的错误信息。
 */
- (void)showOtcError:(id)error;
- (void)showOtcError:(id)error not_login_callback:(void (^)())not_login_callback;

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
 *  (public) 更新订单
 */
- (WsPromise*)updateUserOrder:(NSString*)bts_account_name
                     order_id:(NSString*)order_id
                   payAccount:(NSString*)payAccount
                   payChannel:(id)payChannel
                         type:(EOtcOrderUpdateType)type;

/*
 *  (public) 查询用户收款方式/增加收款方式/删除收款方式/编辑收款方式
 */
- (WsPromise*)queryPaymentMethods:(NSString*)bts_account_name;
- (WsPromise*)addPaymentMethods:(id)args;
- (WsPromise*)delPaymentMethods:(NSString*)bts_account_name pmid:(id)pmid;
- (WsPromise*)editPaymentMethods:(NSString*)bts_account_name new_status:(EOtcPaymentMethodStatus)new_status pmid:(id)pmid;

/*
 *  (public) 上传二维码图片。
 */
- (WsPromise*)uploadQrCode:(NSString*)bts_account_name filename:(NSString*)filename data:(NSData*)data;

/*
 *  (public) 获取二维码图片流。
 */
- (WsPromise*)queryQrCode:(NSString*)bts_account_name filename:(NSString*)filename;

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
- (WsPromise*)queryAdList:(EOtcAdStatus)ad_status
                     type:(EOtcAdType)ad_type
               asset_name:(NSString*)asset_name
               otcAccount:(NSString*)otcAccount
                     page:(NSInteger)page
                page_size:(NSInteger)page_size;

///*
// *  (public) 查询广告详情。
// */
//- (WsPromise*)queryAdDetails:(NSString*)ad_id;

/*
 *  (public) 锁定价格
 */
- (WsPromise*)lockPrice:(NSString*)bts_account_name
                  ad_id:(NSString*)ad_id
                   type:(EOtcAdType)ad_type
           asset_symbol:(NSString*)asset_symbol
                  price:(NSString*)price;

/*
 *  (public) 发送短信
 */
- (WsPromise*)sendSmsCode:(NSString*)bts_account_name phone:(NSString*)phone_number type:(EOtcSmsType)type;

/*
 *  (public) 登录。部分API接口需要传递登录过的token字段。
 */
- (WsPromise*)login:(NSString*)bts_account_name;

#pragma mark- for merchant

- (void)gotoOtcMerchantHome:(VCBase*)owner;

/*
 *  (public) API - 商家申请进度查询
 */
- (WsPromise*)merchantProgress:(NSString*)bts_account_name;

/*
 *  (public) API - 查询商家订单列表
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryMerchantOrders:(NSString*)bts_account_name
                             type:(EOtcOrderType)type
                           status:(EOtcOrderStatus)status
                             page:(NSInteger)page
                        page_size:(NSInteger)page_size;

/*
 *  (public) API - 查询订单详情
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryMerchantOrderDetails:(NSString*)bts_account_name order_id:(NSString*)order_id;

/*
 *  (public) API - 查询商家资产
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryMerchantOtcAsset:(NSString*)bts_account_name;

/*
 *  (public) API - 查询商家指定资产余额查询
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryMerchantAssetBalance:(NSString*)bts_account_name
                             otcAccount:(NSString*)otcAccount
                             merchantId:(id)merchantId
                            assetSymbol:(id)assetSymbol;

/*
 *  (public) API - 查询商家付款方式
 *  认证：TOKEN 方式
 */
- (WsPromise*)queryMerchantPaymentMethods:(NSString*)bts_account_name;

/*
 *  (public) API - 更新商家付款方式
 *  认证：SIGN 方式
 */
- (WsPromise*)updateMerchantPaymentMethods:(NSString*)bts_account_name
                                otcAccount:(NSString*)otcAccount
                              aliPaySwitch:(id)aliPaySwitch
                         bankcardPaySwitch:(id)bankcardPaySwitch;

@end
