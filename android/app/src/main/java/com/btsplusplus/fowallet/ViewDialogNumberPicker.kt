package com.btsplusplus.fowallet

import android.app.Dialog
import android.content.Context
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.util.AttributeSet
import android.view.*
import android.widget.*
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp


class NumberPickerBtspp : NumberPicker {

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
        if ( view is EditText ) {
            ( view as EditText ).apply {
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                setFocusable(false)
            }
        }
    }
}

class ViewDialogNumberPicker : Dialog {

    constructor(ctx: Context, array_data: Array<String>, callback: (index: Int, result: String) -> Unit) : super(ctx) {
        var _ctx = ctx
        var _selected_value = 0

        // 外层 Layout
        val layout = LinearLayout(context)
        val layout_params = LinearLayout.LayoutParams(100.dp, 100.dp)
        layout.orientation = LinearLayout.VERTICAL
        layout.layoutParams = layout_params
        layout.setBackgroundColor(context!!.resources.getColor(R.color.theme01_appBackColor))
        layout.setPadding(20, 20, 20, 20)

        // 顶部按钮(取消 和 确认)
        val layout_buttons = LinearLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
            orientation = LinearLayout.HORIZONTAL
        }

        val tv_cancel = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP,1f)
            gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
            textSize = 7.5f.dp
            text = _ctx.resources.getString(R.string.nameCancel)
            setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
        }

        val tv_ok = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP, 1f)
            gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
            textSize = 7.5f.dp
            text = _ctx.resources.getString(R.string.nameOk)
            setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
        }

        val picker = NumberPickerBtspp(context)
        picker.displayedValues = array_data
        picker.minValue = 0
        picker.maxValue = array_data.size - 1
        picker.value = 0
        picker.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP )

        // 更改分割线颜色和高度（利用反射修改属性）
        picker.javaClass.superclass.declaredFields.forEach {
            if ( it.name.equals("mSelectionDivider") ) {
                it.isAccessible = true
                try {
                    it.set(picker, ColorDrawable(_ctx.resources.getColor(R.color.theme01_textColorGray)))
                } catch ( e: Exception ) {
                    e.printStackTrace()
                }
            }
            if ( it.name.equals("mSelectionDividerHeight" )){
                it.isAccessible = true
                try {
                    it.set(picker, 1)
                } catch ( e: Exception ) {
                    e.printStackTrace()
                }
            }
        }

        layout_buttons.addView(tv_cancel)
        layout_buttons.addView(tv_ok)
        layout.addView(layout_buttons)
        layout.addView(picker)

        setContentView(layout)
        setCanceledOnTouchOutside(false)
        setCancelable(false)

        // REMARK 部分机型去除标题栏
        val v = this.findViewById<View>(android.R.id.title)
        v?.visibility = View.GONE

        // 取消点击
        tv_cancel.setOnClickListener{
            dismiss()
        }

        // 确认点击
        tv_ok.setOnClickListener{
            callback.invoke(_selected_value,array_data[_selected_value])
            dismiss()
        }

        // number picker 选择
        picker.setOnValueChangedListener{ number_picker: NumberPicker, old_val: Int, new_val: Int ->
            _selected_value = new_val
        }

        //  禁止系统返回键
        this.setOnKeyListener { dialogInterface, keyCode, keyEvent ->
            if (keyCode == KeyEvent.KEYCODE_BACK) {
                return@setOnKeyListener false
            }
            return@setOnKeyListener true
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val window = this.window
        window.setGravity(Gravity.CENTER_VERTICAL)
        val params: WindowManager.LayoutParams  = window.attributes
        params.width = WindowManager.LayoutParams.MATCH_PARENT
        params.height = WindowManager.LayoutParams.WRAP_CONTENT
        window.attributes = params
    }
}