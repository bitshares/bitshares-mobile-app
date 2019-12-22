package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.OtcManager
import bitshares.dp
import bitshares.xmlstring
import org.json.JSONObject

class ViewOtcMerchantOrderCell : LinearLayout {

    private var _ctx: Context
    private var _data: JSONObject
    private var _user_type: OtcManager.EOtcUserType

    constructor(ctx: Context, data: JSONObject, user_type: OtcManager.EOtcUserType) : super(ctx) {
        _ctx = ctx
        _data = data
        _user_type = user_type
        createUI()
    }

    private fun createUI(): LinearLayout {
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
        layout_params.gravity = Gravity.CENTER_VERTICAL

        val status_infos = OtcManager.auxGenOtcOrderStatusAndActions(_ctx, _data, _user_type)
        val prefix = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) "" else R.string.kOtcOrderCellTitleMerchantPrefix.xmlstring(_ctx)
        val pending = status_infos.optBoolean("pending")

        val layout_wrap = LinearLayout(_ctx)
        layout_wrap.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_wrap.orientation = LinearLayout.VERTICAL
        layout_wrap.setPadding(0, 0, 0, 10.dp)

        // 第一行 商家图标 商家名称 交易总数|成交比
        val ly1 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    if (!status_infos.optBoolean("sell")) {
                        text = "$prefix${R.string.kOtcOrderCellTitleBuy.xmlstring(_ctx)}"
                        setTextColor(_ctx.resources.getColor(R.color.theme01_buyColor))
                    } else {
                        text = "$prefix${R.string.kOtcOrderCellTitleSell.xmlstring(_ctx)}"
                        setTextColor(_ctx.resources.getColor(R.color.theme01_sellColor))
                    }
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
                    gravity = Gravity.CENTER
                })

                addView(TextView(_ctx).apply {
                    text = _data.getString("assetSymbol")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                    setPadding(5.dp, 0, 0, 0)
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                _layout_params.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = "${status_infos.getString("main")} >"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                    if (pending) {
                        setTextColor(_ctx.resources.getColor(R.color.theme01_textColorHighlight))
                    } else {
                        setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                    }
                    gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                })
            })
        }

        // 第二行 数量 单价
        val ly2 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = R.string.kLabelTradeHisTitleTime.xmlstring(_ctx)
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
                    text = "${R.string.kLabelTradeHisTitleAmount.xmlstring(_ctx)}(${_data.getString("assetSymbol")})"
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
                    text = "${R.string.kVcOrderTotal.xmlstring(_ctx)}(${_data.getString("legalCurrencySymbol")})"
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
                    text = OtcManager.fmtOrderListTime(_data.getString("ctime"))
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
                    text = _data.getString("amount")
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
                text = if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                    _data.getString("merchantNickname")
                } else {
                    _data.getString("userAccount")
                }
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

}