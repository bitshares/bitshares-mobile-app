package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.text.SpannableStringBuilder
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import bitshares.toList
import kotlinx.android.synthetic.main.activity_asset_op_issue.*
import org.json.JSONArray

class ActivityAssetOpissue : BtsppActivity() {

    lateinit var _tv_select_account_from_assets_opissue: TextView
    lateinit var _tv_available_assets_from_assets_opissue: TextView
    lateinit var _et_issue_asset_quantity_from_assets_opissue: EditText
    lateinit var _tv_issue_asset_symbol_from_assets_opissue: TextView
    lateinit var _tv_select_total_quantity_from_assets_opissue: TextView
    lateinit var _et_memo_info_from_assets_opissue: EditText

    lateinit var _tv_max_issue_quantity_from_assets_opissue: TextView
    lateinit var _tv_current_issue_quantity_from_assets_opissue: TextView
    lateinit var _btn_issue_from_assets_opissue: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_op_issue)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        _tv_select_account_from_assets_opissue = tv_select_account_from_assets_opissue

        // 可用资产数量
        _tv_available_assets_from_assets_opissue = tv_available_assets_from_assets_opissue
        _tv_available_assets_from_assets_opissue.text = String.format("可用 %s %s","3,000,000,000","FEEFREE")

        // 发行数量
        _et_issue_asset_quantity_from_assets_opissue = et_issue_asset_quantity_from_assets_opissue

        // 发行资产
        _tv_issue_asset_symbol_from_assets_opissue = tv_issue_asset_symbol_from_assets_opissue
        _tv_issue_asset_symbol_from_assets_opissue.text = "FEEFREE"

        // 备注信息
        _et_memo_info_from_assets_opissue = et_memo_info_from_assets_opissue

        // 最大发行量
        _tv_max_issue_quantity_from_assets_opissue = tv_max_issue_quantity_from_assets_opissue
        _tv_max_issue_quantity_from_assets_opissue.text = String.format("%s %s","3,000,000,000","FEEFREE")

        // 当前发行量
        _tv_current_issue_quantity_from_assets_opissue = tv_current_issue_quantity_from_assets_opissue
        _tv_current_issue_quantity_from_assets_opissue.text = String.format("%s %s","3,000,000","FEEFREE")

        // 选择全部
        _tv_select_total_quantity_from_assets_opissue = tv_select_total_quantity_from_assets_opissue
        _tv_select_total_quantity_from_assets_opissue.setOnClickListener {
            onSelectTotalAssetQuantity()
        }

        iv_select_account_right_arrow.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

        // 选择账号
        layout_select_account_from_assets_opissue.setOnClickListener {
            onSelectAccount()
        }

        // 发行
        _btn_issue_from_assets_opissue = btn_issue_from_assets_opissue
        _btn_issue_from_assets_opissue.setOnClickListener {
            onClickAssetIssue()
        }

        // 返回
        layout_back_from_assets_opissue.setOnClickListener {
            finish()
        }
    }

    // 选择全部数量
    private fun onSelectTotalAssetQuantity(){
        _et_issue_asset_quantity_from_assets_opissue.text = SpannableStringBuilder("3000000000")
    }

    // 发行资产按钮点击
    private fun onClickAssetIssue(){

    }

    // 选择账号
    private fun onSelectAccount() {
        val acconts = JSONArray().apply {
            put("account01")
            put("account02")
            put("account03")
        }
        ViewSelector.show(this, "请选择备用账号", acconts.toList<String>().toTypedArray()) { index: Int, account_name: String ->
            _tv_select_account_from_assets_opissue.text = account_name
        }
    }
}
