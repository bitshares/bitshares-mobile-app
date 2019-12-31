package com.btsplusplus.fowallet

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.ViewEx.EditTextEx
import org.json.JSONObject
import java.math.BigDecimal

class ViewDialogOtcTrade : Dialog {

    var _ctx: Context

    private val content_fontsize = 12.0f

    // 输入数量 Edittext
    private lateinit var _tf_amount: EditText

    // 输入金额 Edittext
    private lateinit var _tf_total: EditText

    // 交易数量 TextView
    private lateinit var _tv_trade_amount: TextView

    // 交易金额
    private lateinit var _tv_trade_total: TextView

    //  倒计时按钮
    private lateinit var _btnAutoClose: TextView

    private var _ad_info: JSONObject
    private var _lock_info: JSONObject
    private var _sell_user_balance: JSONObject?
    private var _callback: (result: JSONObject?) -> Unit

    private var _tf_amount_watcher: UtilsDigitTextWatcher
    private var _tf_total_watcher: UtilsDigitTextWatcher

    private var _isBuy = false
    private var _numPrecision = 0
    private var _totalPrecision = 0
    private var _autoCloseTimerID = 0
    private var _autoCloseSeconds = 0L
    private var _nBalance: BigDecimal? = null
    private var _nPrice: BigDecimal
    private var _nStock: BigDecimal
    private var _nStockFinal: BigDecimal
    private var _nMaxLimit: BigDecimal
    private var _nMaxLimitFinal: BigDecimal

