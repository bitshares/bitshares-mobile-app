package com.btsplusplus.fowallet

import android.content.Context
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.OtcManager
import bitshares.dp
import bitshares.isTrue
import bitshares.xmlstring
import org.json.JSONObject

class ViewOtcMerchantCell : LinearLayout {

    private var _ctx: Context
    private var _user_type = OtcManager.EOtcUserType.eout_normal_user
    private var _data: JSONObject
    private var _callback: (JSONObject) -> Unit

    private val content_fontsize = 12.0f

    constructor(ctx: Context, user_type: OtcManager.EOtcUserType, data: JSONObject, callback: (JSONObject) -> Unit) : super(ctx) {
        _ctx = ctx
        _user_type = user_type
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

        //  获取数据
        val assetSymbol = _data.getString("assetSymbol")
        val fiat_sym = OtcManager.sharedOtcManager().getFiatCnyInfo().getString("legalCurrencySymbol")

        //  第一行
        //  用户端：商家头像 + 商家名称 ----- 统计数据
        //  商家端：商家买卖 + 资产
        val ly1 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL
            if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                // 左边
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT


                    addView(TextView(_ctx).apply {
                        text = _data.getString("merchantNickname").substring(0, 1)
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
                        text = _data.getString("merchantNickname")
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        gravity = Gravity.CENTER
                        setPadding(5.dp, 0, 0, 0)
                    })
                })
//                // 右边 TODO;2.9 miss dasta
//                addView(LinearLayout(_ctx).apply {
//                    val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
//                    layoutParams = _layout_params
//                    gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
//
//                    addView(TextView(_ctx).apply {
//                        text = "" //String.format("%s 笔 | %s", _data.getInt("total"), _data.getString("rate"))
//
//                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
//                        setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
//                    })
//                })
            } else {
                addView(LinearLayout(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                    addView(TextView(_ctx).apply {
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        if (_data.getInt("adType") == OtcManager.EOtcAdType.eoadt_merchant_buy.value) {
                            text = R.string.kOtcAdCellLabelMcMerchantBuy.xmlstring(_ctx)
                            setTextColor(_ctx.resources.getColor(R.color.theme01_buyColor))
                        } else {
                            text = R.string.kOtcAdCellLabelMcMerchantSell.xmlstring(_ctx)
                            setTextColor(_ctx.resources.getColor(R.color.theme01_sellColor))
                        }
                    })
                    addView(TextView(_ctx).apply {
                        text = assetSymbol
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        gravity = Gravity.CENTER
                        setPadding(5.dp, 0, 0, 0)
                    })
                })
            }
        }

        // 第二行 数量 单价标题
        val ly2 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            //  左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(_ctx).apply {
                    text = R.string.kOtcAdCellLabelAmount.xmlstring(_ctx)
                    setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    gravity = Gravity.CENTER
                })

                addView(TextView(_ctx).apply {
                    text = String.format("%s %s", _data.getString("stock"), assetSymbol)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    gravity = Gravity.CENTER
                    setPadding(5.dp, 0, 0, 0)
                })
            })

            //  右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                addView(TextView(_ctx).apply {
                    text = R.string.kOtcAdCellLabelUnitPrice.xmlstring(_ctx)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
        }

        // 第三行 限额 价格价格
        val ly3 = LinearLayout(_ctx).apply {
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                //  限额
                addView(TextView(_ctx).apply {
                    text = R.string.kOtcAdCellLabelLimit.xmlstring(_ctx)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorGray))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    gravity = Gravity.CENTER
                })

                //  限额范围
                addView(TextView(_ctx).apply {
                    text = "$fiat_sym${_data.getString("lowestLimit")} - $fiat_sym${_data.getString("maxLimit")}"
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    gravity = Gravity.CENTER
                    setPadding(5.dp, 0, 0, 0)
                })
            })

            // 右边 - 单价价格
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                addView(TextView(_ctx).apply {
                    text = "$fiat_sym${_data.getString("price")}"
                    paint.isFakeBoldText = true
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 19.0f)
                    setTextColor(_ctx.resources.getColor(R.color.theme01_textColorHighlight))
                })
            })
        }

        // 第四行 支付宝 微信 购买/出售/上架/下架
        val ly4 = LinearLayout(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 40.dp)
            orientation = LinearLayout.HORIZONTAL

            // 左边
            addView(LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                //  银行卡
                if (_data.isTrue("bankcardPaySwitch")) {
                    val iv = ImageView(_ctx).apply {
                        scaleType = ImageView.ScaleType.FIT_END
                        gravity = Gravity.LEFT
                        setPadding(0, 0, 12, 0)
                    }
                    iv.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_bankcard))
                    addView(iv)
                }

                //  支付宝
                if (_data.isTrue("aliPaySwitch")) {
                    val iv = ImageView(_ctx).apply {
                        scaleType = ImageView.ScaleType.FIT_END
                        gravity = Gravity.LEFT
                        setPadding(0, 0, 12, 0)
                    }
                    iv.setImageDrawable(resources.getDrawable(R.drawable.icon_pm_alipay))
                    addView(iv)
                }
            })

            // 右边
            addView(LinearLayout(_ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, 28.dp, 1f)
                layoutParams = _layout_params
                gravity = Gravity.TOP or Gravity.RIGHT

                val ad_type = _data.getInt("adType")
                //  用户端：买卖 商家端：上架/下架
                if (_user_type == OtcManager.EOtcUserType.eout_normal_user) {
                    val button_buy_or_sell = TextView(_ctx).apply {
                        if (ad_type == OtcManager.EOtcAdType.eoadt_user_buy.value) {
                            text = resources.getString(R.string.kLabelTitleBuy)
                            setBackgroundColor(resources.getColor(R.color.theme01_buyColor))
                        } else {
                            text = resources.getString(R.string.kLabelTitleSell)
                            setBackgroundColor(resources.getColor(R.color.theme01_sellColor))
                        }
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                        gravity = Gravity.TOP
                        setPadding(20.dp, 5.dp, 20.dp, 5.dp)
                    }
                    button_buy_or_sell.setOnClickListener { _callback(_data) }
                    addView(button_buy_or_sell)
                } else {
                    //  商家端按钮
                    val ad_status = _data.getInt("status")
                    if (ad_status != OtcManager.EOtcAdStatus.eoads_deleted.value) {
                        val button_ad_down = TextView(_ctx).apply {
                            text = if (ad_status == OtcManager.EOtcAdStatus.eoads_online.value) {
                                R.string.kOtcAdCellLabelMcBtnDown.xmlstring(_ctx)
                            } else {
                                R.string.kOtcAdCellLabelMcBtnReup.xmlstring(_ctx)
                            }
                            setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
                            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                            setTextColor(resources.getColor(R.color.theme01_textColorMain))
                            gravity = Gravity.TOP
                            setPadding(20.dp, 5.dp, 20.dp, 5.dp)
                        }
                        button_ad_down.setOnClickListener { _callback(_data) }
                        addView(button_ad_down)
                    }
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
}