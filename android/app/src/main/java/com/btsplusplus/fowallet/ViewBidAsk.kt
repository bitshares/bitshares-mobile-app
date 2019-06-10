package com.btsplusplus.fowallet

import android.content.Context
import android.view.Gravity
import android.view.View
import android.widget.*
import bitshares.OrgUtils
import bitshares.Utils
import com.btsplusplus.fowallet.kline.TradingPair
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class ViewBidAsk : FrameLayout {

    private var _showRows: Int = 20
    private var _label_arrays = mutableListOf<Array<TextView>>()
    lateinit var _tradingPair: TradingPair
    private var _line_height: Float = 0.0f

    constructor(context: Context) : super(context)

    fun initView(line_height: Float, rows: Int, tradingPair: TradingPair): ViewBidAsk {
        _showRows = rows
        _label_arrays.clear()
        _tradingPair = tradingPair

        val ctx = this.context
        val res = ctx.resources

        _line_height = line_height

        val height = _line_height * (_showRows + 2f)

        val layout_view_height = Utils.toDp(_line_height, res)

        // 外层 layout_params
        val wrap_layout_params = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, Utils.toDp(height, res))

        // 外层 layout
        this.layoutParams = wrap_layout_params


        // 背景色块
        val color_block_layout = LinearLayout(ctx)
        color_block_layout.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        color_block_layout.orientation = LinearLayout.VERTICAL

        //  表格
        val table_layout = TableLayout(ctx)
        val table_layout_params = TableLayout.LayoutParams(TableLayout.LayoutParams.MATCH_PARENT, TableLayout.LayoutParams.WRAP_CONTENT)
        table_layout.setPadding(Utils.toDp(10f, res), Utils.toDp(10f, res), Utils.toDp(10f, res), Utils.toDp(10f, res))
        table_layout.setColumnShrinkable(2, true)
        table_layout.setColumnShrinkable(3, true)
        table_layout.layoutParams = table_layout_params
        table_layout.isStretchAllColumns = true

        val table_row = TableRow(ctx)
        val table_row_params = TableRow.LayoutParams(TableRow.LayoutParams.MATCH_PARENT, Utils.toDp(line_height, res))
        table_row_params.gravity = Gravity.CENTER_VERTICAL
        table_row.orientation = TableRow.HORIZONTAL
        table_row.layoutParams = table_row_params
        table_row.gravity = Gravity.CENTER_VERTICAL

        val tv1 = ViewUtils.createTextViewForOrderBook(ctx, ctx.resources.getString(R.string.kLableBidBuy), Gravity.LEFT, R.color.theme01_textColorGray, 2f, layout_view_height)
        val tv2 = ViewUtils.createTextViewForOrderBook(ctx, ctx.resources.getString(R.string.kLableBidAmount), Gravity.LEFT, R.color.theme01_textColorGray, 6f, layout_view_height)
        val tv3 = ViewUtils.createTextViewForOrderBook(ctx, ctx.resources.getString(R.string.kLableBidPrice), Gravity.RIGHT, R.color.theme01_textColorGray, 6f, layout_view_height)
        val tv4 = ViewUtils.createTextViewForOrderBook(ctx, ctx.resources.getString(R.string.kLableBidPrice), Gravity.LEFT, R.color.theme01_textColorGray, 6f, layout_view_height)
        val tv5 = ViewUtils.createTextViewForOrderBook(ctx, ctx.resources.getString(R.string.kLableBidAmount), Gravity.RIGHT, R.color.theme01_textColorGray, 6f, layout_view_height)
        val tv6 = ViewUtils.createTextViewForOrderBook(ctx, ctx.resources.getString(R.string.kLableAskSell), Gravity.RIGHT, R.color.theme01_textColorGray, 2f, layout_view_height)

        tv3.setPadding(0, 0, Utils.toDp(5f, res), 0)
        tv4.setPadding(Utils.toDp(5f, res), 0, 0, 0)

        table_row.addView(tv1)
        table_row.addView(tv2)
        table_row.addView(tv3)
        table_row.addView(tv4)
        table_row.addView(tv5)
        table_row.addView(tv6)

        table_layout.addView(table_row)

        for (i in 0 until _showRows) {

            val table_row = TableRow(ctx)
            val table_row_params = TableRow.LayoutParams(TableRow.LayoutParams.MATCH_PARENT, Utils.toDp(80f, res))
            table_row_params.gravity = Gravity.CENTER_VERTICAL
            table_row.orientation = TableRow.HORIZONTAL
            table_row.layoutParams = table_row_params
            table_row.gravity = Gravity.CENTER_VERTICAL

            val idnum = (1 + i).toString()
            val tv1 = ViewUtils.createTextViewForOrderBook(ctx, idnum, Gravity.LEFT, R.color.theme01_textColorNormal, 2f, layout_view_height)
            val tv2 = ViewUtils.createTextViewForOrderBook(ctx, "--", Gravity.LEFT, R.color.theme01_textColorNormal, 6f, layout_view_height)
            val tv3 = ViewUtils.createTextViewForOrderBook(ctx, "--", Gravity.RIGHT, R.color.theme01_buyColor, 6f, layout_view_height)
            val tv4 = ViewUtils.createTextViewForOrderBook(ctx, "--", Gravity.LEFT, R.color.theme01_sellColor, 6f, layout_view_height)
            val tv5 = ViewUtils.createTextViewForOrderBook(ctx, "--", Gravity.RIGHT, R.color.theme01_textColorNormal, 6f, layout_view_height)
            val tv6 = ViewUtils.createTextViewForOrderBook(ctx, idnum, Gravity.RIGHT, R.color.theme01_textColorNormal, 2f, layout_view_height)

            tv3.setPadding(0, 0, Utils.toDp(5f, res), 0)
            tv4.setPadding(Utils.toDp(5f, res), 0, 0, 0)

            table_row.addView(tv1)
            table_row.addView(tv2)
            table_row.addView(tv3)
            table_row.addView(tv4)
            table_row.addView(tv5)
            table_row.addView(tv6)

            table_layout.addView(table_row)

            //  绘制行
            val wrap_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, layout_view_height)

            if (i == 0) {
                // REMARK 1.5 倍为何超过了
                wrap_params.setMargins(0, Utils.toDp(line_height + 10f, res), 0, 0)
            }

            val wrap = LinearLayout(ctx)
            wrap.layoutParams = wrap_params
            wrap.orientation = LinearLayout.HORIZONTAL

            //  绘制左右2个layout容器
            val left_layout_params = LinearLayout.LayoutParams(0, layout_view_height, 1.0f)
            val left_layout = LinearLayout(ctx)
            left_layout.layoutParams = left_layout_params
            left_layout.gravity = Gravity.RIGHT

            val right_layout_params = LinearLayout.LayoutParams(0, layout_view_height, 1.0f)
            val right_layout = LinearLayout(ctx)
            right_layout.layoutParams = right_layout_params
            right_layout.gravity = Gravity.LEFT

            //  绘制买卖背景深度信息
            val buy_block_layout_params = LinearLayout.LayoutParams(Utils.toDp(5f * i, res), layout_view_height)
            val buy_block_layout = TextView(ctx)
            buy_block_layout.setBackgroundColor(res.getColor(R.color.theme01_buyColor2))
            buy_block_layout.layoutParams = buy_block_layout_params
            buy_block_layout.visibility = View.GONE

            val sell_block_layout_params = LinearLayout.LayoutParams(Utils.toDp(5f * i, res), layout_view_height)
            val sell_block_layout = TextView(ctx)
            sell_block_layout.setBackgroundColor(res.getColor(R.color.theme01_sellColor2))
            sell_block_layout.layoutParams = sell_block_layout_params
            sell_block_layout.visibility = View.GONE

            left_layout.addView(buy_block_layout)
            right_layout.addView(sell_block_layout)

            wrap.addView(left_layout)
            wrap.addView(right_layout)

            color_block_layout.addView(wrap)

            //  保存到容器
            _label_arrays.add(arrayOf(tv1, tv2, tv3, tv4, tv5, tv6, buy_block_layout, sell_block_layout))
        }

        this.addView(color_block_layout)
        this.addView(table_layout)

        return this
    }

    /**
     * 刷新
     */
    fun refreshWithData(data: JSONObject) {
        val bids = data.getJSONArray("bids")
        val bids_size = bids.length()

        val asks = data.getJSONArray("asks")
        val asks_size = asks.length()

        val half_width = (Utils.screen_width / 2).toInt()

        //  REMARK：这个最大值只取前5行的最大值，即使数据有20行甚至更多。
        var _bid_max_sum = 0.0
        var _ask_max_sum = 0.0
        var rowdata = bids.optJSONObject(_label_arrays.size - 1)
        if (rowdata != null) {
            _bid_max_sum = rowdata.getDouble("sum")
        }
        rowdata = asks.optJSONObject(_label_arrays.size - 1)
        if (rowdata != null) {
            _ask_max_sum = rowdata.getDouble("sum")
        }
        val max_sum = max(max(_bid_max_sum, _ask_max_sum), 0.1)

        val res = this.context.resources
        val layout_view_height = Utils.toDp(_line_height, res)
        _label_arrays.forEachIndexed { index, jsonArray ->
            //  买
            if (index < bids_size) {
                val order = bids.getJSONObject(index)
                if (order.optBoolean("iscall")) {
                    jsonArray[0].setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                    jsonArray[1].setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                    jsonArray[2].setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                } else {
                    jsonArray[0].setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    jsonArray[1].setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    jsonArray[2].setTextColor(resources.getColor(R.color.theme01_buyColor))
                }
                jsonArray[1].text = OrgUtils.formatFloatValue(order.getString("quote").toDouble(), _tradingPair._numPrecision, false)
                jsonArray[2].text = OrgUtils.formatFloatValue(order.getString("price").toDouble(), _tradingPair._displayPrecision, false)
                //  买盘 背景
                jsonArray[6].visibility = View.VISIBLE
                val layout_params = LinearLayout.LayoutParams(max(min(order.getDouble("sum") * half_width / max_sum, half_width.toDouble()), 1.0).roundToInt(), layout_view_height)
                jsonArray[6].layoutParams = layout_params
            } else {
                jsonArray[1].text = "--"
                jsonArray[2].text = "--"
                jsonArray[6].visibility = View.GONE
            }
            //  卖
            if (index < asks_size) {
                val order = asks.getJSONObject(index)
                if (order.optBoolean("iscall")) {
                    jsonArray[3].setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                    jsonArray[4].setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                    jsonArray[5].setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                } else {
                    jsonArray[3].setTextColor(resources.getColor(R.color.theme01_sellColor))
                    jsonArray[4].setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    jsonArray[5].setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                }
                jsonArray[4].text = OrgUtils.formatFloatValue(order.getString("quote").toDouble(), _tradingPair._numPrecision, false)
                jsonArray[3].text = OrgUtils.formatFloatValue(order.getString("price").toDouble(), _tradingPair._displayPrecision, false)
                //  卖盘背景
                jsonArray[7].visibility = View.VISIBLE
                val layout_params = LinearLayout.LayoutParams(max(min(order.getDouble("sum") * half_width / max_sum, half_width.toDouble()), 1.0).roundToInt(), layout_view_height)
                jsonArray[7].layoutParams = layout_params
            } else {
                jsonArray[4].text = "--"
                jsonArray[3].text = "--"
                jsonArray[7].visibility = View.GONE
            }
        }
    }

}