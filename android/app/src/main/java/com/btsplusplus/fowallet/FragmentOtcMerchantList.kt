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
import org.json.JSONArray
import org.json.JSONObject


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
                for (item in list.forin<JSONObject>()) {
                    val bankcardPaySwitch = item!!.isTrue("bankcardPaySwitch")
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
                val view = ViewOtcMerchantCell(ctx, _user_type, data) { ad_item -> onAdActionButtonClicked(ctx, ad_item)}
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

    private fun onAdActionButtonClicked(ctx: Context, ad_item: JSONObject) {
        if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
            //  TODO:2.9 buy or sell
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

//    private fun onBuyButtonClicked() {
//        val ad_type = _data.getInt("adType")
//        ViewDialogOtcTrade(_ctx, _data.getString("assetSymbol"), ad_type, _data) { _index: Int, result_data: JSONObject ->
//        }.show()
//    }
//
//    private fun onSellButtonClicked() {
//        val ad_type = _data.getInt("adType")
//        ViewDialogOtcTrade(_ctx, _data.getString("assetSymbol"), ad_type, _data) { _index: Int, result_data: JSONObject ->
//        }.show()
//    }
}
