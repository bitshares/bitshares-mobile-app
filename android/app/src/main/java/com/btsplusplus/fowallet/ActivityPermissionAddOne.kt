package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import kotlinx.android.synthetic.main.activity_permission_add_one.*

class ActivityPermissionAddOne : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_permission_add_one)
        setFullScreen()

        layout_back_from_add_one_permission.setOnClickListener {
            finish()
        }

        // 搜索账号
        tv_search_from_add_one_permission.setOnClickListener {

        }

        // 提交按钮
        btn_submitt_from_add_one_permission.setOnClickListener {

        }

    }
}
