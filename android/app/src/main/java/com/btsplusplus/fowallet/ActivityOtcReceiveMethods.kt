package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.OtcManager
import bitshares.Promise
import bitshares.forEach
import bitshares.toList
import kotlinx.android.synthetic.main.activity_otc_payment_list.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityOtcReceiveMethods : BtsppActivity() {

    private lateinit var _auth_info: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_normal_user
    private var _data_array: JSONArray? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_payment_list)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _auth_info = args.getJSONObject("auth_info")
        _user_type = args.get("user_type") as OtcManager.EOtcUserType

        //  添加支付方式
        button_add_payment_method_from_merchant_payment_list.setOnClickListener { onAddPaymentMethodClicked() }

        //  返回
        layout_back_from_otc_merchant_payment_list.setOnClickListener { finish() }

        //  查询
        queryPaymentMethods()
    }

    private fun onQueryPaymentMethodsResponsed(responsed: JSONObject?) {
        _data_array = responsed?.optJSONArray("data")
        refreshUI(_data_array)
    }

    private fun queryPaymentMethods() {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        otc.queryReceiveMethods(otc.getCurrentBtsAccount()).then {
            mask.dismiss()
            onQueryPaymentMethodsResponsed(it as? JSONObject)
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

    private fun refreshUI(data_array: JSONArray?) {
        val layout_payment_lists = layout_payment_lists_from_orc_merchant
        layout_payment_lists.removeAllViews()
        if (data_array == null || data_array.length() == 0) {
            layout_payment_lists.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kOtcRmLabelEmpty)))
        } else {
            data_array.forEach<JSONObject> {
                val pm_item = it!!
                val view = ViewOtcMerchantPaymentCell(this, pm_item)
                view.setOnClickListener {
                    onReceiveMethodCellClicked(pm_item)
                }
                layout_payment_lists.addView(view)
            }
        }
    }

    private fun onReceiveMethodCellClicked(pm_item: JSONObject) {
        val enable_or_disable = if (pm_item.getInt("status") == OtcManager.EOtcPaymentMethodStatus.eopms_enable.value) {
            resources.getString(R.string.kOtcPmActionBtnDisable)
        } else {
            resources.getString(R.string.kOtcPmActionBtnEnable)
        }
        //  操作选项 TODO:2.9 lang only for android title
        ViewSelector.show(this, "请选择要执行的操作", arrayOf(enable_or_disable, resources.getString(R.string.kOtcPmActionBtnDelete))) { index: Int, _: String ->
            if (index == 0) {
                //  启用 or 禁用
                guardWalletUnlocked(true) { unlocked ->
                    if (unlocked) {
                        _onActionEnableOrDisableClicked(pm_item)
                    }
                }
            } else {
                //  删除
                _onActionDeleteClicked(pm_item)
            }
        }
    }

    private fun _onActionEnableOrDisableClicked(pm_item: JSONObject) {
        val new_status = if (pm_item.getInt("status") == OtcManager.EOtcPaymentMethodStatus.eopms_enable.value) {
            OtcManager.EOtcPaymentMethodStatus.eopms_disable
        } else {
            OtcManager.EOtcPaymentMethodStatus.eopms_enable
        }
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        otc.editPaymentMethods(otc.getCurrentBtsAccount(), new_status, pm_item.getInt("id")).then {
            mask.dismiss()
            //  刷新data & UI
            pm_item.put("status", new_status.value)
            refreshUI(_data_array)
            //  提示信息
            if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                if (new_status == OtcManager.EOtcPaymentMethodStatus.eopms_enable) {
                    showToast(resources.getString(R.string.kOtcRmActionTipsEnabled))
                } else {
                    showToast(resources.getString(R.string.kOtcRmActionTipsDisabled))
                }
            } else {
                if (new_status == OtcManager.EOtcPaymentMethodStatus.eopms_enable) {
                    showToast(resources.getString(R.string.kOtcMcRmActionTipsEnabled))
                } else {
                    showToast(resources.getString(R.string.kOtcMcRmActionTipsDisabled))
                }
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

    private fun _onActionDeleteClicked(pm_item: JSONObject) {
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), resources.getString(R.string.kOtcPmActionTipsDeleteConfirm)).then {
            if (it != null && it as Boolean) {
                guardWalletUnlocked(true) { unlocked ->
                    if (unlocked) {
                        _execActionDeleteCore(pm_item)
                    }
                }
            }
        }
    }

    private fun _execActionDeleteCore(pm_item: JSONObject) {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        otc.delPaymentMethods(otc.getCurrentBtsAccount(), pm_item.getInt("id")).then {
            mask.dismiss()
            //  提示
            showToast(resources.getString(R.string.kOtcPmActionTipsDeleted))
            //  刷新
            queryPaymentMethods()
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

    private fun onAddPaymentMethodClicked() {
        val asset_list = JSONArray().apply {
            put(resources.getString(R.string.kOtcAdPmNameBankCard))
            put(resources.getString(R.string.kOtcAdPmNameAlipay))
        }
        //  TODO:2.9 lang
        ViewSelector.show(this, "请选择要添加的收款方式", asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->
            val result_promise = Promise()
            if (index == 0) {
                goTo(ActivityOtcAddBankCard::class.java, true, args = JSONObject().apply {
                    put("auth_info", _auth_info)
                    put("result_promise", result_promise)
                })
            } else if (index == 1) {
                goTo(ActivityOtcAddAlipay::class.java, true, args = JSONObject().apply {
                    put("auth_info", _auth_info)
                    put("result_promise", result_promise)
                })
            } else {
                assert(false)
            }
            result_promise.then { dirty ->
                //  刷新
                if (dirty != null && dirty as Boolean) {
                    queryPaymentMethods()
                }
                return@then null
            }
        }
    }
}
