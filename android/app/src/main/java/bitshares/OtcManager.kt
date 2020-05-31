package bitshares

import android.app.Activity
import android.content.Context
import com.btsplusplus.fowallet.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class OtcManager {

    /**
     *  入口类型
     */
    enum class EOtcEntryType(val value: Int) {
        eoet_enabled(1),       //  启用。不需要msg。
        eoet_disabled(2),      //  禁用。可见，不可进入。提示msg。
        eoet_gone(3)           //  不可见。不需要msg。
    }

    /**
     * API认证方式
     */
    enum class EOtcAuthFlag(val value: Int) {
        eoaf_none(0),                   //  无需认证
        eoaf_sign(1),                   //  Active私钥签名认证
        eoaf_token(2)                   //  Token认证
    }

    /**
     * 错误码
     */
    enum class EOtcErrorCode(val value: Int) {
        eoerr_ok(0),                                   //  正常
        eoerr_system(1),                               //  系统错误
        eoerr_internal(1001),                          //  内部错误
        eoerr_miss_param(1002),                        //  参数错误
        eoerr_miss_db(1003),                           //  数据库错误
        eoerr_rpc_error(1004),                         //  RPC错误
        eoerr_id_alloc(1005),                          //  ID分配错误
        eoerr_system_close(1006),                      //  系统关闭
        eoerr_system_config_missing(1007),             //  缺少配置信息
        eoerr_miss_io(1008),                           //  IO错误
        eoerr_req_limit(1009),                         //  请求错误限制
        eoerr_address_query(1010),                     //  查询地址错误
        eoerr_sign_blank(1011),                        //  签名为空
        eoerr_too_often(1012),                         //  ※ 请求太频繁
        eoerr_sign_error(1013),                        //  签名错误
        eoerr_request_expired(1014),                   //  请求已经过期

        //  用户部分
        eoerr_user_not_exist(2001),                    //  用户不存在
        eoerr_user_frozen(2002),                       //  ※ 账号已被冻结
        eoerr_user_idcard_not_verify(2003),            //  ※ 身份未验证
        eoerr_user_idcard_verifyed(2004),              //  身份已验证，不用重复验证。
        eoerr_user_idcard_verify_failed(2005),         //  ※ 身份认证失败。
        eoerr_user_idcard_bind_other_account(2006),    //  ※ 身份已绑定其他BTS账户
        eoerr_user_change_same_phone(2007),            //  用户替换相同的手机号码
        eoerr_user_sms_type_failed(2008),              //  无法获取短信模版
        eoerr_user_account_not_exist(2009),            //  BTS账号不存在
        eoerr_user_account_not_empty(2010),            //  BTS账号不为空
        eoerr_user_account_not_login(2011),            //  ※ BTS账号未登录

        //  商家部分
        eoerr_merchant_not_actived(3001),              //  商家未激活
        eoerr_merchant_not_exist(3002),                //  商家不存在
        eoerr_bts_account_isnt_merchant(3003),         //  BTS账号暂不是商家
        eoerr_bak_account_is_merchant(3004),           //  备用BTS账号已经是商家了
        eoerr_nickname_already_exist(3005),            //  商家昵称被占用
        eoerr_insufficient_conditions(3006),           //  不符合申请条件
        eoerr_unapplied_merchant(3007),                //  未申请的商家
        eoerr_insufficient_margin(3008),               //  保证金不足

        //  广告部分
        eoerr_ad_existed_ad(4001),                     //  ※ 已存在相同的广告
        eoerr_ad_info(4002),                           //  广告信息错误
        eoerr_ad_price_changed(4003),                  //  广告价格变化了
        eoerr_ad_price_lock_expired(4004),             //  ※ 广告价格锁定已过期
        eoerr_ad_price_not_match(4005),                //  价格不匹配
        eoerr_ad_exist_ing_order(4006),                //  ※ 广告存在进行中的订单
        eoerr_ad_less_than_lowest_num(4007),           //  ※ 参数错误：小于最低限额
        eoerr_ad_more_than_useable_num(4008),          //  ※ 参数错误：商家库存（余额）不足
        eoerr_ad_status_not_valid(4009),               //  无效广告（广告已下架等
        eoerr_ad_price_not_equal_zero(4010),           //  广告价格非零
        eoerr_ad_more_than_highest_num(4011),          //  ※ 参数错误：超过最大限额

        //  订单相关
        eoerr_order_cancel_to_go_online(5001),         //  ※ 取消订单数量达到上限
        eoerr_order_business_type_error(5002),         //  业务类型错误
        eoerr_order_more_than_useable_num(5003),       //  ※ 超过广告可交易数量
        eoerr_merchant_free(5004),                     //  ※ BTS手续费余额不足，最低50。
        eoerr_order_in_progress_online(5005),          //  ※ 进行中的订单达到上限
        eoerr_asset_not_exist(5006),                   //  资产不存在
        eoerr_amount_to_large(5007),                   //  ※ 订单金额太大
        eoerr_amount_to_small(5008),                   //  ※ 订单金额太小
        eoerr_error_order(5009),                       //  订单不存在or状态错误
        eoerr_order_payment_methods(5010),             //  商家广告缺少付款方式
        eoerr_order_no_payment(5011),                  //  ※ 未添加付款方式
        eoerr_order_not_exist(5012),                   //  订单不存在

        //  短信相关
        eoerr_sms_upper_limit(6001),                   //  ※ 短信验证码条数超过限制
        eoerr_sms_code_wrong(6002),                    //  ※ 验证码不正确或已过期
        eoerr_sms_code_exist(6003),                    //  ※ 请不要重复发送短信验证码
        eoerr_sms_template_not_find_key(6004),         //  解析SMS模版错误-找不到需要替换到密钥

        //  文件相关
        eoerr_file_blank(7001),                        //  文件为空
        eoerr_file_not_upload(7002),                   //  文件未上传
        eoerr_file_format(7003),                       //  文件格式错误
        eoerr_file_too_large(7004),                    //  文件过大
        eoerr_file_type(7005),                         //  文件类型错误
        eoerr_file_upload_too_often(7006),             //  文件上传太频繁

        //  付款方式相关
        eoerr_pay_method(8001),                        //  付款方式不正确
        eoerr_bankcard_blank(8002),                    //  银行卡号不能为空
        eoerr_bankcard_reserved_phone(8003),           //  预留手机号不能为空
        eoerr_bankcard_type_blank(8004),               //  需要银行卡类型
        eoerr_bankcard_type(8005),                     //  银行卡类型不正确
        eoerr_pay_account_blank(8006),                 //  付款账号为空
        eoerr_bankcard_verify(8007),                   //  ※ 银行卡四元素验证失败
        eoerr_receive_method_exist(8009),              //  付款方式已经存在
        eoerr_no_payment_account(8010),                //  请添加一个付款账号

        //  juhe
        eoerr_api_call(9001),                          //  调用API异常
    }

    /**
     * 场外交易用户类型
     */
    enum class EOtcUserType(val value: Int) {
        eout_normal_user(0),   //  普通用户
        eout_merchant(1)           //  商家
    }

    /**
     *  资产类型
     */
    enum class EOtcAssetType(val value: Int) {
        eoat_fiat(1),          //  法币
        eoat_digital(2)        //  数字货币
    }

    /**
     *  商家广告定价类型
     */
    enum class EOtcPriceType(val value: Int) {
        eopt_price_fixed(1),   //  固定价格
    }

    /**
     *  场外交易账号状态
     */
    enum class EOtcUserStatus(val value: Int) {
        eous_default(0),       //  默认值（初始化时的值）
        eous_normal(1),            //  正常
        eous_freeze(2),            //  冻结中
    }

    /**
     *  场外交易身份认证状态
     */
    enum class EOtcUserIdVerifyStatus(val value: Int) {
        eovs_none(0),          //  未认证
        eovs_kyc1(1),              //  1级认证
        eovs_kyc2(2),              //  2级认证
        eovs_kyc3(3),              //  3级认证
    }

    /**
     *  场外交易收款方式类型
     */
    enum class EOtcPaymentMethodType(val value: Int) {
        eopmt_alipay(1),       //  支付宝
        eopmt_bankcard(2),         //  银行卡
        eopmt_wechatpay(3)         //  微信
    }

    /**
     *  场外交易收款方式状态
     */
    enum class EOtcPaymentMethodStatus(val value: Int) {
        eopms_enable(1),       //  已开启
        eopms_disable(2)           //  已禁用
    }

    /**
     *  商家广告类型
     */
    enum class EOtcAdType(val value: Int) {
        eoadt_all(0),                          //  所有广告

        eoadt_merchant_sell(1),                //  商家出售（用户购买）
        eoadt_merchant_buy(2),                 //  商家购买（用户出售）

        eoadt_user_sell(eoadt_merchant_buy.value),   //  用户出售（商家购买）
        eoadt_user_buy(eoadt_merchant_sell.value)    //  用户购买（商家出售）
    }

    /**
     *  用户订单类型
     */
    enum class EOtcOrderType(val value: Int) {
        eoot_query_all(0),     //  查询参数 - 全部
        eoot_query_sell(1),    //  查询参数 - 出售
        eoot_query_buy(2),     //  查询参数 - 购买
        eoot_data_sell(2),     //  返回类型 - 出售
        eoot_data_buy(1),      //  返回类型 - 购买
    }

    /**
     *  用户订单查询状态 TODO:2.9 申诉中哪些状态呢？
     */
    enum class EOtcOrderStatus(val value: Int) {
        eoos_all(0),               //  用户和商家都是：查询全部

        eoos_pending(1),           //  用户：查询进行中
        eoos_completed(2),         //  用户：查询已完成
        eoos_cancelled(3),         //  用户：查询已取消

        eoos_mc_wait_process(1),   //  商家：需处理
        eoos_mc_pending(2),        //  商家：进行中
        eoos_mc_done(3),           //  商家：已结束（已完成+已取消）
    }

    /**
     *  用户订单进度状态，数据库 status 字段。
     */
    enum class EOtcOrderProgressStatus(val value: Int) {
        eoops_new(1),                  //  订单已创建
        eoops_already_paid(2),         //  已付款
        eoops_already_transferred(3),  //  已转币
        eoops_already_confirmed(4),    //  区块已确认 TODO:2.9 确认中还是已确认？待审核，描述也需要对应调整。
        eoops_refunded(5),             //  已退款
        eoops_refund_failed(6),        //  退款失败
        eoops_completed(7),            //  交易成功
        eoops_cancelled(8),            //  失败订单（包括取消订单）
        eoops_chain_failed(9),         //  区块操作失败（异常了）
        eoops_return_assets(10),       //  退币中
    }

    /**
     *  更新订单类型。
     */
    enum class EOtcOrderUpdateType(val value: Int) {
        //  用户
        eoout_to_paied(1),             //  买单：确认付款
        eoout_to_cancel(2),            //  买单：取消订单
        eoout_to_refunded_confirm(3),  //  买单：商家退款&用户确认&取消订单
        eoout_to_transferred(4),       //  卖单：用户确认转币
        eoout_to_received_money(5),    //  卖单：确认收款 TODO:2.9 不确定

        //  商家
        eoout_to_mc_received_money(1), //  用户购买：放行（已收款）
        eoout_to_mc_cancel(2),         //  用户购买：无法接单，商家退款。
        eoout_to_mc_paied(3),          //  用户卖单：商家已付款
        eoout_to_mc_return(4),         //  用户卖单：无法接单，退币。
    }

    /**
     *  商家广告状态
     */
    enum class EOtcAdStatus(val value: Int) {
        eoads_online(1),       //  上架中
        eoads_offline(2),      //  下架中
        eoads_deleted(3),      //  删除
    }

    /**
     *  验证码业务类型
     */
    enum class EOtcSmsType(val value: Int) {
        eost_id_verify(1),     //  身份认证
        eost_change_phone(2),      //  更换手机号
        eost_new_order_notify(3),  //  新订单通知
    }

    /**
     *  用户订单对应的各种可操作事件类型。仅客户端用，服务器不存在。
     */
    enum class EOtcOrderOperationType(val value: Int) {
        //  用户
        eooot_transfer(0),                 //  卖单：立即转币
        eooot_contact_customer_service(1),     //  卖单：联系客服
        eooot_confirm_received_money(2),       //  卖单：确认收款（放行资产给商家）

        eooot_cancel_order(3),                 //  买单：取消订单
        eooot_confirm_paid(4),                 //  买单：我已付款成功
        eooot_confirm_received_refunded(5),    //  买单：确认收到商家退款 & 取消订单

        //  商家
        eooot_mc_cancel_sell_order(6),         //  用户卖单：无法接单（退币、需要签名）
        eooot_mc_confirm_paid(7),              //  用户卖单：我已付款成功
        eooot_mc_cancel_buy_order(8),          //  用户买单：无法接单
        eooot_mc_confirm_received_money(9),    //  用户买单：确认收款（放行、需要签名）
    }

    /**
     *  商家：申请进度
     */
    enum class EOtcMcProgress(val value: Int) {
        eomp_default(0),                    //  未申请：默认值
        eomp_applying(1),                   //  申请中
        eomp_approved(2),                   //  已同意
        eomp_rejected(3),                   //  已拒绝
        eomp_activated(4),                  //  已激活
    }

    /**
     *  商家：状态
     */
    enum class EOtcMcStatus(val value: Int) {
        eoms_default(0),
        eoms_not_active(0),                //  未激活
        eoms_activated(1),                 //  已激活
        eoms_activat_cancelled(2),         //  取消激活
        eoms_freezed(3),                   //  冻结
    }

    companion object {

        private var _spInstanceAppCacheMgr: OtcManager? = null
        fun sharedOtcManager(): OtcManager {
            if (_spInstanceAppCacheMgr == null) {
                _spInstanceAppCacheMgr = OtcManager()
            }
            return _spInstanceAppCacheMgr!!
        }

        /**
         *  (public) 是否是有效的手机号初步验证。
         */
        fun checkIsValidPhoneNumber(str_phone_num: String?): Boolean {
            if (str_phone_num == null || str_phone_num.isEmpty()) {
                return false
            }
            //  TODO:2.9 是否需要这个check？
            if (str_phone_num.length != 11) {
                return false
            }
            return true
        }


        /**
         *  (public) 是否是有效的中国身份证号。
         */
        fun checkIsValidChineseCardNo(str_card_no: String?): Boolean {
            if (str_card_no == null || str_card_no.isEmpty()) {
                return false
            }
            if (str_card_no.length != 18) {
                return false
            }
            //  验证身份证校验位是否正确

            //  TODO:2.9 待完成

            //            NSString* part_one = [str_card_no substringToIndex:17];
            //            //  REMARK：最后的X强制转换为大写字母。
            //            unichar verify = [[[str_card_no substringFromIndex:17] uppercaseString] characterAtIndex:0];
            //            if (![OrgUtils isFullDigital:part_one]) {
            //                return NO;
            //            }
            //            NSInteger muls[] = {7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2};
            //            assert(sizeof(muls) / sizeof(muls[0]) == 17);
            //            unichar mods[] = {'1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2'};
            //
            //            NSInteger sum = 0;
            //            for (NSInteger i = 0; i < part_one.length; ++i) {
            //            sum += [[part_one substringWithRange:NSMakeRange(i, 1)] integerValue] * muls[i];
            //        }
            //            NSInteger mod = sum % 11;
            //            if (mods[mod] != verify) {
            //                return NO;
            //            }
            return true
        }


        /**
         *  (public) 解析 OTC 服务器返回的时间字符串，格式：2019-11-26T13:29:51.000+0000。
         */
        fun parseTime(time: String): Long {
            val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
            f.timeZone = java.util.TimeZone.getTimeZone("UTC")
            val d = f.parse(time)
            return (d.time / 1000.0).toLong()
        }

        /**
         *  格式化：场外交易订单列表日期显示格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
         */
        fun fmtOrderListTime(time: String): String {
            val ts = parseTime(time)
            val d = Date(ts * 1000)
            val f = SimpleDateFormat("MM-dd HH:mm")
            return f.format(d)
        }

        /**
         *  格式化：场外交易订单详情日期显示格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
         */
        fun fmtOrderDetailTime(time: String): String {
            val ts = parseTime(time)
            val d = Date(ts * 1000)
            val f = SimpleDateFormat("yyyy-MM-dd HH:mm:ss")
            return f.format(d)
        }

        /**
         *  格式化：格式化商家加入日期格式。REMARK：以当前时区格式化，北京时间当前时区会+8。
         */
        fun fmtMerchantTime(time: String): String {
            val ts = parseTime(time)
            val d = Date(ts * 1000)
            val f = SimpleDateFormat("yyyy-MM-dd")
            return f.format(d)
        }

        /**
         *  格式化：场外交易订单倒计时时间。
         */
        fun fmtPaymentExpireTime(left_ts: Long): String {
            assert(left_ts > 0)
            val min = left_ts / 60
            val sec = left_ts % 60
            return String.format("%02d:%02d", min, sec)
        }

        /**
         *  (public) 辅助 - 获取收款方式名字图标等。
         */
        fun auxGenPaymentMethodInfos(ctx: Context, account: String, type: Int, bankname: String?): JSONObject {
            var name: String? = null
            var icon: Int? = null
            val short_account = account

            when (type) {
                EOtcPaymentMethodType.eopmt_alipay.value -> {
                    name = R.string.kOtcAdPmNameAlipay.xmlstring(ctx)
                    icon = R.drawable.icon_pm_alipay
                }
                EOtcPaymentMethodType.eopmt_bankcard.value -> {
                    name = R.string.kOtcAdPmNameBankCard.xmlstring(ctx)
                    icon = R.drawable.icon_pm_bankcard

                    name = bankname
                    if (name == null || name.isEmpty()) {
                        name = R.string.kOtcAdPmNameBankCard.xmlstring(ctx)
                    }
                    //  TODO:2.9 未完成
//                    NSString* card_no = [account stringByReplacingOccurrencesOfString:@" " withString:@""];
//                    short_account = [card_no substringFromIndex:MAX((NSInteger)card_no.length - 4, 0)];
                }
                EOtcPaymentMethodType.eopmt_wechatpay.value -> {
                    name = R.string.kOtcAdPmNameWechatPay.xmlstring(ctx)
                    icon = R.drawable.icon_pm_wechat
                }
            }

            if (name == null) {
                name = String.format(R.string.kOtcAdPmUnknownType.xmlstring(ctx), type.toString())
            }

            if (icon == null) {
                //  TODO:2.9 default  icon
                icon = R.drawable.icon_pm_bankcard
            }

            return JSONObject().apply {
                put("name", name)
                put("icon", icon)
                put("name_with_short_account", "$name($short_account)")
            }
        }

        /**
         *  (private) 场外交易订单流转各种状态信息：用户端看的情况。
         */
        private fun _auxGenOtcOrderStatusAndActions_UserSide(ctx: Context, order: JSONObject): JSONObject {
            val bUserSell = order.getInt("type") == EOtcOrderType.eoot_data_sell.value
            val status = order.getInt("status")
            var status_main: String? = null
            var status_desc: String? = null
            val actions = JSONArray()
            var showRemark = false
            var pending = true

            if (bUserSell) {
                //  -- 用户卖币提现
                when (status) {
                    EOtcOrderProgressStatus.eoops_new.value -> {
                        status_main = R.string.kOtcOsUser_sell_new_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_sell_new_desc.xmlstring(ctx)
                        //  按钮：联系客服 + 立即转币
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_contact_customer_service)
                            put("color", R.color.theme01_textColorGray)
                        })
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_transfer)
                            put("color", R.color.theme01_textColorHighlight)
                        })
                    }
                    EOtcOrderProgressStatus.eoops_already_transferred.value -> {
                        status_main = R.string.kOtcOsUser_sell_transferred_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_sell_transferred_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_already_confirmed.value -> {
                        status_main = R.string.kOtcOsUser_sell_confirmed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_sell_confirmed_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_already_paid.value -> {
                        status_main = R.string.kOtcOsUser_sell_paid_main.xmlstring(ctx) // 商家已付款(请放行) 申诉 + 确认收款(放行操作需二次确认)
                        status_desc = R.string.kOtcOsUser_sell_paid_desc.xmlstring(ctx)
                        //  按钮：联系客服 + 放行XXX资产
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_contact_customer_service)
                            put("color", R.color.theme01_textColorGray)
                        })
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_confirm_received_money)
                            put("color", R.color.theme01_textColorHighlight)
                        })
                    }
                    EOtcOrderProgressStatus.eoops_completed.value -> {
                        status_main = R.string.kOtcOsUser_sell_completed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_sell_completed_desc.xmlstring(ctx)
                        pending = false
                    }
                    EOtcOrderProgressStatus.eoops_chain_failed.value -> {
                        status_main = R.string.kOtcOsUser_sell_chain_failed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_sell_chain_failed_desc.xmlstring(ctx)
                        //  按钮：联系客服
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_contact_customer_service)
                            put("color", R.color.theme01_textColorGray)
                        })
                    }
                    EOtcOrderProgressStatus.eoops_return_assets.value -> {
                        status_main = R.string.kOtcOsUser_sell_return_assets_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_sell_return_assets_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_cancelled.value -> {
                        status_main = R.string.kOtcOsUser_sell_cancelled_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_sell_cancelled_desc.xmlstring(ctx)
                        pending = false
                    }
                }   //  end when
            } else {
                //  -- 用户充值买币
                when (status) {
                    EOtcOrderProgressStatus.eoops_new.value -> {
                        status_main = R.string.kOtcOsUser_buy_new_main.xmlstring(ctx)       // 已下单(待付款)     取消 + 确认付款
                        status_desc = R.string.kOtcOsUser_buy_new_desc.xmlstring(ctx)
                        showRemark = true
                        //  按钮：取消订单 + 确认付款
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_cancel_order)
                            put("color", R.color.theme01_textColorGray)
                        })
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_confirm_paid)
                            put("color", R.color.theme01_textColorHighlight)
                        })
                    }
                    EOtcOrderProgressStatus.eoops_already_paid.value -> {
                        status_main = R.string.kOtcOsUser_buy_paid_main.xmlstring(ctx)       // 已付款(待收币)
                        status_desc = R.string.kOtcOsUser_buy_paid_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_already_transferred.value -> {
                        status_main = R.string.kOtcOsUser_buy_transferred_main.xmlstring(ctx)       //  已转币
                        status_desc = R.string.kOtcOsUser_buy_transferred_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_already_confirmed.value -> {
                        status_main = R.string.kOtcOsUser_buy_confirmed_main.xmlstring(ctx)       //  已收币 REMARK：这是中间状态，会自动跳转到已完成。
                        status_desc = R.string.kOtcOsUser_buy_confirmed_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_completed.value -> {
                        status_main = R.string.kOtcOsUser_buy_completed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_buy_completed_desc.xmlstring(ctx)
                        pending = false
                    }
                    EOtcOrderProgressStatus.eoops_refunded.value -> {
                        status_main = R.string.kOtcOsUser_buy_refunded_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_buy_refunded_desc.xmlstring(ctx)
                        //  按钮：联系客服 + 我已收到退款（取消订单）
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_contact_customer_service)
                            put("color", R.color.theme01_textColorGray)
                        })
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_confirm_received_refunded)
                            put("color", R.color.theme01_textColorHighlight)
                        })
                    }
                    EOtcOrderProgressStatus.eoops_chain_failed.value -> {
                        status_main = R.string.kOtcOsUser_buy_chain_failed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_buy_chain_failed_desc.xmlstring(ctx)
                        //  按钮：联系客服
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_contact_customer_service)
                            put("color", R.color.theme01_textColorGray)
                        })
                    }
                    EOtcOrderProgressStatus.eoops_cancelled.value -> {
                        status_main = R.string.kOtcOsUser_buy_cancelled_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsUser_buy_cancelled_desc.xmlstring(ctx)
                        pending = false
                    }
                }   //  end when
            }

            if (status_main == null) {
                status_main = String.format(R.string.kOtcOsUser_unknown_main.xmlstring(ctx), status.toString())
            }
            if (status_desc == null) {
                status_desc = String.format(R.string.kOtcOsUser_unknown_desc.xmlstring(ctx), status.toString())
            }

            //  返回数据
            return JSONObject().apply {
                put("main", status_main)
                put("desc", status_desc)
                put("actions", actions)
                put("sell", bUserSell)
                put("phone", order.optString("phone"))
                put("show_remark", showRemark)
                put("pending", pending)
            }
        }

        /**
         *  (private) 场外交易订单流转各种状态信息：商家端看的情况。
         */
        private fun _auxGenOtcOrderStatusAndActions_MerchantSide(ctx: Context, order: JSONObject): JSONObject {
            val bUserSell = order.getInt("type") == EOtcOrderType.eoot_data_sell.value
            val status = order.getInt("status")
            var status_main: String? = null
            var status_desc: String? = null
            val actions = JSONArray()
            val showRemark = false
            var pending = true

            if (bUserSell) {
                //  -- 用户卖币提现
                when (status) {
                    EOtcOrderProgressStatus.eoops_new.value -> {
                        status_main = R.string.kOtcOsMerchant_sell_new_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_sell_new_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_already_transferred.value -> {
                        status_main = R.string.kOtcOsMerchant_sell_transferred_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_sell_transferred_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_already_confirmed.value -> {
                        status_main = R.string.kOtcOsMerchant_sell_confirmed_main.xmlstring(ctx)               //  区块已确认(请付款) 【商家】
                        status_desc = R.string.kOtcOsMerchant_sell_confirmed_desc.xmlstring(ctx)
                        //  按钮：无法接(卖)单 + 确认付款
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_mc_cancel_sell_order)
                            put("color", R.color.theme01_textColorGray)
                        })
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_mc_confirm_paid)
                            put("color", R.color.theme01_textColorHighlight)
                        })
                    }
                    EOtcOrderProgressStatus.eoops_already_paid.value -> {
                        status_main = R.string.kOtcOsMerchant_sell_paid_main.xmlstring(ctx)              // 商家已付款（等待用户确认放行）
                        status_desc = R.string.kOtcOsMerchant_sell_paid_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_completed.value -> {
                        status_main = R.string.kOtcOsMerchant_sell_completed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_sell_completed_desc.xmlstring(ctx)
                        pending = false
                    }
                    EOtcOrderProgressStatus.eoops_chain_failed.value -> {
                        status_main = R.string.kOtcOsMerchant_sell_chain_failed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_sell_chain_failed_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_return_assets.value -> {
                        status_main = R.string.kOtcOsMerchant_sell_return_assets_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_sell_return_assets_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_cancelled.value -> {
                        status_main = R.string.kOtcOsMerchant_sell_cancelled_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_sell_cancelled_desc.xmlstring(ctx)
                        pending = false
                    }
                }   //  end when
            } else {
                //  -- 用户充值买币
                when (status) {
                    EOtcOrderProgressStatus.eoops_new.value -> {
                        status_main = R.string.kOtcOsMerchant_buy_new_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_buy_new_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_already_paid.value -> {
                        //  DONE!!!
                        status_main = R.string.kOtcOsMerchant_buy_paid_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_buy_paid_desc.xmlstring(ctx)
                        //  按钮：无法接(买)单 + 放行资产
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_mc_cancel_buy_order)
                            put("color", R.color.theme01_textColorGray)
                        })
                        actions.put(JSONObject().apply {
                            put("type", EOtcOrderOperationType.eooot_mc_confirm_received_money)
                            put("color", R.color.theme01_textColorHighlight)
                        })
                    }
                    EOtcOrderProgressStatus.eoops_already_transferred.value -> {
                        status_main = R.string.kOtcOsMerchant_buy_transferred_main.xmlstring(ctx)      //  已转币
                        status_desc = R.string.kOtcOsMerchant_buy_transferred_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_already_confirmed.value -> {
                        status_main = R.string.kOtcOsMerchant_buy_confirmed_main.xmlstring(ctx)      //  已收币 REMARK：这是中间状态，会自动跳转到已完成。
                        status_desc = R.string.kOtcOsMerchant_buy_confirmed_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_completed.value -> {
                        status_main = R.string.kOtcOsMerchant_buy_completed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_buy_completed_desc.xmlstring(ctx)
                        pending = false
                    }
                    EOtcOrderProgressStatus.eoops_refunded.value -> {
                        status_main = R.string.kOtcOsMerchant_buy_refunded_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_buy_refunded_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_chain_failed.value -> {
                        status_main = R.string.kOtcOsMerchant_buy_chain_failed_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_buy_chain_failed_desc.xmlstring(ctx)
                    }
                    EOtcOrderProgressStatus.eoops_cancelled.value -> {
                        status_main = R.string.kOtcOsMerchant_buy_cancelled_main.xmlstring(ctx)
                        status_desc = R.string.kOtcOsMerchant_buy_cancelled_desc.xmlstring(ctx)
                        pending = false
                    }
                }   //  end when
            }

            if (status_main == null) {
                status_main = String.format(R.string.kOtcOsMerchant_unknown_main.xmlstring(ctx), status.toString())
            }
            if (status_desc == null) {
                status_desc = String.format(R.string.kOtcOsMerchant_unknown_desc.xmlstring(ctx), status.toString())
            }

            //  返回数据
            return JSONObject().apply {
                put("main", status_main)
                put("desc", status_desc)
                put("actions", actions)
                put("sell", bUserSell)
                put("phone", order.optString("phone"))
                put("show_remark", showRemark)
                put("pending", pending)
            }
        }

        /**
         *  (public) 辅助 - 根据订单当前状态获取主状态、状态描述、以及可操作按钮等信息。
         */
        fun auxGenOtcOrderStatusAndActions(ctx: Context, order: JSONObject, user_type: EOtcUserType): JSONObject {
            return if (user_type == EOtcUserType.eout_normal_user) {
                _auxGenOtcOrderStatusAndActions_UserSide(ctx, order)
            } else {
                _auxGenOtcOrderStatusAndActions_MerchantSide(ctx, order)
            }
        }
    }

    var server_config: JSONObject? = null                   //  服务器配置
    private var _base_api = "http://otc-api.gdex.vip"       //  TODO:2.9 test url
    private var _fiat_cny_info: JSONObject? = null          //  法币信息 TODO:2.9 默认只支持一种
    private var _asset_list_digital: JSONArray? = null      //  支持的数字资产列表
    private var _cache_merchant_detail: JSONObject? = null  //  商家信息（如果进入场外交易使用缓存，进入商家每次都刷新。）

    fun asset_list_digital(): JSONArray {
        return _asset_list_digital!!
    }

    /**
     *  (public) 当前账号名
     */
    fun getCurrentBtsAccount(): String {
        assert(WalletManager.sharedWalletManager().isWalletExist())
        return WalletManager.sharedWalletManager().getWalletAccountName()!!
    }

    /**
     *  (public) 获取当前法币信息
     */
    fun getFiatCnyInfo(): JSONObject {
        if (_fiat_cny_info != null) {
            //{
            //    assetAlias = RMB;
            //    assetId = "";
            //    assetPrecision = 2;
            //    assetSymbol = CNY;
            //    legalCurrencySymbol = "\U00a5";
            //    type = 1;
            //}
            return JSONObject().apply {
                put("assetSymbol", _fiat_cny_info!!.getString("assetSymbol"))
                put("assetPrecision", _fiat_cny_info!!.getInt("assetPrecision"))
                put("legalCurrencySymbol", _fiat_cny_info!!.getString("legalCurrencySymbol"))
                put("type", _fiat_cny_info!!.get("type"))
                put("name", _fiat_cny_info!!.getString("assetAlias"))
            }
        } else {
            //  TODO:2.9 数据不存在时兼容
            return JSONObject().apply {
                put("assetSymbol", "CNY")
                put("assetPrecision", 2)
                put("legalCurrencySymbol", "¥")
                put("type", 1)
            }
        }
    }

    /**
     *  (public) 获取缓存的商家信息（可能为nil）
     */
    fun getCacheMerchantDetail(): JSONObject? {
        return _cache_merchant_detail
    }

    /**
     *  (public) 是否支持指定资产判断
     */
    fun isSupportDigital(asset_name: String): Boolean {
        if (_asset_list_digital != null && _asset_list_digital!!.length() > 0) {
            for (item in _asset_list_digital!!.forin<JSONObject>()) {
                if (item!!.getString("assetSymbol") == asset_name) {
                    return true
                }
            }
        }
        return false
    }

    /**
     *  (public) 获取资产信息。OTC运营方配置的，非链上数据。
     */
    fun getAssetInfo(asset_name: String): JSONObject {
        if (_asset_list_digital != null && _asset_list_digital!!.length() > 0) {
            for (item in _asset_list_digital!!.forin<JSONObject>()) {
                if (item!!.getString("assetSymbol") == asset_name) {
                    return item
                }
            }
        }
        assert(false)
        //  not reached
        return JSONObject()
    }


    /**
     *  (public) 查询动态配置信息
     */
    fun queryConfig(): Promise {
        val p = Promise()
        //  TODO:2.9 asste name encode
        ChainObjectManager.sharedChainObjectManager().queryAssetData("CCTEST").then {
            var config: JSONObject? = null
            val asset_data = it as? JSONObject
            if (asset_data != null) {
                val json = asset_data.getJSONObject("options").getString("description").to_json_object()
                val main = json?.optString("main", null)
                if (main != null && main.isNotEmpty() && main.length % 2 == 0) {
                    config = main.hexDecode().utf8String().to_json_object()
                }
            }
            if (config != null) {
                //  更新节点URL
                val api = config.optJSONObject("urls")?.optString("api", null)
                if (api != null && api.isNotEmpty()) {
                    _base_api = api.toString()
                }
                //  更新配置
                server_config = config
            }
            p.resolve(server_config)
            return@then null
        }.catch {
            //  查询失败，返回之前的数据。
            p.resolve(server_config)
        }
        return p
    }

    /**
     *  (public) 跳转到客服支持页面
     */
    fun gotoSupportPage(ctx: Activity) {
        gotoUrlPages(ctx, pagename = "support")
    }

    fun gotoUrlPages(ctx: Activity, pagename: String) {
        server_config?.let {
            var url = it.optJSONObject("urls")?.optString(pagename, null)
            assert(url != null)
            if (url != null) {
                url = String.format("%s?v=%s", url, Utils.now_ts().toString())
                ctx.goToWebView("", url)
            }
        }
    }

    /**
     *  (public) 转到OTC界面，会自动初始化必要信息。
     */
    fun gotoOtc(ctx: Activity, asset_name: String, ad_type: EOtcAdType) {
        val walletMgr = WalletManager.sharedWalletManager()
        assert(walletMgr.isWalletExist())

        if (WalletManager.isMultiSignPermission(walletMgr.getWalletAccountInfo()!!.getJSONObject("account").getJSONObject("active"))) {
            ctx.showToast(R.string.kOtcMgrNotSupportMultiSignAccount.xmlstring(ctx))
            return
        }

        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
        mask.show()

        val p1 = queryFiatAssetCNY()
        val p2 = queryAssetList(EOtcAssetType.eoat_digital)
        val p3 = merchantDetail(getCurrentBtsAccount(), false)
        Promise.all(p1, p2, p3).then {
            mask.dismiss()
            val data_array = it as? JSONArray
            val asset_data = data_array?.optJSONObject(1)
            //  获取数字货币信息
            _asset_list_digital = asset_data?.optJSONArray("data")
            if (_asset_list_digital == null || _asset_list_digital!!.length() <= 0) {
                ctx.showToast(R.string.kOtcMgrNoOpenAnyDigiAssets.xmlstring(ctx))
                return@then null
            }

            //  是否支持判断
            if (!isSupportDigital(asset_name)) {
                ctx.showToast(String.format(R.string.kOtcMgrNotSupportAsset.xmlstring(ctx), asset_name))
                return@then null
            }

            //  转到场外交易界面
            ctx.goTo(ActivityOtcMerchantList::class.java, true, args = JSONObject().apply {
                put("asset_name", asset_name)
                put("ad_type", ad_type)
            })
            return@then null
        }.catch { err ->
            mask.dismiss()
            showOtcError(ctx, err)
        }
    }

    private fun _guardUserIdVerified(ctx: Activity, prev_mask: ViewMask?, askForIdVerifyMsg: String?, first_request: Boolean, keep_mask: Boolean, verifyed_callback: (auth_info: JSONObject, mask: ViewMask?) -> Unit) {
        val mask = prev_mask
                ?: ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx).apply { show() }

        queryIdVerify(getCurrentBtsAccount()).then {
            val responsed = it as? JSONObject
            if (isIdVerifyed(responsed)) {
                if (keep_mask) {
                    verifyed_callback(responsed!!.getJSONObject("data"), mask)
                } else {
                    mask.dismiss()
                    verifyed_callback(responsed!!.getJSONObject("data"), null)
                }
            } else {
                mask.dismiss()
                //  未认证：询问认证 or 直接转认证界面
                if (askForIdVerifyMsg != null) {
                    ctx.alerShowMessageConfirm(R.string.kWarmTips.xmlstring(ctx), askForIdVerifyMsg).then {
                        if (it != null && it as Boolean) {
                            ctx.goTo(ActivityOtcUserAuth::class.java, true)
                        }
                        return@then null
                    }
                } else {
                    ctx.goTo(ActivityOtcUserAuth::class.java, true)
                }
            }
            return@then null
        }.catch { err ->
            if (first_request && isOtcUserNotLoginError(err)) {
                //  处理登录
                handleOtcUserLogin(ctx, mask) { new_mask ->
                    //  query id verify again
                    _guardUserIdVerified(ctx, new_mask, askForIdVerifyMsg, false, keep_mask, verifyed_callback)
                }
            } else {
                //  认证失败：直接显示错误信息，关闭mask。
                mask.dismiss()
                showOtcError(ctx, err)
            }
        }
    }

    /**
     *  (public) 确保已经进行认证认证。
     */
    fun guardUserIdVerified(ctx: Activity, askForIdVerifyMsg: String?, keep_mask: Boolean = false, verifyed_callback: (auth_info: JSONObject, mask: ViewMask?) -> Unit) {
        _guardUserIdVerified(ctx, null, askForIdVerifyMsg, true, keep_mask, verifyed_callback)
    }

    /**
     *  (private) 请求私钥授权登录。
     */
    private fun handleOtcUserLogin(ctx: Activity, prev_mask: ViewMask, login_callback: (ViewMask) -> Unit) {
        val currMask: ViewMask?
        val isLocked = WalletManager.sharedWalletManager().isLocked()
        if (isLocked) {
            prev_mask.dismiss()
            currMask = null
        } else {
            currMask = prev_mask
        }
        //  解锁之前需要关闭mask。
        ctx.guardWalletUnlocked(true) { unlocked ->
            if (unlocked) {
                //  如果之前的mask被关闭了，则这里重新创建。
                val mask = currMask
                        ?: ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx).apply { show() }
                val account_name = getCurrentBtsAccount()
                login(account_name).then {
                    val login_responsed = it as? JSONObject
                    val token = login_responsed?.optString("data", null)
                    if (token != null && token.isNotEmpty()) {
                        _saveUserTokenCookie(account_name, token)
                        //  把最新的mask返回，可能和之前已经不同了。
                        login_callback(mask)
                    } else {
                        showOtcError(ctx, null)
                    }
                    return@then null
                }.catch { err ->
                    mask.dismiss()
                    showOtcError(ctx, err)
                }
            }
        }
    }

    /**
     *  (public) 处理用户注销账号。需要清理token等信息。
     */
    fun processLogout() {
        if (WalletManager.sharedWalletManager().isWalletExist()) {
            _delUserTokenCookie(getCurrentBtsAccount())
        }
        //  清理商家信息
        _cache_merchant_detail = null
    }

    /**
     *  (public) 是否是指定错误判断。
     */
    fun isOtcError(error: Any?, check_errcode: EOtcErrorCode): Boolean {
        if (error != null && error is Promise.WsPromiseException) {
            val json = try {
                JSONObject(error.message.toString())
            } catch (e: Exception) {
                null
            }
            if (json != null) {
                val otcerror = json.optJSONObject("otcerror")
                if (otcerror != null) {
                    val errcode = otcerror.getInt("code")
                    if (errcode == check_errcode.value) {
                        return true
                    }
                }
            }
        }
        return false
    }

    /**
     *  (public) 是否是未登录错误判断。
     */
    fun isOtcUserNotLoginError(error: Any?): Boolean {
        if (error != null && error is Promise.WsPromiseException) {
            val json = try {
                JSONObject(error.message.toString())
            } catch (e: Exception) {
                null
            }
            if (json != null) {
                val otcerror = json.optJSONObject("otcerror")
                if (otcerror != null) {
                    val errcode = otcerror.getInt("code")
                    if (errcode == EOtcErrorCode.eoerr_user_account_not_login.value) {
                        return true
                    }
                }
            }
        }
        return false
    }

    /**
     *  (public) 显示OTC的错误信息。
     */
    fun showOtcError(ctx: Activity, error: Any?, not_login_callback: (() -> Unit)? = null) {
        var errmsg: String? = null
        if (error != null && error is Promise.WsPromiseException) {
            val json = try {
                JSONObject(error.message.toString())
            } catch (e: Exception) {
                error.message
            }
            if (json is JSONObject) {
                if (json.has("err_string_id")) {
                    errmsg = ctx.resources.getString(json.getInt("err_string_id"))
                } else {
                    val otcerror = json.optJSONObject("otcerror")
                    if (otcerror != null) {
                        //  异常中包含 otcerror 的情况
                        val errcode = otcerror.getInt("code")
                        if (errcode == EOtcErrorCode.eoerr_user_account_not_login.value && not_login_callback != null) {
                            not_login_callback()
                            return
                        } else {
                            //  REMARK：部分消息特化处理，如有需要可继续添加。
                            when (errcode) {
                                EOtcErrorCode.eoerr_too_often.value -> errmsg = R.string.kOtcMgrErrTooOften.xmlstring(ctx)
                                EOtcErrorCode.eoerr_user_frozen.value -> errmsg = R.string.kOtcMgrErrUserFrozen.xmlstring(ctx)
                                EOtcErrorCode.eoerr_user_idcard_not_verify.value -> errmsg = R.string.kOtcMgrErrUserIdCardNotVerify.xmlstring(ctx)
                                EOtcErrorCode.eoerr_user_idcard_verify_failed.value -> errmsg = R.string.kOtcMgrErrUserIdCardVerifyFailed.xmlstring(ctx)
                                EOtcErrorCode.eoerr_user_idcard_bind_other_account.value -> errmsg = R.string.kOtcMgrErrUserIdCardBindOtherBtsAccount.xmlstring(ctx)
                                EOtcErrorCode.eoerr_user_account_not_login.value -> errmsg = R.string.kOtcMgrErrNotLoginOrTokenIsEmpty.xmlstring(ctx)

                                EOtcErrorCode.eoerr_ad_existed_ad.value -> errmsg = R.string.kOtcMgrErrAdExistSameTypeAd.xmlstring(ctx)
                                EOtcErrorCode.eoerr_ad_price_lock_expired.value -> errmsg = R.string.kOtcMgrErrAdLockPriceExpired.xmlstring(ctx)
                                EOtcErrorCode.eoerr_ad_exist_ing_order.value -> errmsg = R.string.kOtcMgrErrAdExistPendingOrder.xmlstring(ctx)
                                EOtcErrorCode.eoerr_ad_less_than_lowest_num.value -> errmsg = R.string.kOtcMgrErrAdLessthanMinLimit.xmlstring(ctx)
                                EOtcErrorCode.eoerr_ad_more_than_useable_num.value -> errmsg = R.string.kOtcMgrErrAdMorethanUseableNum.xmlstring(ctx)
                                EOtcErrorCode.eoerr_ad_more_than_highest_num.value -> errmsg = R.string.kOtcMgrErrAdMorethanMaxLimit.xmlstring(ctx)

                                EOtcErrorCode.eoerr_order_cancel_to_go_online.value -> errmsg = R.string.kOtcMgrErrOrderCancelTooMuch.xmlstring(ctx)
                                EOtcErrorCode.eoerr_order_more_than_useable_num.value -> errmsg = R.string.kOtcMgrErrOrderMorethanUseableNum.xmlstring(ctx)
                                EOtcErrorCode.eoerr_merchant_free.value -> errmsg = R.string.kOtcMgrErrMerchantBtsFeeNotEnough.xmlstring(ctx)
                                EOtcErrorCode.eoerr_order_in_progress_online.value -> errmsg = R.string.kOtcMgrErrOrderExistTooMuchPendingOrder.xmlstring(ctx)
                                EOtcErrorCode.eoerr_amount_to_large.value -> errmsg = R.string.kOtcMgrErrOrderTotalTooLarge.xmlstring(ctx)
                                EOtcErrorCode.eoerr_amount_to_small.value -> errmsg = R.string.kOtcMgrErrOrderTotalTooSmall.xmlstring(ctx)
                                EOtcErrorCode.eoerr_order_no_payment.value -> errmsg = R.string.kOtcMgrErrOrderNoPaymentMethod.xmlstring(ctx)

                                EOtcErrorCode.eoerr_sms_upper_limit.value -> errmsg = R.string.kOtcMgrErrSmsSendLimit.xmlstring(ctx)
                                EOtcErrorCode.eoerr_sms_code_wrong.value -> errmsg = R.string.kOtcMgrErrSmsCodeWrong.xmlstring(ctx)
                                EOtcErrorCode.eoerr_sms_code_exist.value -> errmsg = R.string.kOtcMgrErrSmsCodeExist.xmlstring(ctx)

                                EOtcErrorCode.eoerr_bankcard_verify.value -> errmsg = R.string.kOtcMgrErrBankcardVerifyFailed.xmlstring(ctx)

                                else -> {
                                    //  默认错误消息处理
                                    val tmpmsg = otcerror.optString("message", null)
                                    if (tmpmsg != null && tmpmsg.isNotEmpty()) {
                                        //  显示 code 和 message
                                        errmsg = otcerror.toString()
                                    } else {
                                        //  仅显示 code
                                        errmsg = String.format(R.string.kOtcMgrErrNetworkOrServerFailedWithCode.xmlstring(ctx), errcode.toString())
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                errmsg = json as? String
            }
        }
        if (errmsg == null || errmsg.isEmpty()) {
            errmsg = R.string.kOtcMgrErrNetworkOrServerFailed.xmlstring(ctx)
        }
        ctx.showToast(errmsg)
    }

    /**
     *  (public) 辅助方法 - 是否已认证判断
     */
    fun isIdVerifyed(responsed: JSONObject?): Boolean {
        val data = responsed?.optJSONObject("data")
        if (data == null) {
            return false
        }
        val iIdVerify = data.getInt("isIdcard")
        if (iIdVerify == EOtcUserIdVerifyStatus.eovs_kyc1.value ||
                iIdVerify == EOtcUserIdVerifyStatus.eovs_kyc2.value ||
                iIdVerify == EOtcUserIdVerifyStatus.eovs_kyc3.value) {
            return true
        }
        return false
    }

    /**
     *  (public) API - 查询OTC用户身份认证信息。
     *  认证：TOKEN 方式
     *  bts_account_name    - BTS账号名
     */
    fun queryIdVerify(bts_account_name: String): Promise {
        val url = "$_base_api/user/queryIdVerify"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 请求身份认证
     *  认证：SIGN 方式
     */
    fun idVerify(args: JSONObject): Promise {
        val url = "$_base_api/user/idcardVerify"
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 创建订单
     *  认证：SIGN 方式
     */
    fun createUserOrder(bts_account_name: String, ad_id: String, ad_type: Int, legalCurrencySymbol: String, price: String, total: String): Promise {
        val url = "$_base_api/user/order/set"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("adId", ad_id)
            put("adType", ad_type)
            put("legalCurrencySymbol", legalCurrencySymbol)
            put("price", price)
            put("totalAmount", total)
            put("channel", "testotca")  //  TODO:2.9 config
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 查询用户订单列表
     *  认证：TOKEN 方式
     */
    fun queryUserOrders(bts_account_name: String, type: EOtcOrderType, status: EOtcOrderStatus, page: Int, page_size: Int): Promise {
        val url = "$_base_api/user/order/list"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("orderType", type.value)
            put("status", status.value)
            put("page", page)
            put("pageSize", page_size)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 查询订单详情
     *  认证：TOKEN 方式
     */
    fun queryUserOrderDetails(bts_account_name: String, order_id: String): Promise {
        val url = "$_base_api/user/order/details"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("orderId", order_id)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 更新用户订单
     *  认证：SIGN 方式
     */
    fun updateUserOrder(bts_account_name: String, order_id: String, payAccount: String?, payChannel: Any?, type: EOtcOrderUpdateType): Promise {
        val url = "$_base_api/user/order/update"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("orderId", order_id)
            put("type", type.value)
            //  有的状态不需要这些参数。
            if (payAccount != null) {
                put("payAccount", payAccount)
            }
            if (payChannel != null) {
                put("paymentChannel", payChannel)
            }
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 查询用户收款方式
     *  认证：TOKEN 方式
     */
    fun queryReceiveMethods(bts_account_name: String): Promise {
        val url = "$_base_api/payMethod/query"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 添加收款方式
     *  认证：SIGN 方式
     */
    fun addPaymentMethods(args: JSONObject): Promise {
        val url = "$_base_api/payMethod/add"
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 删除收款方式
     *  认证：SIGN 方式
     */
    fun delPaymentMethods(bts_account_name: String, pmid: Any): Promise {
        val url = "$_base_api/payMethod/del"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("id", pmid)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 编辑收款方式
     *  认证：SIGN 方式
     */
    fun editPaymentMethods(bts_account_name: String, new_status: EOtcPaymentMethodStatus, pmid: Any): Promise {
        val url = "$_base_api/payMethod/edit"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("id", pmid)
            put("status", new_status.value)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    ///*
    // *  (public) API - 上传二维码图片。
    // */
    //- (WsPromise*)uploadQrCode:(NSString*)bts_account_name filename:(NSString*)filename data:(NSData*)data
    //{
    //1//      TODO:2.9 测试数据
    ////        NSString* bundlePath = [NSBundle mainBundle].resourcePath;
    ////        NSString* fullPathInApp = [NSString stringWithFormat:@"%@/%@", bundlePath, @"abouticon@3x.png"];
    ////        NSData* data = [NSData dataWithContentsOfFile:fullPathInApp];
    ////
    ////        [[otc queryQrCode:[otc getCurrentBtsAccount] filename:@"2019/11/2415170943383153952545308672.png"] then:^id(id data) {
    ////            NSLog(@"%@", data);
    ////            return nil;
    ////        }];
    ////
    ////    [[[otc uploadQrCode:[otc getCurrentBtsAccount] filename:@"test.png" data:data] then:^id(id data) {
    ////        NSLog(@"%@", data);
    ////        return nil;
    ////    }] catch:^id(id error) {
    ////        [otc showOtcError:error];
    ////        return nil;
    ////    }];

    //    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/oss/upload"];
    //    id args = @{
    //        @"btsAccount":bts_account_name,
    //        @"fileName":filename,
    //    };
    //    return [self _handle_otc_server_response:[OrgUtils asyncUploadBinaryData:url data:data key:@"multipartFile" filename:filename args:args]];
    //}
    //
    ///*
    // *  (public) API - 获取二维码图片流。
    // */
    //- (WsPromise*)queryQrCode:(NSString*)bts_account_name filename:(NSString*)filename
    //{
    //    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/oss/query"];
    //    id args = @{
    //        @"btsAccount":bts_account_name,
    //        @"fileName":filename,
    //    };
    //    return [self _queryApiCore:url args:args headers:nil as_json:NO auth_flag:eoaf_none];
    //}

    /**
     *  (public) API - 查询OTC支持的数字资产列表（bitCNY、bitUSD、USDT等）
     *  认证：无
     *  asset_type  - 资产类型 默认值：eoat_digital
     */
    fun queryAssetList(): Promise {
        return queryAssetList(EOtcAssetType.eoat_digital)
    }

    fun queryAssetList(asset_type: EOtcAssetType): Promise {
        val url = "$_base_api/asset/getList"
        val args = JSONObject().apply {
            put("type", asset_type.value)
        }
        return _queryApiCore(url, args = args)
    }

    /**
     *  (private) API - 直接查询CNY法币信息。TODO:3.0目前只支持cny一个。临时实现。
     */
    private fun queryFiatAssetCNY(): Promise {
        //  已经存在了则直接返回
        if (_fiat_cny_info != null) {
            return Promise._resolve(_fiat_cny_info)
        }
        return queryAssetList(EOtcAssetType.eoat_fiat).then {
            val fiat_data = it as? JSONObject
            _fiat_cny_info = null
            val asset_list_fiat = fiat_data?.optJSONArray("data")
            if (asset_list_fiat != null && asset_list_fiat.length() > 0) {
                for (fiat_info in asset_list_fiat.forin<JSONObject>()) {
                    //  TODO:2.9 固定fiat CNY
                    if (fiat_info!!.getString("assetSymbol") == "CNY") {
                        _fiat_cny_info = fiat_info
                        break
                    }
                }
            }
            return@then _fiat_cny_info
        }
    }

    /**
     *  (public) API - 查询OTC商家广告列表。
     *  认证：无
     *  ad_status   - 广告状态 默认值：eoads_online
     *  ad_type     - 状态类型
     *  asset_name  - OTC数字资产名字（CNY、USD、GDEX.USDT等）
     *  page        - 页号
     *  page_size   - 每页数量
     */
    fun queryAdList(ad_type: EOtcAdType, asset_name: String, page: Int, page_size: Int, ad_status: EOtcAdStatus = EOtcAdStatus.eoads_online, otcAccount: String? = null): Promise {
        val url = "$_base_api/ad/list"
        val args = JSONObject().apply {
            put("adStatus", ad_status.value)
            put("adType", ad_type.value)
            put("assetSymbol", asset_name)
            if (otcAccount != null) {
                put("otcAccount", otcAccount)
            }
            put("page", page)
            put("pageSize", page_size)

        }
        return _queryApiCore(url, args = args)
    }

    /**
     *  (public) 查询广告详情。
     */
    fun queryAdDetails(ad_id: String): Promise {
        val url = "$_base_api/ad/detail"
        val args = JSONObject().apply {
            put("adId", ad_id)
        }
        return _queryApiCore(url, args = args)
    }


    /**
     *  (public) API - 锁定价格
     *  认证：TOKEN 方式
     */
    fun lockPrice(bts_account_name: String, ad_id: String, ad_type: Int, asset_symbol: String, price: String): Promise {
        val url = "$_base_api/order/price/lock/set"
        val args = JSONObject().apply {
            put("adId", ad_id)
            put("adType", ad_type)
            put("btsAccount", bts_account_name)
            put("assetSymbol", asset_symbol)
            put("price", price)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }


    /**
     *  (public) API - 发送短信
     *  认证：TOKEN 认证
     */
    fun sendSmsCode(bts_account_name: String, phone_number: String, type: EOtcSmsType): Promise {
        val url = "$_base_api/sms/send"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("phoneNum", phone_number)
            put("type", type.value)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 登录。部分API接口需要传递登录过的token字段。
     *  认证：SIGN 方式
     */
    fun login(bts_account_name: String): Promise {
        val url = "$_base_api/user/login"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (private) 执行OTC网络请求。
     *  as_json     - 是否返回 json 格式，否则返回原始数据流。
     */
    private fun _queryApiCore(url: String, args: JSONObject, headers: JSONObject? = null, as_json: Boolean = true, auth_flag: EOtcAuthFlag = EOtcAuthFlag.eoaf_none): Promise {
        //  认证：签名 or token
        var headers_args = headers

        if (auth_flag != EOtcAuthFlag.eoaf_none) {
            //  计算签名 先获取毫秒时间戳
            val timestamp = Utils.now_ts_ms().toString()
            val auth_key: String
            val auth_value: String?
            if (auth_flag == EOtcAuthFlag.eoaf_sign) {
                auth_key = "sign"
                auth_value = _sign(timestamp, args)
            } else {
                assert(auth_flag == EOtcAuthFlag.eoaf_token)
                auth_key = "token"
                //  REMARK：需要token的时候如果本地不存在，则传递一个无效token。否则服务器会报1002，缺少参数错误。
                auth_value = _loadUserTokenCookie(getCurrentBtsAccount()) ?: "invalidtoken"
            }

            //  合并请求header
            val new_headers = headers_args ?: JSONObject()
            new_headers.put("timestamp", timestamp)
            if (auth_value != null) {
                new_headers.put(auth_key, auth_value)
            }

            //  更新header
            headers_args = new_headers
        }

        //  TODO:2.9 headers, as json
        val request_promise = OrgUtils.asyncPost_jsonBody(url, args, headers_args)
        if (as_json) {
            //  REMARK：json格式需要判断返回值
            return _handle_otc_server_response(request_promise)
        } else {
            return request_promise
        }
    }

    /**
     *  (private) 处理返回值。
     *  request_promise - 实际的网络请求。
     */
    private fun _handle_otc_server_response(request_promise: Promise): Promise {
        val p = Promise()

        request_promise.then {
            val responsed = it as? JSONObject
            if (responsed == null) {
                p.reject(JSONObject().apply {
                    put("err_string_id", R.string.kOtcMgrErrNetworkOrServerFailed)
                })
                return@then null
            }
            val code = responsed.getInt("code")
            if (code != EOtcErrorCode.eoerr_ok.value) {
                p.reject(JSONObject().apply {
                    put("otcerror", JSONObject().apply {
                        put("code", code)
                        put("message", responsed.optString("message"))
                    })
                })
            } else {
                p.resolve(responsed)
            }
            return@then null
        }.catch {
            p.reject(JSONObject().apply {
                put("err_string_id", R.string.kOtcMgrErrNetworkOrServerFailed)
            })
        }
        return p
    }

    /**
     *  (private) token信息管理
     */
    private fun _genUserTokenCookieName(bts_account_name: String): String {
        //  TODO:2.9 token key config
        return "_bts_otc_token_$bts_account_name"
    }

    private fun _loadUserTokenCookie(bts_account_name: String): String? {
        return AppCacheManager.sharedAppCacheManager().getPref(_genUserTokenCookieName(bts_account_name)) as? String
    }

    private fun _delUserTokenCookie(bts_account_name: String) {
        AppCacheManager.sharedAppCacheManager().deletePref(_genUserTokenCookieName(bts_account_name)).saveCacheToFile()
    }

    private fun _saveUserTokenCookie(bts_account_name: String, token: String?) {
        if (token != null) {
            AppCacheManager.sharedAppCacheManager().setPref(_genUserTokenCookieName(bts_account_name), token).saveCacheToFile()
        }
    }

    /**
     *  (private) 生成待签名之前的完整字符串。
     */
    private fun _gen_sign_string(args: JSONObject): String {
        val keys = mutableListOf<String>()
        args.keys().forEach { keys.add(it) }
        val pArray = mutableListOf<String>()
        keys.sorted().forEach { key ->
            //  TODO:2.9 url encode???
            //  pArray.add("$key=${URLEncoder.encode(args.getString(key))}")
            pArray.add("$key=${args.getString(key)}")
        }
        return pArray.joinToString("&")
    }

    /**
     *  (private) 执行签名。钱包需要先解锁。
     */
    private fun _sign(timestamp: String, args: JSONObject?): String? {
        val walletMgr = WalletManager.sharedWalletManager()
        assert(!walletMgr.isLocked())

        //  获取待签名字符串
        val sign_args = args ?: JSONObject()
        sign_args.put("timestamp", timestamp)
        val sign_str = _gen_sign_string(sign_args)
        sign_args.remove("timestamp")

        //  ODO:2.9 不支持任何多签。必须单key 100%权限。active。
        val active_permission = walletMgr.getWalletAccountInfo()!!.getJSONObject("account").getJSONObject("active")
        val sign_keys = walletMgr.getSignKeys(active_permission)
        assert(sign_keys.length() == 1)
        //  TODO:2.9 实际签名数据是否加上chain id
        val signs = walletMgr.signTransaction(sign_str.utf8String(), sign_keys)
        if (signs == null) {
            return null
        }
        return (signs.get(0) as ByteArray).hexEncode()
    }

    fun gotoOtcMerchantHome(ctx: Activity) {
        //  TODO:2.9 merchantProgress 暂时不调用
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
        mask.show()

        //  直接调用商家详情，非商家返回空数据。
        val current_bts_account = getCurrentBtsAccount()
        val p1 = merchantDetail(current_bts_account, skip_cache = true)
        val p2 = queryFiatAssetCNY()
        Promise.all(p1, p2).then {
            mask.dismiss()
            val data_array = it as? JSONArray
            val merchant_detail = data_array?.optJSONObject(0)

            //  备用账号判断
            if (merchant_detail != null) {
                //  val btsAccount = merchant_detail.optString("btsAccount", null)
                val bakAccount = merchant_detail.optString("bakAccount", null)
                if (bakAccount != null && current_bts_account == bakAccount) {
                    ctx.showToast(String.format(R.string.kOtcMgrBakAccountCannotLogin.xmlstring(ctx), bakAccount))
                    return@then null
                }
            }
            
            if (merchant_detail != null) {
                // `status` tinyint(2) NOT NULL DEFAULT '0' COMMENT '状态:0=默认,0=未激活,1=已激活,2=取消激活,3=冻结',
                //  TODO:2.9 args progressInfo:nil
                ctx.goTo(ActivityOtcMcHome::class.java, true, args = JSONObject().apply {
                    put("merchant_detail", merchant_detail)
                })
            } else {
                //  TODO:3.0 暂时不开放申请，跳转说明页面，联系客服。
                gotoUrlPages(ctx, pagename = "apply")
                //ctx.goTo(ActivityOtcMcMerchantApply::class.java, true)
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            showOtcError(ctx, err)
        }
    }

    //  TODO:2.9 待處理
    ///*
    // *  (public) API - 商家申请进度查询
    // *  认证：SIGN 方式
    // */
    //- (WsPromise*)merchantProgress:(NSString*)bts_account_name
    //{
    //    id url = [NSString stringWithFormat:@"%@%@", _base_api, @"/merchant/progress"];
    //    id args = @{
    //        @"btsAccount":bts_account_name,
    //    };
    //    return [self _queryApiCore:url args:args headers:nil auth_flag:eoaf_sign];
    //}

    /**
     *  (public) API - 商家制度查询
     *  认证：无
     */
    fun merchantPolicy(bts_account_name: String): Promise {
        val url = "$_base_api/merchant/policy"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_none)
    }

    /**
     *  (public) API - 商家激活
     *  认证：SIGN 方式
     */
    fun merchantActive(bts_account_name: String): Promise {
        val url = "$_base_api/merchant/active"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 商家申请
     *  认证：SIGN 方式
     */
    fun merchantApply(bts_account_name: String, bakAccount: String, nickName: String): Promise {
        val url = "$_base_api/merchant/apply"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("bakAccount", bakAccount)
            put("nickname", nickName)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 商家详情查询
     *  认证：无
     */
    fun merchantDetail(bts_account_name: String, skip_cache: Boolean): Promise {
        //  直接返回缓存
        if (!skip_cache && _cache_merchant_detail != null) {
            return Promise._resolve(_cache_merchant_detail)
        }
        //  从服务器查询
        val url = "$_base_api/merchant/detail"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        //  查询
        val p = Promise()
        _queryApiCore(url, args = args).then {
            val merchant_detail_responsed = it as? JSONObject
            _cache_merchant_detail = merchant_detail_responsed?.optJSONObject("data")
            p.resolve(_cache_merchant_detail)
            return@then null
        }.catch { err ->
            _cache_merchant_detail = null
            if (isOtcError(err, EOtcErrorCode.eoerr_merchant_not_exist)) {
                p.resolve(null)
            } else {
                p.reject(err)
            }
        }
        return p
    }

    /**
     *  (public) API - 查询商家订单列表
     *  认证：TOKEN 方式
     */
    fun queryMerchantOrders(bts_account_name: String, type: EOtcOrderType, status: EOtcOrderStatus, page: Int, page_size: Int): Promise {
        val url = "$_base_api/merchants/order/list"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("orderType", type.value)
            put("status", status.value)
            put("page", page)
            put("pageSize", page_size)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 查询订单详情
     *  认证：TOKEN 方式
     */
    fun queryMerchantOrderDetails(bts_account_name: String, order_id: String): Promise {
        val url = "$_base_api/merchants/order/details"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("orderId", order_id)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 查询商家资产
     *  认证：TOKEN 方式
     */
    fun queryMerchantOtcAsset(bts_account_name: String): Promise {
        val url = "$_base_api/merchant/asset/list"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 查询商家指定资产余额查询
     *  认证：TOKEN 方式
     */
    fun queryMerchantAssetBalance(bts_account_name: String, otcAccount: String, merchantId: Any, assetSymbol: String): Promise {
        val url = "$_base_api/merchant/asset/balance"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("otcAccount", otcAccount)
            put("merchantId", merchantId)
            put("assetSymbol", assetSymbol)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 划转商家资产到个人账号
     *  认证：SIGN 方式
     */
    fun queryMerchantAssetExport(bts_account_name: String, signatureTx: JSONObject): Promise {
        val url = "$_base_api/merchant/asset/export"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("signatureTx", signatureTx.toString())
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 查询商家付款方式
     *  认证：TOKEN 方式
     */
    fun queryMerchantPaymentMethods(bts_account_name: String): Promise {
        val url = "$_base_api/merchant/getpaymethod"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_token)
    }

    /**
     *  (public) API - 更新商家付款方式
     *  认证：SIGN 方式
     */
    fun updateMerchantPaymentMethods(bts_account_name: String, aliPaySwitch: Boolean?, bankcardPaySwitch: Boolean?): Promise {
        assert(aliPaySwitch != null || bankcardPaySwitch != null)
        val url = "$_base_api/merchant/payswitch"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            //  REMARK：服务器采用true和false计算签名，用0和1计算签名会导致签名验证失败。
            if (aliPaySwitch != null) {
                put("aliPaySwitch", if (aliPaySwitch) "true" else "false")
            }
            if (bankcardPaySwitch != null) {
                put("bankcardPaySwitch", if (bankcardPaySwitch) "true" else "false")
            }
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 更新商家订单
     *  认证：SIGN 方式
     */
    fun updateMerchantOrder(bts_account_name: String, order_id: String, payAccount: String?, payChannel: Any?, type: EOtcOrderUpdateType, signatureTx: JSONObject?): Promise {
        val url = "$_base_api/merchants/order/update"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("orderId", order_id)
            put("type", type.value)
            //  有的状态不需要这些参数。
            if (payAccount != null) {
                put("payAccount", payAccount)
            }
            if (payChannel != null) {
                put("paymentChannel", payChannel)
            }
            if (signatureTx != null) {
                put("signatureTx", signatureTx.toString())
            }
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 查询商家memokey
     *  认证：SIGN 方式
     */
    fun queryMerchantMemoKey(bts_account_name: String): Promise {
        val url = "$_base_api/merchants/order/memo/key"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 商家创建广告（不上架、仅保存）
     *  认证：SIGN 方式
     */
    fun merchantCreateAd(args: JSONObject): Promise {
        val url = "$_base_api/ad/create"
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 商家更新并上架广告
     *  认证：SIGN 方式
     */
    fun merchantUpdateAd(args: JSONObject): Promise {
        val url = "$_base_api/ad/publish"
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 商家重新上架广告
     *  认证：SIGN 方式
     */
    fun merchantReUpAd(bts_account_name: String, ad_id: String): Promise {
        val url = "$_base_api/ad/reup"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("adId", ad_id)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 商家下架广告
     *  认证：SIGN 方式
     */
    fun merchantDownAd(bts_account_name: String, ad_id: String): Promise {
        val url = "$_base_api/ad/down"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("adId", ad_id)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }

    /**
     *  (public) API - 商家删除广告
     *  认证：SIGN 方式
     */
    fun merchantDeleteAd(bts_account_name: String, ad_id: String): Promise {
        val url = "$_base_api/ad/cancel"
        val args = JSONObject().apply {
            put("btsAccount", bts_account_name)
            put("adId", ad_id)
        }
        return _queryApiCore(url, args = args, auth_flag = EOtcAuthFlag.eoaf_sign)
    }
}