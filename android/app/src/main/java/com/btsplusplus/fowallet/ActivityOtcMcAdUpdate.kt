package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import bitshares.toList
import kotlinx.android.synthetic.main.activity_otc_mc_ad_update.*
import org.json.JSONArray

class ActivityOtcMcAdUpdate : BtsppActivity() {

    private lateinit var _ad_type_list: JSONArray
    private lateinit var _asset_type_list: JSONArray

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_ad_update)
        // 设置全屏
        setFullScreen()

        _ad_type_list = JSONArray().apply {
            put("购买")
            put("出售")
        }
        _asset_type_list = JSONArray().apply {
            put("USD")
            put("CNY")
            put("GDEX.USD")
        }

        layout_select_ad_type_from_otc_mc_ad_update.setOnClickListener { adTypeOnSelected() }
        layout_select_asset_type_from_otc_mc_ad_update.setOnClickListener { assetTypeOnSelected() }
        layout_select_price_from_otc_mc_ad_update.setOnClickListener { inputPriceOnSelected() }
        layout_select_quantity_from_otc_mc_ad_update.setOnClickListener { inputQuantityOnSelected() }
        layout_select_min_amount_limit_from_otc_mc_ad_update.setOnClickListener { inputMinAmountLimitOnSelected() }
        layout_select_max_amount_limit_from_otc_mc_ad_update.setOnClickListener { inputMaxAmountLimitOnSelected() }
        layout_select_trade_description_from_otc_mc_ad_update.setOnClickListener { inputTradeDescriptionOnSelected() }
        tv_submit_ad_from_otc_mc_ad_update.setOnClickListener { onAdSubmitClicked() }

        layout_back_from_otc_mc_ad_update.setOnClickListener { finish() }
    }

    private fun adTypeOnSelected(){
        ViewSelector.show(this, "选择广告类型", _ad_type_list.toList<String>().toTypedArray()) { index: Int, _: String ->

        }
    }

    private fun assetTypeOnSelected(){
        ViewSelector.show(this, "选择资产类型", _asset_type_list.toList<String>().toTypedArray()) { index: Int, _: String ->

        }
    }

    private fun inputPriceOnSelected(){

    }

    private fun inputQuantityOnSelected(){

    }

    private fun inputMinAmountLimitOnSelected(){

    }

    private fun inputMaxAmountLimitOnSelected(){

    }

    private fun inputTradeDescriptionOnSelected(){

    }

    private fun onAdSubmitClicked(){

    }
}
