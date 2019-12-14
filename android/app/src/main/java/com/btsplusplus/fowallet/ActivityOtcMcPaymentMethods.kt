package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.TextView
import kotlinx.android.synthetic.main.activity_otc_mc_payment_methods.*

class ActivityOtcMcPaymentMethods : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_payment_methods)
        // 设置全屏
        setFullScreen()

        val args = btspp_args_as_JSONObject()
        val _type = args.getString("type")

        if (_type == "receive"){
            findViewById<TextView>(R.id.title).text = "收款方式"
        } else {
            findViewById<TextView>(R.id.title).text = "付款方式"
        }

        // 支付宝
        switch_alipay_from_otc_payment_methods.setOnCheckedChangeListener { _, isChecked: Boolean ->
        }
        // 银行卡
        switch_bankcard_from_otc_payment_methods.setOnCheckedChangeListener { _, isChecked: Boolean ->
        }

        layout_back_from_otc_mc_payment_methods.setOnClickListener { finish() }
    }
}
