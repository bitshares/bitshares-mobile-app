package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.EditText
import android.widget.TextView
import bitshares.toList
import kotlinx.android.synthetic.main.activity_otc_mc_merchant_apply.*
import org.json.JSONArray

class ActivityOtcMcMerchantApply : BtsppActivity() {

    lateinit var edit_text_nickname: EditText
    lateinit var tv_bak_account: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_merchant_apply)
        // 设置全屏
        setFullScreen()

        tv_bak_account = tv_bak_account_name_from_otc_mc_merchant_apply
        edit_text_nickname = et_input_nickname_from_otc_mc_merchant_apply

        tv_account_name_from_otc_mc_merchant_apply.text = "susu01"
        layout_select_bak_account_from_otc_mc_merchant_apply.setOnClickListener { onSelectBakAccount() }
        tv_apply_submit_from_otc_mc_merchant_apply.setOnClickListener { onApplySubmit() }
        layout_back_from_otc_mc_merchant_apply.setOnClickListener { finish() }
    }

    private fun onApplySubmit() {

    }

    private fun onSelectBakAccount() {

        val bak_acconts = JSONArray().apply {
            put("susu02")
            put("susu03")
        }
        ViewSelector.show(this, "请选择备用账号", bak_acconts.toList<String>().toTypedArray()) { index: Int, _: String ->
            tv_bak_account.text = bak_acconts.getString(index)
        }

    }
}
