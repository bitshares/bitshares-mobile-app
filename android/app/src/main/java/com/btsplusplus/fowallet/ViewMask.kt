package com.btsplusplus.fowallet

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.graphics.drawable.ClipDrawable
import android.graphics.drawable.ColorDrawable
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

class ViewMask : Dialog {

    private var _owner: Context? = null

    constructor(loading_text: String, context: Context?) : super(context) {
        _owner = context

        val textView = TextView(context!!)
        textView.text = loading_text
        textView.setTextColor(context.resources.getColor(R.color.theme01_textColorMain))
        textView.gravity = Gravity.CENTER

        val progress = ProgressBar(context)

        // Todo progress 变色不起作用
        val drawable = ClipDrawable(ColorDrawable(context.resources.getColor(R.color.theme01_textColorMain)), Gravity.LEFT, ClipDrawable.HORIZONTAL)
        progress.progressDrawable = drawable

        val layout = LinearLayout(context)
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout.orientation = LinearLayout.VERTICAL
        layout.layoutParams = layout_params

        layout.setBackgroundColor(context.resources.getColor(R.color.theme01_textColorGray))
        layout.setPadding(20, 20, 20, 20)

        layout.addView(progress)
        layout.addView(textView)

        setContentView(layout)

        setCanceledOnTouchOutside(false)
        setCancelable(false)

        // dialog 窗口属性
        val attr = window.attributes
        attr.gravity = Gravity.CENTER
        attr.width = LinearLayout.LayoutParams.WRAP_CONTENT
        attr.title = null
        attr.height = LinearLayout.LayoutParams.WRAP_CONTENT
        this.window.attributes = attr

        // REMARK 部分机型去除标题栏
        val v = this.findViewById<View>(android.R.id.title)
        v?.visibility = View.GONE

        //  禁止系统返回键
        this.setOnKeyListener { dialogInterface, keyCode, keyEvent ->
            if (keyCode == KeyEvent.KEYCODE_BACK) {
                return@setOnKeyListener false
            }
            return@setOnKeyListener true
        }
    }

    override fun dismiss() {
        val v = _owner as? Activity
        if (v != null) {
            if (!v.isFinishing && !v.isDestroyed) {
                super.dismiss()
            }
        } else {
            super.dismiss()
        }
    }

}