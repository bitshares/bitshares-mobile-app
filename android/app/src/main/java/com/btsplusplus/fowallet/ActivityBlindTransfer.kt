package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.StealthTransferUtils
import com.btsplusplus.fowallet.utils.kAppBlindReceiptBlockNum
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_blind_transfer.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityBlindTransfer : BtsppActivity() {

    private var _curr_blind_asset: JSONObject? = null
    private var _data_array_blind_output = JSONArray()
    private var _data_array_blind_input = JSONArray()
    private var _auto_change_blind_output: JSONObject? = null

    private lateinit var _viewBlindInputs: ViewBlindAccountsOrReceipt
    private lateinit var _viewBlindOutputs: ViewBlindAccountsOrReceipt

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_transfer)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val blind_balance = args.optJSONObject("blind_balance")
        if (blind_balance != null) {
            onSelectBlindBalanceDone(jsonArrayfrom(blind_balance))
        }

        //  初始化UI
        _viewBlindInputs = ViewBlindAccountsOrReceipt(this, kBlindItemTypeInput, layout_blind_receipt_list_from_blind_transfer, callback_remove = { _on_remove_input_clicked(it) }, callback_add = { _on_add_one_input_clicked() })
        _viewBlindOutputs = ViewBlindAccountsOrReceipt(this, kBlindItemTypeOutput, layout_blind_account_list_from_blind_transfer, callback_remove = { _on_remove_output_clicked(it) }, callback_add = { _on_add_one_output_clicked() })
        refreshUI()

        //  提交事件
        btn_commit.setOnClickListener { onSubmit() }

        //  返回事件
        layout_back_from_blind_transfer.setOnClickListener { finish() }
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

    private fun calcBlindOutputTotalAmount(): BigDecimal {
        var n_total = BigDecimal.ZERO
        for (item in _data_array_blind_output.forin<JSONObject>()) {
            n_total = n_total.add(item!!.get("n_amount") as BigDecimal)
        }
        return n_total
    }

    private fun calcNetworkFee(n_output_num: BigDecimal?): BigDecimal? {
        if (_curr_blind_asset == null) {
            //  尚未选择收据
            return null
        }
        val n = n_output_num ?: BigDecimal.valueOf(_data_array_blind_output.length().toLong())
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        var n_fee = chainMgr.getNetworkCurrentFee(EBitsharesOperations.ebo_blind_transfer, null, null, n)
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
        onCalcAutoChange()
        refreshUI()
    }

    private fun _on_remove_output_clicked(idx: Int) {
        assert(idx < _data_array_blind_output.length())
        _data_array_blind_output.remove(idx)
        onCalcAutoChange()
        refreshUI()
    }

    /**
     *  (private) 计算自动找零。
     */
    private fun onCalcAutoChange() {
        _auto_change_blind_output = null

        //  没有任何输出：不找零。
        if (_data_array_blind_output.length() <= 0) {
            return
        }

        //  预估手续费失败：不找零。
        val n_output_num = BigDecimal.valueOf((_data_array_blind_output.length() + 1).toLong())
        val n_fee = calcNetworkFee(n_output_num)
        if (n_fee == null) {
            return
        }

        //  找零余额小于等于零，直接返回。
        val n_left_balance = calcBlindInputTotalAmount().subtract(calcBlindOutputTotalAmount()).subtract(n_fee)
        if (n_left_balance <= BigDecimal.ZERO) {
            return
        }

        //  计算自动找零地址。REMARK：从当前所有输入的收据获取收款地址。如果能转出收据，说明持有收据对应的私钥。
        //  优先寻找主地址、其次寻找子地址。
        var change_public_key: String? = null
        val accounts_hash = AppCacheManager.sharedAppCacheManager().getAllBlindAccounts()
        for (blind_balance in _data_array_blind_input.forin<JSONObject>()) {
            val public_key = blind_balance!!.getString("real_to_key")
            assert(public_key.isNotEmpty())
            val blind_account = accounts_hash.optJSONObject(public_key)
            if (blind_account != null) {
                val parent_key = blind_account.optString("parent_key")
                if (parent_key.isNotEmpty()) {
                    //  子账号（继续循环）
                    change_public_key = public_key
                } else {
                    //  主账号（中断循环）
                    change_public_key = public_key
                    break
                }
            }
        }
        //  生成找零输出对象。
        if (change_public_key != null) {
            _auto_change_blind_output = JSONObject().apply {
                put("public_key", change_public_key)
                put("n_amount", n_left_balance)
                put("bAutoChange", true)
            }
        }
    }

    private fun _on_add_one_output_clicked() {
        if (_data_array_blind_input.length() <= 0) {
            showToast(resources.getString(R.string.kVcStTipErrPleaseSelectReceiptFirst))
            return
        }

        //  可配置：限制最大隐私输出数量
        val allow_maximum_blind_output = 5
        if (_data_array_blind_output.length() >= allow_maximum_blind_output) {
            showToast(String.format(resources.getString(R.string.kVcStTipErrReachedMaxBlindOutputNum), allow_maximum_blind_output.toString()))
            return
        }

        assert(_curr_blind_asset != null)

        //  计算添加输出的时候，点击【全部】按钮的最大余额值，如果计算失败则会取消按钮显示。
        var n_max_balance: BigDecimal? = null
        val n_output_num = BigDecimal.valueOf((_data_array_blind_output.length() + 1).toLong())
        val n_fee = calcNetworkFee(n_output_num)
        if (n_fee != null) {
            val n_inputs = calcBlindInputTotalAmount()
            val n_outputs = calcBlindOutputTotalAmount()
            n_max_balance = n_inputs.subtract(n_outputs).subtract(n_fee)
            if (n_max_balance < BigDecimal.ZERO) {
                n_max_balance = BigDecimal.ZERO
            }
        }

        //  转到添加权限界面
        val result_promise = Promise()
        goTo(ActivityBlindOutputAddOne::class.java, true, args = JSONObject().apply {
            put("asset", _curr_blind_asset)
            put("n_max_balance", n_max_balance)
            put("result_promise", result_promise)
        })
        result_promise.then {
            val json_data = it as JSONObject
            //  添加
            _data_array_blind_output.put(json_data)
            //  计算找零
            onCalcAutoChange()
            //  刷新
            refreshUI()
            return@then null
        }
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
        if (_curr_blind_asset == null) {
            _data_array_blind_output = JSONArray()
        }
    }

    private fun _on_add_one_input_clicked() {
        StealthTransferUtils.processSelectReceipts(this, _data_array_blind_input) {
            //  重新选择
            onSelectBlindBalanceDone(it)
            //  自动找零
            onCalcAutoChange()
            //  刷新
            refreshUI()
        }
    }

    private fun refreshUI() {
        _draw_ui_blind_outputs_and_inputs()
        _draw_ui_bottom_data()
    }

    private fun _draw_ui_blind_outputs_and_inputs() {
        //  收据信息
        _viewBlindInputs.refreshUI(_data_array_blind_input)
        //  收款信息
        if (_auto_change_blind_output != null) {
            val new_ary = JSONArray().apply {
                putAll(_data_array_blind_output)
                put(_auto_change_blind_output)
            }
            _viewBlindOutputs.refreshUI(new_ary)
        } else {
            _viewBlindOutputs.refreshUI(_data_array_blind_output)
        }
    }

    private fun _draw_ui_bottom_data() {
        var n_total_input: BigDecimal? = null
        var n_total_output: BigDecimal? = null
        val n_fee = calcNetworkFee(null)
        if (_curr_blind_asset != null) {
            n_total_input = calcBlindInputTotalAmount()
            n_total_output = calcBlindOutputTotalAmount()
        }

        //  收据总金额
        tv_total_input_value.let { tv ->
            if (_curr_blind_asset != null) {
                val base_str = String.format("%s %s", n_total_input!!.toPriceAmountString(), _curr_blind_asset!!.getString("symbol"))
                if (n_fee != null && n_total_input < n_total_output!!.add(n_fee)) {
                    tv.text = String.format("%s(%s)", base_str, resources.getString(R.string.kVcTradeTipAmountNotEnough))
                    tv.setTextColor(resources.getColor(R.color.theme01_tintColor))
                } else {
                    tv.text = base_str
                    tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                }
            } else {
                tv.text = "--"
                tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            }
        }

        //  输出总金额
        if (_curr_blind_asset != null) {
            tv_total_output_value.text = String.format("%s %s", n_total_output!!.toPriceAmountString(), _curr_blind_asset!!.getString("symbol"))
        } else {
            tv_total_output_value.text = "--"
        }

        //  广播手续费
        if (n_fee != null) {
            tv_network_fee_value.text = String.format("%s %s", n_fee.toPriceAmountString(), _curr_blind_asset!!.getString("symbol"))
        } else {
            tv_network_fee_value.text = "--"
        }
    }

    /**
     *  提交事件
     */
    private fun onSubmit() {
        //  检测输入参数有效性
        if (_data_array_blind_input.length() <= 0) {
            showToast(resources.getString(R.string.kVcStTipSubmitPleaseSelectReceipt))
            return
        }

        val n_zero = BigDecimal.ZERO
        val n_total_input = calcBlindInputTotalAmount()
        assert(n_total_input > n_zero)

        if (_data_array_blind_output.length() <= 0) {
            showToast(resources.getString(R.string.kVcStTipSubmitPleaseAddBlindOutput))
            return
        }

        val n_total_output = calcBlindOutputTotalAmount()
        assert(n_total_output > n_zero)

        assert(_curr_blind_asset != null)
        var n_gift: BigDecimal? = null
        var n_fee: BigDecimal? = null
        var final_blind_output_array: JSONArray? = null
        if (_auto_change_blind_output != null) {
            val n_output_num = BigDecimal.valueOf((_data_array_blind_output.length() + 1).toLong())
            n_fee = calcNetworkFee(n_output_num)
            //  REMARK：如果已经有找零信息了，则手续费计算肯定是成功的。
            assert(n_fee != null)
            //  找零 = 总输入 - 总输出 - 手续费
            assert((_auto_change_blind_output!!.get("n_amount") as BigDecimal).compareTo(n_total_input.subtract(n_total_output).subtract(n_fee)) == 0)
            //  合并找零输出到总输出列表中
            final_blind_output_array = JSONArray()
            final_blind_output_array.putAll(_data_array_blind_output)
            final_blind_output_array.put(_auto_change_blind_output)
        } else {
            n_fee = calcNetworkFee(null)
            if (n_fee == null) {
                showToast(String.format(resources.getString(R.string.kVcStTipErrCannotBlindTransferInvalidCER), _curr_blind_asset!!.getString("symbol")))
                return
            }
            //  自动赠与（找零金额不足支持1个output的手续费时，考虑自动赠与给第一个output。）
            n_gift = n_total_input.subtract(n_total_output).subtract(n_fee)
            if (n_gift < n_zero) {
                showToast(resources.getString(R.string.kVcStTipErrTotalInputReceiptNotEnough))
                return
            }
            //  REMARK：gift 应该小于一个 output 的手续费，当然这里也应该小于总的手续费。
            assert(n_gift <= n_fee)
            //  余额刚好为0，不用赠与。
            if (n_gift.compareTo(n_zero) == 0) {
                n_gift = null
            }
            //  计算最终输出列表
            if (n_gift != null) {
                //  赠与给第一个输出
                val mut_first_output = _data_array_blind_output.first<JSONObject>()!!.shadowClone()
                mut_first_output.put("n_amount", (mut_first_output.get("n_amount") as BigDecimal).add(n_gift))
                final_blind_output_array = JSONArray()
                final_blind_output_array.put(mut_first_output)
                //  添加其他输出
                if (_data_array_blind_output.length() > 1) {
                    for (i in 1 until _data_array_blind_output.length()) {
                        final_blind_output_array.put(_data_array_blind_output.getJSONObject(i))
                    }
                }
            } else {
                //  无赠与、无找零，直接默认输出。
                final_blind_output_array = _data_array_blind_output
            }
        }

        //  二次确认
        val value: String
        val symbol = _curr_blind_asset!!.getString("symbol")
        if (_auto_change_blind_output != null) {
            value = String.format(resources.getString(R.string.kVcStTipAskConfrimBlindTransferWithAutoChange),
                    _data_array_blind_output.length().toString(),
                    n_total_output.toPlainString(), symbol,
                    (_auto_change_blind_output!!.get("n_amount") as BigDecimal).toPlainString(), symbol,
                    n_fee!!.toPlainString(), symbol)
        } else if (n_gift != null) {
            value = String.format(resources.getString(R.string.kVcStTipAskConfrimBlindTransferWithAutoGift),
                    _data_array_blind_output.length().toString(),
                    n_total_output.toPlainString(), symbol,
                    n_gift.toPlainString(), symbol,
                    n_fee!!.toPlainString(), symbol)
        } else {
            value = String.format(resources.getString(R.string.kVcStTipAskConfrimBlindTransfer),
                    _data_array_blind_output.length().toString(),
                    n_total_output.toPlainString(), symbol,
                    n_fee!!.toPlainString(), symbol)
        }

        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), value).then {
            if (it != null && it as Boolean) {
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        blindTransferCore(_curr_blind_asset!!, _data_array_blind_input, final_blind_output_array, n_fee)
                    }
                }
            }
        }
    }

    private fun blindTransferCore(asset: JSONObject, blind_balance_array: JSONArray, blind_output_array: JSONArray, n_fee: BigDecimal) {
        assert(blind_balance_array.length() > 0)
        assert(blind_output_array.length() > 0)


        //  根据隐私收据生成 blind_input 参数。同时返回所有相关盲因子以及签名KEY。
        val sign_keys = JSONObject()
        val input_blinding_factors = JSONArray()
        val inputs = StealthTransferUtils.genBlindInputs(this, blind_balance_array, input_blinding_factors, sign_keys, null)
        if (inputs == null) {
            return
        }

        //  生成隐私输出，和前面的输入盲因子相关联。
        val blind_output_args = StealthTransferUtils.genBlindOutputs(blind_output_array, asset, input_blinding_factors)

        //  构造OP
        val precision = asset.getInt("precision")
        val n_fee_pow = n_fee.multiplyByPowerOf10(precision)

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("asset_id", asset.getString("id"))
                put("amount", n_fee_pow.toPlainString())
            })
            put("inputs", inputs)
            put("outputs", blind_output_args.getJSONArray("blind_outputs"))
        }

        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
        //  REMARK：该操作不涉及账号，不需要处理提案的情况。仅n个私钥签名即可。
        BitsharesClientManager.sharedBitsharesClientManager().blindTransfer(op, sign_keys).then {

            val walletMgr = WalletManager.sharedWalletManager()
            val pAppCahce = AppCacheManager.sharedAppCacheManager()
            //  a、删除已经提取的收据。
            for (blind_balance in blind_balance_array.forin<JSONObject>()) {
                pAppCahce.removeBlindBalance(blind_balance!!)
            }
            //  b、自动导入【我的】收据
            for (item in blind_output_args.getJSONArray("receipt_array").forin<JSONObject>()) {
                val blind_balance = item!!.getJSONObject("blind_balance")
                //  REMARK：有隐私账号私钥的收据即为我自己的收据。
                val real_to_key = blind_balance.optString("real_to_key")
                if (real_to_key.isNotEmpty() && walletMgr.havePrivateKey(real_to_key)) {
                    pAppCahce.appendBlindBalance(blind_balance)
                }
            }
            pAppCahce.saveWalletInfoToFile()

            //  [统计]
            btsppLogCustom("txBlindTransferFullOK", jsonObjectfromKVS("asset", asset.getString("symbol")))

            //  生成二维码 & 转到备份收据界面
            val tx_data = it as JSONArray
            assert(tx_data.length() > 0)

            //  生成隐私转账收据信息
            val block_num = tx_data.getJSONObject(0).getString("block_num")
            val blind_receipt_string = JSONObject().apply { put(kAppBlindReceiptBlockNum, block_num) }.toString().base58_encode()

            Utils.asyncCreateQRBitmap(blind_receipt_string, 150.dp).then { btm ->
                mask.dismiss()
                goTo(ActivityBlindBackupReceipt::class.java, true, clear_navigation_stack = true, args = JSONObject().apply {
                    put("result", tx_data)
                    put("qrbitmap", btm!!)
                    put("blind_receipt_string", blind_receipt_string)
                })
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            showGrapheneError(err)
        }
    }
}
