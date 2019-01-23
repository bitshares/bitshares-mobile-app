package com.btsplusplus.fowallet.ViewEx

import android.content.Context
import android.util.TypedValue
import android.widget.EditText
import android.widget.LinearLayout
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import com.btsplusplus.fowallet.R

class EditTextEx : EditText {
    constructor(context: Context, hint: String, width: Int = LLAYOUT_MATCH, height: Int = LLAYOUT_WARP, weight: Float? = null, dp_size: Float = 14.0f) : super(context) {
        val layout_params = LinearLayout.LayoutParams(width, height)
        if (weight != null) {
            layout_params.weight = weight
        }
        this.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        this.setHintTextColor(resources.getColor(R.color.theme01_textColorGray))
        this.setTextSize(TypedValue.COMPLEX_UNIT_DIP, dp_size)
        this.hint = hint
        this.layoutParams = layout_params
        this.background = null
        this.setPadding(0, 0, 0, 0)
    }

    fun initWithSingleLine(): EditText {
        this.setSingleLine(true)
        this.maxLines = 1
        return this
    }

    fun initWithMutiLine(lines: Int): EditText {
        this.maxLines = lines
        return this
    }
}
