package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_create_proposal.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityCreateProposal : BtsppActivity() {

    private lateinit var _opcode: EBitsharesOperations
    private lateinit var _opdata: JSONObject
    private lateinit var _opaccount: JSONObject
    private lateinit var _result_promise: Promise
    private lateinit var _permissionAccountArray: JSONArray

    private lateinit var _proposal_create_args: JSONObject

    private var _bForceAddReviewTime: Boolean = false
    private var _fee_paying_account: JSONObject? = null
    private var _iProposalLifetime: Int = 0
    private var _iProposalReviewtime: Int = 0

    private val ARR_DEFAULT_APPROVE_PERIOD_DAYS = arrayOf(1,2,3,5,7,15)
    private val ARR_DEFAULT_REVIEW_PERIOD_DAYS = arrayOf(0,1,2,3,7)

    private var default_approve_period_select_index: Int = 0
    private var default_review_period_select_index: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_create_proposal)

        setFullScreen()

        //  获取参数 / get params
        val proposal_args = TempManager.sharedTempManager().get_args_as_JSONObject()
        _opcode = proposal_args.get("opcode") as EBitsharesOperations
        _opdata = proposal_args.getJSONObject("opdata")
        _opaccount = proposal_args.getJSONObject("opaccount")
        _result_promise = proposal_args.get("result_promise") as Promise

        //  默认第一个 / default value
        _permissionAccountArray = WalletManager.sharedWalletManager().getFeePayingAccountList(true)
        if (_permissionAccountArray.length() > 0) {
            _fee_paying_account = _permissionAccountArray.getJSONObject(0)
        }
        //  初始化默认值
        _proposal_create_args = JSONObject()
        if (_bForceAddReviewTime){
            _iProposalLifetime = 3600 * 24 * 3
            _iProposalReviewtime = 3600 * 24 * 2
            default_approve_period_select_index = 4
            default_review_period_select_index = 2
        }else{
            _iProposalLifetime = 3600 * 24 * 7
            _iProposalReviewtime = 3600 * 24 * 0
            default_approve_period_select_index = 2
            default_review_period_select_index = 0
        }
        _bForceAddReviewTime = _opaccount.getString("id").equals(BTS_GRAPHENE_COMMITTEE_ACCOUNT)

        //  事件 - 返回按钮 / back button
        layout_cancel_from_transfer_proposal.setOnClickListener {
            onBackClicked(null)
        }

        //  事件 - 提交按钮 / submit button
        submit_btn_of_transfer_proposal.setOnClickListener { onSubmitClicked() }

        //  事件 - 提案发起者 / proposal creator
        layout_proposal_initiator_account_of_transfer_proposal.setOnClickListener { onProposalCreatorCellClicked() }

        //  事件 - 操作周期 / approve period
        layout_proposal_approve_period_of_transfer_proposal.setOnClickListener { onProposalApprovePeriodCellClicked() }

        //  事件 - 审核周期 / review period
        layout_proposal_review_period_of_transfer_proposal.setOnClickListener { onProposalReviewPeriodCellClicked() }

        //  初始化UI / initialize
        refreshDefaultUI()

        //  查询依赖 / query
        onQueryMissedObjectIDs()
    }

    override fun onBackClicked(result: Any?) {
        _result_promise.resolve(result)
        finish()
    }

    private fun refreshDefaultUI(){
        refreshPayingAccountUI()
        if (_bForceAddReviewTime) {
            label_approve_period_value.text = String.format(R.string.kProposalLabelNDays.xmlstring(this), 3)
            label_review_period_value.text = String.format(R.string.kProposalLabelNDays.xmlstring(this), 2)
        } else {
            label_approve_period_value.text = String.format(R.string.kProposalLabelNDays.xmlstring(this), 7)
            label_review_period_value.text = R.string.kProposalLabelNoReviewPeriod.xmlstring(this)
        }
    }

    private fun refreshPayingAccountUI() {
        if (_fee_paying_account != null) {
            findViewById<TextView>(R.id.label_creator_name).text = _fee_paying_account!!.getString("name")
        } else {
            findViewById<TextView>(R.id.label_creator_name).text = R.string.kProposalTipsSelectFeePayingAccount.xmlstring(this)
        }
    }

    private fun onQueryGrapheneObjectResponsed() {
        val layout_body = layout_body_of_transfer_proposal
        layout_body.removeAllViews()
        //  刷新显示
        val uidata = OrgUtils.processOpdata2UiData(_opcode.value, _opdata, false, this)
        layout_body.addView(ViewUtils.createProposalOpInfoCell(this, uidata, useBuyColorForTitle = false, nameFontSize = 14.0f))
        //  line
        val lv_line = View(this)
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        val line_layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
        line_layoutParams.topMargin = 10.dp
        lv_line.layoutParams = line_layoutParams
        layout_body.addView(lv_line)
    }

    private fun onQueryMissedObjectIDs() {
        val container = JSONObject()
        OrgUtils.extractObjectID(_opcode.value, _opdata, container)
        val ids = container.keys().toJSONArray()

        //  查询
        val mask = ViewMesk(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        ChainObjectManager.sharedChainObjectManager().queryAllGrapheneObjects(ids).then {
            mask.dismiss()
            onQueryGrapheneObjectResponsed()
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun onSubmitClicked() {
        if (_fee_paying_account == null) {
            showToast(R.string.kProposalSubmitTipsSelectCreator.xmlstring(this))
            return
        }
        if (!WalletManager.sharedWalletManager().canAuthorizeThePermission(_fee_paying_account!!.getJSONObject("active"))) {
            showToast(String.format(R.string.kProposalEditTipsNoFeePayingAccountActiveKey.xmlstring(this), _fee_paying_account!!.getString("name")))
            return
        }
        //  返回结果：提交
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                _proposal_create_args.put("kFeePayingAccount", _fee_paying_account)
                _proposal_create_args.put("kApprovePeriod", _iProposalLifetime)
                _proposal_create_args.put("kReviewPeriod", _iProposalReviewtime)
                onBackClicked(_proposal_create_args)
            }
        }
    }

    private fun onProposalApprovePeriodCellClicked(){
        val arr_days = ARR_DEFAULT_APPROVE_PERIOD_DAYS.map {
            String.format(R.string.kProposalLabelNDays.xmlstring(this),it)
        }
        ViewDialogNumberPicker(this, null, arr_days.toList<String>().toTypedArray(), default_approve_period_select_index){ _index: Int, txt: String ->
            _iProposalLifetime = 3600 * 24 * _index
            _proposal_create_args.put("kApprovePeriod", _iProposalLifetime)
            default_approve_period_select_index = _index
            label_approve_period_value.text = txt
        }.show()
    }

    private fun onProposalReviewPeriodCellClicked(){
        val arr_days = ARR_DEFAULT_REVIEW_PERIOD_DAYS.map {
            if (it == 0) {
                String.format(R.string.kProposalLabelNoReviewPeriod.xmlstring(this))
            } else {
                String.format(R.string.kProposalLabelNDays.xmlstring(this),it)
            }
        }
        ViewDialogNumberPicker(this, null, arr_days.toList<String>().toTypedArray(), default_review_period_select_index){ _index: Int, txt: String ->
            _iProposalReviewtime = 3600 * 24 * _index
            _proposal_create_args.put("kReviewPeriod", _iProposalReviewtime)
            default_review_period_select_index = _index
            label_review_period_value.text = txt
        }.show()
    }

    private fun onProposalCreatorCellClicked() {
        val list = JSONArray()
        _permissionAccountArray.forEach<JSONObject> { list.put(it!!.getString("name")) }
        ViewSelector.show(this, resources.getString(R.string.kProposalTipsSelectFeePayingAccount), list.toList<String>().toTypedArray()) { index: Int, result: String ->
            _fee_paying_account = _permissionAccountArray.getJSONObject(index)
            refreshPayingAccountUI()
        }
    }
}
