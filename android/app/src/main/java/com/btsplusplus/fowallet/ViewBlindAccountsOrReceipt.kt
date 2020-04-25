package com.btsplusplus.fowallet

import android.content.Context
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.forEach
import kotlinx.android.synthetic.main.fragment_main_buy.view.*
import org.json.JSONArray
import org.json.JSONObject
import org.w3c.dom.Text

class ViewBlindAccountsOrReceipt : LinearLayout {
    private var _ctx: Context
    lateinit var _data: JSONArray
    var _view_type: String
    var _layout_parent: LinearLayout

    constructor(ctx: Context, view_type: String, layout_parent: LinearLayout, data: JSONArray) : super(ctx) {
        _ctx = ctx
        _view_type = view_type
        _layout_parent = layout_parent
        setDataAndRefreshUI(data)
    }

    private fun setDataAndRefreshUI(data: JSONArray){
        _data = data
        refreshUI()
    }

    private fun addItemLineAndRefreshUI(data: JSONObject){
        _data.put(data)
        refreshUI()
    }

    private fun removeItemAndRefreshUI(index: Int){
        _data.remove(index)
        refreshUI()
    }

    fun refreshUI() {
        _layout_parent.removeAllViews()

        _layout_parent.addView(createBlindAddressHeader())

        var index: Int = 0
        _data.forEach<JSONObject> {
            _layout_parent.addView(createBlindAddressCell(it!!,index))
            index++
        }
        _layout_parent.addView(createAddButton())
    }

    private fun isTypeBlindAccount() : Boolean {
        return _view_type == "blind_account"
    }

    private fun getTestData() : JSONObject {
        val data = JSONObject().apply {
            put("address",if (isTypeBlindAccount()) { "TEST7UPXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" } else { "收据 #1D5CBADEAAEDF" })
            put("quantity","100")
            put("operation","移除")
        }
        return data
    }

    // 创建添加按钮
    private fun createAddButton() : LinearLayout {
        val layout = LinearLayout(_ctx)
        layout.layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
            gravity = Gravity.CENTER
            setMargins(0,15.dp,0,0)
        }
        layout.orientation = LinearLayout.HORIZONTAL
        layout.gravity = Gravity.CENTER

        // + icon
        // Todo 换图标
        val iv_button = ImageView(_ctx).apply {
            gravity = Gravity.CENTER_VERTICAL
            scaleType = ImageView.ScaleType.FIT_END
            setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
            setImageDrawable(resources.getDrawable(R.drawable.ic_btn_star))
        }

        // button name
        val tv_name = TextView(_ctx).apply {
            setPadding(5.dp,0,0,0)
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,6.0f)
            if (isTypeBlindAccount()){
                text = "添加输出"
            } else {
                text = "选择收据"
            }
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
            setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
        }

        layout.setOnClickListener {
            addItemLineAndRefreshUI(getTestData())
        }

        layout.addView(iv_button)
        layout.addView(tv_name)

        return layout
    }

    // 创建头部字段
    private fun createBlindAddressHeader() : LinearLayout{

        // 父容器
        val layout = LinearLayout(_ctx)
        layout.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0,8.dp,0,0)
        }
        layout.orientation = LinearLayout.HORIZONTAL

        // TextView - blind adress or receipt
        val tv_blind_address = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,6.0f)
            if (isTypeBlindAccount()){
                text = "隐私地址(${_data.length()})"
            } else {
                text = "隐私收据(${_data.length()})"
            }
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
            setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }

        // TextView - quantity
        val tv_quantity = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,3.0f)
            text = "数量"
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
            setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }

        // TextView - quantity
        val tv_operation = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1.0f)
            text = "操作"
            gravity = Gravity.RIGHT
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
            setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }

        layout.addView(tv_blind_address)
        layout.addView(tv_quantity)
        layout.addView(tv_operation)
        return layout
    }

    // 创建隐私列表 cell
    private fun createBlindAddressCell(data: JSONObject,index: Int) : LinearLayout{

        // 父容器
        val layout = LinearLayout(_ctx)
        layout.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0,8.dp,0,0)
        }
        layout.orientation = LinearLayout.HORIZONTAL

        // TextView - blind adress
        val tv_blind_address = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,6.0f)
            text = data.getString("address")
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
            setTextColor(resources.getColor(R.color.theme01_textColorMain))
            setSingleLine(true)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        // TextView - quantity
        val tv_quantity = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,3.0f)
            text = data.getString("quantity")
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
            setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }

        // TextView - quantity
        val tv_operation = TextView(_ctx).apply {
            layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1.0f)
            text = data.getString("operation")
            gravity = Gravity.RIGHT
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
            setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
            setOnClickListener {
                removeItemAndRefreshUI(index)
            }
        }

        layout.addView(tv_blind_address)
        layout.addView(tv_quantity)
        layout.addView(tv_operation)
        return layout
    }
}