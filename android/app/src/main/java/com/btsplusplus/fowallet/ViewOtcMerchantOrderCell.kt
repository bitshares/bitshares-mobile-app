package com.btsplusplus.fowallet

import android.app.Activity
import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.Utils
import bitshares.dp
import bitshares.forEach
import org.json.JSONObject

class ViewOtcMerchantOrderCell  : LinearLayout {

    var _ctx: Context
    var _data: JSONObject

    constructor(ctx: Context, data: JSONObject) : super(ctx) {
        _ctx = ctx
        _data = data
        createUI()
    }

    private fun createUI(): LinearLayout {
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
        layout_params.gravity = Gravity.CENTER_VERTICAL

        val layout_wrap = LinearLayout(_ctx)
        layout_wrap.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_wrap.orientation = LinearLayout.VERTICAL
        layout_wrap.setPadding(0,0,0,10.dp)

        // 第一行 商家图标 商家名称 交易总数|成交比
        val ly1 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    val order_type = _data.getInt("order_type")
                    if (order_type == 1) {
                        text = "购买"
                        setTextColor(_ctx.resources.getColor(R.color.theme01_buyColor))
                    } else {
                        text = "出售"
                        setTextColor(_ctx.resources.getColor(R.color.theme01_sellColor))
                    }
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
                    gravity = Gravity.CENTER
                })

                addView(TextView(_ctx).apply {
                    text = _data.getString("asset_name")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                    setPadding(5.dp,0,0,0)
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                _layout_params.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = "退款已确认"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                    gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                })

                val iv = ImageView(_ctx).apply {
                    scaleType = ImageView.ScaleType.FIT_END
                    setImageDrawable(resources.getDrawable(R.drawable.ic_btn_right_arrow))
                    gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                    setColorFilter(resources.getColor(R.color.theme01_textColorGray))
                }
                addView(iv)
            })
        }
        ly1.setOnClickListener { onOrderClicked() }


        // 第二行 数量 单价
        val ly2 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = "时间"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                    gravity = Gravity.LEFT
                })
            })
            // 中间
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                addView(TextView(_ctx).apply {
                    text = "数量${_data.getString("asset_name")}"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                    gravity = Gravity.CENTER
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = "总金额${_data.getString("legal_symbol")}"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
        }


        // 第三行 数量 单价
        val ly3 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = _data.getString("time")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
                    gravity = Gravity.LEFT
                })
            })
            // 中间
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                addView(TextView(_ctx).apply {
                    text = _data.getString("quantity")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
                    gravity = Gravity.CENTER
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = _data.getString("price")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
                })
            })
        }


        // 第四行 支付宝 微信 购买/出售
        val ly4 = LinearLayout(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(TextView(_ctx).apply {
                text = _data.getString("merchant_name")
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                gravity = Gravity.LEFT
            })
        }

        layout_wrap.addView(ly1)
        layout_wrap.addView(ly2)
        layout_wrap.addView(ly3)
        layout_wrap.addView(ly4)
        layout_wrap.addView(ViewLine(_ctx, 10.dp, 0.dp))

        addView(layout_wrap)
        return this
    }

    private fun onOrderClicked(){
        (_ctx as Activity).showToast("点击了该订单")
    }

}