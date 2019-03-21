package com.btsplusplus.fowallet

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.util.Size
import android.util.SizeF
import bitshares.dp
import bitshares.forEach
import bitshares.kBTS_KLINE_PRICE_VOL_FONTSIZE
import com.btsplusplus.fowallet.kline.TradingPair
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ViewDeepGraph : ViewBase {

    companion object {

        //  深度图总共行数
        const val kBTS_KLINE_DEEP_GRAPH_ROW_N = 6

        //  深度图X轴高度
        const val kBTS_KLINE_DEEP_GRAPH_AXIS_X_HEIGHT = 20

    }

    var fCellTotalHeight: Float = 0f
    var fMainGraphOffset: Float = 0f
    var fMainGraphRowH: Float = 0f
    var fMainGraphHeight: Float = 0f

    var _limit_order_infos: JSONObject? = null

    lateinit var _tradingPair: TradingPair
    lateinit var _f10NumberSize: Size                    //  测量字体高度
    lateinit var _fontname: Typeface                     //  K线图各种数据字体
    var _fontsize: Float = 0.0f

    var _context: Context
    var m_canvas: Canvas = Canvas()
    var first_refresh: Boolean = true
    lateinit var _view_size: SizeF

    constructor(context: Context) : super(context) {
        _context = context
    }

    constructor(context: Context, width: Float, tradingPair: TradingPair) : super(context) {
        _context = context

        //  外部参数
        _tradingPair = tradingPair

        val height = Math.ceil(width / 2.0).toFloat()

        _view_size = SizeF(width, height)

        fMainGraphRowH = height / kBTS_KLINE_DEEP_GRAPH_ROW_N.toFloat()
        fMainGraphHeight = (kBTS_KLINE_DEEP_GRAPH_ROW_N - 1) * fMainGraphRowH
        fMainGraphOffset = height - fMainGraphHeight
        fCellTotalHeight = height + kBTS_KLINE_DEEP_GRAPH_AXIS_X_HEIGHT

        //  初始化默认字体
        _fontname = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
        _fontsize = kBTS_KLINE_PRICE_VOL_FONTSIZE.toFloat()

        //  REMARK：测量X轴、Y轴、MAX、MIN价格、VOL等字体高度用。
        _f10NumberSize = auxSizeWithText("0.123456789-:", _fontname, _fontsize)
    }

    constructor(context: Context, attrs: AttributeSet) : super(context) {
        _context = context
    }

    constructor(context: Context, attrs: AttributeSet, defStyle: Int) : super(context) {
        _context = context
    }

    override fun onDraw(canvas: Canvas) {
        m_canvas = canvas
        super.onDraw(m_canvas)
        if (_limit_order_infos == null) {
            return
        }

        val bid_array = _limit_order_infos!!.getJSONArray("bids")
        val ask_array = _limit_order_infos!!.getJSONArray("asks")
        assert(bid_array != null)
        assert(ask_array != null)

        drawCore(bid_array, ask_array)
    }

    /**
     *  描绘文字 (ios为返回 Layer)
     */
    private fun getTextPaintWithString(textColor: Int, fontname: Typeface, fontsize: Float): Paint {
        val paint = Paint()
        paint.isAntiAlias = true
        paint.textSize = fontsize
        paint.color = textColor
        paint.typeface = fontname
        return paint
    }

    /**
     *  (private) 描绘深度图边框和背景
     */
    private fun drawDeepGraph(points: MutableList<PointF>, color: Int, firstClose: Boolean) {
        //  1、描绘边框
        val path = Path()

        //  起始点封闭
        var firstPoint: PointF = points.first()
        if (firstClose) {
            path.moveTo(firstPoint.x, fMainGraphOffset + fMainGraphHeight)
            path.lineTo(firstPoint.x, firstPoint.y)
        } else {
            path.moveTo(firstPoint.x, firstPoint.y)
        }
        var p: PointF? = null
        for (idxY: Int in 1 until points.count() - 1) {
            p = points.get(idxY)
            path.lineTo(p.x, p.y)
        }

        //  结尾点封闭
        var lastPoint: PointF = points.last()
        if (!firstClose) {
            path.lineTo(lastPoint.x, fMainGraphOffset + fMainGraphHeight)
        }

        val paint = Paint()
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2.0f
        paint.flags = Paint.ANTI_ALIAS_FLAG
        paint.color = color
        paint.shader = null

        m_canvas.drawPath(path, paint)

        val maxOffsetY: Float = fMainGraphOffset + fMainGraphHeight

        val maskPath = path
        paint.style = Paint.Style.FILL
        paint.alpha = (255 * 0.1).toInt()
        paint.strokeWidth = 0f

        maskPath.lineTo(lastPoint.x, maxOffsetY)
        maskPath.lineTo(firstPoint.x, maxOffsetY)
        maskPath.lineTo(firstPoint.x, firstPoint.y)
        maskPath.close()

        m_canvas.drawPath(maskPath, paint)
    }

    /**
     *  描绘文字 (ios为返回 Layer)
     */
    fun getTextPaintWithString(text: String, textColor: Int, fontname: Typeface, fontsize: Float): Paint {
        val paint = Paint()
        paint.textSize = fontsize
        paint.color = textColor
        paint.textAlign = Paint.Align.CENTER
        paint.typeface = fontname

        return paint
    }

    private fun drawCore(bid_array: JSONArray, ask_array: JSONArray) {

        var bid_max_sum: Double = 0.0
        var ask_max_sum: Double = 0.0
        var bid_min_sum: Double = 0.0
        var ask_min_sum: Double = 0.0
        val bid_num: Int = bid_array.length()
        val ask_num: Int = ask_array.length()
        val total_num: Int = bid_num + ask_num

        //  数据不足
        if (bid_num <= 2 || ask_num <= 2) {
            val str = resources.getString(R.string.kLabelNODATA)
            val fontsize = 30f.dp
            val str_size = auxSizeWithText(str, _fontname, fontsize)
            val paint = getTextPaintWithString(resources.getColor(R.color.theme01_textColorGray), _fontname, fontsize)
            paint.textAlign = Paint.Align.CENTER
            m_canvas.drawText(str, _view_size.width / 2.0f, (_view_size.height - str_size.height) / 2.0f + str_size.height, paint)
            return
        }

        //    {
        //        base = 17442;
        //        price = "0.8721012601863211";
        //        quote = "19999.9711";
        //        sum = "88659.12796999999";
        //    }
        var bid_min_price: Double = 0.0
        var bid_max_price: Double = 0.0
        if (bid_num > 0) {
            bid_max_sum = bid_array.getJSONObject(bid_array.length() - 1).getDouble("sum")
            bid_min_sum = bid_array.getJSONObject(0).getDouble("sum")
            bid_min_price = bid_array.getJSONObject(bid_array.length() - 1).getDouble("price")
            bid_max_price = bid_array.getJSONObject(0).getDouble("price")
        }
        var ask_min_price: Double = 0.0
        var ask_max_price = 0.0
        if (ask_num > 0) {
            ask_max_sum = ask_array.getJSONObject(ask_array.length() - 1).getDouble("sum")
            ask_min_sum = ask_array.getJSONObject(0).getDouble("sum")
            ask_min_price = ask_array.getJSONObject(0).getDouble("price")
            ask_max_price = ask_array.getJSONObject(ask_array.length() - 1).getDouble("price")
        }
        val max_sum: Double = Math.max(bid_max_sum, ask_max_sum)
        val min_sum: Double = Math.min(bid_min_sum, ask_min_sum)
        val min_price: Double = Math.min(bid_min_price, ask_min_price)
        val max_price: Double = Math.max(bid_max_price, ask_max_price)

        val fWidth: Float = _view_size.width

        var buy_points: MutableList<PointF> = mutableListOf()
        var sell_points: MutableList<PointF> = mutableListOf()

        //  买单
        var i = bid_num - 1
        while (i >= 0) {
            val order = bid_array.getJSONObject(i)
            val x: Double = (fWidth * buy_points.count() / total_num).toDouble()
            val y: Double = fMainGraphOffset + fMainGraphHeight * (1.0f - order.getDouble("sum") / max_sum)
            buy_points.add(PointF(x.toFloat(), y.toFloat()))
            i--
        }

        //  卖单
        ask_array.forEach { order: JSONObject? ->
            val x: Double = (fWidth * (buy_points.count() + sell_points.count()) / total_num).toDouble()
            val y: Double = fMainGraphOffset + fMainGraphHeight * (1.0f - order!!.getDouble("sum") / max_sum)
            sell_points.add(PointF(x.toFloat(), y.toFloat()))
        }

        //  描绘Y轴（数量区间）
        var diff_sum = (max_sum - min_sum) / (kBTS_KLINE_DEEP_GRAPH_ROW_N - 1)
        for (i in 1 until kBTS_KLINE_DEEP_GRAPH_ROW_N) {
            val value: Double = min_sum + diff_sum * i

            val scale = _tradingPair._numPrecision
            val str_num = BigDecimal(value).setScale(scale, BigDecimal.ROUND_UP)
            val str = str_num.toString()
            val str_size = auxSizeWithText(str, _fontname, _fontsize)

            val offsetY: Float = fMainGraphOffset + fMainGraphHeight - fMainGraphRowH * i + str_size.height

            val paint = getTextPaintWithString(resources.getColor(R.color.theme01_textColorNormal), _fontname, _fontsize)
            paint.textAlign = Paint.Align.RIGHT
            m_canvas.drawText(str, _view_size.width - 4.0f.dp, offsetY, paint)
        }

        //  描绘X轴（价格区间）
        val diff_price: Double = (max_price - min_price) / 2
        for (i in 0 until 3) {
            val value: Double = min_price + diff_price * i
            val scale = _tradingPair._displayPrecision
            val str_num = BigDecimal(value).setScale(scale, BigDecimal.ROUND_UP)
            val str = str_num.toString()
            val str_size = auxSizeWithText(str, _fontname, _fontsize)

            val offsetY: Float = fMainGraphOffset + fMainGraphHeight + 4f.dp + str_size.height
            var offsetX: Float
            val paint = getTextPaintWithString(resources.getColor(R.color.theme01_textColorNormal), _fontname, _fontsize)
            if (i == 0) {
                offsetX = 4.0f.dp
                paint.textAlign = Paint.Align.LEFT
            } else if (i == 1) {
                offsetX = _view_size.width / 2.0f
                paint.textAlign = Paint.Align.CENTER
            } else {
                offsetX = _view_size.width - 4.0f.dp
                paint.textAlign = Paint.Align.RIGHT
            }

            m_canvas.drawText(str, offsetX, offsetY, paint)
        }

        //  描绘图形
        drawDeepGraph(buy_points, resources.getColor(R.color.theme01_buyColor), false)
        drawDeepGraph(sell_points, resources.getColor(R.color.theme01_sellColor), true)
    }

    fun refreshDeepGraph(limit_order_infos: JSONObject) {
        _limit_order_infos = limit_order_infos
        postInvalidate()
    }

}


