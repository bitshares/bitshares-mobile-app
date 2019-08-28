package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import bitshares.btsppLogCustom
import bitshares.jsonObjectfromKVS
import kotlinx.android.synthetic.main.activity_scan_account_name.*
import kotlinx.android.synthetic.main.activity_scan_result_private_key.*

class ActivityScanAccountName : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scan_account_name)


        val tv_account_id = findViewById<TextView>(R.id.txt_account_id)
        val tv_account_name = findViewById<TextView>(R.id.txt_account_name)
        val btn_transfer = findViewById<Button>(R.id.button_transfer)
        val btn_detail = findViewById<Button>(R.id.button_view_detail)

        // 返回
        layout_back_from_scan_result_account_name.setOnClickListener {
            finish()
        }

        // 转账
        btn_transfer.setOnClickListener {

        }

        // 查看详情
        btn_detail.setOnClickListener {

        }



    }
}
