package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.Switch
import bitshares.OtcManager
import bitshares.isTrue
import kotlinx.android.synthetic.main.activity_otc_mc_payment_methods.*
import org.json.JSONObject

class ActivityOtcMcPaymentMethods : BtsppActivity() {

    private var _aliPaySwitch = false
    private var _bankcardPaySwitch = false
    private var _disableSwitchEvent = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_payment_methods)
        //  设置全屏
        setFullScreen()

        ////  获取参数
        //val args = btspp_args_as_JSONObject()
        //val auth_info = args.getJSONObject("auth_info")
        //val merchant_detail = args.getJSONObject("merchant_detail")

        //  支付宝
        switch_alipay_from_otc_payment_methods.visibility = View.INVISIBLE
        switch_bankcard_from_otc_payment_methods.visibility = View.INVISIBLE

        layout_back_from_otc_mc_payment_methods.setOnClickListener { finish() }

        //  查询
        queryPaymentMethods()
    }

    private fun onQueryPaymentMethodsResponsed(responsed: JSONObject?) {
        val data = responsed?.getJSONObject("data")
        if (data != null) {
            _aliPaySwitch = data.isTrue("aliPaySwitch")
            _bankcardPaySwitch = data.isTrue("bankcardPaySwitch")
        }

        //  支付宝
        switch_alipay_from_otc_payment_methods.visibility = View.VISIBLE
        switch_alipay_from_otc_payment_methods.isChecked = _aliPaySwitch
        switch_alipay_from_otc_payment_methods.setOnCheckedChangeListener { switch, selected: Boolean ->
            onSwitchClicked(OtcManager.EOtcPaymentMethodType.eopmt_alipay, selected, switch as Switch)
        }

        //  银行卡
        switch_bankcard_from_otc_payment_methods.visibility = View.VISIBLE
        switch_bankcard_from_otc_payment_methods.isChecked = _bankcardPaySwitch
        switch_bankcard_from_otc_payment_methods.setOnCheckedChangeListener { switch, selected: Boolean ->
            onSwitchClicked(OtcManager.EOtcPaymentMethodType.eopmt_bankcard, selected, switch as Switch)
        }
    }

    private fun queryPaymentMethods() {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        otc.queryMerchantPaymentMethods(otc.getCurrentBtsAccount()).then {
            mask.dismiss()
            onQueryPaymentMethodsResponsed(it as? JSONObject)
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

    private fun onSwitchClicked(tag: OtcManager.EOtcPaymentMethodType, selected: Boolean, switch: Switch) {
        if (_disableSwitchEvent) {
            return
        }
        var newAliPaySwitch: Boolean? = null
        var newBankcardPaySwitch: Boolean? = null
        when (tag) {
            OtcManager.EOtcPaymentMethodType.eopmt_alipay -> {
                newAliPaySwitch = selected
                if (!selected && !_bankcardPaySwitch) {
                    _disableSwitchEvent = true
                    switch.isChecked = !selected
                    _disableSwitchEvent = false
                    showToast(resources.getString(R.string.kOtcMcPmSubmitTipCannotCloseAll))
                    return
                }
            }
            OtcManager.EOtcPaymentMethodType.eopmt_bankcard -> {
                newBankcardPaySwitch = selected
                if (!selected && !_aliPaySwitch) {
                    _disableSwitchEvent = true
                    switch.isChecked = !selected
                    _disableSwitchEvent = false
                    showToast(resources.getString(R.string.kOtcMcPmSubmitTipCannotCloseAll))
                    return
                }
            }
            else -> {
                assert(false)
            }
        }

        //  先解锁
        guardWalletUnlocked(true) { unlocked ->
            if (unlocked) {
                val otc = OtcManager.sharedOtcManager()
                val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
                mask.show()
                otc.updateMerchantPaymentMethods(otc.getCurrentBtsAccount(), newAliPaySwitch, newBankcardPaySwitch).then {
                    mask.dismiss()
                    if (newAliPaySwitch != null) {
                        _aliPaySwitch = selected
                        if (selected) {
                            showToast(resources.getString(R.string.kOtcMcPmSubmitTipEnableAlipay))
                        } else {
                            showToast(resources.getString(R.string.kOtcMcPmSubmitTipDisableAlipay))
                        }
                    }
                    if (newBankcardPaySwitch != null) {
                        _bankcardPaySwitch = selected
                        if (selected) {
                            showToast(resources.getString(R.string.kOtcMcPmSubmitTipEnableBankcardPay))
                        } else {
                            showToast(resources.getString(R.string.kOtcMcPmSubmitTipDisableBankcardPay))
                        }
                    }
                    return@then null
                }.catch { err ->
                    mask.dismiss()
                    otc.showOtcError(this, err)
                    _disableSwitchEvent = true
                    switch.isChecked = !selected
                    _disableSwitchEvent = false
                }
            } else {
                _disableSwitchEvent = true
                switch.isChecked = !selected
                _disableSwitchEvent = false
            }
        }

        //  end
    }
}
