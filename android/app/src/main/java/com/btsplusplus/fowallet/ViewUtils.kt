package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TableRow
import android.widget.TextView
import bitshares.AppCacheManager
import bitshares.Utils
import bitshares.dp
import bitshares.xmlstring
import org.json.JSONObject
import kotlin.math.max


class ViewUtils {
    companion object {

        /**
         *  辅助 - 创建账号搜索框结果CELL视图
         */
        fun auxGenSearchAccountLineView(ctx: BtsppActivity, name: String, oid: String, raw_data: Any, click_callback: ((data: Any) -> Unit)? = null): LinearLayout {
            val v = LinearLayout(ctx)
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 34.dp)
            layout_params.gravity = Gravity.CENTER_VERTICAL

            v.layoutParams = layout_params

            val tv = TextView(ctx)
            tv.text = name
            tv.gravity = Gravity.CENTER_VERTICAL
            tv.setTextColor(ctx.resources!!.getColor(R.color.theme01_textColorMain))

            val tv2 = TextView(ctx)
            tv2.text = "#$oid"
            tv2.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
            tv2.setTextColor(ctx.resources!!.getColor(R.color.theme01_textColorNormal))

            val layout_params2 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 34.dp)
            layout_params2.weight = 1.0f
            tv2.layoutParams = layout_params2

            v.addView(tv)
            v.addView(tv2)

            //  事件 - 点击搜索结果
            if (click_callback != null) {
                v.setOnClickListener { click_callback(raw_data) }
            }

