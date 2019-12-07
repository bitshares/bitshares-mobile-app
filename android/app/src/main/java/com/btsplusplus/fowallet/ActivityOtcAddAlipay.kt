package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import kotlinx.android.synthetic.main.activity_otc_add_alipay.*

class ActivityOtcAddAlipay : BtsppActivity() {

    private lateinit var et_realname: EditText
    private lateinit var et_account: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_add_alipay)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 返回
        layout_back_from_otc_add_apipay.setOnClickListener { finish() }

        et_account = et_input_account_from_otc_add_alipay
        et_realname = et_input_realname_from_otc_add_alipay

        //  提交
        tv_submit_from_otc_add_alipay.setOnClickListener { onSubmit() }

    }

    private fun onSubmit(){
        
    }
}
