package com.btsplusplus.fowallet.ViewEx

import android.content.Context
import android.widget.LinearLayout
import bitshares.LLAYOUT_MATCH


class LinearLayoutEx : LinearLayout {

    constructor(context: Context, width: Int? = LLAYOUT_MATCH, height: Int? = LLAYOUT_MATCH, weight: Float? = null, orientation: Int? = LinearLayout.HORIZONTAL, gravity: Int? = null, params_gravity: Int? = null) : super(context) {
        val layout_params = LinearLayout.LayoutParams(width!!, height!!)
        if (orientation != null) {
            this.orientation = orientation
        }
        if (weight != null) {
            layout_params.weight = weight
        }
        if (gravity != null) {
            this.gravity = gravity
        }
        if (params_gravity != null) {
            layout_params.gravity = params_gravity
        }
        this.layoutParams = layout_params
    }
}