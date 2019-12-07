package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import kotlinx.android.synthetic.main.activity_otc_user_auth_infos.*

class ActivityOtcUserAuthInfos : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_user_auth_infos)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        layout_back_from_otc_user_auth_info.setOnClickListener { finish() }

        tv_realname_from_otc_user_authinfo.text = "*洋明"
        tv_idcordno_from_otc_user_authinfo.text = "31011*********0909"
        tv_contact_phone_from_otc_user_authinfo.text = "13910000000"
        tv_status_from_otc_user_authinfo.text = "已完成"

    }
}
