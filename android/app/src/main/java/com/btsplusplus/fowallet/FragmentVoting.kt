package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.pow
import kotlin.math.round

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentVoting.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentVoting.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentVoting : BtsppFragment() {

    private val kSecTypeCommitteeActive = 0         //  活跃理事会成员
    private val kSecTypeCommitteeCandidate = 1      //  候选理事会成员（非活跃）
    private val kSecTypeWitnessActive = 2          //  活跃见证人
    private val kSecTypeWitnessCandidate = 3        //  候选见证人（非活跃）
    private val kSecTypeWorkerExpired = 4           //  过期的预算项目
    private val kSecTypeWorkerNotExpired = 5        //  非过期的预算项目
    private val kSecTypeWorkerActive = 6            //  活跃预算项目（能拿到预算金额的）
    private val kSecTypeWorkerInactive = 7          //  提案预算项目（投票尚未通过的预算项目）
    private val kBtnTagProxyHelp = 100              //  帮助：当前代理人

    private var listener: OnFragmentInteractionListener? = null

    private var _view: View? = null
    private var _ctx: Context? = null

    lateinit var _votingInfo: JSONObject
    private var _bts_precision: Int = 0
    private var _bts_precision_pow: Double = 0.0

    private var _vote_type: VotingTypes = VotingTypes.committees
    private var _have_proxy: Boolean = false
    private var _bDirty: Boolean = false
    private var _data_array = JSONArray()

    private var _nTotalBudget: BigDecimal? = null    //  预算总额（仅worker项目可能存在，worker也可能为nil。）
    private var _nActiveMinVoteNum: String? = null   //  预算项目通过最低票数（仅worker项目可能存在，worker也可能为nil。）

    override fun onInitParams(args: Any?) {
        _vote_type = args as VotingTypes
        val bts_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(BTS_NETWORK_CORE_ASSET_ID)
        _bts_precision = bts_asset.getInt("precision")
        _bts_precision_pow = 10.0.pow(_bts_precision)
    }

    /**
     * 处理数据响应
     * last_budget_object -  预算项目对象（可能为空）
     */
    fun onQueryDataResponsed(data_array: JSONArray, last_budget_object: JSONObject?, voting_info: JSONObject) {
        //  保存
        _votingInfo = voting_info
        //  更新代理人信息
        _have_proxy = _votingInfo.getBoolean("have_proxy")

        val gp = ChainObjectManager.sharedChainObjectManager().getObjectGlobalProperties()
        val active_committee_members = gp.getJSONArray("active_committee_members")
        val active_witnesses = gp.getJSONArray("active_witnesses")

        val active_committee_members_hash = JSONObject()
        val active_witnesses_hash = JSONObject()
        active_committee_members.forEach<String> { oid -> active_committee_members_hash.put(oid, true) }
        active_witnesses.forEach<String> { oid -> active_witnesses_hash.put(oid, true) }

        val voting_hash = _votingInfo.getJSONObject("voting_hash")
        if (_vote_type == VotingTypes.workers) {
            //  预算提案（活跃预算、提案预算、过期预算）

            //  1、筛选过期和有效的预算项目
            val ary_expired_worker = mutableListOf<JSONObject>()
            val ary_valid = mutableListOf<JSONObject>()
            val now_ts = Utils.now_ts()
            for (worker in data_array) {
                val selected = voting_hash.has(worker!!.getString("vote_for"))
                worker.put("_kSelected", selected)
                worker.put("_kOldSelected", selected)
                val end_data_ts = Utils.parseBitsharesTimeString(worker.getString("work_end_date"))
                if (now_ts >= end_data_ts) {
                    ary_expired_worker.add(worker)
                } else {
                    ary_valid.add(worker)
                }
            }
            //  2、按照得票排序有效预算项目
            val ary_valid_sorted = ary_valid.sortedByDescending { it.getString("total_votes_for").toDouble() }
            //  3、有预算项目，则分成活跃和非活跃。无预算项目，则按照投票顺序排序即可。
            if (last_budget_object != null) {
                //  3.1、预算总额 = min(当前预算值 * 24小时, 最大预算)
                val worker_budget = last_budget_object.getJSONObject("record").getString("worker_budget")
                val max_worker_budget = gp.getJSONObject("parameters").getString("worker_budget_per_day")
                val n_bts_precision = BigDecimal.valueOf(_bts_precision_pow)
                val n_max_worker_budget = bigDecimalfromAmount(max_worker_budget, n_bts_precision)
                val n = bigDecimalfromAmount(worker_budget, n_bts_precision)
                _nTotalBudget = n.multiply(BigDecimal.valueOf(24.0))
                //  _nTotalBudget > n_max_worker_budget
                if (_nTotalBudget!!.compareTo(n_max_worker_budget) > 0) {
                    _nTotalBudget = n_max_worker_budget
                }
                //  3.2 分组（活跃和非活跃）
                val ary_active = mutableListOf<JSONObject>()
                val ary_inactive = mutableListOf<JSONObject>()
                var active_vote_number: String? = null
                val zero = BigDecimal.ZERO
                var rest_budget = _nTotalBudget
                for (worker in ary_valid_sorted) {
                    //  rest_budget > 0
                    if (rest_budget!!.compareTo(zero) > 0) {
                        ary_active.add(worker)
                        //  记录活跃最低票数需求。
                        active_vote_number = worker.getString("total_votes_for")
                    } else {
                        ary_inactive.add(worker)
                    }
                    //  TODO:fowallet 计算注资比例 = min(rest_budget, daily_pay) / daily_pay
                    //  计算下一个 worker 的剩余预算。
                    val n_daily_pay = bigDecimalfromAmount(worker.getString("daily_pay"), n_bts_precision)
                    rest_budget = rest_budget.subtract(n_daily_pay)
                }
                if (active_vote_number != null) {
                    _nActiveMinVoteNum = OrgUtils.formatFloatValue(round(active_vote_number.toDouble() / _bts_precision_pow), _bts_precision)
                } else {
                    //  REMARK：没有预算资金，所有投票无论多少都没法通过。
                    _nActiveMinVoteNum = ""
                }
                //  添加组：活跃预算项目和非活跃预算项目
                if (ary_active.size > 0) {
                    _data_array.put(jsonObjectfromKVS("kType", kSecTypeWorkerActive, "kDataArray", ary_active))
                }
                if (ary_inactive.size > 0) {
                    _data_array.put(jsonObjectfromKVS("kType", kSecTypeWorkerInactive, "kDataArray", ary_inactive))
                }
            } else {
                _nTotalBudget = null
                _nActiveMinVoteNum = null
                //  添加组：非过期预算项目
                _data_array.put(jsonObjectfromKVS("kType", kSecTypeWorkerNotExpired, "kDataArray", ary_valid_sorted))
            }
            //  添加组：过期预算项目
            _data_array.put(jsonObjectfromKVS("kType", kSecTypeWorkerExpired, "kDataArray", ary_expired_worker))
        } else {
            //  理事会、见证人
            val ary_active = mutableListOf<JSONObject>()
            val ary_candidate = mutableListOf<JSONObject>()
            for (obj in data_array) {
                val oid = obj!!.getString("id")
                val selected = voting_hash.has(obj.getString("vote_id"))
                obj.put("_kSelected", selected)
                obj.put("_kOldSelected", selected)
                if (active_committee_members_hash.has(oid) || active_witnesses_hash.has(oid)) {
                    ary_active.add(obj)
                } else {
                    ary_candidate.add(obj)
                }
            }
            val sorted_ary_active = ary_active.sortedByDescending { it.getString("total_votes").toDouble() }
            val sorted_ary_candidate = ary_candidate.sortedByDescending { it.getString("total_votes").toDouble() }
            if (_vote_type == VotingTypes.committees) {
                _data_array.put(jsonObjectfromKVS("kType", kSecTypeCommitteeActive, "kDataArray", sorted_ary_active))
                _data_array.put(jsonObjectfromKVS("kType", kSecTypeCommitteeCandidate, "kDataArray", sorted_ary_candidate))
            } else {
                _data_array.put(jsonObjectfromKVS("kType", kSecTypeWitnessActive, "kDataArray", sorted_ary_active))
                _data_array.put(jsonObjectfromKVS("kType", kSecTypeWitnessCandidate, "kDataArray", sorted_ary_candidate))
            }
        }

        //  刷新界面
        refreshUI()
    }

    private fun createHeaderView(ctx: Context, text: String, hasTip: Boolean, auxArgs: JSONObject): LinearLayout {

        val ly_header = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, toDp(32f), null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)

        val tv_header_title = ViewUtils.createTextView(ctx, text, 13f, R.color.theme01_textColorHighlight, true)
        tv_header_title.gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
        val tv_header_title_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, toDp(32.0f))
        tv_header_title_layout_params.gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
        tv_header_title_layout_params.weight = 1.0f

        val tv_header_link_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, toDp(32.0f))
        tv_header_link_layout_params.gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
        tv_header_link_layout_params.weight = 1.0f
        ly_header.addView(tv_header_title, tv_header_title_layout_params)

        if (hasTip) {
            //  问号帮助按钮
            if (auxArgs.length() > 0) {
                val tv_header_link = ImageView(ctx)
                tv_header_link.setImageResource(R.drawable.icon_tip)
                tv_header_link.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
                tv_header_link.right = Gravity.RIGHT
                val tv_header_link_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                tv_header_link_layout_params.gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                tv_header_link.layoutParams = tv_header_link_layout_params

                val link_title = auxArgs.getString("kTitle")
                val link_url = auxArgs.getString("kURL")
                tv_header_link.setOnClickListener {
                    //  [统计]
                    btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", link_url.split('#').last()))
                    activity!!.goToWebView(link_title, link_url)
                }
                ly_header.addView(tv_header_link)
            }
        } else {
            //  其他值
            if (auxArgs.length() > 0) {
                val text_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, toDp(32.0f))

                val right_tv1 = TextView(ctx)
                right_tv1.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                right_tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f)
                right_tv1.gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                right_tv1.text = auxArgs.getString("kTitle")
                right_tv1.setPadding(0, 0, toDp(2f), 0)

                val right_tv2 = TextView(ctx)
                right_tv2.setTextColor(resources.getColor(R.color.theme01_textColorMain))
                right_tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f)
                right_tv2.gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                right_tv2.text = auxArgs.getString("kValue")

                ly_header.addView(right_tv1, text_layout_params)
                ly_header.addView(right_tv2, text_layout_params)
            }
        }

        return ly_header
    }

    private fun addACommitteeView(ctx: Context, v: View, index: Int, data: JSONObject) {
        val account_id: String = when (_vote_type) {
            VotingTypes.committees -> data.getString("committee_member_account")
            VotingTypes.witnesses -> data.getString("witness_account")
            VotingTypes.workers -> data.getString("worker_account")
        }
        assert(account_id != "")

        val ly_body: LinearLayout = v.findViewById(R.id.voting_sv)

        val ly_wrap = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT, null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val ly_left = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.MATCH_PARENT, 0.5f, Gravity.LEFT or Gravity.CENTER_VERTICAL, null)
        val ly_right = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.MATCH_PARENT, 7.0f, Gravity.RIGHT or Gravity.TOP, LinearLayout.VERTICAL)

        ly_wrap.setPadding(0, toDp(10f), 0, toDp(10f))

        val checkbox = CheckBox(ctx)
        checkbox.text = ""
        checkbox.isChecked = data.getBoolean("_kSelected")
        checkbox.tag = "checkbox.$index"
        checkbox.scaleX = 0.5f
        checkbox.scaleY = 0.5f
        val checkbox_drawable = resources.getDrawable(R.drawable.checkbox_drawable)
        checkbox.buttonDrawable = checkbox_drawable

        val user = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(account_id)
        val account_name = user.getString("name")
        val total_votes = OrgUtils.formatFloatValue(round(data.getString("total_votes").toDouble() / _bts_precision_pow), _bts_precision)

        // 右边第一行
        val ly_line1 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT, null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val tv1_center = ViewUtils.createTextView(ctx, "${index + 1}. $account_name", 13f, R.color.theme01_textColorNormal, true)
        tv1_center.tag = "tv1_center.$index"
        tv1_center.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
        val tv1_right = ViewUtils.createTextView(ctx, R.string.kLabelVotingIntroduction.xmlstring(ctx), 11f, R.color.theme01_textColorHighlight, false)
        tv1_right.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
        //  不可见
        val url = data.optString("url", "")
        if (url == "") {
            tv1_right.visibility = android.view.View.INVISIBLE
        }
        tv1_right.gravity = Gravity.RIGHT
        tv1_right.setPadding(0, toDp(2.5f), 0, toDp(2.5f))
        tv1_center.setPadding(0, toDp(2.5f), 0, toDp(2.5f))

        ly_line1.addView(tv1_center)
        ly_line1.addView(tv1_right)

        // 右边第二行
        val ly_line2 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT, null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val line2_ly1 = ViewUtils.createLinearLayout(ctx, 0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val line2_ly2 = ViewUtils.createLinearLayout(ctx, 0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        line2_ly2.gravity = Gravity.RIGHT
        val tv1_line2_ly1 = ViewUtils.createTextView(ctx, "${ctx.resources.getString(R.string.kVcVoteCellTotalVotes)} ", 11f, R.color.theme01_textColorNormal, true)
        val tv2_line2_ly1 = ViewUtils.createTextView(ctx, total_votes, 11f, R.color.theme01_textColorNormal, true)
        tv2_line2_ly1.tag = "tv2_line2_ly1.$index"
        line2_ly1.addView(tv1_line2_ly1)
        line2_ly1.addView(tv2_line2_ly1)
        ly_line2.addView(line2_ly1)
        ly_line2.addView(line2_ly2)

        var tv2_line2_ly2: TextView? = null
        if (_vote_type == VotingTypes.witnesses) {
            val total_missed = data.optString("total_missed", "")

            val tv1_line2_ly2 = ViewUtils.createTextView(ctx, "${ctx.resources.getString(R.string.kVcVoteCellMissed)} ", 11f, R.color.theme01_textColorNormal, true)
            tv2_line2_ly2 = ViewUtils.createTextView(ctx, total_missed, 11f, R.color.theme01_textColorNormal, true)
            tv2_line2_ly2.tag = "tv2_line2_ly2.$index"
            tv1_line2_ly2.gravity = Gravity.RIGHT
            tv2_line2_ly2.gravity = Gravity.RIGHT

            line2_ly2.addView(tv1_line2_ly2)
            line2_ly2.addView(tv2_line2_ly2)
        }

        //  refresh selected color
        val fun_update_select_color = label@{ selected: Boolean ->
            val init_color = if (selected) {
                resources.getColor(R.color.theme01_textColorMain)
            } else {
                resources.getColor(R.color.theme01_textColorNormal)
            }
            tv1_center.setTextColor(init_color)
            tv2_line2_ly1.setTextColor(init_color)
            tv2_line2_ly2?.setTextColor(init_color)
            return@label
        }

        fun_update_select_color(data.getBoolean("_kSelected"))

        //  checkbox点击事件
        checkbox.setOnCheckedChangeListener { _, isChecked ->
            //  更新选中状态
            data.put("_kSelected", isChecked)
            //  更新脏标记
            _bDirty = _isUserModifyed()
            //  更新颜色
            fun_update_select_color(isChecked)
        }

        //  介绍点击事件
        if (url != "") {
            tv1_right.setOnClickListener {
                activity!!.openURL(url)
            }
        }

        ly_left.addView(checkbox)
        ly_right.addView(ly_line1)
        ly_right.addView(ly_line2)

        ly_wrap.addView(ly_left)
        ly_wrap.addView(ly_right)
        ly_body.addView(ly_wrap)
        ly_body.addView(ViewUtils.createLine(ctx))
    }

    private fun addAWorkerView(ctx: Context, v: View, index: Int, data: JSONObject) {

        val ly_body: LinearLayout = v.findViewById(R.id.voting_sv)

        val ly_wrap = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT, null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)

        val left_wrap = ViewUtils.createLinearLayout(ctx, 0, LinearLayout.LayoutParams.MATCH_PARENT, 1f, Gravity.LEFT or Gravity.CENTER_VERTICAL, null)
        val right_wrap = ViewUtils.createLinearLayout(ctx, 0, LinearLayout.LayoutParams.MATCH_PARENT, 6.5f, Gravity.LEFT or Gravity.CENTER_VERTICAL, LinearLayout.VERTICAL)


        val ly_line1 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(25f, ctx.resources), null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val ly_line2 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(25f, ctx.resources), null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val ly_line3 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(25f, ctx.resources), null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val ly_line4 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(25f, ctx.resources), null, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)

        ly_wrap.setPadding(0, toDp(10f), 0, toDp(10f))

        val checkbox = CheckBox(ctx)
        val checkbox_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.MATCH_PARENT)
        checkbox_layout_params.gravity = LinearLayout.VERTICAL
        checkbox.isChecked = data.getBoolean("_kSelected")
        checkbox.layoutParams = checkbox_layout_params
        checkbox.text = ""
        checkbox.tag = "checkbox.$index"
        checkbox.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER_HORIZONTAL
        checkbox.scaleX = 0.5f
        checkbox.scaleY = 0.5f
        val checkbox_drawable = resources.getDrawable(R.drawable.checkbox_drawable)
        checkbox.buttonDrawable = checkbox_drawable

        //  第一行 name
        val worker_name = data.getString("name")
        val tv1_line1 = ViewUtils.createTextView(ctx, "${index + 1}. $worker_name", 13f, R.color.theme01_textColorNormal, true)
        tv1_line1.setSingleLine(true)
        tv1_line1.maxLines = 1
        tv1_line1.ellipsize = TextUtils.TruncateAt.END
        tv1_line1.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 8f)

        val tv2_line1 = ViewUtils.createTextView(ctx, R.string.kLabelVotingIntroduction.xmlstring(ctx), 11f, R.color.theme01_textColorHighlight, true)
        tv2_line1.gravity = Gravity.RIGHT
        val tv2_line1_layout_params = LinearLayout.LayoutParams(0, Utils.toDp(25f, ctx.resources), 1.5f)
        tv2_line1_layout_params.gravity = Gravity.RIGHT
        tv2_line1.layoutParams = tv2_line1_layout_params
        tv1_line1.tag = "tv1_line1.$index"
        tv2_line1.tag = "tv2_line1.$index"
        //  不可见
        val url = data.optString("url", "")
        if (url == "") {
            tv2_line1.visibility = android.view.View.INVISIBLE
        }

        //  第二行 creator
        val account_id = data.getString("worker_account")
        val name = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(account_id).getString("name")
        val worker_id = data.getString("id")

        val tv1_line2 = ViewUtils.createTextView(ctx, "${ctx.resources.getString(R.string.kVcVoteCellWorkerID)} ", 11f, R.color.theme01_textColorNormal, true)
        val tv2_line2 = ViewUtils.createTextView(ctx, worker_id, 11f, R.color.theme01_textColorNormal, true)
        val tv3_line2 = ViewUtils.createTextView(ctx, "${ctx.resources.getString(R.string.kVcVoteCellCreator)} ", 11f, R.color.theme01_textColorNormal, true)
        val tv4_line2 = ViewUtils.createTextView(ctx, name, 11f, R.color.theme01_textColorNormal, true)
        tv3_line2.gravity = Gravity.RIGHT
        tv4_line2.gravity = Gravity.RIGHT
        val ly1_line2 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.WRAP_CONTENT, Utils.toDp(25f, ctx.resources), 1f, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL).apply {
            addView(tv1_line2)
            addView(tv2_line2)
        }
        val ly2_line2 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.WRAP_CONTENT, Utils.toDp(25f, ctx.resources), 1f, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL).apply {
            gravity = Gravity.RIGHT
            addView(tv3_line2)
            addView(tv4_line2)
        }

        //  第三行 votes & daily_pay
        val ly1_line3 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.WRAP_CONTENT, Utils.toDp(25f, ctx.resources), 1f, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val ly2_line3 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.WRAP_CONTENT, Utils.toDp(25f, ctx.resources), 1f, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        ly2_line3.gravity = Gravity.RIGHT

        val total_votes_for = OrgUtils.formatFloatValue(round(data.getString("total_votes_for").toDouble() / _bts_precision_pow), _bts_precision)
        val daily_pay = round(data.getString("daily_pay").toDouble() / _bts_precision_pow).toLong().toString()
        val tv1_line3 = ViewUtils.createTextView(ctx, "${ctx.resources.getString(R.string.kVcVoteCellTotalVotes)} ", 11f, R.color.theme01_textColorNormal, true)
        val tv2_line3 = ViewUtils.createTextView(ctx, total_votes_for, 11f, R.color.theme01_textColorNormal, true)
        val tv3_line3 = ViewUtils.createTextView(ctx, "${ctx.resources.getString(R.string.kVcVoteCellDailyPay)} ", 11f, R.color.theme01_textColorNormal, true)
        val tv4_line3 = ViewUtils.createTextView(ctx, daily_pay, 11f, R.color.theme01_textColorNormal, true)
        tv3_line3.gravity = Gravity.RIGHT
        tv4_line3.gravity = Gravity.RIGHT
        tv1_line3.tag = "tv1_line3.$index"
        tv2_line3.tag = "tv2_line3.$index"
        tv3_line3.tag = "tv3_line3.$index"
        tv4_line3.tag = "tv4_line3.$index"

        //  第四行 date & type
        val ly1_line4 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.WRAP_CONTENT, Utils.toDp(25f, ctx.resources), 1f, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        val ly2_line4 = ViewUtils.createLinearLayout(ctx, LinearLayout.LayoutParams.WRAP_CONTENT, Utils.toDp(25f, ctx.resources), 1f, Gravity.CENTER_VERTICAL, LinearLayout.HORIZONTAL)
        ly2_line4.gravity = Gravity.RIGHT

        val work_begin_date = Utils.parseBitsharesTimeString(data.getString("work_begin_date"))
        val work_end_date = Utils.parseBitsharesTimeString(data.getString("work_end_date"))
        val fmt = SimpleDateFormat("yy/MM/dd")
        val s_work_begin_date = fmt.format(Date(work_begin_date * 1000))
        val s_work_end_date = fmt.format(Date(work_end_date * 1000))
        val tv1_line4 = ViewUtils.createTextView(ctx, "${ctx.resources.getString(R.string.kVcVoteCellWPDatePeriod)} ", 11f, R.color.theme01_textColorNormal, true)
        val tv2_line4 = ViewUtils.createTextView(ctx, "${s_work_begin_date} - ${s_work_end_date}", 11f, R.color.theme01_textColorNormal, true)

        val typevalue = OrgUtils.getWorkerType(data)
        val typename = when (typevalue) {
            EBitsharesWorkType.ebwt_refund.value -> R.string.kVcVoteCellWPRefund.xmlstring(ctx)
            EBitsharesWorkType.ebwt_vesting.value -> R.string.kVcVoteCellWPVesting.xmlstring(ctx)
            else -> R.string.kVcVoteCellWPBurn.xmlstring(ctx)
        }
        val isRefundOrBurnWorker = typevalue != 1
        val tv3_line4 = ViewUtils.createTextView(ctx, "${R.string.kVcVoteCellWPType.xmlstring(ctx)} ", 11f, R.color.theme01_textColorNormal, true)
        val tv4_line4 = ViewUtils.createTextView(ctx, typename, 11f, R.color.theme01_textColorNormal, true)
        tv3_line4.gravity = Gravity.RIGHT
        tv4_line4.gravity = Gravity.RIGHT
        tv1_line4.tag = "tv1_line4.$index"
        tv2_line4.tag = "tv2_line4.$index"
        tv3_line4.tag = "tv3_line4.$index"
        tv4_line4.tag = "tv4_line4.$index"

        //  refresh selected color
        val fun_update_select_color = label@{ selected: Boolean ->
            val color = if (selected) {
                resources.getColor(R.color.theme01_textColorMain)
            } else {
                resources.getColor(R.color.theme01_textColorNormal)
            }
            tv1_line1.setTextColor(color)
            tv2_line2.setTextColor(color)
            tv4_line2.setTextColor(color)
            tv2_line3.setTextColor(color)
            tv4_line3.setTextColor(color)
            tv2_line4.setTextColor(color)
            val typecolor = if (selected) {
                if (isRefundOrBurnWorker) resources.getColor(R.color.theme01_callOrderColor) else resources.getColor(R.color.theme01_textColorMain)
            } else {
                resources.getColor(R.color.theme01_textColorNormal)
            }
            tv4_line4.setTextColor(typecolor)
            return@label
        }

        fun_update_select_color(data.getBoolean("_kSelected"))

        checkbox.setOnCheckedChangeListener { _, isChecked ->
            //  更新选中状态
            data.put("_kSelected", isChecked)
            //  更新脏标记
            _bDirty = _isUserModifyed()
            //  更新颜色
            fun_update_select_color(isChecked)
        }

        //  介绍点击事件
        if (url != "") {
            tv2_line1.setOnClickListener {
                activity!!.openURL(url)
            }
        }

        ly1_line3.addView(tv1_line3)
        ly1_line3.addView(tv2_line3)
        ly2_line3.addView(tv3_line3)
        ly2_line3.addView(tv4_line3)

        ly_line1.addView(tv1_line1)
        ly_line1.addView(tv2_line1)
        ly_line2.addView(ly1_line2)
        ly_line2.addView(ly2_line2)
        ly_line3.addView(ly1_line3)
        ly_line3.addView(ly2_line3)
        ly1_line4.addView(tv1_line4)
        ly1_line4.addView(tv2_line4)
        ly2_line4.addView(tv3_line4)
        ly2_line4.addView(tv4_line4)
        ly_line4.addView(ly1_line4)
        ly_line4.addView(ly2_line4)

        left_wrap.addView(checkbox)

        right_wrap.addView(ly_line1)
        right_wrap.addView(ly_line2)
        right_wrap.addView(ly_line3)
        right_wrap.addView(ly_line4)

        ly_wrap.addView(left_wrap)
        ly_wrap.addView(right_wrap)

        ly_body.addView(ly_wrap)
        ly_body.addView(ViewUtils.createLine(ctx))
    }

    /**
     * (public) 重置用户所做的修改。
     */
    fun resetUserModify() {
        _bDirty = false
        for (it in _data_array) {
            val data = it as JSONObject
            val list = data.get("kDataArray") as List<JSONObject>
            for (json in list) {
                json.put("_kSelected", json.getBoolean("_kOldSelected"))
            }
        }
        //  刷新UI
        refreshUI()
    }

    /**
     * (public) 获取当前用户选择的投票列表。
     */
    fun getCurrSelectVotingInfos(): JSONArray {
        val selected_vote_id = JSONArray()
        for (it in _data_array) {
            val data = it as JSONObject
            val list = data.get("kDataArray") as List<JSONObject>
            for (json in list) {
                if (json.getBoolean("_kSelected")) {
                    //  理事会、见证人
                    if (_vote_type == VotingTypes.workers) {
                        //  TODO:fowallet vote_against 反对票（暂时没用到）
                        selected_vote_id.put(json.getString("vote_for"))
                    } else {
                        selected_vote_id.put(json.getString("vote_id"))
                    }
                }
            }
        }
        return selected_vote_id
    }

    /**
     * (public) 获取投票信息成功，刷新界面。
     */
    fun onQueryVotingInfoResponsed(voting_info: JSONObject) {
        //  保存
        _votingInfo = voting_info
        //  更新代理人信息
        _have_proxy = _votingInfo.getBoolean("have_proxy")
        //  投票成功（可能更换了代理人，重新初始化脏标记和selected标记。）
        _bDirty = false
        val voting_hash = _votingInfo.getJSONObject("voting_hash")
        for (it in _data_array) {
            val data = it as JSONObject
            val list = data.get("kDataArray") as List<JSONObject>
            for (json in list) {
                var vote_id: String
                if (_vote_type == VotingTypes.workers) {
                    vote_id = json.getString("vote_for")
                } else {
                    vote_id = json.getString("vote_id")
                }
                val selected = voting_hash.has(vote_id)
                json.put("_kSelected", selected)
                json.put("_kOldSelected", selected)
            }
        }

        //  刷新
        refreshUI()
    }

    /**
     * (private) 用户是否编辑过判断
     */
    private fun _isUserModifyed(): Boolean {
        for (it in _data_array) {
            val data = it as JSONObject
            val list = data.get("kDataArray") as List<JSONObject>
            for (json in list) {
                val _kSelected = json.getBoolean("_kSelected")
                val _kOldSelected = json.getBoolean("_kOldSelected")
                if (_kSelected != _kOldSelected) {
                    return true
                }
            }
        }
        return false
    }

    private fun refreshUI() {
        val ly_body: LinearLayout = _view!!.findViewById(R.id.voting_sv)
        ly_body.removeAllViews()

        var offset_index: Int = 0
        _data_array.forEach<JSONObject> {
            val data = it as JSONObject
            val list = data.get("kDataArray") as List<JSONObject>
            val type = data.getInt("kType")
            val n = list.size
            var segtitle: String = ""
            var hastip: Boolean = true
            val auxArgs = JSONObject()
            when (type) {
                kSecTypeCommitteeActive -> {
                    segtitle = String.format(_ctx!!.resources.getString(R.string.kLabelVotingActiveCommittees), n.toString())
                    auxArgs.put("kTitle", _ctx!!.resources.getString(R.string.kVcVoteWhatIsActiveCommittee))
                    auxArgs.put("kURL", "https://btspp.io/qam.html#qa_committee")
                }
                kSecTypeCommitteeCandidate -> {
                    segtitle = String.format(_ctx!!.resources.getString(R.string.kLabelVotingStandbyCommittees), n.toString())
                    auxArgs.put("kTitle", _ctx!!.resources.getString(R.string.kVcVoteWhatIsStandbyCommittee))
                    auxArgs.put("kURL", "https://btspp.io/qam.html#qa_committee_c")
                }
                kSecTypeWitnessActive -> {
                    segtitle = String.format(_ctx!!.resources.getString(R.string.kLabelVotingActiveWitnesses), n.toString())
                    auxArgs.put("kTitle", _ctx!!.resources.getString(R.string.kVcVoteWhatIsActiveWitness))
                    auxArgs.put("kURL", "https://btspp.io/qam.html#qa_witness")
                }
                kSecTypeWitnessCandidate -> {
                    segtitle = String.format(_ctx!!.resources.getString(R.string.kLabelVotingStandbyWitnesses), n.toString())
                    auxArgs.put("kTitle", _ctx!!.resources.getString(R.string.kVcVoteWhatIsStandbyWitness))
                    auxArgs.put("kURL", "https://btspp.io/qam.html#qa_witness_c")
                }
                kSecTypeWorkerExpired -> {
                    segtitle = String.format(_ctx!!.resources.getString(R.string.kLabelVotingExpiredWP), n.toString())
                    hastip = false
                }
                kSecTypeWorkerNotExpired -> {
                    segtitle = String.format(_ctx!!.resources.getString(R.string.kLabelVotingNotExpiredWP), n.toString())
                    hastip = false
                }
                kSecTypeWorkerActive -> {
                    segtitle = String.format(_ctx!!.resources.getString(R.string.kLabelVotingActiveWP), n.toString())
                    hastip = false
                    auxArgs.put("kTitle", "${_ctx!!.resources.getString(R.string.kLabelVotingTotalBudget)} ")
                    auxArgs.put("kValue", OrgUtils.formatFloatValue(round(_nTotalBudget!!.toDouble()), _bts_precision, has_comma = false))
                }
                kSecTypeWorkerInactive -> {
                    segtitle = String.format(_ctx!!.resources.getString(R.string.kLabelVotingInactiveWP), n.toString())
                    hastip = false
                    auxArgs.put("kTitle", "${_ctx!!.resources.getString(R.string.kLabelVotingWPPassVotes)} ")
                    auxArgs.put("kValue", _nActiveMinVoteNum)
                }
                else -> assert(false)
            }
            ly_body.addView(createHeaderView(_ctx!!, segtitle, hastip, auxArgs))

            list.forEachIndexed { i, jsonObject ->
                if (_vote_type == VotingTypes.workers) {
                    addAWorkerView(_ctx!!, _view!!, offset_index + i, jsonObject)
                } else {
                    addACommitteeView(_ctx!!, _view!!, offset_index + i, jsonObject)
                }
            }
            offset_index += n
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        _ctx = inflater.context
        _view = inflater.inflate(R.layout.fragment_voting, container, false)
        return _view
    }

    // TODO: Rename method, update argument and hook method into UI event
    fun onButtonPressed(uri: Uri) {
        listener?.onFragmentInteraction(uri)
    }

    override fun onDetach() {
        super.onDetach()
        listener = null
    }

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     *
     *
     * See the Android Training lesson [Communicating with Other Fragments]
     * (http://developer.android.com/training/basics/fragments/communicating.html)
     * for more information.
     */
    interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        fun onFragmentInteraction(uri: Uri)
    }
}
