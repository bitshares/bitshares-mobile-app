package com.btsplusplus.fowallet

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp

class ViewCustomDialogConfirm : Dialog {

    constructor(ctx: Context, body: LinearLayout, ConfirmText: String, CancelText: String, ConfirmCallback: (Any) -> Any) : super(ctx) {

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




        layout_buttons.addView(tv_cancel)
        layout_buttons.addView(tv_ok)
        layout.addView(layout_buttons)


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
            dismiss()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val window = this.window!!
        //  bottom
        window.setGravity(Gravity.CENTER)
        //  full screen
        window.decorView.setPadding(0, 0, 0, 0)
        val params: WindowManager.LayoutParams = window.attributes
        params.width = WindowManager.LayoutParams.MATCH_PARENT
        params.height = WindowManager.LayoutParams.WRAP_CONTENT
        window.attributes = params
        window.decorView.setBackgroundColor(Color.GREEN)
    }
}