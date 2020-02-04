package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.Utils
import bitshares.xmlstring
import org.json.JSONObject


class ViewAssetCell : LinearLayout {

    private var _ctx: Context
    private var _data: JSONObject

    constructor(ctx: Context, data: JSONObject) : super(ctx) {
        _ctx = ctx
        _data = data
        createUI()
    }

    private fun createUI(): LinearLayout {

        val ctx = _ctx
        val data = _data

        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(24f,_ctx.resources))
        layout_params.gravity = Gravity.CENTER_VERTICAL

        val ly_wrap: LinearLayout = LinearLayout(ctx)
        ly_wrap.orientation = LinearLayout.VERTICAL

        // layout1 左: Buy SEED/CNY 右: 07-11 11:50
        val ly1: LinearLayout = LinearLayout(ctx)
        ly1.orientation = LinearLayout.HORIZONTAL
        ly1.layoutParams = layout_params
        ly1.setPadding(0, Utils.toDp(5.0f,_ctx.resources), 0, 0)
        val tv1 = TextView(ctx)

        tv1.text = _data.getString("asset_symbol")
        tv1.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv1.gravity = Gravity.CENTER_VERTICAL
        tv1.setPadding(0,0,Utils.toDp(5.0f,_ctx.resources),0)

        val tv2 = TextView(ctx)
        tv2.text = "Smart"
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv2.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv2.gravity = Gravity.CENTER_VERTICAL
        tv2.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
        tv2.setPadding(Utils.toDp(5.0f,_ctx.resources), 0, Utils.toDp(5.0f,_ctx.resources), 0)

        // layout2 左: 供应量 中 最大供应量 右 隐私供应量
        val ly2: LinearLayout = LinearLayout(ctx)
        ly2.orientation = LinearLayout.HORIZONTAL
        ly2.layoutParams = layout_params

        val tv4 = TextView(ctx)
        tv4.text = "供应量"
        tv4.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv4.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv4.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
        tv4.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.LEFT)

        val tv5 = TextView(ctx)
        tv5.text = "最大供应量"
        tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv5.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv5.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
        tv5.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.CENTER)

        val tv6 = TextView(ctx)
        tv6.text = "隐私供应量"
        tv6.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv6.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv6.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv6.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.RIGHT)


        // layout3
        val ly3: LinearLayout = LinearLayout(ctx)
        ly3.orientation = LinearLayout.HORIZONTAL
        ly3.layoutParams = layout_params

        val tv7 = TextView(ctx)
        tv7.text = data.getString("supply")
        tv7.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv7.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv7.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
        tv7.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.LEFT)

        val tv8 = TextView(ctx)
        tv8.text = data.getString("max_supply")
        tv8.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv8.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv8.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
        tv8.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.CENTER)

        val tv9 = TextView(ctx)
        tv9.text = data.getString("privacy_supply")
        tv9.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv9.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv9.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv9.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.RIGHT)

        // layout4
        val ly4: LinearLayout = LinearLayout(ctx)
        ly4.orientation = LinearLayout.HORIZONTAL
        ly4.layoutParams = layout_params

        val tv10 = TextView(ctx)
        tv10.text = String.format("%s %s",data.getString("asset_quantity"), data.getString("asset_name"))
        tv10.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv10.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv10.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
        tv10.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.LEFT)


        // 线
        val lv_line = View(ctx)
        var layout_tv9 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(1.0f,_ctx.resources))
        layout_tv9.setMargins(0,Utils.toDp(10.0f,_ctx.resources),0,Utils.toDp(10.0f,_ctx.resources))
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_tv9

        ly1.addView(tv1)
        ly1.addView(tv2)

        ly2.addView(tv4)
        ly2.addView(tv5)
        ly2.addView(tv6)

        ly3.addView(tv7)
        ly3.addView(tv8)
        ly3.addView(tv9)

        ly4.addView(tv10)

        ly_wrap.addView(ly1)
        ly_wrap.addView(ly2)
        ly_wrap.addView(ly3)
        ly_wrap.addView(ly4)
        ly_wrap.addView(lv_line)

        this.addView(ly_wrap)

        return this
    }

    private fun createLayout(gr: Int): LinearLayout.LayoutParams {
        var layout = LinearLayout.LayoutParams(Utils.toDp(0f,_ctx.resources), Utils.toDp(24.0f,_ctx.resources))
        layout.weight = 1.0f
        layout.gravity = gr
        return layout
    }

}