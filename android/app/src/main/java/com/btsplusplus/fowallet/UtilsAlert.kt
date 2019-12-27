package com.btsplusplus.fowallet

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.text.InputFilter
import android.text.InputType
import android.text.method.DigitsKeyListener
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import bitshares.*
import org.json.JSONObject

class UtilsAlert {
    companion object {

        /**
         * show toast
         */
        private var _last_toast: Toast? = null

        fun showToast(ctx: Context, text: String, duration: Int) {
            _last_toast?.cancel()
            _last_toast = android.widget.Toast.makeText(ctx, text, duration)
            _last_toast?.show()
        }

        /**
         * 显示输入对话框
         */
        fun showInputBox(ctx: Context, title: String, placeholder: String,
                         btn_ok: String = ctx.resources.getString(R.string.kBtnOK),
                         btn_cancel: String = ctx.resources.getString(R.string.kBtnCancel),
                         is_password: Boolean = true, tfcfg: ((tf: EditText) -> Unit)? = null, iDecimalPrecision: Int = -1, iMaxLength: Int = -1): Promise {
            val p = Promise()

            //  输入框
            val edit = EditText(ctx)
            val padding = Utils.toDp(20.0f, ctx.resources)
            edit.setPadding(padding, padding, padding, padding)
            edit.hint = placeholder

            //  限制最大输入长度
            if (iMaxLength > 0) {
                edit.filters = arrayOf(InputFilter.LengthFilter(iMaxLength))
            }

            if (iDecimalPrecision > 0) {
                //  输入：小数
                edit.inputType = InputType.TYPE_CLASS_NUMBER.or(InputType.TYPE_NUMBER_FLAG_DECIMAL)
                edit.maxLines = 1
                edit.setSingleLine(true)
                //  小数输入的默认长度
                if (iMaxLength <= 0) {
                    edit.filters = arrayOf(InputFilter.LengthFilter(12 + iDecimalPrecision))
                }
                edit.keyListener = DigitsKeyListener.getInstance(".1234567890")
                edit.addTextChangedListener(UtilsDigitTextWatcher().set_tf(edit).set_precision(iDecimalPrecision))
            } else if (iDecimalPrecision == 0) {
                //  输入：正整数
                edit.inputType = InputType.TYPE_CLASS_NUMBER
                edit.maxLines = 1
                edit.setSingleLine(true)
                //  整数输入的默认长度
                if (iMaxLength <= 0) {
                    edit.filters = arrayOf(InputFilter.LengthFilter(12))
                }
                edit.keyListener = DigitsKeyListener.getInstance("1234567890")
            } else {
                //  输入：普通文本or密码
                if (is_password) {
                    edit.inputType = InputType.TYPE_CLASS_TEXT.or(InputType.TYPE_TEXT_VARIATION_PASSWORD)
                } else {
                    edit.inputType = InputType.TYPE_CLASS_TEXT
                }
            }

            //  自定义配置放在最后（可选）
            if (tfcfg != null) {
                tfcfg(edit)
            }

            //  对话框
            val builder = AlertDialog.Builder(ctx)
            builder.setTitle(title)
            builder.setView(edit)
            builder.setPositiveButton(btn_ok) { dialog, _ ->
                dialog.dismiss()
                p.resolve(edit.text.toString())
            }
            builder.setNegativeButton(btn_cancel) { dialog, _ ->
                dialog.dismiss()
                p.resolve(null)
            }
            builder.setCancelable(false)

            val act = ctx as? Activity
            if (act != null && !act.isFinishing) {
                builder.show()
            } else {
                p.resolve(null)
            }

            return p
        }

        /**
         * 显示确认对话框
         */
        fun showMessageConfirm(
                ctx: Context, title: String?,
                message: String,
                btn_ok: String? = ctx.resources.getString(R.string.kBtnOK),
                btn_cancel: String? = ctx.resources.getString(R.string.kBtnCancel),
                link: JSONObject? = null
        ): Promise {
            val p = Promise()

            var dig: AlertDialog? = null
            val builder = AlertDialog.Builder(ctx)

            builder.setTitle(title ?: "")
            builder.setMessage(message)

            if (link != null) {
                val link_text = link.getString("text")
                val link_url = link.getString("url")

                builder.setView(TextView(ctx).apply {

                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                        gravity = Gravity.CENTER
                    }
                    gravity = Gravity.CENTER

                    setPadding(0, 40.dp, 0, 0)

                    text = link_text

                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 17.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorHighlight))

                    setOnClickListener {
                        (ctx as Activity).goToWebView("", link_url)
                    }
                })
            }

            builder.setOnKeyListener { _, keyCode, _ ->
                if (keyCode == KeyEvent.KEYCODE_BACK) {
                    //  REMARK：cancel 按钮存在的时候，返回键才默认按照 cancel 行为处理。不存在则禁止返回键。
                    if (btn_cancel != null && dig != null) {
                        dig!!.dismiss()
                        p.resolve(false)
                    }
                    return@setOnKeyListener false
                }
                return@setOnKeyListener true
            }

            if (btn_ok != null) {
                builder.setPositiveButton(btn_ok) { dialog, _ ->
                    dialog.dismiss()
                    p.resolve(true)
                }
            }

            if (btn_cancel != null) {
                builder.setNegativeButton(btn_cancel) { dialog, _ ->
                    dialog.dismiss()
                    p.resolve(false)
                }
            }

            builder.setCancelable(false)

            val act = ctx as? Activity
            if (act != null && !act.isFinishing) {
                dig = builder.create()
                dig?.show()
            } else {
                p.resolve(false)
            }

            return p
        }

        /**
         * 显示messagebox
         */
        fun showMessageBox(ctx: Context, message: String, title: String? = null, btn_ok: String? = ctx.resources.getString(R.string.kBtnOK)) {
            val builder = AlertDialog.Builder(ctx)
            builder.setTitle(title ?: ctx.resources.getString(R.string.kWarmTips))
            builder.setMessage(message)
            if (btn_ok != null) {
                builder.setPositiveButton(btn_ok) { dialog, _ ->
                    dialog.dismiss()
                }
            }
            if (ctx is Activity) {
                if (!ctx.isFinishing) {
                    builder.create().show()
                }
            }
        }
    }
}