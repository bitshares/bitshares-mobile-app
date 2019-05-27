package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_setting_currency.*
import org.json.JSONObject

class ActivitySettingCurrency : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_setting_currency)

        setFullScreen()

        var currEstimateAssetSymbol = SettingManager.sharedSettingManager().getEstimateAssetSymbol()
        val symbolMarkHash = JSONObject()
        val data_array = ChainObjectManager.sharedChainObjectManager().getEstimateUnitList()
        data_array.forEach<JSONObject> {
            val item = it!!

            val layout = ViewUtils.createLinearLayout(this, LinearLayout.LayoutParams.MATCH_PARENT, 34.dp, null, null, LinearLayout.HORIZONTAL, topMargin = 15)

            val tv = TextView(this)
            val tv_layout = ViewUtils.createLinearLayout(this, 0, LinearLayout.LayoutParams.WRAP_CONTENT, 9f, Gravity.CENTER_VERTICAL, null)
            val iv_layout = ViewUtils.createLinearLayout(this, 14f.dp.toInt(), 14f.dp.toInt(), 0.5f, Gravity.CENTER_VERTICAL or Gravity.RIGHT, null)

            tv.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            tv.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

            //  货币单位格式
            val prefix = resources.getString(resources.getIdentifier(item.getString("namekey"), "string", this.packageName))
            val symbol = item.getString("symbol")
            tv.text = "${prefix}(${symbol})"

            //  是否选中
            val iv = ImageView(this)
            iv.setImageResource(R.drawable.ic_btn_check)
            if (symbol == currEstimateAssetSymbol) {
                iv.visibility = View.VISIBLE
            } else {
                iv.visibility = View.INVISIBLE
            }
            symbolMarkHash.put(symbol, iv)

            tv_layout.addView(tv, ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            iv_layout.addView(iv, ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            layout.addView(tv_layout)
            layout.addView(iv_layout)

            val line = ViewUtils.createLine(this)

            layout_wrap_of_currency.addView(layout)
            layout_wrap_of_currency.addView(line)

            //  点击事件
            layout.tag = symbol
            layout.setOnClickListener {
                if (symbol != currEstimateAssetSymbol) {
                    //  变更可见性
                    (symbolMarkHash.get(currEstimateAssetSymbol) as View).visibility = View.INVISIBLE
                    (symbolMarkHash.get(symbol) as View).visibility = View.VISIBLE
                    //  变更设置
                    currEstimateAssetSymbol = symbol
                    SettingManager.sharedSettingManager().setUseConfig(kSettingKey_EstimateAssetSymbol, currEstimateAssetSymbol)
                    //  [统计]
                    btsppLogCustom("selectEstimateAsset", jsonObjectfromKVS("symbol", currEstimateAssetSymbol))
                }
            }
        }

        layout_back_from_setting_currency.setOnClickListener { finish() }
    }
}
