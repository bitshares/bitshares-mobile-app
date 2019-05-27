package com.btsplusplus.fowallet

import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_add_asset_pairs_result.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityAddAssetPairsResult : BtsppActivity() {

    var search_editor: EditText? = null

    var layout_search: LinearLayout? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_add_asset_pairs_result)

        text_cancel_from_add_trade_obj.setOnClickListener { view ->
            this.hideSoftKeyboard()
            finish()
        }

        search_editor = edit_search_trade_obj_for_search
        layout_search = layout_search_from_add_trade_obj_search

        var watcher: ThisTextWatcher? = ThisTextWatcher()
        watcher!!.ctx = this
        search_editor!!.addTextChangedListener(watcher)

        setFullScreen()
    }

    class ThisTextWatcher : TextWatcher {

        //        var layout_wrap: LinearLayout? = null
        var ctx: ActivityAddAssetPairsResult? = null

        override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {

        }

        override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {

        }

        private fun createCell(data: JSONObject) {
            val v = LinearLayout(ctx)
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ctx!!.toDp(30f))
            layout_params.gravity = Gravity.CENTER_VERTICAL

            v.layoutParams = layout_params

            val base = data.getJSONObject("base")
            val quote = data.getJSONObject("quote")
            val quote_symbol = quote.getString("symbol")
            val base_name = base.getString("name")

            val tv: TextView = TextView(ctx)
            tv.text = "${quote_symbol}/${base_name}"
            tv.gravity = Gravity.CENTER_VERTICAL
            tv.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 3f)
            tv.setTextColor(ctx!!.resources!!.getColor(R.color.theme01_textColorMain))
            v.addView(tv)

            if (ChainObjectManager.sharedChainObjectManager().isDefaultPair(quote, base)) {
                val label_forbid: TextView = TextView(ctx)
                label_forbid.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                label_forbid.text = ctx!!.resources.getString(R.string.kSearchTipsForbidden)
                label_forbid.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                label_forbid.setTextColor(ctx!!.resources!!.getColor(R.color.theme01_textColorNormal))
                v.addView(label_forbid)
            } else {
                val switch = Switch(ctx)
                switch.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                val layout_switch_params = LinearLayout.LayoutParams(0, ctx!!.toDp(30f), 3f)
                layout_switch_params.weight = 1.0f
                switch.layoutParams = layout_switch_params
                //  默认值
                switch.isChecked = AppCacheManager.sharedAppCacheManager().is_custom_market(quote_symbol, base.getString("symbol"))
                switch.setOnCheckedChangeListener { compoundButton, selected ->
                    onSwitchAction(data, selected, compoundButton as Switch)
                }
                v.addView(switch)
            }

            ctx!!.layout_search!!.addView(v)
        }

        /**
         * 开关点击
         */
        private fun onSwitchAction(data: JSONObject, selected: Boolean, switch: Switch) {
            val pAppCache = AppCacheManager.sharedAppCacheManager()
            if (selected) {
                val max_custom_pair_num = ChainObjectManager.sharedChainObjectManager().getDefaultParameters().getInt("max_custom_pair_num")
                if (pAppCache.get_all_custom_markets().length() >= max_custom_pair_num) {
                    switch.isChecked = false
                    ctx!!.showToast(String.format(ctx!!.resources.getString(R.string.kSearchTipsMaxCustomParisNumber), max_custom_pair_num.toString()))
                    return
                }
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

        private fun isSearchMatched(target: String, match: String): Boolean {
            return 0 == target.indexOf(match)
        }

        private fun processSearchResult(data_array: JSONArray, searchString: String) {
            ctx!!.layout_search!!.removeAllViews()

            val base_markets = ChainObjectManager.sharedChainObjectManager().getDefaultMarketInfos()

            val list = mutableListOf<JSONObject>()
            for (data in data_array) {
                if (isSearchMatched(data!!.getString("symbol"), searchString)) {
                    for (obj in base_markets) {
                        val market = obj!!
                        val base = market.getJSONObject("base")
                        //  REMARK：略过 base 和 quote 相同的交易对：CNY/CNY USD/USD BTS/BTS
                        if (data.getString("symbol") == base.getString("symbol")) {
                            continue
                        }
                        list.add(jsonObjectfromKVS("quote", data, "base", base))
                    }
                }
            }

            //  按照帐号名字长度升序排列（即匹配度高的排在前面） 比如 搜索：freedom16，那么 freedom168就排在freedom1613前面。
            list.sortBy { it.getJSONObject("quote").getString("symbol").length }

            //  添加到列表
            for (data in list) {
                createCell(data)
            }
        }

        override fun afterTextChanged(s: Editable) {
            val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            val searchString = s.toString().toUpperCase()

            if (searchString.isNotEmpty()) {
                conn.async_exec_db("list_assets", jsonArrayfrom(searchString, 20)).then {
                    ctx?.runOnMainUI {
                        processSearchResult(it as JSONArray, searchString)
                    }
                    return@then null
                }.catch {
                    //  TODO:toast
                }
            } else {
                ctx!!.layout_search!!.removeAllViews()
            }
        }
    }
}
