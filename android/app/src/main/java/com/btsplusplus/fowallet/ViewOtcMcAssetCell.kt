package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.dp
import org.json.JSONObject

class ViewOtcMcAssetCell : LinearLayout {

    private var _ctx: Context
    private var _data: JSONObject
    private var _callback: (Boolean) -> Unit

    private val content_fontsize = 12.0f

    constructor(ctx: Context, data: JSONObject, callback: (Boolean) -> Unit) : super(ctx) {
        _ctx = ctx
        _data = data
        _callback = callback
        createUI()
    }

    private fun createUI(): LinearLayout {
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
        layout_params.gravity = Gravity.CENTER_VERTICAL

        val layout_wrap = LinearLayout(_ctx)
        layout_wrap.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_wrap.orientation = LinearLayout.VERTICAL
        layout_wrap.setPadding(0, 0, 0, 10.dp)

        // 第一行 商家图标 商家名称 交易总数|成交比
        val ly1 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 第一行 资产名称
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = _data.getString("assetSymbol")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                })
            })
        }

        // 第二行 可用 冻结 平台手续费(文本)
        val ly2 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = resources.getString(R.string.kOtcMcAssetListCellAvailable)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
            // 中间
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                addView(TextView(_ctx).apply {
                    text = resources.getString(R.string.kOtcMcAssetListCellFreeze)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = resources.getString(R.string.kOtcMcAssetListCellFees)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
        }

        // 第三行 可用 冻结 平台手续费(值)
        val ly3 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = _data.getString("available")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
                })
            })
            // 中间
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                addView(TextView(_ctx).apply {
                    text = _data.getString("freeze")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = _data.getString("fees")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorNormal))
                })
            })
        }

        // 第四行 转入 转出 (操作)

        // 第三行 可用 冻结 平台手续费(值)
        val ly4 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 转入
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                addView(TextView(_ctx).apply {
                    text = resources.getString(R.string.kOtcMcAssetBtnTransferIn)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorHighlight))
                    setOnClickListener { _callback(true) }
                })
            })
            // 转出
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                addView(TextView(_ctx).apply {
                    text = resources.getString(R.string.kOtcMcAssetBtnTransferOut)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorHighlight))
                    setOnClickListener { _callback(false) }
                })
            })
        }

        layout_wrap.addView(ly1)
        layout_wrap.addView(ly2)
        layout_wrap.addView(ly3)
        layout_wrap.addView(ly4)

        addView(layout_wrap)
        return this
    }
}