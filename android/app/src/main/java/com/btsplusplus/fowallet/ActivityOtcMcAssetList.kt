package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import bitshares.dp
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_otc_mc_asset_list.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityOtcMcAssetList : BtsppActivity() {

    lateinit var layout_parent: LinearLayout

    private lateinit var _data: JSONArray

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_asset_list)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        layout_parent = layout_asset_list_from_otc_mc_home

        layout_back_from_otc_mc_asset_list.setOnClickListener { finish() }

        getData()

        refreshUI()

    }

    private fun getData(){
        _data = JSONArray().apply {
            for (i in 0 until 10){
                put(JSONObject().apply{
                    put("asset_name", "CNY")
                    put("available", 1717.6)
                    put("freeze_count", 41060000000)
                    put("fee",0)
                })
            }
        }
    }

    private fun refreshUI(){
        if (_data.length() == 0){
            layout_parent.addView(ViewUtils.createEmptyCenterLabel(this, "没有任何资产"))
        } else {
            _data.forEach<JSONObject> {
                val view = ViewOtcMcAssetCell(this,it!!)
                layout_parent.addView(view)
                layout_parent.addView(ViewLine(this, 0.dp, 10.dp))
            }
        }
    }
}
