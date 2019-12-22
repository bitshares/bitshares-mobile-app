package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.OtcManager
import bitshares.dp
import org.json.JSONObject

class ViewOtcMerchantPaymentCell : LinearLayout {

    private var _ctx: Context
    private var _data: JSONObject

    constructor(ctx: Context, data: JSONObject) : super(ctx) {
        _ctx = ctx
        _data = data
        createUI()
    }

    private fun createUI(): LinearLayout {
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
        layout_params.gravity = Gravity.CENTER_VERTICAL

        val pminfos = OtcManager.auxGenPaymentMethodInfos(_ctx, _data.getString("account"),
                _data.getInt("type"),
                _data.optString("bankName"))

        val layout_wrap = LinearLayout(_ctx)
        layout_wrap.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_wrap.orientation = LinearLayout.VERTICAL
        layout_wrap.setPadding(0, 0, 0, 10.dp)

        // 第一行 商家图标 商家名称 已字符|未支付
        val ly1 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                }
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                val iv = ImageView(_ctx).apply {
                    scaleType = ImageView.ScaleType.FIT_END
                    gravity = Gravity.LEFT
                }

                iv.setImageDrawable(resources.getDrawable(pminfos.getInt("icon")))
                addView(iv)

                addView(TextView(_ctx).apply {
                    text = pminfos.getString("name")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                    setPadding(5.dp, 0, 0, 0)
                })
            })

            // 右边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                addView(TextView(_ctx).apply {
                    if (_data.getInt("status") == OtcManager.EOtcPaymentMethodStatus.eopms_enable.value) {
                        text = resources.getString(R.string.kOtcPmCellStatusEnabled)
                        setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                    } else {
                        text = resources.getString(R.string.kOtcPmCellStatusDisabled)
                        setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    }
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
                    gravity = Gravity.CENTER
                    setPadding(5.dp, 0, 0, 0)
                })
            })
        }

        // 第二行 姓名
        val ly2 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = _data.optString("realName")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
                    gravity = Gravity.LEFT
                })
            })
        }

        // 第三行 账号 or 银行卡号
        val ly3 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = _data.optString("account")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.LEFT
                })
            })
        }

        layout_wrap.addView(ly1)
        layout_wrap.addView(ly2)
        layout_wrap.addView(ly3)
        layout_wrap.addView(ViewLine(_ctx, 5.dp, 0.dp))

        addView(layout_wrap)
        return this
    }
}