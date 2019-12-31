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
 *  入口类型
 */
typedef enum EOtcEntryType
{
    eoet_enabled = 1,       //  启用。不需要msg。
    eoet_disabled = 2,      //  禁用。可见，不可进入。提示msg。
    eoet_gone = 3           //  不可见。不需要msg。
} EOtcEntryType;

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
 *  错误码 带 ※ 号的客户端需要反馈给用户。
 */
typedef enum EOtcErrorCode
{
    eoerr_ok = 0,                                   //  正常
    eoerr_system = 1,                               //  系统错误
    eoerr_internal = 1001,                          //  内部错误
    eoerr_miss_param = 1002,                        //  参数错误
    eoerr_miss_db = 1003,                           //  数据库错误
    eoerr_rpc_error = 1004,                         //  RPC错误
    eoerr_id_alloc = 1005,                          //  ID分配错误
    eoerr_system_close = 1006,                      //  系统关闭
    eoerr_system_config_missing = 1007,             //  缺少配置信息
    eoerr_miss_io = 1008,                           //  IO错误
    eoerr_req_limit = 1009,                         //  请求错误限制
    eoerr_address_query = 1010,                     //  查询地址错误
    eoerr_sign_blank = 1011,                        //  签名为空
    eoerr_too_often = 1012,                         //  ※ 请求太频繁
    eoerr_sign_error = 1013,                        //  签名错误
    eoerr_request_expired = 1014,                   //  请求已经过期
    
    //  用户部分
    eoerr_user_not_exist = 2001,                    //  用户不存在
    eoerr_user_frozen = 2002,                       //  ※ 账号已被冻结
    eoerr_user_idcard_not_verify = 2003,            //  ※ 身份未验证
    eoerr_user_idcard_verifyed = 2004,              //  身份已验证，不用重复验证。
    eoerr_user_idcard_verify_failed = 2005,         //  ※ 身份认证失败。
    eoerr_user_idcard_bind_other_account = 2006,    //  ※ 身份已绑定其他BTS账户
    eoerr_user_change_same_phone = 2007,            //  用户替换相同的手机号码
    eoerr_user_sms_type_failed = 2008,              //  无法获取短信模版
    eoerr_user_account_not_exist = 2009,            //  BTS账号不存在
    eoerr_user_account_not_empty = 2010,            //  BTS账号不为空
    eoerr_user_account_not_login = 2011,            //  ※ BTS账号未登录
    
    //  商家部分
    eoerr_merchant_not_actived = 3001,              //  商家未激活
    eoerr_merchant_not_exist = 3002,                //  商家不存在
    eoerr_bts_account_isnt_merchant = 3003,         //  BTS账号暂不是商家
    eoerr_bak_account_is_merchant = 3004,           //  备用BTS账号已经是商家了
    eoerr_nickname_already_exist = 3005,            //  商家昵称被占用
    eoerr_insufficient_conditions = 3006,           //  不符合申请条件
    eoerr_unapplied_merchant = 3007,                //  未申请的商家
    eoerr_insufficient_margin = 3008,               //  保证金不足
    
    //  广告部分
    eoerr_ad_existed_ad = 4001,                     //  ※ 已存在相同的广告
    eoerr_ad_info = 4002,                           //  广告信息错误
    eoerr_ad_price_changed = 4003,                  //  广告价格变化了
    eoerr_ad_price_lock_expired = 4004,             //  ※ 广告价格锁定已过期
    eoerr_ad_price_not_match = 4005,                //  价格不匹配
    eoerr_ad_exist_ing_order = 4006,                //  ※ 广告存在进行中的订单
    eoerr_ad_less_than_lowest_num = 4007,           //  ※ 参数错误：小于最低限额
    eoerr_ad_more_than_useable_num = 4008,          //  ※ 参数错误：商家库存（余额）不足
    eoerr_ad_status_not_valid = 4009,               //  无效广告（广告已下架等
    eoerr_ad_price_not_equal_zero = 4010,           //  广告价格非零
    eoerr_ad_more_than_highest_num = 4011,          //  ※ 参数错误：超过最大限额
    
    //  订单相关
    eoerr_order_cancel_to_go_online = 5001,         //  ※ 取消订单数量达到上限
    eoerr_order_business_type_error = 5002,         //  业务类型错误
    eoerr_order_more_than_useable_num = 5003,       //  ※ 超过广告可交易数量
    eoerr_merchant_free = 5004,                     //  ※ BTS手续费余额不足，最低50。
    eoerr_order_in_progress_online = 5005,          //  ※ 进行中的订单达到上限
    eoerr_asset_not_exist = 5006,                   //  资产不存在
    eoerr_amount_to_large = 5007,                   //  ※ 订单金额太大
    eoerr_amount_to_small = 5008,                   //  ※ 订单金额太小
    eoerr_error_order = 5009,                       //  订单不存在or状态错误
    eoerr_order_payment_methods = 5010,             //  商家广告缺少付款方式
    eoerr_order_no_payment = 5011,                  //  ※ 未添加付款方式
    eoerr_order_not_exist = 5012,                   //  订单不存在
    
    //  短信相关
    eoerr_sms_upper_limit = 6001,                   //  ※ 短信验证码条数超过限制
    eoerr_sms_code_wrong = 6002,                    //  ※ 验证码不正确或已过期
    eoerr_sms_code_exist = 6003,                    //  ※ 请不要重复发送短信验证码
    eoerr_sms_template_not_find_key = 6004,         //  解析SMS模版错误-找不到需要替换到密钥
    
    //  文件相关
    eoerr_file_blank = 7001,                        //  文件为空
    eoerr_file_not_upload = 7002,                   //  文件未上传
    eoerr_file_format = 7003,                       //  文件格式错误
    eoerr_file_too_large = 7004,                    //  文件过大
    eoerr_file_type = 7005,                         //  文件类型错误
    eoerr_file_upload_too_often = 7006,             //  文件上传太频繁
    
    //  付款方式相关
    eoerr_pay_method = 8001,                        //  付款方式不正确
    eoerr_bankcard_blank = 8002,                    //  银行卡号不能为空
    eoerr_bankcard_reserved_phone = 8003,           //  预留手机号不能为空
    eoerr_bankcard_type_blank = 8004,               //  需要银行卡类型
    eoerr_bankcard_type = 8005,                     //  银行卡类型不正确
    eoerr_pay_account_blank = 8006,                 //  付款账号为空
    eoerr_bankcard_verify = 8007,                   //  ※ 银行卡四元素验证失败
    eoerr_receive_method_exist = 8009,              //  付款方式已经存在
    eoerr_no_payment_account = 8010,                //  请添加一个付款账号
    
    //  juhe
    eoerr_api_call = 9001,                          //  调用API异常
    
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
 *  商家广告定价类型
 */
typedef enum EOtcPriceType
{
    eopt_price_fixed = 1,   //  固定价格
} EOtcPriceType;

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
    eoos_all = 0,               //  用户和商家都是：查询全部
    
    eoos_pending = 1,           //  用户：查询进行中
    eoos_completed = 2,         //  用户：查询已完成
    eoos_cancelled = 3,         //  用户：查询已取消
    
    eoos_mc_wait_process = 1,   //  商家：需处理
    eoos_mc_pending = 2,        //  商家：进行中
    eoos_mc_done = 3,           //  商家：已结束（已完成+已取消）
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
 *  更新订单类型。
 */
typedef enum EOtcOrderUpdateType
{
    //  用户
    eoout_to_paied = 1,             //  买单：确认付款
    eoout_to_cancel = 2,            //  买单：取消订单
    eoout_to_refunded_confirm = 3,  //  买单：商家退款&用户确认&取消订单
    eoout_to_transferred = 4,       //  卖单：用户确认转币
    eoout_to_received_money = 5,    //  卖单：确认收款 TODO:2.9 不确定
    
    //  商家
    eoout_to_mc_received_money = 1, //  用户购买：放行（已收款）
    eoout_to_mc_cancel = 2,         //  用户购买：无法接单，商家退款。
    eoout_to_mc_paied = 3,          //  用户卖单：商家已付款
    eoout_to_mc_return = 4,         //  用户卖单：无法接单，退币。
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
    //  用户
    eooot_transfer = 0,                 //  卖单：立即转币
    eooot_contact_customer_service,     //  卖单：联系客服
    eooot_confirm_received_money,       //  卖单：确认收款（放行资产给商家）
    
    eooot_cancel_order,                 //  买单：取消订单
    eooot_confirm_paid,                 //  买单：我已付款成功
    eooot_confirm_received_refunded,    //  买单：确认收到商家退款 & 取消订单
    
    //  商家
    eooot_mc_cancel_sell_order,         //  用户卖单：无法接单（退币、需要签名）
    eooot_mc_confirm_paid,              //  用户卖单：我已付款成功
    eooot_mc_cancel_buy_order,          //  用户买单：无法接单
    eooot_mc_confirm_received_money,    //  用户买单：确认收款（放行、需要签名）
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

/*
 *  商家：状态
 */
typedef enum EOtcMcStatus
{
    eoms_default = 0,
    eoms_not_active = 0,                //  未激活
    eoms_activated = 1,                 //  已激活
    eoms_activat_cancelled = 2,         //  取消激活
    eoms_freezed = 3,                   //  冻结
} EOtcMcStatus;

@class VCBase;

@interface OtcManager : NSObject

@property (nonatomic, strong) NSDictionary* server_config;  //  服务器配置
@property (nonatomic, strong) NSArray* asset_list_digital;  //  支持的数字资产列表

+ (OtcManager*)sharedOtcManager;

/*
 *  (public) 是否是有效的手机号初步验证。
 */
+ (BOOL)checkIsValidPhoneNumber:(NSString*)str_phone_num;

/*
 *  (public) 是否是有效的中国身份证号。
 */
+ (BOOL)checkIsValidChineseCardNo:(NSString*)str_card_no;

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
+ (NSDictionary*)auxGenOtcOrderStatusAndActions:(id)order user_type:(EOtcUserType)user_type;

/*
 *  (public) 当前账号名
 */
- (NSString*)getCurrentBtsAccount;

/*
 *  (public) 获取当前法币信息
 */
- (NSDictionary*)getFiatCnyInfo;

/*
 *  (public) 获取缓存的商家信息（可能为nil）
 */
- (NSDictionary*)getCacheMerchantDetail;

/*
 *  (public) 是否支持指定资产判断
 */
- (BOOL)isSupportDigital:(NSString*)asset_name;

/*
 *  (public) 获取资产信息。OTC运营方配置的，非链上数据。
 */
- (NSDictionary*)getAssetInfo:(NSString*)asset_name;

/*
 *  (public) 查询动态配置信息
 */
- (WsPromise*)queryConfig;

/*
 *  (public) 跳转到客服支持页面
 */
- (void)gotoSupportPage:(VCBase*)owner;
- (void)gotoUrlPages:(VCBase*)owner pagename:(NSString*)pagename;

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
          legalCurrencySymbol:(NSString*)legalCurrencySymbol
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
- (WsPromise*)queryReceiveMethods:(NSString*)bts_account_name;
- (WsPromise*)addPaymentMethods:(id)args;
- (WsPromise*)delPaymentMethods:(NSString*)bts_account_name pmid:(id)pmid;
- (WsPromise*)editPaymentMethods:(NSString*)bts_account_name new_status:(EOtcPaymentMethodStatus)new_status pmid:(id)pmid;

///*
// *  (public) 上传二维码图片。
// */
//- (WsPromise*)uploadQrCode:(NSString*)bts_account_name filename:(NSString*)filename data:(NSData*)data;
//
///*
// *  (public) 获取二维码图片流。
// */
//- (WsPromise*)queryQrCode:(NSString*)bts_account_name filename:(NSString*)filename;

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
 *  (public) API - 发送短信
 *  认证：TOKEN 认证
 */
- (WsPromise*)sendSmsCode:(NSString*)bts_account_name phone:(NSString*)phone_number type:(EOtcSmsType)type;

/*
 *  (public) 登录。部分API接口需要传递登录过的token字段。
 */
- (WsPromise*)login:(NSString*)bts_account_name;

#pragma mark- for merchant

- (void)gotoOtcMerchantHome:(VCBase*)owner;

///*
// *  (public) API - 商家申请进度查询
// */
//- (WsPromise*)merchantProgress:(NSString*)bts_account_name;

/*
 *  (public) API - 商家制度查询
 *  认证：无
 */
- (WsPromise*)merchantPolicy:(NSString*)bts_account_name;

/*
 *  (public) API - 商家激活
 *  认证：SIGN 方式
 */
- (WsPromise*)merchantActive:(NSString*)bts_account_name;

/*
 *  (public) API - 商家申请
 *  认证：SIGN 方式
 */
- (WsPromise*)merchantApply:(NSString*)bts_account_name bakAccount:(NSString*)bakAccount nickName:(NSString*)nickName;

/*
 *  (public) API - 商家详情查询
 *  认证：无
 */
- (WsPromise*)merchantDetail:(NSString*)bts_account_name skip_cache:(BOOL)skip_cache;

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
 *  (public) API - 划转商家资产到个人账号
 *  认证：SIGN 方式
 */
- (WsPromise*)queryMerchantAssetExport:(NSString*)bts_account_name signatureTx:(id)signatureTx;

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
                              aliPaySwitch:(id)aliPaySwitch
                         bankcardPaySwitch:(id)bankcardPaySwitch;

/*
 *  (public) API - 更新商家订单
 *  认证：SIGN 方式
 */
- (WsPromise*)updateMerchantOrder:(NSString*)bts_account_name
                         order_id:(NSString*)order_id
                       payAccount:(NSString*)payAccount
                       payChannel:(id)payChannel
                             type:(EOtcOrderUpdateType)type
                      signatureTx:(id)signatureTx;

/*
 *  (public) API - 查询商家memokey
 *  认证：SIGN 方式
 */
- (WsPromise*)queryMerchantMemoKey:(NSString*)bts_account_name;

/*
 *  (public) API - 商家创建广告（不上架、仅保存）
 *  认证：SIGN 方式
 */
- (WsPromise*)merchantCreateAd:(id)args;

/*
 *  (public) API - 商家更新并上架广告
 *  认证：SIGN 方式
 */
- (WsPromise*)merchantUpdateAd:(id)args;

/*
 *  (public) API - 商家重新上架广告
 *  认证：SIGN 方式
 */
- (WsPromise*)merchantReUpAd:(NSString*)bts_account_name ad_id:(NSString*)ad_id;

/*
 *  (public) API - 商家下架广告
 *  认证：SIGN 方式
 */
- (WsPromise*)merchantDownAd:(NSString*)bts_account_name ad_id:(NSString*)ad_id;

/*
 *  (public) API - 商家删除广告
 *  认证：SIGN 方式
 */
- (WsPromise*)merchantDeleteAd:(NSString*)bts_account_name ad_id:(NSString*)ad_id;

@end
