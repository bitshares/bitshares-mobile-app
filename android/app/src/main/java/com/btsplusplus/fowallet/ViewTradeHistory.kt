package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.TableLayout
import android.widget.TableRow
import android.widget.TextView
import bitshares.OrgUtils
import bitshares.Utils
import bitshares.jsonArrayfrom
import bitshares.xmlstring
import com.btsplusplus.fowallet.kline.TradingPair
import org.json.JSONArray


class ViewTradeHistory : TableLayout {

    private var _showRows: Int = 20
    lateinit var _tradingPair: TradingPair
    private var _label_arrays = mutableListOf<JSONArray>()

    constructor(context: Context) : super(context)

    fun initView(line_height: Float, rows: Int, tradingPair: TradingPair): ViewTradeHistory {
        _showRows = rows
        _tradingPair = tradingPair
        _label_arrays.clear()

        val line_height = line_height

        val width = Utils.screen_width
        var height: Float = line_height * (_showRows + 1)

        val ctx = this.context

        val res = this.context.resources

        // Todo remove
        height = line_height * (_showRows + 1)

        val layout_view_height = Utils.toDp(line_height, res)

        // 表格
        val this_params = TableLayout.LayoutParams(TableLayout.LayoutParams.MATCH_PARENT, Utils.toDp(height + 20f, res))
        this.setPadding(Utils.toDp(10f, res), Utils.toDp(10f, res), Utils.toDp(10f, res), Utils.toDp(10f, res))
        this.setColumnShrinkable(2, true)
        this.setColumnShrinkable(3, true)
        this.layoutParams = this_params
        this.isStretchAllColumns = true

        val table_row = TableRow(this.context)
        val table_row_params = TableRow.LayoutParams(TableRow.LayoutParams.MATCH_PARENT, Utils.toDp(line_height, res))
        table_row.orientation = TableRow.HORIZONTAL
        table_row.layoutParams = table_row_params

        val base_symbol = _tradingPair._baseAsset.getString("symbol")
        val quote_symbol = _tradingPair._quoteAsset.getString("symbol")

        val tv1 = ViewUtils.createTextViewForOrderBook(ctx, R.string.kLabelTradeHisTitleTime.xmlstring(ctx), Gravity.LEFT, R.color.theme01_textColorGray, 25f, layout_view_height)
        val tv2 = ViewUtils.createTextViewForOrderBook(ctx, R.string.kLabelTradeHisTitleType.xmlstring(ctx), Gravity.LEFT, R.color.theme01_textColorGray, 15f, layout_view_height)
        val tv3 = ViewUtils.createTextViewForOrderBook(ctx, "${R.string.kLabelTradeHisTitlePrice.xmlstring(ctx)}($base_symbol)", Gravity.RIGHT, R.color.theme01_textColorGray, 30f, layout_view_height)
        val tv4 = ViewUtils.createTextViewForOrderBook(ctx, "${R.string.kLabelTradeHisTitleAmount.xmlstring(ctx)}($quote_symbol)", Gravity.RIGHT, R.color.theme01_textColorGray, 30f, layout_view_height)

        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11f)
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11f)
        tv3.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11f)
        tv4.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11f)

        table_row.addView(tv1)
        table_row.addView(tv2)
        table_row.addView(tv3)
        table_row.addView(tv4)

        this.addView(table_row)

        for (i in 0 until _showRows) {

            val table_row = TableRow(ctx)
            val table_row_params = TableRow.LayoutParams(TableRow.LayoutParams.MATCH_PARENT, Utils.toDp(line_height, res))
            table_row.orientation = TableRow.HORIZONTAL
            table_row.layoutParams = table_row_params

            val tv1 = ViewUtils.createTextViewForOrderBook(ctx, "--", Gravity.LEFT, R.color.theme01_textColorMain, 25f, layout_view_height)

            val color = R.color.theme01_buyColor
            val tv2 = ViewUtils.createTextViewForOrderBook(ctx, "--", Gravity.LEFT, color, 15f, layout_view_height)

            val tv3 = ViewUtils.createTextViewForOrderBook(ctx, "--", Gravity.RIGHT, R.color.theme01_textColorMain, 30f, layout_view_height)
            val tv4 = ViewUtils.createTextViewForOrderBook(ctx, "--", Gravity.RIGHT, R.color.theme01_textColorMain, 30f, layout_view_height)

            table_row.addView(tv1)
            table_row.addView(tv2)
            table_row.addView(tv3)
            table_row.addView(tv4)

            this.addView(table_row)

            //  保存到容器
            _label_arrays.add(jsonArrayfrom(table_row, tv1, tv2, tv3, tv4))
        }

        return this
    }

    fun refreshWithData(ctx: Context, data_array: JSONArray) {
        val size = data_array.length()
        _label_arrays.forEachIndexed { index, jsonArray ->
            if (index < size) {
                (jsonArray.get(0) as TableRow).visibility = View.VISIBLE
                val data = data_array.getJSONObject(index)
                //  时间、方向、价格、数量。
                (jsonArray.get(1) as TextView).text = Utils.fmtTradeHistoryTimeShowString(ctx, data.getString("time"))
                val dir_label = jsonArray.get(2) as TextView
                if (data.getBoolean("issell")) {
                    dir_label.text = ctx.resources.getString(R.string.kBtnSell)
                    dir_label.setTextColor(resources.getColor(R.color.theme01_sellColor))
                } else {
                    dir_label.text = ctx.resources.getString(R.string.kBtnBuy)
                    dir_label.setTextColor(resources.getColor(R.color.theme01_buyColor))
                }
                if (data.getBoolean("iscall")) {
                    dir_label.setTextColor(resources.getColor(R.color.theme01_callOrderColor))
                }
                (jsonArray.get(3) as TextView).text = OrgUtils.formatFloatValue(data.getString("price").toDouble(), _tradingPair._displayPrecision)
                (jsonArray.get(4) as TextView).text = OrgUtils.formatFloatValue(data.getString("amount").toDouble(), _tradingPair._numPrecision)
            } else {
                (jsonArray.get(0) as TableRow).visibility = View.GONE
            }
        }
    }
}