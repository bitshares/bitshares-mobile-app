package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import android.widget.TextView
import kotlinx.android.synthetic.main.activity_asset_op_global_settle.*

class ActivityAssetOpGlobalSettle : BtsppActivity() {

    lateinit var _et_amount_symbol: TextView
    lateinit var _et_amount: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_op_global_settle)

        // 设置全屏
        setFullScreen()

        _et_amount_symbol = tv_asset_symbol_from_global_settle
        _et_amount = et_amount_from_global_settle

        // 预测为真 按钮点击事件
        tv_forecast_true_from_global_settle.setOnClickListener { onForecastTrueButtonClicked() }

        // 预测为假 按钮点击事件
        tv_forecast_fake_from_global_settle.setOnClickListener { onForecastFakeButtonClicked() }

        // 返回按钮事件
        layout_back_from_global_settle.setOnClickListener { finish() }

        // 提交按钮事件
        button_submit_from_global_settle.setOnClickListener { onSubmitBtnClicked() }
    }

    private fun onForecastTrueButtonClicked(){

    }

    private fun onForecastFakeButtonClicked(){

    }

    private fun onSubmitBtnClicked(){

    }
}
