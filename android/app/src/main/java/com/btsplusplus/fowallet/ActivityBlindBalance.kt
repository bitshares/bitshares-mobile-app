package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import bitshares.dp
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_blind_balance.*
import kotlinx.android.synthetic.main.activity_blind_transfer.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityBlindBalance : BtsppActivity() {

    lateinit var _layout_receipt_list: LinearLayout
    lateinit var _data_receipt: JSONArray
    lateinit var _current_symbol: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_balance)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化成员
        _layout_receipt_list = layout_receipt_list_from_blind_balance

        _data_receipt = JSONArray()

        _current_symbol = "TEST"

        getData()
        refreshUI()

        // 新增按钮事件
        button_add_from_blind_balance.setOnClickListener {
            onAddbuttonClicked()
        }

        // 返回事件
        layout_back_from_blind_balance.setOnClickListener { finish() }

        // 新增事件
        button_add_from_blind_balance.setOnClickListener {  }
    }

    private fun getData(){
        val data = JSONObject().apply {
            put("number","8FDF4397")
            put("id","TEST7UPXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
            put("amount","14")
        }
        for(i in 0 until 10){
            _data_receipt.put(data)
        }
    }

    private fun refreshUI(){
        var index = 0
        _data_receipt.forEach<JSONObject> {
            val data = it!!

            _layout_receipt_list.addView(ViewBlindReceiptCell(this,data,_current_symbol,index,false))
            _layout_receipt_list.addView(ViewLine(this, margin_top = 8.dp))

            index++
        }
    }

    private fun onAddbuttonClicked(){

    }
}
