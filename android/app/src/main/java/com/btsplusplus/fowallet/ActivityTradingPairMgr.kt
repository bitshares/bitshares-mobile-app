package com.btsplusplus.fowallet

import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import kotlinx.android.synthetic.main.activity_trading_pair_mgr.*
import org.json.JSONObject

class ActivityTradingPairMgr : BtsppActivity() {

    private val _data_array_pairs = mutableListOf<JSONObject>()
    private val _args_pair_info = JSONObject()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_trading_pair_mgr)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  初始化数据 - 获取所有收藏或自定义交易对列表。
        val all_fav_markets = AppCacheManager.sharedAppCacheManager().get_all_fav_markets()
        for (key in all_fav_markets.keys()) {
            _data_array_pairs.add(all_fav_markets.getJSONObject(key))
        }
        _data_array_pairs.sortBy { it.getString("base") }

        //  初始化UI -  切换图片改变颜色
        icon_switch_button.setColorFilter(resources.getColor(R.color.theme01_textColorMain))
        _draw_ui_all()

        //  添加按钮事件
        btn_add_from_trading_pair_mgr.setOnClickListener { onAddButtonClicked() }

        //  交易资产点击事件
        layout_quote_asset.setOnClickListener { onQuoteAssetClicked() }

        //  中间切换按钮点击事件
        layout_switch_button.setOnClickListener { onSwitchButtonClicked() }

        //  报价资产点击事件
        layout_base_asset.setOnClickListener { onBaseAssetClicked() }

        //  返回按钮事件
        layout_back_from_trading_pair_mgr.setOnClickListener { finish() }
    }

    private fun onAddPairCore(quote: JSONObject, base: JSONObject) {
        val pAppCache = AppCacheManager.sharedAppCacheManager()

        val quote_id = quote.getString("id")
        val base_id = base.getString("id")

        if (pAppCache.is_fav_market(quote_id, base_id)) {
            showToast(resources.getString(R.string.kVcMyPairSubmitTipPairIsAlreadyExist))
            return
        }

        if (VcUtils.processMyFavPairStateChanged(this, quote, base, associated_view = null)) {
            //  添加到列表
            var exist = false
            for (fav_item in _data_array_pairs) {
                if (quote_id == fav_item.getString("quote") && base_id == fav_item.getString("base")) {
                    exist = true
                    break
                }
            }
            if (!exist) {
                _data_array_pairs.add(JSONObject().apply {
                    put("base", base_id)
                    put("quote", quote_id)
                })
                _data_array_pairs.sortBy { it.getString("base") }
            }
            //  刷新
            _draw_ui_all()
        }
    }

    private fun onAddButtonClicked() {
        val quote = _args_pair_info.optJSONObject("quote")
        val base = _args_pair_info.optJSONObject("base")

        if (quote == null) {
            showToast(resources.getString(R.string.kVcMyPairSubmitTipMissQuoteAsset))
            return
        }

        if (base == null) {
            showToast(resources.getString(R.string.kVcMyPairSubmitTipMissBaseAsset))
            return
        }

        if (quote.getString("id") == base.getString("id")) {
            showToast(resources.getString(R.string.kVcMyPairSubmitTipQuoteBaseIsSame))
            return
        }

        //  添加
        onAddPairCore(quote, base)
    }

    private fun onQuoteAssetClicked() {
        TempManager.sharedTempManager().set_query_account_callback { last_activity, asset_info ->
            last_activity.goTo(ActivityTradingPairMgr::class.java, true, back = true)
            //  处理选择搜索结果
            ChainObjectManager.sharedChainObjectManager().appendAssetCore(asset_info)
            _args_pair_info.put("quote", asset_info)
            _draw_ui_current_pair_assets()
        }
        val self = this
        goTo(ActivityAccountQueryBase::class.java, true, args = JSONObject().apply {
            put("kSearchType", ENetworkSearchType.enstAssetAll)
            put("kTitle", self.resources.getString(R.string.kVcTitleSearchAssetQuote))
        })
    }

    private fun onBaseAssetClicked() {
        TempManager.sharedTempManager().set_query_account_callback { last_activity, asset_info ->
            last_activity.goTo(ActivityTradingPairMgr::class.java, true, back = true)
            //  处理选择搜索结果
            ChainObjectManager.sharedChainObjectManager().appendAssetCore(asset_info)
            _args_pair_info.put("base", asset_info)
            _draw_ui_current_pair_assets()
        }
        val self = this
        goTo(ActivityAccountQueryBase::class.java, true, args = JSONObject().apply {
            put("kSearchType", ENetworkSearchType.enstAssetAll)
            put("kTitle", self.resources.getString(R.string.kVcTitleSearchAssetBase))
        })
    }

    private fun onSwitchButtonClicked() {
        val quote = _args_pair_info.optJSONObject("quote")
        val base = _args_pair_info.optJSONObject("base")
        if (quote != null) {
            _args_pair_info.put("base", quote)
        } else {
            _args_pair_info.remove("base")
        }
        if (base != null) {
            _args_pair_info.put("quote", base)
        } else {
            _args_pair_info.remove("quote")
        }
        //  刷新
        _draw_ui_current_pair_assets()
    }

    private fun onFavButtonClicked(quote: JSONObject, base: JSONObject, imageView: ImageView) {
        if (VcUtils.processMyFavPairStateChanged(this, quote, base, associated_view = imageView)) {
            //  界面刷新
            _draw_ui_my_pairs_title()
            _draw_ui_pairs_list()
        }
    }

    private fun _draw_ui_current_pair_assets() {
        val quote = _args_pair_info.optJSONObject("quote")
        if (quote != null) {
            tv_quote_asset.text = quote.getString("symbol")
            tv_quote_asset.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            tv_quote_asset.text = "--"
            tv_quote_asset.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        }

        val base = _args_pair_info.optJSONObject("base")
        if (base != null) {
            tv_base_asset.text = base.getString("symbol")
            tv_base_asset.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            tv_base_asset.text = "--"
            tv_base_asset.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        }
    }

    private fun _draw_ui_my_pairs_title() {
        tv_my_pairs_title.text = String.format(resources.getString(R.string.kSearchTipsMyCustomPairs), _data_array_pairs.size.toString())
    }

    private fun _draw_ui_all() {
        _draw_ui_current_pair_assets()
        _draw_ui_my_pairs_title()
        _draw_ui_pairs_list()
    }

    private fun _draw_ui_pairs_list() {
        val container = layout_trading_pairs_from_trading_pair_mgr
        container.removeAllViews()

        if (_data_array_pairs.isEmpty()) {
            container.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kLabelNoFavMarket), text_color = resources.getColor(R.color.theme01_textColorGray)))
        } else {
            for (data in _data_array_pairs) {
                createCell(container, data)
            }
        }
    }

    private fun createCell(container: LinearLayout, data: JSONObject) {
        val _ctx = this
        val cell = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                gravity = Gravity.CENTER_VERTICAL
            }
            orientation = LinearLayout.HORIZONTAL
        }

        val pAppCache = AppCacheManager.sharedAppCacheManager()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val base = chainMgr.getChainObjectByID(data.getString("base"))
        val quote = chainMgr.getChainObjectByID(data.getString("quote"))
        val quote_symbol = quote.getString("symbol")
        val base_symbol = base.getString("symbol")

        //  左 (交易对 自定义)
        val tv_trading_pair = TextView(this).apply {
            text = "$quote_symbol / $base_symbol"
            gravity = Gravity.CENTER_VERTICAL
            setTextColor(resources!!.getColor(R.color.theme01_textColorMain))
        }
        cell.addView(tv_trading_pair)

        //  自定义标签
        if (!chainMgr.isDefaultPair(quote, base)) {
            val tv_custom = TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                    setMargins(4.dp, 0, 0, 0)
                }
                text = resources.getString(R.string.kSettingApiCellCustomFlag)
                gravity = Gravity.CENTER_VERTICAL
                setPadding(4.dp, 1.dp, 4.dp, 1.dp)
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10.0f)
                background = resources.getDrawable(R.drawable.border_text_view)
            }
            cell.addView(tv_custom)
        }

        //  右 (收藏star图标)
        val layout_iv = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                gravity = Gravity.RIGHT
            }
            gravity = Gravity.RIGHT
            val iv = ImageView(_ctx).apply {
                setImageResource(R.drawable.ic_btn_star)
                setColorFilter(if (pAppCache.is_fav_market(quote.getString("id"), base.getString("id"))) {
                    resources.getColor(R.color.theme01_textColorHighlight)
                } else {
                    resources.getColor(R.color.theme01_textColorGray)
                })
            }
            //  事件 - 点击取消收藏交易对
            iv.setOnClickListener { onFavButtonClicked(quote, base, iv) }
            addView(iv)
        }
        cell.addView(layout_iv)

        //  添加到容器
        container.addView(cell)
        container.addView(ViewLine(this, margin_top = 12.dp, margin_bottom = 12.dp))
    }

}
