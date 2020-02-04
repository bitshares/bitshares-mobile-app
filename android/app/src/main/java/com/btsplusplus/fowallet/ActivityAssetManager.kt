package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_asset_manager.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityAssetManager : BtsppActivity() {

    lateinit var _layout_wrap_from_assets_manager: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_manager)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        _layout_wrap_from_assets_manager = layout_wrap_from_assets_manager

        button_add_from_assets_manager.setOnClickListener {
            goTo(ActivityAssetCreateOrEdit::class.java, true)
        }

        refreshUI()

        layout_back_from_assets_manager.setOnClickListener {
            finish()
        }
    }

    private fun refreshUI(){

        val data = JSONArray().apply {
            for (i in 0 until 10){
                put(JSONObject().apply {

                    put("asset_symbol", String.format("CNY_%s",i.toString()))
                    put("asset_name", String.format("China_yuan_%s",i.toString()))
                    put("asset_quantity", i.toString())
                    put("supply","41,731,117.9935")
                    put("max_supply","100,000,000,000")
                    put("privacy_supply","363.3342")

                })
            }
        }

        data.forEach<JSONObject> {
            _layout_wrap_from_assets_manager.addView(ViewAssetCell(this, it!!))
        }

    }
}
