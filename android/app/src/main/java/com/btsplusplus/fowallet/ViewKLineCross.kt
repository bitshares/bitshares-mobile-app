package com.btsplusplus.fowallet

import android.content.Context
import android.graphics.*
import android.util.Size
import android.util.SizeF
import android.view.MotionEvent
import bitshares.*
import com.btsplusplus.fowallet.kline.MKlineItemData
import com.btsplusplus.fowallet.kline.TradingPair
import java.math.BigDecimal
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.round


/**
 * K线十字叉
 */
class ViewKLineCross : ViewBase {

    private var _first_init_draw: Boolean = true         //  首次初始化不描绘
    private var _tradingPair: TradingPair
    private var _currModel: MKlineItemData? = null
    var _kline: ViewKLine? = null
    private var _view_size: SizeF = SizeF(0f, 0f)
    private var _fontname: Typeface
    private var _fontsize: Float = 1.0f
    private var _ctx: Context


    /**
     *  描绘文字 (ios为返回 Layer)
     */
    private fun getTextPaintWithString(text: String, textColor: Int, fontname: Typeface, fontsize: Float): Paint {
        val paint = Paint()
        paint.isAntiAlias = true
        paint.textSize = fontsize
        paint.color = textColor
        paint.textAlign = Paint.Align.CENTER
        paint.typeface = fontname

        return paint
    }

    /**
     * 请求描绘十字叉
     */
    fun postDrawCrossLayer(model: MKlineItemData?) {
        _first_init_draw = false
        _currModel = model
        postInvalidate()
    }

    /**
     * 仅描绘MA
     */
    fun postDraw() {
        _first_init_draw = false
        _currModel = null
        postInvalidate()
    }

