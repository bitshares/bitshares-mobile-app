package com.btsplusplus.fowallet

import android.annotation.SuppressLint
import android.app.ActionBar
import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.graphics.drawable.ClipDrawable
import android.graphics.drawable.ColorDrawable
import android.view.*
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.px2dp
import com.btsplusplus.fowallet.indictorView.AVLoadingIndicatorView
import org.xmlpull.v1.XmlPullParser



class ViewMask : Dialog {

    private var _owner: Context? = null

    @SuppressLint("ResourceType")
    constructor(loading_text: String, context: Context?) : super(context) {
        _owner = context

        val textView = TextView(context!!)
        textView.text = loading_text
        textView.setTextColor(context.resources.getColor(R.color.theme01_textColorMain))
        textView.gravity = Gravity.CENTER

        val layout_loading = LinearLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                gravity = Gravity.CENTER
            }
            gravity = Gravity.CENTER
        }
        LayoutInflater.from(context).inflate(R.layout.activity_loading_view, layout_loading)

        val layout = LinearLayout(context)
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER
        }
        layout.orientation = LinearLayout.VERTICAL
        layout.layoutParams = layout_params
        layout.gravity = Gravity.CENTER

        layout.background = context.resources.getDrawable(R.drawable.loading)
        layout.setPadding(5.dp, 14.dp, 5.dp, 20.dp)

        layout.addView(layout_loading)
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