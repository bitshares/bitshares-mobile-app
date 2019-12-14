package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import android.widget.LinearLayout
import bitshares.toList
import kotlinx.android.synthetic.main.activity_otc_mc_asset_transfer.*
import org.json.JSONArray

class ActivityOtcMcAssetTransfer : BtsppActivity() {

    lateinit var layout_parent: LinearLayout

    private var _transfer_type: Int = 0

    lateinit var _edit_input_amount: EditText


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_asset_transfer)
        // 设置全屏
        setFullScreen()

        layout_parent = layout_asset_transfer_from_otc_mc_home

        val args = btspp_args_as_JSONObject()

        // 1 个人 -> 商家    1 商家 -> 个人
        _transfer_type = args.getInt("type")

        _edit_input_amount = et_input_amount_from_otc_mc_asset_transfer

        tv_from_text_from_otc_mc_transfer.text = if(_transfer_type == 1) { "(个人账号)" } else { "商家账号" }
        tv_from_account_from_otc_mc_transfer.text = "susu03"

        tv_to_text_from_otc_mc_transfer.text = if(_transfer_type == 1) { "(商家账号)" } else { "个人账号" }
        tv_to_account_from_otc_mc_transfer.text = "otc-xxxxxxxx"

        tv_transfer_asset_from_otc_mc_asset_transfer.text = "USD"
        tv_available_from_otc_mc_asset_transfer.text = "可用 0 USD"
        tv_input_aasset_symbol_from_otc_mc_asset_transfer.text = "USD"
        tv_warm_tip_from_otc_mc_asset_transfer.text = "【温馨提示】\n 从个人账号直接转账给商家账号"

        layout_select_asset_from_otc_mc_asset_transfer.setOnClickListener { onSelectAsset() }
        tv_transfer_all_from_otc_mc_asset_transfer.setOnClickListener { onTransferAllClicked() }
        tv_transfer_submit_from_otc_mc_asset_transfer.setOnClickListener { onTransferClicked() }

        layout_back_from_otc_mc_asset_transfer.setOnClickListener { finish() }
    }

    private fun onSelectAsset(){
        val asset_list = JSONArray().apply {
            put("USD")
            put("CNY")
            put("GDEX.USD")
        }
        ViewSelector.show(this, "请选资产", asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->
            val asset_name = asset_list.getString(index)
            tv_transfer_asset_from_otc_mc_asset_transfer.text = asset_name
            tv_input_aasset_symbol_from_otc_mc_asset_transfer.text = asset_name
            tv_available_from_otc_mc_asset_transfer.text = "可用 0 ${asset_name}"
        }
    }

    private fun onTransferAllClicked(){

    }

    private fun onTransferClicked(){

    }
}
