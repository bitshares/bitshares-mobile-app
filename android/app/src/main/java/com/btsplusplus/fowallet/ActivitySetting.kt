package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.SettingManager
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_setting.*

class ActivitySetting : BtsppActivity() {

    override fun onResume() {
        super.onResume()
        //  初始化默认值
        _refresh_currency()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_setting)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        layout_back_from_setting.setOnClickListener { finish() }

        layout_currency_from_setting.setOnClickListener { goTo(ActivitySettingCurrency::class.java, true) }
    }

    /**
     * 显示当前计价方式
     */
    private fun _refresh_currency() {
        val assetSymbol = SettingManager.sharedSettingManager().getEstimateAssetSymbol()
        val currency = ChainObjectManager.sharedChainObjectManager().getEstimateUnitBySymbol(assetSymbol)
        label_txt_currency.text = resources.getString(resources.getIdentifier(currency.getString("namekey"), "string", this.packageName))
    }
}
