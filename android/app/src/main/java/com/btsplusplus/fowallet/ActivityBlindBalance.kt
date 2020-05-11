package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import bitshares.*
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_blind_balance.*
import kotlinx.android.synthetic.main.activity_blind_transfer.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityBlindBalance : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_balance)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  导入收据按钮事件
        button_add_from_blind_balance.setOnClickListener { onAddbuttonClicked() }

        //  返回事件
        layout_back_from_blind_balance.setOnClickListener { finish() }

        //  查询数据依赖
        queryBlindBalanceAndDependence()
    }

    private fun onQueryBlindBalanceAndDependenceResponsed(data_array: JSONArray) {
        refreshUI(data_array)
    }

    private fun queryBlindBalanceAndDependence() {
        val data_array = AppCacheManager.sharedAppCacheManager().getAllBlindBalance().values()
        val ids = JSONObject()
        for (blind_balance in data_array.forin<JSONObject>()) {
            ids.put(blind_balance!!.getJSONObject("decrypted_memo").getJSONObject("amount").getString("asset_id"), true)
        }
        if (ids.length() > 0) {
            VcUtils.simpleRequest(this, ChainObjectManager.sharedChainObjectManager().queryAllGrapheneObjects(ids.keys().toJSONArray())) {
                onQueryBlindBalanceAndDependenceResponsed(data_array)
            }
        } else {
            onQueryBlindBalanceAndDependenceResponsed(data_array)
        }
    }

    private fun refreshUI(data_array: JSONArray?) {
        val list = data_array ?: AppCacheManager.sharedAppCacheManager().getAllBlindBalance().values()

        //  清空
        val container = layout_receipt_list_from_blind_balance
        container.removeAllViews()

        if (list.length() > 0) {
            //  描绘
            var index = 0
            list.forEach<JSONObject> {
                val blind_balance = it!!

                container.addView(ViewBlindReceiptCell(this, blind_balance, index, can_check = false))
                container.addView(ViewLine(this, margin_top = 8.dp))

                index++
            }
        } else {
            //  无数据
            container.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kVcStTipEmptyNoBlindCanImport)))
        }
    }

    private fun onAddbuttonClicked(){
        val result_promise = Promise()
        goTo(ActivityBlindBalanceImport::class.java, true, args = JSONObject().apply {
            put("result_promise", result_promise)
        })
        result_promise.then { dirty ->
            //  刷新UI
            if (dirty != null && dirty as Boolean) {
                refreshUI(null)
            }
        }
    }
}
