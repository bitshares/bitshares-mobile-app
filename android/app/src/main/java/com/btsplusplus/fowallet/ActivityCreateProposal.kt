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
    private lateinit var _result_promise: Promise
    private lateinit var _permissionAccountArray: JSONArray
    private var _fee_paying_account: JSONObject? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_create_proposal)

        setFullScreen()

        //  获取参数 / get params
        val proposal_args = TempManager.sharedTempManager().get_args_as_JSONObject()
        _opcode = proposal_args.get("opcode") as EBitsharesOperations
        _opdata = proposal_args.getJSONObject("opdata")
        _result_promise = proposal_args.get("result_promise") as Promise

        //  默认第一个 / default value
        _permissionAccountArray = WalletManager.sharedWalletManager().getFeePayingAccountList(true)
        if (_permissionAccountArray.length() > 0) {
            _fee_paying_account = _permissionAccountArray.getJSONObject(0)
        }

        //  事件 - 返回按钮 / back button
        layout_cancel_from_transfer_proposal.setOnClickListener { onBackClicked(null) }

        //  事件 - 提交按钮 / submit button
        submit_btn_of_transfer_proposal.setOnClickListener { onSubmitClicked() }

        //  事件 -提案发起者 / proposal creator
        layout_proposal_initiator_account_of_transfer_proposal.setOnClickListener { onProposalCreatorCellClicked() }

        //  初始化UI / initialize
        refreshCreatorUI()

        //  查询依赖 / query
        onQueryMissedObjectIDs()
    }

    override fun onBackClicked(result: Any?) {
        _result_promise.resolve(result)
        finish()
    }

    private fun refreshCreatorUI() {
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
                onBackClicked(_fee_paying_account)
            }
        }
    }

    private fun onProposalCreatorCellClicked() {
        val list = JSONArray()
        _permissionAccountArray.forEach<JSONObject> { list.put(it!!.getString("name")) }
        ViewSelector.show(this, resources.getString(R.string.kProposalTipsSelectFeePayingAccount), list.toList<String>().toTypedArray()) { index: Int, result: String ->
            _fee_paying_account = _permissionAccountArray.getJSONObject(index)
            refreshCreatorUI()
        }
    }
}
