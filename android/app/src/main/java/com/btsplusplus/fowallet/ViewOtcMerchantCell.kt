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
    var _entry: String = ""
    var _asset_name: String
    var _data: JSONObject

     private val content_fontsize = 12.0f

    constructor(ctx: Context, entry: String,asset_name: String, data: JSONObject) : super(ctx) {
        _ctx = ctx
        _entry = entry
        _asset_name = asset_name
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

        // 第一行
        // entry = otc_mc_list : 商家图标 商家名称 交易总数|成交比
        // entry = otc_ad_list : 商家购买|商家出售 asset_name
        val ly1 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            if (_entry == "otc_mc_list"){
                // 左边
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT


                    addView(TextView(_ctx).apply {
                        text = _data.getString("mmerchant_name").first().toString()
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                        background = _ctx.resources.getDrawable(R.drawable.circle_character_view)

                        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                            width = 22.dp
                            height = 22.dp
                        }
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
            if (_entry == "otc_ad_list") {
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                    addView(TextView(_ctx).apply {
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        if (_data.getInt("ad_type") == 1) {
                            text = "商家购买"
                            setTextColor(_ctx.resources.getColor(R.color.theme01_buyColor))
                        } else {
                            text = "商家出售"
                            setTextColor(_ctx.resources.getColor(R.color.theme01_sellColor))
                        }
                    })
                    addView(TextView(_ctx).apply {
                        text = _asset_name
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        gravity = Gravity.CENTER
                        setPadding(5.dp,0,0,0)
                    })
                })
            }
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

                    if (_entry == "otc_mc_list") {
                        setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    } else if (_entry == "otc_ad_list") {
                        setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                    }

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

                    if (_entry == "otc_mc_list"){
                        text =  String.format("%s%s - %s%s",_data.getString("legal_asset_symbol"), _data.getString("limit_min"),_data.getString("legal_asset_symbol"), _data.getString("limit_max"))
                        setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
                    } else if (_entry == "otc_ad_list") {
                        text = "限额"
                        setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                    }
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)

                    gravity = Gravity.CENTER
                })

                addView(TextView(_ctx).apply {

                    if (_entry == "otc_mc_list"){
                        text = _data.getInt("trade_count").toString()
                    } else if (_entry == "otc_ad_list") {
                        text =  String.format("%s%s - %s%s",_data.getString("legal_asset_symbol"), _data.getString("limit_min"),_data.getString("legal_asset_symbol"), _data.getString("limit_max"))
                    }
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)

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
                        setPadding(0,0,5,0)
                    }
                    if (payment_method == "alipay"){
                        iv.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_alipay))
                    }
                    if (payment_method == "bankcard"){
                        iv.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_bankcard))
                    }
                    addView(iv)
                }


            })

            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, 32.dp, 1f)
                layoutParams = _layout_params
                gravity = Gravity.TOP or Gravity.RIGHT

                val ad_type = _data.getInt("ad_type")

                if (_entry == "otc_mc_list"){
                    val button_buy_or_sell = TextView(_ctx).apply {
                        if(ad_type == 1) {
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
                        if(ad_type == 1) {
                            onBuyButtonClicked()
                        } else {
                            onSellButtonClicked()
                        }
                    }
                    addView(button_buy_or_sell)
                }
                if (_entry == "otc_ad_list") {
                    val button_ad_down = TextView(_ctx).apply {
                        text = "下架"
                        setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        gravity = Gravity.TOP
                        setPadding(20.dp,5.dp,20.dp,5.dp)
                    }
                    button_ad_down.setOnClickListener {
                        onAdDownButtonClicked()
                    }
                    addView(button_ad_down)
                }
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

    private fun onAdDownButtonClicked(){

    }

    private fun onBuyButtonClicked(){
        val ad_type = _data.getInt("ad_type")
        ViewDialogOtcTrade(_ctx,_asset_name,ad_type,_data){ _index: Int, result_data: JSONObject ->

        }.show()
    }

    private fun onSellButtonClicked(){
        val ad_type = _data.getInt("ad_type")
        ViewDialogOtcTrade(_ctx,_asset_name,ad_type,_data){ _index: Int, result_data: JSONObject ->

        }.show()
    }
}