package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import kotlinx.android.synthetic.main.activity_blind_output_add_one.*

class ActivityBlindOutputAddOne : BtsppActivity() {

    lateinit var _et_account: EditText
    lateinit var _et_quantity: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_output_add_one)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化
        _et_account = et_account_from_blind_output_add_one
        _et_quantity = et_quantity_from_blind_output_add_one

        // 输出资产名称
        tv_asset_symbol_from_blind_output_add_one.text = "TEST"

        // 我的账户点击事件
        tv_my_account_from_blind_output_add_one.setOnClickListener {
            onMyAccountClicked()
        }

        // 提交事件
        layout_submit_from_blind_output_add_one.setOnClickListener {
            onSubmit()
        }

        // 返回事件
        layout_back_from_blind_output_add_one.setOnClickListener { finish() }
    }

    private fun onMyAccountClicked(){

    }

    private fun onSubmit(){
        val account_name = _et_account.text.toString()
        val quantity = _et_quantity.text.toString()
    }
}
