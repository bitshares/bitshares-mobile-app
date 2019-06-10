package com.btsplusplus.fowallet.kline

import bitshares.bigDecimalfromAmount
import bitshares.fixComma
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.max
import kotlin.math.min

class TradingPair {

    var _pair: String = ""

    lateinit var _baseAsset: JSONObject
    lateinit var _quoteAsset: JSONObject
    var _baseIsSmart: Boolean = false
    var _quoteIsSmart: Boolean = false

    var _isCoreMarket = false                       //  是否是智能资产市场（该标记需要后期更新）
    var _smartAssetId = ""                          //  智能资产ID
    var _sbaAssetId = ""                            //  背书资产ID

    var _baseId: String = ""
    var _quoteId: String = ""

    var _basePrecision: Int = 0
    var _quotePrecision: Int = 0

    var _basePrecisionPow: Double = 0.0
    var _quotePrecisionPow: Double = 0.0

    var _displayPrecisionDynamic: Boolean = false   //  动态参数是否动态计算完毕（每次进入交易界面计算一次，之后每次更新盘口数据不在重新计算。）
    var _displayPrecision: Int = 8                  //  价格显示精度：资产买盘、卖盘显示精度、出价精度。默认值 -1，需要初始化。
    var _numPrecision: Int = 4                      //  数量显示精度：num_price_total_max_precision - _displayPrecision

    constructor()

    fun initWithBaseID(baseId: String, quoteId: String): TradingPair {

        assert(baseId != null)
        assert(quoteId != null)

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val base = chainMgr.getChainObjectByID(baseId)
        val quote = chainMgr.getChainObjectByID(quoteId)
        return initWithBaseAsset(base, quote)
    }

    fun initWithBaseSymbol(baseSymbol: String, quoteSymbol: String): TradingPair {

        assert(baseSymbol != null)
        assert(quoteSymbol != null)

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val base = chainMgr.getAssetBySymbol(baseSymbol)
        val quote = chainMgr.getAssetBySymbol(quoteSymbol)
        return initWithBaseAsset(base, quote)

    }

    fun initWithBaseAsset(baseAsset: JSONObject, quoteAsset: JSONObject): TradingPair {

        assert(baseAsset != null)
        assert(quoteAsset != null)

        _pair = String.format("%s_%s", baseAsset.getString("symbol"), quoteAsset.getString("symbol"))

        _baseAsset = baseAsset
        _quoteAsset = quoteAsset
        _baseIsSmart = _is_smart(_baseAsset)
        _quoteIsSmart = _is_smart(_quoteAsset)

        _baseId = baseAsset.getString("id")
        _quoteId = quoteAsset.getString("id")
        _basePrecision = _baseAsset.getInt("precision")
        _quotePrecision = _quoteAsset.getInt("precision")
        _basePrecisionPow = Math.pow(10.0, _basePrecision.toDouble())
        _quotePrecisionPow = Math.pow(10.0, _quotePrecision.toDouble())

        //  初始化默认值
        _displayPrecisionDynamic = false
        setDisplayPrecision(-1)

        return this
    }


    /**
     *  (private) 是否是智能货币判断
     */
    private fun _is_smart(asset: JSONObject): Boolean {
        val bitasset_data_id = asset.optString("bitasset_data_id")
        return bitasset_data_id != ""
    }

    /**
     *  (public) 刷新智能资产交易对（市场）标记。即：quote是base的背书资产，或者base是quote的背书资产。
     */
    fun refreshCoreMarketFlag(sba_hash: JSONObject) {
        _isCoreMarket = false
        _smartAssetId = ""
        _sbaAssetId = ""

        val base_sba = sba_hash.optString(_baseId, null)
        if (base_sba != null && base_sba == _quoteId) {
            _isCoreMarket = true
            _smartAssetId = _baseId
            _sbaAssetId = _quoteId
            return
        }

        val quote_sba = sba_hash.optString(_quoteId, null)
        if (quote_sba != null && quote_sba == _baseId) {
            _isCoreMarket = true
            _smartAssetId = _quoteId
            _sbaAssetId = _baseId
            return
        }
    }

