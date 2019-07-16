package com.btsplusplus.fowallet

import android.content.Context
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_process_proposal.*
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

class ActivityProposal : BtsppActivity() {

    private var _data_array = mutableListOf<JSONObject>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_process_proposal)

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  返回按钮
        layout_back_from_process_proposal.setOnClickListener { finish() }

        //  查询提案
        queryAllProposals()
    }

    private fun queryAllProposals() {
        val account_name_list = WalletManager.sharedWalletManager().getWalletAccountNameList()
        assert(account_name_list.length() > 0)

        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        val promiseList = JSONArray()
        account_name_list.forEach<String> {
            promiseList.put(conn.async_exec_db("get_proposed_transactions", jsonArrayfrom(it!!)))
        }
        Promise.all(promiseList).then { list ->
            val array_list = list as JSONArray

            val proposal_list = JSONArray()
            val proposal_marked = JSONObject()
            //  查询依赖
            val query_ids = JSONObject()
            val skip_cache_ids = JSONObject()
            //  遍历所有提案
            array_list.forEach<Any> {
                val proposals = it as? JSONArray
                if (proposals != null && proposals.length() > 0) {
                    for (item in proposals.forin<JSONObject>()) {
                        val proposal = item!!
                        val proposal_id = proposal.getString("id")
                        //  REMARK：已经添加到列表了则略过。部分提案可能在多个账号中存在。所以存在重复的情况。
                        if (proposal_marked.has(proposal_id)) {
                            continue
                        }

                        //  TODO:fowallet REMARK:需要多种权限的提案暂时不支持。
                        if (proposal.getJSONArray("required_active_approvals").length() + proposal.getJSONArray("required_owner_approvals").length() != 1) {
                            continue
                        }

                        query_ids.put(proposal.getString("proposer"), true)
                        proposal.getJSONArray("available_active_approvals").forEach<String> { uid ->
                            query_ids.put(uid, true)
                            skip_cache_ids.put(uid, true)
                        }
                        proposal.getJSONArray("available_owner_approvals").forEach<String> { uid ->
                            query_ids.put(uid, true)
                            skip_cache_ids.put(uid, true)
                        }
                        proposal.getJSONArray("required_active_approvals").forEach<String> { uid ->
                            query_ids.put(uid, true)
                            skip_cache_ids.put(uid, true)
                        }
                        proposal.getJSONArray("required_owner_approvals").forEach<String> { uid ->
                            query_ids.put(uid, true)
                            skip_cache_ids.put(uid, true)
                        }

                        val operations = proposal.getJSONObject("proposed_transaction").getJSONArray("operations")
                        operations.forEach<JSONArray> { ary ->
                            assert(ary!!.length() == 2)
                            val opcode = ary.getInt(0)
                            val opdata = ary.getJSONObject(1)
                            OrgUtils.extractObjectID(opcode, opdata, query_ids)
                        }
                        //  添加到列表
                        proposal_list.put(proposal)
                        //  标记已存在
                        proposal_marked.put(proposal_id, true)
                    }
                }
            }
            return@then chainMgr.queryAllGrapheneObjects(query_ids.keys().toJSONArray(), skip_cache_ids).then {
                //  二次查询依赖
                //  1、查询提案账号权限中的多签成员/代理人等名字信息等。
                val query_account_ids = JSONObject()
                proposal_list.forEach<JSONObject> { proposal ->
                    proposal!!.getJSONArray("required_active_approvals").forEach<String> { uid ->
                        val account = chainMgr.getChainObjectByID(uid!!)
                        val account_auths = account.getJSONObject("active").getJSONArray("account_auths")
                        account_auths.forEach<JSONArray> { item ->
                            assert(item!!.length() == 2)
                            query_account_ids.put(item.getString(0), true)
                        }
                        val voting_account = account.getJSONObject("options").getString("voting_account")
                        if (voting_account != BTS_GRAPHENE_PROXY_TO_SELF) {
                            query_account_ids.put(voting_account, true)
                        }
                    }
                    proposal.getJSONArray("required_owner_approvals").forEach<String> { uid ->
                        val account = chainMgr.getChainObjectByID(uid!!)
                        val account_auths = account.getJSONObject("owner").getJSONArray("account_auths")
                        account_auths.forEach<JSONArray> { item ->
                            assert(item!!.length() == 2)
                            query_account_ids.put(item.getString(0), true)
                        }
                        val voting_account = account.getJSONObject("options").getString("voting_account")
                        if (voting_account != BTS_GRAPHENE_PROXY_TO_SELF) {
                            query_account_ids.put(voting_account, true)
                        }
                    }
                }

                //  2、更新账号信息时候查询投票信息
                //  新vote_id
                val new_vote_id_hash = JSONObject()
                proposal_list.forEach<JSONObject> { proposal ->
                    val operations = proposal!!.getJSONObject("proposed_transaction").getJSONArray("operations")
                    operations.forEach<JSONArray> { it ->
                        val ary = it!!
                        assert(ary.length() == 2)
                        val opcode = ary.getInt(0)
                        if (opcode == EBitsharesOperations.ebo_account_update.value) {
                            val opdata = ary.getJSONObject(1)
                            val new_options = opdata.optJSONObject("new_options")
                            if (new_options != null) {
                                val votes = new_options.optJSONArray("votes")
                                if (votes != null && votes.length() > 0) {
                                    votes.forEach<String> { vote_id ->
                                        new_vote_id_hash.put(vote_id, true)
                                    }
                                }
                                val voting_account = new_options.getString("voting_account")
                                if (voting_account != BTS_GRAPHENE_PROXY_TO_SELF) {
                                    query_account_ids.put(voting_account, true)
                                }
                            }
                        }
                    }
                }
                //  老vote_id
                skip_cache_ids.keys().toJSONArray().forEach<String> { it ->
                    val account_id = it!!
                    val account = chainMgr.getChainObjectByID(account_id)
                    val options = account.optJSONObject("options")
                    val votes = options?.optJSONArray("votes")
                    if (votes != null && votes.length() > 0) {
                        votes.forEach<String> { vote_id ->
                            new_vote_id_hash.put(vote_id, true)
                        }
                    }
                }

                val vote_id_list = new_vote_id_hash.keys().toJSONArray()

                val p1 = chainMgr.queryAllGrapheneObjects(query_account_ids.keys().toJSONArray())
                val p2 = chainMgr.queryAllVoteIds(vote_id_list)

                return@then Promise.all(p1, p2).then { data ->
                    //  第三次查询依赖（投票信息中的见证人理事会成员名字等）
                    val query_ids_3rd = JSONObject()
                    vote_id_list.forEach<String> { it ->
                        val vote_id = it!!
                        val vote_info = chainMgr.getVoteInfoByVoteID(vote_id)
                        val committee_member_account = vote_info!!.optString("committee_member_account", null)
                        if (committee_member_account != null) {
                            query_ids_3rd.put(committee_member_account, true)
                        } else {
                            val witness_account = vote_info.optString("witness_account", null)
                            if (witness_account != null) {
                                query_ids_3rd.put(witness_account, true)
                            }
                        }
                    }
                    return@then chainMgr.queryAllGrapheneObjects(query_ids_3rd.keys().toJSONArray()).then { data ->
                        mask.dismiss()
                        onQueryAllProposalsResponse(proposal_list)
                        return@then null
                    }
                }
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    private fun onQueryAllProposalsResponse(data_array: JSONArray) {
        _data_array.clear()

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        data_array.forEach<JSONObject> {
            val proposal = it!!
            //  TODO:fowallet 需要多种权限的提案暂不支持
            assert(proposal.getJSONArray("required_active_approvals").length() + proposal.getJSONArray("required_owner_approvals").length() == 1)
            //  获取提案执行需要批准的权限数据
            var require_account: JSONObject? = null
            var permissions: JSONObject? = null
            var is_active = true
            if (require_account == null) {
                proposal.getJSONArray("required_active_approvals").forEach<String> { uid ->
                    require_account = chainMgr.getChainObjectByID(uid!!)
                    permissions = require_account!!.getJSONObject("active")
                    is_active = true
                }
            }
            if (require_account == null) {
                proposal.getJSONArray("required_owner_approvals").forEach<String> { uid ->
                    require_account = chainMgr.getChainObjectByID(uid!!)
                    permissions = require_account!!.getJSONObject("owner")
                    is_active = false
                }
            }
            assert(require_account != null && permissions != null)

            //  获取多签中每个权限实体详细数据（包括权重等）
            val needAuthorizeHash = JSONObject()
            permissions!!.getJSONArray("account_auths").forEach<JSONArray> { item ->
                assert(item!!.length() == 2)
                val account_id = item.getString(0)
                val account = chainMgr.getChainObjectByID(account_id)
                val obj = jsonObjectfromKVS("name", account.getString("name"),
                        "key", account_id, "threshold", item.getInt(1), "isaccount", true, "isactive", is_active)
                needAuthorizeHash.put(account_id, obj)
            }
            permissions!!.getJSONArray("address_auths").forEach<JSONArray> { item ->
                assert(item!!.length() == 2)
                val key = item.getString(0)
                val obj = jsonObjectfromKVS("name", key,
                        "key", key, "threshold", item.getInt(1), "isaddr", true, "isactive", is_active)
                needAuthorizeHash.put(key, obj)
            }
            permissions!!.getJSONArray("key_auths").forEach<JSONArray> { item ->
                assert(item!!.length() == 2)
                val key = item.getString(0)
                val obj = jsonObjectfromKVS("name", key,
                        "key", key, "threshold", item.getInt(1), "iskey", true, "isactive", is_active)
                needAuthorizeHash.put(key, obj)
            }

            //  获取当前授权状态（有哪些实体已授权、哪些未授权）
            var currThreshold = 0
            val passThreshold = permissions!!.getInt("weight_threshold")
            assert(passThreshold > 0)
            val availableHash = JSONObject()
            proposal.getJSONArray("available_active_approvals").forEach<String> { key ->
                availableHash.put(key, jsonObjectfromKVS("isaccount", true))
                val item = needAuthorizeHash.optJSONObject(key)
                if (item != null) {
                    currThreshold += item.getInt("threshold")
                }
            }
            proposal.getJSONArray("available_key_approvals").forEach<String> { key ->
                availableHash.put(key, jsonObjectfromKVS("iskey", true))
                val item = needAuthorizeHash.optJSONObject(key)
                if (item != null) {
                    currThreshold += item.getInt("threshold")
                }
            }
            proposal.getJSONArray("available_owner_approvals").forEach<String> { key ->
                availableHash.put(key, jsonObjectfromKVS("isaccount", true))
                val item = needAuthorizeHash.optJSONObject(key)
                if (item != null) {
                    currThreshold += item.getInt("threshold")
                }
            }
            var thresholdPercent = currThreshold.toDouble() * 100.0 / passThreshold.toDouble()
            if (currThreshold < passThreshold) {
                thresholdPercent = min(thresholdPercent, 99.0)
            }
            if (currThreshold > 0) {
                thresholdPercent = max(thresholdPercent, 1.0)
            }

            //  预处理是否进入审核期。
            var inReview = false
            val review_period_time = proposal.optString("review_period_time", "")
            if (review_period_time != "") {
                val review_period_time_ts = Utils.parseBitsharesTimeString(review_period_time)
                val now_sec = Utils.now_ts()
                if (now_sec >= review_period_time_ts) {
                    inReview = true
                }
            }

            //  预处理OP描述信息
            val new_operations = JSONArray()
            val operations = proposal.getJSONObject("proposed_transaction").getJSONArray("operations")
            operations.forEach<JSONArray> { ary ->
                assert(ary!!.length() == 2)
                val opcode = ary.getInt(0)
                val opdata = ary.getJSONObject(1)
                val new_op = jsonObjectfromKVS("opcode", opcode, "opdata", opdata, "uidata", OrgUtils.processOpdata2UiData(opcode, opdata, null, true, this))
                new_operations.put(new_op)
            }

            //  添加到列表
            val processed_infos = jsonObjectfromKVS("inReview", inReview,
                    "passThreshold", passThreshold,
                    "currThreshold", currThreshold,
                    "thresholdPercent", thresholdPercent,
                    "needAuthorizeHash", needAuthorizeHash,
                    "availableHash", availableHash,
                    "newOperations", new_operations)
            proposal.put("kProcessedData", processed_infos)
            _data_array.add(proposal)
        }

        //  根据ID降序排列
        _data_array.sortByDescending { it.getString("id").split(".").last().toInt() }

        //  刷新UI
        refreshUI()
    }

    private fun refreshUI() {
        //  清除UI
        val layout_parent = layout_list_of_process_propsal
        layout_parent.removeAllViews()

        if (_data_array.size > 0) {
            //  循环描绘所有提案
            var index = 0
            _data_array.forEach {
                drawOneProposalUI(this, layout_parent, it, index)
                index++
            }
        } else {
            layout_parent.addView(ViewUtils.createEmptyCenterLabel(this, R.string.kProposalTipsNoAnyProposals.xmlstring(this)))
        }
    }

    private fun drawOneProposalUI(ctx: Context, layout_parent: LinearLayout, proposal: JSONObject, index: Int) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val proposalProcessedData = proposal.getJSONObject("kProcessedData")

        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        val layout_proposal_cell = LinearLayout(this)
        layout_proposal_cell.orientation = LinearLayout.VERTICAL
        layout_proposal_cell.layoutParams = layout_params

        if (index > 0) {
            layout_params.setMargins(0, 10, 0, 10)
        }

        // 第一行 ID & 日期
        val layout1_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        val layout1_title = LinearLayout(this)
        layout1_title.layoutParams = layout1_params
        layout1_title.orientation = LinearLayout.HORIZONTAL

        val tv_line1_left_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, 28.dp)
        val tv_line1_left = TextView(this)
        tv_line1_left.layoutParams = tv_line1_left_params
        tv_line1_left.gravity = Gravity.LEFT
        val id = proposal.getString("id")
        tv_line1_left.text = "${index + 1}. #${id}"
        tv_line1_left.gravity = Gravity.LEFT
        tv_line1_left.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv_line1_left.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv_line1_left.paint.isFakeBoldText = true

        //  除了ID标题字段以外其他字段的字号
        val form_font_size = 11.0f
        val form_line_height = 25.dp

        val tv_line1_right_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 28.dp)
        val tv_line1_right = TextView(this)
        tv_line1_right_params.gravity = Gravity.RIGHT
        tv_line1_right.layoutParams = tv_line1_right_params

        tv_line1_right.text = String.format(R.string.kVcOrderExpired.xmlstring(ctx), Utils.fmtLimitOrderTimeShowString(proposal.getString("expiration_time")))
        tv_line1_right.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line1_right.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv_line1_right.gravity = Gravity.RIGHT

        layout1_title.addView(tv_line1_left)
        layout1_title.addView(tv_line1_right)

        // 第二行 目标账号 xxx   发起账号 xxx
        val layout2_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        val layout2_accounts = LinearLayout(this)
        layout2_accounts.layoutParams = layout2_params
        layout2_accounts.orientation = LinearLayout.HORIZONTAL

        val tv_line2_left_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, form_line_height)
        val tv_line2_left_recv_account = TextView(this)
        tv_line2_left_recv_account.layoutParams = tv_line2_left_params
        tv_line2_left_recv_account.gravity = Gravity.LEFT
        tv_line2_left_recv_account.text = R.string.kProposalCellApprover.xmlstring(this)
        tv_line2_left_recv_account.gravity = Gravity.LEFT
        tv_line2_left_recv_account.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line2_left_recv_account.paint.isFakeBoldText = true
        tv_line2_left_recv_account.setTextColor(resources.getColor(R.color.theme01_textColorNormal))

        val tv_line2_left_recv_account_value = TextView(this)
        tv_line2_left_recv_account_value.layoutParams = tv_line2_left_params
        tv_line2_left_recv_account_value.gravity = Gravity.LEFT
        //  计算发起账号字符串。可能存在多个账号。
        val require_ids = JSONObject()
        val require_names = mutableListOf<String>()
        proposal.getJSONArray("required_active_approvals").forEach<String> { uid -> require_ids.put(uid, true) }
        proposal.getJSONArray("required_owner_approvals").forEach<String> { uid -> require_ids.put(uid, true) }
        require_ids.keys().forEach { uid -> require_names.add(chainMgr.getChainObjectByID(uid).getString("name")) }
        tv_line2_left_recv_account_value.text = require_names.joinToString(" ")
        tv_line2_left_recv_account_value.gravity = Gravity.LEFT
        tv_line2_left_recv_account_value.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line2_left_recv_account_value.paint.isFakeBoldText = true
        tv_line2_left_recv_account_value.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv_line2_left_recv_account_value.setPadding(3.dp, 0, 0, 0)


        val layout_line2_right_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, form_line_height)
        layout_line2_right_params.gravity = Gravity.RIGHT
        val layout_line2_right = LinearLayout(this)
        layout_line2_right.layoutParams = layout_line2_right_params
        layout_line2_right.orientation = LinearLayout.HORIZONTAL
        layout_line2_right.gravity = Gravity.RIGHT


        val tv_line2_right_send_account = TextView(this)
        // tv_line2_right_send_account.layoutParams = tv_line2_right_params

        tv_line2_right_send_account.text = R.string.kProposalCellCreator.xmlstring(this)
        tv_line2_right_send_account.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line2_right_send_account.paint.isFakeBoldText = true
        tv_line2_right_send_account.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv_line2_right_send_account.gravity = Gravity.RIGHT


        val tv_line2_right_send_account_value = TextView(this)
        // tv_line2_right_send_account_value.layoutParams = tv_line2_right_params

        tv_line2_right_send_account_value.text = chainMgr.getChainObjectByID(proposal.getString("proposer")).getString("name")
        tv_line2_right_send_account_value.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line2_right_send_account_value.paint.isFakeBoldText = true
        tv_line2_right_send_account_value.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv_line2_right_send_account_value.gravity = Gravity.RIGHT
        tv_line2_right_send_account_value.setPadding(3.dp, 0, 0, 0)

        layout_line2_right.addView(tv_line2_right_send_account)
        layout_line2_right.addView(tv_line2_right_send_account_value)

        layout2_accounts.addView(tv_line2_left_recv_account)
        layout2_accounts.addView(tv_line2_left_recv_account_value)
        layout2_accounts.addView(layout_line2_right)


        // 第三行 授权进度 xxx   状态 xxx
        val layout3_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, form_line_height)
        val layout3_status = LinearLayout(this)
        layout3_status.layoutParams = layout3_params
        layout3_status.orientation = LinearLayout.HORIZONTAL

        val tv_line3_left_auth_progress = TextView(this)
        tv_line3_left_auth_progress.layoutParams = tv_line2_left_params
        tv_line3_left_auth_progress.gravity = Gravity.LEFT
        tv_line3_left_auth_progress.text = R.string.kProposalCellProgress.xmlstring(this)
        tv_line3_left_auth_progress.gravity = Gravity.LEFT
        tv_line3_left_auth_progress.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line3_left_auth_progress.paint.isFakeBoldText = true
        tv_line3_left_auth_progress.setTextColor(resources.getColor(R.color.theme01_textColorNormal))

        val tv_line3_left_auth_progress_value = TextView(this)
        val currThreshold = proposalProcessedData.getInt("currThreshold")
        val passThreshold = proposalProcessedData.getInt("passThreshold")
        val percent = proposalProcessedData.getDouble("thresholdPercent").toInt()
        tv_line3_left_auth_progress_value.layoutParams = tv_line2_left_params
        tv_line3_left_auth_progress_value.gravity = Gravity.LEFT
        tv_line3_left_auth_progress_value.text = "${percent}% (${currThreshold}/${passThreshold})"
        tv_line3_left_auth_progress_value.gravity = Gravity.LEFT
        tv_line3_left_auth_progress_value.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line3_left_auth_progress_value.paint.isFakeBoldText = true
        tv_line3_left_auth_progress_value.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv_line3_left_auth_progress_value.setPadding(3.dp, 0, 0, 0)

        val layout_line3_right_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, form_line_height)
        layout_line3_right_params.gravity = Gravity.RIGHT
        val layout_line3_right = LinearLayout(this)
        layout_line3_right.layoutParams = layout_line3_right_params
        layout_line3_right.orientation = LinearLayout.HORIZONTAL
        layout_line3_right.gravity = Gravity.RIGHT

        //  计算提案状态信息
        //  （白色）进行中：没有或者未进入审核期授权未通过
        //  （红色）未通过：进入审核期并且授权未通过
        //  （红色）失败：无审核期并且授权已通过，则执行失败。
        //  （绿色）待审核：有审核期但尚未开始审核并且授权已通过
        //  （绿色）审核中：进入审核期并且授权已通过
        val bApprovalPassed = currThreshold >= passThreshold
        val bInReview = proposalProcessedData.getBoolean("inReview")

        val status: String
        val statusColor: Int
        if (bApprovalPassed) {
            if (proposal.has("review_period_time")) {
                if (bInReview) {
                    //  审核中：进入审核期并且授权已通过
                    status = R.string.kProposalCellStatusReview.xmlstring(this)
                    statusColor = resources.getColor(R.color.theme01_buyColor)
                } else {
                    //  待审核：有审核期但尚未开始审核并且授权已通过
                    status = R.string.kProposalCellStatusWaitReview.xmlstring(this)
                    statusColor = resources.getColor(R.color.theme01_buyColor)
                }
            } else {
                //  失败：无审核期并且授权已通过，则执行失败。
                status = R.string.kProposalCellStatusFailed.xmlstring(this)
                statusColor = resources.getColor(R.color.theme01_sellColor)
            }
        } else {
            if (proposal.has("review_period_time") && bInReview) {
                //  未通过：进入审核期并且授权未通过
                status = R.string.kProposalCellStatusNotPassed.xmlstring(this)
                statusColor = resources.getColor(R.color.theme01_sellColor)
            } else {
                //  进行中：没有或者未进入审核期并且授权未通过
                status = R.string.kProposalCellStatusPending.xmlstring(this)
                statusColor = resources.getColor(R.color.theme01_textColorMain)
            }
        }

        val tv_line3_right_status = TextView(this)
        tv_line3_right_status.text = R.string.kProposalCellStatusTitle.xmlstring(this)
        tv_line3_right_status.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line3_right_status.paint.isFakeBoldText = true
        tv_line3_right_status.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv_line3_right_status.gravity = Gravity.RIGHT

        val tv_line3_right_status_value = TextView(this)
        tv_line3_right_status_value.text = status
        tv_line3_right_status_value.setTextSize(TypedValue.COMPLEX_UNIT_DIP, form_font_size)
        tv_line3_right_status_value.paint.isFakeBoldText = true
        tv_line3_right_status_value.setTextColor(statusColor)
        tv_line3_right_status_value.gravity = Gravity.RIGHT
        tv_line3_right_status_value.setPadding(3.dp, 0, 0, 0)

        layout_line3_right.addView(tv_line3_right_status)
        layout_line3_right.addView(tv_line3_right_status_value)

        layout3_status.addView(tv_line3_left_auth_progress)
        layout3_status.addView(tv_line3_left_auth_progress_value)
        layout3_status.addView(layout_line3_right)

        //  第四行 账号列表
        val layout4_authorized_list = ViewPropsalList(this).init(proposal)

        //  第五行 提案内容列表
        val layout5_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        val layout5_opinfos = LinearLayout(this)
        layout5_params.setMargins(0, 10, 0, 12)
        layout5_opinfos.layoutParams = layout5_params
        layout5_opinfos.orientation = LinearLayout.VERTICAL

        val newOperations = proposalProcessedData.getJSONArray("newOperations")
        newOperations.forEach<JSONObject> {
            val operation = it!!
            val bNormalDesc: Boolean
            when (operation.getInt("opcode")) {
                EBitsharesOperations.ebo_account_update.value -> {
                    val view = ViewProposalAccountUpdate(this, operation, true)
                    bNormalDesc = view._useNormalDescLabel
                    layout5_opinfos.addView(view)
                }
                else -> {
                    bNormalDesc = true
                    layout5_opinfos.addView(ViewUtils.createProposalOpInfoCell(this, operation.getJSONObject("uidata"), useBuyColorForTitle = true))
                }
            }
            if (bNormalDesc) {
                val lv_line = View(this)
                lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
                lv_line.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp).apply {
                    topMargin = 6.dp
                }
                layout5_opinfos.addView(lv_line)
            }

        }

        // 第六话  批准   否决
        val layout6_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 28.dp)
        val layout6_actions = LinearLayout(this)
        layout6_actions.layoutParams = layout6_params
        layout6_actions.orientation = LinearLayout.HORIZONTAL
        layout6_params.setMargins(0, 10, 0, 10)

        val tv6_left_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
        val tv6_left = TextView(this)
        tv6_left.layoutParams = tv6_left_params
        tv6_left.text = R.string.kProposalCellBtnApprove.xmlstring(this)
        tv6_left.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
        tv6_left.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
        tv6_left.setTextColor(resources.getColor(R.color.theme01_textColorHighlight))

        val tv6_right = TextView(this)
        tv6_right.layoutParams = tv6_left_params
        tv6_right.text = R.string.kProposalCellBtnNotApprove.xmlstring(this)
        tv6_right.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
        tv6_right.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
        tv6_right.setTextColor(resources.getColor(R.color.theme01_textColorHighlight))

        // 批准事件
        tv6_left.setOnClickListener { onApproveClicked(proposal) }

        // 否决事件
        tv6_right.setOnClickListener { onRejectClicked(proposal) }

        layout6_actions.addView(tv6_left)
        layout6_actions.addView(tv6_right)

        layout_proposal_cell.addView(layout1_title)
        layout_proposal_cell.addView(layout2_accounts)

        //  授权进度 & 状态
        layout_proposal_cell.addView(layout3_status)
        var lv_line = View(this)
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
        layout_proposal_cell.addView(lv_line)

        //  权限列表
        layout_proposal_cell.addView(layout4_authorized_list)
        lv_line = View(this)
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
        layout_proposal_cell.addView(lv_line)

        //  OP信息
        layout_proposal_cell.addView(layout5_opinfos)

        layout_proposal_cell.addView(layout6_actions)

        layout_parent.addView(layout_proposal_cell)

        // 线
        lv_line = View(this)
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
        layout_parent.addView(lv_line)
    }

    /**
     * 事件 - 批准按钮点击
     */
    private fun onApproveClicked(proposal: JSONObject) {
        //  REMARK：查询提案发起者是否处于黑名单中，黑名单中不可批准。
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()

        chainMgr.queryAllGrapheneObjectsSkipCache(jsonArrayfrom(BTS_GRAPHENE_ACCOUNT_BTSPP_TEAM)).then {
            mask.dismiss()
            val account = chainMgr.getChainObjectByID(BTS_GRAPHENE_ACCOUNT_BTSPP_TEAM)
            val blacklisted_accounts = account.optJSONArray("blacklisted_accounts")
            val proposer_uid = proposal.getString("proposer")
            val proposer_account = chainMgr.getChainObjectByID(proposer_uid)
            val proposer_registrar = proposer_account.getString("registrar")

            var in_blacklist = false
            if (blacklisted_accounts != null && blacklisted_accounts.length() > 0) {
                for (uid in blacklisted_accounts.forin<String>()) {
                    //  发起账号 or 发起账号的注册者 在黑名单种，均存在风险。
                    if (uid!! == proposer_uid || uid == proposer_registrar) {
                        in_blacklist = true
                        break
                    }
                }
            }

            if (in_blacklist) {
                UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), String.format(R.string.kProposalSubmitTipsBlockedApprovedForBlackList.xmlstring(this), proposer_account.getString("name")), btn_cancel = null).then {
                    return@then null
                }
            } else {
                _gotoApproveCore(proposal)
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(R.string.tip_network_error.xmlstring(this))
        }
    }

    private fun _gotoApproveCore(proposal: JSONObject) {
        //  审核中：仅可移除授权，不可添加授权。
        val kProcessedData = proposal.getJSONObject("kProcessedData")
        if (kProcessedData.getBoolean("inReview")) {
            showToast(R.string.kProposalSubmitTipsInReview.xmlstring(this))
            return
        }
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                gotoVcApproveCore(proposal, kProcessedData)
            }
        }
    }

    private fun gotoVcApproveCore(proposal: JSONObject, kProcessedData: JSONObject) {
        val needAuthorizeHash = kProcessedData.getJSONObject("needAuthorizeHash")
        val walletMgr = WalletManager.sharedWalletManager()
        val idAccountDataHash = walletMgr.getAllAccountDataHash(false)

        //  1、筛选我钱包中所有的【权限实体】
        val result = JSONObject()
        needAuthorizeHash.keys().forEach { key ->
            val item = needAuthorizeHash.getJSONObject(key)
            assert(item.getString("key") == key)
            if (item.optBoolean("isaccount")) {
                val account_data = idAccountDataHash.optJSONObject(key)
                if (account_data != null) {
                    result.put(key, item)
                }
            } else if (item.optBoolean("iskey")) {
                if (walletMgr.havePrivateKey(key)) {
                    result.put(key, item)
                }
            }
        }

        if (result.length() <= 0) {
            showToast(R.string.kProposalSubmitTipsNoPermissionApprove.xmlstring(this))
            return
        }

        //  2、筛选出尚未批准的【权限实体】
        val approveArray = JSONArray()
        val availableHash = kProcessedData.getJSONObject("availableHash")
        result.keys().forEach { key ->
            val item = result.getJSONObject(key)
            if (!availableHash.has(key)) {
                approveArray.put(item)
            }
        }

        if (approveArray.length() <= 0) {
            showToast(R.string.kProposalSubmitTipsYouAlreadyApproved.xmlstring(this))
            return
        }

        //  转到批准界面
        val result_promise = Promise()
        goTo(ActivityProposalAuthorizeEdit::class.java, true, args = jsonObjectfromKVS("proposal", proposal, "data_array", approveArray, "isremove", false,
                "result_promise", result_promise, "title", R.string.kVcTitleProposalAddApprove.xmlstring(this)))
        result_promise.then { result ->
            val json = result as? JSONObject
            if (json != null) {
                val target_account = json.getJSONObject("target_account")
                val fee_paying_account = json.getJSONObject("fee_paying_account")
                onUpdateProposalCore(proposal, fee_paying_account, target_account, false)
            }
        }
    }

    /**
     *  交易 - 更新提案
     */
    private fun onUpdateProposalCore(proposal: JSONObject, feePayingAccount: JSONObject, targetAccount: JSONObject, isRemove: Boolean) {
        //  1、判断手续费是否足够。（TODO:暂时不判断）

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        var permissions: JSONObject? = null
        var approval_account: JSONObject? = null

        //  添加/移除授权
        var active_approvals_to_add: JSONArray? = null
        var active_approvals_to_remove: JSONArray? = null
        var owner_approvals_to_add: JSONArray? = null
        var owner_approvals_to_remove: JSONArray? = null
        var key_approvals_to_add: JSONArray? = null
        var key_approvals_to_remove: JSONArray? = null

        if (isRemove) {
            if (targetAccount.optBoolean("isaccount")) {
                approval_account = chainMgr.getChainObjectByID(targetAccount.getString("key"))
                if (targetAccount.getBoolean("isactive")) {
                    active_approvals_to_remove = jsonArrayfrom(targetAccount.getString("key"))
                    permissions = approval_account.getJSONObject("active")
                } else {
                    owner_approvals_to_remove = jsonArrayfrom(targetAccount.getString("key"))
                    permissions = approval_account.getJSONObject("owner")
                }
            } else {
                assert(targetAccount.optBoolean("iskey"))
                //  REMARK：只有拥有私钥的KEY在可以移除。
                assert(WalletManager.sharedWalletManager().havePrivateKey(targetAccount.getString("key")))
                key_approvals_to_remove = jsonArrayfrom(targetAccount.getString("key"))
            }
        } else {
            if (targetAccount.optBoolean("isaccount")) {
                approval_account = chainMgr.getChainObjectByID(targetAccount.getString("key"))
                if (targetAccount.getBoolean("isactive")) {
                    active_approvals_to_add = jsonArrayfrom(targetAccount.getString("key"))
                    permissions = approval_account.getJSONObject("active")
                } else {
                    owner_approvals_to_add = jsonArrayfrom(targetAccount.getString("key"))
                    permissions = approval_account.getJSONObject("owner")
                }
            } else {
                assert(targetAccount.optBoolean("iskey"))
                //  REMARK：只有拥有私钥的KEY在可以添加。
                assert(WalletManager.sharedWalletManager().havePrivateKey(targetAccount.getString("key")))
                key_approvals_to_add = jsonArrayfrom(targetAccount.getString("key"))
            }
        }

        val needCreateProposal = permissions != null && !WalletManager.sharedWalletManager().canAuthorizeThePermission(permissions)
        //  REMARK：如果需要创建提案来更新提案，那么把提案内容的手续费支付对象设置为提案权限者对象自身。
        //  否则，会出现手续费对象和权限者对象两个实体，那么新创建的提案存在2个required_active_approvals对象，对大部分客户端不友好。
        val fee_paying_account = if (needCreateProposal) approval_account!!.getString("id") else feePayingAccount.getString("id")

        val opdata = jsonObjectfromKVS("fee", jsonObjectfromKVS("amount", 0, "asset_id", BTS_NETWORK_CORE_ASSET_ID),
                "fee_paying_account", fee_paying_account,
                "proposal", proposal.getString("id"),
                "active_approvals_to_add", active_approvals_to_add ?: JSONArray(),
                "active_approvals_to_remove", active_approvals_to_remove ?: JSONArray(),
                "owner_approvals_to_add", owner_approvals_to_add ?: JSONArray(),
                "owner_approvals_to_remove", owner_approvals_to_remove ?: JSONArray(),
                "key_approvals_to_add", key_approvals_to_add ?: JSONArray(),
                "key_approvals_to_remove", key_approvals_to_remove ?: JSONArray()
        )

        if (needCreateProposal) {
            //  发起提案交易
            askForCreateProposal(EBitsharesOperations.ebo_proposal_update, !targetAccount.getBoolean("isactive"),
                    false, opdata, approval_account!!, null) {
                showToast(R.string.kProposalSubmitTipTxOK.xmlstring(this))
                //  刷新界面
                queryAllProposals()
            }
        } else {
            //  普通交易：请求网络广播
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().proposalUpdate(opdata).then {
                mask.dismiss()
                if (isRemove) {
                    showToast(R.string.kProposalSubmitTxTipsRemoveApprovalOK.xmlstring(this))
                } else {
                    showToast(R.string.kProposalSubmitTxTipsAddApprovalOK.xmlstring(this))
                }
                //  [统计]
                btsppLogCustom("txProposalUpdateFullOK", jsonObjectfromKVS("account", fee_paying_account))
                //  刷新
                queryAllProposals()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txProposalUpdateFailed", jsonObjectfromKVS("account", fee_paying_account))
            }
        }
    }

    /**
     * 事件 - 否决按钮点击
     */
    private fun onRejectClicked(proposal: JSONObject) {
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                gotoVcRejectCore(proposal)
            }
        }
    }

    private fun gotoVcRejectCore(proposal: JSONObject) {
        val kProcessedData = proposal.getJSONObject("kProcessedData")
        val availableHash = kProcessedData.getJSONObject("availableHash")
        if (availableHash.length() <= 0) {
            showToast(R.string.kProposalSubmitTipsNoNeedRemove.xmlstring(this))
            return
        }
        val needAuthorizeHash = kProcessedData.getJSONObject("needAuthorizeHash")
        val rejectArray = JSONArray()
        val walletMgr = WalletManager.sharedWalletManager()
        val idAccountDataHash = walletMgr.getAllAccountDataHash(false)
        availableHash.keys().forEach { key ->
            //  REMARK：批准之后被刷掉了，无权限了，则不存在于需要授权列表了。
            val item = needAuthorizeHash.optJSONObject(key)
            if (item != null) {
                if (item.optBoolean("isaccount")) {
                    val account_data = idAccountDataHash.optJSONObject(key)
                    if (account_data != null) {
                        rejectArray.put(item)
                    }
                } else {
                    assert(item.optBoolean("iskey"))
                    if (walletMgr.havePrivateKey(key)) {
                        rejectArray.put(item)
                    }
                }
            }
        }
        if (rejectArray.length() <= 0) {
            showToast(R.string.kProposalSubmitTipsNoNeedRemove.xmlstring(this))
            return
        }
        //  转到移除授权界面
        val result_promise = Promise()
        goTo(ActivityProposalAuthorizeEdit::class.java, true, args = jsonObjectfromKVS("proposal", proposal, "data_array", rejectArray, "isremove", true,
                "result_promise", result_promise, "title", R.string.kVcTitleProposalRemoveApprove.xmlstring(this)))
        result_promise.then { result ->
            val json = result as? JSONObject
            if (json != null) {
                val target_account = json.getJSONObject("target_account")
                val fee_paying_account = json.getJSONObject("fee_paying_account")
                onUpdateProposalCore(proposal, fee_paying_account, target_account, true)
            }
        }
    }
}
