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

class ViewProposalAccountUpdatePermissionOwner : LinearLayout {

    var _ctx: Context
    val content_fontsize = 11.0f

    constructor(ctx: Context) : super(ctx) {
        _ctx = ctx
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_params.topMargin = 10
        this.layoutParams = layout_params
        this.orientation = LinearLayout.VERTICAL
    }

    private fun genLineLables(name: String, old_value: Int, new_value: Int): LinearLayout {
        val layout = LinearLayout(_ctx)
        layout.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0, 2.dp, 0, 2.dp)
        }
        layout.orientation = LinearLayout.HORIZONTAL
        layout.gravity = Gravity.CENTER_VERTICAL
        layout.apply {
            val tv_name = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 5f)
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                setSingleLine(true)
                ellipsize = TextUtils.TruncateAt.valueOf("END")
                paint.isFakeBoldText = true
                text = name
            }
            val tv_change = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2f).apply {
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                paint.isFakeBoldText = true
                text = new_value.toString()
            }
            val tv_result = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1.5f).apply {
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                paint.isFakeBoldText = true
            }

            if (old_value == new_value) {
                tv_result.text = "0"
            } else if (new_value > old_value) {
                //  变化 +
                tv_result.text = "+${new_value - old_value}"
                tv_change.setTextColor(resources.getColor(R.color.theme01_buyColor))
            } else {
                //  变化 -
                tv_result.text = (new_value - old_value).toString()
                tv_change.setTextColor(resources.getColor(R.color.theme01_sellColor))
            }

            addView(tv_name)
            addView(tv_change)
            addView(tv_result)
        }
        return layout
    }

    fun initWithPermission(old_permission_json: JSONObject, new_permission_json: JSONObject, title: String): LinearLayout {

        // 第一行标题行: 权限 新阈值/新权重 变化量
        val layout_permission_title = LinearLayout(_ctx)
        layout_permission_title.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
        layout_permission_title.orientation = LinearLayout.HORIZONTAL
        layout_permission_title.gravity = Gravity.CENTER_VERTICAL
        layout_permission_title.apply {
            val tv_name = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 5f)
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorGray))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                paint.isFakeBoldText = true
                text = title
            }
            val tv_change = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2f).apply {
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorGray))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                paint.isFakeBoldText = true
                text = R.string.kOpDetailSubTitleNewWeightOrThreshold.xmlstring(_ctx)
            }
            val tv_result = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1.5f).apply {
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorGray))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                paint.isFakeBoldText = true
                text = R.string.kOpDetailSubTitleChangeValue.xmlstring(_ctx)
            }

            addView(tv_name)
            addView(tv_change)
            addView(tv_result)
        }
        addView(layout_permission_title)

        // 第二行 阈值 权重(值) 变化量(值)
        addView(genLineLables(R.string.kOpDetailSubPrefixThreshold.xmlstring(_ctx), old_permission_json.getInt("weight_threshold"), new_permission_json.getInt("weight_threshold")))

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val old_weights_hash = JSONObject()
        val new_weights_hash = JSONObject()
        val total_keys = JSONObject()

        old_permission_json.getJSONArray("account_auths").forEach<JSONArray> { it ->
            val item = it!!
            assert(item.length() == 2)
            val account_id = item.getString(0)
            old_weights_hash.put(account_id, item.getInt(1))
            total_keys.put(account_id, JSONObject().apply { put("isaccount", true) })
        }
        old_permission_json.getJSONArray("key_auths").forEach<JSONArray> { it ->
            val item = it!!
            assert(item.length() == 2)
            val key = item.getString(0)
            old_weights_hash.put(key, item.getInt(1))
            total_keys.put(key, JSONObject().apply { put("iskey", true) })
        }
        new_permission_json.getJSONArray("account_auths").forEach<JSONArray> { it ->
            val item = it!!
            assert(item.length() == 2)
            val account_id = item.getString(0)
            new_weights_hash.put(account_id, item.getInt(1))
            total_keys.put(account_id, JSONObject().apply { put("isaccount", true) })
        }
        new_permission_json.getJSONArray("key_auths").forEach<JSONArray> { it ->
            val item = it!!
            assert(item.length() == 2)
            val key = item.getString(0)
            new_weights_hash.put(key, item.getInt(1))
            total_keys.put(key, JSONObject().apply { put("iskey", true) })
        }
        total_keys.keys().toJSONArray().forEach<String> { it ->
            val key = it!!
            val info = total_keys.getJSONObject(key)
            val name: String
            if (info.optBoolean("isaccount")) {
                name = String.format("* %s", chainMgr.getChainObjectByID(key).getString("name"))
            } else {
                name = String.format("* %s", key)
            }

            var iOldWeight = 0
            var iNewWeight = 0
            val old_weight = old_weights_hash.optInt(key)
            if (old_weight != null) {
                iOldWeight = old_weight
            }
            val new_weight = new_weights_hash.optInt(key)
            if (new_weight != null) {
                iNewWeight = new_weight
            }

            addView(genLineLables(name, iOldWeight, iNewWeight))
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