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
    private var _ad_type = OtcManager.EOtcAdType.eoadt_user_buy
    private var _user_type = OtcManager.EOtcUserType.eout_normal_user

    override fun onInitParams(args: Any?) {
        val json = args as JSONObject
        _ad_type = json.get("ad_type") as OtcManager.EOtcAdType
        _user_type = json.get("user_type") as OtcManager.EOtcUserType
    }

    /**
     * 查询广告列表
     */
    fun queryAdList(asset_name: String) {
        waitingOnCreateView().then {
            val ctx = it as Context
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()
            OtcManager.sharedOtcManager().queryAdList(_ad_type, asset_name, 0, 50).then {
                mask.dismiss()
                onQueryAdListResponsed(ctx, asset_name, it as? JSONObject)
                return@then null
            }.catch { err ->
                mask.dismiss()
                OtcManager.sharedOtcManager().showOtcError(ctx as Activity, err)
            }
            return@then null
        }
    }

    private fun onQueryAdListResponsed(ctx: Context, asset_name: String, responsed: JSONObject?) {
        val list = responsed?.optJSONObject("data")?.optJSONArray("records")
        val data_array = JSONArray()
        if (list != null && list.length() > 0) {
            for (item in list.forin<JSONObject>()) {
                val bankcardPaySwitch = item!!.isTrue("bankcardPaySwitch")
                val aliPaySwitch = item.isTrue("aliPaySwitch")
                val wechatPaySwitch = false     //  TODO:3.0 默认false，ad数据里没微信。
                if (aliPaySwitch || bankcardPaySwitch || wechatPaySwitch) {
                    data_array.put(item)
                }
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
                //  TODO:2.9 mc
                layout.addView(ViewUtils.createEmptyCenterLabel(ctx, R.string.kOtcAdNoAnyMerchantOnline.xmlstring(ctx)))
            }
        } else {
            data_array.forEach<JSONObject> {
                val view = ViewOtcMerchantCell(ctx, _user_type, it!!)
                layout.addView(view)
            }
        }
    }
}
