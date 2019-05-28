package com.btsplusplus.fowallet

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.text.InputType
import android.view.KeyEvent
import android.widget.EditText
import android.widget.Toast
import bitshares.Promise
import bitshares.Utils

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
        fun showInputBox(ctx: Context, title: String, placeholder: String, btn_ok: String = ctx.resources.getString(R.string.kBtnOK), btn_cancel: String = ctx.resources.getString(R.string.kBtnCancel), is_password: Boolean = true): Promise {
            val p = Promise()

            //  输入框
            val edit = EditText(ctx)
            val padding = Utils.toDp(20.0f, ctx.resources)
            edit.setPadding(padding, padding, padding, padding)
            edit.hint = placeholder
            if (is_password) {
                edit.inputType = InputType.TYPE_CLASS_TEXT.or(InputType.TYPE_TEXT_VARIATION_PASSWORD)
            } else {
                edit.inputType = InputType.TYPE_CLASS_TEXT
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
        fun showMessageConfirm(ctx: Context, title: String?, message: String, btn_ok: String? = ctx.resources.getString(R.string.kBtnOK), btn_cancel: String? = ctx.resources.getString(R.string.kBtnCancel)): Promise {
            val p = Promise()

            var dig: AlertDialog? = null
            val builder = AlertDialog.Builder(ctx)

            builder.setTitle(title ?: "")
            builder.setMessage(message)
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