package com.btsplusplus.fowallet
import android.os.Bundle
import android.widget.LinearLayout
import bitshares.forEach
import bitshares.toList
import kotlinx.android.synthetic.main.activity_otc_order_list.*
import kotlinx.android.synthetic.main.activity_otc_payment_list.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityOtcPaymentList : BtsppActivity() {

    private lateinit var _data: JSONArray
    private lateinit var _layout_payment_lists: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_payment_list)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 添加支付方式
        button_add_payment_method_from_merchant_payment_list.setOnClickListener { onAddPaymentMethodClicked() }

        //  返回
        layout_back_from_otc_merchant_payment_list.setOnClickListener { finish() }

        // 列表根 layout
        _layout_payment_lists = layout_payment_lists_from_orc_merchant

        _data = JSONArray()
        getData()
        refreshUI()
    }


    private fun getData(){
        addPayment()
    }

    private fun addPayment(){
        _data.put(JSONObject().apply {
            put("payment_type", 1)
            put("icon", "银行")
            put("name", "中国银行")
            put("username", "钟洋明")
            put("card_no", "1234 56")
        })
    }

    private fun refreshUI(){
        _layout_payment_lists.removeAllViews()
        if (_data.length() == 0){
            _layout_payment_lists.addView(ViewUtils.createEmptyCenterLabel(this, "没有任何支付方式"))
        } else {
            _data.forEach<JSONObject> {
                val view = ViewOtcMerchantPaymentCell(this, it!!)
                _layout_payment_lists.addView(view)
            }
        }
    }

    private fun onAddPaymentMethodClicked(){
        val asset_list = JSONArray().apply {
            put("支付宝")
            put("银行卡")
        }
        ViewSelector.show(this, "添加收款方式", asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->
            if(index == 0){
                goTo(ActivityOtcAddAlipay::class.java, true)
            } else {
                goTo(ActivityOtcAddBankCard::class.java, true)
            }
        }
    }
}
