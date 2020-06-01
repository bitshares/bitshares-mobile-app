package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.EditText
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_scan_result_transfer.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityScanResultTransfer : BtsppActivity() {

    private lateinit var _to_account: JSONObject
    private lateinit var _asset: JSONObject
    private var _default_amount: String? = null
    private var _default_memo: String? = null
    private var _bLockAmount = false
    private var _bLockMemo = false

    private var _tf_amount_watcher: UtilsDigitTextWatcher? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_scan_result_transfer)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _to_account = args.getJSONObject("to")
        _asset = args.getJSONObject("asset")
        _default_amount = args.optString("amount", null)
        _default_memo = args.optString("memo", null)

        //  账号名称 & ID
        val tv_account_name = account_name_from_scan_result_transfer
        tv_account_name.text = _to_account.getString("name")

        val tv_account_id = account_id_from_scan_result_transfer
        tv_account_id.text = "#${_to_account.getString("id").split(".").last()}"

        //  初始化UI
        _bLockAmount = _default_amount != null && _default_amount != ""
        _bLockMemo = _default_memo != null && _default_memo != ""

        //  - 数量字段
        if (_bLockAmount) {
            //  数量：只读
            layout_transfer_amount_auto_input.visibility = View.VISIBLE
            layout_transfer_amount_input.visibility = View.GONE

            val tv_transfer_amount = txt_transfer_amount_from_scan_result_transfer
            tv_transfer_amount.text = "$_default_amount ${_asset.getString("symbol")}"
        } else {
            //  数量：用户输入
            layout_transfer_amount_auto_input.visibility = View.GONE
            layout_transfer_amount_input.visibility = View.VISIBLE

            btn_transfer_asset.text = _asset.getString("symbol").toUpperCase()

            //  绑定事件处理
            //  初始化事件
            _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(findViewById<EditText>(R.id.tf_amount_from_scan_result_transfer)).set_precision(_asset.getInt("precision"))
            tf_amount_from_scan_result_transfer.addTextChangedListener(_tf_amount_watcher!!)
            _tf_amount_watcher!!.on_value_changed(::onAmountChanged)
        }

        //  - 备注字段
        if (_bLockMemo) {
            //  备注：只读
            layout_memo_info_auto_input.visibility = View.VISIBLE
            layout_memo_info_input.visibility = View.GONE

            txt_memo_info_from_scan_result_transfer.text = _default_memo
        } else {
            //  备注：用户输入
            layout_memo_info_auto_input.visibility = View.GONE
            layout_memo_info_input.visibility = View.VISIBLE
        }

        //  返回按钮
        layout_back_from_scan_result_transfer.setOnClickListener { finish() }

        //  提交支付事件
        button_payment_from_scan_result.setOnClickListener { onCommitCore() }
    }

    /**
     * (private) 支付数量发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        //  ...
    }

    /**
     * (private) 点击支付按钮事件
     */
    private fun onCommitCore() {
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
                mask.show()
                val p1 = get_full_account_data_and_asset_hash(WalletManager.sharedWalletManager().getWalletAccountName()!!)
                val p2 = ChainObjectManager.sharedChainObjectManager().queryFeeAssetListDynamicInfo()
                Promise.all(p1, p2).then {
                    val data_array = it as JSONArray
                    val full_userdata = data_array.getJSONObject(0)
                    if (!_onPayCoreWithMask(full_userdata, mask)) {
                        mask.dismiss()
                    }
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(resources.getString(R.string.tip_network_error))
                }
            }
        }
    }

    /**
     *  (private) 辅助 - 判断手续费是否足够，足够则返回需要消耗的手续费，不足则返回 nil。
     *  fee_price_item      - 服务器返回的需要手续费值
     *  fee_asset_id        - 当前手续费资产ID
     *  asset               - 正在转账的资产
     *  n_amount            - 正在转账的数量
     */
    private fun _isFeeSufficient(fee_price_item: JSONObject, fee_asset: JSONObject, asset: JSONObject, n_amount: BigDecimal, full_account_data: JSONObject): BigDecimal? {
        val fee_asset_id = fee_asset.getString("id")
        assert(fee_asset_id == fee_price_item.getString("asset_id"))

        //  1、转账消耗资产值（只有转账资产和手续费资产相同时候才设置）
        var n_transfer_cost = BigDecimal.ZERO
        if (asset.getString("id") == fee_asset_id) {
            n_transfer_cost = n_amount
        }

        //  2、手续费消耗值
        val n_fee_cost = bigDecimalfromAmount(fee_price_item.getString("amount"), fee_asset.getInt("precision"))

        //  3、总消耗值
        val n_total_cost = n_transfer_cost.add(n_fee_cost)

        //  4、获取手续费资产总的可用余额
        var n_available = BigDecimal.ZERO
        for (balance_object in full_account_data.getJSONArray("balances")) {
            val asset_type = balance_object!!.getString("asset_type")
            if (asset_type == fee_asset_id) {
                n_available = bigDecimalfromAmount(balance_object.getString("balance"), fee_asset.getInt("precision"))
                break
            }
        }
        //  5、判断：n_available < n_total_cost
        if (n_available < n_total_cost) {
            //  不足：返回 nil。
            return null
        }

        //  足够（返回手续费值）
        return n_fee_cost
    }

    private fun _onPayCoreWithMask(full_account_data: JSONObject, mask: ViewMask): Boolean {
        val from_account = full_account_data.getJSONObject("account")

        //  收款方不能为自己。
        if (from_account.getString("id") == _to_account.getString("id")) {
            showToast(resources.getString(R.string.kVcScanResultPaySubmitTipsToIsMyself))
            return false
        }

        //  1、检测付款金额参数是否正确、账户余额是否足够。
        val str_amount = if (!_bLockAmount) findViewById<EditText>(R.id.tf_amount_from_scan_result_transfer).text.toString() else _default_amount!!
        if (str_amount == "") {
            showToast(resources.getString(R.string.kVcScanResultPaySubmitTipsInputPayAmount))
            return false
        }

        val n_amount = Utils.auxGetStringDecimalNumberValue(str_amount)
        if (n_amount <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kVcScanResultPaySubmitTipsInputPayAmount))
            return false
        }

        val pay_asset_id = _asset.getString("id")
        val pay_asset_precision = _asset.getInt("precision")

        val balances_hash = JSONObject()
        for (it in full_account_data.getJSONArray("balances").forin<JSONObject>()) {
            val balance_object = it!!
            val asset_type = balance_object.getString("asset_type")
            val balance = balance_object.getString("balance")
            if (pay_asset_id == asset_type) {
                val n_balance = bigDecimalfromAmount(balance, pay_asset_precision)
                if (n_balance < BigDecimal.ZERO) {
                    showToast(resources.getString(R.string.kVcScanResultPaySubmitTipsNotEnough))
                    return false
                }
                val n_left = n_balance.subtract(n_amount)
                val n_left_pow = n_left.multiplyByPowerOf10(pay_asset_precision)
                balances_hash.put(asset_type, jsonObjectfromKVS("asset_id", asset_type, "amount", n_left_pow.toPlainString()))
            } else {
                balances_hash.put(asset_type, jsonObjectfromKVS("asset_id", asset_type, "amount", balance))
            }
        }
        val balances_list = balances_hash.values()
        val fee_item = ChainObjectManager.sharedChainObjectManager().estimateFeeObject(EBitsharesOperations.ebo_transfer.value, balances_list)

        //  2、检测备注信息
        var str_memo: String?
        str_memo = if (!_bLockMemo) findViewById<EditText>(R.id.tf_memo_from_scan_result_transfer).text.toString() else _default_memo!!
        if (str_memo == "") {
            str_memo = null
        }

        //  检测备注私钥相关信息
        var memo_object: JSONObject? = null
        if (str_memo != null) {
            val from_public_memo = from_account.optJSONObject("options")?.optString("memo_key", null)
            if (from_public_memo == null) {
                showToast(resources.getString(R.string.kVcTransferSubmitTipAccountNoMemoKey))
                return false
            }
            val to_public = _to_account.optJSONObject("options")?.optString("memo_key", null)
            if (to_public == null) {
                showToast(resources.getString(R.string.kVcTransferSubmitTipWalletNoMemoKey))
                return false
            }
            memo_object = WalletManager.sharedWalletManager().genMemoObject(str_memo, from_public_memo, to_public)
            if (memo_object == null) {
                showToast(resources.getString(R.string.kVcTransferSubmitTipWalletNoMemoKey))
                return false
            }
        }

        //  --- 开始构造OP ---
        val n_amount_pow = n_amount.multiplyByPowerOf10(pay_asset_precision)
        val fee_asset_id = fee_item.getString("fee_asset_id")

        val op = JSONObject().apply {
            put("fee", jsonObjectfromKVS("amount", 0, "asset_id", fee_asset_id))
            put("from", from_account.getString("id"))
            put("to", _to_account.getString("id"))
            put("amount", jsonObjectfromKVS("amount", n_amount_pow.toPlainString(), "asset_id", _asset.getString("id")))
            put("memo", memo_object)    //  maybe null
        }

        //  --- 开始评估手续费 ---
        BitsharesClientManager.sharedBitsharesClientManager().calcOperationFee(op, EBitsharesOperations.ebo_transfer).then {
            mask.dismiss()
            val fee_price_item = it as JSONObject
            //  判断手续费是否足够
            val fee_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(fee_asset_id)
            val n_fee_cost = _isFeeSufficient(fee_price_item, fee_asset, _asset, n_amount, full_account_data)
            if (n_fee_cost == null) {
                showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
                return@then null
            }

            //  --- 弹框确认转账行为 ---
            val transfer_args = JSONObject().apply {
                put("from", from_account)
                put("to", _to_account)
                put("asset", _asset)
                put("fee_asset", fee_asset)

                put("kAmount", n_amount.toDouble())
                put("kFeeCost", n_fee_cost.toDouble())

                put("kMemo", str_memo)
            }

            //  确保有权限发起普通交易，否则作为提案交易处理。
            GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_transfer, false, false,
                    op, full_account_data.getJSONObject("account")) { isProposal, _ ->
                assert(!isProposal)
                //  非提案交易：转转账确认界面
                val result_promise = Promise()
                transfer_args.put("result_promise", result_promise)
                goTo(ActivityTransferConfirm::class.java, true, args = transfer_args)
                result_promise.then {
                    if (it != null && it as Boolean) {
                        //  确认支付
                        _processTransferCore(_asset, n_amount, op, full_account_data)
                    }
                }
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
        return true
    }

    private fun _processTransferCore(transfer_asset: JSONObject, transfer_n_amount: BigDecimal, op_data: JSONObject, full_account_data: JSONObject) {
        //  请求网络广播
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()
        BitsharesClientManager.sharedBitsharesClientManager().transfer(op_data).then {
            val tx_data = it as? JSONArray
            mask.dismiss()
            //  [统计]
            btsppLogCustom("txPayTransferFullOK", jsonObjectfromKVS("asset", transfer_asset.getString("symbol")))
            goTo(ActivityScanResultPaySuccess::class.java, true, clear_navigation_stack = true, args = JSONObject().apply {
                put("result", tx_data)
                put("to_account", _to_account)
                put("amount_string", "${transfer_n_amount.toPlainString()} ${transfer_asset.getString("symbol")}")
            })
            return@then null
        }.catch { err ->
            mask.dismiss()
            showGrapheneError(err)
            //  [统计]
            btsppLogCustom("txPayTransferFailed", jsonObjectfromKVS("asset", transfer_asset.getString("symbol")))
        }
    }
}
