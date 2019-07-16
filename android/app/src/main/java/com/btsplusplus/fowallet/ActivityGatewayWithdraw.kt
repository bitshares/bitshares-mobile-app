package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.Gravity
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.ViewEx.EditTextEx
import com.btsplusplus.fowallet.ViewEx.TextViewEx
import com.btsplusplus.fowallet.gateway.GatewayAssetItemData
import com.btsplusplus.fowallet.gateway.GatewayBase
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_gateway_withdraw.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityGatewayWithdraw : BtsppActivity() {

    private lateinit var _withdraw_args: JSONObject
    private lateinit var _fullAccountData: JSONObject
    private var _intermediateAccount: JSONObject? = null
    private lateinit var _withdrawAssetItem: JSONObject
    private lateinit var _result_promise: Promise
    private lateinit var _gateway: JSONObject

    private var _asset: JSONObject? = null
    private var _precision_amount = 8
    private var _n_available = BigDecimal.ZERO
    private var _n_withdrawMinAmount = BigDecimal.ZERO
    private var _n_withdrawGateFee = BigDecimal.ZERO
    private var _aux_data_array = JSONArray()
    private var _bSupportMemo = false

    private var _cell_final_value: TextViewEx? = null
    private var _tf_amount_watcher: UtilsDigitTextWatcher? = null
    private var _tf_memo: EditText? = null

    private var _withdrawBalanceDirty = false                   //  是否发生提币，如果提币了返回列表需要刷新。

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_gateway_withdraw)

        //  获取参数 / get params
        _withdraw_args = btspp_args_as_JSONObject()
        _fullAccountData = _withdraw_args.getJSONObject("fullAccountData")
        _intermediateAccount = _withdraw_args.optJSONObject("intermediateAccount")
        _withdrawAssetItem = _withdraw_args.getJSONObject("withdrawAssetItem")
        _result_promise = _withdraw_args.get("result_promise") as Promise
        _gateway = _withdraw_args.getJSONObject("gateway")
        val appext = _withdrawAssetItem.get("kAppExt") as GatewayAssetItemData
        val balance = appext.balance
        if (!balance.optBoolean("iszero")) {
            _asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(balance.getString("asset_id"))
            _precision_amount = _asset!!.getInt("precision")
            _refreshWithdrawAssetBalance(null)
        }
        _bSupportMemo = appext.supportMemo
        val ctx = this
        //  附加信息数据
        val symbol = appext.symbol
        val withdrawMinAmount = appext.withdrawMinAmount
        if (withdrawMinAmount != null && withdrawMinAmount != "") {
            _n_withdrawMinAmount = BigDecimal(withdrawMinAmount!!.fixComma())
            _aux_data_array.put(JSONObject().apply {
                put("title", R.string.kVcDWCellMinWithdrawNumber.xmlstring(ctx))
                put("value", "$withdrawMinAmount $symbol")
            })
        }
        val withdrawGateFee = appext.withdrawGateFee
        if (withdrawGateFee != null && withdrawGateFee != "") {
            _n_withdrawGateFee = BigDecimal(withdrawGateFee!!.fixComma())
            _aux_data_array.put(JSONObject().apply {
                put("title", R.string.kVcDWCellWithdrawFee.xmlstring(ctx))
                put("value", "$withdrawGateFee $symbol")
            })
        }

        if (_intermediateAccount != null) {
            _aux_data_array.put(JSONObject().apply {
                put("title", R.string.kVcDWCellWithdrawGatewayAccount.xmlstring(ctx))
                put("value", _intermediateAccount!!.getJSONObject("account").getString("name"))
            })
        }
        if (appext.withdrawMaxAmountOnce != null && appext.withdrawMaxAmountOnce != "") {
            _aux_data_array.put(JSONObject().apply {
                put("title", R.string.kVcDWCellMaxWithdrawNumberOnce.xmlstring(ctx))
                put("value", "${appext.withdrawMaxAmountOnce} $symbol")
            })
        }
        if (appext.withdrawMaxAmount24Hours != null && appext.withdrawMaxAmount24Hours != "") {
            _aux_data_array.put(JSONObject().apply {
                put("title", R.string.kVcDWCellMaxWithdrawNumber24Hours.xmlstring(ctx))
                put("value", "${appext.withdrawMaxAmount24Hours} $symbol")
            })
        }

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  back
        layout_back_from_gateway_withdraw.setOnClickListener { onBackClicked(null) }

        //  init ui
        initAllUI()

        //  events
        val tf = findViewById<EditText>(R.id.tf_withdraw_amount)
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_precision_amount)
        tf.addTextChangedListener(_tf_amount_watcher!!)
        _tf_amount_watcher!!.on_value_changed(::onAmountChanged)
    }

    override fun onBackClicked(result: Any?) {
        _result_promise.resolve(_withdrawBalanceDirty)
        finish()
    }

    /**
     *  (private) 刷新提币资产可用余额
     */
    private fun _refreshWithdrawAssetBalance(fullAccountData: JSONObject?) {
        val full_account_data = fullAccountData ?: _fullAccountData
        if (fullAccountData != null) {
            _fullAccountData = fullAccountData!!
        }
        if (_asset == null) {
            return
        }
        val asset_id = _asset!!.getString("id")
        var asset_value = "0"
        for (balance_item in full_account_data.getJSONArray("balances").forin<JSONObject>()) {
            val asset_type = balance_item!!.getString("asset_type")
            if (asset_type == asset_id) {
                asset_value = balance_item.getString("balance")
                break
            }
        }
        _n_available = bigDecimalfromAmount(asset_value, _precision_amount)
    }

    /**
     *  (private) 计算实际到账数量
     */
    private fun _calcFinalValue(amount: BigDecimal): BigDecimal {
        var n_final_value = amount.subtract(_n_withdrawGateFee)
        if (n_final_value < BigDecimal.ZERO) {
            n_final_value = BigDecimal.ZERO
        }
        return n_final_value
    }

    /**
     *  (private) 刷新实际到账数量
     */
    private fun _refreshFinalValueUI(amount: BigDecimal) {
        _cell_final_value?.let {
            it.text = "${_calcFinalValue(amount).toPlainString()} ${(_withdrawAssetItem.get("kAppExt") as GatewayAssetItemData).backSymbol}"
        }
    }

    /**
     *  (private) 转账数量发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        val symbol = (_withdrawAssetItem.get("kAppExt") as GatewayAssetItemData).symbol

        //  无效输入
        if (str_amount == "") {
            available_of_withdraw_page.let {
                it.text = "${_n_available.toPlainString()} $symbol"
                it.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            }
            return
        }

        //  获取输入的数量
        val n_amount = Utils.auxGetStringDecimalNumberValue(str_amount)

        //  _n_available < n_amount
        if (_n_available < n_amount) {
            //  数量不足
            available_of_withdraw_page.let {
                it.text = "${_n_available.toPlainString()} $symbol(${R.string.kVcTransferSubmitTipAmountNotEnough.xmlstring(this)})"
                it.setTextColor(resources.getColor(R.color.theme01_tintColor))
            }
        } else {
            available_of_withdraw_page.let {
                it.text = "${_n_available.toPlainString()} $symbol"
                it.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            }
        }

        _refreshFinalValueUI(n_amount)
    }

    private fun initAllUI() {
        val ctx = this

        //  标题
        findViewById<TextView>(R.id.id_title).text = _withdraw_args.getString("title")

        //  可用
        available_of_withdraw_page.text = "${_n_available.toPlainString()} ${(_withdrawAssetItem.get("kAppExt") as GatewayAssetItemData).symbol}"

        //  备注信息
        var label_memo_title: TextViewEx? = null
        if (_bSupportMemo) {
            label_memo_title = TextViewEx(this, R.string.kVcDWCellWithdrawMemo.xmlstring(ctx), dp_size = 13.0f, margin_top = 10.dp, margin_bottom = 10.dp, width = LLAYOUT_MATCH)
            _tf_memo = EditTextEx(this, R.string.kVcDWCellWithdrawPlaceholderMemo.xmlstring(ctx), dp_size = 17.0f).initWithSingleLine()
        }

        //  附加信息
        val aux_data_uilist = JSONArray()
        _aux_data_array.forEach<JSONObject> {
            val item = it!!
            val layout = LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 10.dp, 0, 0)
                }
                addView(TextViewEx(ctx, item.getString("title"), dp_size = 13.0f, width = LLAYOUT_WARP, color = R.color.theme01_textColorGray, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL))
                addView(TextViewEx(ctx, item.getString("value"), dp_size = 13.0f, width = LLAYOUT_MATCH, color = R.color.theme01_textColorNormal, gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL))
            }
            aux_data_uilist.put(layout)
        }

        //  实际到账
        val layout_min_withdraw_in_account = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                setMargins(0, 50.dp, 0, 0)
            }
            addView(TextViewEx(ctx, R.string.kVcDWCellWithdrawFinalValue.xmlstring(ctx), dp_size = 13.0f, width = LLAYOUT_WARP, color = R.color.theme01_textColorMain, gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL))
            _cell_final_value = TextViewEx(ctx, "", dp_size = 13.0f, width = LLAYOUT_MATCH, color = R.color.theme01_buyColor, gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL).apply {
                paint.isFakeBoldText = true
            }
            _refreshFinalValueUI(BigDecimal.ZERO)
            addView(_cell_final_value)
        }

        //  提币按钮
        val tv_button_withdraw = TextViewEx(ctx, resources.getString(R.string.kVcDWWithdrawSubmitButton), gravity = Gravity.CENTER, width = LLAYOUT_MATCH, height = 32.dp, margin_top = 10.dp)
        tv_button_withdraw.setBackgroundColor(resources.getColor(R.color.theme01_mainButtonBackColor))
        tv_button_withdraw.setOnClickListener { gotoWithdrawCore() }

        //  点击全部
        total_text_of_withdraw_page.setOnClickListener {
            _tf_amount_watcher?.let {
                it.set_new_text(_n_available.toPlainString())
                onAmountChanged(it.get_tf_string())
            }
        }

        layout_parent_of_withdraw_page.apply {
            _tf_memo?.let {
                addView(label_memo_title!!)
                addView(it)
                addView(ViewLine(ctx, margin_top = 10.dp))
            }
            aux_data_uilist.forEach<LinearLayout> { addView(it!!) }
            addView(layout_min_withdraw_in_account)
            addView(tv_button_withdraw)
        }
    }

    private fun gotoWithdrawCore() {
        val str_address = tf_withdraw_address.text.toString()
        if (str_address == "" || str_address.isEmpty()) {
            showToast(R.string.kVcDWSubmitTipsAddressCannotBeEmpty.xmlstring(this))
            return
        }

        val str_amount = tf_withdraw_amount.text.toString()
        var str_memo = ""
        if (_bSupportMemo && _tf_memo != null) {
            str_memo = _tf_memo!!.text.toString()
        }

        val n_amount = Utils.auxGetStringDecimalNumberValue(str_amount)
        if (n_amount <= BigDecimal.ZERO) {
            showToast(R.string.kVcDWSubmitTipsPleaseInputAmount.xmlstring(this))
            return
        }

        if (_n_available < n_amount) {
            showToast(R.string.kVcDWSubmitTipsWithdrawAmountNotEnough.xmlstring(this))
            return
        }

        if (n_amount < _n_withdrawMinAmount) {
            showToast(R.string.kVcDWSubmitTipsWithdrawLessThanMinNumber.xmlstring(this))
            return
        }

        val n_final_value = _calcFinalValue(n_amount)
        if (n_final_value <= BigDecimal.ZERO) {
            showToast(R.string.kVcDWSubmitTipsFinalValueTooLow.xmlstring(this))
            return
        }

        val from_public_memo = _fullAccountData.getJSONObject("account").getJSONObject("options").optString("memo_key")
        if (from_public_memo == "" || from_public_memo.isEmpty()) {
            showToast(R.string.kVcDWSubmitTipsNoMemoCannotWithdraw.xmlstring(this))
            return
        }

        //  --- 参数大部分检测合法 执行请求 ---
        //  TODO:REMARK：解锁钱包，这里和其它交易不同，这里严格检查active权限，目前提案交易不支持，因为提案转账大部分都没有memokey，提币存在问题。
        guardWalletUnlocked(true) { unlocked ->
            //  a、解锁钱包成功
            if (unlocked) {
                if (WalletManager.sharedWalletManager().havePrivateKey(from_public_memo)) {
                    //  安全提示（二次确认）：
                    //  1、没有填写备注时提示是否缺失。
                    //  2、填写了备注提示二次确认是否正确。
                    val tipMessage: String = if (_bSupportMemo) {
                        if (str_memo != "" && str_memo.isNotEmpty()) {
                            R.string.kVcDWSubmitSecondConfirmMsg01.xmlstring(this)
                        } else {
                            R.string.kVcDWSubmitSecondConfirmMsg02.xmlstring(this)
                        }
                    } else {
                        R.string.kVcDWSubmitSecondConfirmMsg03.xmlstring(this)
                    }
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), tipMessage, btn_ok = R.string.kVcDWSubmitSecondBtnContinue.xmlstring(this)).then {
                        if (it != null && it as Boolean) {
                            //  b、继续提币确认
                            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
                            mask.show()

                            val appext = _withdrawAssetItem.get("kAppExt") as GatewayAssetItemData
                            val intermediateAccountData = _intermediateAccount?.getJSONObject("account")

                            //  REMARK：查询提币所需信息（账号、memo等）该接口返回都promise不会发生reject，不用catch。
                            (_gateway.get("api") as GatewayBase).queryWithdrawIntermediateAccountAndFinalMemo(appext, str_address, str_memo, intermediateAccountData).then {
                                val withdraw_info = it as? JSONObject
                                if (withdraw_info == null) {
                                    mask.dismiss()
                                    showToast(R.string.kVcDWErrTipsRequestWithdrawAddrFailed.xmlstring(this))
                                    return@then null
                                }

                                val final_account = withdraw_info.getString("intermediateAccount")
                                val final_memo = withdraw_info.getString("finalMemo")
                                val final_account_data = withdraw_info.getJSONObject("intermediateAccountData")

                                //  REMARK：验证提币地址、数量、备注等是否合法。不用catch。
                                (_gateway.get("api") as GatewayBase).checkAddress(_withdrawAssetItem, str_address, final_memo, n_amount.toString()).then { valid ->
                                    if (valid != null && valid as Boolean) {
                                        //  c、地址验证通过继续提币
                                        _processWithdrawCore(mask, str_address, n_amount, final_memo, final_account_data, from_public_memo)
                                    } else {
                                        mask.dismiss()
                                        showToast(R.string.kVcDWSubmitTipsInvalidAddress.xmlstring(this))
                                    }
                                    return@then null
                                }
                                return@then null
                            }
                        }
                        return@then null
                    }
                } else {
                    //  no memo private key
                    showToast(R.string.kVcDWSubmitTipsNoMemoCannotWithdraw.xmlstring(this))
                }
            }
        }
    }

    private fun _refreshUI(full_account_data: JSONObject) {
        //  clear
        _tf_amount_watcher?.set_new_text("")
        _tf_memo?.setText("")

        //  刷新可用余额数量
        _refreshWithdrawAssetBalance(full_account_data)

        //  刷新UI
        available_of_withdraw_page.let {
            it.text = "${_n_available.toPlainString()} ${(_withdrawAssetItem.get("kAppExt") as GatewayAssetItemData).symbol}"
            it.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
        _refreshFinalValueUI(BigDecimal.ZERO)
    }

    /**
     *  (private) 各种参数校验通过，处理提币转账请求。
     */
    private fun _processWithdrawCore(mask: ViewMask, address: String, n_amount: BigDecimal, final_memo: String, final_intermediate_account: JSONObject, from_public_memo: String) {
        assert(_asset != null)

        //  TODO:fowallet 很多特殊处理
        //  useFullAssetName        - 部分网关提币备注资产名需要 网关.资产
        //  assetWithdrawlAlias     - 部分网关部分币种提币备注和bts上资产名字不同。
        // val assetName = (_withdrawAssetItem.get("kAppExt") as GatewayAssetItemData).backSymbol

        // var final_memo: String
        // if (memo.isNotEmpty()) {
        //     final_memo = "$assetName:$address:$memo"
        // } else {
        //     final_memo = "$assetName:$address"
        // }

        val to_account = final_intermediate_account
        val to_public = to_account.getJSONObject("options").getString("memo_key")
        val memo_object = WalletManager.sharedWalletManager().genMemoObject(final_memo, from_public_memo, to_public)
        if (memo_object == null) {
            mask.dismiss()
            showToast(R.string.kVcTransferSubmitTipWalletNoMemoKey.xmlstring(this))
            return
        }

        //  --- 开始构造OP ---
        val from_account = _fullAccountData.getJSONObject("account")
        val n_amount_pow = n_amount.scaleByPowerOfTen(_precision_amount).toLong()

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", BTS_NETWORK_CORE_ASSET_ID)
            })
            put("from", from_account.getString("id"))
            put("to", to_account.getString("id"))
            put("amount", JSONObject().apply {
                put("amount", n_amount_pow)
                put("asset_id", _asset!!.getString("id"))
            })
            put("memo", memo_object!!)
        }

        //  请求网络广播
        val account_id = from_account.getString("id")
        BitsharesClientManager.sharedBitsharesClientManager().transfer(op).then {
            //  设置脏标记，返回网关列表需要刷新。
            _withdrawBalanceDirty = true
            ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_id).then {
                mask.dismiss()
                _refreshUI(it as JSONObject)
                showToast(R.string.kVcDWSubmitTxFullOK.xmlstring(this))
                //  [统计]
                btsppLogCustom("txGatewayWithdrawFullOK", jsonObjectfromKVS("account", account_id, "asset", _asset!!.getString("symbol")))
                return@then null
            }.catch {
                mask.dismiss()
                showToast(R.string.kVcDWSubmitTxOK.xmlstring(this))
                //  [统计]
                btsppLogCustom("txGatewayWithdrawOK", jsonObjectfromKVS("account", account_id, "asset", _asset!!.getString("symbol")))
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            showGrapheneError(err)
            //  [统计]
            btsppLogCustom("txGatewayWithdrawFailed", jsonObjectfromKVS("account", account_id, "asset", _asset!!.getString("symbol")))
        }

    }
}
