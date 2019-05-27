package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_add_asset_pairs_base.*
import org.json.JSONObject

class ActivityAddAssetPairsBase : BtsppActivity() {

    private var layout_search: LinearLayout? = null

    private val _array_data = mutableListOf<JSONObject>()

    override fun onResume() {
        super.onResume()
        reloadAndRefresh()
    }

    override fun onCreate(savedInstanceState: Bundle?) {


        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_add_asset_pairs_base)

        layout_search = layout_search_from_add_trade_obj_search_index

        layout_back.setOnClickListener { view ->
            finish()
        }

        //  监听
        edit_search_trade_obj.isFocusable = false
        edit_search_trade_obj.isFocusableInTouchMode = false
        edit_search_trade_obj.setOnClickListener {
            goTo(ActivityAddAssetPairsResult::class.java, false)
        }

        setFullScreen()
    }

    /**
     * 重新加载数据&刷新列表。
     */
    fun reloadAndRefresh() {
        reinitCustomMarketList()
        _refreshUI()
    }

    /**
     * (private) 初始化自定义交易对列表
     */
    private fun reinitCustomMarketList() {
        _array_data.clear()

        val custom_markets = AppCacheManager.sharedAppCacheManager().get_all_custom_markets()
        if (custom_markets.length() <= 0) {
            return
        }

        var market_hash = JSONObject()
        ChainObjectManager.sharedChainObjectManager().getDefaultMarketInfos().forEach<JSONObject> {
            val market = it!!
            val base = market.getJSONObject("base")
            market_hash.put(base.getString("symbol"), base)
        }
        for (obj in custom_markets.values()) {
            val custom_item = obj!!
            val base_symbol = custom_item.getString("base")
            val market_base = market_hash.optJSONObject(base_symbol)
            //  无效数据（用户添加之后，官方删除了部分市场可能存在该情况。）
            if (market_base == null) {
                continue
            }
            val quote = custom_item.getJSONObject("quote")
            _array_data.add(jsonObjectfromKVS("base", market_base, "quote", quote))
        }

        //  排序
        _array_data.sortBy { it.getJSONObject("quote").getString("symbol") }
    }

    private fun _refreshUI() {
        addDefaultResult()
        findViewById<TextView>(R.id.label_txt_my_custom_n).text = String.format(resources.getString(R.string.kSearchTipsMyCustomPairs), _array_data.size.toString())
    }

    private fun addDefaultResult() {
        //  添加到列表
        layout_search!!.removeAllViews()
        for (data in _array_data) {
            createCell(data)
        }
    }

    private fun createCell(data: JSONObject) {
        val v = LinearLayout(this)
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(30f))
        layout_params.gravity = Gravity.CENTER_VERTICAL

        v.layoutParams = layout_params

        val base = data.getJSONObject("base")
        val quote = data.getJSONObject("quote")
        val quote_symbol = quote.getString("symbol")
        val base_name = base.getString("name")

        val tv: TextView = TextView(this)
        tv.text = "${quote_symbol}/${base_name}"
        tv.gravity = Gravity.CENTER_VERTICAL
        tv.setTextColor(resources!!.getColor(R.color.theme01_textColorMain))

        //  开关
        val switch = Switch(this)
        switch.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        val layout_switch_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(30f))
        layout_switch_params.weight = 1.0f
        switch.layoutParams = layout_switch_params
        //  默认值
        switch.isChecked = AppCacheManager.sharedAppCacheManager().is_custom_market(quote_symbol, base.getString("symbol"))
        switch.setOnCheckedChangeListener { compoundButton, selected ->
            onSwitchAction(data, selected, compoundButton as Switch)
        }

        v.addView(tv)
        v.addView(switch)

        layout_search!!.addView(v)
    }

    private fun onSwitchAction(data: JSONObject, selected: Boolean, switch: Switch) {
        val pAppCache = AppCacheManager.sharedAppCacheManager()
        if (selected) {
            val base = data.getJSONObject("base")
            val quote = data.getJSONObject("quote")
            pAppCache.set_custom_markets(quote, base.getString("symbol")).saveCustomMarketsToFile()
            //  [统计]
            btsppLogCustom("event_custommarket_add", jsonObjectfromKVS("base", base.getString("symbol"), "quote", quote.getString("symbol")))
        } else {
            val base = data.getJSONObject("base")
            val quote = data.getJSONObject("quote")
            pAppCache.remove_custom_markets(quote.getString("symbol"), base.getString("symbol")).saveCustomMarketsToFile()
            //  [统计]
            btsppLogCustom("event_custommarket_remove", jsonObjectfromKVS("base", base.getString("symbol"), "quote", quote.getString("symbol")))
        }
        //  标记：自定义交易对发生变化，市场列表需要更新。
        TempManager.sharedTempManager().customMarketDirty = true
    }
}
