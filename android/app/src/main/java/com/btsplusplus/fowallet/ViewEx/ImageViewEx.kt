package com.btsplusplus.fowallet.ViewEx

import android.content.Context
import android.widget.ImageView
import android.widget.LinearLayout
import bitshares.LLAYOUT_WARP

class ImageViewEx : ImageView {

    constructor(context: Context, resource_id: Int, color_filter: Int? = null, scale_x: Float? = 1.0f, scale_y: Float? = 1.0f, width: Int? = LLAYOUT_WARP, height: Int? = LLAYOUT_WARP, gravity: Int? = null) : super(context) {

        val layout_params = LinearLayout.LayoutParams(width!!, height!!)
        if (gravity != null) {
            layout_params.gravity = gravity
        }

        this.setImageDrawable(resources.getDrawable(resource_id))
        this.scaleX = scale_x!!
        this.scaleY = scale_y!!
        if (color_filter != null) {
            this.setColorFilter(resources.getColor(color_filter))
        }
        this.layoutParams = layout_params

    }

}