    constructor(ctx: Context, ad_info: JSONObject, lock_info: JSONObject, sell_user_balance: JSONObject?, callback: (result: JSONObject?) -> Unit) : super(ctx) {
        //  基本参数
        _ctx = ctx
        _ad_info = ad_info
        _lock_info = lock_info
        _sell_user_balance = sell_user_balance
        _callback = callback
        //  参数扩展
        val assetSymbol = _ad_info.getString("assetSymbol")
        val fiatSymbol = OtcManager.sharedOtcManager().getFiatCnyInfo().getString("legalCurrencySymbol")
        _isBuy = _ad_info.getInt("adType") == OtcManager.EOtcAdType.eoadt_user_buy.value
        val assetInfo = OtcManager.sharedOtcManager().getAssetInfo(assetSymbol)
        _numPrecision = assetInfo.getInt("assetPrecision")
        _totalPrecision = OtcManager.sharedOtcManager().getFiatCnyInfo().getInt("assetPrecision")
        if (_sell_user_balance != null) {
            _nBalance = bigDecimalfromAmount(_sell_user_balance!!.getString("amount"), _numPrecision)
        }
        _nPrice = Utils.auxGetStringDecimalNumberValue(lock_info.getString("unitPrice"))
        _nStock = Utils.auxGetStringDecimalNumberValue(ad_info.getString("stock"))
        _nMaxLimit = Utils.auxGetStringDecimalNumberValue(lock_info.getString("highLimitPrice"))
        _nMaxLimitFinal = _nMaxLimit
        val n_trade_max_limit = _calc_n_total_from_number(_nStock)
        if (_nMaxLimitFinal > n_trade_max_limit) {
            _nMaxLimitFinal = n_trade_max_limit
        }
        _nStockFinal = _nStock
        val n_stock_limit = _calc_n_number_from_total(_nMaxLimit)
        if (_nStockFinal > n_stock_limit) {
            _nStockFinal = n_stock_limit
        }

        _autoCloseSeconds = _lock_info.getLong("expireDate")

        //  --- 构造UI ---

        //  外层 Layout
        val layout = LinearLayout(context)
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_params.leftMargin = 0
        layout_params.rightMargin = 0
        layout.orientation = LinearLayout.VERTICAL
        layout.layoutParams = layout_params
        layout.setBackgroundColor(context.resources.getColor(R.color.theme01_appBackColor))
        layout.setPadding(0, 0, 0, 20.dp)

        //  UI - 顶部标题
        val layout_titlebar = LinearLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, 44.dp)
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 0, 0, 0)
            setBackgroundColor(context.resources.getColor(R.color.theme01_tabBarColor))
            addView(TextView(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                this.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                val title = if (_isBuy) {
                    "${R.string.kOtcInputTitleBuy.xmlstring(ctx)} $assetSymbol"
                } else {
                    "${R.string.kOtcInputTitleSell.xmlstring(ctx)} $assetSymbol"
                }
                text = title
                setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                setPadding(0, 0, 10.dp, 0)
            })
        }

        //  中间内容通用的 layout_params
        val layout_params_content = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
        layout_params_content.gravity = Gravity.CENTER_VERTICAL

        //  第一行 单价
        val ly1 = LinearLayout(ctx).apply {
            val _layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            _layout_params.gravity = Gravity.CENTER
            _layout_params.setMargins(0, 10.dp, 0, 10.dp)
            layoutParams = _layout_params
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)
            gravity = Gravity.CENTER

            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER
                addView(TextView(ctx).apply {
                    text = R.string.kOtcInputLabelUnitPrice.xmlstring(ctx)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                    gravity = Gravity.CENTER
                })
                addView(TextView(ctx).apply {
                    text = "$fiatSymbol${_lock_info.getString("unitPrice")}"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 18.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                    gravity = Gravity.CENTER
                    setPadding(5.dp, 0, 0, 0)
                })
            })
        }

        //  第二行 购买数量标题(余额) --- 购买数量
        val ly2 = LinearLayout(ctx).apply {
            layoutParams = layout_params_content
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 2f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(ctx).apply {
                    text = if (_isBuy) R.string.kOtcInputCellLabelBuyAmount.xmlstring(ctx) else R.string.kOtcInputCellLabelSellAmount.xmlstring(ctx)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.LEFT
                })
                //  卖出时：显示我的余额
                if (!_isBuy) {
                    addView(TextView(ctx).apply {
                        text = "${R.string.kOtcInputCellYourBalance.xmlstring(ctx)} ${OrgUtils.formatFloatValue(_nBalance!!.toDouble(), _numPrecision, has_comma = false)} $assetSymbol"
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                        setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                        gravity = Gravity.CENTER
                        setPadding(5.dp, 0, 0, 0)
                    })
                }
            })
            //  右边 可买数量/可卖数量
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                addView(TextView(ctx).apply {
                    text = "${R.string.kOtcInputCellStock.xmlstring(ctx)} ${_ad_info.getString("stock")} $assetSymbol"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
        }

        //  第三行 数量输入框  usd | 全部买入
        val ly3 = LinearLayout(ctx).apply {
            layoutParams = layout_params_content
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                val placeholder = if (_isBuy) R.string.kOtcInputPlaceholderBuyAmount.xmlstring(ctx) else R.string.kOtcInputPlaceholderSellAmount.xmlstring(ctx)
                _tf_amount = EditTextEx(ctx, placeholder, dp_size = 17.0f).apply {
                    // 限制整数和小数
                    inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                    maxLines = 1
                    setSingleLine(true)
                }
                addView(_tf_amount)
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(ctx).apply {
                    text = assetSymbol
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                })
                addView(TextView(ctx).apply {
                    text = " | "
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                })

                addView(TextView(ctx).apply {
                    text = if (_isBuy) R.string.kOtcInputTailerBtnBuyAll.xmlstring(ctx) else R.string.kOtcInputTailerBtnSellAll.xmlstring(ctx)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorHighlight))

                    // 买入或出售全部数量
                    setOnClickListener {
                        onButtonTailerClicked(true)
                    }
                })
            })
        }

        //  第四行 购买金额标题 限额
        val ly4 = LinearLayout(ctx).apply {
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
            layout_params.setMargins(0, 10.dp, 0, 0)
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0.dp, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(ctx).apply {
                    text = if (_isBuy) R.string.kOtcInputCellLabelBuyTotal.xmlstring(ctx) else R.string.kOtcInputCellLabelSellTotal.xmlstring(ctx)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.LEFT
                })
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(ctx).apply {
                    text = "${R.string.kOtcInputCellLabelLimit.xmlstring(ctx)} $fiatSymbol${_lock_info.getString("lowLimitPrice")} - $fiatSymbol${_lock_info.getString("highLimitPrice")}"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
        }

        //  第五行 总金额输入框  ¥ | 最大金额
        val ly5 = LinearLayout(ctx).apply {
            layoutParams = layout_params_content
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                val placeholder = if (_isBuy) R.string.kOtcInputPlaceholderBuyTotal.xmlstring(ctx) else R.string.kOtcInputPlaceholderSellTotal.xmlstring(ctx)
                _tf_total = EditTextEx(ctx, placeholder, dp_size = 17.0f).apply {
                    // 限制整数和小数
                    inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                    maxLines = 1
                    setSingleLine(true)
                }
                addView(_tf_total)
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(ctx).apply {
                    text = fiatSymbol
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                })
                addView(TextView(ctx).apply {
                    text = " | "
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                })

                addView(TextView(ctx).apply {
                    text = R.string.kOtcInputTailerBtnMaxTotal.xmlstring(ctx)

                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorHighlight))

                    // 最大金额买入或出售
                    setOnClickListener {
                        onButtonTailerClicked(false)
                    }
                })
            })
        }

        // 第六行 交易数量 0 USD
        val ly6 = LinearLayout(ctx).apply {
            layoutParams = layout_params_content
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 10.dp, 10.dp, 0)

            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                _tv_trade_amount = TextView(ctx).apply {
                    text = "${R.string.kOtcInputCellLabelTradeAmount.xmlstring(ctx)} 0 $assetSymbol"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                }

                addView(_tv_trade_amount)
            })
        }

        // 第七行 实际付款(到账)
        val ly7 = LinearLayout(ctx).apply {
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
            layout_params.setMargins(0, 10.dp, 0, 0)
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(ctx).apply {
                    text = if (_isBuy) R.string.kOtcInputCellRealPayment.xmlstring(ctx) else R.string.kOtcInputCellRealReceive.xmlstring(ctx)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                })
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                _tv_trade_total = TextView(ctx).apply {
                    text = "${fiatSymbol}0"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorHighlight))
                }
                addView(_tv_trade_total)
            })
        }

        // 第八行 x秒后自动取消 下单
        val ly8 = LinearLayout(ctx).apply {
            val _layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 32.dp)
            _layout_params.setMargins(0, 10.dp, 0, 20.dp)
            layoutParams = _layout_params
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                val _layoutParams = LinearLayout.LayoutParams(0.dp, 32.dp, 1f)
                _layoutParams.setMargins(0, 0, 3.dp, 0)
                layoutParams = _layoutParams
                gravity = Gravity.CENTER
                setBackgroundColor(ctx.resources.getColor(R.color.theme01_textColorGray))

                _btnAutoClose = TextView(ctx).apply {
                    text = String.format(R.string.kOtcInputAutoCloseSecTips.xmlstring(ctx), _autoCloseSeconds.toString())
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                }
                addView(_btnAutoClose)

                //  事件
                setOnClickListener { onButtomAutoCancelClicked() }
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layoutParams = LinearLayout.LayoutParams(0.dp, 32.dp, 1f)
                _layoutParams.setMargins(3.dp, 0, 0, 0)
                layoutParams = _layoutParams
                gravity = Gravity.CENTER
                if (_isBuy) {
                    setBackgroundColor(ctx.resources.getColor(R.color.theme01_buyColor))
                } else {
                    setBackgroundColor(ctx.resources.getColor(R.color.theme01_sellColor))
                }
                addView(TextView(ctx).apply {
                    text = R.string.kOtcInputBtnCreateOrder.xmlstring(ctx)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                })

                //  事件
                setOnClickListener { onClickBuyOrSellSubmit() }
            })
        }

        layout.addView(layout_titlebar)
        layout.addView(ly1)
        layout.addView(ly2)
        layout.addView(ly3)
        layout.addView(ViewLine(ctx, 0, 0, 10.dp, 10.dp))
        layout.addView(ly4)
        layout.addView(ly5)
        layout.addView(ViewLine(ctx, 0, 0, 10.dp, 10.dp))
        layout.addView(ly6)
        layout.addView(ly7)
        layout.addView(ly8)

        setContentView(layout)

        //  输入框
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(_tf_amount).set_precision(_numPrecision)
        _tf_amount.addTextChangedListener(_tf_amount_watcher)
        _tf_amount_watcher.on_value_changed(::onNumberFieldChanged)

        _tf_total_watcher = UtilsDigitTextWatcher().set_tf(_tf_total).set_precision(_totalPrecision)
        _tf_total.addTextChangedListener(_tf_total_watcher)
        _tf_total_watcher.on_value_changed(::onTotalFieldChanged)

        //  REMARK 部分机型去除标题栏
        val v = this.findViewById<View>(android.R.id.title)
        v?.visibility = View.GONE

        //  自动关闭定时器
        _autoCloseTimerID = AsyncTaskManager.sharedAsyncTaskManager().scheduledSecondsTimer(_autoCloseSeconds) { left_ts ->
            if (left_ts > 0) {
                _btnAutoClose.text = String.format(R.string.kOtcInputAutoCloseSecTips.xmlstring(ctx), left_ts.toString())
            } else {
                onButtomAutoCancelClicked()
            }
        }
    }

    /**
     *  (private) 输入的数量发生变化，评估交易额。
     */
    private fun onNumberFieldChanged(str_amount: String) {
        val n_amount = Utils.auxGetStringDecimalNumberValue(str_amount)
        val n_total = _calc_n_total_from_number(n_amount)

        //  刷新 交易数量 和 最终金额。
        _draw_ui_trade_value(n_amount)
        _draw_ui_final_value(n_total)

        //  总金额
        if (str_amount.isEmpty()) {
            _tf_total_watcher.set_new_text("")
        } else {
            _tf_total_watcher.set_new_text(OrgUtils.formatFloatValue(n_total.toDouble(), _totalPrecision, has_comma = false))
        }
    }

    /**
     *  (private) 输入交易额变化，重新计算交易数量or价格。
     */
    private fun onTotalFieldChanged(str_total: String) {
        val n_total = Utils.auxGetStringDecimalNumberValue(str_total)
        val n_amount = _calc_n_number_from_total(n_total)

        //  刷新 交易数量 和 最终金额。
        _draw_ui_trade_value(n_amount)
        _draw_ui_final_value(n_total)

        //  交易数量
        if (str_total.isEmpty()) {
            _tf_amount_watcher.set_new_text("")
        } else {
            _tf_amount_watcher.set_new_text(OrgUtils.formatFloatValue(n_amount.toDouble(), _numPrecision, has_comma = false))
        }
    }

    private fun _draw_ui_trade_value(n_value: BigDecimal) {
        //  TODO:2.9 是否超过。余额 以及。数量限制
        val assetSymbol = _ad_info.getString("assetSymbol")
        _tv_trade_amount.text = "${R.string.kOtcInputCellLabelTradeAmount.xmlstring(_ctx)} ${OrgUtils.formatFloatValue(n_value.toDouble(), _numPrecision, has_comma = true)} $assetSymbol"
    }

    private fun _draw_ui_final_value(n_final: BigDecimal) {
        //  TODO:2.9 是否超过限额
        val fiatSymbol = OtcManager.sharedOtcManager().getFiatCnyInfo().getString("legalCurrencySymbol")
        _tv_trade_total.text = "$fiatSymbol${OrgUtils.formatFloatValue(n_final.toDouble(), _totalPrecision, has_comma = true)}"
    }

    /**
     *  (private) 根据总金额计算数量
     *  REMARK：买入行为：数量向下取整 卖出行为：数量向上取整
     */
    private fun _calc_n_number_from_total(n_total: BigDecimal): BigDecimal {
        return n_total.divide(_nPrice, _numPrecision, if (_isBuy) BigDecimal.ROUND_DOWN else BigDecimal.ROUND_UP)
    }

    /**
     *  (private) 根据数量计算总金额
     *  REMARK：买入行为：总金额向上取整 卖出行为：向下取整
     */
    private fun _calc_n_total_from_number(n_amount: BigDecimal): BigDecimal {
        return _nPrice.multiply(n_amount).setScale(_totalPrecision, if (_isBuy) BigDecimal.ROUND_UP else BigDecimal.ROUND_DOWN)
    }

    /**
     * 输入框末尾按钮点击
     */
    private fun onButtonTailerClicked(bIsAmountTailer: Boolean) {
        if (bIsAmountTailer) {
            var max_value = _nStockFinal
            //  出售的情况下
            if (!_isBuy) {
                if (max_value > _nBalance) {
                    max_value = _nBalance!!
                }
            }
            _tf_amount_watcher.set_new_text(OrgUtils.formatFloatValue(max_value.toDouble(), _numPrecision, has_comma = false))
            onNumberFieldChanged(_tf_amount.text.toString())
        } else {
            var max_value = _nMaxLimitFinal
            //  出售的情况下
            if (!_isBuy) {
                val sell_max = _calc_n_total_from_number(_nBalance!!)
                if (max_value > sell_max) {
                    max_value = sell_max
                }
            }
            _tf_total_watcher.set_new_text(OrgUtils.formatFloatValue(max_value.toDouble(), _totalPrecision, has_comma = false))
            onTotalFieldChanged(_tf_total.text.toString())
        }
    }

    private fun onClickBuyOrSellSubmit() {
        val str_amount = _tf_amount.text.toString()
        val str_total = _tf_total.text.toString()

        val n_amount = Utils.auxGetStringDecimalNumberValue(str_amount)
        val n_total = Utils.auxGetStringDecimalNumberValue(str_total)

        if (n_total <= BigDecimal.ZERO) {
            (_ctx as Activity).showToast(R.string.kOtcInputSubmitTipTotalZero.xmlstring(_ctx))
            return
        }

        if (n_amount > _nStock) {
            (_ctx as Activity).showToast(R.string.kOtcInputSubmitTipAmountGreatThanStock.xmlstring(_ctx))
            return
        }

        if (_nBalance != null && n_amount > _nBalance!!) {
            (_ctx as Activity).showToast(R.string.kOtcInputSubmitTipAmountGreatThanBalance.xmlstring(_ctx))
            return
        }

        val n_min_limit = Utils.auxGetStringDecimalNumberValue(_lock_info.getString("lowLimitPrice"))
        if (n_total < n_min_limit) {
            (_ctx as Activity).showToast(R.string.kOtcInputSubmitTipTotalLessMinLimit.xmlstring(_ctx))
            return
        }

        if (n_total > _nMaxLimit) {
            (_ctx as Activity).showToast(R.string.kOtcInputSubmitTipTotalGreatMaxLimit.xmlstring(_ctx))
            return
        }

        //  校验完毕，前往下单。
        _handleCloseWithResult(JSONObject().apply {
            put("total", str_total)
        })
    }

    private fun onButtomAutoCancelClicked() {
        _handleCloseWithResult(null)
    }

    /**
     *  (private) 关闭界面
     */
    private fun _handleCloseWithResult(result: JSONObject?) {
        AsyncTaskManager.sharedAsyncTaskManager().removeSecondsTimer(_autoCloseTimerID)
        dismiss()
        _callback(result)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val window = this.window!!
        //  bottom
        window.setGravity(Gravity.BOTTOM)
        //  full screen
        window.decorView.setPadding(0, 0, 0, 0)
        val params: WindowManager.LayoutParams = window.attributes
        params.width = WindowManager.LayoutParams.MATCH_PARENT
        params.height = WindowManager.LayoutParams.WRAP_CONTENT
        window.attributes = params
        window.decorView.setBackgroundColor(Color.GREEN)
        window.setWindowAnimations(R.style.SlideFromBottom)
    }

}