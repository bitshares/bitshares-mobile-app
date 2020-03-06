package com.btsplusplus.fowallet

import android.text.Editable
import android.text.TextWatcher
import android.widget.EditText
import bitshares.Utils

class UtilsDigitTextWatcher : TextWatcher {
    /**
     * 设置文本（不触发事件）
     */
    fun set_new_text(str: String) {
        _tf?.let {
            _enable_callback = false
            it.setText(str)
            //  REMARK：由于 maxLength 存在，这里不采用 str.length。
            it.setSelection(it.text.toString().length)
            _enable_callback = true
        }
    }

    /**
     * 设置关联的输入框控件
     */
    fun set_tf(tf: EditText): UtilsDigitTextWatcher {
        _tf = tf
        return this
    }

    /**
     * 获取输入框当前文本
     */
    fun get_tf_string(): String {
        if (_tf != null) {
            return _tf!!.text.toString()
        } else {
            return ""
        }
    }

    fun set_precision(precision: Int): UtilsDigitTextWatcher {
        _precision = precision
        return this
    }

    fun on_value_changed(callback: (s: String) -> Unit) {
        _callback = callback
    }

    fun set_alpha_text_inputfield(is_alpha_text_inputfield: Boolean): UtilsDigitTextWatcher {
        _is_alpha_text_inputfield = is_alpha_text_inputfield
        return this
    }

    private var _is_alpha_text_inputfield = false
    private var _precision: Int = 5
    private var _tf: EditText? = null
    private var _valid_string: String = ""
    private var _callback: ((s: String) -> Unit)? = null
    private var _last_callback_string: String? = null

    /**
     * 是否启用callback回掉，如果需要代码设置输入框的值，应该先关闭，设置完了之后再开启，否则可能导致循环触发。
     */
    private var _enable_callback: Boolean = true

    fun clear() {
        _tf!!.text.clear()
        _valid_string = ""
        _last_callback_string = null
    }

    fun endInput() {
        _tf?.clearFocus()
    }

    override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {
    }

    override fun afterTextChanged(s: Editable) {
        if (_callback != null) {
            if (_last_callback_string == null || _last_callback_string!! != _valid_string) {
                _last_callback_string = _valid_string
                if (_enable_callback) {
                    _callback!!(_valid_string)
                }
            }
        }
    }

    /**
     * 限制数字输入框输入格式
     */
    override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
        if (!_is_alpha_text_inputfield && !Utils.isValidAmountOrPriceInput(s.toString(), _precision)) {
            _tf!!.setText(_valid_string)
            _tf!!.setSelection(_valid_string.length)
        } else {
            _valid_string = s.toString()
        }
    }
}