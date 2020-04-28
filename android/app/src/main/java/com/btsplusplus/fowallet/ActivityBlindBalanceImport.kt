package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import kotlinx.android.synthetic.main.activity_blind_balance_import.*

class ActivityBlindBalanceImport : BtsppActivity() {

    lateinit var _et_blind_receipt: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_balance_import)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化
        _et_blind_receipt = et_blind_receipt_from_blind_balance_import

        // 提交事件
        layout_submit_from_blind_balance_import.setOnClickListener {
            onSubmit()
        }

        // 返回事件
        layout_back_from_blind_balance_import.setOnClickListener { finish() }
    }

    private fun onSubmit(){
        val blind_receipt = _et_blind_receipt.text.toString()
    }
}
