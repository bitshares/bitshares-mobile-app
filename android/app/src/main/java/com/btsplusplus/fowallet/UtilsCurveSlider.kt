package com.btsplusplus.fowallet

import android.annotation.SuppressLint
import android.graphics.PorterDuff
import android.graphics.drawable.LayerDrawable
import android.support.v7.app.AppCompatActivity
import android.widget.SeekBar
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt


class UtilsCurveSlider {

    private var _slider: SeekBar

    private var _mapping_min: Double = 0.0
    private var _mapping_max: Double = 0.0
    private var _mapping_diff: Double = 0.0
    private var _max_y_value: Double = 0.0

    private var _callback: ((value: Double) -> Unit)? = null

    fun on_value_changed(callback: (value: Double) -> Unit) {
        _callback = callback
    }

    /**
     * 设置最小、最大、当前值
     */
    fun set_min(min: Double) {
        _mapping_min = min
        _mapping_diff = _mapping_max - _mapping_min
        assert(_mapping_diff >= 0.01)
    }

    fun set_max(max: Double) {
        _mapping_max = max
        _mapping_diff = _mapping_max - _mapping_min
        assert(_mapping_diff >= 0.01)
    }

    fun set_value(progress: Double) {
        _slider.progress = real_value_to_x(progress)
    }

    fun get_value(): Double {
        return x_to_real_value(_slider.progress)
    }


    @SuppressLint("ResourceAsColor")
            /**
             * 构造函数
             */
    constructor(slider: SeekBar) {
        _slider = slider

        // REMARK 调整 条和块的颜色
        val color = (_slider.context as AppCompatActivity).resources.getColor(R.color.theme01_textColorMain)
        val layerDrawable = _slider.progressDrawable as? LayerDrawable
        if (layerDrawable != null) {
            val dra = layerDrawable.getDrawable(2)
            dra.setColorFilter(color, PorterDuff.Mode.SRC)
        }
        _slider.thumb.setColorFilter(color, PorterDuff.Mode.SRC_ATOP)
        _slider.invalidate()

        _slider.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(slider: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser && slider != null) {
                    _onProgressChanged(slider, progress)
                }
            }

            override fun onStartTrackingTouch(slider: SeekBar?) {
            }

            override fun onStopTrackingTouch(slider: SeekBar?) {
            }
        })
    }

    fun init_with_range(max: Int, mapping_min: Double, mapping_max: Double): UtilsCurveSlider {
        _mapping_min = mapping_min
        _mapping_max = mapping_max
        _mapping_diff = mapping_max - mapping_min
        assert(_mapping_diff >= 0.01)
        _slider.max = max
        _max_y_value = _formula_01(max)
        return this
    }

    /**
     * 事件：slider值变化。
     */
    private fun _onProgressChanged(slider: SeekBar, progress: Int) {
        if (_callback != null) {
            _callback!!.invoke(x_to_real_value(progress))
        }
    }

    /**
     * 公式01：目前映射公式：y = 0.02 * x^2
     * x范围：0 - _slider_max
     * y范围：0 - 0.02 * _slider_max^2
     * 实际值：y_value / max_y_value * (mapping_max - mapping_min) + mapping_min
     */
    private fun _formula_01(x: Int): Double {
        return 0.02 * x * x
    }

    /**
     * 公式01：逆向，通过 y 计算 x。
     */
    private fun _formula_01_reverse(y: Double): Int {
        return Math.sqrt(y / 0.02).roundToInt()
    }

    /**
     * 映射：slider值（x）到最终实际值
     */
    private fun x_to_real_value(x: Int): Double {
        val value = _mapping_diff * _formula_01(x) / _max_y_value + _mapping_min
        return max(min(value, _mapping_max), _mapping_min)
    }

    /**
     * 映射：最终实际值 到 slider值（x）
     */
    private fun real_value_to_x(value: Double): Int {
        val new_value = max(min(value, _mapping_max), _mapping_min)
        val y_value = (_max_y_value * (new_value - _mapping_min)).toDouble() / _mapping_diff
        val x_value = _formula_01_reverse(y_value)
        return max(0, min(x_value, _slider.max))
    }
}