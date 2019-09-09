package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import bitshares.Promise
import kotlinx.android.synthetic.main.activity_scan_result_normal.*

class ActivityScanResultNormal : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_scan_result_normal)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        tv_scan_str_from_scan_result_normal.text = "https://shop533402981.taobao.com/category-1475157567.htm?spm=a1z10.1-c-s.0.0.1864434ewymDF6&search=y&catName=2019.08.26+%D0%C2%C6%B7"

        layout_back_from_scan_result_normal.setOnClickListener {
            finish()
        }
    }
}