    /**
     *  (public) 计算需要显示的喂价信息，不需要显示喂价则返回 nil。
     *
     *  REMARK：返回的结果如果需要显示则需要用 NSString stringWithFormat: 进行格式化。
     */
    fun calcShowFeedInfo(bitasset_data_id_data_array: JSONArray?): BigDecimal? {
        //  1、不需要显示喂价（都不是智能资产）
        if (bitasset_data_id_data_array == null || bitasset_data_id_data_array.length() <= 0) {
            return null
        }

        var current_feed: JSONObject? = null

        if (bitasset_data_id_data_array.length() >= 2) {
            assert(bitasset_data_id_data_array.length() == 2)
            //  2、两种资产都是智能资产
            val first = bitasset_data_id_data_array.getJSONObject(0)
            val last = bitasset_data_id_data_array.getJSONObject(1)
            val first_sba = first.getJSONObject("options").getString("short_backing_asset")
            val last_sba = last.getJSONObject("options").getString("short_backing_asset")
            val first_id = first.getString("asset_id")
            val last_id = last.getString("asset_id")

            if (first_sba == last_id) {
                //  last 给 first 背书，显示 first 资产的喂价。
                current_feed = first.getJSONObject("current_feed")
            } else if (last_sba == first_id) {
                //  first 给 last 背书，显示 last 资产的喂价。
                current_feed = last.getJSONObject("current_feed")
            } else {
                //  例：USD 和 KITTY.CNY - 都是智能资产，但不互相背书
                return null
            }
        } else {
            //  3、base 或 quote 是智能资产
            val first = bitasset_data_id_data_array.getJSONObject(0)
            val first_sba = first.getJSONObject("options").getString("short_backing_asset")
            val first_id = first.getString("asset_id")

            //  base 背书 或者 quote 背书。
            if ((first_id == _baseId && first_sba == _quoteId) || (first_id == _quoteId && first_sba == _baseId)) {
                current_feed = first.getJSONObject("current_feed")
            } else {
                return null
            }
        }

        //  根据喂价数据计算喂价
        assert(current_feed != null)
        val settlement_price = current_feed!!.getJSONObject("settlement_price")
        val asset01 = settlement_price.getJSONObject("base")
        val asset02 = settlement_price.getJSONObject("quote")
        val amount01_amount = asset01.getString("amount")
        val amount02_amount = asset02.getString("amount")

        //  喂价数据（过期or未设置）
        if (amount01_amount.toLong() == 0L || amount02_amount.toLong() == 0L) {
            return null
        }

        //  REMARK：喂价往下取（因为如果往上，那么抵押的时候评估抵押物价值可能略微偏高，在175贴现抵押的时候可能出现误差。）
        //  price = base / quote
        val n_base: BigDecimal
        val n_quote: BigDecimal
        if (asset01.getString("asset_id") == _quoteId) {
            n_base = bigDecimalfromAmount(amount02_amount, _basePrecision)
            n_quote = bigDecimalfromAmount(amount01_amount, _quotePrecision)
        } else {
            n_base = bigDecimalfromAmount(amount01_amount, _basePrecision)
            n_quote = bigDecimalfromAmount(amount02_amount, _quotePrecision)
        }
        return n_base.divide(n_quote, _basePrecision, BigDecimal.ROUND_DOWN)
    }

    /**
     *  (private) 设置显示精度和数量精度信息
     *  display_precision   - 如果该值为 -1，则使用默认值初始化。
     */
    private fun setDisplayPrecision(display_precision: Int) {
        //  如果 display_precision 为负数，则从配置参数获取默认值。
        val parameters = ChainObjectManager.sharedChainObjectManager().getDefaultParameters()
        var tmp_precision = display_precision
        if (tmp_precision < 0) {
            tmp_precision = parameters.getInt("display_precision")
        }

        //  更新价格精度
        _displayPrecision = tmp_precision

        //  更新数量精度（最小0，最大不能超过quote资产本身的precision精度信息。）
        val max_precision = parameters.getInt("num_price_total_max_precision")
        var n = max_precision - _displayPrecision
        n = min(max(n, 0), _quotePrecision)
        _numPrecision = n
    }

    /**
     *  (public) 根据限价单信息动态更新显示精度和数量精度字段
     */
    fun dynamicUpdateDisplayPrecision(limit_data_infos: JSONObject) {
        if (!_displayPrecisionDynamic) {
            _displayPrecisionDynamic = true

            //  获取参考出价信息
            val bids_array = limit_data_infos.getJSONArray("bids")
            val asks_array = limit_data_infos.getJSONArray("asks")
            var ref_item: JSONObject? = null
            if (bids_array != null && bids_array.length() > 0) {
                ref_item = bids_array.getJSONObject(0)
            } else if (asks_array != null && asks_array.length() > 0) {
                ref_item = asks_array.getJSONObject(0)
            } else {
                //  没有深度信息，不用计算了，直接返回。
                return
            }

            //  计算有效精度
            //{
            //    base = "1233.8661";
            //    price = "1.100001101078906";
            //    quote = "1121.695331749937";
            //    sum = "1121.695331749937";
            //}

            val display_min_fraction: Int = ChainObjectManager.sharedChainObjectManager().getDefaultParameters().getInt("display_min_fraction")
            //  REMARK：这里用 %f 格式化代理 %@，否则对于部分小数会格式化出 1e-06 等不可期的数据。
            val price: String = String.format("%f", ref_item.getDouble("price"))
            price.fixComma().let { new_price ->
                if (new_price.indexOf(".") != -1) {
                    val ary = new_price.split(".")
                    val part1: String = ary[0]       //  整数部分
                    if (part1.toInt() > 0) {
                        _displayPrecision = Math.max(_displayPrecision - part1.length, display_min_fraction)
                    } else {
                        val part2: String = ary[1]   //  小数部分
                        var temp: String?
                        var precision = 0
                        for (i in 0 until part2.length) {
                            temp = part2.substring(i, 1)
                            //  非0
                            if (temp != "0") {
                                _displayPrecision += precision
                                break
                            } else {
                                precision += 1
                            }
                        }
                        //  如果 part04 全位0，则 _displayPrecision 不会赋值，则为默认值。
                    }
                } else {
                    //  没有小数点，则默认取2位小数点即可。
                    _displayPrecision = display_min_fraction
                }
            }
            //  更新 num 显示精度
            setDisplayPrecision(_displayPrecision)
            println(String.format("%s - displayPrecision: %d", price, _displayPrecision))
        }
    }


}