package com.btsplusplus.fowallet

import android.content.Context
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

/**
 *  视图类型
 */
const val kBlindItemTypeInput = 0
const val kBlindItemTypeOutput = 1

class ViewBlindAccountsOrReceipt : LinearLayout {
    private var _ctx: Context
    private var _view_type: Int
    private var _layout_parent: LinearLayout
    private var _callback_remove: ((idx: Int) -> Unit)?
    private var _callback_add: (() -> Unit)?

    constructor(ctx: Context, view_type: Int, layout_parent: LinearLayout, callback_remove: ((idx: Int) -> Unit)? = null, callback_add: (() -> Unit)? = null) : super(ctx) {
        _ctx = ctx
        _view_type = view_type
        _layout_parent = layout_parent
        _callback_remove = callback_remove
        _callback_add = callback_add
    }

    fun refreshUI(data_array: JSONArray? = null) {
        _layout_parent.removeAllViews()
        _layout_parent.addView(createBlindAddressHeader(data_array))
        if (data_array != null) {
            var index = 0
            data_array.forEach<JSONObject> {
                _layout_parent.addView(createBlindAddressCell(it!!, index))
                index++
            }
        }
        _layout_parent.addView(createAddButton())
    }

    private fun isTypeBlindAccount(): Boolean {
        return _view_type == kBlindItemTypeOutput
    }

    //  创建添加按钮
    private fun createAddButton(): LinearLayout {
        val layout = LinearLayout(_ctx)
        layout.layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
            gravity = Gravity.CENTER
            setMargins(0, 15.dp, 0, 0)
        }
        layout.orientation = LinearLayout.HORIZONTAL
        layout.gravity = Gravity.CENTER

        //  按钮图标
        val iv_button = ImageView(_ctx).apply {
            gravity = Gravity.CENTER_VERTICAL
            scaleType = ImageView.ScaleType.FIT_END
            setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
            setImageDrawable(resources.getDrawable(R.drawable.icon_add))
        }

        //  按钮名字
        val tv_name = TextView(_ctx).apply {
            setPadding(5.dp, 0, 0, 0)
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 6.0f)
            text = if (isTypeBlindAccount()) {
                resources.getString(R.string.kVcStBtnAddBlindOutput)
            } else {
                resources.getString(R.string.kVcStBtnSelectReceipt)
            }
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
        }

        //  事件 - 添加
        layout.setOnClickListener { _callback_add?.invoke() }

        layout.addView(iv_button)
        layout.addView(tv_name)

        return layout
    }

    //  创建头部字段
    private fun createBlindAddressHeader(data_array: JSONArray?): LinearLayout {
        val data_size = data_array?.length() ?: 0

        //  父容器
        val layout = LinearLayout(_ctx)
        layout.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0, 8.dp, 0, 0)
        }
        layout.orientation = LinearLayout.HORIZONTAL

        //  TextView - blind adress or receipt
        val tv_blind_address = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 5.0f)
            text = if (isTypeBlindAccount()) {
                String.format(resources.getString(R.string.kVcStCellTitleBlindAccountWithN), data_size.toString())
            } else {
                String.format(resources.getString(R.string.kVcStCellTitleBlindReceiptWithN), data_size.toString())
            }
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }

        //  TextView - quantity
        val tv_quantity = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 3.0f).apply {
                setMargins(12.dp, 0, 0, 0)
            }
            text = resources.getString(R.string.kVcStCellTitleOutputAmount)
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }

        //  TextView - quantity
        val tv_operation = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2.0f)
            text = resources.getString(R.string.kVcStCellTitleOperation)
            gravity = Gravity.RIGHT
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }

        layout.addView(tv_blind_address)
        layout.addView(tv_quantity)
        layout.addView(tv_operation)
        return layout
    }

    //  创建隐私列表 cell
    private fun createBlindAddressCell(data: JSONObject, index: Int): LinearLayout {

        // 父容器
        val layout = LinearLayout(_ctx)
        layout.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0, 8.dp, 0, 0)
        }
        layout.orientation = LinearLayout.HORIZONTAL

        //  自动找零颜色调整
        val maincolor = if (data.optBoolean("bAutoChange")) resources.getColor(R.color.theme01_textColorGray) else resources.getColor(R.color.theme01_textColorMain)

        //  TextView - 地址or收据
        val tv_blind_address = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 5.0f)
            when (_view_type) {
                kBlindItemTypeInput -> {
                    val decrypted_memo = data.getJSONObject("decrypted_memo")
                    val hex_check_num = BinSerializer().write_u32(decrypted_memo.getLong("check")).get_data().hexEncode().toUpperCase()
                    text = String.format(resources.getString(R.string.kVcStCellValueReceiptValue), hex_check_num)
                    ellipsize = TextUtils.TruncateAt.END
                }
                kBlindItemTypeOutput -> {
                    text = data.getString("public_key")
                    ellipsize = TextUtils.TruncateAt.MIDDLE
                }
                else -> assert(false)
            }
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            setTextColor(maincolor)
            setSingleLine(true)
            maxLines = 1
        }

        //  TextView - 数量
        val tv_quantity = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 3.0f).apply {
                setMargins(12.dp, 0, 0, 0)
            }
            when (_view_type) {
                kBlindItemTypeInput -> {
                    val amount = data.getJSONObject("decrypted_memo").getJSONObject("amount")
                    val asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(amount.getString("asset_id"))
                    val n_amount = bigDecimalfromAmount(amount.getString("amount"), asset.getInt("precision"))
                    text = n_amount.toPriceAmountString()
                    ellipsize = TextUtils.TruncateAt.END
                }
                kBlindItemTypeOutput -> {
                    text = (data.get("n_amount") as BigDecimal).toPriceAmountString()
                }
                else -> assert(false)
            }
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            setTextColor(maincolor)
        }

        //  TextView - 操作
        val tv_operation = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 2.0f)
            if (data.optBoolean("bAutoChange")) {
                //  自动找零
                text = resources.getString(R.string.kVcStCellOperationKindAutoChange)
                setTextColor(maincolor)
            } else {
                //  移除
                text = resources.getString(R.string.kVcStCellOperationKindRemove)
                setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                //  事件 - 移除
                setOnClickListener { _callback_remove?.invoke(index) }
            }
            gravity = Gravity.RIGHT
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
        }

        layout.addView(tv_blind_address)
        layout.addView(tv_quantity)
        layout.addView(tv_operation)
        return layout
    }
}