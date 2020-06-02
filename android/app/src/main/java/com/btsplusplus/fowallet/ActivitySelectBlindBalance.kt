package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import bitshares.*
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_select_blind_balance.*
import org.json.JSONArray
import org.json.JSONObject

class ActivitySelectBlindBalance : BtsppActivity() {

    private var _data_array = JSONArray()
    private lateinit var _default_selected: JSONObject

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_select_blind_balance)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val result_promise = args.opt("result_promise") as? Promise
        _default_selected = args.getJSONObject("default_selected")

        //  确认提交按钮事件
        btn_done.setOnClickListener { onSubmit(result_promise) }

        //  返回事件
        layout_back_from_select_blind_balance.setOnClickListener { finish() }

        //  查询数据依赖
        queryBlindBalanceAndDependence()
    }

    private fun onQueryBlindBalanceAndDependenceResponsed(data_array: JSONArray?) {
        _data_array = JSONArray()
        if (data_array != null && data_array.length() > 0) {
            for (blind_balance in data_array.forin<JSONObject>()) {
                //  添加收据并初始化默认选中状态
                val commitment = blind_balance!!.getJSONObject("decrypted_memo").getString("commitment")
                val selected = _default_selected.has(commitment)
                _data_array.put(JSONObject().apply {
                    put("_kBlindBalance", blind_balance)
                    put("_kSelected", selected)
                })
            }
        }
        refreshUI(_data_array)
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

    /**
     *  更新选中状态
     */
    private fun onSelectReceipt(select_index: Int, checked: Boolean) {
        _data_array.getJSONObject(select_index).put("_kSelected", checked)
    }

    private fun refreshUI(data_array: JSONArray) {
        //  清空
        val container = layout_receipt_list_from_select_blind_balance
        container.removeAllViews()

        if (data_array.length() > 0) {
            //  动态修改布局
            val oldLayoutParams = container.layoutParams
            oldLayoutParams.height = LinearLayout.LayoutParams.WRAP_CONTENT
            container.layoutParams = oldLayoutParams

            //  确定按钮可见性
            layout_submit_button.visibility = View.VISIBLE
            //  描绘
            var index = 0
            data_array.forEach<JSONObject> {
                val blind_balance = it!!.getJSONObject("_kBlindBalance")
                val selected = it.getBoolean("_kSelected")
                val cell = ViewBlindReceiptCell(this, blind_balance, index, can_check = true) { index: Int, checked: Boolean ->
                    onSelectReceipt(index, checked)
                }
                //  默认选中
                cell.setDefaultSelectedStatus(selected)
                container.addView(cell)
                container.addView(ViewLine(this, margin_top = 8.dp))

                index++
            }
        } else {
            //  动态修改布局（空标签才能够居中）
            val oldLayoutParams = container.layoutParams
            oldLayoutParams.height = LinearLayout.LayoutParams.MATCH_PARENT
            container.layoutParams = oldLayoutParams

            //  确定按钮可见性
            layout_submit_button.visibility = View.GONE
            //  无数据
            container.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kVcStTipEmptyNoBlindBalance)))
        }
    }

    /**
     *  提交
     */
    private fun onSubmit(result_promise: Promise?) {
        val ids = JSONObject()
        val result = JSONArray()
        //  获取所有选中的隐私收据
        for (row_data in _data_array.forin<JSONObject>()) {
            if (row_data!!.getBoolean("_kSelected")) {
                val blind_balance = row_data.getJSONObject("_kBlindBalance")
                result.put(blind_balance)
                ids.put(blind_balance.getJSONObject("decrypted_memo").getJSONObject("amount").getString("asset_id"), true)
            }
        }
        if (ids.length() > 1) {
            showToast(resources.getString(R.string.kVcStTipErrPleaseSelectSameAssetReceipts))
            return
        }
        //  返回
        result_promise?.resolve(result)
        finish()
    }
}
