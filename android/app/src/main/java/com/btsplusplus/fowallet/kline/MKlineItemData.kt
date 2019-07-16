package com.btsplusplus.fowallet.kline

import bitshares.Utils
import bitshares.bigDecimalfromAmount
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.pow

class MKlineItemData {

    var dataIndex = 0
    var showIndex = 0

    var isRise: Boolean = false
    var isMaxPrice: Boolean = false
    var isMinPrice: Boolean = false
    var isMax24Vol: Boolean = false

    var nPriceOpen: BigDecimal? = null
    var nPriceClose: BigDecimal? = null
    var nPriceHigh: BigDecimal? = null
    var nPriceLow: BigDecimal? = null

    var n24Vol: BigDecimal? = null              //  成交量
    var n24TotalAmount: BigDecimal? = null      //  成交额
    var nAvgPrice: BigDecimal? = null           //  成交均价

    var ma60: BigDecimal? = null                //  分时图需要显示 / for timeline

    var main_index01: BigDecimal? = null        //  主图指标01-03（根据设置对应不同指标，比如ma1-ma3，或者ema1-ema3，或者boll、ub、lb等）
    var main_index02: BigDecimal? = null
    var main_index03: BigDecimal? = null
    var fOffsetMainIndex01: Float = 0f
    var fOffsetMainIndex02: Float = 0f
    var fOffsetMainIndex03: Float = 0f

    var adv_index01: BigDecimal? = null        //  高级指标（MACD等）
    var adv_index02: BigDecimal? = null
    var adv_index03: BigDecimal? = null
    var fOffsetAdvIndex01: Float = 0f
    var fOffsetAdvIndex02: Float = 0f
    var fOffsetAdvIndex03: Float = 0f

    var vol_ma5: BigDecimal? = null
    var vol_ma10: BigDecimal? = null

    var change: BigDecimal? = null
    var change_percent: BigDecimal? = null

    var fOffsetOpen: Float = 0f
    var fOffsetClose: Float = 0f
    var fOffsetHigh: Float = 0f
    var fOffsetLow: Float = 0f

    var fOffset24Vol: Float = 0f

    var fOffsetMA60: Float = 0f

    var fOffsetVolMA5: Float = 0f
    var fOffsetVolMA10: Float = 0f

    var date: Long = 0

    fun reset() {
        showIndex = 0

        isRise = false
        isMaxPrice = false
        isMinPrice = false
        isMax24Vol = false

        nPriceOpen = null
        nPriceClose = null
        nPriceHigh = null
        nPriceLow = null

        n24Vol = null
        n24TotalAmount = null
        nAvgPrice = null

        ma60 = null

        main_index01 = null
        main_index02 = null
        main_index03 = null

        fOffsetMainIndex01 = 0f
        fOffsetMainIndex02 = 0f
        fOffsetMainIndex03 = 0f

        adv_index01 = null
        adv_index02 = null
        adv_index03 = null
        fOffsetAdvIndex01 = 0f
        fOffsetAdvIndex02 = 0f
        fOffsetAdvIndex03 = 0f

        vol_ma5 = null
        vol_ma10 = null

        change = null
        change_percent = null

        fOffsetOpen = 0f
        fOffsetClose = 0f
        fOffsetHigh = 0f
        fOffsetLow = 0f

        fOffset24Vol = 0f

        fOffsetMA60 = 0f

        fOffsetVolMA5 = 0f
        fOffsetVolMA10 = 0f

        date = 0L
    }

    constructor()

