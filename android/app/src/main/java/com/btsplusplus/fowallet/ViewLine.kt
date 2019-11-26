package com.btsplusplus.fowallet

import android.content.Context
import android.view.View
import android.widget.LinearLayout
import bitshares.dp

class ViewLine : View {

    constructor(context: Context, margin_top: Int = 0, margin_bottom: Int = 0, margin_left: Int = 0, margin_right: Int = 0) : super(context) {
        var layout_line_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
        layout_line_params.setMargins(margin_left, margin_top, margin_right, margin_bottom)
        this.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        this.layoutParams = layout_line_params
    }

}