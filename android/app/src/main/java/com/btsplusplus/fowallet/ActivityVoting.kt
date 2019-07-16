package com.btsplusplus.fowallet

import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.View
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_voting.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityVoting : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()

    private var _const_proxy_to_self: String = ""
    private var _bHaveProxy: Boolean = false
    private var _currVoteInfos: JSONObject? = null
    private var _btn_proxy: TextView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_voting)

        // 设置 fragment
        setFragments()
        setViewPager(0, R.id.view_pager_of_voting, R.id.tablayout_of_voting, fragmens)
        setTabListener(R.id.tablayout_of_voting, R.id.view_pager_of_voting)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  返回键
        layout_back_from_voting.setOnClickListener { finish() }

        //  部分数据初始化
        _const_proxy_to_self = ChainObjectManager.sharedChainObjectManager().getDefaultParameters().getString("voting_proxy_to_self")
        val full_account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val account_data = full_account_data.getJSONObject("account")
        val account_options = account_data.getJSONObject("options")
        _bHaveProxy = account_options.getString("voting_account") != _const_proxy_to_self
        _currVoteInfos = null

        //  是否显示当前代理
        current_proxy_of_voting.visibility = View.INVISIBLE
        current_proxy_name_of_voting.text = ""
        current_proxy_help_of_voting.setOnClickListener {
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_proxy"))
            goToWebView(resources.getString(R.string.kVcVoteWhatIsProxy), "https://btspp.io/qam.html#qa_proxy")
        }

        //  底部按钮
        val submit_btn = findViewById<TextView>(R.id.btn_submit_of_voting)
        submit_btn.isClickable = true

        _btn_proxy = findViewById(R.id.btn_set_delegate_of_voting)
        _btn_proxy!!.isClickable = true
        if (_bHaveProxy) {
            _btn_proxy!!.text = resources.getString(R.string.kVcVoteBtnCancelProxy)
        }

        //  事件
        btn_submit_of_voting.setOnClickListener { onSubmitVoteClicked() }
        btn_set_delegate_of_voting.setOnClickListener { onProxyClicked() }
        button_refresh_of_voting.setOnClickListener { onResetClicked() }

        //  查询：全局信息（活跃见证人等）、理事会信息、见证人信息、预算项目信息、预算对象信息、投票信息。
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val p0 = conn.async_exec_db("get_global_properties")
        val p1 = conn.async_exec_db("get_committee_count").then {
            val n = it as Int
            val ary = JSONArray()
            //  理事会ID：0...n
            for (i in 0 until n) {
                ary.put("1.${EBitsharesObjectType.ebot_committee_member.value}.${i}")
            }
            return@then conn.async_exec_db("get_committee_members", jsonArrayfrom(ary))
        }
        val p2 = conn.async_exec_db("get_witness_count").then {
            val n = it as Int
            val ary = JSONArray()
            //  见证人ID：1..n
            for (i in 1..n) {
                ary.put("1.${EBitsharesObjectType.ebot_witness.value}.${i}")
            }
            return@then conn.async_exec_db("get_witnesses", jsonArrayfrom(ary))
        }
        val p3 = conn.async_exec_db("get_all_workers")
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val p4 = chainMgr.queryLastBudgetObject()
        val p5 = chainMgr.queryAccountVotingInfos(WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").getString("id"))
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()
        Promise.all(p0, p1, p2, p3, p4, p5).then {
            var data_array = it as JSONArray
            chainMgr.updateObjectGlobalProperties(data_array.getJSONObject(0))
            val uid_hash = JSONObject()
            val ary_committee = data_array.getJSONArray(1)
            val ary_witness = data_array.getJSONArray(2)
            val ary_work = data_array.getJSONArray(3)
            //  预算项目
            val last_budget_object = data_array.get(4) as? JSONObject
            val voting_info = data_array.getJSONObject(5)
            //  当前角色 vote_info 查询完毕之后刷新按钮信息。
            _updateBottomButtonTitle(voting_info)
            ary_committee.forEach<JSONObject> { uid_hash.put(it!!.getString("committee_member_account"), true) }
            ary_witness.forEach<JSONObject> { uid_hash.put(it!!.getString("witness_account"), true) }
            ary_work.forEach<JSONObject> { uid_hash.put(it!!.getString("worker_account"), true) }
            return@then chainMgr.queryAllAccountsInfo(uid_hash.keys().toJSONArray()).then {
                //  刷新子界面
                var idx = 1
                fragmens.forEach {
                    val frag = it as FragmentVoting
                    frag.onQueryDataResponsed(data_array.getJSONArray(idx), last_budget_object, voting_info)
                    ++idx
                }
                mask.dismiss()
                return@then true
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     * 事件 - 重置按钮点击
     */
    private fun onResetClicked() {
        fragmens.forEach {
            val frag = it as FragmentVoting
            frag.resetUserModify()
        }
    }

    /**
     * 事件 - 投票界面底部按钮点击
     */
    private fun onSubmitVoteClicked() {
        if (_currVoteInfos == null) {
            showToast(resources.getString(R.string.tip_network_error))
            return
        }

        //  设置了代理人的情况，先弹框告知用户。
        if (_bHaveProxy) {
            alerShowMessageConfirm(null, resources.getString(R.string.kVcVoteTipAutoCancelProxy)).then {
                if (it != null && it as Boolean) {
                    _processActionVoting()
                }
                return@then null
            }
        } else {
            _processActionVoting()
        }
    }

    private fun onProxyClicked() {
        if (_currVoteInfos == null) {
            showToast(resources.getString(R.string.tip_network_error))
            return
        }
        if (_bHaveProxy) {
            _processActionRemoveProxy()
        } else {
            _processActionSettingProxy()
        }
    }

    /**
     * (private) 执行投票请求核心
     */
    private fun _processActionCore(fee_item: JSONObject, full_account_data: JSONObject, new_voting_account: String, new_votes: JSONArray?, title: String) {
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                _processActionUnlockCore(fee_item, full_account_data, new_voting_account, new_votes, title)
            }
        }
    }

    /**
     * (private) 排序投票信息（这个排序方式不能调整，和官方网页版一致。）
     */
    private fun _sort_votes(votes: JSONArray): JSONArray {
        //  投票格式 投票类型:投票ID
        //  这里根据投票ID升序排列
        return votes.toList<String>().sortedBy { it.split(':')[1].toInt() }.toJsonArray()
    }

    private fun _processActionUnlockCore(fee_item: JSONObject, full_account_data: JSONObject, new_voting_account: String, new_votes: JSONArray?, title: String) {
        var sorted_new_votes: JSONArray

        //  默认为空
        if (new_votes == null) {
            sorted_new_votes = JSONArray()
        } else {
            sorted_new_votes = _sort_votes(new_votes)
        }

        //  统计数量
        var num_witness: Int = 0
        var num_committee: Int = 0
        for (vote_id in sorted_new_votes.forin<String>()) {
            val vote_type = vote_id!!.split(':')[0].toInt()
            when (vote_type) {
                VotingTypes.committees.value -> ++num_committee
                VotingTypes.witnesses.value -> ++num_witness
            }
        }

        //  构造请求数据
        val fee_asset_id = fee_item.getString("fee_asset_id")
        val account_data = full_account_data.getJSONObject("account")
        val account_id = account_data.getString("id")
        val fee = jsonObjectfromKVS("amount", 0, "asset_id", fee_asset_id)
        val new_options = jsonObjectfromKVS("memo_key", account_data.getJSONObject("options").getString("memo_key"),
                "voting_account", new_voting_account, "num_witness", num_witness, "num_committee", num_committee, "votes", sorted_new_votes)
        val op_data = jsonObjectfromKVS("fee", fee, "account", account_id, "new_options", new_options)

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_account_update, false, false,
                op_data, account_data) { isProposal, _ ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().accountUpdate(op_data).then {
                //  投票成功、继续请求、刷新界面。
                ChainObjectManager.sharedChainObjectManager().queryAccountVotingInfos(account_id).then {
                    mask.dismiss()
                    _refreshUI(it as JSONObject)
                    showToast(String.format(resources.getString(R.string.kVcVoteTipTxFullOK), title))
                    //  [统计]
                    btsppLogCustom("txVotingFullOK", jsonObjectfromKVS("account", account_id))
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(String.format(resources.getString(R.string.kVcVoteTipTxOK), title))
                    //  [统计]
                    btsppLogCustom("txVotingOK", jsonObjectfromKVS("account", account_id))
                }
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txVotingFailed", jsonObjectfromKVS("account", account_id))
            }
        }
    }

    /**
     * (private) 交易行为：修改投票（如果有代理人则会自动删除。）
     */
    private fun _processActionVoting() {
        //  1、检查投票信息是否发生变化（有代理则不检测，有代理则取消代理，保持投票信息不变即可。）
        val new_votes = _getAllSelectedVotingInfos()
        if (!_bHaveProxy) {
            val old_votes = _currVoteInfos!!.getJSONObject("voting_hash").keys().toJSONArray()
            if (!_isVotingChanged(old_votes, new_votes)) {
                showToast(resources.getString(R.string.kVcVoteTipVoteNoChange))
                return
            }
        }

        //  2、检查手续费是否足够
        val full_account_data = _get_full_account_data()
        val fee_item = _get_fee_item(full_account_data)
        if (!fee_item.getBoolean("sufficient")) {
            showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }

        //  3、执行请求（代理设置为自己投票）
        _processActionCore(fee_item, full_account_data, _const_proxy_to_self, new_votes, resources.getString(R.string.kVcTitleVoting))
    }

    /**
     * (private) 交易行为：删除代理人
     */
    private fun _processActionRemoveProxy() {
        //  1、判断手续费是否足够
        val full_account_data = _get_full_account_data()
        val fee_item = _get_fee_item(full_account_data)
        if (!fee_item.getBoolean("sufficient")) {
            showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }

        //  2、执行请求（设置为自己投票）
        _processActionCore(fee_item, full_account_data, _const_proxy_to_self, null, resources.getString(R.string.kVcVotePrefixRemoveProxy))
    }

    /**
     * (private) 交易行为：设置代理人
     */
    private fun _processActionSettingProxy() {
        //  1、判断手续费是否足够
        val full_account_data = _get_full_account_data()
        val fee_item = _get_fee_item(full_account_data)
        if (!fee_item.getBoolean("sufficient")) {
            showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }

        //  2、选择委托投票人
        TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
            last_activity.goTo(ActivityVoting::class.java, true, back = true)
            //  设置代理人
            _processActionCore(fee_item, full_account_data, it.getString("id"), null, resources.getString(R.string.kVcVoteBtnSetupProxy))
        }
        goTo(ActivityAccountQueryBase::class.java, true)
    }

    /**
     * (private) 获取完整的帐号信息。
     */
    private fun _get_full_account_data(): JSONObject {
        val wallet_account_info = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
        val account_id = wallet_account_info.getJSONObject("account").getString("id")
        var full_account_data = ChainObjectManager.sharedChainObjectManager().getFullAccountDataFromCache(account_id)
        if (full_account_data == null) {
            full_account_data = wallet_account_info
        }
        return full_account_data
    }

    /**
     * 获取手续费对象。
     */
    private fun _get_fee_item(full_account_data: JSONObject): JSONObject {
        return ChainObjectManager.sharedChainObjectManager().getFeeItem(EBitsharesOperations.ebo_account_update, full_account_data)
    }

    /**
     * (private) 辅助 - 判断投票信息是否发生变化。
     */
    private fun _isVotingChanged(old_votes: JSONArray, new_votes: JSONArray): Boolean {
        if (old_votes.length() != new_votes.length()) {
            return true
        }

        //  排序投票信息
        val sorted_old_votes = old_votes.toList<String>().sortedBy({ it }).toJsonArray()
        val sorted_new_votes = new_votes.toList<String>().sortedBy({ it }).toJsonArray()

        //  逐个比较
        var idx: Int = 0
        for (vote_id_old in sorted_old_votes.forin<String>()) {
            val vote_id_new = sorted_new_votes.getString(idx)
            if (vote_id_old!! != vote_id_new) {
                return true
            }
            ++idx
        }

        //  没变化
        return false
    }

    /**
     * (private) 获取用户选择的投票项目
     */
    private fun _getAllSelectedVotingInfos(): JSONArray {
        val vote_ids = JSONArray()
        fragmens.forEach {
            val frag = it as FragmentVoting
            vote_ids.putAll(frag.getCurrSelectVotingInfos())
        }
        return vote_ids
    }

    private fun _updateBottomButtonTitle(vote_info: JSONObject) {
        _currVoteInfos = vote_info
        //  更新是否有代理人标记
        _bHaveProxy = vote_info.getBoolean("have_proxy")
        if (_bHaveProxy) {
            _btn_proxy!!.text = "取消代理"
            //  显示当前代理
            current_proxy_of_voting.visibility = View.VISIBLE
            val curr_proxy_name = vote_info.getJSONObject("voting_account").getString("name")
            current_proxy_name_of_voting.text = "${resources.getString(R.string.kVcVoteTipCurrentProxy)} ${curr_proxy_name}"
        } else {
            _btn_proxy!!.text = resources.getString(R.string.kVcVoteBtnSetupProxy)
            //  隐藏当前代理
            current_proxy_of_voting.visibility = View.GONE
        }
    }

    /**
     * (private) 投票成功之后刷新UI
     */
    private fun _refreshUI(voting_info: JSONObject) {
        _updateBottomButtonTitle(voting_info)
        fragmens.forEach {
            val frag = it as FragmentVoting
            frag.onQueryVotingInfoResponsed(voting_info)
        }
    }

    private fun setFragments() {
        fragmens.add(FragmentVoting().initialize(VotingTypes.committees))
        fragmens.add(FragmentVoting().initialize(VotingTypes.witnesses))
        fragmens.add(FragmentVoting().initialize(VotingTypes.workers))
    }


}
