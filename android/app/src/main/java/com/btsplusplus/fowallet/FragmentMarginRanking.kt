package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentMarginRanking.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentMarginRanking.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentMarginRanking : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _currentView: View? = null
    private var _tradingPair: TradingPair? = null
    private var _feedPriceInfo: BigDecimal? = null
    private var _mcr: BigDecimal? = null

    private var _ctx: Context? = null

    private var _waiting_draw_infos: JSONArray? = null

    /**
     * 刷新排行榜界面
     */
    fun onQueryCallOrderDataResponsed(data_array: JSONArray) {
        //  REMARK：数据返回的时候界面尚未创建完毕先保存
        if (_currentView == null) {
            _waiting_draw_infos = data_array
            return
        }

        //  data[0] - 抵押排行信息
        //  data[1] - 喂价信息
        //  保存喂价信息、并计算喂价
        val feedPriceData = data_array.getJSONObject(1)
        if (_tradingPair == null) {
            val short_backing_asset = feedPriceData.getJSONObject("options").getString("short_backing_asset")
            _tradingPair = TradingPair().initWithBaseID(feedPriceData.getString("asset_id"), short_backing_asset)
        }
        _feedPriceInfo = _tradingPair!!.calcShowFeedInfo(jsonArrayfrom(feedPriceData))

        //  计算MCR
        val mcr = feedPriceData.getJSONObject("current_feed").getString("maintenance_collateral_ratio")
        _mcr = bigDecimalfromAmount(mcr, 3)

        //  刷新UI
        //  喂价
        _currentView!!.findViewById<TextView>(R.id.label_txt_curr_feed).text = "${_ctx!!.resources.getString(R.string.kVcRankCurrentFeedPrice)} ${_feedPriceInfo!!.toPriceAmountString()}"
        //  列表
        val lay = _currentView!!.findViewById<LinearLayout>(R.id.layout_fragment_of_diya_ranking_cny)
        lay.removeAllViews()

        val data_array = data_array[0] as JSONArray
        if (data_array.length() > 0) {
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(30f))
            layout_params.gravity = Gravity.CENTER_VERTICAL
            for (json in data_array.forin<JSONObject>()) {
                createCell(lay, _ctx!!, layout_params, json!!)
            }
        } else {
            lay.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, R.string.kVcTipsNoCallOrder.xmlstring(_ctx!!)))
        }
    }

    private fun createCell(layout: LinearLayout, ctx: Context, layout_params: LinearLayout.LayoutParams, data: JSONObject) {
        // 标题
        val tv_title: TextView = TextView(ctx)
        tv_title.text = ""
        tv_title.gravity = Gravity.CENTER_VERTICAL
        tv_title.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv_title.layoutParams = layout_params
        tv_title.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)

        // layout1 左: 强平触发价 1.4799 右: 保证金比例 175.02%
        val ly1: LinearLayout = LinearLayout(ctx)
        ly1.orientation = LinearLayout.HORIZONTAL
        ly1.layoutParams = layout_params
        ly1.setPadding(0, toDp(5.0f), 0, 0)

        //  强平触发价
        val tv1 = TextView(ctx)
        tv1.text = R.string.kVcRankCallPrice.xmlstring(ctx)
        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv1.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv1.gravity = Gravity.CENTER_VERTICAL

        val tv2 = TextView(ctx)
        tv2.text = ""
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv2.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv2.gravity = Gravity.CENTER_VERTICAL
        tv2.setPadding(toDp(2.0f), 0, 0, 0)

        //  抵押率
        val tv3 = TextView(ctx)
        tv3.text = R.string.kVcRankRatio.xmlstring(ctx)
        tv3.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv3.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv3.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        var layout_tv3 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_tv3.weight = 1.0f
        layout_tv3.gravity = Gravity.RIGHT
        tv3.layoutParams = layout_tv3

        val tv4 = TextView(ctx)
        tv4.text = ""
        tv4.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv4.setTextColor(resources.getColor(R.color.theme01_tintColor))
        tv4.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv4.setPadding(toDp(2.0f), 0, 0, 0)

        ly1.addView(tv1)
        ly1.addView(tv2)
        ly1.addView(tv3)
        ly1.addView(tv4)


        // layout2 左: 抵押(BTS) 81,279.4799 右: 借入(CNY)213,583.9999
        val ly2: LinearLayout = LinearLayout(ctx)
        ly2.orientation = LinearLayout.HORIZONTAL
        ly2.layoutParams = layout_params

        //  抵押
        val tv5 = TextView(ctx)
        tv5.text = "${R.string.kVcRankColl.xmlstring(ctx)}(${_tradingPair!!._quoteAsset.getString("symbol")})"
        tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv5.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv5.gravity = Gravity.CENTER_VERTICAL

        val tv6 = TextView(ctx)
        tv6.text = ""
        tv6.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv6.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv6.gravity = Gravity.CENTER_VERTICAL
        tv6.setPadding(toDp(2.0f), 0, 0, 0)

        //  借入
        val tv7 = TextView(ctx)
        tv7.text = "${R.string.kVcRankDebt.xmlstring(ctx)}(${_tradingPair!!._baseAsset.getString("symbol")})"
        tv7.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv7.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv7.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        var layout_tv7 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_tv7.weight = 1.0f
        layout_tv7.gravity = Gravity.RIGHT
        tv7.layoutParams = layout_tv7

        val tv8 = TextView(ctx)
        tv8.text = ""
        tv8.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12.0f)
        tv8.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv8.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv8.setPadding(toDp(2.0f), 0, 0, 0)

        //  计算各种数值
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val account = chainMgr.getChainObjectByID(data.getString("borrower"))
        tv_title.text = account.getString("name")

        val call_price = data.getJSONObject("call_price")
        val base = call_price.getJSONObject("base")
        val quote = call_price.getJSONObject("quote")
        val base_id = base.getString("asset_id")
        val quote_id = quote.getString("asset_id")
        val base_asset = chainMgr.getChainObjectByID(base_id)
        val quote_asset = chainMgr.getChainObjectByID(quote_id)

        val base_precision = base_asset.getInt("precision")
        val quote_precision = quote_asset.getInt("precision")

        val str_collateral = data.getString("collateral")
        val str_debt = data.getString("debt")

        val debt_precision = _tradingPair!!._basePrecision
        val collateral_precision = _tradingPair!!._quotePrecision

        //  计算抵押率
        val n_coll = bigDecimalfromAmount(str_collateral, collateral_precision)
        val n_debt = bigDecimalfromAmount(str_debt, debt_precision)
        val n_ratio = BigDecimal.valueOf(100.0).multiply(n_coll).multiply(_feedPriceInfo!!).divide(n_debt, 2, BigDecimal.ROUND_UP)

        //  强平触发价 高精度计算
        tv2.text = OrgUtils.calcSettlementTriggerPrice(str_debt, str_collateral, debt_precision, collateral_precision, _mcr!!, false, null, true).toPriceAmountString()
        tv4.text = "${n_ratio.toPlainString()}%"
        tv6.text = OrgUtils.formatAssetString(str_collateral, collateral_precision)
        tv8.text = OrgUtils.formatAssetString(str_debt, debt_precision)

        // 线
        val lv_line = View(ctx)
        var layout_tv9 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(1.0f))
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_tv9

        ly2.addView(tv5)
        ly2.addView(tv6)
        ly2.addView(tv7)
        ly2.addView(tv8)

        val layout_row = LinearLayout(ctx)
        layout_row.orientation = LinearLayout.VERTICAL

        layout_row.setOnClickListener {
            activity!!.viewUserAssets(data.getString("borrower"))
        }

        layout_row.addView(tv_title)
        layout_row.addView(ly1)
        layout_row.addView(ly2)
        layout_row.addView(lv_line)

        layout.addView(layout_row)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        val v: View = inflater.inflate(R.layout.fragment_margin_ranking, container, false)
        v.findViewById<ImageView>(R.id.tip_link_feedprice).setOnClickListener {
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_feedprice"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsFeedPrice), "https://btspp.io/qam.html#qa_feedprice")
        }
        _currentView = v
        //  refresh UI
        if (_waiting_draw_infos != null) {
            val data_array = _waiting_draw_infos!!
            _waiting_draw_infos = null
            onQueryCallOrderDataResponsed(data_array)
        }
        return v
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
}
