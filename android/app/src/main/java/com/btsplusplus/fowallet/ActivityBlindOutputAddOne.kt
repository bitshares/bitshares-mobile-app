package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.EditText
import bitshares.OrgUtils
import bitshares.Promise
import bitshares.Utils
import bitshares.toPriceAmountString
import kotlinx.android.synthetic.main.activity_blind_output_add_one.*
import org.json.JSONObject
import java.math.BigDecimal

class ActivityBlindOutputAddOne : BtsppActivity() {

    private var _tf_amount_watcher: UtilsDigitTextWatcher? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_output_add_one)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val asset = args.getJSONObject("asset")
        val n_max_balance = args.opt("n_max_balance") as? BigDecimal
        val result_promise = args.opt("result_promise") as? Promise

        //  初始化UI
        if (n_max_balance != null) {
            tv_available_balance.text = String.format("%s %s %s",
                    resources.getString(R.string.kOtcMcAssetCellAvailable),
                    n_max_balance.toPriceAmountString(),
                    asset.getString("symbol"))
            tv_tailer_btn_all.setOnClickListener { onTailerAllButtonClicked(n_max_balance) }
        } else {
            tv_available_balance.visibility = View.INVISIBLE
            tv_tailer_separator.visibility = View.GONE
            tv_tailer_btn_all.visibility = View.GONE
        }

        //  UI - 输出资产名称
        tv_tailer_asset_symbol.text = asset.getString("symbol")

        //  事件 - 输入框文字变更精度控制
        val tf = findViewById<EditText>(R.id.tf_amount)
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(asset.getInt("precision"))
        tf.addTextChangedListener(_tf_amount_watcher!!)
        _tf_amount_watcher!!.on_value_changed(::onAmountChanged)

        //  我的账户点击事件
        btn_my_accounts.setOnClickListener { onMyAccountClicked() }

        //  提交事件
        btn_done.setOnClickListener { onSubmit(result_promise) }

        //  返回事件
        layout_back_from_blind_output_add_one.setOnClickListener { finish() }
    }

    private fun onAmountChanged(str_amount: String) {
        //  ...
    }

    private fun onTailerAllButtonClicked(n_max_balance: BigDecimal) {
        val tf = findViewById<EditText>(R.id.tf_amount)
        tf.setText(n_max_balance.toPlainString())
        tf.setSelection(tf.text.toString().length)
    }

    private fun onMyAccountClicked() {
        val self = this
        val result_promise = Promise()
        goTo(ActivityBlindAccounts::class.java, true, args = JSONObject().apply {
            put("title", self.resources.getString(R.string.kVcTitleSelectBlindAccount))
            put("result_promise", result_promise)
        })
        result_promise.then {
            val blind_account = it as? JSONObject
            if (blind_account != null) {
                val str_public_key = blind_account.optString("public_key")
                val tf = findViewById<EditText>(R.id.tf_public_key)
                tf.setText(str_public_key)
                tf.setSelection(tf.text.toString().length)
            }
            return@then null
        }
    }

    private fun onSubmit(result_promise: Promise?) {
        val str_authority = tf_public_key.text.toString().trim()
        if (str_authority.isEmpty() || !OrgUtils.isValidBitsharesPublicKey(str_authority)) {
            showToast(resources.getString(R.string.kVcStTipPleaseInputValidBlindAccountAddr))
            return
        }

        val n_amount = Utils.auxGetStringDecimalNumberValue(tf_amount.text.toString().trim())
        if (n_amount <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kVcStTipPleaseInputOutputAmountValue))
            return
        }

        //  返回
        result_promise?.resolve(JSONObject().apply {
            put("public_key", str_authority)
            put("n_amount", n_amount)
        })
        finish()
    }
}
