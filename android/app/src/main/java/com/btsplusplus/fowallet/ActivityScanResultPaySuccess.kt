package com.btsplusplus.fowallet

import android.os.Bundle
import kotlinx.android.synthetic.main.activity_scan_result_pay_success.*

class ActivityScanResultPaySuccess : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_scan_result_pay_success)

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val to_account = args.getJSONObject("to_account")
        val trx_id = args.optJSONArray("result")?.optJSONObject(0)?.getString("id") ?: ""
        val to_account_id = to_account.optString("id", null)
        val success_tip_string = args.optString("success_tip_string", null)

        val tv_pay_amount = tv_pay_amount_from_scan_result_pay_success
        val tv_receiver_account = tv_receiver_account_from_scan_result_pay_success
        val tv_tv_transaction_id = tv_transaction_id_from_scan_result_pay_success

        //  UI - 支付成功图标
        img_pay_success.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
        //  UI - 支付成功提示文字
        tv_pay_success_text.text = success_tip_string ?: resources.getString(R.string.kVcScanResultTipsPaySuccess)
        //  UI - 支付金额、收款人、交易ID
        tv_pay_amount.text = args.optString("amount_string")
        tv_receiver_account.text = to_account.getString("name")
        tv_tv_transaction_id.text = trx_id

        //  返回按钮点击
        layout_back_from_scan_result_pay_success.setOnClickListener { finish() }

        //  完成按钮点击
        button_finish_from_scan_result_pay_success.setOnClickListener { finish() }

        //  接收账号整行点击
        layout_receiver_account_from_scan_result_pay_success.setOnClickListener {
            if (to_account_id != null && to_account_id != "") {
                viewUserAssets(to_account_id)
            }
        }

        //  交易账号整行点击
        layout_transaction_id_from_scan_result_pay_success.setOnClickListener {
            if (trx_id != "") {
                openURL("https://bts.ai/tx/$trx_id")
            }
        }
    }
}
