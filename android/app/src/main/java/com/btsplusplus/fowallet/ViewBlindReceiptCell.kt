package com.btsplusplus.fowallet

import android.content.Context
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONObject

class ViewBlindReceiptCell : LinearLayout {
    private var _ctx: Context
    private var _blind_balance: JSONObject
    private var _can_check: Boolean = false
    private var _index: Int = 0
    private var _onChecked: ((index: Int, checked: Boolean) -> Unit)? = null

    private var _check_box: CheckBox? = null
    private var _tv_receipt_number: TextView? = null

    constructor(ctx: Context, blind_balance: JSONObject, index: Int, can_check: Boolean, onChecked: ((index: Int, checked: Boolean) -> Unit)? = null) : super(ctx) {
        _ctx = ctx
        _blind_balance = blind_balance
        _can_check = can_check
        _index = index
        _onChecked = onChecked

        this.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0, 15.dp, 0, 0)
        }
        this.orientation = LinearLayout.HORIZONTAL

        refreshUI()
    }

    /**
     *  设置默认是否选中状态
     */
    fun setDefaultSelectedStatus(selected: Boolean) {
        _check_box?.let {
            it.isChecked = selected
            if (selected) {
                _tv_receipt_number?.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            } else {
                _tv_receipt_number?.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            }
            return@let
        }
    }

    private fun refreshUI() {
        //  准备数据
        val decrypted_memo = _blind_balance.getJSONObject("decrypted_memo")
        val amount_item = decrypted_memo.getJSONObject("amount")
        val check_sum = decrypted_memo.getLong("check")
        val hex_check_num = BinSerializer().write_u32(check_sum).get_data().hexEncode().toUpperCase()
        val asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(amount_item.getString("asset_id"))
        val n_amount = bigDecimalfromAmount(amount_item.getString("amount"), asset.getInt("precision"))
        val real_to_key = _blind_balance.getString("real_to_key")

        //  描绘（选择框、可能不存在）
        var right_content_margin_value = 0.dp
        if (_can_check) {
            val checkbox = CheckBox(_ctx)
            val checkbox_layout_params = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_MATCH).apply {
                gravity = Gravity.LEFT
                setMargins(0, 0, 0, 0)
            }
            checkbox_layout_params.gravity = LinearLayout.VERTICAL
            checkbox.setPadding(0, 0, 0, 0)
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
                if (isChecked) {
                    _tv_receipt_number?.setTextColor(resources.getColor(R.color.theme01_textColorMain))
                } else {
                    _tv_receipt_number?.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                }
                _onChecked?.invoke(_index, isChecked)
            }
            this.addView(checkbox)
            right_content_margin_value = 10.dp
            _check_box = checkbox
        }

        //  数据展示
        val layout_wrapper = LinearLayout(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                setMargins(right_content_margin_value, 0, 0, 0)
            }
            orientation = LinearLayout.VERTICAL

            //  第一行 - 收据编号
            _tv_receipt_number = TextView(_ctx).apply {
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                text = String.format(resources.getString(R.string.kVcStCellTitleReceiptName), (_index + 1).toString(), hex_check_num)
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
            }

            //  第二行 - 左: 地址, 右: 金额
            val layout_header = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 8.dp, 0, 0)
                }
                orientation = LinearLayout.HORIZONTAL

                //  地址(名称)
                val alias_name = ViewUtils.genBlindAccountDisplayName(_ctx, real_to_key)
                val tv_address = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 3f)
                    if (alias_name != null && alias_name.isNotEmpty()) {
                        text = String.format(resources.getString(R.string.kVcStCellTitleReceiptAddrWithAliasName), alias_name)
                    } else {
                        text = resources.getString(R.string.kVcStCellTitleReceiptAddr)
                    }
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorGray))
                }

                // 金额(名称)
                val tv_amount = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2f)
                    text = resources.getString(R.string.kVcStCellTitleReceiptAmountValue)
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    gravity = Gravity.RIGHT
                }

                addView(tv_address)
                addView(tv_amount)
            }

            //  第三行 - 左: 地址(值), 右: 金额(值)
            val layout_body = LinearLayout(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                    setMargins(0, 8.dp, 0, 0)
                }
                orientation = LinearLayout.HORIZONTAL

                //  地址(value)
                val tv_address_value = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 3f)
                    text = real_to_key
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setSingleLine(true)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.MIDDLE
                }

                //  金额(value)
                val tv_amount_value = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2f)
                    text = String.format("%s %s", n_amount.toPriceAmountString(), asset.getString("symbol"))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    gravity = Gravity.RIGHT
                }

                addView(tv_address_value)
                addView(tv_amount_value)
            }

            addView(_tv_receipt_number)
            addView(layout_header)
            addView(layout_body)
        }
        this.addView(layout_wrapper)
    }
}