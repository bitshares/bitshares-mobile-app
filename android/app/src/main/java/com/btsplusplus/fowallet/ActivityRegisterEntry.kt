package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.ImageView
import android.widget.TextView
import kotlinx.android.synthetic.main.activity_register_entry.*

class ActivityRegisterEntry : BtsppActivity() {

    lateinit var _et_account_name: EditText

    lateinit var _iv_unchecked_include_letter_digit: ImageView
    lateinit var _iv_checked_include_letter_digit: ImageView
    lateinit var _iv_unchecked_start_with_letter: ImageView
    lateinit var _iv_checked_start_with_letter: ImageView
    lateinit var _iv_unchecked_end_with_letter_digit: ImageView
    lateinit var _iv_checked_end_with_letter_digit: ImageView
    lateinit var _iv_unchecked_include_digit: ImageView
    lateinit var _iv_checked_include_digit: ImageView
    lateinit var _iv_unchecked_length3to32: ImageView
    lateinit var _iv_checked_length3to32: ImageView
    lateinit var _tv_include_letter_digit: TextView
    lateinit var _tv_start_with_letter: TextView
    lateinit var _tv_end_with_letter_digit: TextView
    lateinit var _tv_include_digit: TextView
    lateinit var _tv_length3to32: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_register_entry)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        _et_account_name = et_account_name_from_register_entry

        // 各种 checkbox 和 textview 初始化
        _iv_unchecked_include_letter_digit = iv_unchecked_include_letter_digit_from_register_entry
        _iv_checked_include_letter_digit = iv_checked_include_letter_digit_from_register_entry
        _iv_unchecked_start_with_letter = iv_unchecked_start_with_letter_from_register_entry
        _iv_checked_start_with_letter = iv_checked_start_with_letter_from_register_entry
        _iv_unchecked_end_with_letter_digit = iv_unchecked_end_with_letter_digit_from_register_entry
        _iv_checked_end_with_letter_digit = iv_checked_end_with_letter_digit_from_register_entry
        _iv_unchecked_include_digit = iv_unchecked_include_digit_from_register_entry
        _iv_checked_include_digit = iv_checked_include_digit_from_register_entry
        _iv_unchecked_length3to32 = iv_unchecked_length3to32_from_register_entry
        _iv_checked_length3to32 = iv_checked_length3to32_from_register_entry

        _tv_include_letter_digit = tv_include_letter_digit_from_register_entry
        _tv_start_with_letter = tv_start_with_letter_from_register_entry
        _tv_end_with_letter_digit = tv_end_with_letter_digit_from_register_entry
        _tv_include_digit = tv_include_digit_from_register_entry
        _tv_length3to32 = tv_length3to32_from_register_entry

        // 默认不选中
        unCheckAllCheckbox()

        // 返回按钮事件
        layout_back_from_register_entry.setOnClickListener { finish() }

        // 下一步按钮事件
        button_next_from_register_entry.setOnClickListener { onNextButtonClicked() }

    }

    private fun unCheckAllCheckbox(){
        switchIncludeLetterDigit(false)
        switchStartWithLetter(false)
        switchEndWithLetterDigit(false)
        switchInclueDigit(false)
        switchLength3to32(false)
    }

    private fun switchIncludeLetterDigit(checked: Boolean){
        if (checked) {
            _iv_unchecked_include_letter_digit.visibility = View.GONE
            _iv_checked_include_letter_digit.visibility = View.VISIBLE
            _iv_checked_include_letter_digit.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
            _tv_include_letter_digit.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            _iv_unchecked_include_letter_digit.visibility = View.VISIBLE
            _iv_checked_include_letter_digit.visibility = View.GONE
            _iv_unchecked_include_letter_digit.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            _tv_include_letter_digit.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    private fun switchStartWithLetter(checked: Boolean){
        if (checked) {
            _iv_unchecked_start_with_letter.visibility = View.GONE
            _iv_checked_start_with_letter.visibility = View.VISIBLE
            _iv_checked_start_with_letter.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
            _tv_start_with_letter.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            _iv_unchecked_start_with_letter.visibility = View.VISIBLE
            _iv_checked_start_with_letter.visibility = View.GONE
            _iv_unchecked_start_with_letter.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            _tv_start_with_letter.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    private fun switchEndWithLetterDigit(checked: Boolean){
        if (checked) {
            _iv_unchecked_end_with_letter_digit.visibility = View.GONE
            _iv_checked_end_with_letter_digit.visibility = View.VISIBLE
            _iv_checked_end_with_letter_digit.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
            _tv_end_with_letter_digit.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            _iv_unchecked_end_with_letter_digit.visibility = View.VISIBLE
            _iv_checked_end_with_letter_digit.visibility = View.GONE
            _iv_unchecked_end_with_letter_digit.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            _tv_end_with_letter_digit.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    private fun switchInclueDigit(checked: Boolean){
        if (checked) {
            _iv_unchecked_include_digit.visibility = View.GONE
            _iv_checked_include_digit.visibility = View.VISIBLE
            _iv_checked_include_digit.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
            _tv_include_digit.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            _iv_unchecked_include_digit.visibility = View.VISIBLE
            _iv_checked_include_digit.visibility = View.GONE
            _iv_unchecked_include_digit.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            _tv_include_digit.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    private fun switchLength3to32(checked: Boolean){
        if (checked) {
            _iv_unchecked_length3to32.visibility = View.GONE
            _iv_checked_length3to32.visibility = View.VISIBLE
            _iv_checked_length3to32.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
            _tv_length3to32.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            _iv_unchecked_length3to32.visibility = View.VISIBLE
            _iv_checked_length3to32.visibility = View.GONE
            _iv_unchecked_length3to32.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            _tv_length3to32.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    private fun onNextButtonClicked(){

    }
}
