package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_trading_pair_mgr.*
import org.json.JSONObject
import org.w3c.dom.Text

class ActivityTradingPairMgr : BtsppActivity() {

    lateinit var tv_trade_asset: TextView
    lateinit var tv_quote_asset: TextView
    lateinit var layout_trading_pairs: LinearLayout
    lateinit var tv_my_tradeing_pair_n: TextView

    private val _array_data = mutableListOf<JSONObject>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_trading_pair_mgr)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化对象
        tv_trade_asset = tv_trade_asset_from_trading_pair_mgr
        tv_quote_asset = tv_quote_asset_from_trading_pair_mgr
        layout_trading_pairs = layout_trading_pairs_from_trading_pair_mgr
        tv_my_tradeing_pair_n = tv_my_custom_n_trading_pair_mgr

        // 切换图片改变颜色
        iv_switch_from_trading_pair_mgr.setColorFilter(resources.getColor(R.color.theme01_textColorMain))

        tv_trade_asset.text = "BTS"
        tv_quote_asset.text = "USD"

        // 添加按钮事件
        btn_add_from_trading_pair_mgr.setOnClickListener {

        }

        // 交易资产点击事件
        layout_trade_asset_from_trading_pair_mgr.setOnClickListener {

        }

        // 中间切换按钮点击事件
        layout_switch_from_trading_pair_mgr.setOnClickListener {

        }

        // 报价资产点击事件
        layout_quote_asset_from_trading_pair_mgr.setOnClickListener {

        }

        // 返回按钮事件
        layout_back_from_trading_pair_mgr.setOnClickListener { finish() }

        reloadAndRefresh()
    }

    /**
     * 重新加载数据&刷新列表。
     */
    private fun reloadAndRefresh() {
        reinitCustomMarketList()
        tv_my_tradeing_pair_n.text = "我的交易对(${_array_data.count()})个"
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

        val market_hash = JSONObject()
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
    }

    private fun addDefaultResult() {
        //  添加到列表
        layout_trading_pairs.removeAllViews()

        if (_array_data.count() === 0){
            layout_trading_pairs.addView(ViewUtils.createEmptyCenterLabel(this, "没有任何自选", text_color = resources.getColor(R.color.theme01_textColorGray)))
            return
        }

        for (data in _array_data) {
            createCell(data)
        }
    }

    private fun createCell(data: JSONObject) {
        val _ctx = this
        val view = LinearLayout(this)
        val layout_params = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
        layout_params.gravity = Gravity.CENTER_VERTICAL

        view.orientation = LinearLayout.HORIZONTAL
        view.layoutParams = layout_params

        val base = data.getJSONObject("base")
        val quote = data.getJSONObject("quote")
        val quote_symbol = quote.getString("symbol")
        val base_name = base.getString("name")

        // 左 (交易对 自定义)
        val tv_trading_pair = TextView(this).apply {
            text = "${quote_symbol}/${base_name}"
            gravity = Gravity.CENTER_VERTICAL
            setTextColor(resources!!.getColor(R.color.theme01_textColorMain))
        }
        view.addView(tv_trading_pair)

        // 自定义标签
        if (true){
            val tv_custom = TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                    setMargins(4.dp,0,0,0)
                }
                text = "自定义"
                gravity = Gravity.CENTER_VERTICAL
                setPadding(4.dp, 1.dp, 4.dp, 1.dp)
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10.0f)
                background = resources.getDrawable(R.drawable.border_text_view)
            }
            view.addView(tv_custom)
        }

        //  右 (收藏star图标)
        val layout_iv = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                gravity = Gravity.RIGHT
            }
            gravity = Gravity.RIGHT
            val iv = ImageView(_ctx).apply {
                setImageResource(R.drawable.ic_btn_star)

                // 点击取消收藏交易对
                setOnClickListener {

                }
            }
            addView(iv)
        }
        view.addView(layout_iv)

        layout_trading_pairs.addView(view)
        layout_trading_pairs.addView(ViewLine(this, margin_top = 12.dp, margin_bottom = 12.dp))
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
