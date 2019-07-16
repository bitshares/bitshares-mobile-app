package com.btsplusplus.fowallet

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.crashlytics.android.Crashlytics
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentMarketInfo.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentMarketInfo.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentMarketInfo : BtsppFragment() {
    private var listener: OnFragmentInteractionListener? = null

    private var _view: View? = null
    private var _context: Context? = null

    private var _favorites_market: Boolean = false                          //  是否是自选市场
    private var _favorites_asset_list: JSONArray? = null                    //  自选列表（非自选市场该变量为nil。）
    private var _marketInfos: JSONObject? = null                            //  市场信息配置（基本资产、引用资产、分组信息等）
    private var _label_arrays = mutableListOf<JSONArray>()                  //  数组(base, quote, price, percent, 24volume)

    private var _inited = false

    override fun onInitParams(args: Any?) {
        val market_config_info = args as? JSONObject
        if (market_config_info != null) {
            _favorites_market = false
            _favorites_asset_list = null
            _marketInfos = market_config_info
        } else {
            _favorites_market = true
            _marketInfos = null
            _favorites_asset_list = null
            loadAllFavoritesMarkets()
        }
        _inited = true
    }

    /**
     * (public) 刷新UI（ticker数据变更）
     */
    fun onRefreshTickerData() {
        if (!_inited) {
            return
        }
        //  添加到缓存
        _label_arrays.forEach {
            val base_symbol = it.getString(0)
            val quote_symbol = it.getString(1)
            val label_price = it.get(2) as TextView
            val label_percent = it.get(3) as TextView
            val label_24vol = it.get(4) as TextView
            //  更新数据
            val ticker_show_data = _getTickerData(base_symbol, quote_symbol)
            label_price.text = ticker_show_data.getString("price_str")
            label_24vol.text = ticker_show_data.getString("volume_str")
            label_percent.text = ticker_show_data.getString("percent_str")
            label_percent.setBackgroundColor(resources.getColor(ticker_show_data.getInt("percent_color")))
        }
    }

    /**
     *  (public) 刷新自选市场
     */
    fun onRefreshFavoritesMarket() {
        if (!_inited) {
            return
        }
        loadAllFavoritesMarkets()
    }

    /**
     *  (private) 刷新自选市场列表
     */
    private fun loadAllFavoritesMarkets() {
        //  非自选市场不刷新。
        if (!_favorites_market) {
            return
        }
        //  加载数据
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val pAppCache = AppCacheManager.sharedAppCacheManager()
        _favorites_asset_list = JSONArray()
        for (fav_item in pAppCache.get_all_fav_markets().values().toList<JSONObject>().sortedBy { it.getString("base") }) {
            val base_symbol = fav_item.getString("base")
            val quote_symbol = fav_item.getString("quote")
            //  是自定义交易对，则有效。
            if (pAppCache.is_custom_market(quote_symbol, base_symbol)) {
                _favorites_asset_list!!.put(fav_item)
                continue
            }
            //  是默认交易对，则有效。
            if (chainMgr.isDefaultPair(base_symbol, quote_symbol)) {
                _favorites_asset_list!!.put(fav_item)
                continue
            }
            //  既不是自定义交易对、也不是默认交易对，则收藏无效了，则从收藏列表删除。（用户添加了自定义、然后收藏了、然后删除了自定义交易对）
            pAppCache.remove_fav_markets(quote_symbol, base_symbol)
        }
        pAppCache.saveFavMarketsToFile()

        //  如果有UI界面则刷新。
        if (_view != null) {
            _refreshUI()
        }
    }

    /**
     *  (public) 刷新自定义交易对
     */
    fun onRefreshCustomMarket() {
        if (!_inited) {
            return
        }

        //  自选列表不处理
        if (_favorites_market) {
            return
        }

        //  获取当前 base 信息
        val curr_base_symbol = _marketInfos!!.getJSONObject("base").getString("symbol")

        //  从合并后的列表筛选当前base对应的市场信息
        for (market in ChainObjectManager.sharedChainObjectManager().getMergedMarketInfos()) {
            if (market.getJSONObject("base").getString("symbol") == curr_base_symbol) {
                _marketInfos = market
                break
            }
        }

        //  重新加载
        _refreshUI()
    }

    /**
     * 刷新UI，描绘所有数据。
     */
    private fun _refreshUI() {
        if (_view == null) {
            return
        }

        val container = _view!!.findViewById<LinearLayout>(R.id.markets_info_sv)
        container.removeAllViews()

        //  先清空
        _label_arrays.clear()

        if (_favorites_market) {
            //  - 自定义市场
            if (_favorites_asset_list != null && _favorites_asset_list!!.length() > 0) {
                //  描绘所有自选交易对
                for (fav_item in _favorites_asset_list!!) {
                    fav_item!!.tap {
                        _refreshDrawOnCell(null, _context!!, container, it.getString("quote"), it.getString("base"))
                    }
                }
            } else {
                //  没有自选交易对
                container.addView(ViewUtils.createEmptyCenterLabel(_context!!, _context!!.resources.getString(R.string.kLabelNoFavMarket)))
            }
        } else {
            //  普通市场

            //  遍历描绘所有分组
            val group_list = _marketInfos!!.getJSONArray("group_list")
            for (i in 0 until group_list.length()) {
                val group = group_list.getJSONObject(i)

                //  分组名称
                val flmain = FrameLayout(_context)
                val flmain_layout_params: FrameLayout.LayoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, toDp(32f))
                val tvmain = TextView(_context)
                val tvmain_layout_params = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
                tvmain_layout_params.setMargins(toDp(10f), 0, 0, 0)
                tvmain_layout_params.gravity = Gravity.CENTER_VERTICAL
                tvmain.gravity = Gravity.CENTER_VERTICAL
                tvmain.setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                tvmain.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f)
                val group_key = group.getString("group_key")
                val group_info = ChainObjectManager.sharedChainObjectManager().getGroupInfoFromGroupKey(group_key)
                tvmain.text = resources.getString(resources.getIdentifier(group_info.getString("name_key"), "string", context!!.packageName))
                flmain.addView(tvmain, tvmain_layout_params)

                //  介绍按钮
                if (group_info.optBoolean("intro", false)) {
                    val inmain: TextView = TextView(_context)
                    val inmain_layout_params = FrameLayout.LayoutParams(toDp(100f), FrameLayout.LayoutParams.MATCH_PARENT)
                    inmain_layout_params.setMargins(0, 0, toDp(10f), 0)
                    inmain_layout_params.gravity = Gravity.RIGHT
                    inmain.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                    inmain.text = resources.getString(R.string.kLabelGroupIntroduction)
                    inmain.setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    inmain.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12f)
                    inmain.setOnClickListener {
                        //  [统计]
                        btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_gateway"))
                        activity!!.goToWebView(_context!!.resources.getString(R.string.kVcTitleWhatIsGateway), "https://btspp.io/qam.html#qa_gateway")
                    }
                    flmain.addView(inmain, inmain_layout_params)
                }
                container.addView(flmain, flmain_layout_params)

                //  描绘单个分组下的所有交易对
                val quote_list = group.getJSONArray("quote_list")
                for (j in 0 until quote_list.length()) {
                    val base_symbol = _marketInfos!!.getJSONObject("base").getString("symbol")
                    val quote_symbol = quote_list.getString(j)
                    _refreshDrawOnCell(group_info, _context!!, container, quote_symbol, base_symbol)
                }
            }
        }
    }

    /**
     * 生成 Ticker 最终显示数据，格式化数据等。
     */
    private fun _getTickerData(base_symbol: String, quote_symbol: String): JSONObject {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val ticker_data = chainMgr.getTickerData(base_symbol, quote_symbol)
        val base_asset = chainMgr.getAssetBySymbol(base_symbol)

        val latest: String
        val quote_volume: String
        val percent_change: String
        if (ticker_data != null) {
            var sym = ""
            if (base_symbol == "CNY") {
                sym = "¥"   //  REMARK：半角形式，如果需要全角用这个￥。
            } else if (base_symbol == "USD") {
                sym = "$"   //  REMARK：半角形式，如果需要全角用这个＄。
            }
            latest = String.format("%s%s", sym, OrgUtils.formatFloatValue(ticker_data.getString("latest").toDouble(), base_asset.getInt("precision")))
            quote_volume = ticker_data.getString("quote_volume")
            percent_change = ticker_data.getString("percent_change")
        } else {
            latest = "--"
            quote_volume = "--"
            percent_change = "0"
        }

        val percent_color: Int
        val percent_str: String

        val percent = percent_change.toDouble()
        if (percent > 0.0f) {
            percent_color = R.color.theme01_buyColor
            percent_str = "+${percent_change}%"
        } else if (percent < 0) {
            percent_color = R.color.theme01_sellColor
            percent_str = "${percent_change}%"
        } else {
            percent_color = R.color.theme01_zeroColor
            percent_str = "${percent_change}%"
        }

        return jsonObjectfromKVS("price_str", latest, "volume_str", "${_context!!.resources.getString(R.string.kLabelHeader24HVol)} ${quote_volume}", "percent_str", percent_str, "percent_color", percent_color)
    }

    private fun _refreshDrawOnCell(group_info: JSONObject?, ctx: Context, ly: LinearLayout, quote_symbol: String, base_symbol: String) {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        //  获取资产信息
        val base = chainMgr.getAssetBySymbol(base_symbol)
        val quote = chainMgr.getAssetBySymbol(quote_symbol)

        var quote_name = quote_symbol

        //  REMARK：如果是网关资产、则移除网关前缀。自选市场没有分组信息，网关资产也显示全称。
        if (group_info != null && group_info.optBoolean("gateway")) {
            val group_prefix = group_info.optString("prefix")
            if (quote_name.indexOf(group_prefix) == 0) {
                val ary = quote_name.split(".")
                if (ary.count() >= 2 && ary[0] == group_prefix) {
                    quote_name = ary.subList(1, ary.size).joinToString(".")
                }
            }
        }

        val fl = FrameLayout(ctx)
        val frame_layout_params: FrameLayout.LayoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, toDp(48f))

        //  QUOTE 名
        val tv1 = TextView(ctx)
        val tv1_layout_params = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)

        tv1_layout_params.setMargins(toDp(10f), toDp(3f), 0, 0)
        tv1.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv1.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15f)
        tv1.id = R.id.view1_of_markets

        //  BASE 名
        val tv2 = TextView(ctx)
        val tv2_layout_params = FrameLayout.LayoutParams(toDp(70f), FrameLayout.LayoutParams.MATCH_PARENT)

        tv2.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        tv2.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10f)

        tv1.text = quote_name
        tv2.text = "  /${chainMgr.getDefaultMarketInfoByBaseSymbol(base_symbol).getJSONObject("base").getString("name")}"

        val tv1_paint = tv1.paint
        val tv1_width = tv1_paint.measureText(quote_name)
        tv2_layout_params.setMargins(tv1_width.toInt() + 20, toDp(9f), 0, 0)

        val tv3_id = View.generateViewId()
        val tv4_id = View.generateViewId()
        val tv5_id = View.generateViewId()

        val ticker_show_data = _getTickerData(base_symbol, quote_symbol)

        //  24H量
        val tv3 = TextView(ctx)
        val tv3_layout_params = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.MATCH_PARENT)
        tv3_layout_params.setMargins(toDp(10f), toDp(23f), 0, 0)
        tv3.text = ticker_show_data.getString("volume_str")
        tv3.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        tv3.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10f)
        tv3.id = tv3_id

        //  价格
        val tv4 = TextView(ctx)
        val tv4_layout_params = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.MATCH_PARENT, Gravity.RIGHT or Gravity.CENTER_VERTICAL)
        tv4_layout_params.setMargins(0, 0, toDp(85f), 0)
        tv4.text = ticker_show_data.getString("price_str")
        tv4.gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
        tv4.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv4.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
        tv4.id = tv4_id

        //  百分比
        val tv5 = TextView(ctx)
        val tv5_layout_params = FrameLayout.LayoutParams(toDp(70f), toDp(25f), Gravity.RIGHT or Gravity.CENTER_VERTICAL)
        tv5_layout_params.setMargins(0, 0, toDp(10f), 0)
        tv5.id = tv5_id
        tv5.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
        tv5.setTextColor(resources.getColor(R.color.theme01_textColorPercent))
        tv5.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
        tv5.text = ticker_show_data.getString("percent_str")
        tv5.setBackgroundColor(resources.getColor(ticker_show_data.getInt("percent_color")))

        //  渲染每一行
        fl.addView(tv1, tv1_layout_params)
        fl.addView(tv2, tv2_layout_params)
        fl.addView(tv3, tv3_layout_params)
        fl.addView(tv4, tv4_layout_params)
        fl.addView(tv5, tv5_layout_params)

        ly.addView(fl, frame_layout_params)

        //  添加到缓存
        _label_arrays.add(jsonArrayfrom(base_symbol, quote_symbol, tv4, tv5, tv3))

        //  点击cell进入K线界面
        fl.setOnClickListener {
            Crashlytics.log("ready to kline, base: $base, quote: $quote")
            val intent = Intent()
            intent.setClass(ctx, ActivityKLine::class.java)
            intent.putExtra(BTSPP_START_ACTIVITY_PARAM_ID, ParametersManager.sharedParametersManager().genParams(jsonArrayfrom(base, quote)))
            startActivity(intent)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        // Inflate the layout for this fragment
        _context = inflater.context
        return inflater.inflate(R.layout.fragment_market_info, container, false).also {
            _view = it
            _refreshUI()
        }
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
