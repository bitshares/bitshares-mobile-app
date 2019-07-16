package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.text.TextUtils
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TableRow
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
 * [FragmentFeedPrice.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentFeedPrice.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentFeedPrice : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _ctx: Context? = null
    private var _currentView: View? = null
    private var _tradingPair: TradingPair? = null
    private var _feedPriceInfo: BigDecimal? = null

    private var _waiting_draw_infos: JSONObject? = null

    /**
     * 刷新喂价信息
     */
    fun onQueryFeedInfoResponsed(asset: JSONObject, infos: JSONObject, data_array: JSONArray, active_witnesses: JSONArray) {
        //  REMARK：数据返回的时候界面尚未创建完毕先保存
        if (_currentView == null || this.activity == null) {
            _waiting_draw_infos = jsonObjectfromKVS("asset", asset, "infos", infos, "data_array", data_array, "active_witnesses", active_witnesses)
            return
        }

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val short_backing_asset_id = infos.getJSONObject("options").getString("short_backing_asset")

        val asset_id = asset.getString("id")
        val asset_precision = asset.getInt("precision")

        val sba_asset = chainMgr.getChainObjectByID(short_backing_asset_id)
        val sba_asset_precision = sba_asset.getInt("precision")

        val curr_feed_price_item = infos.getJSONObject("current_feed").getJSONObject("settlement_price")
        val n_curr_feed_price = OrgUtils.calcPriceFromPriceObject(curr_feed_price_item, short_backing_asset_id, sba_asset_precision, asset_precision)

        //  刷新UI
        //  喂价
        _currentView!!.findViewById<TextView>(R.id.label_txt_curr_feed).text = "${_ctx!!.resources.getString(R.string.kVcFeedCurrentFeedPrice)} ${n_curr_feed_price!!.toPriceAmountString()}"

        //  列表
        val line_height = 28.0f

        val lay = _currentView!!.findViewById<LinearLayout>(R.id.layout_fragment_detail_feedprice)
        lay.removeAllViews()
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 30.dp)
        layout_params.gravity = Gravity.CENTER_VERTICAL

        lay.addView(createRow(_ctx!!, line_height, title = true))

        val publishedAccountHash = JSONObject()
        val list = mutableListOf<JSONObject>()
        for (json in data_array.forin<JSONArray>()) {
            val publisher_account_id = json!!.getString(0)
            publishedAccountHash.put(publisher_account_id, true)

            val feed_info_ary = json.getJSONArray(1)
            val publish_date = feed_info_ary.getString(0)
            val feed_data = feed_info_ary.getJSONObject(1)

            val name = chainMgr.getChainObjectByID(publisher_account_id).getString("name")
            val n_price = OrgUtils.calcPriceFromPriceObject(feed_data.getJSONObject("settlement_price"), short_backing_asset_id, sba_asset_precision, asset_precision)!!
            val change = n_price.divide(n_curr_feed_price, 4, BigDecimal.ROUND_DOWN).subtract(BigDecimal.ONE).scaleByPowerOfTen(2)

            list.add(jsonObjectfromKVS("name", name, "price", n_price, "diff", change, "date", publish_date))
        }

        list.sortedByDescending { (it.get("price") as BigDecimal).toDouble() }.forEach {
            lay.addView(createRow(_ctx!!, line_height, it.getString("name"), it.get("price") as BigDecimal, it.get("diff") as BigDecimal, it.getString("date")))
        }
        active_witnesses.forEach<JSONObject> {
            val witness_account = it!!.getString("witness_account")
            if (!publishedAccountHash.optBoolean(witness_account, false)) {
                val name = chainMgr.getChainObjectByID(witness_account).getString("name")
                lay.addView(createRow(_ctx!!, line_height, name = name, miss = true))
            }
        }
    }

    private fun createRow(ctx: Context, line_height: Float, name: String? = null, price: BigDecimal? = null, diff: BigDecimal? = null, date: String = "", title: Boolean = false, miss: Boolean = false): TableRow {
        val row_height = Utils.toDp(line_height, this.resources)

        var color = if (title || miss) R.color.theme01_textColorNormal else R.color.theme01_textColorMain

        val table_row = TableRow(ctx)
        val table_row_params = TableRow.LayoutParams(TableRow.LayoutParams.MATCH_PARENT, row_height)
        table_row.orientation = TableRow.HORIZONTAL
        table_row.layoutParams = table_row_params

        //  name
        val tv1 = ViewUtils.createTextView(ctx, name
                ?: R.string.kVcFeedWitnessName.xmlstring(_ctx!!), 13f, color, false)
        tv1.setSingleLine(true)
        tv1.maxLines = 1
        tv1.ellipsize = TextUtils.TruncateAt.END
        val tv1_params = TableRow.LayoutParams(0, row_height)
        tv1_params.weight = 4f
        tv1_params.gravity = Gravity.CENTER_VERTICAL
        tv1.gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
        tv1.layoutParams = tv1_params

        //  price
        val price_str = price?.toPlainString()
                ?: (if (miss) "--" else R.string.kVcFeedPriceName.xmlstring(_ctx!!))
        val tv2 = ViewUtils.createTextView(ctx, price_str, 13f, color, false)
        tv2.setSingleLine(true)
        tv2.maxLines = 1
        tv2.ellipsize = TextUtils.TruncateAt.END
        val tv2_params = TableRow.LayoutParams(0, row_height)
        tv2_params.weight = 2f
        tv2_params.gravity = Gravity.CENTER_VERTICAL
        tv2.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
        tv2.layoutParams = tv2_params

        //  bias
        var diffstr = R.string.kVcFeedRate.xmlstring(_ctx!!)
        var diffcolor = color
        if (!title) {
            if (miss) {
                diffstr = "--"
            } else {
                diffstr = diff!!.toPlainString()
                val result = diff.compareTo(BigDecimal.ZERO)
                if (result > 0) {
                    diffstr = "+${diff.toPlainString()}"
                    diffcolor = R.color.theme01_buyColor
                } else if (result < 0) {
                    diffcolor = R.color.theme01_sellColor
                }
                diffstr = "${diffstr}%"
            }
        }
        val tv3 = ViewUtils.createTextView(ctx, diffstr, 13f, diffcolor, false)
        tv3.setSingleLine(true)
        tv3.maxLines = 1
        tv3.ellipsize = TextUtils.TruncateAt.END
        val tv3_params = TableRow.LayoutParams(0, row_height)
        tv3_params.weight = 2f
        tv3_params.gravity = Gravity.CENTER_VERTICAL
        tv3.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
        tv3.layoutParams = tv3_params

        //  publish date
        val datestr = if (title) R.string.kVcFeedPublishDate.xmlstring(ctx) else (if (miss) R.string.kVcFeedNoData.xmlstring(ctx) else Utils.fmtFeedPublishDateString(_ctx!!, date))
        val tv4 = ViewUtils.createTextView(ctx, datestr, 13f, color, false)
        tv4.setSingleLine(true)
        tv4.maxLines = 1
        tv4.ellipsize = TextUtils.TruncateAt.END
        val tv4_params = TableRow.LayoutParams(0, row_height)
        tv4_params.weight = 3f
        tv4_params.gravity = Gravity.CENTER_VERTICAL
        tv4.gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
        tv4.layoutParams = tv4_params

        table_row.addView(tv1)
        table_row.addView(tv2)
        table_row.addView(tv3)
        table_row.addView(tv4)

        return table_row
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        _ctx = inflater.context
        val v: View = inflater.inflate(R.layout.fragment_feed_price, container, false)
        v.findViewById<ImageView>(R.id.tip_link_feedprice).setOnClickListener {
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_feedprice"))
            activity!!.goToWebView(_ctx!!.resources.getString(R.string.kVcTitleWhatIsFeedPrice), "https://btspp.io/qam.html#qa_feedprice")
        }
        _currentView = v
        //  refresh UI
        if (_waiting_draw_infos != null) {
            val asset = _waiting_draw_infos!!.getJSONObject("asset")
            val infos = _waiting_draw_infos!!.getJSONObject("infos")
            val data_array = _waiting_draw_infos!!.getJSONArray("data_array")
            val active_witnesses = _waiting_draw_infos!!.getJSONArray("active_witnesses")
            _waiting_draw_infos = null
            onQueryFeedInfoResponsed(asset, infos, data_array, active_witnesses)
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
