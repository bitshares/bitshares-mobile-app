package com.btsplusplus.fowallet

import android.os.Bundle
import kotlinx.android.synthetic.main.activity_scan_result_pay_success.*

class ActivityScanResultPaySuccess : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_scan_result_pay_success)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        val tv_pay_amount = tv_pay_amount_from_scan_result_pay_success
        val tv_receiver_account = tv_receiver_account_from_scan_result_pay_success
        val tv_tv_transaction_id = tv_transaction_id_from_scan_result_pay_success

        tv_pay_amount.text = "0.01CNY"
        tv_receiver_account.text = "syalon-flauspid"
        tv_tv_transaction_id.text = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

        // 返回按钮点击
        layout_back_from_scan_result_pay_success.setOnClickListener {
            finish()
        }
        // 完成按钮点击
        button_finish_from_scan_result_pay_success.setOnClickListener {

        }
        // 接收账号整行点击
        layout_receiver_account_from_scan_result_pay_success.setOnClickListener {

        }
        // 交易账号整行点击
        layout_transaction_id_from_scan_result_pay_success.setOnClickListener {

        }
    }
}
