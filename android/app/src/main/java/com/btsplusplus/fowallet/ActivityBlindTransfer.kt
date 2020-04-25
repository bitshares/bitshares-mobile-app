package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import kotlinx.android.synthetic.main.activity_blind_transfer.*
import org.json.JSONArray
import org.json.JSONObject
import org.w3c.dom.Text

class ActivityBlindTransfer : BtsppActivity() {

    lateinit var _data_blind_receipt: JSONArray
    lateinit var _data_blind_accounts: JSONArray

    lateinit var _tv_total_receipt_amount: TextView
    lateinit var _total_output_amount: TextView
    lateinit var _tv_broadcast_fee: TextView

    lateinit var _layout_blind_account: LinearLayout
    lateinit var _layout_blind_receipt: LinearLayout

    lateinit var _view_blind_receipt: ViewBlindAccountsOrReceipt
    lateinit var _view_blind_account: ViewBlindAccountsOrReceipt

    lateinit var _current_asset_symbol: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_transfer)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化对象
        _layout_blind_account = layout_blind_account_list_from_blind_transfer
        _layout_blind_receipt = layout_blind_receipt_list_from_blind_transfer
        _tv_total_receipt_amount = tv_total_receipt_amount_from_blind_transfer
        _total_output_amount = tv_total_output_amount_from_blind_transfer
        _tv_broadcast_fee = tv_broadcast_fee_from_blind_transfer

        _data_blind_receipt = JSONArray()
        _data_blind_accounts = JSONArray()

        _current_asset_symbol = "TEST"
        _tv_total_receipt_amount.text = "2.3 ${_current_asset_symbol}"
        _total_output_amount.text = "555 ${_current_asset_symbol}"
        _tv_broadcast_fee.text = "5.0001 ${_current_asset_symbol}"

        // 获取收据并刷新UI
        getBlindReceiptData()
        _view_blind_receipt = ViewBlindAccountsOrReceipt(this,"blind_receipt", _layout_blind_receipt,_data_blind_receipt)

        // 获取隐私地址并刷新UI
        getBlindAccountData()
        _view_blind_account = ViewBlindAccountsOrReceipt(this,"blind_account", _layout_blind_account,_data_blind_accounts)

        // 提交事件
        layout_submit_button_from_blind_transfer.setOnClickListener {
            onSubmit()
        }

        // 返回事件
        layout_back_from_blind_transfer.setOnClickListener { finish() }

    }

    // 获取隐私收据数据
    private fun getBlindReceiptData(){
        val data = JSONObject().apply {
            put("address","收据 #1D52C8C6")
            put("quantity","100")
            put("operation","移除")
        }
        for(i in 0 until 10){
            _data_blind_receipt.put(data)
        }
    }

    // 获取隐私账号数据
    private fun getBlindAccountData(){
        val data = JSONObject().apply {
            put("address","TEST7UPXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
            put("quantity","100")
            put("operation","移除")
        }
        for(i in 0 until 10){
            _data_blind_accounts.put(data)
        }
    }

    private fun onSubmit(){

    }
}
