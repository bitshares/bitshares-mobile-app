package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.Utils
import bitshares.dp
import org.json.JSONObject

/**
 *  检测类型条件枚举常量定义
 */
const val kCondTypeRegular = 0          //  检测条件：正则
const val kCondLengthRange = 1          //  检测条件：字符串范围限制。

class ViewFormatConditons : LinearLayout {

    class SignalConditionViews(val title: TextView, val checked: ImageView, val unchecked: ImageView)
    class ConditionDataItem(val condition: JSONObject, val checkbox: SignalConditionViews)

    private var _ctx: Context
    private var _condition_array = arrayListOf<ConditionDataItem>()
    private var _lastCheckString: String? = null
    private var _isAllConditionsMatched = false

    private var _tf_watcher: UtilsDigitTextWatcher? = null  //  文本编辑监听事件

    var isAlwaysShow: Boolean = false                       //  是否一直显示，如需修改请在 bindingTextField 调用之前设置。

    fun isAllConditionsMatched(): Boolean {
        return _isAllConditionsMatched
    }

    constructor(ctx: Context) : super(ctx) {
        _ctx = ctx

        this.orientation = LinearLayout.VERTICAL
        this.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            setMargins(0, 5.dp, 0, 0)
        }
    }

    /**
     *  (public) 辅助 - 快速生成【钱包密码】格式的条件视图。
     */
    fun auxFastConditionsViewForWalletPassword() {
        fastConditionContainsUppercaseLetter(resources.getString(R.string.kFmtConditioncontainsUpperLetters))
        fastConditionContainsLowercaseLetter(resources.getString(R.string.kFmtConditionContainsLowerLetters))
        fastConditionContainsArabicNumerals(resources.getString(R.string.kFmtConditionContainsDigits))
        addLengthCondition(resources.getString(R.string.kFmtConditionLen12To40Chars), min_length = 12, max_length = 40, negative = false)
    }

    /**
     *  (public) 辅助 - 快速生成【账号模式的账号密码】格式的条件视图。
     */
    fun auxFastConditionsViewForAccountPassword() {
        //  TODO:5.0 是否随机密码？
        fastConditionContainsUppercaseLetter(resources.getString(R.string.kFmtConditioncontainsUpperLetters))
        fastConditionContainsLowercaseLetter(resources.getString(R.string.kFmtConditionContainsLowerLetters))
        fastConditionContainsArabicNumerals(resources.getString(R.string.kFmtConditionContainsDigits))
        addLengthCondition(resources.getString(R.string.kFmtConditionLen32To40Chars), min_length = 32, max_length = 40, negative = false)
    }

    /**
     *  (public) 辅助 - 快速生成【账号名】格式的条件视图。
     */
    fun auxFastConditionsViewForAccountNameFormat() {
        //  REMARK：注册时的账号名，默认显示。
        addRegularCondition(resources.getString(R.string.kFmtConditionOnlyContainsLetterDigitAndHyphens), regular = "^[A-Za-z0-9\\-]+$", negative = false)
        fastConditionBeginWithLetter(resources.getString(R.string.kFmtConditionBeginwithLetters))
        fastConditionEndWithLetterOrDigit(resources.getString(R.string.kFmtConditionEndWithLetterOrDigits))
        fastConditionContainsArabicNumerals(resources.getString(R.string.kFmtConditionContainsDigits))
        addLengthCondition(resources.getString(R.string.kFmtConditionLen3To32Chars), min_length = 3, max_length = 32, negative = false)
    }

    /**
     *  (public) 快速添加条件 - 包含大写字母、小写字母、0-9的阿拉伯数字、字母开头。
     */
    fun fastConditionContainsUppercaseLetter(title: String) {
        addRegularCondition(title = title, regular = ".*[A-Z]+.*", negative = false)
    }

    fun fastConditionContainsLowercaseLetter(title: String) {
        addRegularCondition(title = title, regular = ".*[a-z]+.*", negative = false)
    }

    fun fastConditionContainsArabicNumerals(title: String) {
        addRegularCondition(title = title, regular = ".*[0-9]+.*", negative = false)
    }

    fun fastConditionBeginWithLetter(title: String) {
        addRegularCondition(title = title, regular = "^[A-Za-z]+.*", negative = false)
    }

    fun fastConditionEndWithLetterOrDigit(title: String) {
        addRegularCondition(title = title, regular = ".*[A-Za-z0-9]+$", negative = false)
    }

    /**
     *  (public) 快速添加条件 - 包含2个以上非连续的大写字母。
     */
    fun fastConditionContainsMoreThanTwoUppercaseLetterNonConsecutive(title: String) {
        addRegularCondition(title = title, regular = ".*[A-Z]+[^A-Z]+[A-Z]+.*", negative = false)
    }

    /**
     *  (public) 添加条件 - 正则匹配类型。
     *  negative - 否定，表示不匹配。
     */
    fun addRegularCondition(title: String, regular: String, negative: Boolean) {
        _addCondition(title, condition = JSONObject().apply {
            put("type", kCondTypeRegular)
            put("regular", regular)
            put("negative", negative)
        })
    }

    /**
     *  (public) 添加条件 - 长度范围类型。区间范围 min..max。都是闭区间。
     *  negative - 否定，表示不匹配。
     */
    fun addLengthCondition(title: String, min_length: Int, max_length: Int, negative: Boolean) {
        assert(min_length > 0)
        assert(max_length >= min_length)

        _addCondition(title, condition = JSONObject().apply {
            put("type", kCondLengthRange)
            put("min", min_length)
            put("max", max_length)
            put("negative", negative)
        })
    }

    private fun _addCondition(title: String, condition: JSONObject) {
        _condition_array.add(ConditionDataItem(condition = condition, checkbox = genOneView(title)))
    }

    private fun genOneView(title: String): SignalConditionViews {
        var scv: SignalConditionViews? = null
        val view = LinearLayout(_ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp).apply {
                gravity = Gravity.CENTER_VERTICAL
                setMargins(0, 5.dp, 0, 0)
            }
            //  checkbox图标
            var icon_checked: ImageView? = null
            var icon_unchecked: ImageView? = null
            val icon = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(16.dp, 16.dp)
                //  选中
                icon_checked = ImageView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                    setImageResource(R.drawable.icon_checked)
                    setColorFilter(resources.getColor(R.color.theme01_buyColor))
                    right = Gravity.RIGHT
                    visibility = View.GONE
                }
                addView(icon_checked)
                //  非选中
                icon_unchecked = ImageView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
                    setImageResource(R.drawable.icon_unchecked)
                    setColorFilter(resources.getColor(R.color.theme01_textColorGray))
                    right = Gravity.RIGHT
                    visibility = View.VISIBLE
                }
                addView(icon_unchecked)
            }
            addView(icon)
            //  文本
            val tv = TextView(_ctx).apply {
                text = title
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                setTextColor(resources.getColor(R.color.theme01_textColorGray))
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                    setMargins(4.dp, 0, 0, 0)
                }
            }
            addView(tv)

            scv = SignalConditionViews(tv, icon_checked!!, icon_unchecked!!)
        }
        addView(view)

        return scv!!
    }

    /**
     *  (public) 绑定输入框（监听文本变更事件，如果外面需要处理该事件则不用绑定，直接调用 onTextDidChange 即可。）
     */
    fun bindingTextField(tf: EditText) {
        if (_tf_watcher == null) {
            _tf_watcher = UtilsDigitTextWatcher().set_tf(tf).set_alpha_text_inputfield(true)
            tf.addTextChangedListener(_tf_watcher)
            _tf_watcher?.on_value_changed { str_new ->
                onTextDidChange(str_new)
            }
            //  动态显示的情况下，添加监听。
            if (!isAlwaysShow) {
                //  初始化不可见
                this.visibility = View.GONE
                tf.setOnFocusChangeListener { _, hasFocus ->
                    if (hasFocus) {
                        this.visibility = View.VISIBLE
                    } else {
                        this.visibility = View.GONE
                    }
                }
            } else {
                //  初始化可见性
                this.visibility = View.VISIBLE
            }
        }
    }

    /**
     *  (public) 触发器 - 文字变更检测。
     */
    fun onTextDidChange(new_string: String?) {
        _lastCheckString = new_string
        _isAllConditionsMatched = true

        for (item in _condition_array) {
            val condition = item.condition
            var success = _checkCondition(condition, new_string)
            if (condition.optBoolean("negative")) {
                success = !success
            }
            val checkbox = item.checkbox
            if (success) {
                //  条件匹配
                checkbox.checked.visibility = View.VISIBLE
                checkbox.unchecked.visibility = View.GONE
                checkbox.title.setTextColor(resources.getColor(R.color.theme01_buyColor))
            } else {
                //  条件不匹配
                checkbox.checked.visibility = View.GONE
                checkbox.unchecked.visibility = View.VISIBLE
                checkbox.title.setTextColor(resources.getColor(R.color.theme01_textColorGray))
                //  设置尚未全部匹配标记
                _isAllConditionsMatched = false
            }
        }
    }

    /**
     *  (private) 检测各种条件类型是否匹配
     */
    private fun _checkCondition(condition: JSONObject, value: String?): Boolean {
        return when (condition.getInt("type")) {
            kCondLengthRange -> _checkCondLengthRange(condition, value)
            kCondTypeRegular -> _checkCondRegular(condition, value)
            else -> false
        }
    }

    private fun _checkCondRegular(condition: JSONObject, value: String?): Boolean {
        if (value == null) {
            return false
        }
        return Utils.isRegularMatch(value, condition.getString("regular"))
    }

    private fun _checkCondLengthRange(condition: JSONObject, value: String?): Boolean {
        if (value == null) {
            return false
        }
        val _min = condition.getInt("min")
        val _max = condition.getInt("max")
        val len = value.length
        return len in _min.._max
    }
}