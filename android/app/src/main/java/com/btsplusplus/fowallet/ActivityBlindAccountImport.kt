package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import kotlinx.android.synthetic.main.activity_blind_account_import.*

lateinit var _et_alias_name: EditText
lateinit var _et_password: EditText

class ActivityBlindAccountImport : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_account_import)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化
        _et_alias_name = et_alias_name_from_blind_account_import
        _et_password = et_password_from_blind_account_import

        // 提交事件
        layout_submit_from_blind_account_import.setOnClickListener {
            onSubmit()
        }

        // 返回事件
        layout_back_from_blind_account_import.setOnClickListener { finish() }

    }

    private fun onSubmit(){
        val alias_name = _et_alias_name.text.toString()
        val password = _et_password.text.toString()
    }
}
