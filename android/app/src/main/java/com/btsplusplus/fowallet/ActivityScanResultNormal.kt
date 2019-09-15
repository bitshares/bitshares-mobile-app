package com.btsplusplus.fowallet

import android.os.Bundle
import kotlinx.android.synthetic.main.activity_scan_result_normal.*

class ActivityScanResultNormal : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_scan_result_normal)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  设置参数
        tv_scan_str_from_scan_result_normal.text = btspp_args_as_JSONObject().getString("result")
        layout_back_from_scan_result_normal.setOnClickListener { finish() }
    }
}
