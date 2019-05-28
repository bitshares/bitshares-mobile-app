package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import kotlinx.android.synthetic.main.activity_setting_language.*
import org.json.JSONObject

class ActivitySettingLanguage : BtsppActivity() {

    private lateinit var _result_promise: Promise

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_setting_language)

        //  获取参数 / get params
        val args = btspp_args_as_JSONObject()
        _result_promise = args.get("result_promise") as Promise

        setFullScreen()

        var currLangCode = LangManager.sharedLangManager().currLangCode
        val langCodeMarkHash = JSONObject()
        val data_array = LangManager.sharedLangManager().data_array
        data_array.forEach<JSONObject> {
            val item = it!!

            val layout = ViewUtils.createLinearLayout(this, LinearLayout.LayoutParams.MATCH_PARENT, 34.dp, null, null, LinearLayout.HORIZONTAL, topMargin = 15)

            val tv = TextView(this)
            val tv_layout = ViewUtils.createLinearLayout(this, 0, LinearLayout.LayoutParams.WRAP_CONTENT, 9f, Gravity.CENTER_VERTICAL, null)
            val iv_layout = ViewUtils.createLinearLayout(this, 14f.dp.toInt(), 14f.dp.toInt(), 0.5f, Gravity.CENTER_VERTICAL or Gravity.RIGHT, null)

            tv.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            tv.gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

            //  货币单位格式
            val langName = resources.getString(resources.getIdentifier(item.getString("langNameKey"), "string", this.packageName))
            val langCode = item.getString("langCode")
            tv.text = langName

            //  是否选中
            val iv = ImageView(this)
            iv.setImageResource(R.drawable.ic_btn_check)
            if (langCode == currLangCode) {
                iv.visibility = View.VISIBLE
            } else {
                iv.visibility = View.INVISIBLE
            }
            langCodeMarkHash.put(langCode, iv)

            tv_layout.addView(tv, ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            iv_layout.addView(iv, ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            layout.addView(tv_layout)
            layout.addView(iv_layout)

            val line = ViewUtils.createLine(this)

            layout_wrap_of_language.addView(layout)
            layout_wrap_of_language.addView(line)

            //  点击事件
            layout.tag = langCode
            layout.setOnClickListener {
                if (langCode != currLangCode) {
                    //  变更可见性
                    (langCodeMarkHash.get(currLangCode) as View).visibility = View.INVISIBLE
                    (langCodeMarkHash.get(langCode) as View).visibility = View.VISIBLE
                    //  [统计]
                    btsppLogCustom("selectLanguage", jsonObjectfromKVS("langCode", currLangCode))
                    //  变更设置
                    currLangCode = langCode
                    onChangeLanguage(currLangCode)
                }
            }
        }

        layout_back_from_setting_language.setOnClickListener { onBackClicked(false) }
    }

    override fun onBackClicked(result: Any?) {
        _result_promise.resolve(true)
        super.onBackClicked(result)
    }

    private fun onChangeLanguage(langCode: String) {
        LangManager.sharedLangManager().setLocale(this, langCode, true)
        recreate()
    }
}
