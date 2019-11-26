package com.btsplusplus.fowallet

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.text.InputType
import android.text.SpannableStringBuilder
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.forEach
import com.btsplusplus.fowallet.ViewEx.EditTextEx
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max

class ViewDialogOtcTrade : Dialog {

    var _ctx: Context

    private val content_fontsize = 12.0f

    // 输入数量 Edittext
    private lateinit var _et_input_quantity:EditText

    // 输入金额 Edittext
    private lateinit var _et_input_amount:EditText

    // 交易数量 TextView
    private lateinit var _tv_trade_quantity:TextView

    private var _ad_type: Int
    private var _asset_name: String
    private var _data: JSONObject


    constructor(ctx: Context, asset_name: String, ad_type: Int, data: JSONObject, callback: (index: Int, result: JSONObject) -> Unit) : super(ctx) {

//
//        put("mmerchant_name","吉祥承兑")
//        put("total",3332)
//        put("rate","94%")
//        put("trade_count",1500)
//        put("legal_asset_symbol","¥")
//        put("limit_min","30")
//        put("limit_max","1250")
//        put("price","7.21")
//        put("payment_methods", JSONArray().apply {
//            put("alipay")
//            put("wechat")
//        })
//
//
        _ctx = ctx
        _ad_type = ad_type
        _asset_name = asset_name
        _data = data

        val legal_asset_symbol = data.getString("legal_asset_symbol")
        val limit_min = data.getString("limit_min")
        val limit_max = data.getString("limit_max")
        val trade_type_string = if (ad_type == 1) { "购买" } else { "出售" }


        //  外层 Layout
        val layout = LinearLayout(context)
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_params.leftMargin = 0
        layout_params.rightMargin = 0
        layout.orientation = LinearLayout.VERTICAL
        layout.layoutParams = layout_params
        layout.setBackgroundColor(context.resources.getColor(R.color.theme01_appBackColor))
        layout.setPadding(0,0,0,20.dp)

        //  顶部标题
        val layout_titlebar = LinearLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, 44.dp)
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 0, 0, 0)
            setBackgroundColor(context.resources.getColor(R.color.theme01_tabBarColor))

            addView(TextView(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f).apply {
                    gravity = Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                this.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                val title = String.format("%s %s",trade_type_string,asset_name)
                text = title
                setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                setPadding(0, 0, 10.dp, 0)
            })
        }

        // 中间内容通用的 layout_params
        val layout_params_content = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
        layout_params_content.gravity = Gravity.CENTER_VERTICAL

        // 第一行 单价
        val ly1 = LinearLayout(ctx).apply {
            val _layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            _layout_params.gravity = Gravity.CENTER
            _layout_params.setMargins(0,10.dp,0,10.dp)
            layoutParams = _layout_params
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)
            gravity = Gravity.CENTER

            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER

                addView(TextView(ctx).apply {
                    text = "单价"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                    gravity = Gravity.CENTER
                })

                addView(TextView(ctx).apply {
                    text = String.format("%s%s",legal_asset_symbol,data.getString("price"))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 18.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                    gravity = Gravity.CENTER
                    setPadding(5.dp,0,0,0)
                })
            })
        }


        // 第二行 购买数量标题 购买数量
        val ly2 = LinearLayout(ctx).apply {
            layoutParams = layout_params_content
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(ctx).apply {
                    text = "${trade_type_string}数量"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.LEFT
                })
                // 余额
                if (ad_type == 2){
                    addView(TextView(ctx).apply {
                        text = String.format("余额 %s %s","100.3",legal_asset_symbol)
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                        setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                        gravity = Gravity.CENTER
                        setPadding(5.dp,0,0,0)
                    })
                }
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(ctx).apply {
                    text = String.format("数量 %s %s","2620",asset_name)

                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
        }

        // 第三行 输入框  usd | 全部买入
        val ly3 = LinearLayout(ctx).apply {
            layoutParams = layout_params_content
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                _et_input_quantity = EditTextEx(ctx,"请输入${trade_type_string}数量",dp_size = 17.0f).apply {
                    // 限制整数和小数
                    inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                    maxLines = 1
                    setSingleLine(true)
                }
                addView(_et_input_quantity)
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(ctx).apply {
                    text = asset_name
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                })
                addView(TextView(ctx).apply {
                    text = " | "
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                })
                addView(TextView(ctx).apply {
                    text = "全部${trade_type_string}"

                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorHighlight))

                    // 买入或出售全部数量
                    setOnClickListener {
                        onClickBuyOrSellTotalQuantity()
                    }
                })
            })
        }

        // 第四行 购买金额标题 购买数量
        val ly4 = LinearLayout(ctx).apply {
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
            layout_params.setMargins(0,10.dp,0,0)
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0.dp, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(ctx).apply {
                    text = "${trade_type_string}金额"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.LEFT
                })
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(ctx).apply {
                    text = String.format("限额 %s%s - %s%s",legal_asset_symbol , limit_min, legal_asset_symbol , limit_max)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                })
            })
        }

        // 第五行 输入框  ¥ | 最大金额
        val ly5 = LinearLayout(ctx).apply {
            layoutParams = layout_params_content
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                _et_input_amount = EditTextEx(ctx,"请输入${trade_type_string}金额",dp_size = 17.0f).apply {
                    // 限制整数和小数
                    inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                    maxLines = 1
                    setSingleLine(true)
                }
                addView(_et_input_amount)
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(ctx).apply {
                    text = legal_asset_symbol
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                })
                addView(TextView(ctx).apply {
                    text = " | "
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorGray))
                })
                addView(TextView(ctx).apply {
                    text = "最大金额"

                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorHighlight))

                    // 最大金额买入或出售
                    setOnClickListener {
                        onClickBuyOrSellMaxAmount()
                    }
                })
            })
        }

        // 第六行 交易数量 0 USD
        val ly6 = LinearLayout(ctx).apply {
            layoutParams = layout_params_content
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 10.dp, 10.dp, 0)

            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                _tv_trade_quantity = TextView(ctx).apply {
                    text = String.format("交易数量 %s %s", 0, asset_name)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                }

                addView(_tv_trade_quantity)
            })
        }

        // 第七行 实际付款(到账)
        val ly7 = LinearLayout(ctx).apply {
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 24.dp)
            layout_params.setMargins(0,10.dp,0,0)
            layoutParams = layout_params
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT

                addView(TextView(ctx).apply {
                    text = String.format("实际%s",if (ad_type == 1) { "付款" } else { "到账" })
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER_VERTICAL or Gravity.LEFT
                })
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layout_params = LinearLayout.LayoutParams(0.dp, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                layoutParams = _layout_params
                gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT

                addView(TextView(ctx).apply {
                    text = "${legal_asset_symbol}0"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, content_fontsize)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorHighlight))
                })
            })
        }

        // 第八行 x秒后自动取消 下单
        val ly8 = LinearLayout(ctx).apply {
            val _layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 32.dp)
            _layout_params.setMargins(0,10.dp,0,20.dp)
            layoutParams = _layout_params
            orientation = LinearLayout.HORIZONTAL
            setPadding(10.dp, 0, 10.dp, 0)

            // 左边
            addView(LinearLayout(ctx).apply {
                val _layoutParams = LinearLayout.LayoutParams(0.dp, 32.dp, 1f)
                _layoutParams.setMargins(0,0,3.dp,0)
                layoutParams = _layoutParams
                gravity = Gravity.CENTER
                setBackgroundColor(ctx.resources.getColor(R.color.theme01_textColorNormal))

                addView(TextView(ctx).apply {
                    text = "60秒后自动取消"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                })
            })
            // 右边
            addView(LinearLayout(ctx).apply {
                val _layoutParams = LinearLayout.LayoutParams(0.dp, 32.dp, 1f)
                _layoutParams.setMargins(3.dp,0,0,0)
                layoutParams = _layoutParams
                gravity = Gravity.CENTER

                if (ad_type == 1){
                    setBackgroundColor(ctx.resources.getColor(R.color.theme01_buyColor))
                } else {
                    setBackgroundColor(ctx.resources.getColor(R.color.theme01_sellColor))
                }
                addView(TextView(ctx).apply {
                    text = "下单"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                    setTextColor(ctx.resources.getColor(R.color.theme01_textColorMain))
                    gravity = Gravity.CENTER
                })

                setOnClickListener { onClickBuyOrSellSubmit() }
            })
        }

        layout.addView(layout_titlebar)
        layout.addView(ly1)
        layout.addView(ly2)
        layout.addView(ly3)
        layout.addView(ViewLine(ctx,0,0,10.dp,10.dp))
        layout.addView(ly4)
        layout.addView(ly5)
        layout.addView(ViewLine(ctx,0,0,10.dp,10.dp))
        layout.addView(ly6)
        layout.addView(ly7)
        layout.addView(ly8)

        setContentView(layout)

        //  REMARK 部分机型去除标题栏
        val v = this.findViewById<View>(android.R.id.title)
        v?.visibility = View.GONE

    }

    private fun onClickBuyOrSellTotalQuantity(){
        _et_input_quantity.text = SpannableStringBuilder("9999.99")
    }

    private fun onClickBuyOrSellMaxAmount(){
        _et_input_amount.text = SpannableStringBuilder(_data.getString("limit_max"))
    }

    private fun onClickBuyOrSellSubmit(){

    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val window = this.window!!
        //  bottom
        window.setGravity(Gravity.BOTTOM)
        //  full screen
        window.decorView.setPadding(0, 0, 0, 0)
        val params: WindowManager.LayoutParams = window.attributes
        params.width = WindowManager.LayoutParams.MATCH_PARENT
        params.height = WindowManager.LayoutParams.WRAP_CONTENT
        window.attributes = params
        window.decorView.setBackgroundColor(Color.GREEN)
    }

}