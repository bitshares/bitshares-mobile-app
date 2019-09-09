package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.LinearLayout
import kotlinx.android.synthetic.main.activity_scan_result_transfer.*

class ActivityScanResultTransfer : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scan_result_transfer)

        // 账号名称
        val tv_account_name = account_name_from_scan_result_transfer
        tv_account_name.text = "Saya007"

        // 账号ID
        val tv_account_id = account_id_from_scan_result_transfer
        tv_account_id.text = "#1234567890"

        // 转账金额(自动读取)
        val tv_transfer_amount = txt_transfer_amount_from_scan_result_transfer
        tv_transfer_amount.text = "300 CNY"

        // 备注信息(自动读取)
        val tv_memo_info = txt_memo_info_from_scan_result_transfer
        tv_memo_info.text = "PPxsxxxxxxxxx"

        // 可用
        val tv_value_avaiable = txt_value_avaiable_from_scan_result_transfer
        tv_value_avaiable.text = "可用 33CNY"

        // 输入转账金额
        val et_amount = tf_amount_from_scan_result_transfer

        // 输入备注信息
        val et_memo_info = tf_memo_from_scan_result_transfer


        // 结果1: 自动读取转账金额 和 备注
        layout_transfer_amount_auto_input.visibility = LinearLayout.VISIBLE
        layout_memo_info_auto_input.visibility = LinearLayout.VISIBLE

        // 结果2: 手动输入转账金额 和 备注
        // layout_transfer_amount_input.visibility = LinearLayout.VISIBLE
        // layout_memo_info_input.visibility = LinearLayout.VISIBLE

        // 结果3: 手动输入转账金额 ，自动读取备注
        // layout_transfer_amount_input.visibility = LinearLayout.VISIBLE
        // layout_memo_info_auto_input.visibility = LinearLayout.VISIBLE

        // 结果4: 自动读取转账金额 ，手动输入备注
        // layout_transfer_amount_auto_input.visibility = LinearLayout.VISIBLE
        // layout_memo_info_input.visibility = LinearLayout.VISIBLE

        // 返回按钮
        layout_back_from_scan_result_transfer.setOnClickListener {
            finish()
        }

        // 提交支付事件
        button_payment_from_scan_result.setOnClickListener {

        }

    }
}
