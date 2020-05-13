package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.toList
import kotlinx.android.synthetic.main.activity_transfer_from_blind.*
import kotlinx.android.synthetic.main.activity_transfer_to_blind.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityTransferFromBlind : BtsppActivity() {

    lateinit var _layout_blind_receipt: LinearLayout
    lateinit var _data_blind_receipt: JSONArray
    lateinit var _view_blind_receipt: ViewBlindAccountsOrReceipt

    lateinit var _tv_accoun_name: TextView
    lateinit var _tv_accoun_id: TextView
    lateinit var _tv_total_amount: TextView
    lateinit var _tv_total_fee: TextView

    lateinit var _current_asset_symbol: String

    lateinit var _current_account: JSONObject

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_transfer_from_blind)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化成员
        _layout_blind_receipt = layout_blind_receipt_list_from_transfer_from_blind
        _tv_accoun_name = tv_account_name_from_transfer_from_blind
        _tv_accoun_id = tv_account_id_from_transfer_from_blind

        _tv_total_amount = tv_total_amount_from_transfer_from_blind
        _tv_total_fee = tv_broadcast_fee_from_transfer_from_blind

        _data_blind_receipt = JSONArray()

        // 选择目标账户箭头颜色
        iv_select_goal_account_from_transfer_from_blind.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

        // 当前资产
        _current_asset_symbol = "TEST"
        _tv_total_amount.text = "3.7 ${_current_asset_symbol}"
        _tv_total_fee.text = "0.001 ${_current_asset_symbol}"

        // 获取隐私账号地址并刷新UI
        getData()
        _view_blind_receipt = ViewBlindAccountsOrReceipt(this, kBlindItemTypeInput, _layout_blind_receipt)

        // 设置默认账户
        _current_account = JSONObject().apply {
            put("name","TEMP-ACCOUNT1")
            put("id","1.2.4")
        }

        // 选择目标账户事件
        layout_select_goal_account_from_transfer_from_blind.setOnClickListener {
            onSelectGoalAccount()
        }

        // 提交事件
        layout_submit_button_from_transfer_from_blind.setOnClickListener {
            onSubmit()
        }

        // 返回事件
        layout_back_from_transfer_from_blind.setOnClickListener { finish() }
    }

    private fun onSubmit(){

    }

    private fun refreshAccountUI(){
        _tv_accoun_name.text = _current_account.getString("name")
        _tv_accoun_id.text = _current_account.getString("id")
    }

    private fun onSelectGoalAccount(){
        // REMARK TEST DATA
        val list = JSONArray()
        val data = JSONArray().apply {
            for (i in 0 until 5){
                put(JSONObject().apply {
                    put("name","TEMP-ACCOUNT1")
                    put("id","1.2.4")
                })
                list.put("TEMP-ACCOUNT1")
            }
        }

        ViewSelector.show(this, "", list.toList<String>().toTypedArray()) { index: Int, result: String ->
            _current_account = data.getJSONObject(index)
            refreshAccountUI()
        }

    }

    private fun getData(){
        val data = JSONObject().apply {
            put("address","收据 #1D52C8C6")
            put("quantity","100")
            put("operation","移除")
        }
        for(i in 0 until 10){
            _data_blind_receipt.put(data)
        }
    }
}