    /**
     *  (private) 描绘十字叉
     */
    private fun drawCrossLayer(canvas: Canvas, model: MKlineItemData) {

        //  描绘MA指标
        val currCandleWidth = _kline!!._currCandleWidth

        val spaceW: Float = (currCandleWidth * 2 + kBTS_KLINE_SHADOW_WIDTH + kBTS_KLINE_INTERVAL).toFloat()
        val path = Path()

        //  1、竖线
        val point = PointF()
        path.moveTo(model.showIndex * spaceW + currCandleWidth, 0.0f)
        path.lineTo(model.showIndex * spaceW + currCandleWidth, _view_size.height)

        //  2、横线
        var yOffsetHor: Float
        if (model.isRise) {
            yOffsetHor = _kline!!.fMainMAHeight + floor(model.fOffsetClose)
        } else {
            yOffsetHor = _kline!!.fMainMAHeight + ceil(model.fOffsetClose)
        }
        path.moveTo(0.0f, yOffsetHor)
        path.lineTo(_view_size.width, yOffsetHor)

        val paint = Paint()
        paint.strokeWidth = 1.0f.dp
        paint.style = Paint.Style.STROKE
        paint.color = resources.getColor(R.color.theme01_textColorMain)
        canvas.drawPath(path, paint)

        //  分时图和蜡烛图十字叉详情显示不同数据。
        val date_str: String = _kline!!.formatDateString(model.date)
        val value_ary: Array<String>?
        val title_ary: Array<String>?

        if (_kline!!.isDrawTimeLine()) {
            value_ary = arrayOf(date_str,
                    model.nPriceClose!!.toPlainString(),
                    model.n24Vol!!.toPlainString(),
                    model.n24TotalAmount!!.toPlainString(),
                    if (model.nAvgPrice != null) model.nAvgPrice!!.toPlainString() else "--"
            )
            title_ary = arrayOf(
                    R.string.kLabelKLineDate.xmlstring(_ctx),
                    R.string.kLabelKLinePrice.xmlstring(_ctx),
                    R.string.kLabelKLineVol.xmlstring(_ctx),
                    R.string.kLabelKLineTotalAmount.xmlstring(_ctx),
                    R.string.kLabelKLineAvgPrice.xmlstring(_ctx)
            )

        } else {
            value_ary = arrayOf(
                    date_str,
                    model.nPriceOpen!!.toPlainString(),
                    model.nPriceHigh!!.toPlainString(),
                    model.nPriceLow!!.toPlainString(),
                    model.nPriceClose!!.toPlainString(),
                    model.change!!.toPlainString(),
                    model.change_percent!!.toPriceAmountString(),
                    model.n24Vol!!.toPlainString(),
                    model.n24TotalAmount!!.toPlainString(),
                    if (model.nAvgPrice != null) model.nAvgPrice!!.toPlainString() else "--"
            )
            title_ary = arrayOf(
                    R.string.kLabelKLineDate.xmlstring(_ctx),
                    R.string.kLabelKLineOpen.xmlstring(_ctx),
                    R.string.kLabelKLineHigh.xmlstring(_ctx),
                    R.string.kLabelKLineLow.xmlstring(_ctx),
                    R.string.kLabelKLineClose.xmlstring(_ctx),
                    R.string.kLabelKLineChange.xmlstring(_ctx),
                    R.string.kLabelKLineChangePercent.xmlstring(_ctx),
                    R.string.kLabelKLineVol.xmlstring(_ctx),
                    R.string.kLabelKLineTotalAmount.xmlstring(_ctx),
                    R.string.kLabelKLineAvgPrice.xmlstring(_ctx)
            )
        }

        //  3、描绘详情
        val fDetailX: Float
        val fDetailY: Float
        val fDetailLineHeight: Float = 14.0f.dp
        val fDetailWidth: Float = 112.0f.dp
        val fDetailLineNumber: Float = title_ary.size.toFloat()
        val fDetailHeight: Float = fDetailLineHeight * fDetailLineNumber + 4.dp

        if (model.showIndex >= _kline!!._maxShowNumber / 2) {
            //  十字叉详情：靠左边显示
            fDetailX = 4.0f.dp
            fDetailY = _kline!!.fMainMAHeight
        } else {
            //  十字叉详情：靠右边显示
            fDetailX = _view_size.width - 4.dp - fDetailWidth
            fDetailY = _kline!!.fMainMAHeight
        }

        //  3.1、背景框
        val x1 = fDetailX
        val y1 = fDetailY
        val x2 = x1 + fDetailWidth
        val y2 = y1 + fDetailHeight
        //  背景
        paint.color = resources.getColor(R.color.theme01_appBackColor)
        paint.style = Paint.Style.FILL
        canvas.drawRect(x1, y1, x2, y2, paint)
        //  边框
        paint.color = resources.getColor(R.color.theme01_textColorNormal)
        paint.style = Paint.Style.STROKE
        canvas.drawRect(x1, y1, x2, y2, paint)

        //  3.2、详情 Value
        for ((lineIndex, value: String) in value_ary.withIndex()) {
            var txtColor: Int? = null
            var str: String? = null
            if (lineIndex == 5 || lineIndex == 6) {
                if (model.isRise) {
                    str = "+${value}"
                    txtColor = resources.getColor(R.color.theme01_buyColor)
                } else {
                    str = value
                    txtColor = resources.getColor(R.color.theme01_sellColor)
                }
                //  涨跌幅增加百分号显示。
                if (lineIndex == 6) {
                    str = "${str}%"
                }
            } else {
                str = value
                txtColor = resources.getColor(R.color.theme01_textColorMain)
            }
            val txt_paint = getTextPaintWithString(str, txtColor, _fontname, _fontsize)
            val x1 = fDetailX + 4f.dp
            val y1 = fDetailY + fDetailLineHeight * lineIndex + 4f.dp
            txt_paint.textAlign = Paint.Align.RIGHT
            val str_size = auxSizeWithText(str, _fontname, _fontsize)
            canvas.drawText(str, x1 + fDetailWidth - 8f.dp, y1 + str_size.height, txt_paint)
        }

        //  3.3、详情 Title
        for ((lineIndex: Int, str: String) in title_ary.withIndex()) {
            val txt_paint = getTextPaintWithString(str, resources.getColor(R.color.theme01_textColorMain), _fontname, _fontsize)
            val x1 = fDetailX + 4f.dp
            val y1 = fDetailY + fDetailLineHeight * lineIndex + 4f.dp
            txt_paint.textAlign = Paint.Align.LEFT
            val str_size = auxSizeWithText(str, _fontname, _fontsize)
            canvas.drawText(str, x1, y1 + str_size.height, txt_paint)
        }

        //  4、底部时间
        val date_str_size = auxSizeWithText(date_str, _fontname, _fontsize)
        val bottomRectW: Float = date_str_size.width + 8f.dp
        var bottomRectX: Float = max(model.showIndex * spaceW + currCandleWidth - round(bottomRectW / 2.0f), 1.0f.dp)
        bottomRectX = Math.min(bottomRectX, _view_size.width - bottomRectW - 1.0f.dp)
        val bottomRectY: Float = _view_size.height + 1f.dp
        val bottomRectH: Float = date_str_size.height + 8f.dp
        val _paint = Paint()
        _paint.strokeWidth = 1.0f.dp
        //  背景
        _paint.color = resources.getColor(R.color.theme01_appBackColor)
        _paint.style = Paint.Style.FILL
        canvas.drawRect(bottomRectX, bottomRectY, bottomRectX + bottomRectW, bottomRectY + bottomRectH, _paint)
        //  边框
        _paint.color = resources.getColor(R.color.theme01_textColorNormal)
        _paint.style = Paint.Style.STROKE
        canvas.drawRect(bottomRectX, bottomRectY, bottomRectX + bottomRectW, bottomRectY + bottomRectH, _paint)
        //  日期文本
        val bottom_date_txt_paint: Paint = getTextPaintWithString(date_str, resources.getColor(R.color.theme01_textColorMain), _fontname, _fontsize)
        bottom_date_txt_paint.textAlign = Paint.Align.CENTER
        canvas.drawText(date_str, bottomRectX + bottomRectW / 2.0f, bottomRectY + 4f.dp + date_str_size.height, bottom_date_txt_paint)

        //  5、横轴
        val tailer_str: String = model.nPriceClose!!.toPlainString()
        val tailer_str_size = auxSizeWithText(tailer_str, _fontname, _fontsize)
        val fHorTailerX: Float
        val fHorTailerW: Float = tailer_str_size.width + 8.0f.dp
        val fHorTailerH: Float = tailer_str_size.height + 8.0f.dp
        val fHorTailerY: Float = yOffsetHor - round(fHorTailerH / 2.0f)

        if (model.showIndex >= _kline!!._maxShowNumber / 2) {
            //  横轴尾端：靠右显示
            fHorTailerX = _view_size.width - fHorTailerW - 1.0f
        } else {
            //  横轴尾端：靠左显示
            fHorTailerX = 1.0f
        }
        //  背景
        _paint.color = resources.getColor(R.color.theme01_appBackColor)
        _paint.style = Paint.Style.FILL
        canvas.drawRect(fHorTailerX, fHorTailerY, fHorTailerX + fHorTailerW, fHorTailerY + fHorTailerH, _paint)
        //  边框
        _paint.color = resources.getColor(R.color.theme01_textColorMain)
        _paint.style = Paint.Style.STROKE
        canvas.drawRect(fHorTailerX, fHorTailerY, fHorTailerX + fHorTailerW, fHorTailerY + fHorTailerH, _paint)
        //  文字
        val tailer_txt_paint: Paint = getTextPaintWithString(tailer_str, resources.getColor(R.color.theme01_textColorMain), _fontname, _fontsize)
        tailer_txt_paint.textAlign = Paint.Align.CENTER
        canvas.drawText(tailer_str, fHorTailerX + fHorTailerW / 2.0f, fHorTailerY + 4f.dp + tailer_str_size.height, tailer_txt_paint)
    }


