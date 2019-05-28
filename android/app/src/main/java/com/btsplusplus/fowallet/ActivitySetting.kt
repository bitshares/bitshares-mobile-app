package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.LangManager
import bitshares.Promise
import bitshares.SettingManager
import bitshares.jsonObjectfromKVS
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_setting.*

class ActivitySetting : BtsppActivity() {

    private lateinit var _result_promise: Promise

    override fun onResume() {
        super.onResume()
        //  初始化默认值
        _refreshUI()
    }

    override fun onBackClicked(result: Any?) {
        _result_promise.resolve(true)
        super.onBackClicked(result)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_setting)

        //  获取参数 / get params
        val args = btspp_args_as_JSONObject()
        _result_promise = args.get("result_promise") as Promise

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        layout_back_from_setting.setOnClickListener { onBackClicked(false) }

        layout_language_from_setting.setOnClickListener {
            val saveCurrLangCode = LangManager.sharedLangManager().currLangCode
            val result_promise = Promise()
            goTo(ActivitySettingLanguage::class.java, true, args = jsonObjectfromKVS("result_promise", result_promise))
            result_promise.then {
                if (LangManager.sharedLangManager().currLangCode != saveCurrLangCode) {
                    //  reset arguments
                    recreate()
                }
            }
        }

        layout_currency_from_setting.setOnClickListener { goTo(ActivitySettingCurrency::class.java, true) }
    }

    private fun _refreshUI() {
        _refresh_language()
        _refresh_currency()
    }

    private fun _refresh_language() {
        label_txt_language.text = LangManager.sharedLangManager().getCurrentLanguageName(this)
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
