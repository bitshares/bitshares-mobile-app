package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.btsppLogCustom
import bitshares.jsonObjectfromKVS
import kotlinx.android.synthetic.main.activity_scan_result_private_key.*

class ActivityScanResultPrivateKey : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scan_result_private_key)

        val tv_account_id = findViewById<TextView>(R.id.txt_account_id)
        val tv_account_name = findViewById<TextView>(R.id.txt_account_name)
        val tv_private_key_type = findViewById<TextView>(R.id.txt_private_key_type)
        val btn_import = findViewById<Button>(R.id.button_import_private_key)
        val iv_tip_password = findViewById<ImageView>(R.id.tip_password)

        // 返回
        layout_back_from_scan_result_private_key.setOnClickListener {
            finish()
        }

        // 导入
        btn_import.setOnClickListener {

        }

        // 交易密码 tip
        iv_tip_password.setOnClickListener {
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_trading_password"))
            goToWebView(resources.getString(R.string.kVcTitleWhatIsTradePassowrd), "https://btspp.io/qam.html#qa_trading_password")

        }



    }
}
