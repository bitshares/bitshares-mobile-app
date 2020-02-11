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

class ViewOrderCell : LinearLayout {

    private var _ctx: Context
    private var _data: JSONObject
    private var _isSettlementsOrder: Boolean

    constructor(ctx: Context, data: JSONObject, isSettlementsOrder: Boolean) : super(ctx) {
        _ctx = ctx
        _data = data
        _isSettlementsOrder = isSettlementsOrder
        createUI()
    }

    private fun createUI(): LinearLayout {

        val ctx = _ctx
        val data = _data

        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(24f, _ctx.resources))
        layout_params.gravity = Gravity.CENTER_VERTICAL

        val ly_wrap = LinearLayout(ctx)
        ly_wrap.orientation = LinearLayout.VERTICAL

        // layout1 左: Buy SEED/CNY 右: 07-11 11:50
        val ly1 = LinearLayout(ctx)
        ly1.orientation = LinearLayout.HORIZONTAL
        ly1.layoutParams = layout_params
        ly1.setPadding(0, Utils.toDp(5.0f, _ctx.resources), 0, 0)
        val tv1 = TextView(ctx)
        if (data.getBoolean("issell")) {
            tv1.text = if (_isSettlementsOrder) ctx.resources.getString(R.string.kLabelTradeSettleTypeSell) else ctx.resources.getString(R.string.kBtnSell)
            if (data.optBoolean("iscall")) {
                tv1.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
            } else {
                tv1.setTextColor(resources.getColor(R.color.theme01_sellColor))
            }
        } else {
            tv1.text = if (_isSettlementsOrder) ctx.resources.getString(R.string.kLabelTradeSettleTypeBuy) else ctx.resources.getString(R.string.kBtnBuy)
            if (data.optBoolean("iscall")) {
                tv1.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
            } else {
                tv1.setTextColor(resources.getColor(R.color.theme01_buyColor))
            }
        }

        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv1.gravity = Gravity.CENTER_VERTICAL

        val tv2 = TextView(ctx)
        val quote_symbol = data.getString("quote_symbol")
        val base_symbol = data.getString("base_symbol")
        tv2.text = "${quote_symbol}/${base_symbol}"
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        tv2.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv2.gravity = Gravity.CENTER_VERTICAL


        tv2.setPadding(Utils.toDp(5.0f, _ctx.resources), 0, 0, 0)

        val tv3 = TextView(ctx)
        val time = if (_isSettlementsOrder) data.optString("time") else data.optString("block_time")
        if (time == "") {
            tv3.visibility = android.view.View.INVISIBLE
        } else {
            tv3.visibility = android.view.View.VISIBLE
            tv3.text = Utils.fmtAccountHistoryTimeShowString(time)
        }
        tv3.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10.0f)
        tv3.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv3.gravity = Gravity.BOTTOM or Gravity.RIGHT
        val layout_tv3 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_tv3.weight = 1.0f
        layout_tv3.gravity = Gravity.RIGHT or Gravity.BOTTOM
        tv3.layoutParams = layout_tv3


        // layout2 左: price(CNY) 中 Amount(SEED) 右 总金额(CNY)
        val ly2 = LinearLayout(ctx)
        ly2.orientation = LinearLayout.HORIZONTAL
        ly2.layoutParams = layout_params

        val tv4 = TextView(ctx)
        tv4.text = "${R.string.kLableBidPrice.xmlstring(ctx)}(${base_symbol})"
        tv4.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv4.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv4.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
        tv4.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.LEFT)

        val tv5 = TextView(ctx)
        tv5.text = "${R.string.kLabelTradeHisTitleAmount.xmlstring(ctx)}(${quote_symbol})"
        tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv5.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv5.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
        tv5.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.CENTER)

        val tv6 = TextView(ctx)
        tv6.text = "${R.string.kVcOrderTotal.xmlstring(ctx)}(${base_symbol})"
        tv6.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv6.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv6.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv6.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.RIGHT)


        // layout3
        val ly3 = LinearLayout(ctx)
        ly3.orientation = LinearLayout.HORIZONTAL
        ly3.layoutParams = layout_params

        val tv7 = TextView(ctx)
        tv7.text = data.getString("price")
        tv7.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv7.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv7.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
        tv7.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.LEFT)

        val tv8 = TextView(ctx)
        tv8.text = data.getString("amount")
        tv8.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv8.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv8.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
        tv8.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.CENTER)

        val tv9 = TextView(ctx)
        tv9.text = data.getString("total")
        tv9.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv9.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv9.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv9.layoutParams = createLayout(Gravity.CENTER_VERTICAL or Gravity.RIGHT)

        // 线
        val lv_line = View(ctx)
        val layout_tv9 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(1.0f, _ctx.resources))
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_tv9

        ly1.addView(tv1)
        ly1.addView(tv2)
        ly1.addView(tv3)

        ly2.addView(tv4)
        ly2.addView(tv5)
        ly2.addView(tv6)

        ly3.addView(tv7)
        ly3.addView(tv8)
        ly3.addView(tv9)


        ly_wrap.addView(ly1)
        ly_wrap.addView(ly2)
        ly_wrap.addView(ly3)
        ly_wrap.addView(lv_line)

        this.addView(ly_wrap)

        return this
    }

    private fun createLayout(gr: Int): LinearLayout.LayoutParams {
        val layout = LinearLayout.LayoutParams(Utils.toDp(0f, _ctx.resources), Utils.toDp(24.0f, _ctx.resources))
        layout.weight = 1.0f
        layout.gravity = gr
        return layout
    }

}