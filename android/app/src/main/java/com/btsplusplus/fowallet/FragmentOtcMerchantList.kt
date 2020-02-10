package com.btsplusplus.fowallet


import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal


// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 *
 */
class FragmentOtcMerchantList : BtsppFragment() {

    private var _ctx: Context? = null
    private var _view: View? = null

    private var _user_type = OtcManager.EOtcUserType.eout_normal_user

    private var _ad_type = OtcManager.EOtcAdType.eoadt_user_buy         //  用户端

    private var _auth_info: JSONObject? = null                          //  商家端
    private var _merchant_detail: JSONObject? = null                    //  商家端
    private var _ad_status = OtcManager.EOtcAdStatus.eoads_online       //  商家端

    override fun onInitParams(args: Any?) {
        val json = args as JSONObject
        _user_type = json.get("user_type") as OtcManager.EOtcUserType
        if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            _ad_type = json.get("ad_type") as OtcManager.EOtcAdType
        } else {
            _auth_info = json.getJSONObject("auth_info")
            _merchant_detail = json.getJSONObject("merchant_detail")
            _ad_status = json.get("ad_status") as OtcManager.EOtcAdStatus
        }
    }

    /**
     * 查询广告列表
     */
    fun queryAdList(asset_name: String) {
        waitingOnCreateView().then {
            val ctx = it as Context
            val otc = OtcManager.sharedOtcManager()
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()
            val p1 = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                otc.queryAdList(_ad_type, asset_name, 0, 50)
            } else {
                otc.queryAdList(OtcManager.EOtcAdType.eoadt_all, "", 0, 50, _ad_status, _merchant_detail!!.getString("otcAccount"))
            }
            p1.then {
                mask.dismiss()
                onQueryAdListResponsed(ctx, asset_name, it as? JSONObject)
                return@then null
            }.catch { err ->
                mask.dismiss()
                otc.showOtcError(ctx as Activity, err)
            }
            return@then null
        }
    }

    private fun onQueryAdListResponsed(ctx: Context, asset_name: String, responsed: JSONObject?) {
        val list = responsed?.optJSONObject("data")?.optJSONArray("records")
        val data_array = JSONArray()
        if (list != null && list.length() > 0) {
            if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                val n_zero = BigDecimal.ZERO
                for (item in list.forin<JSONObject>()) {
                    //  用户端：过滤掉0库存的广告
                    val n_stock = Utils.auxGetStringDecimalNumberValue(item!!.getString("stock"))
                    if (n_stock <= n_zero) {
                        continue
                    }
                    val bankcardPaySwitch = item.isTrue("bankcardPaySwitch")
                    val aliPaySwitch = item.isTrue("aliPaySwitch")
                    val wechatPaySwitch = false     //  TODO:3.0 默认false，ad数据里没微信。
                    if (aliPaySwitch || bankcardPaySwitch || wechatPaySwitch) {
                        data_array.put(item)
                    }
                }
            } else {
                data_array.putAll(list)
            }
        }
        refreshUI(data_array, ctx, asset_name)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        super.onCreateView(inflater, container, savedInstanceState)
        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_otc_merchant_list, container, false)
        return _view
    }

    private fun refreshUI(data_array: JSONArray, ctx: Context, asset_name: String) {
        if (_view == null) {
            return
        }
        val layout: LinearLayout = _view!!.findViewById(R.id.layout_buy_from_fragment_merchant_list)
        layout.removeAllViews()
        if (data_array.length() == 0) {
            if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                layout.addView(ViewUtils.createEmptyCenterLabel(ctx, R.string.kOtcAdNoAnyMerchantOnline.xmlstring(ctx)))
            } else {
                val str = when (_ad_status) {
                    OtcManager.EOtcAdStatus.eoads_online -> R.string.kOtcMcAdTableNoOnlineAd.xmlstring(ctx)
                    OtcManager.EOtcAdStatus.eoads_offline -> R.string.kOtcMcAdTableNoAd.xmlstring(ctx)
                    OtcManager.EOtcAdStatus.eoads_deleted -> R.string.kOtcMcAdTableNoAd.xmlstring(ctx)
                }
                layout.addView(ViewUtils.createEmptyCenterLabel(ctx, str))
            }
        } else {
            data_array.forEach<JSONObject> {
                val data = it!!
                val view = ViewOtcMerchantCell(ctx, _user_type, data) { ad_item -> onAdActionButtonClicked(ctx, ad_item) }
                //  商家：尚未删除的广告添加点击事件
                if (_user_type == OtcManager.EOtcUserType.eout_merchant && data.getInt("status") != OtcManager.EOtcAdStatus.eoads_deleted.value) {
                    view.setOnClickListener { onAdInfoCellClicked(ctx, data) }
                }
                layout.addView(view)
            }
        }
    }

    private fun onAdInfoCellClicked(ctx: Context, ad_item: JSONObject) {
        val result_promise = Promise()
        (ctx as Activity).goTo(ActivityOtcMcAdUpdate::class.java, true, args = JSONObject().apply {
            put("auth_info", _auth_info)
            put("merchant_detail", _merchant_detail)
            put("user_type", _user_type)
            put("ad_info", ad_item)
            put("result_promise", result_promise)
        })
        result_promise.then { dirty ->
            //  刷新UI
            if (dirty != null && dirty as Boolean) {
                queryAdList(ad_item.getString("assetSymbol"))
            }
        }
    }

    private fun _askForContactCustomerService(ctx: Context, auth_info: JSONObject) {
        UtilsAlert.showMessageConfirm(ctx, R.string.kWarmTips.xmlstring(ctx), R.string.kOtcAdUserFreezeAsk.xmlstring(ctx)).then {
            if (it != null && it as Boolean) {
                OtcManager.sharedOtcManager().gotoSupportPage(ctx as Activity)
            }
        }
    }

    /**
     *  (private) 用户卖出时 - 查询用户的收款方式列表。
     */
    private fun _queryReceiveMethodList(): Promise {
        if (_ad_type == OtcManager.EOtcAdType.eoadt_user_buy) {
            return Promise._resolve(true)
        } else {
            val otc = OtcManager.sharedOtcManager()
            return otc.queryReceiveMethods(otc.getCurrentBtsAccount()).then {
                val payment_responsed = it as? JSONObject
                return@then payment_responsed?.optJSONArray("data")
            }
        }
    }

    /**
     *  (private) 用户卖出时 - 查询用户对应资产余额。
     */
    private fun _queryUserBalance(ad_item: JSONObject, userAccount: String): Promise {
        if (_ad_type == OtcManager.EOtcAdType.eoadt_user_buy) {
            return Promise._resolve(null)
        } else {
            val p = Promise()
            ChainObjectManager.sharedChainObjectManager().queryAccountBalance(userAccount, jsonArrayfrom(ad_item.getString("assetId"))).then {
                val data_array = it as? JSONArray
                if (data_array != null && data_array.length() > 0) {
                    p.resolve(data_array.getJSONObject(0))
                } else {
                    p.resolve(null)
                }
                return@then null
            }.catch {
                p.resolve(null)
            }
            return p
        }
    }

    /**
     *  (private) 用户的收款方式和商家付款方式不匹配的提示。
     */
    private fun askForAddNewPaymentMethod(ctx: Context, ad_item: JSONObject, auth_info: JSONObject) {
        val bankcardPaySwitch = ad_item.isTrue("bankcardPaySwitch")
        val aliPaySwitch = ad_item.isTrue("aliPaySwitch")
        val wechatPaySwitch = false     //  TODO:2.9 默认false，ad数据里没微信。

        val ary = mutableListOf<String>()
        if (aliPaySwitch) {
            ary.add(R.string.kOtcAdPmNameAlipay.xmlstring(ctx))
        }
        if (bankcardPaySwitch) {
            ary.add(R.string.kOtcAdPmNameBankCard.xmlstring(ctx))
        }
        if (wechatPaySwitch) {
            ary.add(R.string.kOtcAdPmNameWechatPay.xmlstring(ctx))
        }

        assert(ary.size > 0)
        val paymentStrList = ary.joinToString(R.string.kOtcAdPmJoinChar.xmlstring(ctx))
        UtilsAlert.showMessageConfirm(ctx, R.string.kWarmTips.xmlstring(ctx), String.format(R.string.kOtcAdOrderMissingPmAsk.xmlstring(ctx), paymentStrList)).then {
            if (it != null && it as Boolean) {
                (ctx as Activity).goTo(ActivityOtcReceiveMethods::class.java, true, args = JSONObject().apply {
                    put("auth_info", auth_info)
                    put("user_type", OtcManager.EOtcUserType.eout_normal_user)
                })
            }
        }
    }

    /**
     *  (private) 价格变化，是否继续下单?
     */
    private fun askForPriceChanged(ctx: Context, ad_item: JSONObject, lock_info: JSONObject, auth_info: JSONObject, sell_user_balance: JSONObject?) {
        UtilsAlert.showMessageConfirm(ctx, R.string.kWarmTips.xmlstring(ctx), R.string.kOtcAdOrderPriceChangeAsk.xmlstring(ctx)).then {
            if (it != null && it as Boolean) {
                gotoInputOrderCore(ctx, ad_item, lock_info, auth_info, sell_user_balance)
            }
        }
    }

    /**
     *  (private) 前往下单
     */
    private fun gotoInputOrderCore(ctx: Context, ad_item: JSONObject, lock_info: JSONObject, auth_info: JSONObject, sell_user_balance: JSONObject?) {
        ViewDialogOtcTrade(ctx, ad_item, lock_info, sell_user_balance) { result: JSONObject? ->
            if (result != null) {
                //  输入完毕：尝试下单
                val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
                mask.show()
                val adType = ad_item.getInt("adType")
                val otc = OtcManager.sharedOtcManager()
                otc.createUserOrder(otc.getCurrentBtsAccount(), ad_item.getString("adId"),
                        adType, lock_info.getString("legalCurrencySymbol"),
                        lock_info.getString("unitPrice"), result.getString("total")).then {
                    mask.dismiss()
                    //  TODO:3.0 暂时不自动转账，可能转账失败等。手续费不足。
                    val msg = if (adType == OtcManager.EOtcAdType.eoadt_user_sell.value) {
                        resources.getString(R.string.kOtcAdSubmitTipOrderOK_Sell)
                    } else {
                        resources.getString(R.string.kOtcAdSubmitTipOrderOK_Buy)
                    }
                    UtilsAlert.showMessageConfirm(ctx, resources.getString(R.string.kWarmTips), msg, btn_cancel = null).then {
                        (ctx as Activity).goTo(ActivityOtcOrderList::class.java, true, args = JSONObject().apply {
                            put("auth_info", auth_info)
                            put("user_type", OtcManager.EOtcUserType.eout_normal_user)
                        })
                        return@then null
                    }
                    return@then null
                }.catch { err ->
                    mask.dismiss()
                    otc.showOtcError(ctx as Activity, err)
                }
            }
        }.show()
    }

    /**
     *  (private) 检测用户是否存在对应的收款方式。
     */
    private fun _checkUserReceiveMethod(pminfo_list: JSONArray?, aliPaySwitch: Boolean, bankcardPaySwitch: Boolean, wechatPaySwitch: Boolean): Boolean {
        if (pminfo_list != null && pminfo_list.length() > 0) {
            for (pminfo in pminfo_list.forin<JSONObject>()) {
                if (pminfo!!.getInt("status") != OtcManager.EOtcPaymentMethodStatus.eopms_enable.value) {
                    continue
                }
                when (pminfo.getInt("type")) {
                    OtcManager.EOtcPaymentMethodType.eopmt_alipay.value -> {
                        if (aliPaySwitch) {
                            return true
                        }
                    }
                    OtcManager.EOtcPaymentMethodType.eopmt_bankcard.value -> {
                        if (bankcardPaySwitch) {
                            return true
                        }
                    }
                    OtcManager.EOtcPaymentMethodType.eopmt_wechatpay.value -> {
                        if (wechatPaySwitch) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    /**
     * 事件 - 点击购买or出售按钮。
     */
    private fun onBuyOrSellButtonClicked(ctx: Context, ad_item: JSONObject) {
        val bankcardPaySwitch = ad_item.isTrue("bankcardPaySwitch")
        val aliPaySwitch = ad_item.isTrue("aliPaySwitch")
        val wechatPaySwitch = false     //  TODO:2.9 默认false，ad数据里没微信。

        //  已经过滤过了，这里的都是至少开启了一种付款方式的。
        assert(aliPaySwitch || bankcardPaySwitch || wechatPaySwitch)

        val adId = ad_item.getString("adId")

        val otc = OtcManager.sharedOtcManager()
        val merchant_detail = otc.getCacheMerchantDetail()
        if (merchant_detail != null) {
            val myOtcAccountId = merchant_detail.optString("otcAccountId", null)
            val adOtcAccountId = ad_item.optString("otcBtsId", null)
            if (myOtcAccountId != null && adOtcAccountId != null && myOtcAccountId == adOtcAccountId) {
                showToast(R.string.kOtcAdSubmitTipCannotTradeWithSelf.xmlstring(ctx))
                return
            }
        }

        (ctx as Activity).guardWalletUnlocked(true) { unlocked ->
            if (unlocked) {
                otc.guardUserIdVerified(ctx, R.string.kOtcAdAskIdVerifyTips03.xmlstring(ctx), keep_mask = true) { auth_info, new_mask ->
                    val mask = new_mask!!
                    //  1、查询账号状态：用户账号是否异常
                    if (auth_info.getInt("status") == OtcManager.EOtcUserStatus.eous_freeze.value) {
                        mask.dismiss()
                        _askForContactCustomerService(ctx, auth_info)
                        return@guardUserIdVerified
                    }
                    val p1 = otc.queryConfig()
                    val p2 = _queryReceiveMethodList()
                    Promise.all(p1, p2).then {
                        val data_array = it as JSONArray
                        //  a. 检测服务器配置 是否开启下单功能判断
                        val order_config = data_array.getJSONObject(0).optJSONObject("order")
                        if (order_config == null || !order_config.isTrue("enable")) {
                            var msg = order_config?.optString("msg", null)
                            if (msg == null || msg.isEmpty()) {
                                msg = R.string.kOtcEntryDisableDefaultMsg.xmlstring(ctx)
                            }
                            mask.dismiss()
                            showToast(msg)
                            return@then null
                        }
                        //  b. 仅卖出的情况 检测用户是否存在对应的收款方式
                        if (_ad_type == OtcManager.EOtcAdType.eoadt_user_sell) {
                            if (!_checkUserReceiveMethod(data_array.optJSONArray(1), aliPaySwitch, bankcardPaySwitch, wechatPaySwitch)) {
                                mask.dismiss()
                                askForAddNewPaymentMethod(ctx, ad_item, auth_info)
                                return@then null
                            }
                        }
                        //  3、查询余额&锁定价格&前往下单（TODO:2.9 是否先查询广告详情，目前数据一直）
                        val userAccount = otc.getCurrentBtsAccount()
                        return@then _queryUserBalance(ad_item, userAccount).then {
                            //  卖出时候：获取余额异常
                            val userAssetBalance = it as? JSONObject
                            if (_ad_type == OtcManager.EOtcAdType.eoadt_user_sell && userAssetBalance == null) {
                                mask.dismiss()
                                showToast(R.string.tip_network_error.xmlstring(ctx))
                                return@then null
                            }
                            return@then otc.lockPrice(userAccount, adId, ad_item.getInt("adType"), ad_item.getString("assetSymbol"), ad_item.getString("price")).then {
                                mask.dismiss()
                                val responsed = it as JSONObject
                                val lock_info = responsed.getJSONObject("data")

                                //  REMARK：这里必须设置精度，不然 5 和 5.0 大数比较会不同。
                                val oldprice = Utils.auxGetStringDecimalNumberValue(ad_item.getString("price")).setScale(12)
                                val newprice = Utils.auxGetStringDecimalNumberValue(lock_info.getString("unitPrice")).setScale(12)

                                //  价格变化
                                if (oldprice != newprice) {
                                    askForPriceChanged(ctx, ad_item, lock_info, auth_info, userAssetBalance)
                                } else {
                                    gotoInputOrderCore(ctx, ad_item, lock_info, auth_info, userAssetBalance)
                                }
                                return@then null
                            }
                        }
                    }.catch { err ->
                        mask.dismiss()
                        otc.showOtcError(ctx, err)
                    }
                }
            }
        }
    }

    private fun onAdActionButtonClicked(ctx: Context, ad_item: JSONObject) {
        if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            onBuyOrSellButtonClicked(ctx, ad_item)
        } else {
            when (ad_item.getInt("status")) {
                OtcManager.EOtcAdStatus.eoads_online.value -> {
                    (ctx as Activity).guardWalletUnlocked(true) { unlocked ->
                        if (unlocked) {
                            _execAdUpOrDown(ctx, ad_item, reup = false)
                        }
                    }
                }
                OtcManager.EOtcAdStatus.eoads_offline.value -> {
                    (ctx as Activity).guardWalletUnlocked(true) { unlocked ->
                        if (unlocked) {
                            _execAdUpOrDown(ctx, ad_item, reup = true)
                        }
                    }
                }
                OtcManager.EOtcAdStatus.eoads_deleted.value -> assert(false)
            }
        }
    }

    private fun _execAdUpOrDown(ctx: Context, ad_item: JSONObject, reup: Boolean) {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
        mask.show()
        val p1 = if (reup) {
            otc.merchantReUpAd(otc.getCurrentBtsAccount(), ad_item.getString("adId"))
        } else {
            otc.merchantDownAd(otc.getCurrentBtsAccount(), ad_item.getString("adId"))
        }
        p1.then {
            mask.dismiss()
            if (reup) {
                showToast(R.string.kOtcMcAdSubmitTipsUpOK.xmlstring(ctx))
            } else {
                showToast(R.string.kOtcMcAdSubmitTipsDownOK.xmlstring(ctx))
            }
            //  刷新
            queryAdList(ad_item.getString("assetSymbol"))
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(ctx as Activity, err)
        }
    }
}
