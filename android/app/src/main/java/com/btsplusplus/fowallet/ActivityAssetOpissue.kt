package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.EditText
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_asset_op_issue.*
import org.json.JSONObject
import java.math.BigDecimal

class ActivityAssetOpissue : BtsppActivity() {

    //  外部参数
    private lateinit var _asset: JSONObject
    private lateinit var _dynamic_asset_data: JSONObject
    private var _result_promise: Promise? = null

    //  实例变量
    private var _precision = 0
    private var _to_account: JSONObject? = null
    private lateinit var _n_max_supply: BigDecimal
    private lateinit var _n_cur_supply: BigDecimal
    private lateinit var _n_balance: BigDecimal
    private lateinit var _tf_amount_watcher: UtilsDigitTextWatcher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_op_issue)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _asset = args.getJSONObject("kAsset")
        _dynamic_asset_data = args.getJSONObject("kDynamicAssetData")
        _result_promise = args.opt("result_promise") as? Promise
        findViewById<TextView>(R.id.title).text = args.getString("kTitle")

        //  初始化实例变量
        _precision = _asset.getInt("precision")
        _n_max_supply = bigDecimalfromAmount(_asset.getJSONObject("options").getString("max_supply"), _precision)
        _n_cur_supply = bigDecimalfromAmount(_dynamic_asset_data.getString("current_supply"), _precision)
        _n_balance = _n_max_supply.subtract(_n_cur_supply)
        //  REMARK：发行出去之后又更新了最大供应量，则最大供应量可能小于当前供应量，则这里可能为负数。
        if (_n_balance < BigDecimal.ZERO) {
            _n_balance = BigDecimal.ZERO
        }

        //  初始化UI
        drawUI_currAsset()
        drawUI_supply()
        drawUI_balance(false)

        //  事件 - 选择目标账号
        img_arrow_target_account.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        layout_target_account.setOnClickListener { onTargetAccountClicked() }

        //  事件 - 全部
        btn_tf_tailer_all.setOnClickListener { onSelectAllClicked() }

        //  事件 - 发行
        btn_submit.setOnClickListener { onSubmitClicked() }

        //  事件 - 返回
        layout_back_from_assets_opissue.setOnClickListener { finish() }

        //  输入框
        val tf = findViewById<EditText>(R.id.tf_amount)
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_asset.getInt("precision"))
        tf.addTextChangedListener(_tf_amount_watcher)
        _tf_amount_watcher.on_value_changed(::onAmountChanged)
    }

    private fun drawUI_currAsset() {
        tv_tf_tailer_asset_symbol.text = _asset.getString("symbol")
    }

    private fun drawUI_supply() {
        val symbol = _asset.getString("symbol")
        tv_max_supply.text = "${OrgUtils.formatFloatValue(_n_max_supply.toDouble(), _precision, has_comma = true)} $symbol"
        tv_cur_supply.text = "${OrgUtils.formatFloatValue(_n_cur_supply.toDouble(), _precision, has_comma = true)} $symbol"
    }

    private fun drawUI_targetAccount() {
        if (_to_account != null) {
            tv_target_account_main.setTextColor(resources.getColor(R.color.theme01_buyColor))
            tv_target_account_main.text = _to_account!!.getString("name")
            tv_target_account_detail.text = _to_account!!.getString("id")
        } else {
            tv_target_account_main.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tv_target_account_main.text = resources.getString(R.string.kVcAssetOpCellValueIssueTargetAccountDefault)
            tv_target_account_detail.text = ""
        }
//        }
    }

    private fun drawUI_balance(not_enough: Boolean) {
        val symbol = _asset.getString("symbol")
        if (not_enough) {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_n_balance.toPlainString()} $symbol(${resources.getString(R.string.kOtcMcAssetTransferBalanceNotEnough)})"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            tv_curr_balance.text = "${resources.getString(R.string.kOtcMcAssetCellAvailable)} ${_n_balance.toPlainString()} $symbol"
            tv_curr_balance.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
    }

    /**
     *  (private) 数量输入框发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        drawUI_balance(_n_balance < Utils.auxGetStringDecimalNumberValue(str_amount))
    }

    /**
     *  (private) 选择全部数量
     */
    private fun onSelectAllClicked() {
        val tf = findViewById<EditText>(R.id.tf_amount)
        tf.setText(_n_balance.toPlainString())
        tf.setSelection(tf.text.toString().length)
        //  onAmountChanged 会自动触发
    }

    /**
     *  事件 - 点击选择目标账号
     */
    private fun onTargetAccountClicked() {
        TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
            last_activity.goTo(ActivityAssetOpissue::class.java, true, back = true)
            //  设置代理人
            _to_account = it
            drawUI_targetAccount()
        }
        goTo(ActivityAccountQueryBase::class.java, true)
    }

    /**
     *  事件 - 点击提交按钮
     */
    private fun onSubmitClicked() {
        if (_to_account == null) {
            showToast(resources.getString(R.string.kVcAssetOpSubmitTipsIssuePleaseSelectTargetAccount))
            return
        }

        val n_amount = Utils.auxGetStringDecimalNumberValue(_tf_amount_watcher.get_tf_string())
        if (n_amount <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kVcAssetOpSubmitTipsIssuePleaseInputIssueAmount))
            return
        }

        if (_n_balance < n_amount) {
            showToast(resources.getString(R.string.kVcAssetOpSubmitTipsIssueNotEnough))
            return
        }

        //  获取备注(memo)信息
        val str = findViewById<EditText>(R.id.tf_memo).text.toString()
        var str_memo: String? = null
        if (str.isNotEmpty()) {
            str_memo = str
        }

        val value = String.format(resources.getString(R.string.kVcAssetOpSubmitAskIssue), n_amount.toPlainString(), _asset.getString("symbol"), _to_account!!.getString("name"))
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), value).then {
            if (it != null && it as Boolean) {
                val from = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        _processIssueAssetCore(from, _to_account!!, _asset, n_amount, str_memo)
                    }
                }
            }
        }
    }

    private fun _processIssueAssetCore(from: JSONObject, to: JSONObject, asset: JSONObject, n_amount: BigDecimal, memo: String?) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val promise_map = JSONObject().apply {
            put("to", chainMgr.queryFullAccountInfo(to.getString("id")))
        }

        VcUtils.simpleRequest(this, Promise.map(promise_map)) {
            //  生成 memo 对象。
            val hashmap = it as JSONObject
            var memo_object: JSONObject? = null
            if (memo != null) {
                val from_public_memo = from.getJSONObject("options").getString("memo_key")
                val to_full_account_data = hashmap.getJSONObject("to")
                val to_public = to_full_account_data.getJSONObject("account").getJSONObject("options").getString("memo_key")
                memo_object = WalletManager.sharedWalletManager().genMemoObject(memo, from_public_memo, to_public)
                if (memo_object == null) {
                    showToast(resources.getString(R.string.kVcTransferSubmitTipWalletNoMemoKey))
                    return@simpleRequest
                }
            }

            //  --- 开始构造OP ---
            val n_amount_pow = n_amount.multiplyByPowerOf10(asset.getInt("precision"))
            val opdata = JSONObject().apply {
                put("fee", JSONObject().apply {
                    put("asset_id", chainMgr.grapheneCoreAssetID)
                    put("amount", 0)
                })
                put("issuer", from.getString("id"))
                put("asset_to_issue", JSONObject().apply {
                    put("asset_id", asset.getString("id"))
                    put("amount", n_amount_pow.toPlainString())
                })
                put("issue_to_account", to.getString("id"))
                put("memo", memo_object)
            }

            //  确保有权限发起普通交易，否则作为提案交易处理。
            GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_asset_issue, false, false,
                    opdata, from) { isProposal, _ ->
                assert(!isProposal)
                //  请求网络广播
                val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
                BitsharesClientManager.sharedBitsharesClientManager().assetIssue(opdata).then {
                    mask.dismiss()
                    //  发行成功
                    showToast(resources.getString(R.string.kVcAssetOpSubmitTipsIssueOK))
                    //  [统计]
                    btsppLogCustom("txAssetIssueFullOK", jsonObjectfromKVS("issuer", from.getString("id")))
                    //  返回上一个界面并刷新
                    _result_promise?.resolve(true)
                    _result_promise = null
                    finish()
                    return@then null
                }.catch { err ->
                    mask.dismiss()
                    showGrapheneError(err)
                    //  [统计]
                    btsppLogCustom("txAssetIssueFailed", jsonObjectfromKVS("issuer", from.getString("id")))
                }
            }
        }
    }
}
