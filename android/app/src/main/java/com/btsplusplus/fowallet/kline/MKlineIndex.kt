package com.btsplusplus.fowallet.kline

import java.math.BigDecimal
import java.math.BigDecimal.ROUND_HALF_UP

class MKlineIndex {

    companion object {

        /**
         *  (public) calc MA index
         */
        fun calc_ma_index(n: Int, data_arr: MutableList<MKlineItemData>, ceil_handler: Array<Int>, getter: (MKlineItemData) -> BigDecimal?, setter: (MKlineItemData, BigDecimal?) -> Unit) {
            if (n <= 0) {
                return
            }

            val n_n = BigDecimal(n)
            var sum = BigDecimal.ZERO
            var ma: BigDecimal?

            val scale = ceil_handler[0]
            val rounding = ceil_handler[1]

            data_arr.forEachIndexed { dataIndex, m ->
                val value = getter(m)!!

                sum = sum.add(value)

                if (dataIndex >= n - 1) {
                    if (dataIndex >= n) {
                        val last_value = getter(data_arr[dataIndex - n])
                        sum = sum.subtract(last_value)
                    }
                    ma = sum.divide(n_n, scale, rounding)
                } else {
                    ma = null
                }

                setter(m, ma)
            }
        }

        /**
         *  (public) calc EMA index
         */
        fun calc_ema_index(n: Int, data_arr: MutableList<MKlineItemData>, ceil_handler: Array<Int>, getter: (MKlineItemData) -> BigDecimal?, setter: (MKlineItemData, BigDecimal?) -> Unit) {

            if (n <= 0) {
                return
            }

            val n_n = BigDecimal(n)
            //  smoothing factor = 2 / (n + 1)
            val alpha = BigDecimal(2).divide(n_n.add(BigDecimal.ONE), 16, ROUND_HALF_UP)

            var sum = BigDecimal.ZERO
            var ema_yesterday: BigDecimal? = null
            var ema_today: BigDecimal?

            val scale = ceil_handler[0]
            val rounding = ceil_handler[1]

            data_arr.forEachIndexed { dataIndex, m ->
                val value = getter(m)
                if (value != null) {
                    //  calc
                    if (ema_yesterday != null) {
                        ema_today = value.subtract(ema_yesterday).multiply(alpha).add(ema_yesterday).setScale(scale, rounding)
                    } else {
                        sum = sum.add(value)
                        if (dataIndex < n - 1) {
                            ema_today = null
                        } else {
                            //  calc MA as ema
                            ema_today = sum.divide(n_n, scale, rounding)
                        }
                    }

                    //  set
                    setter(m, ema_today)
                    ema_yesterday = ema_today
                }
            }
        }

        /**
         * (public) calc Bollinger Bands index
         */
        fun calc_boll_index(n: Int, p: Int, data_arr: MutableList<MKlineItemData>, ceil_handler: Array<Int>, getter: (MKlineItemData) -> BigDecimal?) {
            calc_ma_index(n, data_arr, ceil_handler, getter) { m, new_index_value ->
                m.main_index01 = new_index_value
            }

            val n_n = BigDecimal(n)
            val scale = ceil_handler[0]
            val rounding = ceil_handler[1]

            data_arr.forEachIndexed { dataIndex, m ->
                if (m.main_index01 != null) {
                    //  data = close(n)
                    //  ma = data.sum / data.size
                    //  md = sqrt(data.map{|v| (v-ma)**2}.sum/data.size)
                    //  ub = ma + p*md
                    //  lb = ma - p*md
                    assert(dataIndex >= n - 1)

                    var sum_of_variance = BigDecimal.ZERO

                    for (i in dataIndex + 1 - n..dataIndex) {
                        val variance = m.main_index01!!.subtract(getter(data_arr[i])).pow(2)
                        sum_of_variance = sum_of_variance.add(variance)
                    }

                    //  计算平均方差
                    val average_variance = sum_of_variance.divide(n_n, 16, ROUND_HALF_UP)

                    //  标准差
                    val p_standard_deviation = p * Math.sqrt(average_variance.toDouble())

                    //  N倍标准差
                    val n_standard_deviation = BigDecimal(p_standard_deviation)

                    //  REMARK：下轨可能为负数
                    m.main_index02 = m.main_index01!!.add(n_standard_deviation).setScale(scale, rounding)
                    m.main_index03 = m.main_index01!!.subtract(n_standard_deviation).setScale(scale, rounding)
                }
            }
        }


    }

}