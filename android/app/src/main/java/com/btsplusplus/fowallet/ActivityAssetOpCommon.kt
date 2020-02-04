package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.text.SpannableStringBuilder
import android.widget.EditText
import android.widget.TextView
import bitshares.toList
import kotlinx.android.synthetic.main.activity_asset_op_common.*
import kotlinx.android.synthetic.main.activity_asset_op_issue.*
import org.json.JSONArray

class ActivityAssetOpCommon : BtsppActivity() {

    lateinit var _tv_select_asset_from_assets_op_common: TextView
    lateinit var _tv_available_assets_from_assets_op_common: TextView
    lateinit var _et_issue_asset_quantity_from_assets_op_common: EditText
    lateinit var _tv_issue_asset_symbol_from_assets_op_common: TextView
    lateinit var _tv_select_total_quantity_from_assets_op_common: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_op_common)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 资产
        _tv_select_asset_from_assets_op_common = tv_select_asset_from_assets_op_common

        // 有效
        _tv_available_assets_from_assets_op_common = tv_available_assets_from_assets_op_common
        _tv_available_assets_from_assets_op_common.text = String.format("可用 %s %s","3,000,000,000","BTS")

        // 输入资产数量
        _et_issue_asset_quantity_from_assets_op_common = et_issue_asset_quantity_from_assets_op_common

        // 资产符号
        _tv_issue_asset_symbol_from_assets_op_common = tv_issue_asset_symbol_from_assets_op_common
        _tv_issue_asset_symbol_from_assets_op_common.text = "BTS"

        // 选择全部
        _tv_select_total_quantity_from_assets_op_common = tv_select_total_quantity_from_assets_op_common
        _tv_select_total_quantity_from_assets_op_common.setOnClickListener {
            onSelectTotalAssetQuantity()
        }

        iv_select_asset_right_arrow.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

        // 选择账号
        layout_select_asset_from_assets_op_common.setOnClickListener {
            onSelectAsset()
        }

        // 立即销毁
        btn_submit_from_assets_op_common.setOnClickListener {
            onAssetDestroy()
        }

        layout_back_from_assets_op_common.setOnClickListener {
            finish()
        }
    }

    // 选择全部数量
    private fun onSelectTotalAssetQuantity(){
        _et_issue_asset_quantity_from_assets_op_common.text = SpannableStringBuilder("3000000000")
    }

    // 选择资产
    private fun onSelectAsset() {
        val acconts = JSONArray().apply {
            put("BTS")
            put("AAA")
            put("BBB")
        }
        ViewSelector.show(this, "请选资产", acconts.toList<String>().toTypedArray()) { index: Int, asset_name: String ->
            _tv_select_asset_from_assets_op_common.text = asset_name
        }
    }

    // 销毁资产
    private fun onAssetDestroy(){

    }
}