    companion object {

        /**
         *  (public) 解析服务器的K线数据，生成对应的Model。
         *
         *  fillto          - 可为nil。
         *  ceilHandler     - 可为nil。
         */
        fun parseData(data: JSONObject,
                      fillto: MKlineItemData?,
                      base_id: String?,
                      base_precision: Int,
                      quote_precision: Int,
                      ceilHandler: Array<Int>?,
                      percentHandler: Array<Int>?
        ): MKlineItemData {

            var _fillto = fillto
            if (_fillto == null) {
                _fillto = MKlineItemData()
            }

            var _ceilHandler = ceilHandler
            var _percentHandler = percentHandler


            //  保留小数位数 向上取整
            if (_ceilHandler == null) {
                _ceilHandler = arrayOf(base_precision, BigDecimal.ROUND_UP)
            }

            //  涨跌幅的百分比 handler，有效数位4位。百分比加2位小数点。
            if (_percentHandler == null) {
                _percentHandler = arrayOf(4, BigDecimal.ROUND_UP)
            }

            val n_base_precision = BigDecimal.valueOf(10.0.pow(base_precision))
            val n_quote_precision = BigDecimal.valueOf(10.0.pow(quote_precision))

            val cell_scale = _ceilHandler[0]
            val cell_rounding = _ceilHandler[1]

            val percent_scale = _percentHandler[0]
            val percent_rounding = _percentHandler[1]

            val open_base = data.getString("open_base")
            val open_quote = data.getString("open_quote")

            val high_base = data.getString("high_base")
            val high_quote = data.getString("high_quote")

            val low_base = data.getString("low_base")
            val low_quote = data.getString("low_quote")

            val close_base = data.getString("close_base")
            val close_quote = data.getString("close_quote")

            val key = data.getJSONObject("key")

            if (key.getString("base") == base_id) {

                //  price = base/quote

                val n_open_base = bigDecimalfromAmount(open_base, n_base_precision)
                val n_open_quote = bigDecimalfromAmount(open_quote, n_quote_precision)

                val n_high_base = bigDecimalfromAmount(high_base, n_base_precision)
                val n_high_quote = bigDecimalfromAmount(high_quote, n_quote_precision)

                val n_low_base = bigDecimalfromAmount(low_base, n_base_precision)
                val n_low_quote = bigDecimalfromAmount(low_quote, n_quote_precision)

                val n_close_base = bigDecimalfromAmount(close_base, n_base_precision)
                val n_close_quote = bigDecimalfromAmount(close_quote, n_quote_precision)

                val n_open_price = n_open_base.divide(n_open_quote, cell_scale, cell_rounding)
                val n_high_price = n_high_base.divide(n_high_quote, cell_scale, cell_rounding)
                val n_low_price = n_low_base.divide(n_low_quote, cell_scale, cell_rounding)
                val n_close_price = n_close_base.divide(n_close_quote, cell_scale, cell_rounding)

                _fillto.n24Vol = bigDecimalfromAmount(data.getString("quote_volume"), n_quote_precision)
                _fillto.n24TotalAmount = bigDecimalfromAmount(data.getString("base_volume"), n_base_precision)
                _fillto.isRise = n_open_price <= n_close_price

                //  REMARK：完全一致、高低也相同
                _fillto.nPriceOpen = n_open_price
                _fillto.nPriceClose = n_close_price
                _fillto.nPriceHigh = n_high_price
                _fillto.nPriceLow = n_low_price
            } else {

                //  price = quote/base

                val n_open_base = bigDecimalfromAmount(open_base, n_quote_precision)
                val n_open_quote = bigDecimalfromAmount(open_quote, n_base_precision)

                val n_high_base = bigDecimalfromAmount(high_base, n_quote_precision)
                val n_high_quote = bigDecimalfromAmount(high_quote, n_base_precision)

                val n_low_base = bigDecimalfromAmount(low_base, n_quote_precision)
                val n_low_quote = bigDecimalfromAmount(low_quote, n_base_precision)

                val n_close_base = bigDecimalfromAmount(close_base, n_quote_precision)
                val n_close_quote = bigDecimalfromAmount(close_quote, n_base_precision)

                val n_open_price = n_open_quote.divide(n_open_base, cell_scale, cell_rounding)
                val n_high_price = n_high_quote.divide(n_high_base, cell_scale, cell_rounding)
                val n_low_price = n_low_quote.divide(n_low_base, cell_scale, cell_rounding)
                val n_close_price = n_close_quote.divide(n_close_base, cell_scale, cell_rounding)

                _fillto.n24Vol = bigDecimalfromAmount(data.getString("base_volume"), n_quote_precision)
                _fillto.n24TotalAmount = bigDecimalfromAmount(data.getString("quote_volume"), n_base_precision)
                _fillto.isRise = n_open_price <= n_close_price

                //  REMARK：开收相同、高低反向
                _fillto.nPriceOpen = n_open_price
                _fillto.nPriceClose = n_close_price
                _fillto.nPriceHigh = n_low_price
                _fillto.nPriceLow = n_high_price
            }

            //  成交均价
            if (_fillto.n24Vol!! > BigDecimal.ZERO) {
                _fillto.nAvgPrice = _fillto.n24TotalAmount!!.divide(_fillto.n24Vol, cell_scale, cell_rounding)
            } else {
                _fillto.nAvgPrice = null
            }

            //  计算涨跌额和涨跌幅
            _fillto.change = _fillto.nPriceClose!!.subtract(_fillto.nPriceOpen).setScale(cell_scale, cell_rounding)
            var rate = _fillto.nPriceClose!!.divide(_fillto.nPriceOpen, percent_scale, percent_rounding)
            rate = rate.subtract(BigDecimal.ONE)
            _fillto.change_percent = rate.scaleByPowerOfTen(2).setScale(percent_scale, percent_rounding)

            //  解析日期
            _fillto.date = Utils.parseBitsharesTimeString(key.getString("open"))

            return _fillto
        }

    }

}