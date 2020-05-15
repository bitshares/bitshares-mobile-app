package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.StealthTransferUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_transfer_from_blind.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityTransferFromBlind : BtsppActivity() {

    private var _curr_blind_asset: JSONObject? = null
    private var _data_array_blind_input = JSONArray()
    private var _to_account: JSONObject? = null

    private lateinit var _viewBlindInputs: ViewBlindAccountsOrReceipt

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_transfer_from_blind)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val blind_balance = args.optJSONObject("blind_balance")
        if (blind_balance != null) {
            onSelectBlindBalanceDone(jsonArrayfrom(blind_balance))
        }

        //  初始化UI
        _viewBlindInputs = ViewBlindAccountsOrReceipt(this, kBlindItemTypeInput, layout_blind_receipt_list_from_transfer_from_blind, callback_remove = { _on_remove_input_clicked(it) }, callback_add = { _on_add_one_input_clicked() })
        refreshUI()

        //  选择目标账户箭头颜色
        img_arrow_to_account.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

        //  选择目标账户事件
        layout_to_account.setOnClickListener { onSelectGoalAccount() }

        //  提交事件
        btn_commit.setOnClickListener { onSubmit() }

        //  返回事件
        layout_back_from_transfer_from_blind.setOnClickListener { finish() }
    }

    private fun calcBlindInputTotalAmount(): BigDecimal {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        var n_total = BigDecimal.ZERO
        for (blind_balance in _data_array_blind_input.forin<JSONObject>()) {
            val decrypted_memo = blind_balance!!.getJSONObject("decrypted_memo")
            val amount = decrypted_memo.getJSONObject("amount")
            val asset = chainMgr.getChainObjectByID(amount.getString("asset_id"))
            val n_amount = bigDecimalfromAmount(amount.getString("amount"), asset.getInt("precision"))
            n_total = n_total.add(n_amount)
        }
        return n_total
    }

    private fun calcNetworkFee(): BigDecimal? {
        if (_curr_blind_asset == null) {
            //  尚未选择收据
            return null
        }
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        var n_fee = chainMgr.getNetworkCurrentFee(EBitsharesOperations.ebo_transfer_from_blind, null, null, null)
        val asset_id = _curr_blind_asset!!.getString("id")
        if (asset_id != chainMgr.grapheneCoreAssetID) {
            val core_exchange_rate = _curr_blind_asset!!.getJSONObject("options").getJSONObject("core_exchange_rate")
            n_fee = ModelUtils.multiplyAndRoundupNetworkFee(chainMgr.getChainObjectByID(chainMgr.grapheneCoreAssetID), _curr_blind_asset!!,
                    n_fee!!, core_exchange_rate)
            if (n_fee == null) {
                //  汇率数据异常
                return null
            }
        }
        return n_fee
    }

    private fun _on_remove_input_clicked(idx: Int) {
        assert(idx < _data_array_blind_input.length())
        _data_array_blind_input.remove(idx)
        if (_data_array_blind_input.length() <= 0) {
            onSelectBlindBalanceDone(null)
        }
        refreshUI()
    }

    private fun onSelectBlindBalanceDone(new_blind_balance_array: JSONArray?) {
        _data_array_blind_input = JSONArray()
        if (new_blind_balance_array != null && new_blind_balance_array.length() > 0) {
            _data_array_blind_input.putAll(new_blind_balance_array)
        }
        if (_data_array_blind_input.length() > 0) {
            val amount = _data_array_blind_input.first<JSONObject>()!!.getJSONObject("decrypted_memo").getJSONObject("amount")
            _curr_blind_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(amount.getString("asset_id"))
        } else {
            _curr_blind_asset = null
        }
    }

    private fun _on_add_one_input_clicked() {
        StealthTransferUtils.processSelectReceipts(this, _data_array_blind_input) {
            //  重新选择
            onSelectBlindBalanceDone(it)
            //  刷新
            refreshUI()
        }
    }

    private fun refreshUI() {
        _draw_ui_to_accounts()
        _draw_ui_blind_inputs()
        _draw_ui_bottom_data()
    }

    private fun _draw_ui_to_accounts() {
        if (_to_account != null) {
            tv_to_account_name.text = _to_account!!.getString("name")
            tv_to_account_id.text = _to_account!!.getString("id")
            tv_to_account_name.setTextColor(resources.getColor(R.color.theme01_buyColor))
            tv_to_account_id.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            tv_to_account_name.text = resources.getString(R.string.kVcAssetOpCellValueIssueTargetAccountDefault)
            tv_to_account_id.text = ""
            tv_to_account_name.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tv_to_account_id.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    private fun _draw_ui_blind_inputs() {
        _viewBlindInputs.refreshUI(_data_array_blind_input)
    }

    private fun _draw_ui_bottom_data() {
        //  收据总金额
        val n_total_input = calcBlindInputTotalAmount()
        if (_curr_blind_asset != null) {
            tv_total_input_value.text = String.format("%s %s", n_total_input.toPriceAmountString(), _curr_blind_asset!!.getString("symbol"))
        } else {
            tv_total_input_value.text = "--"
        }

        //  广播手续费
        val n_fee = calcNetworkFee()
        if (n_fee != null) {
            tv_network_fee_value.text = String.format("%s %s", n_fee.toPriceAmountString(), _curr_blind_asset!!.getString("symbol"))
        } else {
            tv_network_fee_value.text = "--"
        }

        //  实际到账
        if (n_fee != null) {
            var n_final = n_total_input.subtract(n_fee)
            val n_zero = BigDecimal.ZERO
            if (n_final < n_zero) {
                n_final = n_zero
            }
            tv_actual_amount.text = String.format("%s %s", n_final.toPriceAmountString(), _curr_blind_asset!!.getString("symbol"))
        } else {
            tv_actual_amount.text = "--"
        }
    }

    private fun onSelectGoalAccount() {
        TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
            last_activity.goTo(ActivityTransferFromBlind::class.java, true, back = true)
            //  设置代理人
            _to_account = it
            _draw_ui_to_accounts()
        }
        goTo(ActivityAccountQueryBase::class.java, true)
    }

    /**
     *  提交
     */
    private fun onSubmit() {
        if (_data_array_blind_input.length() <= 0) {
            showToast(resources.getString(R.string.kVcStTipSubmitPleaseSelectReceipt))
            return
        }

        if (_to_account == null) {
            showToast(resources.getString(R.string.kVcStTipErrPleaseSelectToPublicAccount))
            return
        }

        val n_total = calcBlindInputTotalAmount()
        assert(n_total > BigDecimal.ZERO)
        assert(_curr_blind_asset != null)
        val n_fee = calcNetworkFee()
        if (n_fee == null) {
            showToast(String.format(resources.getString(R.string.kVcStTipErrCannotBlindTransferInvalidCER), _curr_blind_asset!!.getString("symbol")))
            return
        }

        if (n_total <= n_fee) {
            showToast(resources.getString(R.string.kVcStTipErrTotalInputReceiptLowThanNetworkFee))
            return
        }

        //  解锁钱包
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                transferFromBlindCore(_data_array_blind_input, _curr_blind_asset!!, n_total, n_fee)
            }
        }
    }

    private fun transferFromBlindCore(blind_balance_array: JSONArray, asset: JSONObject, n_total: BigDecimal, n_fee: BigDecimal) {
        assert(blind_balance_array.length() > 0)

        //  根据隐私收据生成 blind_input 参数。同时返回所有相关盲因子以及签名KEY。
        val sign_keys = JSONObject()
        val input_blinding_factors = JSONArray()
        val inputs = StealthTransferUtils.genBlindInputs(this, blind_balance_array, input_blinding_factors, sign_keys, null)
        if (inputs == null) {
            return
        }

        //  所有盲因子求和
        val blinding_factor = StealthTransferUtils.blindSum(input_blinding_factors)

        //  构造OP
        val precision = asset.getInt("precision")
        val n_transfer_amount = n_total.subtract(n_fee)
        val transfer_amount_pow = n_transfer_amount.multiplyByPowerOf10(precision)
        val fee_pow = n_fee.multiplyByPowerOf10(precision)

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("asset_id", asset.getString("id"))
                put("amount", fee_pow.toPlainString())
            })
            put("amount", JSONObject().apply {
                put("asset_id", asset.getString("id"))
                put("amount", transfer_amount_pow.toPlainString())
            })
            put("to", _to_account!!.getString("id"))
            put("blinding_factor", blinding_factor)
            put("inputs", inputs)
        }

        val amount_string = String.format("%s %s", n_transfer_amount.toPlainString(), asset.getString("symbol"))
        val value = String.format(resources.getString(R.string.kVcStTipAskConfrimTransferFromBlind),
                amount_string, _to_account!!.getString("name"), n_fee.toPlainString(), asset.getString("symbol"))

        //  二次确认
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), value).then {
            if (it != null && it as Boolean) {
                val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

                //  REMARK：该操作不涉及账号，不需要处理提案的情况。仅n个私钥签名即可。
                BitsharesClientManager.sharedBitsharesClientManager().transferFromBlind(op, sign_keys).then {
                    val tx_data = it as? JSONArray

                    mask.dismiss()
                    //  删除已提取的收据
                    val pAppCahce = AppCacheManager.sharedAppCacheManager()
                    for (blind_balance in blind_balance_array.forin<JSONObject>()) {
                        pAppCahce.removeBlindBalance(blind_balance!!)
                    }
                    pAppCahce.saveWalletInfoToFile()

                    //  [统计]
                    btsppLogCustom("txTransferFromBlindFullOK", jsonObjectfromKVS("asset", asset.getString("symbol")))

                    //  转到结果界面。
                    val self = this
                    goTo(ActivityScanResultPaySuccess::class.java, true, clear_navigation_stack = true, args = JSONObject().apply {
                        put("result", tx_data)
                        put("to_account", _to_account)
                        put("amount_string", amount_string)
                        put("success_tip_string", self.resources.getString(R.string.kVcStTipLabelTransferFromBlindSuccess))
                    })
                    return@then null
                }.catch { err ->
                    mask.dismiss()
                    showGrapheneError(err)
                }
            }
        }
    }

}
