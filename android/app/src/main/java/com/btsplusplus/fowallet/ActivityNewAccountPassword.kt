package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_WARP
import bitshares.dp
import kotlinx.android.synthetic.main.activity_new_account_password.*

lateinit var _layout_password_line1: LinearLayout
lateinit var _layout_password_line2: LinearLayout

class ActivityNewAccountPassword : BtsppActivity() {

    var is_zh_password_lang = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_new_account_password)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        _layout_password_line1 = layout_password_line1_from_new_account_password
        _layout_password_line2 = layout_password_line2_from_new_account_password

        tv_tip_from_new_account_password.text = "【温馨提示】\n xxxxxxxxxxx \n xxxxxxxxxxx."

        // 切换语言
        tv_toggle_password_lang.setOnClickListener {
            onTogglePasswordLang()
        }

        // 返回
        layout_back_from_new_account_password.setOnClickListener { finish() }

        // 下一步
        btn_next_from_new_account_password.setOnClickListener {
            onNextButtonClick()
        }

        refreshPasswordUI()
    }

    // 刷新密码区域UI
    private fun refreshPasswordUI(){
        _layout_password_line1.removeAllViews()
        _layout_password_line2.removeAllViews()

        val list = if (is_zh_password_lang){
            arrayOf("哈","哈","哈","哈","哈","哈","哈","哈","哈","哈","哈","哈","哈","哈","哈","哈")
        } else {
            arrayOf("a123","b456","c789","d012","aaaa","bbbb","cccc","dddd")
        }

        list.forEachIndexed { index, word ->
            val view = TextView(this).apply {

                val width = if (is_zh_password_lang){ 0.125f } else { 0.25f }

                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,width).apply {
                    gravity = Gravity.CENTER
                }
                gravity = Gravity.CENTER
                text = word
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
            }

            if (is_zh_password_lang) {
                if (index <= 7) {
                    _layout_password_line1.addView(view)
                } else {
                    _layout_password_line2.addView(view)
                }
            } else {
                if (index <= 3) {
                    _layout_password_line1.addView(view)
                } else {
                    _layout_password_line2.addView(view)
                }
            }
        }
    }

    // 切换语言
    private fun onTogglePasswordLang(){
        if (is_zh_password_lang){
            tv_toggle_password_lang.text = "切换英文密码"
        } else {
            tv_toggle_password_lang.text = "切换中文密码"
        }
        is_zh_password_lang = !is_zh_password_lang
        refreshPasswordUI()
    }

    // 下一步
    private fun onNextButtonClick(){
        goTo(ActivityNewAccountPasswordConfirm::class.java,true)
    }
}
