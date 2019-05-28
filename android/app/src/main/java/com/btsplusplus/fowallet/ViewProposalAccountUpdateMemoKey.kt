package com.btsplusplus.fowallet

import android.content.Context
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.xmlstring

class ViewProposalAccountUpdateMemoKey : LinearLayout {

    var _ctx: Context
    val content_fontsize = 11.0f

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
                setSingleLine(true)
                setEllipsize(TextUtils.TruncateAt.valueOf("END"))
                paint.isFakeBoldText = true
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

    fun initWithOldMemo(old_memokey: String, new_memokey: String, title: String): LinearLayout {
        addView(genLineLables(title, R.string.kOpDetailSubTitleOperate.xmlstring(_ctx), R.color.theme01_textColorGray, R.color.theme01_textColorGray))
        addView(genLineLables("* ${old_memokey}", R.string.kOpDetailSubOpDelete.xmlstring(_ctx), R.color.theme01_textColorNormal, R.color.theme01_sellColor))
        addView(genLineLables("* ${new_memokey}", R.string.kOpDetailSubOpAdd.xmlstring(_ctx), R.color.theme01_textColorNormal, R.color.theme01_buyColor))

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