    /**
     *  描绘一条 MA(n) 指标，返回指标占据的宽度。
     */
    private fun drawOneMaValue(canvas: Canvas, title: String, ma: BigDecimal, offset_x: Float, offset_y: Float, color: Int): Float {
        val str = "$title:${ma.toPlainString()}"
        val str_size: Size = auxSizeWithText(str, _fontname, _fontsize)
        val paint = getTextPaintWithString(str, color, _fontname, _fontsize)
        paint.textAlign = Paint.Align.LEFT
        val frame = RectF(offset_x, offset_y + kBTS_KLINE_PRICE_VOL_FONTSIZE, str_size.width.toFloat(), str_size.height.toFloat())
        canvas.drawText(str, frame.left, frame.top, paint)
        return str_size.width.toFloat()
    }

    /**
     *  在主图顶部和副图顶部描绘 MA(n) 和 VOL。如果参数为 nil，则描绘最新数据的指标。
     */
    private fun drawAllMaValue(canvas: Canvas, model: MKlineItemData?) {
        var _model = model
        if (_model == null) {
            // 无数据
            if (_kline!!._kdataArrayAll.count() <= 0) {
                return
            }
            _model = _kline!!._kdataArrayAll.last()
        }
        assert(_model != null)

        var fMaOffsetX: Float = 4.0f.dp

        if (_kline!!.isDrawTimeLine()) {
            if (_model.ma60 != null) {
                //  同MA5颜色
                fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, "MA60", _model.ma60!!, fMaOffsetX, 4f.dp, resources.getColor(R.color.theme01_ma5Color))
            }
        } else {
            val main_values = SettingManager.sharedSettingManager().getKLineIndexInfos()
            var str_array: Array<String>? = null
            when (_kline!!._kMainIndexType) {
                ViewKLine.EKLineMainIndexType.ekmit_show_ma -> {
                    val ma_value = main_values.getJSONArray("ma_value")
                    str_array = arrayOf("MA${ma_value.getInt(0)}", "MA${ma_value.getInt(1)}", "MA${ma_value.getInt(2)}")
                }
                ViewKLine.EKLineMainIndexType.ekmit_show_ema -> {
                    val ema_value = main_values.getJSONArray("ema_value")
                    str_array = arrayOf("EMA${ema_value.getInt(0)}", "EMA${ema_value.getInt(1)}", "EMA${ema_value.getInt(2)}")
                }
                ViewKLine.EKLineMainIndexType.ekmit_show_boll -> {
                    val boll_value = main_values.getJSONObject("boll_value")
                    str_array = arrayOf("BOLL(${boll_value.getInt("n")},${boll_value.getInt("p")})", "UB", "LB")
                }
            }
            if (_model.main_index01 != null) {
                fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, str_array!![0], _model.main_index01!!, fMaOffsetX, 4f.dp, resources.getColor(R.color.theme01_ma5Color))
            }
            if (_model.main_index02 != null) {
                fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, str_array!![1], _model.main_index02!!, fMaOffsetX, 4f.dp, resources.getColor(R.color.theme01_ma10Color))
            }
            if (_model.main_index03 != null) {
                fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, str_array!![2], _model.main_index03!!, fMaOffsetX, 4f.dp, resources.getColor(R.color.theme01_ma30Color))
            }
        }

        //  副图区域 分时和K线一致。
        fMaOffsetX = 4.0f.dp
        val fSecondOffsetY: Float = _kline!!.fMainMAHeight.plus(_kline!!.fMainGraphHeight)
        fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, "VOL", _model.n24Vol!!, fMaOffsetX, fSecondOffsetY, resources.getColor(R.color.theme01_textColorMain))
        if (_model.vol_ma5 != null) {
            fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, "MA5", _model.vol_ma5!!, fMaOffsetX, fSecondOffsetY, resources.getColor(R.color.theme01_ma5Color))
        }
        if (_model.vol_ma10 != null) {
            fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, "MA10", _model.vol_ma10!!, fMaOffsetX, fSecondOffsetY, resources.getColor(R.color.theme01_ma10Color))
        }

        //  描绘其它高级指标属性
        drawAdvancedIndex_values(canvas, _model)
    }

    private fun drawIndexMACD_values(canvas: Canvas, m: MKlineItemData) {
        //  MACD指标
        //  adv_index01 - MACD
        //  adv_index02 - DIFF
        //  adv_index03 - DEA

        //  成交量柱子底部Y坐标
        var fVolumeGraphBottomY = _view_size.height - (_kline!!.fSecondMAHeight + _kline!!.fSecondGraphHeight)

        val main_values = SettingManager.sharedSettingManager().getKLineIndexInfos()
        val macd_value = main_values.getJSONObject("macd_value")

        var fMaOffsetX = 4.0f.dp

        if (m.adv_index01 != null) {
            fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, "MACD(${macd_value.getInt("s")},${macd_value.getInt("l")},${macd_value.getInt("m")})", m.adv_index01!!, fMaOffsetX, fVolumeGraphBottomY, resources.getColor(R.color.theme01_ma5Color))
        }
        if (m.adv_index02 != null) {
            fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, "DIFF", m.adv_index02!!, fMaOffsetX, fVolumeGraphBottomY, resources.getColor(R.color.theme01_ma10Color))
        }
        if (m.adv_index03 != null) {
            fMaOffsetX += 8.0f.dp + drawOneMaValue(canvas, "DEA", m.adv_index03!!, fMaOffsetX, fVolumeGraphBottomY, resources.getColor(R.color.theme01_ma30Color))
        }
    }

    private fun drawAdvancedIndex_values(canvas: Canvas, m: MKlineItemData) {
        when (_kline!!._kSubIndexType) {
            ViewKLine.EKLineSubIndexType.eksit_show_macd -> drawIndexMACD_values(canvas, m)
            else -> {
            }
        }
    }

    constructor(context: Context, sw: Float, tradingPair: TradingPair) : super(context) {
        _tradingPair = tradingPair
        _view_size = SizeF(sw, sw)

        //  初始化默认字体
        _fontname = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
        _fontsize = kBTS_KLINE_PRICE_VOL_FONTSIZE.toFloat()

        _ctx = context
    }

    //  主刷新
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (_first_init_draw) {
            return
        }
        if (_kline == null) {
            return
        }
        if (_currModel != null) {
            drawAllMaValue(canvas, _currModel)
            drawCrossLayer(canvas, _currModel!!)
        } else {
            drawAllMaValue(canvas, null)
        }
    }

    override fun dispatchTouchEvent(event: MotionEvent?): Boolean {
        return false
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        return false
    }
}