package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import kotlinx.android.synthetic.main.activity_otc_user_auth.*

class ActivityOtcUserAuth : AppCompatActivity() {

    private lateinit var et_realname: EditText
    private lateinit var et_idcordno: EditText
    private lateinit var et_contact_phone: EditText
    private lateinit var et_auth_code: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_user_auth)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        layout_back_from_otc_user_auth.setOnClickListener { finish() }

        et_realname = et_input_realname_from_otc_user_auth
        et_idcordno = et_input_idcardno_from_otc_user_auth
        et_contact_phone = et_input_contact_phone_from_otc_user_auth
        et_auth_code = et_input_phone_auth_code_from_otc_user_auth

        tv_get_phone_auth_code_from_otc_user_auth.setOnClickListener { sendPhoneAuthCode() }
        tv_submit_from_otc_user_auth.setOnClickListener { onSubmit() }

    }

    private fun sendPhoneAuthCode(){
        val phone_number = et_contact_phone.text.toString()
    }

    private fun onSubmit(){

        goTo(ActivityOtcUserAuthInfos::class.java,true)

    }
}
