package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_permission_edit.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityPermissionEdit : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_permission_edit)
        setFullScreen()

        tv_permission_type_from_edit_permission.text = "资金权限"

        // 阀值
        tv_threshold_value_from_edit_permission.text = "1"

        val layout_parent = ly_edit_public_key_from_edit_permission

        // 测试数据
        val data = JSONArray().apply {
            for (i in 1 until 11){
                val json = JSONObject().apply {
                    put("account_public_key", "test${i}")
                    put("weight", i * 5)
                    put("percent", i * 5)
                }
                put(json)
            }
        }

        val _this = this

        data.forEach<JSONObject> {
            val data = it!!
            val layout = LinearLayout(_this).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0,5.dp,0,0)
                }
                orientation = LinearLayout.HORIZONTAL

                val layout_left = LinearLayout(_this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL

                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,10.0f).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    }
                    val tv_public_key = TextView(_this).apply {
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        text = data.getString("account_public_key")
                    }
                    addView(tv_public_key)
                }

                val layout_center = LinearLayout(_this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL

                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,4.0f).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    }
                    val tv_weight = TextView(_this).apply {
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        text = "${data.getString("weight")}(${data.getString("percent")}%)"
                    }
                    addView(tv_weight)
                }

                val layout_right = LinearLayout(_this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL

                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,2.0f).apply {
                        gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                    }
                    val tv_remove = TextView(_this).apply {
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                        text = "移除"

                        setOnClickListener {

                        }
                    }
                    addView(tv_remove)
                }

                addView(layout_left)
                addView(layout_center)
                addView(layout_right)


            }


            layout_parent.addView(layout)

        }

        // 修改阀值
        ly_threshold_value_from_edit_permission.setOnClickListener {
            UtilsAlert.showInputBox(this, "新阀值", "请输入新的阀值", "确定").then {
                val threshold_value = it as? String
                if (threshold_value != null) {

                }
            }
        }

        btn_add_one_from_edit_permission.setOnClickListener {
            goTo(ActivityPermissionAddOne::class.java, true)
        }

        btn_submit_from_edit_permission.setOnClickListener {

        }

        layout_back_from_edit_permission.setOnClickListener{
            finish()
        }
    }
}
