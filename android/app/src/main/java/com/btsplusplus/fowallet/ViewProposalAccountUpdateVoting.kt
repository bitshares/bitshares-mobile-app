package com.btsplusplus.fowallet

import android.content.Context
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject

class ViewProposalAccountUpdateVoting : LinearLayout {

    companion object {
        /**
         *  计算行显示信息
         */
        fun calcLineInfos(old_options_json: JSONObject, new_options_json: JSONObject): JSONObject {

            val total_keys = JSONObject()

            val old_voting_account = old_options_json.getString("voting_account")
            val new_voting_account = new_options_json.getString("voting_account")

            val old_is_self = old_voting_account == BTS_GRAPHENE_PROXY_TO_SELF
            val new_is_self = new_voting_account == BTS_GRAPHENE_PROXY_TO_SELF

            if (old_is_self && new_is_self) {
                //  1、更新前后都无代理：更新投票信息对比投票差异
                val old_vote_ids = JSONObject()
                val new_vote_ids = JSONObject()

                old_options_json.getJSONArray("votes").forEach<String> { vote_id ->
                    old_vote_ids.put(vote_id, true)
                }
                new_options_json.getJSONArray("votes").forEach<String> { vote_id ->
                    new_vote_ids.put(vote_id, true)
                }
                new_vote_ids.keys().toJSONArray().forEach<String> { vote_id ->
                    if (!old_vote_ids.optBoolean(vote_id)) {
                        //  新增
                        total_keys.put(vote_id, JSONObject().apply {
                            put("isvote", true)
                            put("isadd", true)
                        })
                    }
                }
                old_vote_ids.keys().toJSONArray().forEach<String> { vote_id ->
                    if (!new_vote_ids.optBoolean(vote_id)) {
                        //  删除
                        total_keys.put(vote_id, JSONObject().apply {
                            put("isvote", true)
                            put("isadd", false)
                        })
                    }
                }
            } else if (!old_is_self && new_is_self) {
                //  2、取消代理：所有的投票都属于新增。
                total_keys.put("kRemoveProxy", JSONObject().apply {
                    put("isremoveproxy", true)
                    put("voting_account", old_voting_account)
                })

                new_options_json.getJSONArray("votes").forEach<String> { vote_id ->
                    total_keys.put(vote_id, JSONObject().apply {
                        put("isvote", true)
                        put("isadd", true)
                    })
                }
            } else if (old_is_self && !new_is_self) {
                //  3、新增代理：投票信息根据代理人而定（自己的不显示）
                total_keys.put("kAddProxy", JSONObject().apply {
                    put("isaddproxy", true)
                    put("voting_account", new_voting_account)
                })
            } else if (!old_is_self && !new_is_self) {
                //  4、更新代理
                if (old_voting_account != new_voting_account) {
                    total_keys.put("kRemoveProxy", JSONObject().apply {
                        put("isremoveproxy", true)
                        put("voting_account", old_voting_account)
                    })
                    total_keys.put("kAddProxy", JSONObject().apply {
                        put("isaddproxy", true)
                        put("voting_account", new_voting_account)
                    })

                }
            }
            return total_keys
        }
    }

    var _ctx: Context
    private val content_fontsize = 11.0f

    constructor(ctx: Context) : super(ctx) {
        _ctx = ctx
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_params.topMargin = 10
        this.layoutParams = layout_params
        this.orientation = LinearLayout.VERTICAL
    }

