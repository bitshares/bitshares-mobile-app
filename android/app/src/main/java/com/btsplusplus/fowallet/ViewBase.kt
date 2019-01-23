package com.btsplusplus.fowallet

import android.content.Context
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.util.Size
import android.view.View

open class ViewBase : View {

    constructor(context: Context) : super(context)

    /**
     *  (public) 辅助计算文字尺寸
     */
    fun auxSizeWithText(text: String, typeface: Typeface, textsize: Float): Size {
        val paint = Paint()
        val rect = Rect()
        paint.textSize = textsize
        paint.typeface = typeface
        paint.getTextBounds(text, 0, text.length, rect)
        return Size(rect.width(), rect.height())
    }
}