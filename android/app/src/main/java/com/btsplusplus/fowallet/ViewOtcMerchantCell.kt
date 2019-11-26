package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.dp
import bitshares.forEach
import bitshares.toList
import bitshares.xmlstring
import org.json.JSONArray
import org.json.JSONObject

class ViewOtcMerchantCell  : LinearLayout {

    var _ctx: Context
    var _asset_name: String
    var _ad_type: Int
    var _data: JSONObject

     private val content_fontsize = 12.0f

    constructor(ctx: Context, asset_name: String, ad_type: Int, data: JSONObject) : super(ctx) {
        _ctx = ctx
        _asset_name = asset_name
        _ad_type = ad_type
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
                    text = _data.getString("mmerchant_name").first().toString()
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    background = _ctx.resources.getDrawable(R.drawable.border_text_view)
                    gravity = Gravity.CENTER
                })

                addView(TextView(_ctx).apply {
                    text = _data.getString("mmerchant_name")
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                    setPadding(5.dp,0,0,0)
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = String.format("%s 笔 | %s",_data.getInt("total"), _data.getString("rate"))

                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
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
                    text = "数量"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                })

                addView(TextView(_ctx).apply {
                    text = String.format("%s %s",_data.getInt("trade_count").toString(),_asset_name)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    gravity = Gravity.CENTER
                    setPadding(5.dp,0,0,0)
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = "单价"

                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
        }


        // 第三行 限额 价格
        val ly3 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text =  String.format("%s%s - %s%s",_data.getString("legal_asset_symbol"), _data.getString("limit_min"),_data.getString("legal_asset_symbol"), _data.getString("limit_max"))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                })

                addView(TextView(_ctx).apply {
                    text = _data.getInt("trade_count").toString()
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    gravity = Gravity.CENTER
                    setPadding(5.dp,0,0,0)
                })
            })
            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(_ctx).apply {
                    text = String.format("%s%s",_data.getString("legal_asset_symbol"),_data.getString("price"))

                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorHighlight))
                })
            })
        }


        // 第四行 支付宝 微信 购买/出售
        val ly4 = LinearLayout(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 40.dp)
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                _data.getJSONArray("payment_methods").forEach<String> {
                    val payment_method = it!!

                    val iv = ImageView(_ctx).apply {
                        scaleType = ImageView.ScaleType.FIT_END
                        gravity = Gravity.LEFT
                    }
                    if (payment_method == "wechat"){
                        iv.setImageDrawable(resources.getDrawable(R.drawable.icon_htlc_preimage))
                    }
                    if (payment_method == "alipay"){
                        iv.setImageDrawable(resources.getDrawable(R.drawable.icon_htlc_hashcode))
                    }
                    addView(iv)
                }


            })

            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, 32.dp, 1f)
                layoutParams = _layout_params
                gravity = Gravity.TOP or Gravity.RIGHT

                val button_buy_or_sell = TextView(_ctx).apply {
                    if(_ad_type == 1) {
                        text = resources.getString(R.string.kLabelTitleBuy)
                        setBackgroundColor(resources.getColor(R.color.theme01_buyColor))
                    } else {
                        text = resources.getString(R.string.kLabelTitleSell)
                        setBackgroundColor(resources.getColor(R.color.theme01_sellColor))
                    }
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.TOP
                    setPadding(20.dp,5.dp,20.dp,5.dp)
                }
                button_buy_or_sell.setOnClickListener {
                    if(_ad_type == 1) {
                        onBuyButtonClicked()
                    } else {
                        onSellButtonClicked()
                    }
                }
                addView(button_buy_or_sell)
            })
        }

        layout_wrap.addView(ly1)
        layout_wrap.addView(ly2)
        layout_wrap.addView(ly3)
        layout_wrap.addView(ly4)
        layout_wrap.addView(ViewLine(_ctx, 0.dp, 0.dp))

        addView(layout_wrap)
        return this
    }

    private fun onBuyButtonClicked(){
        ViewDialogOtcTrade(_ctx,_asset_name,_ad_type,_data){ _index: Int, result_data: JSONObject ->

        }.show()
    }

    private fun onSellButtonClicked(){
        ViewDialogOtcTrade(_ctx,_asset_name,_ad_type,_data){ _index: Int, result_data: JSONObject ->

        }.show()
    }
}