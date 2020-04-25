package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.LinearLayout
import bitshares.deleteIf
import bitshares.dp
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_select_blind_balance.*
import org.json.JSONArray
import org.json.JSONObject
import com.orhanobut.logger.Logger

class ActivitySelectBlindBalance : BtsppActivity() {

    lateinit var _layout_receipt_list: LinearLayout
    lateinit var _data_receipt: JSONArray
    lateinit var _current_symbol: String
    lateinit var _selected_receipts: JSONArray

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_select_blind_balance)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()


        // 初始化成员
        _layout_receipt_list = layout_receipt_list_from_select_blind_balance

        _data_receipt = JSONArray()
        _selected_receipts = JSONArray()

        _current_symbol = "TEST"

        getData()
        refreshUI()

        // 确认提交按钮事件
        layout_submit_button_from_select_blind_balance.setOnClickListener {
            onSubmit()
        }

        // 返回事件
        layout_back_from_select_blind_balance.setOnClickListener { finish() }

    }

    fun onSelectReceipt(select_index: Int, checked: Boolean){
        val receipt = _data_receipt.getJSONObject(select_index)
        if (checked){
            _selected_receipts.put(receipt.getString("id"))
        } else {
            // Todo 删除选中的
            _selected_receipts = _selected_receipts.deleteIf<String> {
                return@deleteIf receipt.getString("id") == it!!
            }
        }
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

            val cell = ViewBlindReceiptCell(this,data,_current_symbol,index,true){ index: Int, checked: Boolean ->
                onSelectReceipt(index, checked)
            }

            _layout_receipt_list.addView(cell)
            _layout_receipt_list.addView(ViewLine(this, margin_top = 8.dp))

            index++
        }
    }

    private fun onSubmit(){
        Logger.d(_selected_receipts)
    }
}
