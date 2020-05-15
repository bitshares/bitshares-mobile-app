package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.EditText
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_asset_op_global_settle.*
import org.json.JSONObject
import java.math.BigDecimal

class ActivityAssetOpGlobalSettle : BtsppActivity() {

    private lateinit var _curr_selected_asset: JSONObject   //  当前选中资产
    private lateinit var _bitasset_data: JSONObject
    private var _result_promise: Promise? = null

    private lateinit var _tf_price_watcher: UtilsDigitTextWatcher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_op_global_settle)

        // 设置全屏
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _curr_selected_asset = args.getJSONObject("current_asset")
        _bitasset_data = args.getJSONObject("bitasset_data")
        _result_promise = args.opt("result_promise") as? Promise

        //  描绘UI
        _draw_ui_curr_asset()
        _draw_ui_tailer_asset_symbol()
        _draw_ui_prediction()

        //  返回按钮事件
        layout_back_from_global_settle.setOnClickListener { finish() }

        //  提交按钮事件
        button_submit_from_global_settle.setOnClickListener { onSubmitBtnClicked() }

        //  输入框 TODO:7.0 如果切换资产则需要切换精度
        val tf = findViewById<EditText>(R.id.tf_price)
        _tf_price_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(8)
        tf.addTextChangedListener(_tf_price_watcher)
        _tf_price_watcher.on_value_changed(::onPriceChanged)
    }

    /**
     *  (private) 价格发生变化。
     */
    private fun onPriceChanged(str_price: String) {
        //  ...
    }

    private fun _draw_ui_curr_asset() {
        tv_curr_select_asset_symbol.text = _curr_selected_asset.getString("symbol")
    }

    private fun _draw_ui_tailer_asset_symbol() {
        val back_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(_bitasset_data.getJSONObject("options").getString("short_backing_asset"))
        tv_tailer_asset_symbol.text = back_asset.getString("symbol")
    }

    private fun _draw_ui_prediction() {
        if (_bitasset_data.isTrue("is_prediction_market")) {
            //  预测为真 按钮点击事件
            btn_pmas_true.setOnClickListener { onPredictionTrueButtonClicked() }

            //  预测为假 按钮点击事件
            btn_pmas_false.setOnClickListener { onPredictionFakeButtonClicked() }
        } else {
            tv_tailer_separator.visibility = View.GONE
            btn_pmas_true.visibility = View.GONE
            btn_pmas_false.visibility = View.GONE
        }
    }

    /**
     *  事件 - 真值按钮
     */
    private fun onPredictionTrueButtonClicked() {
        findViewById<EditText>(R.id.tf_price).let { tf ->
            tf.setText("1")
            tf.setSelection(tf.text.toString().length)
        }
    }

    /**
     *  事件 - 假值按钮
     */
    private fun onPredictionFakeButtonClicked() {
        findViewById<EditText>(R.id.tf_price).let { tf ->
            tf.setText("0")
            tf.setSelection(tf.text.toString().length)
        }
    }

    /**
     *  事件 - 提交
     */
    private fun onSubmitBtnClicked() {
        val str_price = _tf_price_watcher.get_tf_string()
        if (str_price.isEmpty()) {
            showToast(resources.getString(R.string.kVcAssetOpGsSubmitTipsPleaseInputPrice))
            return
        }
        val n_price = Utils.auxGetStringDecimalNumberValue(str_price)
        val back_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(_bitasset_data.getJSONObject("options").getString("short_backing_asset"))

        val value = String.format(resources.getString(R.string.kVcAssetOpGsSubmitAskForGs), n_price.toPlainString(), back_asset.getString("symbol"), _curr_selected_asset.getString("symbol"))
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kVcHtlcMessageTipsTitle), value).then {
            if (it != null && it as Boolean) {
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        _execAssetGlobalSettleCore(n_price, back_asset)
                    }
                }
            }
        }
    }

    private fun _execAssetGlobalSettleCore(n_price: BigDecimal, back_asset: JSONObject) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val op_account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")

        val precision_back_asset = back_asset.getInt("precision")
        val precision_settle_asset = _curr_selected_asset.getInt("precision")

        //  REMARK：价格精度保留最低8位小数
        val final_back_precision = Math.max(precision_back_asset, 8)
        val n_amount_back = n_price.multiplyByPowerOf10(final_back_precision)

        //  待清算资产精度 = 自身精度 + 背书资产额外增加的精度(>=0)。
        val final_settle_precision = precision_settle_asset + (final_back_precision - precision_back_asset)
        val n_amount_settle = BigDecimal.ONE.multiplyByPowerOf10(final_settle_precision)
        assert(n_amount_settle > BigDecimal.ZERO)

        //  构造OP
        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", chainMgr.grapheneCoreAssetID)
            })
            put("issuer", op_account.getString("id"))
            put("asset_to_settle", _curr_selected_asset.getString("id"))
            put("settle_price", JSONObject().apply {
                put("base", JSONObject().apply {
                    put("amount", n_amount_settle.toPlainString())
                    put("asset_id", _curr_selected_asset.getString("id"))
                })
                put("quote", JSONObject().apply {
                    put("amount", n_amount_back.toPlainString())
                    put("asset_id", back_asset.getString("id"))
                })
            })
        }

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_asset_global_settle, false, false,
                op, op_account) { isProposal, _ ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
            BitsharesClientManager.sharedBitsharesClientManager().assetGlobalSettle(op).then {
                mask.dismiss()
                showToast(resources.getString(R.string.kVcAssetOpGsSubmitTipsOK))
                //  [统计]
                btsppLogCustom("txAssetGlobalSettleFullOK", jsonObjectfromKVS("account", op_account.getString("id")))
                //  返回上一个界面并刷新
                _result_promise?.resolve(true)
                _result_promise = null
                finish()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txAssetGlobalSettleFailed", jsonObjectfromKVS("account", op_account.getString("id")))
            }
        }
    }
}
