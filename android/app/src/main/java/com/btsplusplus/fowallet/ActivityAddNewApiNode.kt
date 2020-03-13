package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import kotlinx.android.synthetic.main.activity_add_new_api_node.*

class ActivityAddNewApiNode : BtsppActivity() {

    lateinit var _et_node_name: EditText
    lateinit var _et_node_url: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_add_new_api_node)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        _et_node_name = et_node_name_from_new_api_node
        _et_node_url = et_node_url_from_new_api_node

        layout_back_from_new_api_node.setOnClickListener { finish() }

        btn_submit_from_new_api_node.setOnClickListener {
            onSubmitBtnClick()
        }
    }

    // 提交事件
    private fun onSubmitBtnClick(){

    }
}
