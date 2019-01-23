package com.btsplusplus.fowallet.ViewEx

import android.content.Context
import android.view.View
import android.widget.LinearLayout
import bitshares.dp
import com.btsplusplus.fowallet.R

class ViewLine : View {

    constructor(context: Context) : super(context) {

        var layout_line_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
        this.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        this.layoutParams = layout_line_params
    }

}