            return v
        }

        /**
         * 创建垂直/水平居中的空描述Label。
         */
        fun createEmptyCenterLabel(ctx: Context, message: String, text_color: Int = ctx.resources.getColor(R.color.theme01_textColorMain)): TextView {
            val _lbEmptyOrder = TextView(ctx)
            val _lbEmptyOrder_layout_params = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
            _lbEmptyOrder_layout_params.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
            _lbEmptyOrder.text = message
            _lbEmptyOrder.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f)
            _lbEmptyOrder.setTextColor(text_color)
            _lbEmptyOrder.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
            _lbEmptyOrder.layoutParams = _lbEmptyOrder_layout_params
            return _lbEmptyOrder
        }

        fun createLine(ctx: Context): View {
            // 线
            val line = View(ctx)
            val layout_tv9 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1.dp)
            line.setBackgroundColor(ctx.resources.getColor(R.color.theme01_bottomLineColor))
            line.layoutParams = layout_tv9
            return line
        }

        fun createTextView(ctx: Context, text: String, font_size: Float, color: Int, bold: Boolean): TextView {
            val text_view = TextView(ctx)
            text_view.setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
            text_view.setTextColor(ctx.resources.getColor(color))
            text_view.text = text

            val paint = text_view.paint
            paint.isFakeBoldText = bold

            return text_view
        }

        fun createLinearLayout(ctx: Context, layout_width: Int, layout_height: Int, weight: Float?, gravity: Int?, orientation: Int?, topMargin: Int? = null): LinearLayout {
            val layout = LinearLayout(ctx)
            val layout_params = LinearLayout.LayoutParams(layout_width, layout_height)
            if (weight != null) {
                layout_params.weight = weight
            }
            if (gravity != null) {
                layout_params.gravity = gravity
            }
            if (orientation != null) {
                layout.orientation = orientation
            }
            if (topMargin != null) {
                layout_params.topMargin = topMargin.dp
            }
            layout.layoutParams = layout_params
            return layout
        }

        private fun createLinearLayoutParams(ctx: Context, layout_width: Float, layout_height: Float, weight: Float, gravity: Int): LinearLayout.LayoutParams {
            val res = ctx.resources
            val params = LinearLayout.LayoutParams(Utils.toDp(layout_width, res), Utils.toDp(layout_height, res), weight)
            params.gravity = gravity
            return params
        }


        private fun createLayoutParamsForOrderBookTextView(ctx: Context, weight: Float, layout_height: Int): LinearLayout.LayoutParams {
            val layout_params = TableRow.LayoutParams(0, layout_height)
            layout_params.weight = weight
            layout_params.gravity = Gravity.CENTER_VERTICAL
            return layout_params
        }

        fun createTextViewForOrderBook(ctx: Context, text: String, align: Int, color: Int, weight: Float, layout_height: Int): TextView {
            val tv = createTextView(ctx, text, 11f, color, false)
            tv.gravity = align or Gravity.CENTER_VERTICAL
            tv.layoutParams = createLayoutParamsForOrderBookTextView(ctx, weight, layout_height)
            return tv
        }

        /**
         * 交易内容描述信息CELL
         */
        fun createProposalOpInfoCell(ctx: Context, data: JSONObject, useBuyColorForTitle: Boolean, nameFontSize: Float? = null): LinearLayout {
            val _layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            _layout_params.gravity = Gravity.RIGHT
            _layout_params.topMargin = 4.dp
            val _layout = LinearLayout(ctx)
            _layout.layoutParams = _layout_params
            _layout.orientation = LinearLayout.VERTICAL

            //  name
            val name_font_size = nameFontSize ?: 11.0f
            val tv1 = TextView(ctx)
            tv1.text = data.getString("name")
            tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, name_font_size)
            if (nameFontSize == null) {
                tv1.paint.isFakeBoldText = true
            }
            if (useBuyColorForTitle) {
                tv1.setTextColor(ctx.resources.getColor(R.color.theme01_buyColor))
            } else {
                tv1.setTextColor(ctx.resources.getColor(data.getInt("color")))
            }

            //  desc
            val desc_font_size = max(name_font_size - 2.0f, 11.0f)
            val tv2 = TextView(ctx)
            tv2.text = data.getString("desc")
            tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, desc_font_size)
            tv2.setTextColor(ctx.resources.getColor(R.color.theme01_textColorNormal))
            tv2.setPadding(0, 10, 0, 0)

            _layout.addView(tv1)
            _layout.addView(tv2)

            return _layout
        }

        fun createCellForOrder(ctx: Context, layout_params: LinearLayout.LayoutParams, ly: LinearLayout, data: JSONObject, toast_fun: (JSONObject) -> Unit) {


            val ly_wrap: LinearLayout = LinearLayout(ctx)
            ly_wrap.orientation = LinearLayout.VERTICAL

            val resources = ctx.resources

            // layout1 左: Buy SEED/CNY 右: 07-11 11:50
            val ly1 = LinearLayout(ctx)
            ly1.orientation = LinearLayout.HORIZONTAL
            ly1.layoutParams = layout_params
            ly1.setPadding(0, Utils.toDp(5.0f, resources), 0, 0)

            val tv1 = TextView(ctx)
            if (data.getBoolean("issell")) {
                tv1.text = ctx.resources.getString(R.string.kBtnSell)
                tv1.setTextColor(resources.getColor(R.color.theme01_sellColor))
            } else {
                tv1.text = ctx.resources.getString(R.string.kBtnBuy)
                tv1.setTextColor(resources.getColor(R.color.theme01_buyColor))
            }
            tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            tv1.gravity = Gravity.CENTER_VERTICAL

            val tv2 = TextView(ctx)
            val quote_symbol = data.getString("quote_symbol")
            val base_symbol = data.getString("base_symbol")
            tv2.text = "${quote_symbol}/${base_symbol}"
            tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            tv2.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            tv2.gravity = Gravity.CENTER_VERTICAL
            tv2.setPadding(Utils.toDp(5.0f, resources), 0, 0, 0)

            val layout_of_left = LinearLayout(ctx)
            layout_of_left.layoutParams = LinearLayout.LayoutParams(Utils.toDp(0f, resources), LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            layout_of_left.addView(tv1)
            layout_of_left.addView(tv2)
            layout_of_left.gravity = Gravity.CENTER_VERTICAL

            val time = Utils.fmtLimitOrderTimeShowString(data.getString("time"))
            val tv3 = TextView(ctx)
            tv3.text = String.format(R.string.kVcOrderExpired.xmlstring(ctx), time)
            tv3.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
            tv3.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tv3.gravity = Gravity.CENTER
            val layout_tv3 = LinearLayout.LayoutParams(Utils.toDp(0f, resources), LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            layout_tv3.gravity = Gravity.CENTER_VERTICAL
            tv3.layoutParams = layout_tv3

            val tv_cancel = ViewUtils.createTextView(ctx, ctx.resources.getString(R.string.kVcOrderBtnCancel), 11.0f, R.color.theme01_color03, false)
            tv_cancel.gravity = Gravity.RIGHT
            val layout_cancel = LinearLayout.LayoutParams(Utils.toDp(0f, resources), LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            layout_cancel.gravity = Gravity.CENTER_VERTICAL
            tv_cancel.layoutParams = layout_cancel

            // layout2 左: price(CNY) 中 Amount(SEED) 右 总金额(CNY)
            val ly2: LinearLayout = LinearLayout(ctx)
            ly2.orientation = LinearLayout.HORIZONTAL
            ly2.layoutParams = layout_params

            val tv4 = TextView(ctx)
            tv4.text = "${R.string.kLableBidPrice.xmlstring(ctx)}(${base_symbol})"
            tv4.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
            tv4.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tv4.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
            tv4.layoutParams = createLinearLayoutParams(ctx, 0f, 24f, 1.0f, Gravity.CENTER_VERTICAL or Gravity.LEFT)

            val tv5 = TextView(ctx)
            tv5.text = "${R.string.kLableBidAmount.xmlstring(ctx)}(${quote_symbol})"
            tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
            tv5.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tv5.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
            tv5.layoutParams = createLinearLayoutParams(ctx, 0f, 24f, 1.0f, Gravity.CENTER_VERTICAL or Gravity.CENTER)

            val tv6 = TextView(ctx)
            tv6.text = "${ctx.resources.getString(R.string.kVcOrderTotal)}(${base_symbol})"
            tv6.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
            tv6.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tv6.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
            tv6.layoutParams = createLinearLayoutParams(ctx, 0f, 24f, 1.0f, Gravity.CENTER_VERTICAL or Gravity.RIGHT)

            // layout3
            val ly3: LinearLayout = LinearLayout(ctx)
            ly3.orientation = LinearLayout.HORIZONTAL
            ly3.layoutParams = layout_params

            val tv7 = TextView(ctx)
            tv7.text = data.getString("price")
            tv7.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
            tv7.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            tv7.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
            tv7.layoutParams = createLinearLayoutParams(ctx, 0f, 24f, 1.0f, Gravity.CENTER_VERTICAL or Gravity.LEFT)

            val tv8 = TextView(ctx)
            tv8.text = data.getString("amount")
            tv8.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
            tv8.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            tv8.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
            tv8.layoutParams = createLinearLayoutParams(ctx, 0f, 24f, 1.0f, Gravity.CENTER_VERTICAL or Gravity.CENTER)

            val tv9 = TextView(ctx)
            tv9.text = data.getString("total")
            tv9.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
            tv9.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            tv9.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
            tv9.layoutParams = createLinearLayoutParams(ctx, 0f, 24f, 1.0f, Gravity.CENTER_VERTICAL or Gravity.RIGHT)

            // 线
            val lv_line = View(ctx)
            val layout_tv9 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, Utils.toDp(1.0f, resources))
            lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
            lv_line.layoutParams = layout_tv9

            ly1.addView(layout_of_left)
            ly1.addView(tv3)
            ly1.addView(tv_cancel)

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

            ly.addView(ly_wrap)

            // 设置当前订单号到按钮上
            tv_cancel.tag = data.getString("id")
            tv_cancel.setOnClickListener { v: View ->
                toast_fun.invoke(data)
            }
        }

        /**
         *  (public) 根据隐私账户地址获取隐私账户显示名称。
         */
        fun genBlindAccountDisplayName(ctx: Context, blind_account_public_key: String): String? {
            val pAppCache = AppCacheManager.sharedAppCacheManager()
            val blind_account = pAppCache.queryBlindAccount(blind_account_public_key)
            if (blind_account == null) {
                //  获取账号失败
                return null
            }
            val parent_key = blind_account.optString("parent_key")
            if (parent_key.isNotEmpty()) {
                //  子账号（获取父账号）
                val parent_blind_account = pAppCache.queryBlindAccount(parent_key)!!
                var alias_name = parent_blind_account.optString("alias_name")
                val child_idx = blind_account.getInt("child_key_index") + 1
                alias_name = when (child_idx) {
                    1 -> String.format(R.string.kVcStCellSubAccount1st.xmlstring(ctx), alias_name)
                    2 -> String.format(R.string.kVcStCellSubAccount2nd.xmlstring(ctx), alias_name, child_idx.toString())
                    3 -> String.format(R.string.kVcStCellSubAccount3rd.xmlstring(ctx), alias_name, child_idx.toString())
                    else -> String.format(R.string.kVcStCellSubAccountnth.xmlstring(ctx), alias_name, child_idx.toString())
                }
                return alias_name
            } else {
                //  主账号
                return blind_account.optString("alias_name")
            }
        }
    }
}