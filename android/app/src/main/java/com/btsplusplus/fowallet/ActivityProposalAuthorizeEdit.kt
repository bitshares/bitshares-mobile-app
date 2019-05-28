package com.btsplusplus.fowallet

import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_proposal_authorize_edit.*
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

class ActivityProposalAuthorizeEdit : BtsppActivity() {

    private lateinit var _proposal: JSONObject
    private lateinit var _data_array: JSONArray
    private var _isremove = false
    private lateinit var _result_promise: Promise

    private var _target_account: JSONObject? = null
    private var _fee_paying_account: JSONObject? = null
    private lateinit var _permissionAccountArray: JSONArray
    private var _title = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_proposal_authorize_edit)

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数 / get params
        val authorize_args = btspp_args_as_JSONObject()
        _proposal = authorize_args.getJSONObject("proposal")
        _data_array = authorize_args.getJSONArray("data_array")
        _isremove = authorize_args.getBoolean("isremove")
        _result_promise = authorize_args.get("result_promise") as Promise
        _title = authorize_args.optString("title")

        //  REMARK：如果只有1个权限实体，则默认选择，2个以上让用户选择。
        if (_data_array.length() == 1) {
            _target_account = _data_array.getJSONObject(0)
        }

        //  默认第一个 / default value
        _permissionAccountArray = WalletManager.sharedWalletManager().getFeePayingAccountList(true)
        if (_permissionAccountArray.length() > 0) {
            _fee_paying_account = _permissionAccountArray.getJSONObject(0)
        }

        //  事件 - 返回、授权账号、支付账号、提交
        layout_back_from_agree_proposal.setOnClickListener { onBackClicked(null) }
        cell_target_account.setOnClickListener { onTargetAccountCellClicked() }
        cell_fee_paying_account.setOnClickListener { onFeePayingAccountCellClicked() }
        btn_submmit_core.setOnClickListener { onSubmitClicked() }

        //  刷新UI
        refreshUI()
    }

    override fun onBackClicked(result: Any?) {
        _result_promise.resolve(result)
        finish()
    }

    /**
     * 事件 - 提交
     */
    private fun onSubmitClicked() {
        if (_target_account == null) {
            showToast(getSelectTargetAccountTipMessage())
            return
        }
        if (_fee_paying_account == null) {
            showToast(R.string.kProposalEditTipsSelectFeePayingAccount.xmlstring(this))
            return
        }
        if (!WalletManager.sharedWalletManager().canAuthorizeThePermission(_fee_paying_account!!.getJSONObject("active"))) {
            showToast(String.format(R.string.kProposalEditTipsNoFeePayingAccountActiveKey.xmlstring(this), _fee_paying_account!!.getString("name")))
            return
        }
        //  返回结果：提交
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                _result_promise.resolve(jsonObjectfromKVS("target_account", _target_account!!, "fee_paying_account", _fee_paying_account!!))
                finish()
            }
        }
    }

    /**
     * 事件 - 授权账号
     */
    private fun onTargetAccountCellClicked() {
        val list = JSONArray()
        _data_array.forEach<JSONObject> { list.put(it!!.getString("name")) }
        ViewSelector.show(this, getSelectTargetAccountTipMessage(), list.toList<String>().toTypedArray()) { index: Int, result: String ->
            _target_account = _data_array.getJSONObject(index)
            refreshAuthorizedProgressAndListUI()
            refreshTargetAccountUI()
        }
    }

    private fun getSelectTargetAccountTipMessage(): String {
        if (_isremove) {
            return R.string.kProposalEditSelectRemoveApproval.xmlstring(this)
        } else {
            return R.string.kProposalEditSelectAddApproval.xmlstring(this)
        }
    }

    /**
     * 事件 - 支付账号
     */
    private fun onFeePayingAccountCellClicked() {
        val list = JSONArray()
        _permissionAccountArray.forEach<JSONObject> { list.put(it!!.getString("name")) }
        ViewSelector.show(this, R.string.kProposalEditTipsSelectFeePayingAccount.xmlstring(this), list.toList<String>().toTypedArray()) { index: Int, result: String ->
            _fee_paying_account = _permissionAccountArray.getJSONObject(index)
            refreshFeePayingAccountUI()
        }
    }

    private fun refreshTargetAccountUI() {
        findViewById<TextView>(R.id.cell_target_account_title_name).text = if (_isremove) R.string.kProposalEditCellRemoveApprover.xmlstring(this) else R.string.kProposalEditCellAddApprover.xmlstring(this)
        if (_target_account != null) {
            findViewById<TextView>(R.id.label_target_account_name).let {
                it.text = _target_account!!.getString("name")
                if (_isremove) {
                    it.setTextColor(resources.getColor(R.color.theme01_sellColor))
                } else {
                    it.setTextColor(resources.getColor(R.color.theme01_buyColor))
                }
            }
        } else {
            findViewById<TextView>(R.id.label_target_account_name).let {
                it.text = getSelectTargetAccountTipMessage()
                it.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            }
        }
    }

    private fun refreshFeePayingAccountUI() {
        if (_fee_paying_account != null) {
            findViewById<TextView>(R.id.label_fee_paying_account_name).let {
                it.text = _fee_paying_account!!.getString("name")
                it.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            }
        } else {
            findViewById<TextView>(R.id.label_fee_paying_account_name).let {
                it.text = R.string.kProposalEditTipsSelectFeePayingAccount.xmlstring(this)
                it.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            }
        }
    }

    private fun refreshTitleUI() {
        if (_title != "") {
            findViewById<TextView>(R.id.title).text = _title
        }
    }

    private fun refreshAuthorizedProgressAndListUI() {
        val layout_parent = layout_list_of_agress_propsal
        layout_parent.removeAllViews()

        //  第三行 授权进度 xxx   状态 xxx
        val layout3_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        val layout3 = LinearLayout(this)
        layout3_params.setMargins(0, 0, 0, 10)
        layout3.layoutParams = layout3_params
        layout3.orientation = LinearLayout.HORIZONTAL

        val tv_line3_left_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        val tv_line3_left_auth_progress = TextView(this)
        tv_line3_left_auth_progress.layoutParams = tv_line3_left_params
        tv_line3_left_auth_progress.gravity = Gravity.LEFT
        tv_line3_left_auth_progress.text = R.string.kProposalCellProgress.xmlstring(this)
        tv_line3_left_auth_progress.gravity = Gravity.LEFT
        tv_line3_left_auth_progress.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
        tv_line3_left_auth_progress.setTextColor(resources.getColor(R.color.theme01_textColorMain))

        val proposalProcessedData = _proposal.getJSONObject("kProcessedData")
        var currThreshold = proposalProcessedData.getInt("currThreshold")
        val passThreshold = proposalProcessedData.getInt("passThreshold")
        var thresholdPercent = proposalProcessedData.getDouble("thresholdPercent")
        var detailColor = R.color.theme01_textColorMain

        //  动态添加or移除多情况下，更新阈值进度和百分比。
        if (_target_account != null) {
            val needAuthorizeHash = proposalProcessedData.getJSONObject("needAuthorizeHash")
            val item = needAuthorizeHash.getJSONObject(_target_account!!.getString("key"))
            val threshold = item.getInt("threshold")
            if (_isremove) {
                currThreshold -= threshold
                assert(currThreshold >= 0)
                detailColor = R.color.theme01_sellColor
            } else {
                currThreshold += threshold
                detailColor = R.color.theme01_buyColor
            }
            thresholdPercent = currThreshold.toDouble() * 100.0 / passThreshold.toDouble()
            if (currThreshold < passThreshold) {
                thresholdPercent = min(thresholdPercent, 99.0)
            }
            if (currThreshold > 0) {
                thresholdPercent = max(thresholdPercent, 1.0)
            }
        }

        val layout_line3_right_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_line3_right_params.gravity = Gravity.RIGHT
        val layout_line3_right = LinearLayout(this)
        layout_line3_right.layoutParams = layout_line3_right_params
        layout_line3_right.orientation = LinearLayout.HORIZONTAL
        layout_line3_right.gravity = Gravity.RIGHT

        val tv_line3_right_status = TextView(this)
        tv_line3_right_status.text = "${thresholdPercent.toInt()}% (${currThreshold}/${passThreshold})"
        tv_line3_right_status.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
        tv_line3_right_status.setTextColor(resources.getColor(detailColor))
        tv_line3_right_status.gravity = Gravity.RIGHT

        layout_line3_right.addView(tv_line3_right_status)
        layout3.addView(tv_line3_left_auth_progress)
        layout3.addView(layout_line3_right)

        //  第四行 各权限批准状态列表
        var dynamicInfos: JSONObject? = null
        if (_target_account != null) {
            dynamicInfos = jsonObjectfromKVS("remove", _isremove, "key", _target_account!!.getString("key"))
        }
        val layout4 = ViewPropsalList(this).init(_proposal, dynamicInfos)

        //  status
        layout_parent.addView(layout3)

        //  line
        var lv_line = View(this)
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
        layout_parent.addView(lv_line)

        //  authorized list
        layout_parent.addView(layout4)
    }

    /**
     * 刷新所有UI
     */
    private fun refreshUI() {
        refreshTitleUI()
        refreshAuthorizedProgressAndListUI()
        refreshTargetAccountUI()
        refreshFeePayingAccountUI()
    }
}
