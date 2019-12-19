package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.LinearLayout
import bitshares.OtcManager
import bitshares.forEach
import bitshares.toList
import kotlinx.android.synthetic.main.activity_otc_payment_list.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityOtcPaymentList : BtsppActivity() {

    private lateinit var _auth_info: JSONObject

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_payment_list)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _auth_info = args.getJSONObject("auth_info")
        val user_type = args.get("user_type") as OtcManager.EOtcUserType

        //  添加支付方式
        button_add_payment_method_from_merchant_payment_list.setOnClickListener { onAddPaymentMethodClicked() }

        //  返回
        layout_back_from_otc_merchant_payment_list.setOnClickListener { finish() }

        //  查询
        queryPaymentMethods()
    }

    private fun onQueryPaymentMethodsResponsed(responsed: JSONObject?) {
        refreshUI(responsed?.optJSONArray("data"))
    }

    private fun queryPaymentMethods() {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        otc.queryPaymentMethods(otc.getCurrentBtsAccount()).then {
            mask.dismiss()
            onQueryPaymentMethodsResponsed(it as? JSONObject)
            return@then null
        }.catch {  err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

    private fun refreshUI(data_array: JSONArray?) {
        val layout_payment_lists = layout_payment_lists_from_orc_merchant
        layout_payment_lists.removeAllViews()
        if (data_array == null || data_array.length() == 0) {
            layout_payment_lists.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kOtcRmLabelEmpty)))
        } else {
            data_array.forEach<JSONObject> {
                val view = ViewOtcMerchantPaymentCell(this, it!!)
                layout_payment_lists.addView(view)
            }
        }
    }

    private fun onAddPaymentMethodClicked() {
        val asset_list = JSONArray().apply {
            put(resources.getString(R.string.kOtcAdPmNameBankCard))
            put(resources.getString(R.string.kOtcAdPmNameAlipay))
        }
        //  TODO:2.9 lang
        ViewSelector.show(this, "请选择要添加的收款方式", asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->
            if (index == 0) {
                goTo(ActivityOtcAddBankCard::class.java, true, args = JSONObject().apply {
                    put("auth_info", _auth_info)
                })
            } else if (index == 1){
                goTo(ActivityOtcAddAlipay::class.java, true, args = JSONObject().apply {
                    put("auth_info", _auth_info)
                })
            } else {
                assert(false)
            }
            //  TODO:2.9 result promise
        }
    }
}
