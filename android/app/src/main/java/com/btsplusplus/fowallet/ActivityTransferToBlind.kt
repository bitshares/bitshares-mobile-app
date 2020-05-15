package com.btsplusplus.fowallet

import android.os.Bundle
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.StealthTransferUtils
import com.btsplusplus.fowallet.utils.kAppBlindReceiptBlockNum
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_transfer_to_blind.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityTransferToBlind : BtsppActivity() {

    private lateinit var _curr_asset: JSONObject
    private lateinit var _full_account_data: JSONObject
    private var _data_array_blind_output = JSONArray()
    private lateinit var _nCurrBalance: BigDecimal

    private lateinit var _viewBlindOutputs: ViewBlindAccountsOrReceipt

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_transfer_to_blind)
        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _curr_asset = args.getJSONObject("core_asset")
        _full_account_data = args.getJSONObject("full_account_data")
        assert(ModelUtils.assetAllowConfidential(_curr_asset))
        assert(!ModelUtils.assetIsTransferRestricted(_curr_asset))
        assert(!ModelUtils.assetNeedWhiteList(_curr_asset))
        _nCurrBalance = ModelUtils.findAssetBalance(_full_account_data, _curr_asset)

        //  初始化UI
        _viewBlindOutputs = ViewBlindAccountsOrReceipt(this, kBlindItemTypeOutput, layout_blind_account_list_from_transfer_to_blind, callback_remove = { _on_remove_clicked(it) }, callback_add = { _on_add_clicked() })
        refreshUI()

        //  选择资产箭头颜色
        iv_select_asset_from_transfer_to_blind.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

        //  事件 - 选择资产
        layout_select_asset_from_transfer_to_blind.setOnClickListener { onSelectAssetClicked() }

        //  提交事件
        btn_commit.setOnClickListener { onSubmit() }

        //  返回事件
        layout_back_from_transfer_to_blind.setOnClickListener { finish() }
    }

    private fun onSelectAssetDone(asset_info: JSONObject) {
        if (!ModelUtils.assetAllowConfidential(asset_info)) {
            showToast(String.format(resources.getString(R.string.kVcStTipErrForbidBlindTransfer), asset_info.getString("symbol")))
            return
        }
        if (ModelUtils.assetIsTransferRestricted(asset_info)) {
            showToast(String.format(resources.getString(R.string.kVcStTipErrForbidNormalTransfer), asset_info.getString("symbol")))
            return
        }
        if (ModelUtils.assetNeedWhiteList(asset_info)) {
            showToast(String.format(resources.getString(R.string.kVcStTipErrNeedWhiteList), asset_info.getString("symbol")))
            return
        }
        val new_id = asset_info.getString("id")
        val old_id = _curr_asset.getString("id")
        if (new_id != old_id) {
            _curr_asset = asset_info
            //  切换资产：更新余额、清空当前收款人、更新手续费
            _nCurrBalance = ModelUtils.findAssetBalance(_full_account_data, _curr_asset)
            _data_array_blind_output = JSONArray()
            refreshUI()
        }
    }

    private fun onSelectAssetClicked() {
        TempManager.sharedTempManager().set_query_account_callback { last_activity, asset_info ->
            last_activity.goTo(ActivityTransferToBlind::class.java, true, back = true)
            //  选择完毕
            onSelectAssetDone(asset_info)
        }
        val title = resources.getString(R.string.kVcTitleSearchAssets)
        goTo(ActivityAccountQueryBase::class.java, true, args = JSONObject().apply {
            put("kSearchType", ENetworkSearchType.enstAssetAll)
            put("kTitle", title)
        })
    }

    private fun calcBlindOutputTotalAmount(): BigDecimal {
        var n_total = BigDecimal.ZERO
        for (item in _data_array_blind_output.forin<JSONObject>()) {
            n_total = n_total.add(item!!.get("n_amount") as BigDecimal)
        }
        return n_total
    }

    private fun calcNetworkFee(n_output_num: BigDecimal?): BigDecimal {
        val n = n_output_num ?: BigDecimal.valueOf(_data_array_blind_output.length().toLong())
        val n_fee = ChainObjectManager.sharedChainObjectManager().getNetworkCurrentFee(EBitsharesOperations.ebo_transfer_to_blind, null, null, n)
        return n_fee!!
    }

    private fun _on_remove_clicked(idx: Int) {
        assert(idx < _data_array_blind_output.length())
        _data_array_blind_output.remove(idx)
        refreshUI()
    }

    private fun _on_add_clicked() {
        //  可配置：限制最大隐私输出数量
        val allow_maximum_blind_output = 5
        if (_data_array_blind_output.length() >= allow_maximum_blind_output) {
            showToast(String.format(resources.getString(R.string.kVcStTipErrReachedMaxBlindOutputNum), allow_maximum_blind_output.toString()))
            return
        }

        //  计算添加输出的时候，点击【全部】按钮的最大余额值，如果计算失败则会取消按钮显示。
        var n_max_balance = _nCurrBalance.subtract(calcBlindOutputTotalAmount())
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        if (chainMgr.grapheneCoreAssetID == _curr_asset.getString("id")) {
            //  REMARK：转账资产是core资产时候，需要扣除手续费。
            val n_output_num = BigDecimal.valueOf((_data_array_blind_output.length() + 1).toLong())
            val n_fee = calcNetworkFee(n_output_num)
            n_max_balance = n_max_balance.subtract(n_fee)
        }
        if (n_max_balance <= BigDecimal.ZERO) {
            n_max_balance = BigDecimal.ZERO
        }

        //  转到添加权限界面
        val result_promise = Promise()
        goTo(ActivityBlindOutputAddOne::class.java, true, args = JSONObject().apply {
            put("asset", _curr_asset)
            put("n_max_balance", n_max_balance)
            put("result_promise", result_promise)
        })
        result_promise.then {
            val json_data = it as JSONObject
            //  添加
            _data_array_blind_output.put(json_data)
            //  刷新
            refreshUI()
            return@then null
        }
    }

    private fun refreshUI() {
        tv_curr_asset_symbol.text = _curr_asset.getString("symbol")
        _draw_ui_blind_outputs()
        _draw_ui_bottom_data()
    }

    private fun _draw_ui_blind_outputs() {
        _viewBlindOutputs.refreshUI(_data_array_blind_output)
    }

    private fun _draw_ui_bottom_data() {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val n_total = calcBlindOutputTotalAmount()
        val n_core_fee = calcNetworkFee(null)

        val symbol = _curr_asset.getString("symbol")
        val base_str = String.format("%s %s", _nCurrBalance.toPriceAmountString(), symbol)
        var n_max_balance = _nCurrBalance
        if (chainMgr.grapheneCoreAssetID == _curr_asset.getString("id")) {
            //  转账资产和手续费资产相同，则扣除对应手续费。
            n_max_balance = n_max_balance.subtract(n_core_fee)
        }

        //  可用余额
        tv_balance_value.let { tv ->
            if (n_max_balance < n_total) {
                tv.text = String.format("%s(%s)", base_str, resources.getString(R.string.kVcTradeTipAmountNotEnough))
                tv.setTextColor(resources.getColor(R.color.theme01_tintColor))
            } else {
                tv.text = base_str
                tv.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            }
        }

        //  输出总金额
        tv_total_output_value.text = String.format("%s %s", n_total.toPriceAmountString(), symbol)

        //  广播手续费
        tv_network_fee_value.text = String.format("%s %s", n_core_fee.toPriceAmountString(), chainMgr.grapheneAssetSymbol)
    }

    /**
     *  提交
     */
    private fun onSubmit() {
        val i_output_count = _data_array_blind_output.length()
        if (i_output_count <= 0) {
            showToast(resources.getString(R.string.kVcStTipSubmitPleaseAddBlindOutput))
            return
        }

        val n_total = calcBlindOutputTotalAmount()
        assert(n_total > BigDecimal.ZERO)

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        var n_max_balance = _nCurrBalance
        val n_core_fee = calcNetworkFee(null)
        if (chainMgr.grapheneCoreAssetID == _curr_asset.getString("id")) {
            n_max_balance = n_max_balance.subtract(n_core_fee)
        }
        if (n_max_balance < n_total) {
            showToast(resources.getString(R.string.kVcStTipSubmitBalanceNotEnough))
            return
        }

        //  生成隐私输出
        val blind_output_args = StealthTransferUtils.genBlindOutputs(_data_array_blind_output, _curr_asset, input_blinding_factors = null)

        //  生成所有隐私输出承诺盲因子之和
        val receipt_array = blind_output_args.getJSONArray("receipt_array")
        val blind_factor_array = JSONArray()
        for (item in receipt_array.forin<JSONObject>()) {
            blind_factor_array.put(item!!.get("blind_factor"))
        }
        val blinding_factor = StealthTransferUtils.blindSum(blind_factor_array)

        //  构造OP
        val n_total_pow = n_total.multiplyByPowerOf10(_curr_asset.getInt("precision"))
        val op_account = _full_account_data.getJSONObject("account")
        val core_asset = chainMgr.getChainObjectByID(chainMgr.grapheneCoreAssetID)
        val n_fee_pow = n_core_fee.multiplyByPowerOf10(core_asset.getInt("precision"))

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("asset_id", core_asset.getString("id"))
                put("amount", n_fee_pow.toPlainString())
            })
            put("amount", JSONObject().apply {
                put("asset_id", _curr_asset.getString("id"))
                put("amount", n_total_pow.toPlainString())
            })
            put("from", op_account.getString("id"))
            put("blinding_factor", blinding_factor)
            put("outputs", blind_output_args.getJSONArray("blind_outputs"))
        }

        val value = if (i_output_count > 1) {
            String.format(resources.getString(R.string.kVcStTipAskConfrimTransferToBlindN),
                    i_output_count.toString(),
                    n_total.toPlainString(),
                    _curr_asset.getString("symbol"),
                    n_core_fee.toPlainString(),
                    core_asset.getString("symbol"))
        } else {
            String.format(resources.getString(R.string.kVcStTipAskConfrimTransferToBlind1),
                    n_total.toPlainString(),
                    _curr_asset.getString("symbol"),
                    n_core_fee.toPlainString(),
                    core_asset.getString("symbol"))
        }

        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), value).then {
            if (it != null && it as Boolean) {
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {

                        //  确保有权限发起普通交易，否则作为提案交易处理。
                        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_transfer_to_blind, false, false,
                                op, op_account) { isProposal, _ ->
                            assert(!isProposal)

                            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
                            BitsharesClientManager.sharedBitsharesClientManager().transferToBlind(op).then {
                                //  自动导入【我的】收据
                                val walletMgr = WalletManager.sharedWalletManager()
                                val pAppCahce = AppCacheManager.sharedAppCacheManager()
                                for (item in receipt_array.forin<JSONObject>()) {
                                    val blind_balance = item!!.getJSONObject("blind_balance")
                                    //  REMARK：有隐私账号私钥的收据即为我自己的收据。
                                    val real_to_key = blind_balance.optString("real_to_key")
                                    if (real_to_key.isNotEmpty() && walletMgr.havePrivateKey(real_to_key)) {
                                        pAppCahce.appendBlindBalance(blind_balance)
                                    }
                                }
                                pAppCahce.saveWalletInfoToFile()

                                //  [统计]
                                btsppLogCustom("txTransferToBlindFullOK", jsonObjectfromKVS("asset", _curr_asset.getString("symbol")))

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
                }
            }
        }
    }

}
