package com.btsplusplus.fowallet

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.util.AttributeSet
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.NumberPicker
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.forEach
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max

class BtsppNumberPicker : NumberPicker {

    constructor(ctx: Context) : super(ctx)
    constructor(ctx: Context, attrs: AttributeSet) : super(ctx, attrs)
    constructor(ctx: Context, attrs: AttributeSet, defStyleAttr: Int) : super(ctx, attrs, defStyleAttr)

    override fun addView(child: View?) {
        super.addView(child)
        updateView(child)
    }

    override fun addView(child: View?, index: Int) {
        super.addView(child, index)
        updateView(child)
    }

    override fun addView(child: View?, width: Int, height: Int) {
        super.addView(child, width, height)
        updateView(child)
    }

    override fun addView(child: View?, params: ViewGroup.LayoutParams?) {
        super.addView(child, params)
        updateView(child)
    }

    override fun addView(child: View?, index: Int, params: ViewGroup.LayoutParams?) {
        super.addView(child, index, params)
        updateView(child)
    }

    private fun updateView(view: View?) {
        if (view is EditText) {
            view.apply {
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                setFocusable(false)
            }
        }
    }
}

class ViewDialogNumberPicker : Dialog {

    constructor(ctx: Context, title: String?, source_list: JSONArray, itemkey: String?, default_selected: Int, callback: (index: Int, result: String) -> Unit) : super(ctx) {
        val string_list = mutableListOf<String>()
        if (itemkey != null) {
            source_list.forEach<JSONObject> {
                string_list.add(it!!.getString(itemkey))
            }
        } else {
            source_list.forEach<String> {
                string_list.add(it!!)
            }
        }
        val array_data = string_list.toTypedArray()

        //  外层 Layout
        val layout = LinearLayout(context)
        val layout_params = LinearLayout.LayoutParams(100.dp, 100.dp)
        layout_params.leftMargin = 0
        layout_params.rightMargin = 0
        layout.orientation = LinearLayout.VERTICAL
        layout.layoutParams = layout_params
        layout.setBackgroundColor(context.resources.getColor(R.color.theme01_appBackColor))
        layout.setPadding(0, 0, 0, 0)

        //  顶部按钮(取消 和 确认)
        val layout_buttons = LinearLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, 44.dp)
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 0, 0, 0)
            setBackgroundColor(context.resources.getColor(R.color.theme01_tabBarColor))
        }

        val tv_cancel = TextView(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f).apply {
                gravity = Gravity.CENTER_VERTICAL
            }
            gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
            this.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            text = ctx.resources.getString(R.string.Cancel)
            setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
            setPadding(10.dp, 0, 0, 0)
        }

        var tv_title: TextView? = null
        if (title != null && title.isNotEmpty()) {
            tv_title = TextView(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2f).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                this.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                text = title
                setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                setPadding(0, 0, 10.dp, 0)
            }
        }

        val tv_ok = TextView(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f).apply {
                gravity = Gravity.CENTER_VERTICAL
            }
            gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
            this.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            text = ctx.resources.getString(R.string.kBtnOK)
            setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
            setPadding(0, 0, 10.dp, 0)
        }

        val picker = BtsppNumberPicker(context)
        picker.displayedValues = array_data
        picker.minValue = 0
        picker.maxValue = array_data.size - 1
        picker.value = max(default_selected, 0)
        picker.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)

        //  更改分割线颜色和高度（利用反射修改属性）
        picker.javaClass.superclass.declaredFields.forEach {
            if (it.name == "mSelectionDivider") {
                it.isAccessible = true
                try {
                    it.set(picker, ColorDrawable(ctx.resources.getColor(R.color.theme01_bottomLineColor)))
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            if (it.name == "mSelectionDividerHeight") {
                it.isAccessible = true
                try {
                    it.set(picker, 1.dp)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        layout_buttons.addView(tv_cancel)
        tv_title?.let { layout_buttons.addView(it) }
        layout_buttons.addView(tv_ok)
        layout.addView(layout_buttons)
        layout.addView(picker)

        setContentView(layout)

        //  REMARK 部分机型去除标题栏
        val v = this.findViewById<View>(android.R.id.title)
        v?.visibility = View.GONE

        //  取消点击
        tv_cancel.setOnClickListener {
            dismiss()
        }

        //  确认点击
        tv_ok.setOnClickListener {
            val selected = picker.value
            callback.invoke(selected, array_data[selected])
            dismiss()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val window = this.window!!
        //  bottom
        window.setGravity(Gravity.BOTTOM)
        //  full screen
        window.decorView.setPadding(0, 0, 0, 0)
        val params: WindowManager.LayoutParams = window.attributes
        params.width = WindowManager.LayoutParams.MATCH_PARENT
        params.height = WindowManager.LayoutParams.WRAP_CONTENT
        window.attributes = params
        window.decorView.setBackgroundColor(Color.GREEN)
    }
}