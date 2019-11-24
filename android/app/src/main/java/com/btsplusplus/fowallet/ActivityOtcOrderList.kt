package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_otc_merchant_list.*
import kotlinx.android.synthetic.main.activity_otc_order_list.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityOtcOrderList : BtsppActivity() {

    private lateinit var _data: JSONArray
    private lateinit var _layout_order_lists: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_order_list)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  返回
        layout_back_from_otc_merchant_order_list.setOnClickListener { finish() }

        // 列表根 layout
        _layout_order_lists = layout_order_lists_from_orc_merchant

        getData()
        refreshUI()
    }

    private fun getData(){
        _data = JSONArray().apply {
            for (i in 0 until 10) {
                put(JSONObject().apply {
                    put("order_type", 1)
                    put("asset_name", "CNY")
                    put("time", "2019-12-12T12:12")
                    put("quantity", 7.76)
                    put("price", 7.92)
                    put("legal_symbol", "¥")
                    put("merchant_name", "吉祥承兑")
                })
                put(JSONObject().apply {
                    put("order_type", 2)
                    put("asset_name", "GDEX.USDT")
                    put("time", "2019-12-12T12:12")
                    put("quantity", 17.76)
                    put("price", 17.92)
                    put("legal_symbol", "$")
                    put("merchant_name", "XX承兑")
                })
            }
        }
    }

    private fun refreshUI(){
        _layout_order_lists.removeAllViews()
        if (_data.length() == 0){
            _layout_order_lists.addView(ViewUtils.createEmptyCenterLabel(this, "没有订单"))
        } else {
            _data.forEach<JSONObject> {
                val view = ViewOtcMerchantOrderCell(this, it!!)
                _layout_order_lists.addView(view)
            }
        }
    }
}
