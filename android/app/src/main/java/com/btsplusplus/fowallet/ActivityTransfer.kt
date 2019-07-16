package com.btsplusplus.fowallet

import android.content.Intent
import android.os.Bundle
import android.widget.EditText
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_transfer.*
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.pow

class ActivityTransfer : BtsppActivity() {

    private var _full_account_data: JSONObject? = null
    private var _default_asset: JSONObject? = null

    private var _balances_hash: JSONObject? = null
    private var _fee_item: JSONObject? = null
    private var _asset_list: JSONArray? = null
    private var _transfer_args: JSONObject? = null
    private var _n_available: Double = 0.0
    private var _s_available: String = ""
    private var _tf_amount_watcher: UtilsDigitTextWatcher? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_transfer)

        //  获取参数
        var args = btspp_args_as_JSONArray()
        _full_account_data = args[0] as JSONObject
        if (args.length() >= 2) {
            _default_asset = args[1] as JSONObject
        }

        setFullScreen()

        layout_back_from_transfer.setOnClickListener {
            finish()
        }

        cell_to_account.setOnClickListener {
            TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
                last_activity.goTo(ActivityTransfer::class.java, true, back = true)
                _transfer_args!!.put("to", it)
                refreshUI()
            }
            goTo(ActivityAccountQueryBase::class.java, true)
        }

        cell_transfer_asset.setOnClickListener {
            val list = mutableListOf<String>()
            for (asset in _asset_list!!) {
                list.add(asset!!.getString("symbol"))
            }
            ViewSelector.show(this, resources.getString(R.string.kVcTransferTipSelectAsset), list.toTypedArray()) { index: Int, result: String ->
                val select_asset = _asset_list!![index] as JSONObject
                //  选择发生变化则刷新
                if (select_asset.getString("symbol") != _transfer_args!!.getJSONObject("asset").getString("symbol")) {
                    setAsset(select_asset)
                    refreshUI()
                }
            }
        }

        //  事件 - 全部按钮
        btn_transfer_all.setOnClickListener {
            val tf = findViewById<EditText>(R.id.tf_amount)
            tf.setText(_s_available)
            tf.setSelection(tf.text.toString().length)
            //  onAmountChanged 会自动触发
        }

        //  事件 - 发送
        btn_send.setOnClickListener {
            onSendButtonClicked()
        }

        //  初始化相关参数
        genTransferDefaultArgs(null)
        refreshUI()

        //  初始化事件
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(findViewById<EditText>(R.id.tf_amount)).set_precision(_transfer_args!!.getJSONObject("asset").getInt("precision"))
        tf_amount.addTextChangedListener(_tf_amount_watcher!!)
        _tf_amount_watcher!!.on_value_changed(::onAmountChanged)
    }

    /**
     * (private) 事件 - 发送按钮点击
     */
    private fun onSendButtonClicked() {
        if (!_fee_item!!.getBoolean("sufficient")) {
            showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }
        val from = _transfer_args!!.getJSONObject("from")
        val asset = _transfer_args!!.getJSONObject("asset")
        val to = _transfer_args!!.optJSONObject("to")
        if (to == null) {
            showToast(resources.getString(R.string.kVcTransferTipSelectToAccount))
            return
        }

        if (from.getString("id") == to.getString("id")) {
            showToast(R.string.kVcTransferSubmitTipFromToIsSame.xmlstring(this))
            return
        }

        val str_amount = findViewById<EditText>(R.id.tf_amount).text.toString()
        if (str_amount == "") {
            showToast(resources.getString(R.string.kVcTransferSubmitTipPleaseInputAmount))
            return
        }

        val amount = Utils.auxGetStringDecimalNumberValue(str_amount).toDouble()
        if (amount <= 0) {
            showToast(resources.getString(R.string.kVcTransferTipInputSendAmount))
            return
        }

        if (amount > _n_available) {
            showToast(resources.getString(R.string.kVcTransferSubmitTipAmountNotEnough))
            return
        }

        //  获取备注(memo)信息
        val str = findViewById<EditText>(R.id.tf_memo).text.toString()
        var str_memo: String? = null
        if (str != "") {
            str_memo = str
        }

        //  检测备注私钥相关信息
        var from_public_memo: String? = null
        if (str_memo != null) {
            val walletMgr = WalletManager.sharedWalletManager()
            val full_account_data = walletMgr.getWalletAccountInfo()!!
            from_public_memo = full_account_data.getJSONObject("account").getJSONObject("options").optString("memo_key")
            if (from_public_memo == null || from_public_memo == "") {
                showToast(resources.getString(R.string.kVcTransferSubmitTipAccountNoMemoKey))
                return
            }
        }

        //  --- 参数大部分检测合法 执行请求 ---
        this.guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                _processTransferCore(from, to, asset, amount, str_memo, from_public_memo)
            }
        }
    }

    /**
     * 获取结果
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == kRequestCodeTransferConfirm) {
            //  1：确认
            if (resultCode == 1) {
                _processTransferCoreReal()
            }
        }
    }

    /**
     * 转账完毕，刷新界面。
     */
    private fun _refreshUI_onSendDone(new_full_account_data: JSONObject) {
        _tf_amount_watcher?.clear()
        findViewById<EditText>(R.id.tf_memo).text.clear()
        genTransferDefaultArgs(new_full_account_data)
        refreshUI()
    }

    private fun _processTransferCoreReal() {
        val asset = _transfer_args!!.getJSONObject("asset")
        val op_data = _transfer_args!!.getJSONObject("kOpData")
        //  请求网络广播
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()
        BitsharesClientManager.sharedBitsharesClientManager().transfer(op_data).then {
            val account_id = _full_account_data!!.getJSONObject("account").getString("id")
            ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_id).then {
                mask.dismiss()
                _refreshUI_onSendDone(it as JSONObject)
                showToast(resources.getString(R.string.kVcTransferTipTxTransferFullOK))
                //  [统计]
                btsppLogCustom("txTransferFullOK", jsonObjectfromKVS("account", account_id, "asset", asset.getString("symbol")))
                return@then null
            }.catch {
                mask.dismiss()
                showToast(resources.getString(R.string.kVcTransferTipTxTransferOK))
                //  [统计]
                btsppLogCustom("txTransferOK", jsonObjectfromKVS("account", account_id, "asset", asset.getString("symbol")))
            }
            return@then null
        }.catch { err ->
            mask.dismiss()
            showGrapheneError(err)
            //  [统计]
            btsppLogCustom("txTransferFailed", jsonObjectfromKVS("asset", asset.getString("symbol")))
        }
    }

    private fun _processTransferCore(from: JSONObject, to: JSONObject, asset: JSONObject, amount: Double, memo: String?, from_public_memo: String?) {
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()

        val promise_map = JSONObject()
        if (memo != null) {
            promise_map.put("to", ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(to.getString("id")))
        }
        Promise.map(promise_map).then {
            //  生成 memo 对象。
            val hashmap = it as JSONObject
            var memo_object: JSONObject? = null
            if (memo != null) {
                val to_full_account_data = hashmap.getJSONObject("to")
                val to_public = to_full_account_data.getJSONObject("account").getJSONObject("options").getString("memo_key")
                memo_object = WalletManager.sharedWalletManager().genMemoObject(memo, from_public_memo!!, to_public)
                if (memo_object == null) {
                    mask.dismiss()
                    showToast(R.string.kVcTransferSubmitTipWalletNoMemoKey.xmlstring(this))
                    return@then null
                }
            }
            //  --- 开始构造OP ---
            //  TODO:ulong
            val amount_pow = (amount * 10.0.pow(asset.getInt("precision"))).toLong()
            val fee_asset_id = _fee_item!!.getString("fee_asset_id")
            val fee = jsonObjectfromKVS("amount", 0, "asset_id", fee_asset_id)
            val op_amount = jsonObjectfromKVS("amount", amount_pow.toString(), "asset_id", asset.getString("id"))
            val op_data = jsonObjectfromKVS("fee", fee, "from", from.getString("id"), "to", to.getString("id"), "amount", op_amount)
            if (memo_object != null) {
                op_data.put("memo", memo_object)
            }
            //  --- 开始评估手续费 ---
            BitsharesClientManager.sharedBitsharesClientManager().calcOperationFee(op_data, EBitsharesOperations.ebo_transfer).then {
                mask.dismiss()
                val fee_price_item = it as JSONObject
                //  判断手续费是否足够。
                val n_fee_cost = _isFeeSufficient(fee_price_item, fee_asset_id, asset, amount)
                if (n_fee_cost == null) {
                    showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
                    return@then null
                }
                //  --- 弹框确认转账行为 ---
                //  弹确认框之前 设置参数
                _transfer_args!!.put("kAmount", amount)
                _transfer_args!!.put("kFeeCost", n_fee_cost)
                _transfer_args!!.put("kOpData", op_data)        //  传递过去，避免再次构造。
                if (memo != null) {
                    _transfer_args!!.put("kMemo", memo)
                } else {
                    _transfer_args!!.remove("kMemo")
                }
                //  确保有权限发起普通交易，否则作为提案交易处理。
                GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_transfer, false, false,
                        op_data, _full_account_data!!.getJSONObject("account")) { isProposal, _ ->
                    assert(!isProposal)
                    //  非提案交易：转转账确认界面
                    goTo(ActivityTransferConfirm::class.java, true, args = _transfer_args, request_code = kRequestCodeTransferConfirm)
                }
                return@then null
            }.catch {
                mask.dismiss()
                showToast(resources.getString(R.string.tip_network_error))
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     *  (private) 辅助 - 判断手续费是否足够，足够则返回需要消耗的手续费，不足则返回 nil。
     *  fee_price_item      - 服务器返回的需要手续费值
     *  fee_asset_id        - 当前手续费资产ID
     *  asset               - 正在转账的资产
     *  n_amount            - 正在转账的数量
     */
    private fun _isFeeSufficient(fee_price_item: JSONObject, fee_asset_id: String, asset: JSONObject, n_amount: Double): Double? {
        assert(fee_price_item.getString("asset_id") == fee_asset_id)
        //  1、转账消耗资产值（只有转账资产和手续费资产相同时候才设置）
        var n_transfer_cost: Double = 0.0
        if (asset.getString("id") == fee_asset_id) {
            n_transfer_cost = n_amount
        }

        //  2、手续费消耗值
        val fee_asset = _transfer_args!!.getJSONObject("fee_asset")
        val n_fee_cost = fee_price_item.getString("amount").toDouble() / 10.0.pow(fee_asset.getInt("precision"))

        //  3、总消耗值
        val n_total_cost = n_transfer_cost + n_fee_cost

        //  4、获取手续费资产总的可用余额
        var n_available: Double = 0.0
        for (balance_object in _full_account_data!!.getJSONArray("balances")) {
            val asset_type = balance_object!!.getString("asset_type")
            if (asset_type == fee_asset_id) {
                n_available = balance_object.getString("balance").toDouble() / 10.0.pow(fee_asset.getInt("precision"))
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

    /**
     * (private) 转账数量发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        val asset = _transfer_args!!.getJSONObject("asset")
        //  无效输入
        val symbol = asset.getString("symbol")
        val tf = findViewById<TextView>(R.id.txt_value_avaiable)
        if (str_amount == "") {
            tf.text = "${_s_available}${symbol}"
            tf.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            return
        }
        val amount = Utils.auxGetStringDecimalNumberValue(str_amount).toDouble()
        if (amount > _n_available) {
            tf.text = "${_s_available}${symbol}(${resources.getString(R.string.kVcTransferSubmitTipAmountNotEnough)})"
            tf.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            tf.text = "${_s_available}${symbol}"
            tf.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
    }

    private fun genTransferDefaultArgs(full_account_data: JSONObject?) {
        //  保存当前帐号信息
        if (full_account_data != null) {
            _full_account_data = full_account_data
        }

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        //  初始化余额Hash(原来的是Array)
        _balances_hash = JSONObject()
        for (balance_object in _full_account_data!!.getJSONArray("balances")) {
            val asset_type = balance_object!!.getString("asset_type")
            val balance = balance_object.getString("balance")
            _balances_hash!!.put(asset_type, jsonObjectfromKVS("asset_id", asset_type, "amount", balance))
        }
        //  初始化默认值余额（从资产界面点击转账过来，该资产余额可能为0。）
        if (_default_asset != null) {
            val def_id = _default_asset!!.getString("id")
            val def_balance_item = _balances_hash!!.optJSONObject(def_id)
            if (def_balance_item == null) {
                _balances_hash!!.put(def_id, jsonObjectfromKVS("asset_id", def_id, "amount", 0))
            }
        }
        val balances_list = _balances_hash!!.values()
        //  计算手续费对象（更新手续费资产的可用余额，即减去手续费需要的amount）
        _fee_item = chainMgr.estimateFeeObject(EBitsharesOperations.ebo_transfer.value, balances_list)
        val fee_asset_id = _fee_item!!.getString("fee_asset_id")
        val fee_balance = _balances_hash!!.optJSONObject(fee_asset_id)
        if (fee_balance != null) {
            val fee = _fee_item!!.getString("amount").toDouble()
            val old = fee_balance.getString("amount").toDouble()
            val new_balance = JSONObject()
            new_balance.put("asset_id", fee_asset_id)
            if (old >= fee) {
                new_balance.put("amount", (old - fee).toLong())
            } else {
                new_balance.put("amount", 0)
            }
            _balances_hash!!.put(fee_asset_id, new_balance)
        }

        //  获取余额不为0的资产列表
        var none_zero_balances = JSONArray()
        for (balance_item in balances_list) {
            if (balance_item!!.getString("amount").toLong() != 0L) {
                none_zero_balances.put(balance_item)
            }
        }
        //  如果资产列表为空，则添加默认值。{BTS:0}
        if (none_zero_balances.length() <= 0) {
            val balance_object = jsonObjectfromKVS("asset_id", BTS_NETWORK_CORE_ASSET_ID, "amount", 0)
            none_zero_balances = jsonArrayfrom(balance_object)
            _balances_hash!!.put(balance_object.getString("asset_id"), balance_object)
        }

        //  获取资产详细信息列表
        _asset_list = JSONArray()
        for (balance_object in none_zero_balances) {
            _asset_list!!.put(chainMgr.getChainObjectByID(balance_object!!.getString("asset_id")))
        }
        assert(_asset_list!!.length() > 0)

        //  初始化转账默认参数：from、fee_asset
        var last_asset: JSONObject? = null
        if (_transfer_args != null) {
            //  REMARK：第二次调用该方法时才存在 last_asset，上次转账的资产。
            last_asset = _transfer_args!!.getJSONObject("asset")
        }
        _transfer_args = JSONObject()
        val account_info = _full_account_data!!.getJSONObject("account")
        _transfer_args!!.put("from", jsonObjectfromKVS("id", account_info.getString("id"), "name", account_info.getString("name")))
        if (_default_asset == null) {
            //  TODO:fowallet 默认值，优先选择CNY、没CNY选择BTS。TODO：USD呢？？
            for (asset in _asset_list!!) {
                if (asset!!.getString("id") == "1.3.113") {
                    _default_asset = asset
                    break
                }
            }
            if (_default_asset == null) {
                for (asset in _asset_list!!) {
                    if (asset!!.getString("id") == "1.3.0") {
                        _default_asset = asset
                        break
                    }
                }
            }
            if (_default_asset == null) {
                _default_asset = _asset_list!![0] as JSONObject
            }
        }
        val fee_asset = chainMgr.getChainObjectByID(_fee_item!!.getString("fee_asset_id"))
        _transfer_args!!.put("fee_asset", fee_asset)

        //  设置当前资产
        setAsset(last_asset ?: _default_asset!!)
    }

    private fun refreshUI() {
        findViewById<TextView>(R.id.txt_value_from_name).text = _transfer_args!!.getJSONObject("from").getString("name")
        val to = _transfer_args!!.optJSONObject("to")
        val to_txt = findViewById<TextView>(R.id.txt_value_to_name)
        if (to != null) {
            to_txt.text = to.getString("name")
            to_txt.setTextColor(resources.getColor(R.color.theme01_buyColor))
        } else {
            to_txt.text = resources.getString(R.string.kVcTransferTipSelectToAccount)
            to_txt.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
        findViewById<TextView>(R.id.txt_value_asset_name).text = _transfer_args!!.getJSONObject("asset").getString("symbol")
    }

    /**
     * 设置待转账资产：更新可用余额等信息
     */
    private fun setAsset(new_asset: JSONObject) {
        _transfer_args!!.put("asset", new_asset)
        val new_asset_id = new_asset.getString("id")
        val balance = _balances_hash!!.getJSONObject(new_asset_id).getString("amount")

        val precision = new_asset.getInt("precision")
        _n_available = balance.toDouble() / 10.0.pow(precision)
        _s_available = OrgUtils.formatAssetString(balance.toString(), precision, has_comma = false)

        //  更新UI - 可用余额
        val symbol = new_asset.getString("symbol")
        findViewById<TextView>(R.id.txt_value_avaiable).text = "${_s_available}${symbol}"

        //  切换资产清除当前输入的数量
        _tf_amount_watcher?.set_precision(precision)?.clear()
    }
}
