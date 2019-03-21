package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.Utils
import bitshares.xmlstring
import kotlinx.android.synthetic.main.activity_about.*

class ActivityAbout : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_about)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  draw version
        val ver = Utils.appVersionName(this)
        val appname = R.string.kAppName.xmlstring(this)
        label_txt_icon_version.text = "$appname v$ver"
        label_txt_version.text = "$appname v$ver"

        //  back
        layout_back_from_about.setOnClickListener { finish() }
    }
}
