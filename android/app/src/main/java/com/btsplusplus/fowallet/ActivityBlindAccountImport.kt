package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.Promise
import com.btsplusplus.fowallet.utils.VcUtils
import kotlinx.android.synthetic.main.activity_blind_account_import.*

class ActivityBlindAccountImport : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_account_import)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val result_promise = args.opt("result_promise") as? Promise

        // 提交事件
        btn_import_submit.setOnClickListener { onSubmit(result_promise) }

        // 返回事件
        layout_back_from_blind_account_import.setOnClickListener { finish() }
    }

    private fun onSubmit(result_promise: Promise?) {
        val alias_name = tv_alias_name.text.toString().trim()
        val brain_key = tv_brain_key.text.toString().trim()

        VcUtils.processImportBlindAccount(this, alias_name, brain_key) { blind_account ->
            //  导入成功
            result_promise?.resolve(blind_account)
            finish()
        }
    }
}
