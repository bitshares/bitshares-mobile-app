package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.BTS_NETWORK_CHAIN_ID
import bitshares.GrapheneConnection
import bitshares.Promise
import kotlinx.android.synthetic.main.activity_add_new_api_node.*
import org.json.JSONObject

class ActivityAddNewApiNode : BtsppActivity() {

    private lateinit var _url_hash: JSONObject
    private var _result_promise: Promise? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_add_new_api_node)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _url_hash = args.getJSONObject("url_hash")
        _result_promise = args.opt("result_promise") as? Promise

        //  事件 - 返回
        layout_back_from_new_api_node.setOnClickListener { finish() }

        //  事件 - 确定
        btn_submit.setOnClickListener { onSubmitBtnClick() }
    }

    /**
     * 提交事件
     */
    private fun onSubmitBtnClick() {
        val name = tf_node_name.text.toString().trim()
        val url = tf_node_url.text.toString().trim()

        if (name.isEmpty()) {
            showToast(resources.getString(R.string.kSettingNewApiSubmitTipsPleaseInputNodeName))
            return
        }

        if (url.isEmpty()) {
            showToast(resources.getString(R.string.kSettingNewApiSubmitTipsPleaseInputNodeURL))
            return
        }

        if (_url_hash.has(url)) {
            showToast(resources.getString(R.string.kSettingNewApiSubmitTipsURLAlreadyExist))
            return
        }

        val node = JSONObject().apply {
            put("location", name)
            put("url", url)
            put("_is_custom", true)
        }

        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
        GrapheneConnection.checkNodeStatus(node, 0, 0, false).then {
            mask.dismiss()
            val node_status = it as JSONObject
            if (node_status.optBoolean("connected")) {
                //  TODO: 以后也许考虑添加非mainnet等api节点。
                val chain_id = node_status.getJSONObject("chain_properties").optString("chain_id", null)
                if (chain_id != null && chain_id == BTS_NETWORK_CHAIN_ID) {
                    showToast(resources.getString(R.string.kSettingNewApiSubmitTipsOK))
                    //  返回上一个界面并刷新
                    _result_promise?.resolve(node)
                    _result_promise = null
                    finish()
                } else {
                    showToast(resources.getString(R.string.kSettingNewApiSubmitTipsNotBitsharesMainnetNode))
                }
            } else {
                showToast(resources.getString(R.string.kSettingNewApiSubmitTipsConnectedFailed))
            }
            return@then null
        }
    }
}
