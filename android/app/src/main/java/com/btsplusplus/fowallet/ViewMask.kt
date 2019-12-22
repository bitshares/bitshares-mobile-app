package com.btsplusplus.fowallet

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp


class ViewMask : Dialog {

    private var _owner: Context? = null

    @SuppressLint("ResourceType")
    constructor(loading_text: String, context: Context?) : super(context) {
        _owner = context

        //  加载中文字
        val textView = TextView(context!!)
        textView.text = loading_text
        textView.setTextColor(context.resources.getColor(R.color.theme01_textColorMain))
        textView.gravity = Gravity.CENTER

        //  转圈动画
        val layout_loading = LinearLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                gravity = Gravity.CENTER
            }
            gravity = Gravity.CENTER
        }
        LayoutInflater.from(context).inflate(R.layout.activity_loading_view, layout_loading)

        //  整体视图
        val layout = LinearLayout(context)
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER
        }
        layout.orientation = LinearLayout.VERTICAL
        layout.layoutParams = layout_params
        layout.gravity = Gravity.CENTER

        layout.background = context.resources.getDrawable(R.drawable.loading)
        layout.setPadding(10.dp, 16.dp, 10.dp, 16.dp)

        layout.addView(layout_loading)
        layout.addView(textView)

        setContentView(layout)

        setCanceledOnTouchOutside(false)
        setCancelable(false)

        //  dialog 窗口属性
        val attr = window.attributes
        attr.gravity = Gravity.CENTER
        attr.width = LinearLayout.LayoutParams.WRAP_CONTENT
        attr.title = null
        attr.height = LinearLayout.LayoutParams.WRAP_CONTENT
        this.window.setBackgroundDrawableResource(R.color.transparent)
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