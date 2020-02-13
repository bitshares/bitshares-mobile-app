package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.EditText
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_otc_mc_asset_transfer.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityOtcMcAssetTransfer : BtsppActivity() {

    private lateinit var _auth_info: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_merchant
    private lateinit var _merchant_detail: JSONObject
    private lateinit var _asset_list: JSONArray
    private lateinit var _curr_merchant_asset: JSONObject
    private lateinit var _full_account_data: JSONObject
    private var _transfer_in = false
    private var _result_promise: Promise? = null
    private var _argsFromTo = JSONObject()
    private var _nCurrBalance = BigDecimal.ZERO

    private lateinit var _tf_amount_watcher: UtilsDigitTextWatcher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_asset_transfer)
        // 设置全屏
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _auth_info = args.getJSONObject("auth_info")
        _user_type = args.get("user_type") as OtcManager.EOtcUserType
        _merchant_detail = args.getJSONObject("merchant_detail")
        _asset_list = args.getJSONArray("asset_list")
        _curr_merchant_asset = args.getJSONObject("curr_merchant_asset")
        _full_account_data = args.getJSONObject("full_account_data")
        _transfer_in = args.getBoolean("transfer_in")
        _result_promise = args.opt("result_promise") as? Promise
        if (_transfer_in) {
            //  个人到商家
            _argsFromTo.put("from", _merchant_detail.getString("btsAccount"))
            _argsFromTo.put("to", _merchant_detail.getString("otcAccount"))
            _argsFromTo.put("bFromIsMerchant", false)
        } else {
            //  商家到个人
            _argsFromTo.put("from", _merchant_detail.getString("otcAccount"))
            _argsFromTo.put("to", _merchant_detail.getString("btsAccount"))
            _argsFromTo.put("bFromIsMerchant", true)
        }
        _nCurrBalance = _genCurrBalance()

        //  设置图标颜色
        val iconcolor = resources.getColor(R.color.theme01_textColorMain)
        img_icon_otc_switch.setColorFilter(iconcolor)

        //  描绘
        _drawUI_all()

        //  事件
        img_icon_otc_switch.setOnClickListener { onSwitchClicked() }
        layout_curr_asset_symbol.setOnClickListener { onSelectAsset() }
        btn_all.setOnClickListener { onTransferAllClicked() }
        btn_submit.setOnClickListener { onTransferClicked() }
        layout_back_from_otc_mc_asset_transfer.setOnClickListener { finish() }

        //  输入框
        val tf = findViewById<EditText>(R.id.tf_amount)
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_curr_merchant_asset.getInt("kExtPrecision"))
        tf.addTextChangedListener(_tf_amount_watcher)
        _tf_amount_watcher.on_value_changed(::onAmountChanged)
    }

    /**
     *  (private) 转账数量发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        _drawUI_balance(_nCurrBalance < Utils.auxGetStringDecimalNumberValue(str_amount))
    }

    private fun onSwitchClicked() {
        //  交换FROM TO
        _argsFromTo.put("bFromIsMerchant", !_argsFromTo.getBoolean("bFromIsMerchant"))
        val tmp = _argsFromTo.getString("from")
        _argsFromTo.put("from", _argsFromTo.getString("to"))
        _argsFromTo.put("to", tmp)

        //  刷新余额
        _nCurrBalance = _genCurrBalance()
        _tf_amount_watcher.set_new_text("")

        //  刷新UI
        _drawUI_switchCell()
        _drawUI_balance(false)
        _drawUI_tips()
    }

    private fun onSelectAsset() {
        val asset_list = JSONArray()
        _asset_list.forEach<JSONObject> { asset_list.put(it!!.getString("assetSymbol")) }
        ViewSelector.show(this, resources.getString(R.string.kOtcMcAssetSubmitAskSelectTransferAsset), asset_list.toList<String>().toTypedArray()) { index: Int, _: String ->
            val select_asset_symbol = asset_list.getString(index)
            val current_asset_symbol = _curr_merchant_asset.getString("assetSymbol")
            if (current_asset_symbol != select_asset_symbol) {
                _curr_merchant_asset = _asset_list.getJSONObject(index)
                //  切换资产后重新输入（变更输入框精度）
                _nCurrBalance = _genCurrBalance()
                _tf_amount_watcher.set_new_text("")
                _tf_amount_watcher.set_precision(_curr_merchant_asset.getInt("kExtPrecision"))
                _drawUI_assetSymbol()
                _drawUI_balance(false)
            }
        }
    }

    /**
     *  切换资产 or 交换FROM/TO的时候需要更新余额
     */
    private fun _genCurrBalance(): BigDecimal {
        if (_argsFromTo.getBoolean("bFromIsMerchant")) {
            return BigDecimal(_curr_merchant_asset.getString("available"))
        } else {
            //  链上余额
            return ModelUtils.findAssetBalance(_full_account_data, _curr_merchant_asset.getJSONObject("kExtChainAsset"))
        }
    }

    private fun _drawUI_all() {
        _drawUI_switchCell()
        _drawUI_assetSymbol()
        _drawUI_balance(false)
        _drawUI_tips()
    }

    private fun _drawUI_switchCell() {
        if (_argsFromTo.getBoolean("bFromIsMerchant")) {
            tv_from_title.text = resources.getString(R.string.kOtcMcAssetTransferFromToMerchantAccount)
            tv_to_title.text = resources.getString(R.string.kOtcMcAssetTransferFromToUserAccount)
        } else {
            tv_from_title.text = resources.getString(R.string.kOtcMcAssetTransferFromToUserAccount)
            tv_to_title.text = resources.getString(R.string.kOtcMcAssetTransferFromToMerchantAccount)
        }
        tv_from_value.text = _argsFromTo.getString("from")
        tv_to_value.text = _argsFromTo.getString("to")
    }

    private fun _drawUI_assetSymbol() {
        tv_curr_asset_symbol.text = _curr_merchant_asset.getString("assetSymbol")
        tv_tailer_asset_symbol.text = _curr_merchant_asset.getString("assetSymbol")
    }

    private fun _drawUI_balance(not_enough: Boolean) {
        val symbol = _curr_merchant_asset.getString("assetSymbol")
        if (not_enough) {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_nCurrBalance.toPlainString()} $symbol(${resources.getString(R.string.kOtcMcAssetTransferBalanceNotEnough)})"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_nCurrBalance.toPlainString()} $symbol"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
    }

    private fun _drawUI_tips() {
        if (_argsFromTo.getBoolean("bFromIsMerchant")) {
            tv_tips.text = resources.getString(R.string.kOtcMcAssetCellTipsTransferOut)
        } else {
            tv_tips.text = resources.getString(R.string.kOtcMcAssetCellTipsTransferIn)
        }
    }

    private fun onTransferAllClicked() {
        val tf = findViewById<EditText>(R.id.tf_amount)
        tf.setText(_nCurrBalance.toPlainString())
        tf.setSelection(tf.text.toString().length)
        //  onAmountChanged 会自动触发
    }

    private fun onTransferClicked() {
        val n_amount = Utils.auxGetStringDecimalNumberValue(tf_amount.text.toString())
        if (n_amount <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kOtcMcAssetSubmitTipPleaseInputAmount))
            return
        }

        if (_nCurrBalance < n_amount) {
            showToast(resources.getString(R.string.kOtcMcAssetSubmitTipBalanceNotEnough))
            return
        }

        if (_argsFromTo.getBoolean("bFromIsMerchant")) {
            val value = String.format(resources.getString(R.string.kOtcMcAssetSubmitAskTransferOut), n_amount.toPlainString(), _curr_merchant_asset.getString("assetSymbol"))
            UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), value).then {
                if (it != null && it as Boolean) {
                    guardWalletUnlocked(true) { unlocked ->
                        if (unlocked) {
                            _execTransferOut(n_amount)
                        }
                    }
                }
            }
        } else {
            val value = String.format(resources.getString(R.string.kOtcMcAssetSubmitAskTransferIn), n_amount.toPlainString(), _curr_merchant_asset.getString("assetSymbol"))
            UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), value).then {
                if (it != null && it as Boolean) {
                    guardWalletUnlocked(true) { unlocked ->
                        if (unlocked) {
                            _execTransferIn(n_amount)
                        }
                    }
                }
            }
        }
    }

    private fun _execTransferOut(n_amount: BigDecimal) {
        //  获取用户自身的KEY进行签名。
        val walletMgr = WalletManager.sharedWalletManager()
        assert(!walletMgr.isLocked())
        val active_permission = walletMgr.getWalletAccountInfo()!!.getJSONObject("account").getJSONObject("active")
        val sign_pub_keys = walletMgr.getSignKeys(active_permission, false)
        //  TODO:2.9 手续费不足判断？
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        BitsharesClientManager.sharedBitsharesClientManager().simpleTransfer(this,
                _argsFromTo.getString("from"),
                _argsFromTo.getString("to"),
                _curr_merchant_asset.getString("assetSymbol"),
                n_amount.toPlainString(), null, null, sign_pub_keys, false).then {
            val tx_data = it as JSONObject
            val err = tx_data.optString("err", null)
            if (err != null) {
                //  构造签名数据结构错误
                mask.dismiss()
                showToast(err)
            } else {
                //  转账签名成功
                val tx = tx_data.getJSONObject("tx")
                //  调用平台API进行转出操作
                val otc = OtcManager.sharedOtcManager()
                otc.queryMerchantAssetExport(otc.getCurrentBtsAccount(), tx).then {
                    mask.dismiss()
                    showToast(resources.getString(R.string.kOtcMcAssetSubmitTipTransferOutOK))
                    //  返回上一个界面并刷新
                    _result_promise?.resolve(true)
                    _result_promise = null
                    finish()
                    return@then null
                }.catch { err ->
                    mask.dismiss()
                    otc.showOtcError(this, err)
                }
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            showGrapheneError(err)
        }
    }

    private fun _execTransferIn(n_amount: BigDecimal) {
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        BitsharesClientManager.sharedBitsharesClientManager().simpleTransfer(this,
                _argsFromTo.getString("from"),
                _argsFromTo.getString("to"),
                _curr_merchant_asset.getString("assetSymbol"),
                n_amount.toPlainString(), null, null, null, true).then {
            mask.dismiss()
            val data = it as? JSONObject
            val err = data?.optString("err", null)
            if (err != null) {
                showToast(err)
            } else {
                showToast(resources.getString(R.string.kOtcMcAssetSubmitTipTransferInOK))
                //  返回上一个界面并刷新
                _result_promise?.resolve(true)
                _result_promise = null
                finish()
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            showGrapheneError(err)
        }
    }
}