    private fun genLineLables(name: String, result: String, color_name: Int, color_result: Int): LinearLayout {
        val layout = LinearLayout(_ctx)
        layout.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0, 2.dp, 0, 2.dp)
        }
        layout.orientation = LinearLayout.HORIZONTAL
        layout.gravity = Gravity.CENTER_VERTICAL
        layout.apply {
            val tv_name = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 6f)
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(color_name))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                paint.isFakeBoldText = true
                setSingleLine(true)
                ellipsize = TextUtils.TruncateAt.valueOf("END")
                text = name
            }
            val tv_result = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f).apply {
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(color_result))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                paint.isFakeBoldText = true
                text = result
            }
            addView(tv_name)
            addView(tv_result)
        }
        return layout
    }

    private fun genLablesFromLineInfo(line: JSONObject, vote_id: String?): LinearLayout {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        var name: String
        val status: String
        val name_color = R.color.theme01_textColorNormal
        val status_color: Int
        if (line.optBoolean("isvote")) {
            val vote_info = chainMgr.getVoteInfoByVoteID(vote_id!!)
            val committee_member_account = vote_info!!.optString("committee_member_account", null)
            if (committee_member_account != null) {
                name = String.format("%s %s", R.string.kOpDetailSubPrefixCommittee.xmlstring(_ctx), chainMgr.getChainObjectByID(committee_member_account).getString("name"))
            } else {
                val witness_account = vote_info.optString("witness_account", null)
                if (witness_account != null) {
                    name = String.format("%s %s", R.string.kOpDetailSubPrefixWitness.xmlstring(_ctx), chainMgr.getChainObjectByID(witness_account).getString("name"))
                } else {
                    name = String.format("%s %s", vote_info.getString("id"), vote_info.getString("name"))
                }
            }
            name = String.format("* %s", name)
            if (line.getBoolean("isadd")) {
                status = R.string.kOpDetailSubOpAdd.xmlstring(_ctx)
                status_color = R.color.theme01_buyColor
            } else {
                status = R.string.kOpDetailSubOpDelete.xmlstring(_ctx)
                status_color = R.color.theme01_sellColor
            }
        } else {
            if (line.optBoolean("isremoveproxy")) {
                name = String.format("* %s %s", R.string.kOpDetailSubPrefixProxy.xmlstring(_ctx), chainMgr.getChainObjectByID(line.getString("voting_account")).getString("name"))
                status = R.string.kOpDetailSubOpDelete.xmlstring(_ctx)
                status_color = R.color.theme01_sellColor
            } else {
                name = String.format("* %s %s", R.string.kOpDetailSubPrefixProxy.xmlstring(_ctx), chainMgr.getChainObjectByID(line.getString("voting_account")).getString("name"))
                status = R.string.kOpDetailSubOpAdd.xmlstring(_ctx)
                status_color = R.color.theme01_buyColor
            }
        }

        return genLineLables(name, status, name_color, status_color)

    }

    /**
     *  (private) 优先按照vote_type升序排列，vote_type相同则按照vote_id升序排列。
     */
    private fun _sort_votes(votes: JSONArray): JSONArray {
        return votes.toList<String>().sortedWith(Comparator { obj1, obj2 ->
            val ary1 = obj1.split(":")
            val ary2 = obj2.split(":")
            val vote_type_1 = ary1.first().toInt()
            val vote_type_2 = ary2.first().toInt()
            if (vote_type_1 == vote_type_2) {
                val vote_id_1 = ary1.last().toInt()
                val vote_id_2 = ary2.last().toInt()
                if (vote_id_1 < vote_id_2) {
                    return@Comparator -1
                } else if (vote_id_1 > vote_id_2) {
                    return@Comparator 1
                } else {
                    return@Comparator 0
                }
            } else {
                if (vote_type_1 < vote_type_2) {
                    return@Comparator -1
                } else {
                    return@Comparator 1
                }
            }
        }).toJsonArray()
    }

    fun initWithOptions(lines: JSONObject): LinearLayout {

        addView(genLineLables(R.string.kOpDetailSubTitleVoteTargeter.xmlstring(_ctx), R.string.kOpDetailSubTitleOperate.xmlstring(_ctx), R.color.theme01_textColorGray, R.color.theme01_textColorGray))

        val removeProxy = lines.optJSONObject("kRemoveProxy")
        if (removeProxy != null) {
            lines.remove("kRemoveProxy")
            addView(genLablesFromLineInfo(removeProxy, null))
        }

        val addProxy = lines.optJSONObject("kAddProxy")
        if (addProxy != null) {
            lines.remove("kAddProxy")
            addView(genLablesFromLineInfo(addProxy, null))
        }

        _sort_votes(lines.keys().toJSONArray()).forEach<String> { vote_id ->
            addView(genLablesFromLineInfo(lines.getJSONObject(vote_id), vote_id))
        }

        //  线
        val lv_line = View(_ctx)
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp).apply {
            topMargin = 6.dp
        }
        addView(lv_line)

        return this
    }
}
