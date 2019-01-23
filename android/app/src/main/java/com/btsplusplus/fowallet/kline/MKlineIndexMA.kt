package com.btsplusplus.fowallet.kline

import java.math.BigDecimal

class MKlineIndexMA {

    var _n: Int = 0
    var _n_n: BigDecimal
    var _sum: BigDecimal

    var _getter: ((MKlineItemData) -> BigDecimal)? = null

    // var _data_array: JSONArray = JSONArray()
    var _data_array: MutableList<MKlineItemData>? = null
    var _ceil_handler: Array<Int>? = null
    var _cnt: Int = 0

    constructor(n: Int, data_arr: MutableList<MKlineItemData>, ceil_handler: Array<Int>, getter: (MKlineItemData) -> BigDecimal) {
        _n = n
        _n_n = BigDecimal(n)
        _sum = BigDecimal.ZERO

        _getter = getter
        _data_array = data_arr
        _ceil_handler = ceil_handler

        _cnt = 0
    }


    /**
     *  计算移动平均数MA(n)，如果当前蜡烛图数量不足 n，则返回 nil，否则返回 n 项的移动平均数。
     */

    fun calc_ma(model: MKlineItemData): BigDecimal? {
        _sum = _sum.add(_getter!!.invoke(model))
        _cnt++
        if (_cnt >= _n) {
            //  多余项数值需要减去。
            if (_cnt >= _n + 1) {
                val m: MKlineItemData = _data_array!!.get(_cnt - (_n + 1))
                _sum = _sum.subtract(_getter!!(m))
            }
            //  计算平均数
            val scale = _ceil_handler!!.get(0)
            val rounding = _ceil_handler!!.get(1)
            val ma = _sum.divide(_n_n, scale, rounding)
            assert(ma.toDouble() >= 0)
            return ma
        } else {
            //  没达到 n 项，没有 ma 值。
            return null
        }
    }
}