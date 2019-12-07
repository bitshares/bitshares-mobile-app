package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import kotlinx.android.synthetic.main.activity_otc_add_bank_card.*

class ActivityOtcAddBankCard : AppCompatActivity() {

    private lateinit var et_realname: EditText
    private lateinit var et_cardno: EditText
    private lateinit var et_bankname: EditText
    private lateinit var et_bankaddress: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_add_bank_card)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        layout_back_from_otc_add_bankcard.setOnClickListener { finish() }

        et_realname = et_input_realname_from_otc_add_bankcard
        et_cardno = et_input_cardno_from_otc_add_bankcard
        et_bankname = et_input_bankname_from_otc_add_bankcard
        et_bankaddress = et_input_bank_address_from_otc_add_bankcard
        tv_submit_from_otc_add_bankcard.setOnClickListener { onSubmit() }

    }

    private fun onSubmit(){

    }
}
