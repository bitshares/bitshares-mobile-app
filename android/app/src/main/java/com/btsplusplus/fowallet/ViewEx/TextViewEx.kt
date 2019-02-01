package com.btsplusplus.fowallet.ViewEx

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_WARP
import com.btsplusplus.fowallet.R

class TextViewEx : TextView {

    constructor(
            context: Context, text: String, dp_size: Float = 14.0f, color: Int? = null, gravity: Int? = Gravity.LEFT or Gravity.CENTER,
            width: Int? = LLAYOUT_WARP, height: Int? = LLAYOUT_WARP, weight: Float? = null,
            margin_top: Int? = 0, margin_left: Int? = 0, margin_right: Int? = 0, margin_bottom: Int? = 0, bold: Boolean = false) : super(context) {

        val layout_params = LinearLayout.LayoutParams(width!!, height!!)
        layout_params.setMargins(margin_left!!, margin_top!!, margin_right!!, margin_bottom!!)

        this.setTextSize(TypedValue.COMPLEX_UNIT_DIP, dp_size)
        this.text = text
        if (bold) {
            this.paint.isFakeBoldText = true
        }

        if (color == null) {
            this.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            this.setTextColor(resources.getColor(color))
        }

        this.gravity = gravity!!
        layout_params.gravity = gravity!!
        if (weight != null) {
            layout_params.weight = weight
        }

        this.layoutParams = layout_params
    }

}
