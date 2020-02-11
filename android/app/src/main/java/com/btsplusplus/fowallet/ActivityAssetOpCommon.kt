package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.EditText
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_asset_op_common.*
import org.json.JSONObject
import java.math.BigDecimal

class ActivityAssetOpCommon : BtsppActivity() {

    private lateinit var _op_extra_args: JSONObject
    private lateinit var _current_asset: JSONObject
    private lateinit var _full_account_data: JSONObject
    private var _result_promise: Promise? = null

    private var _op_type = EBitsharesAssetOpKind.ebaok_settle
    private var _nCurrBalance = BigDecimal.ZERO
    private lateinit var _tf_amount_watcher: UtilsDigitTextWatcher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_op_common)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _op_extra_args = args.getJSONObject("op_extra_args")
        _current_asset = args.getJSONObject("current_asset")
        _full_account_data = args.getJSONObject("full_account_data")
        _result_promise = args.get("result_promise") as? Promise

        _op_type = _op_extra_args.get("kOpType") as EBitsharesAssetOpKind
        _nCurrBalance = ModelUtils.findAssetBalance(_full_account_data, _current_asset)

        //  初始化UI
        drawUI_title()
        drawUI_once()
        drawUI_currAsset()
        drawUI_balance(false)

        //  事件 - 全部
        btn_tf_tailer_all.setOnClickListener { onSelectAllClicked() }

        //  事件 - 选择资产
        iv_select_asset_right_arrow.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        layout_select_asset_from_assets_op_common.setOnClickListener { onSelectAsset() }

        //  事件 - 提交
        btn_op_submit.setOnClickListener { onSubmitClicked() }

        //  事件 - 返回
        layout_back_from_assets_op_common.setOnClickListener { finish() }

        //  输入框
        val tf = findViewById<EditText>(R.id.tf_amount)
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_current_asset.getInt("precision"))
        tf.addTextChangedListener(_tf_amount_watcher)
        _tf_amount_watcher.on_value_changed(::onAmountChanged)
    }

    private fun drawUI_title() {
        findViewById<TextView>(R.id.title).text = when (_op_type) {
            EBitsharesAssetOpKind.ebaok_settle -> resources.getString(R.string.kVcTitleAssetOpSettle)
            EBitsharesAssetOpKind.ebaok_reserve -> resources.getString(R.string.kVcTitleAssetOpReserve)
            else -> ""
        }
    }

    private fun drawUI_once() {
        tf_amount.hint = _op_extra_args.optString("kMsgAmountPlaceholder")
        btn_op_submit.text = _op_extra_args.optString("kMsgBtnName")
        tv_ui_msg.text = _op_extra_args.optString("kMsgTips")
    }

    private fun drawUI_currAsset() {
        tv_asset_symbol.text = _current_asset.getString("symbol")
        tv_tf_tailer_asset_symbol.text = _current_asset.getString("symbol")
    }

    private fun drawUI_balance(not_enough: Boolean) {
        val symbol = _current_asset.getString("symbol")
        if (not_enough) {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_nCurrBalance.toPlainString()} $symbol(${resources.getString(R.string.kOtcMcAssetTransferBalanceNotEnough)})"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_nCurrBalance.toPlainString()} $symbol"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
    }

    /**
     *  (private) 转账数量发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        drawUI_balance(_nCurrBalance < Utils.auxGetStringDecimalNumberValue(str_amount))
    }

    /**
     *  (private) 选择全部数量
     */
    private fun onSelectAllClicked() {
        val tf = findViewById<EditText>(R.id.tf_amount)
        tf.setText(_nCurrBalance.toPlainString())
        tf.setSelection(tf.text.toString().length)
        //  onAmountChanged 会自动触发
    }

    /**
     *  事件 - 点击选择资产
     */
    private fun onSelectAsset() {
        val kSearchType = when (_op_type) {
            EBitsharesAssetOpKind.ebaok_settle -> ENetworkSearchType.enstAssetSmart
            EBitsharesAssetOpKind.ebaok_reserve -> ENetworkSearchType.enstAssetUIA
            else -> ENetworkSearchType.enstAssetAll
        }

        //  TODO:5.0 考虑默认备选列表？
        TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
            last_activity.goTo(ActivityAssetOpCommon::class.java, true, back = true)
            //  选择完毕
            val new_id = it.getString("id")
            val old_id = _current_asset.getString("id")
            if (new_id != old_id) {
                _current_asset = it
                //  切换资产后重新输入
                _nCurrBalance = ModelUtils.findAssetBalance(_full_account_data, _current_asset)
                _tf_amount_watcher.clear()
                drawUI_currAsset()
                drawUI_balance(false)
            }
        }

        val title = resources.getString(R.string.kVcTitleSearchAssets)
        goTo(ActivityAccountQueryBase::class.java, true, args = JSONObject().apply {
            put("kSearchType", kSearchType)
            put("kTitle", title)
        })
    }

    /**
     *  事件 - 点击提交操作
     */
    private fun onSubmitClicked() {
        val n_amount = Utils.auxGetStringDecimalNumberValue(_tf_amount_watcher.get_tf_string())

        if (n_amount <= BigDecimal.ZERO) {
            showToast(_op_extra_args.optString("kMsgSubmitInputValidAmount"))
            return
        }

        if (_nCurrBalance < n_amount) {
            showToast(resources.getString(R.string.kOtcMcAssetSubmitTipBalanceNotEnough))
            return
        }

        when (_op_type) {
            EBitsharesAssetOpKind.ebaok_settle -> {
                val value = String.format(resources.getString(R.string.kVcAssetOpSubmitAskSettle), n_amount.toPlainString(), _current_asset.getString("symbol"))
                UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kVcHtlcMessageTipsTitle), value).then {
                    if (it != null && it as Boolean) {
                        guardWalletUnlocked(false) { unlocked ->
                            if (unlocked) {
                                _execAssetSettleCore(n_amount)
                            }
                        }
                    }
                }
            }
            EBitsharesAssetOpKind.ebaok_reserve -> {
                val value = String.format(resources.getString(R.string.kVcAssetOpSubmitAskReserve), n_amount.toPlainString(), _current_asset.getString("symbol"))
                UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kVcHtlcMessageTipsTitle), value).then {
                    if (it != null && it as Boolean) {
                        guardWalletUnlocked(false) { unlocked ->
                            if (unlocked) {
                                _execAssetReserveCore(n_amount)
                            }
                        }
                    }
                }
            }
            else -> assert(false)
        }
    }

    /**
     *  (private) 执行清算操作
     */
    private fun _execAssetSettleCore(n_amount: BigDecimal) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val op_account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")

        val n_amount_pow = n_amount.multiplyByPowerOf10(_current_asset.getInt("precision"))
        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", chainMgr.grapheneCoreAssetID)
            })
            put("account", op_account.getString("id"))
            put("amount", JSONObject().apply {
                put("amount", n_amount_pow.toPlainString())
                put("asset_id", _current_asset.getString("id"))
            })
        }

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_asset_settle, false, false,
                op, op_account) { isProposal, _ ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
            BitsharesClientManager.sharedBitsharesClientManager().assetSettle(op).then {
                mask.dismiss()
                showToast(_op_extra_args.optString("kMsgSubmitOK"))
                //  [统计]
                btsppLogCustom("txAssetSettleFullOK", jsonObjectfromKVS("account", op_account.getString("id")))
                //  返回上一个界面并刷新
                _result_promise?.resolve(true)
                _result_promise = null
                finish()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txAssetSettleFailed", jsonObjectfromKVS("account", op_account.getString("id")))
            }
        }
    }

    /**
     *  (private) 执行销毁操作
     */
    private fun _execAssetReserveCore(n_amount: BigDecimal) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val op_account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")

        val n_amount_pow = n_amount.multiplyByPowerOf10(_current_asset.getInt("precision"))
        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", chainMgr.grapheneCoreAssetID)
            })
            put("payer", op_account.getString("id"))
            put("amount_to_reserve", JSONObject().apply {
                put("amount", n_amount_pow.toPlainString())
                put("asset_id", _current_asset.getString("id"))
            })
        }

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_asset_reserve, false, false,
                op, op_account) { isProposal, _ ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
            BitsharesClientManager.sharedBitsharesClientManager().assetReserve(op).then {
                mask.dismiss()
                showToast(_op_extra_args.optString("kMsgSubmitOK"))
                //  [统计]
                btsppLogCustom("txAssetReserveFullOK", jsonObjectfromKVS("account", op_account.getString("id")))
                //  返回上一个界面并刷新
                _result_promise?.resolve(true)
                _result_promise = null
                finish()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txAssetReserveFailed", jsonObjectfromKVS("account", op_account.getString("id")))
            }
        }
    }
}
