package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.OtcManager
import kotlinx.android.synthetic.main.activity_otc_user_auth_infos.*

class ActivityOtcUserAuthInfos : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_user_auth_infos)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val auth_info = btspp_args_as_JSONObject().getJSONObject("auth_info")

        //  UI - 姓名
        var realName = auth_info.optString("realName", null)
        if (realName != null && realName.length >= 2) {
            realName = "*${realName.substring(1)}"
        }
        tv_realname_from_otc_user_authinfo.text = realName ?: ""

        //  UI - 身份证号
        var idstr = auth_info.optString("idcardNo", null)
        if (idstr != null && idstr.length == 18) {
            idstr = "${idstr.substring(0, 6)}********${idstr.substring(14)}"
        }
        tv_idcordno_from_otc_user_authinfo.text = idstr ?: ""

        //  UI - 联系方式
        tv_contact_phone_from_otc_user_authinfo.text = auth_info.optString("phone")

        //  UI - 状态
        if (auth_info.getInt("status") == OtcManager.EOtcUserStatus.eous_freeze.value) {
            tv_status_from_otc_user_authinfo.text = resources.getString(R.string.kOtcAuthInfoCellLabelValueStatusFreeze)
            tv_status_from_otc_user_authinfo.setTextColor(resources.getColor(R.color.theme01_sellColor))
        } else {
            tv_status_from_otc_user_authinfo.text = resources.getString(R.string.kOtcAuthInfoCellLabelValueStatusOK)
            tv_status_from_otc_user_authinfo.setTextColor(resources.getColor(R.color.theme01_buyColor))
        }

        //  事件 - 返回
        layout_back_from_otc_user_auth_info.setOnClickListener { finish() }
    }
}
