package com.btsplusplus.fowallet

import android.content.Context
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import org.json.JSONArray
import org.json.JSONObject

class ViewBlindReceiptCell : LinearLayout {
    private var _ctx: Context
    var _data: JSONObject
    var _can_check: Boolean = false
    var _index: Int = 0
    var _asset_symbol: String = ""
    var _onChecked: ((index: Int, checked: Boolean) -> Unit)? = null

    constructor(ctx: Context, data: JSONObject, asset_symbol: String, index: Int, can_check: Boolean, onChecked: ((index: Int, checked: Boolean) -> Unit)? = null ) : super(ctx) {
        _ctx = ctx
        _data = data
        _can_check = can_check
        _asset_symbol = asset_symbol
        _index = index
        _onChecked = onChecked

        this.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0, 15.dp,0,0)
        }
        this.orientation = LinearLayout.HORIZONTAL

        refreshUI()
    }

    private fun refreshUI(){

        val asset_number = _data.getString("number")
        val asset_id = _data.getString("id")
        val asset_amount = _data.getString("amount")

        var right_content_margin_value = 0.dp
        if (_can_check){
            val checkbox = CheckBox(_ctx)
            val checkbox_layout_params = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_MATCH).apply {
                gravity = Gravity.LEFT
                setMargins(0,0,0,0)
            }
            checkbox_layout_params.gravity = LinearLayout.VERTICAL
            checkbox.setPadding(0,0,0,0)
            checkbox.layoutParams = checkbox_layout_params
            checkbox.text = ""
            checkbox.isChecked = false
            checkbox.tag = "checkbox.$_index"
            checkbox.scaleX = 0.5f
            checkbox.scaleY = 0.5f
            checkbox.gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
            val checkbox_drawable = resources.getDrawable(R.drawable.checkbox_drawable)
            checkbox.buttonDrawable = checkbox_drawable

            checkbox.setOnCheckedChangeListener { _, isChecked ->
                if (_onChecked != null) {
                    _onChecked!!.invoke(_index,isChecked)
                }
            }


            this.addView(checkbox)

            right_content_margin_value = 10.dp
        }

        val layout_wrapper = LinearLayout(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                setMargins(right_content_margin_value, 0, 0, 0)
            }
            orientation = LinearLayout.VERTICAL


            // 第一行 - 收据编号
            val tv_receipt_number = TextView(_ctx).apply {
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                text = "${_index}.收据 #${asset_number}"
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
            }

            // 第二行 - 左: 地址, 右: 金额
            val layout_header = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 8.dp, 0, 0)
                }
                orientation = LinearLayout.HORIZONTAL

                // 地址(名称)
                val tv_address = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 3f)
                    text = "地址"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorGray))
                }

                // 金额(名称)
                val tv_amount = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2f)
                    text = "金额"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    gravity = Gravity.RIGHT
                }

                addView(tv_address)
                addView(tv_amount)
            }


            // 第三行 - 左: 地址(值), 右: 金额(值)
            val layout_body = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 8.dp, 0, 0)
                }
                orientation = LinearLayout.HORIZONTAL

                // 地址(value)
                val tv_address_value = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 3f)
                    text = "${asset_id}"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setSingleLine(true)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                }

                // 金额(value)
                val tv_amount_value = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2f)
                    text = "${asset_amount} ${_asset_symbol}"
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    gravity = Gravity.RIGHT
                }

                addView(tv_address_value)
                addView(tv_amount_value)
            }

            addView(tv_receipt_number)
            addView(layout_header)
            addView(layout_body)
        }
        this.addView(layout_wrapper)
    }
}