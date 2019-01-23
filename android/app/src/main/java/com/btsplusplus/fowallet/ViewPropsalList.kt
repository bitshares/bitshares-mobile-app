package com.btsplusplus.fowallet

import android.content.Context
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.dp
import bitshares.xmlstring
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

class ViewPropsalList : LinearLayout {

    var m_ctx: Context

    constructor(ctx: Context) : super(ctx) {
        m_ctx = ctx
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_params.topMargin = 10
        this.layoutParams = layout_params
        this.orientation = LinearLayout.VERTICAL
    }

    fun init(proposal: JSONObject, dynamicInfos: JSONObject? = null): LinearLayout {
        val proposalProcessedData = proposal.getJSONObject("kProcessedData")
        val needAuthorizeHash = proposalProcessedData.getJSONObject("needAuthorizeHash")
        val availableHash = proposalProcessedData.getJSONObject("availableHash")
        val passThreshold = proposalProcessedData.getInt("passThreshold")
        assert(passThreshold > 0)

        //  动态信息：添加or移除授权时动态显示
        var dynamicKey: String? = null
        if (dynamicInfos != null) {
            dynamicKey = dynamicInfos.getString("key")
        }

        var index = 0
        needAuthorizeHash.keys().forEach { key ->
            val item = needAuthorizeHash.getJSONObject(key)
            val isApproved = availableHash.has(key)

            //  计算该授权实体占比权重。
            val threshold = item.getInt("threshold")
            var weight_percent = threshold.toDouble() * 100.0 / passThreshold.toDouble()
            if (threshold < passThreshold) {
                weight_percent = min(weight_percent, 99.0)
            }
            if (threshold > 0) {
                weight_percent = max(weight_percent, 1.0)
            }

            //  row layout
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 22.dp)
            val layout = LinearLayout(m_ctx)
            layout.layoutParams = layout_params
            layout.orientation = LinearLayout.HORIZONTAL

            //  entity 75% width
            val tv_left = TextView(m_ctx)
            tv_left.gravity = Gravity.LEFT
            var color: Int
            if (dynamicKey != null && dynamicKey == key) {
                color = if (dynamicInfos!!.getBoolean("remove")) resources.getColor(R.color.theme01_sellColor) else resources.getColor(R.color.theme01_buyColor)
            } else {
                color = if (isApproved) resources.getColor(R.color.theme01_buyColor) else resources.getColor(R.color.theme01_textColorNormal)
            }
            val name = item.getString("name")
            val progress = weight_percent.toInt()
            tv_left.text = "* ${progress}% ${name}"
            tv_left.gravity = Gravity.LEFT
            tv_left.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
            tv_left.paint.isFakeBoldText = true
            tv_left.setTextColor(color)
            tv_left.setSingleLine(true)
            tv_left.maxLines = 1
            tv_left.ellipsize = TextUtils.TruncateAt.END
            tv_left.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 7.5f)

            //  状态 25% width
            val layout_right_params = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 2.5f)
            layout_right_params.gravity = Gravity.RIGHT
            val layout_right = LinearLayout(m_ctx)
            layout_right.layoutParams = layout_right_params
            layout_right.orientation = LinearLayout.HORIZONTAL
            layout_right.gravity = Gravity.RIGHT

            var status_txt: String
            if (dynamicKey != null && dynamicKey == key) {
                status_txt = if (dynamicInfos!!.getBoolean("remove")) R.string.kProposalCellRemoveApproval.xmlstring(m_ctx) else R.string.kProposalCellAddApproval.xmlstring(m_ctx)
            } else {
                status_txt = if (isApproved) R.string.kProposalCellApproved.xmlstring(m_ctx) else R.string.kProposalCellNotApproved.xmlstring(m_ctx)
            }
            val tv_right = TextView(m_ctx)
            tv_right.text = status_txt
            tv_right.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
            tv_right.paint.isFakeBoldText = true
            tv_right.setTextColor(color)
            tv_right.gravity = Gravity.RIGHT


            layout_right.addView(tv_right)
            layout.addView(tv_left)
            layout.addView(layout_right)

            this.addView(layout)

            index++
        }
        return this
    }
}