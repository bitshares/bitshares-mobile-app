package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import kotlinx.android.synthetic.main.activity_transfer_to_blind.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityTransferToBlind : BtsppActivity() {

    lateinit var _layout_blind_account: LinearLayout

    lateinit var _tv_tv_available: TextView
    lateinit var _tv_total_amount: TextView
    lateinit var _tv_broadcast_fee: TextView

    lateinit var _layout_submit : LinearLayout

    lateinit var _data_blind_accounts: JSONArray
    lateinit var _view_blond_accounts: ViewBlindAccountsOrReceipt

    lateinit var _current_asset_symbol: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_transfer_to_blind)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化成员
        _layout_blind_account = layout_blind_account_list_from_transfer_to_blind
        _tv_tv_available =  tv_available_from_transfer_to_blind
        _tv_total_amount = tv_total_amount_from_transfer_to_blind
        _tv_broadcast_fee = tv_broadcast_fee_from_transfer_to_blind
        _layout_submit = layout_submit_button_from_transfer_to_blind
        _data_blind_accounts = JSONArray()

        _current_asset_symbol = "TEST"
        refreshAssetUI()


        // 选择资产箭头颜色
        iv_select_asset_from_transfer_to_blind.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

        // 选择资产事件
        layout_select_asset_from_transfer_to_blind.setOnClickListener {
            ViewSelector.show(this, "", arrayOf("TEST","TEST1","TEST2")) { index: Int, result: String ->
                _current_asset_symbol = result
                refreshAssetUI()
            }
        }

        // 获取隐私账号地址并刷新UI
        getData()
        _view_blond_accounts = ViewBlindAccountsOrReceipt(this,"blind_account", _layout_blind_account,_data_blind_accounts)

        // 提交事件
        _layout_submit.setOnClickListener {
            onSubmit()
        }

        // 返回事件
        layout_back_from_transfer_to_blind.setOnClickListener { finish() }

        // 右上角列表事件
        button_lists_from_transfer_to_blind.setOnClickListener {
            goTo(ActivityBlindBalance::class.java,true)
        }
    }

    private fun refreshAssetUI(){
        _tv_tv_available.text = "248273.999999 ${_current_asset_symbol}"
        _tv_total_amount.text = "610 ${_current_asset_symbol}"
        _tv_broadcast_fee.text = "10.001 ${_current_asset_symbol}"
    }

    private fun onSubmit(){

    }


    private fun getData(){
        val data = JSONObject().apply {
            put("address","TEST7UPXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
            put("quantity","100")
            put("operation","移除")
        }
        for(i in 0 until 10){
            _data_blind_accounts.put(data)
        }
    }

}
