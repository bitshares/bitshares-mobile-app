package com.btsplusplus.fowallet

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import com.btsplusplus.fowallet.kline.TradingPair
import org.json.JSONArray
import android.graphics.PorterDuff
import android.util.TypedValue
import android.view.Gravity
import android.widget.*
import bitshares.dp
import bitshares.forEach
import org.json.JSONObject
import android.widget.SeekBar
import android.util.DisplayMetrics


// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentTradeBuyOrSell.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentTradeBuyOrSell.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentTradeBuyOrSell : BtsppFragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null

    private var _isbuy: Boolean = true
    lateinit var _ctx: Context
    lateinit var _view: View
    lateinit var _tradingPair: TradingPair

    lateinit var _et_price: EditText                             // 价格输入框
    lateinit var _et_quantity: EditText                          // 数量输入框
    lateinit var _et_amount: EditText                            // 金额输入框
    lateinit var _seekbar: SeekBar                               // 买卖数量的滑动条

    lateinit var _tv_available: TextView                         // 可用数量
    lateinit var _tv_fee: TextView                               // 手续费
    lateinit var _btn_submit: Button                             // 提交按钮

    lateinit var _layout_trade_history: LinearLayout             // 交易历史layout
    lateinit var _layout_buy_list: LinearLayout                  // 买单列表
    lateinit var _layout_sell_list: LinearLayout                 // 卖单列表

    lateinit var _tv_last_price: TextView                        // 最新价格
    lateinit var _tv_last_price_rate: TextView                   // 价格涨跌幅百分比

    lateinit var SHARED_LAYOUT_PARAMS: LinearLayout.LayoutParams // 列表左右结构的共享 layoutParams

    override fun onInitParams(args: Any?) {
        val json_array = args as JSONArray
        _isbuy = json_array.getBoolean(0)
        _tradingPair = json_array.get(1) as TradingPair
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            param1 = it.getString(ARG_PARAM1)
            param2 = it.getString(ARG_PARAM2)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {

        _view = inflater.inflate(R.layout.fragment_trade_buy_or_sell, container, false)
        _ctx = inflater.context

        // 获取界面元素
        _et_price = _view.findViewById(R.id.et_price_from_trade_buy_or_sell)
        _et_quantity = _view.findViewById(R.id.et_quantity_from_trade_buy_or_sell)
        _et_amount = _view.findViewById(R.id.et_amount_from_trade_buy_or_sell)
        _seekbar = _view.findViewById(R.id.seekbar_from_trade_buy_or_sell)
        _tv_available = _view.findViewById(R.id.tv_available_from_trade_buy_or_sell)
        _tv_fee = _view.findViewById(R.id.tv_fee_from_trade_buy_or_sell)
        _btn_submit = _view.findViewById(R.id.btn_submit_from_trade_buy_or_sell)
        _layout_trade_history = _view.findViewById(R.id.layout_trade_histroy_from_trade_buy_or_sell)
        _layout_buy_list = _view.findViewById(R.id.layout_buy_list_from_trade_buy_or_sell)
        _layout_sell_list = _view.findViewById(R.id.layout_sell_list_from_trade_buy_or_sell)
        _tv_last_price = _view.findViewById(R.id.tv_last_price_from_trade_buy_or_sell)
        _tv_last_price_rate = _view.findViewById(R.id.tv_last_price_rate_from_trade_buy_or_sell)

        // 配置公共 LayoutParams
        SHARED_LAYOUT_PARAMS = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(26f))
        SHARED_LAYOUT_PARAMS.gravity = Gravity.CENTER_VERTICAL

        // 配置滑动条颜色和图标
        val seek_color = if (_isbuy) { R.color.theme01_buyColor } else { R.color.theme01_sellColor }
        val seek_icon = if (_isbuy) { R.drawable.icon_explorer } else { R.drawable.icon_explorer }

        _seekbar.thumb = resources.getDrawable(seek_icon)
        _seekbar.getProgressDrawable().setColorFilter(resources.getColor(seek_color),PorterDuff.Mode.SRC_ATOP)

        // 可用资产数量
        _tv_available.text = "19.9992923819BTS"

        // 手续费
        _tv_fee.text = "0.1%"

        // 计算右侧列表ScrollView高度
        calcOrderScrollViewHeight()

        // 提交按钮文字和颜色
        _btn_submit.setTextColor(_ctx.resources.getColor(R.color.theme01_textColorMain))
        if (_isbuy) {
            _btn_submit.text =  "买入BTS"
            _btn_submit.setBackgroundColor(_ctx.resources.getColor(R.color.theme01_buyColor))
        } else {
            _btn_submit.text =  "卖出BTS"
            _btn_submit.setBackgroundColor(_ctx.resources.getColor(R.color.theme01_sellColor))
        }

        // 当前价格 % 涨跌百分比 和 颜色设置
        _tv_last_price.text = "0.236"
        _tv_last_price.setTextColor(_ctx.resources.getColor(R.color.theme01_buyColor))
        _tv_last_price_rate.text = "+0.35%"
        _tv_last_price_rate.setTextColor(_ctx.resources.getColor(R.color.theme01_buyColor))

        refreshUI()

        bindUIEvents()

        return _view

    }

    private fun bindUIEvents(){
        // 买入或卖出 提交事件
        _btn_submit.setOnClickListener {

        }

        // 买卖数量滑动条滑动事件

        // 价格输入框onChange事件

        // 数量输入框onChange事件

        // 交易额输入框onChange事件
    }

    // 生成交易历史左右结构的 价格 数量 视图
    private fun createHistoryCell(is_buy: Boolean,price: String, quantity: String) : LinearLayout {
        val layout = LinearLayout(_ctx)
        layout.orientation = LinearLayout.HORIZONTAL
        layout.layoutParams = SHARED_LAYOUT_PARAMS
        layout.gravity = Gravity.CENTER_VERTICAL

        val tv_price = TextView(_ctx)
        tv_price.text = price
        tv_price.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        if (is_buy){
            tv_price.setTextColor(_ctx.resources.getColor( R.color.theme01_buyColor ))
        } else {
            tv_price.setTextColor(_ctx.resources.getColor( R.color.theme01_sellColor ))
        }

        val tv_quantity = TextView(_ctx)
        tv_quantity.text = quantity
        tv_quantity.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv_quantity.setTextColor(_ctx.resources.getColor( R.color.theme01_textColorNormal ))
        tv_quantity.gravity = Gravity.RIGHT
        tv_quantity.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)

        layout.addView(tv_price)
        layout.addView(tv_quantity)

        return layout
    }


    // 生成买卖挂单列表的 Cell
    private fun createBuyOrSellOrderCell(index: Int, is_buy: Boolean, price: String, quantity: String, isMyOrder: Boolean) : FrameLayout {
        val layout_wrap = FrameLayout(_ctx)

        val layout = LinearLayout(_ctx)
        layout.orientation = LinearLayout.HORIZONTAL
        layout.layoutParams = SHARED_LAYOUT_PARAMS
        layout.gravity = Gravity.CENTER_VERTICAL

        val tv_dot = TextView(_ctx)
        tv_dot.layoutParams = LinearLayout.LayoutParams(12.dp, LinearLayout.LayoutParams.WRAP_CONTENT)

        tv_dot.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv_dot.setTextColor(_ctx.resources.getColor( R.color.theme01_textColorNormal ))
        if (isMyOrder){
            tv_dot.text = "●"
        }

        val tv_index = TextView(_ctx)
        tv_index.layoutParams = LinearLayout.LayoutParams(16.dp, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv_index.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv_index.text = index.toString()
        tv_index.setTextColor(_ctx.resources.getColor( R.color.theme01_textColorNormal ))


        val tv_price = TextView(_ctx)
        tv_price.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv_price.text = price
        tv_price.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        if (is_buy){
            tv_price.setTextColor(_ctx.resources.getColor( R.color.theme01_buyColor ))
        } else {
            tv_price.setTextColor(_ctx.resources.getColor( R.color.theme01_sellColor ))
        }

        val tv_quantity = TextView(_ctx)
        tv_quantity.setPadding(0,0,5.dp,0)
        tv_quantity.layoutParams = LinearLayout.LayoutParams(16.dp, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv_quantity.text = quantity
        tv_quantity.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 11.0f)
        tv_quantity.setTextColor(_ctx.resources.getColor( R.color.theme01_textColorNormal ))
        tv_quantity.gravity = Gravity.RIGHT
        tv_quantity.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)

        layout.addView(tv_dot)
        layout.addView(tv_index)
        layout.addView(tv_price)
        layout.addView(tv_quantity)


        val layout_view_block = LinearLayout(_ctx)
        layout_view_block.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 26.dp).apply {
            gravity = Gravity.RIGHT
        }
        layout_view_block.gravity = Gravity.RIGHT
        val view_block = View(_ctx)
        view_block.layoutParams = LinearLayout.LayoutParams((index*5).dp, 26.dp).apply {
            gravity = Gravity.RIGHT
        }
        if (is_buy){
            view_block.setBackgroundColor(_ctx.resources.getColor(R.color.theme01_buyColor))
        } else {
            view_block.setBackgroundColor(_ctx.resources.getColor(R.color.theme01_sellColor))
        }
        view_block.background.alpha = 100

        layout_view_block.addView(view_block)
        layout_wrap.addView(layout_view_block)
        layout_wrap.addView(layout)

        return layout_wrap
    }


    fun refreshUI(){

        // REMARK: 测试数据
        val test_data = JSONArray().apply {
            for(i in 0 until 20){
                put(JSONObject().apply {
                    put("price","0.23782")
                    put("quantity", "388888.5888")
                    put("is_buy",i % 2 == 0)
                })
            }
        }

        test_data.forEach<JSONObject> {
            val data = it!!
            val cell = createHistoryCell(data.getBoolean("is_buy"), data.getString("price"), data.getString("quantity") )
            _layout_trade_history.addView(cell)
        }

        var i = 0
        test_data.forEach<JSONObject> {
            val data = it!!
            val cell = createBuyOrSellOrderCell(i+1,true, data.getString("price"), data.getString("quantity"), true )
            _layout_buy_list.addView(cell)

            i++
        }

        i = 0
        test_data.forEach<JSONObject> {
            val data = it!!
            val cell = createBuyOrSellOrderCell(20-i,false, data.getString("price"), data.getString("quantity"), true )
            _layout_sell_list.addView(cell)
            i++
        }

    }

    fun calcOrderScrollViewHeight(){
        // 左边固定区域(用于计算历史订单view的高度)
        val scale = _ctx.resources.getDisplayMetrics().density
        val dm = DisplayMetrics()
        activity!!.windowManager.defaultDisplay.getMetrics(dm)
        val pix_height = dm.heightPixels.toFloat()

        // 状态栏(需计算) 标题栏(40px) tab(40px) 价格百分比(48px) 总margin(25dp + 20dp + 26dp = 71dp)
        val right_scroll_height_pix = ((pix_height - (40 + 40 + 48 + 71 ) * scale ) / 2).toInt()
        val right_scroll_height_dp = (right_scroll_height_pix / scale)

        val sv_sell_list = _view.findViewById<ScrollView>(R.id.sv_sell_list_from_trade_buy_or_sell)
        var layout_params_sell_list = sv_sell_list.layoutParams
        layout_params_sell_list.height = right_scroll_height_dp.dp.toInt()
        sv_sell_list.layoutParams = layout_params_sell_list
    }

    fun getStatusBarHeight(context: Context): Int {
        val resources = context.resources
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return resources.getDimensionPixelSize(resourceId)
    }

    // TODO: Rename method, update argument and hook method into UI event
    fun onButtonPressed(uri: Uri) {
        listener?.onFragmentInteraction(uri)
    }

    override fun onDetach() {
        super.onDetach()
        listener = null
    }

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     *
     *
     * See the Android Training lesson [Communicating with Other Fragments]
     * (http://developer.android.com/training/basics/fragments/communicating.html)
     * for more information.
     */
    interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        fun onFragmentInteraction(uri: Uri)
    }

    companion object {
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param param1 Parameter 1.
         * @param param2 Parameter 2.
         * @return A new instance of fragment FragmentTradeBuyOrSell.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentTradeBuyOrSell().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
