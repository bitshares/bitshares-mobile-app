package com.fowallet.walletcore.bts

import android.content.Context
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.btsplusplus.fowallet.utils.BigDecimalHandler
import com.orhanobut.logger.Logger
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.math.BigInteger
import kotlin.math.floor


class ChainObjectManager {

    /**
     *  各种属性定义
     */
    var isTestNetwork: Boolean = false          //  是否是测试网络
    var grapheneChainID: String                 //  石墨烯区块链ID
    var grapheneCoreAssetID: String             //  石墨烯网络核心资产ID
    var grapheneAssetSymbol: String             //  石墨烯网络核心资产名称
    var grapheneAddressPrefix: String           //  石墨烯网络地址前缀

    var _cacheAssetSymbol2ObjectHash: MutableMap<String, JSONObject>    //  内存缓存
    var _cacheObjectID2ObjectHash: MutableMap<String, JSONObject>       //  内存缓存
    var _cacheAccountName2ObjectHash: MutableMap<String, JSONObject>    //  内存缓存
    var _cacheUserFullAccountData: MutableMap<String, JSONObject>       //  内存缓存
    var _cacheVoteIdInfoHash: MutableMap<String, JSONObject>            //  内存缓存

    var _defaultMarketInfos: JSONObject?                                         //  ipa自带的默认配置信息（fowallet_market.json）
    var _defaultMarketPairs: JSONObject? = null                             //  默认内置交易对。交易对格式：#{base_symbol}_#{quote_symbol}
    lateinit var _defaultMarketBaseHash: MutableMap<String, JSONObject>          //  默认内置市场的 Hash 格式。base_symbol => market_info

    var _defaultGroupList: JSONArray? = null                            //  默认分组信息列表（按照id升序列排列）

    var _tickerDatas: MutableMap<String, Any>                           //  行情 ticker 数据 格式：#{base_symbol}_#{quote_symbol} => ticker_data

    var _mergedMarketInfoList: MutableList<JSONObject>                 //  市场信息列表 默认市场信息的基础上合并了自定义交易对后的市场信息。

    var _estimate_unit_hash: MutableMap<String, JSONObject>             //  计价单位 Hash 计价货币symbol => {...}

    //  单例方法
    companion object {
        var _sharedChainObjectManager: ChainObjectManager? = null

        fun sharedChainObjectManager(): ChainObjectManager {

            if (_sharedChainObjectManager == null) {
                _sharedChainObjectManager = ChainObjectManager()
            }
            return _sharedChainObjectManager!!
        }
    }


    constructor() {

        //  初始化各种属性默认值
        isTestNetwork = false
        grapheneChainID = BTS_NETWORK_CHAIN_ID
        grapheneCoreAssetID = BTS_NETWORK_CORE_ASSET_ID
        grapheneAssetSymbol = BTS_NETWORK_CORE_ASSET
        grapheneAddressPrefix = BTS_ADDRESS_PREFIX

        _cacheAssetSymbol2ObjectHash = mutableMapOf()
        _cacheObjectID2ObjectHash = mutableMapOf()
        _cacheAccountName2ObjectHash = mutableMapOf()
        _cacheUserFullAccountData = mutableMapOf()
        _cacheVoteIdInfoHash = mutableMapOf()

        _defaultMarketInfos = null
        _defaultMarketPairs = null
        _defaultGroupList = null

        _tickerDatas = mutableMapOf()
        _mergedMarketInfoList = mutableListOf()
        _estimate_unit_hash = mutableMapOf()

    }

    /**
     *  (public) 启动初始化
     */
    fun initAll(ctx: Context) {
        loadDefaultMarketInfos(ctx)
        buildAllMarketsInfos()
    }

    private fun loadDefaultMarketInfos(ctx: Context) {
        if (_defaultMarketInfos != null) {
            return
        }
        _defaultMarketInfos = Utils.readJsonToMap(ctx, "fowallet_config.json")
        assert(_defaultMarketInfos != null)

        // 获取 markets
        val markets = _defaultMarketInfos!!.getJSONArray("markets")

        //  初始化默认交易对和默认市场Hash
        _defaultMarketPairs = JSONObject()
        _defaultMarketBaseHash = mutableMapOf()

        for (i in 0 until markets.length()) {
            val market = markets.getJSONObject(i)
            val base = market.getJSONObject("base")
            val base_symbol = base.getString("symbol")
            val group_list = market.getJSONArray("group_list")
            for (j in 0 until group_list.length()) {
                val group = group_list.getJSONObject(j)
                val quote_list = group.getJSONArray("quote_list")
                for (k in 0 until quote_list.length()) {
                    val quote_symbol = quote_list.getString(k)
                    _defaultMarketPairs!!.put("${base_symbol}_${quote_symbol}", true)
                }
            }
            _defaultMarketBaseHash[base_symbol] = market
        }

        //  内部资产也添加到资产列表
        appendAssets(_defaultMarketInfos!!.getJSONObject("internal_assets"))

        //  初始化内部分组信息（并排序）
        _defaultGroupList = getDefaultGroupInfos().values().toList<JSONObject>().sortedBy { it.getInt("id") }.toJsonArray()

        //  初始化计价方式 Hash
        val estimate_unit_list = getEstimateUnitList()
        for (i: Int in 0 until estimate_unit_list.length()) {
            val currency = estimate_unit_list.getJSONObject(i)
            val symbol = currency.getString("symbol")
            _estimate_unit_hash.set(symbol, currency)
        }

        //  初始化主题风格列表 Todo 翻译
        // [[ThemeManager sharedThemeManager] initThemeFromConfig:[_defaultMarketInfos objectForKey:@"internal_themes"]];
    }

    /**
     *  (private) 计算资产所属分组信息（给自定义资产归类）
     */
    private fun auxCalcGroupInfo(quote_asset: JSONObject): JSONObject {
        assert(_defaultGroupList != null)

        val quote_issuer = quote_asset.getString("issuer")
        for (group in _defaultGroupList!!) {
            val group_info = group!!
            //  自定义资产都不归纳到主区
            if (group_info.optBoolean("main", false)) {
                continue
            }
            //  考虑归纳到特定网关里
            if (group_info.optBoolean("gateway", false)) {
                var issuer_matched = false
                val group_info_issuer = group_info.optJSONArray("issuer")
                if (group_info_issuer != null) {
                    for (i in 0 until group_info_issuer.length()) {
                        val issuer_account_id = group_info_issuer.getString(i)
                        if (issuer_account_id == quote_issuer) {
                            issuer_matched = true
                            break
                        }
                    }
                }
                //  第一步、资产发行人和网关发行人一致
                if (issuer_matched) {
                    //  第二步、资产发行人一致的前提下再判断资产的前缀是否和网关前缀一致。（例：WWW网关发行人发了个资产SEER，但是没有WWW.前缀。）
                    val group_prefix = group_info.optString("prefix", "")
                    val quote_name = quote_asset.getString("symbol")
                    if (quote_name.indexOf(group_prefix) == 0) {
                        val ary = quote_name.split(".")
                        if (ary.count() >= 2 && ary[0] == group_prefix) {
                            //  匹配：返回对应分组
                            return group_info
                        }
                    }
                }
                continue
            }
            //  归纳到其他区
            if (group_info.optBoolean("other")) {
                return group_info
            }
        }
        //  not reached...
        assert(false)
        return JSONObject()
    }

    /**
     *  生成所有市场的分组信息（包括内置交易对和自定义交易对）初始化调用、每次添加删除自定义交易对时调用。
     */
    fun buildAllMarketsInfos() {
        _mergedMarketInfoList.clear()

        //  获取内置默认市场信息
        val defaultMarkets = getDefaultMarketInfos()

        //  获取自定义交易对信息 格式参考：#{basesymbol}_#{quotesymbol} => @{@"quote":quote_asset(object),@"base":base_symbol}
        val custom_markets = AppCacheManager.sharedAppCacheManager().get_all_custom_markets()
        if (custom_markets.length() <= 0) {
            for (i: Int in 0 until defaultMarkets.length()) {
                _mergedMarketInfoList.add(defaultMarkets.getJSONObject(i))
            }
            return
        }

        //  开始合并
        val market_hash = JSONObject()
        for (i in 0 until defaultMarkets.length()) {
            val market = defaultMarkets.getJSONObject(i)
            val base_symbol = market.getJSONObject("base").getString("symbol")
            //  REMARK: clone
            val new_market = JSONObject(market.toString())
            market_hash.put(base_symbol, new_market)
            _mergedMarketInfoList.add(new_market)
        }

        //  循环所有自定义交易对，分别添加到对应分组里。
        for (pair in custom_markets.keys()) {
            val info = custom_markets.getJSONObject(pair)
            val base_symbol = info.getString("base")
            //  base_symbol 决定分在哪个大的 market 里。
            val target_market = market_hash.optJSONObject(base_symbol)
            if (target_market == null) {
                //  REMARK：已经删除掉的市场。比如添加了 CNC，用户自定义之后又删除了 CNC 市场。
                continue
            }
            //  quote 决定分在哪个 group 里。
            val quote_asset = info.getJSONObject("quote")
            val quote_symbol = quote_asset.getString("symbol")
            //  不应该出现
            if (quote_symbol == base_symbol) {
                continue
            }
            //  添加资产
            appendAssetCore(quote_asset)
            //  计算 asset 所属分组
            val target_group_info = auxCalcGroupInfo(quote_asset)
            //  从当前市场获取该分组信息
            val target_group_info_id = target_group_info.getInt("id")
            var matched_group_info: JSONObject? = null
            for (group in target_market.getJSONArray("group_list")) {
                val group_info_02 = getGroupInfoFromGroupKey(group!!.getString("group_key"))
                if (group_info_02.getInt("id") == target_group_info_id) {
                    matched_group_info = group
                    break
                }
            }
            //  当前市场存在该分组，只直接添加到该分组里。否则新建一个分组，并把该分组信息添加到市场分组列表。
            if (matched_group_info != null) {
                matched_group_info.getJSONArray("quote_list").put(quote_symbol)
            } else {
                matched_group_info = jsonObjectfromKVS("group_key", target_group_info.getString("key"), "quote_list", jsonArrayfrom(quote_symbol))
                target_market.getJSONArray("group_list").put(matched_group_info)
            }
        }

        //  重新排序下每个市场下的分组顺序
        for (market in _mergedMarketInfoList) {
            val group_list = market.getJSONArray("group_list").toList<JSONObject>()
            val sorted_group_list = group_list.sortedBy { getGroupInfoFromGroupKey(it.getString("group_key")).getInt("id") }.toJsonArray()
            market.remove("group_list")
            market.put("group_list", sorted_group_list)
        }
    }

    /**
     *  (public) 获取部分默认配置参数
     */
    fun getDefaultParameters(): JSONObject {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONObject("parameters")
    }

    /**
     *  (public) 获取水龙头部分配置参数
     */
    fun getDefaultFaucet(): JSONObject {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONObject("faucet")
    }

    /**
     * (public) 获取最后选用的水龙头注册地址
     */
    fun getFinalFaucetURL(): String {
        //  1、优先从服务器动态获取
        val serverConfig = SettingManager.sharedSettingManager().serverConfig
        if (serverConfig != null) {
            val serverFaucetURL = serverConfig.optString("faucetURL", "")
            if (serverFaucetURL != "") {
                return serverFaucetURL
            }
        }
        //  2、其次获取app内默认配置
        val baseURL = getDefaultFaucet().getString("url")
        return "${baseURL}/register"
    }

    /**
     *  (public) 获取抵押排行榜配置列表
     */
    fun getCallOrderRankingSymbolList(): JSONArray {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONArray("call_order_ranking_list")
    }

    /**
     *  (public) 获取喂价详情的配置列表
     */
    fun getDetailFeedPriceSymbolList(): JSONArray {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONArray("detail_feedprice_list")
    }

    /**
     *  (public) 获取可借贷的资产配置列表
     */
    fun getDebtAssetList(): JSONArray {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONArray("debt_asset_list")
    }

    /**
     *  (public) 获取手续费列表（按照列表优先选择）
     */
    fun getFeeAssetSymbolList(): JSONArray {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONArray("fee_assets_list")
    }


    /**
     *  (public) 获取支持的记账单位列表
     */
    fun getEstimateUnitList(): JSONArray {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONArray("estimate_unit")
    }

    /**
     *  (public) 根据计价货币symbol获取计价单位配置信息
     */
    fun getEstimateUnitBySymbol(symbol: String): JSONObject {
        return _estimate_unit_hash[symbol]!!
    }

    /**
     *  (public) 获取网络配置信息
     */
    fun getCfgNetWorkInfos(): JSONObject {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONObject("network_infos")
    }

    /**
     *  (public) 获取资产作为交易对中的 base 资产的优先级，两者之中，优先级高的作为 base，另外一个作为 quote。
     */
    fun genAssetBasePriorityHash(): JSONObject {
        val asset_base_priority = JSONObject()
        var max_priority = 1000
        //  REMARK：优先级 从 CNY 到 BTS 逐渐降低，其他非市场 base 的资产优先级默认为 0。
        val default_markets = getDefaultMarketInfos()
        for (i in 0 until default_markets.length()) {
            val market = default_markets.getJSONObject(i)
            val symbol = market.getJSONObject("base").getString("symbol")
            asset_base_priority.put(symbol, max_priority)
            max_priority -= 1
        }
        return asset_base_priority
    }

    /**
     *  (public) 获取最终的市场列表信息（默认 + 自定义）
     */
    fun getMergedMarketInfos(): MutableList<JSONObject> {
        return _mergedMarketInfoList
    }

    /**
     *  (public) 获取默认的 markets 列表信息
     */
    fun getDefaultMarketInfos(): JSONArray {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONArray("markets")
    }

    /**
     *  (public) 根据 base_symbol 获取 market 信息。
     */
    fun getDefaultMarketInfoByBaseSymbol(base_symbol: String): JSONObject {
        return _defaultMarketBaseHash[base_symbol]!!
    }

    /**
     *  (public) 获取默认所有的分组信息
     */
    fun getDefaultGroupInfos(): JSONObject {
        assert(_defaultMarketInfos != null)
        return _defaultMarketInfos!!.getJSONObject("internal_groups")
    }

    /**
     *  (public) 获取 or 更新全局属性信息（包括活跃理事会、活跃见证人、手续费等信息）REMARK：该对象ID固定为 2.0.0。
     */
    fun getObjectGlobalProperties(): JSONObject {
        return _cacheObjectID2ObjectHash[BTS_GLOBAL_PROPERTIES_ID]!!
    }

    fun updateObjectGlobalProperties(gp: JSONObject?) {
        if (gp != null) {
            _cacheObjectID2ObjectHash[BTS_GLOBAL_PROPERTIES_ID] = gp
        }
    }

    fun queryGlobalProperties(): Promise {
        val api = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return api.async_exec_db("get_global_properties").then {
            val global_data = it as JSONObject
            updateObjectGlobalProperties(global_data)
            return@then global_data
        }
    }

    /**
     *  (public) 获取指定分组信息
     */
    fun getGroupInfoFromGroupKey(group_key: String): JSONObject {
        assert(group_key != null)
        return getDefaultGroupInfos().getJSONObject(group_key)
    }

    /**
     *  (public) 是否是内置交易对判断
     */
    fun isDefaultPair(quote: JSONObject, base: JSONObject): Boolean {
        val pair = "${base.getString("symbol")}_${quote.getString("symbol")}"
        return _defaultMarketPairs!!.optBoolean(pair, false)
    }

    fun isDefaultPair(base_symbol: String, quote: JSONObject): Boolean {
        val pair = "${base_symbol}_${quote.getString("symbol")}"
        return _defaultMarketPairs!!.optBoolean(pair, false)
    }

    fun isDefaultPair(base_symbol: String, quote_symbol: String): Boolean {
        val pair = "${base_symbol}_${quote_symbol}"
        return _defaultMarketPairs!!.optBoolean(pair, false)
    }

    /**
     *  根据名字、符号、ID等获取各种区块链对象。
     */
    fun getAssetBySymbol(symbol: String): JSONObject {
        assert(_cacheAssetSymbol2ObjectHash != null)
        assert(symbol != null)
        return _cacheAssetSymbol2ObjectHash[symbol]!!
    }

    fun getChainObjectByID(oid: String): JSONObject {
        return _cacheObjectID2ObjectHash[oid]!!
    }

    fun getChainObjectByIDSafe(oid: String): JSONObject? {
        return _cacheObjectID2ObjectHash[oid]
    }

    fun getVoteInfoByVoteID(vote_id: String): JSONObject? {
        return _cacheVoteIdInfoHash[vote_id]
    }

    fun getAccountByName(name: String): JSONObject {
        assert(_cacheAccountName2ObjectHash != null)
        assert(name != null)
        return _cacheAccountName2ObjectHash[name]!!
    }

    fun getBlockHeaderInfoByBlockNumber(block_number: String): JSONObject? {
        val oid = "100.0.${block_number}"     //  REMARK：block_num 不是对象ID，特殊处理。可能不存在，部分节点可能查询不到header信息。
        return _cacheObjectID2ObjectHash[oid]
    }

    fun getFullAccountDataFromCache(account_id_or_name: String): JSONObject? {
        assert(_cacheUserFullAccountData != null)
        assert(account_id_or_name != null)
        return _cacheUserFullAccountData[account_id_or_name]
    }

    /**
     *  添加资产
     */
    fun appendAssets(assets_name2obj_hash: JSONObject) {
        assets_name2obj_hash.keys().forEach { name: String ->
            val obj = assets_name2obj_hash.getJSONObject(name)
            appendAssetCore(obj)
        }
    }

    private fun appendAssetCore(asset: JSONObject) {
        assert(asset != null)
        _cacheObjectID2ObjectHash[asset.getString("id")] = asset          //  1.3.0格式
        _cacheAssetSymbol2ObjectHash[asset.getString("symbol")] = asset
    }

    /**
     *  (public) 更新缓存
     */
    fun updateGrapheneObjectCache(data_array: JSONArray?) {
        if (data_array != null && data_array.length() > 0) {
            val pAppCache = AppCacheManager.sharedAppCacheManager()
            data_array.forEach<JSONObject> { obj ->
                if (obj != null) {
                    val oid = obj.optString("id")
                    if (oid != "") {
                        pAppCache.update_object_cache(oid, obj)
                        _cacheObjectID2ObjectHash[oid] = obj
                    }
                }
            }
            pAppCache.saveObjectCacheToFile()
        }
    }

    /**
     *  (public) 获取手续费对象
     *  extra_balance   - key: asset_type   value: balance amount
     */
    fun getFeeItem(op_code: EBitsharesOperations, full_account_data: JSONObject?, extra_balance: JSONObject? = null): JSONObject {
        var local_full_account_data = full_account_data
        if (local_full_account_data == null) {
            val wallet_account_info = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
            val account_id = wallet_account_info.getJSONObject("account").getString("id")
            local_full_account_data = getFullAccountDataFromCache(account_id)
            if (local_full_account_data == null) {
                local_full_account_data = wallet_account_info
            }
        }
        return estimateFeeObject(op_code.value, local_full_account_data, extra_balance)
    }

    /**
     *  (public) 评估指定交易操作所需要的手续费信息
     */
    fun estimateFeeObject(op: Int, full_account_data: JSONObject, extra_balance: JSONObject? = null): JSONObject {
        val balance_hash = JSONObject()
        for (balance_object in full_account_data.getJSONArray("balances")) {
            val asset_type = balance_object!!.getString("asset_type")
            var balance = balance_object.getString("balance")
            if (extra_balance != null) {
                val extra_amount = extra_balance.optString(asset_type, null)
                if (extra_amount != null) {
                    balance = BigInteger(balance).add(BigInteger(extra_amount)).toString()
                }
            }
            balance_hash.put(asset_type, JSONObject().apply {
                put("asset_id", asset_type)
                put("amount", balance)
            })
        }

        //  合并
        if (extra_balance != null) {
            extra_balance.keys().forEach { asset_type ->
                if (balance_hash.optJSONObject(asset_type) == null) {
                    val extra_amount = extra_balance.getString(asset_type)
                    balance_hash.put(asset_type, JSONObject().apply {
                        put("asset_id", asset_type)
                        put("amount", extra_amount)
                    })
                }
            }
        }

        return estimateFeeObject(op, balance_hash.values())
    }

    fun estimateFeeObject(op: Int, balance_list: JSONArray): JSONObject {
        //  TODO:fowallet!!!! 对于需要 price_per_kbyte 的 op 目前尚不支持。

        //  REMARK：fee_list的资产更新及时（尽可能在每次进入操作前进行更新、比如交易、转账之前。）
        val fee_list = getFeeAssetSymbolList()

        //  获取指定操作的默认手续费信息
        val gp = getObjectGlobalProperties()
        val parameters = gp.getJSONObject("parameters")
        val current_fees = parameters.getJSONObject("current_fees")
        var fee_item_args: JSONObject? = null
        for (op_array in current_fees.getJSONArray("parameters").forin<JSONArray>()) {
            val op_code = op_array!![0] as Int
            if (op_code == op) {
                fee_item_args = op_array[1] as JSONObject
                break
            }
        }
        assert(fee_item_args != null)
        val scale = current_fees.getString("scale").toDouble()
        var fee_amount = fee_item_args!!.getInt("fee")
        val price_per_kbyte = fee_item_args.optInt("price_per_kbyte", -1)
        //  TODO:fowallet 转账等操作，默认按照1KB价格评估。
        if (price_per_kbyte >= 0) {
            fee_amount += price_per_kbyte
        }
        var bts_fee = fee_amount.toLong()
        //  手续费缩放系数
        bts_fee = Math.ceil(bts_fee * scale / 10000.0).toLong()
        val bts_asset = getChainObjectByID(BTS_NETWORK_CORE_ASSET_ID)
        val bts_precision = bts_asset.getInt("precision")
        val bts_fee_real = OrgUtils.calcAssetRealPrice(bts_fee, bts_precision)
        //  转换资产列表为 资产Hash。格式：asset_id=>amount
        var balance_hash = JSONObject()
        for (balance in balance_list) {
            balance_hash.put(balance!!.getString("asset_id"), balance.getString("amount"))
        }

        //  循环遍历手续费列表，寻找第一个足够支付手续费的资产。
        for (fee_symbol in fee_list.forin<String>()) {
            val fee_asset = getAssetBySymbol(fee_symbol!!)
            val fee_asset_id = fee_asset.getString("id")

            //  该 fee 当前余额
            val fee_balance_amount = balance_hash.optString(fee_asset_id, "0").toLong()

            //  该 fee 是 BTS 还是其他资产分别处理
            if (fee_asset_id == BTS_NETWORK_CORE_ASSET_ID) {
                if (fee_balance_amount >= bts_fee) {
                    val result = JSONObject()
                    result.put("fee_asset_id", fee_asset_id)
                    result.put("amount", fee_amount)
                    result.put("amount_real", bts_fee_real)
                    result.put("sufficient", true)
                    return result
                }
            } else {
                //  其他其他没动态资产信息，则不能作为手续费。
                val dynamic_asset_data_id = fee_asset.optString("dynamic_asset_data_id")
                if (dynamic_asset_data_id == null || dynamic_asset_data_id == "") {
                    continue
                }

                //  没有手续费池信息，也不能作为手续费。
                val dynamic_asset_data = getChainObjectByIDSafe(dynamic_asset_data_id)
                if (dynamic_asset_data == null) {
                    continue
                }

                //  其他资产和 BTS 资产进行兑换
                val core_exchange_rate = fee_asset.optJSONObject("options")?.optJSONObject("core_exchange_rate")
                //  没有 core_exchange_rate 信息，则不能作为手续费。
                if (core_exchange_rate == null) {
                    continue
                }

                val core_base = core_exchange_rate.getJSONObject("base")
                val core_quote = core_exchange_rate.getJSONObject("quote")

                var fee_amount: Any? = null
                var bts_amount: Any? = null
                if (core_base.getString("asset_id") == BTS_NETWORK_CORE_ASSET_ID) {
                    //  rate = quote / base(bts)
                    fee_amount = core_quote.get("amount")
                    bts_amount = core_base.get("amount")
                } else {
                    //  rate = base / quote(bts)
                    fee_amount = core_base.get("amount")
                    bts_amount = core_quote.get("amount")
                }

                //  bts 数量
                val bts_real = OrgUtils.calcAssetRealPrice(bts_amount!!, bts_precision)

                //  fee 数量
                val fee_precision = fee_asset.getInt("precision")
                val fee_amount_integer = fee_amount.toString().toLong()
                val fee_precision_pow = Math.pow(10.0, fee_precision.toDouble())
                val fee_real: Double = fee_amount_integer / fee_precision_pow

                //  REMARK：用于 CNY、USD 等兑换 BTS 的比例一直都在更新中，避免在用户操作过程中，兑换比例变化导致手续费不足。这里添加一个系数。
                val final_fee_real = 1.2 * fee_real / bts_real * bts_fee_real

                //  向上取整
                val final_fee_amount = Math.ceil(final_fee_real * fee_precision_pow).toLong()

                //  REMARK：这里再把 其他资产的手续费(比如CNY)兑换回 BTS 值，然后判断 CNY 资产的手续费池是否足够。重要！！！
                val pool_min_value = Math.ceil(bts_real / fee_real * (final_fee_amount / fee_precision_pow) * scale)

                //  手续费池余额不足
                if (dynamic_asset_data.getString("fee_pool").toLong() < pool_min_value) {
                    continue
                }

                //  其他资产手续费足够！！
                if (fee_balance_amount >= final_fee_amount) {
                    //  CNY、USD等资产足够支付手续费
                    val result = JSONObject()
                    result.put("fee_asset_id", fee_asset_id)
                    result.put("amount", final_fee_amount)
                    result.put("amount_real", final_fee_real)
                    result.put("sufficient", true)
                    return result
                }
            }
        }

        //  默认选择BTS支付、但手续费不足。
        val result = JSONObject()
        result.put("fee_asset_id", BTS_NETWORK_CORE_ASSET_ID)
        result.put("amount", fee_amount)
        result.put("amount_real", bts_fee_real)
        result.put("sufficient", false)
        return result
    }


    /**
     *  (public) 石墨烯网络初始化，优先调用。重要。
     */
    fun grapheneNetworkInit(): Promise {
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return conn.async_exec_db("get_chain_properties").then { chain_properties: Any? ->
            val json = chain_properties as JSONObject
            //  石墨烯网络区块链ID和BTS主网链ID不同，则为测试网络，不判断核心资产名字。因为测试网络资产名字也可能为BTS。
            val chain_id = json.optString("chain_id")
            isTestNetwork = chain_id == null || chain_id.toString() != BTS_NETWORK_CHAIN_ID
            grapheneChainID = chain_id.toString()
            if (isTestNetwork) {
                //  测试网络：继续初始化核心资产信息
                return@then conn.async_exec_db("get_config").then { graphene_config_data: Any? ->
                    val json = graphene_config_data as JSONObject
                    grapheneAssetSymbol = json.getString("GRAPHENE_SYMBOL")
                    grapheneAddressPrefix = json.getString("GRAPHENE_ADDRESS_PREFIX")
                    return@then true
                }
            } else {
                //  正式网络：直接返回初始化成功
                return@then true
            }
        }

    }


    /**
     *  启动 app 时初始化所有市场的 ticker 数据。（包括自定义市场）
     */
    fun marketsInitAllTickerData(): Promise {
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val promise_list = JSONArray()
        val pairs_list = mutableListOf<String>()

        for (market: JSONObject in getMergedMarketInfos()) {
            val base_item = market.getJSONObject("base")
            val base_name = base_item.getString("name")
            val base_symbol = base_item.getString("symbol")
            val group_list = market.getJSONArray("group_list")
            for (i in 0 until group_list.length()) {
                val group_info = group_list.getJSONObject(i)
                val quote_list = group_info.getJSONArray("quote_list")
                for (j in 0 until quote_list.length()) {
                    val quote_symbol = quote_list.getString(j)
                    pairs_list.add("${base_symbol}_${quote_symbol}")
                    Logger.d("pairs: ${quote_symbol}/${base_name}")
                    promise_list.put(conn.async_exec_db("get_ticker", jsonArrayfrom(base_symbol, quote_symbol)))
                }
            }
        }

        return Promise.all(promise_list).then {
            val data_list = it as JSONArray
            var idx = 0
            for (ticker in data_list.forin<Any>()) {
                val pair = pairs_list[idx]
                _tickerDatas[pair] = ticker!!
                ++idx
            }
            return@then true
        }
    }


    /**
     *  查询Ticker数据（参数：base、quote构成的Hash的列表。）
     */
    fun queryTickerDataByBaseQuoteSymbolArray(base_quote_symbol_array: JSONArray): Promise {
        //  要查询的数据为空，则直接返回。
        if (base_quote_symbol_array == null || base_quote_symbol_array.length() <= 0) {
            return Promise._resolve(true)
        }

        //  构造交易对进行查询
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val promise_list = JSONArray()
        val pairs_list = mutableListOf<String>()

        for (pair_info in base_quote_symbol_array) {
            val base_symbol = pair_info!!.getString("base")
            val quote_symbol = pair_info.getString("quote")
            //  REMARK：pair格式：#{base_symbol}_#{quote_symbol}
            pairs_list.add(String.format("%s_%s", base_symbol, quote_symbol))
            promise_list.put(conn.async_exec_db("get_ticker", jsonArrayfrom(base_symbol, quote_symbol)))
        }

        return Promise.all(promise_list).then {
            val data_list = it as JSONArray
            var idx = 0
            for (ticker in data_list.forin<Any>()) {
                val pair = pairs_list[idx]
                _tickerDatas[pair] = ticker!!
                ++idx
            }
            return@then true
        }

    }

    /**
     *  获取行情的 ticker 数据
     */
    fun getTickerData(base_symbol: String, quote_symbol: String): JSONObject? {
        val pair = String.format("%s_%s", base_symbol, quote_symbol)
        return _tickerDatas[pair] as? JSONObject
    }

    /**
     *  更新 ticker 数据
     */
    fun updateTickeraData(base_symbol: String, quote_symbol: String, ticker: JSONObject?) {
        if (ticker != null) {
            val pair = String.format("%s_%s", base_symbol, quote_symbol)
            _tickerDatas[pair] = ticker
        }
    }

    fun updateTickeraData(pair: String, ticker: JSONObject?) {
        if (ticker != null) {
            _tickerDatas[pair] = ticker
        }
    }

    /**
     *  (public) 查询手续费资产的详细信息（包括动态信息）
     */
    fun queryFeeAssetListDynamicInfo(): Promise {
        var asset_id_array = JSONArray()
        val fee_asset_symbol_list = getFeeAssetSymbolList()
        for (i in 0 until fee_asset_symbol_list.length()) {
            val fee_symbol = fee_asset_symbol_list[i].toString()
            val fee_asset = getAssetBySymbol(fee_symbol)
            val fee_asset_id = fee_asset.getString("id")
            //  BTS 资产作为支付手续费的核心资产，则不用查询，足够即可。
            if (fee_asset_id.equals(BTS_NETWORK_CORE_ASSET_ID)) {
                continue
            }
            //  添加到查询列表
            asset_id_array.put(fee_asset_id)
        }
        Logger.d("[Track] queryFeeAssetListDynamicInfo start.")

        return queryAllObjectsInfo(asset_id_array, _cacheAssetSymbol2ObjectHash, "symbol", true, null).then {
            val asset_hash = it as JSONObject
            Logger.d("[Track] queryFeeAssetListDynamicInfo step01 finish.")
            //  仅有 BTS 可支付手续费，那么这里应该为空了。
            if (asset_hash.length() <= 0) {
                return@then null
            }
            val dynamic_id_list = JSONArray()
            asset_hash.values().forEach<JSONObject> { dynamic_id_list.put(it!!.getString("dynamic_asset_data_id")) }

            //  查询资产的手续费池信息
            val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            return@then conn.async_exec_db("get_objects", jsonArrayfrom(dynamic_id_list)).then { data_array ->
                val json_array = data_array as JSONArray
                Logger.d("[Track] queryFeeAssetListDynamicInfo step02 finish.")
                //  更新内存缓存
                for (obj in json_array) {
                    if (obj == null) {
                        continue
                    }
                    val oid = obj.getString("id")
                    _cacheObjectID2ObjectHash[oid] = obj        //  add to memory cache: id hash
                }
                return@then null
            }
        }
    }

    /**
     *  (public) 查询智能资产的信息（非智能资产返回nil）
     */
    fun queryShortBackingAssetInfos(asset_id_list: JSONArray): Promise {
        return queryAllAssetsInfo(asset_id_list).then {
            val asset_hash = it as JSONObject
            val asset_bitasset_hash = JSONObject()
            val bitasset_id_list = JSONArray()
            asset_id_list.forEach<String> { item ->
                val asset_id = item!!
                val asset = asset_hash.getJSONObject(asset_id)
                val bitasset_data_id = asset.optString("bitasset_data_id")
                if (bitasset_data_id != "") {
                    bitasset_id_list.put(bitasset_data_id)
                    asset_bitasset_hash.put(asset_id, bitasset_data_id)
                }
            }
            return@then queryAllGrapheneObjects(bitasset_id_list).then { resultHash ->
                val bitasset_hash = resultHash as JSONObject
                val sba_hash = JSONObject()
                asset_bitasset_hash.keys().forEach { asset_id ->
                    val bitasset_data_id = asset_bitasset_hash.getString(asset_id)
                    val bitasset_data = bitasset_hash.getJSONObject(bitasset_data_id)
                    val short_backing_asset = bitasset_data.getJSONObject("options").getString("short_backing_asset")
                    sba_hash.put(asset_id, short_backing_asset)
                }
                return@then sba_hash
            }
        }
    }

    /**
     *  (public) 查询所有投票ID信息
     */
    fun queryAllVoteIds(vote_id_array: JSONArray): Promise {

        //  TODO:分批查询？
        assert(vote_id_array.length() < 1000)

        val resultHash = JSONObject()

        //  要查询的数据为空，则返回空的 Hash。
        if (vote_id_array.length() <= 0) {
            return Promise._resolve(resultHash)
        }

        val queryArray = JSONArray()

        //  从缓存加载
        val pAppCache = AppCacheManager.sharedAppCacheManager()
        val now_ts = Utils.now_ts()

        vote_id_array.forEach<String> {
            val vote_id = it!!
            val obj = pAppCache.get_object_cache_ts(vote_id, now_ts)
            if (obj != null) {
                _cacheVoteIdInfoHash[vote_id] = obj     //  add to memory cache: id hash
                resultHash.put(vote_id, obj)
            } else {
                queryArray.put(vote_id)
            }
        }
        if (queryArray.length() == 0) {
            return Promise._resolve(resultHash)
        }
        //  从网络查询。
        val api = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return api.async_exec_db("lookup_vote_ids", jsonArrayfrom(queryArray)).then {
            val data_array = it as JSONArray

            data_array.forEach<JSONObject?> {
                val obj = it
                if (obj != null) {
                    val vid = obj.optString("vote_id", null)
                    if (vid != null) {
                        pAppCache.update_object_cache(vid, obj)
                        _cacheVoteIdInfoHash[vid] = obj           //  add to memory cache: id hash
                        resultHash.put(vid, obj)
                    } else {
                        val vote_for = obj.getString("vote_for")
                        val vote_against = obj.getString("vote_against")

                        pAppCache.update_object_cache(vote_for, obj)
                        _cacheVoteIdInfoHash[vote_for] = obj      //  add to memory cache: id hash
                        resultHash.put(vote_for, obj)

                        pAppCache.update_object_cache(vote_against, obj)
                        _cacheVoteIdInfoHash[vote_against] = obj  //  add to memory cache: id hash
                        resultHash.put(vote_against, obj)
                    }
                }
            }
            //  保存缓存
            pAppCache.saveObjectCacheToFile()
            //  返回结果
            return@then resultHash
        }
    }

    /**
     *  (private) 查询指定对象ID列表的所有对象信息，返回 Hash。 格式：{对象ID=>对象信息, ...}
     *
     *  skipQueryCache - 控制是否查询缓存
     *
     *  REMARK：不处理异常，在外层 VC 逻辑中处理。外部需要 catch 该 promise。
     */
    fun queryAllObjectsInfo(object_id_array: JSONArray, cache: MutableMap<String, JSONObject>?, key: String?, skipQueryCache: Boolean, skipCacheIdHash: JSONObject?): Promise {

        val resultHash = JSONObject()

        //  要查询的数据为空，则返回空的 Hash。
        if (object_id_array.length() <= 0) {
            return Promise._resolve(resultHash)
        }

        val queryArray = JSONArray()
        if (skipQueryCache) {
            //  忽略缓存：重新查询所有ID
            queryArray.putAll(object_id_array)
        } else {
            //  从缓存加载
            val pAppCache = AppCacheManager.sharedAppCacheManager()
            val now_ts = Utils.now_ts()
            for (object_id in object_id_array.forin<String>()) {
                if (skipCacheIdHash != null && skipCacheIdHash.has(object_id)) {
                    //  部分ID跳过缓存
                    queryArray.put(object_id)
                } else {
                    val obj = pAppCache.get_object_cache_ts(object_id!!, now_ts)
                    if (obj != null) {
                        _cacheObjectID2ObjectHash[object_id] = obj  //  add to memory cache: id hash
                        if (cache != null && key != null) {
                            cache[obj.getString(key)] = obj         //  add to memory cache: key hash
                        }
                        resultHash.put(object_id, obj)
                    } else {
                        queryArray.put(object_id)
                    }
                }
            }
            //  从缓存获取完毕，直接返回。
            if (queryArray.length() == 0) {
                return Promise._resolve(resultHash)
            }
        }

        //  从网络查询。
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        //  REMARK：get_accounts、get_assets、get_witnesses、get_committee_members 等接口适用。
        return conn.async_exec_db("get_objects", jsonArrayfrom(queryArray)).then { data_array ->
            val json_array = data_array as JSONArray

            //  更新缓存 和 结果
            val pAppCache = AppCacheManager.sharedAppCacheManager()
            for (obj in json_array) {
                if (obj == null) {
                    continue
                }
                val oid = obj.getString("id")
                pAppCache.update_object_cache(oid, obj)
                _cacheObjectID2ObjectHash[oid] = obj        //  add to memory cache: id hash
                if (cache != null && key != null) {
                    cache[obj.getString(key)] = obj         //  add to memory cache: key hash
                }
                resultHash.put(oid, obj)
            }

            //  保存缓存
            pAppCache.saveObjectCacheToFile()

            //  返回结果
            return@then Promise._resolve(resultHash)
        }
    }

    fun queryAllAccountsInfo(account_id_array: JSONArray): Promise {
        return queryAllObjectsInfo(account_id_array, _cacheAccountName2ObjectHash, "name", false, null)
    }

    fun queryAllAssetsInfo(asset_id_array: JSONArray): Promise {
        return queryAllObjectsInfo(asset_id_array, _cacheAssetSymbol2ObjectHash, "symbol", false, null)
    }

    fun queryAllGrapheneObjects(id_array: JSONArray): Promise {
        return queryAllObjectsInfo(id_array, null, null, false, null)
    }

    fun queryAllGrapheneObjectsSkipCache(id_array: JSONArray): Promise {
        return queryAllObjectsInfo(id_array, null, null, true, null)
    }

    fun queryAllGrapheneObjects(id_array: JSONArray, skipCacheIdHash: JSONObject?): Promise {
        return queryAllObjectsInfo(id_array, null, null, false, skipCacheIdHash)
    }

    /**
     *  (public) 查询所有 block_num 的 header 信息，返回 Hash。 格式：{对象ID=>对象信息, ...}
     *
     *  skipQueryCache - 控制是否查询缓存
     *
     *  REMARK：不处理异常，在外层 VC 逻辑中处理。外部需要 catch 该 promise。
     */
    fun queryAllBlockHeaderInfos(block_num_array: JSONArray, skipQueryCache: Boolean): Promise {
        var resultHash = JSONObject()

        //  要查询的数据为空，则返回空的 Hash。
        if (block_num_array == null || block_num_array.length() <= 0) {
            return Promise._resolve(resultHash)
        }
        var queryArray = JSONArray()
        if (skipQueryCache) {
            //  忽略缓存：重新查询所有 block_num
            queryArray.putAll(block_num_array)
        } else {
            //  从缓存加载
            val pAppCache = AppCacheManager.sharedAppCacheManager()
            for (block_num in block_num_array.forin<String>()) {
                val oid = "100.0.${block_num!!}"                                      //  REMARK：block_num 不是对象ID，特殊处理。
                val obj = pAppCache.get_object_cache_ts(oid, -1)            //  -1 不考虑过期日期
                if (obj != null) {
                    _cacheObjectID2ObjectHash[oid] = obj                            //  add to memory cache: id hash
                    resultHash.put(oid, obj)
                } else {
                    queryArray.put(block_num)
                }
            }
            //  从缓存获取完毕，直接返回。
            if (queryArray.length() == 0) {
                return Promise._resolve(resultHash)
            }
        }
        //  从网络查询。用 get_block_header_batch 代替 get_block_header 接口。
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return conn.async_exec_db("get_block_header_batch", jsonArrayfrom(queryArray)).then {
            val data_array = it as JSONArray
            //  更新缓存 和 结果
            val pAppCache = AppCacheManager.sharedAppCacheManager()
            for (block_header_ary in data_array.forin<JSONArray>()) {
                val block_num = block_header_ary!![0]
                val block_header = block_header_ary[1] as? JSONObject
                if (block_header != null) {
                    val oid = String.format("100.0.%s", block_num)    //  REMARK：block_num 不是对象ID，特殊处理。
                    //  缓存
                    pAppCache.update_object_cache(oid, block_header)
                    _cacheObjectID2ObjectHash[oid] = block_header     //  add to memory cache: id hash
                    resultHash.put(oid, block_header)
                }
            }
            //  保存缓存
            pAppCache.saveObjectCacheToFile()
            //  返回结果
            return@then Promise._resolve(resultHash)
        }
    }


    /**
     *  (public) 查询最近成交记录
     */

    fun queryFillOrderHistory(tradingPair: TradingPair, number: Int): Promise {
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        return conn.async_exec_history("get_fill_order_history", jsonArrayfrom(tradingPair._baseId, tradingPair._quoteId, number * 2)).then { data_array ->
            //  REMARK：筛选所有的 taker，吃单作为交易历史，一次交易撮合肯定有2个订单，买方和卖方，但交易历史和走向根据taker主动成交决定。
            var fillOrders = JSONArray()
            val data_array = data_array as JSONArray

            for (i in 0 until data_array.length()) {
                val fillOrder = data_array.getJSONObject(i)
                val op = fillOrder.getJSONObject("op")
                if (op.getBoolean("is_maker")) {
                    continue
                }
                val time = fillOrder.getString("time")
                val pays = op.getJSONObject("pays")
                val order_id = op.getString("order_id")
                //  是否是爆仓单
                val isCallOrder = order_id.split(".")[1].toInt() == EBitsharesObjectType.ebot_call_order.value
                var isSell = true
                //  获取价格对象，注意老的API节点可能不存在该字段。
                val fill_price = op.optJSONObject("fill_price")
                //  price 和 amount 都按照动态计算出的精度格式化。
                var price: Double?
                var amount: Double?
                //  REMARK：支付的资产为 base 资产（CNY），那么即为 BUY 行为。
                if (pays.getString("asset_id").equals(tradingPair._baseId)) {
                    isSell = false
                    //  购买目标资产数量
                    val buy_amount = op.getJSONObject("receives").getLong("amount")
                    //  REMARK：部分历史订单会出现数量为 0 的数据，直接过滤。
                    if (buy_amount == 0L) {
                        //  TODO:fowallet 添加 flurry统计？
                        continue
                    }
                    amount = buy_amount / tradingPair._quotePrecisionPow

                    if (fill_price != null) {
                        val n_price = OrgUtils.calcPriceFromPriceObject(fill_price, tradingPair._quoteId, tradingPair._quotePrecision, tradingPair._basePrecision, set_divide_precision = false)
                        price = n_price!!.toDouble()
                    } else {
                        val cost_amount = pays.getLong("amount")
                        val cost_real: Double = cost_amount / tradingPair._basePrecisionPow

                        price = cost_real / amount
                    }
                } else {

                    //  卖出资产数量
                    val sell_amount = pays.getLong("amount")
                    //  REMARK：部分历史订单会出现数量为 0 的数据，直接过滤。
                    if (sell_amount == 0L) {
                        //  TODO:fowallet 添加 flurry统计？
                        continue
                    }
                    amount = sell_amount / tradingPair._quotePrecisionPow

                    if (fill_price != null) {
                        val n_price = OrgUtils.calcPriceFromPriceObject(fill_price, tradingPair._quoteId, tradingPair._quotePrecision, tradingPair._basePrecision, set_divide_precision = false)
                        price = n_price!!.toDouble()
                    } else {
                        val gain_amount = op.getJSONObject("receives").getLong("amount")
                        val gain_real: Double = gain_amount / tradingPair._basePrecisionPow
                        price = gain_real / amount
                    }
                }
                fillOrders.put(jsonObjectfromKVS("time", time, "issell", isSell, "iscall", isCallOrder, "price", price, "amount", amount))
            }
            return@then fillOrders
        }
    }

    /**
     *  (public) 查询爆仓单
     */
    fun queryCallOrders(tradingPair: TradingPair, number: Int): Promise {
        if (!tradingPair._isCoreMarket) {
            return Promise._resolve(JSONObject())
        }
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        val bitasset_data_id = getChainObjectByID(tradingPair._smartAssetId).getString("bitasset_data_id")
        val p1 = conn.async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom(bitasset_data_id))).then {
            return@then (it as JSONArray).getJSONObject(0)
        }
        val p2 = conn.async_exec_db("get_call_orders", jsonArrayfrom(tradingPair._smartAssetId, number))

        return Promise.all(p1, p2).then { json_array ->
            val data_array = json_array as JSONArray
            val bitasset = data_array.getJSONObject(0)
            val callorders = data_array.getJSONArray(1)

            //  准备参数
            val debt_precision: Int
            val collateral_precision: Int
            val invert: Boolean
            val roundingMode: Int
            if (tradingPair._smartAssetId == tradingPair._baseId) {
                debt_precision = tradingPair._basePrecision
                collateral_precision = tradingPair._quotePrecision
                invert = false
                roundingMode = BigDecimal.ROUND_DOWN
            } else {
                debt_precision = tradingPair._quotePrecision
                collateral_precision = tradingPair._basePrecision
                invert = true   //  force sell `quote` is force buy action
                roundingMode = BigDecimal.ROUND_UP
            }

            //  计算喂价
            val current_feed = bitasset.getJSONObject("current_feed")
            val settlement_price = current_feed.getJSONObject("settlement_price")
            val feed_price = OrgUtils.calcPriceFromPriceObject(settlement_price, tradingPair._sbaAssetId, collateral_precision, debt_precision, false, roundingMode, false)

            //  REMARK：没人喂价 or 所有喂价都过期，则存在 base和quote 都为 0 的情况。即：无喂价。
            var feed_price_market: BigDecimal? = null
            var call_price_market: BigDecimal? = null
            var call_price = BigDecimal.ZERO
            var total_sell_amount = BigDecimal.ZERO
            var n_mcr: BigDecimal? = null
            var n_mssr: BigDecimal? = null
            var settlement_account_number = 0

            if (feed_price != null) {
                feed_price_market = OrgUtils.calcPriceFromPriceObject(settlement_price, tradingPair._quoteId, tradingPair._quotePrecision, tradingPair._basePrecision, false, roundingMode, true)

                n_mssr = bigDecimalfromAmount(current_feed.getString("maximum_short_squeeze_ratio"), 3)
                n_mcr = bigDecimalfromAmount(current_feed.getString("maintenance_collateral_ratio"), 3)

                //  1、计算爆仓成交价   feed / mssr
                call_price = feed_price.divide(n_mssr, kBigDecimalDefaultMaxPrecision, kBigDecimalDefaultRoundingMode)
                call_price_market = call_price
                if (invert) {
                    call_price_market = BigDecimal.ONE.divide(call_price, kBigDecimalDefaultMaxPrecision, kBigDecimalDefaultRoundingMode)
                }

                //  2、计算爆仓单数量
                val zero = BigDecimal.ZERO
                val settlement_handler = BigDecimalHandler(BigDecimal.ROUND_UP, debt_precision)

                for (item in callorders.forin<JSONObject>()) {
                    val callorder = item!!
                    val n_settlement_trigger_price = OrgUtils.calcSettlementTriggerPrice(callorder.getString("debt"),
                            callorder.getString("collateral"), debt_precision, collateral_precision,
                            n_mcr, false, settlement_handler, false)
                    //  强制平仓
                    if (feed_price < n_settlement_trigger_price) {
                        val sell_amount = OrgUtils.calcSettlementSellNumbers(callorder, debt_precision, collateral_precision, feed_price, call_price, n_mcr, n_mssr)
                        //  小数点精度可能有细微误差
                        if (sell_amount < zero) {
                            continue
                        }
                        total_sell_amount = total_sell_amount.add(sell_amount)
                        ++settlement_account_number;
                    }
                }
            }

            if (feed_price_market != null) {
                assert(n_mssr != null && n_mcr != null && call_price_market != null)
                return@then JSONObject().apply {
                    put("feed_price_market", feed_price_market)
                    put("feed_price", feed_price)               //  需要手动翻转价格

                    put("call_price_market", call_price_market)
                    put("call_price", call_price)               //  需要手动翻转价格

                    put("total_sell_amount", total_sell_amount)
                    put("total_buy_amount", total_sell_amount.multiply(call_price))

                    put("invert", invert)
                    put("mcr", n_mcr)
                    put("mssr", n_mssr)
                    put("settlement_account_number", settlement_account_number)
                }
            } else {
                return@then JSONObject()
            }
        }
    }

    /**
     *  (public) 查询限价单
     */
    fun queryLimitOrders(tradingPair: TradingPair, number: Int): Promise {
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        return conn.async_exec_db("get_limit_orders", jsonArrayfrom(tradingPair._baseId, tradingPair._quoteId, number)).then { data_array ->

            val bidArray = JSONArray()
            val askArray = JSONArray()

            val base_id = tradingPair._baseId

            var bid_amount_sum: Double = 0.0
            var ask_amount_sum: Double = 0.0

            val data_array = data_array as JSONArray
            for (i in 0 until data_array.length()) {
                val limitOrder = data_array.getJSONObject(i)
                val sell_price = limitOrder.getJSONObject("sell_price")
                val base = sell_price.getJSONObject("base")
                val quote = sell_price.getJSONObject("quote")

                //  REMARK：卖单的base和市场的base相同，则为买单。比如，BTS-CNY市场，卖出CNY即买入BTS。
                if (base.getString("asset_id").equals(base_id)) {
                    //  bid order: 单价price = 总价格base / 总数量quote
                    val value_base: Double = base.getLong("amount") / tradingPair._basePrecisionPow
                    val value_quote: Double = quote.getLong("amount") / tradingPair._quotePrecisionPow
                    val price: Double = value_base / value_quote

                    //  for_sale是卖出BASE，为总花费。比如 所有花费的CNY。
                    val base_amount: Double = limitOrder.getLong("for_sale") / tradingPair._basePrecisionPow
                    //  总花费 / 单价，即买单的总数量。比如 BTS。
                    val quote_amount: Double = base_amount / price  //  TODO:fowallet价格精度问题。

                    //  累积
                    bid_amount_sum += quote_amount

                    bidArray.put(jsonObjectfromKVS("price", price, "quote", quote_amount, "base", base_amount, "sum", bid_amount_sum))
                } else {

                    //  ask order

                    //  REMARK：卖单的base和市场quote相同，则为实际的卖单，比如，BTS-CNY市场，卖出BTS。
                    val sell_value: Double = base.getLong("amount") / tradingPair._quotePrecisionPow
                    val buy_value: Double = quote.getLong("amount") / tradingPair._basePrecisionPow
                    val price = buy_value / sell_value

                    //  for_sale是卖出QUOTE，即卖出BTS的数量。
                    val quote_amount: Double = limitOrder.getLong("for_sale") / tradingPair._quotePrecisionPow

                    //  总花费 = 单价 * 数量。
                    val base_amount: Double = quote_amount * price

                    //  累积
                    ask_amount_sum += quote_amount
                    askArray.put(jsonObjectfromKVS("price", price, "quote", quote_amount, "base", base_amount, "sum", ask_amount_sum))
                }
            }
            return@then jsonObjectfromKVS("bids", bidArray, "asks", askArray)
        }
    }

    /**
     *  (public) 查询指定帐号的完整信息
     */
    fun queryFullAccountInfo(account_name_or_id: String): Promise {
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()

        return conn.async_exec_db("get_full_accounts", jsonArrayfrom(jsonArrayfrom(account_name_or_id), false)).then { data: Any? ->
            val data = data as JSONArray?
            if (data == null || data.length() <= 0) {
                return@then null
            }
            val _data = data
            //  获取帐号信息
            val full_account_data = data.getJSONArray(0).getJSONObject(1)
            //  [缓存] 添加到缓存
            val account = full_account_data.getJSONObject("account")
            _cacheUserFullAccountData[account.getString("id")] = full_account_data
            _cacheUserFullAccountData[account.getString("name")] = full_account_data
            return@then full_account_data
        }
    }

    /**
     * (public) 账号是否存在于区块链上
     */
    fun isAccountExistOnBlockChain(account_name: String): Promise {
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return conn.async_exec_db("get_account_by_name", jsonArrayfrom(account_name)).then {
            val account_data = it as? JSONObject
            if (account_data == null || account_data.optString("id") == "") {
                return@then false
            }
            return@then true
        }
    }

    /**
     *  (public) 通过公钥查询所有关联的账号信息。
     */
    fun queryAccountDataHashFromKeys(pubkeyList: JSONArray): Promise {
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return conn.async_exec_db("get_key_references", jsonArrayfrom(pubkeyList)).then {
            val key_data_array = it as JSONArray
            val account_id_hash = JSONObject()
            key_data_array.forEach<JSONArray> {
                val account_array = it!!
                account_array.forEach<String> {
                    account_id_hash.put(it!!, true)
                }
            }
            if (account_id_hash.length() <= 0) {
                return@then JSONObject()
            } else {
                return@then queryAllAccountsInfo(account_id_hash.keys().toJSONArray())
            }
        }
    }

    /**
     *  (public) 查询指定用户的限价单（当前委托信息）
     */
    fun queryUserLimitOrders(account_name_or_id: String): Promise {
        return queryFullAccountInfo(account_name_or_id).then {
            val full_account_data = it as JSONObject
            //  查询当前委托订单中所有关联的 asset 信息。
            var asset_id_hash = JSONObject()
            val limit_orders = full_account_data.getJSONArray("limit_orders")
            if (limit_orders != null && limit_orders.length() > 0) {
                for (i in 0 until limit_orders.length()) {
                    val order = limit_orders.getJSONObject(i)
                    val sell_price = order.getJSONObject("sell_price")
                    asset_id_hash.put(sell_price.getJSONObject("base").getString("asset_id"), true)
                    asset_id_hash.put(sell_price.getJSONObject("quote").getString("asset_id"), true)
                }
            }
            return@then queryAllAssetsInfo(asset_id_hash.keys().toJSONArray()).then {
                return@then full_account_data
            }
        }
    }

    /**
     *  (public) 查询最新的预算项目，可能返回 nil值。
     */
    fun queryLastBudgetObject(): Promise {
        //  根据当前时间戳计算和基准参考时间的差值，然后计算预期的预算项目ID。
        val parameters = getDefaultParameters()
        assert(parameters != null)
        val base_budget_id = parameters.getString("base_budget_id")
        val base_budget_time = parameters.getString("base_budget_time")

        //  获取基准ID
        val oid = base_budget_id.split('.').last()
        val ll_oid = oid.toLong()

        val ts_base = Utils.parseBitsharesTimeString(base_budget_time)
        val ts_curr = Utils.now_ts()

        val elapse_hours = Math.max(floor((ts_curr.toFloat() - ts_base.toFloat()) / 3600.0f), 0f)

        //  REMARK：由于整点维护、或者区块链系统宕机等缘故，预算项目并未精确一致，可能存在少许几个的误差。所以这里一次性查询多个预算项目。
        val latest_oid = (ll_oid + elapse_hours).toInt()
        val query_oid_list = JSONArray()
        for (i in 0..10) {
            query_oid_list.put("2.13.${latest_oid - i}")
        }
        return queryAllObjectsInfo(query_oid_list, null, null, false, null).then {
            val asset_hash = it as JSONObject
            var budget_object: JSONObject? = null
            for (check_oid in query_oid_list.forin<String>()) {
                budget_object = asset_hash.optJSONObject(check_oid!!)
                if (budget_object != null) {
                    break
                }
            }
            if (budget_object == null) {
                //  TODO:fowallet 添加统计
                Logger.d("no budget object: $latest_oid")
            }
            return@then budget_object
        }
    }

    /**
     *  (public) 查询帐号投票信息（如果帐号设置了代理帐号，则继续查询代理帐号的投票信息。代理层级过多则返回空。）
     *  account_data    - full_account_data 的 account 部分。
     *  返回值：
     *      {voting_hash,       - 投票ID等Hash
     *       voting_account,    - 实际执行投票的帐号信息
     *       proxy_level,       - 代理层级（没代理则为0。）
     *       have_proxy         - 是否设置了代理人
     *      }
     */
    fun queryAccountVotingInfos(account_name_or_id: String): Promise {
        return queryFullAccountInfo(account_name_or_id).then {
            val full_account_data = it as JSONObject
            return@then _queryAccountVotingInfosCore(full_account_data.getJSONObject("account"), JSONObject(), 0, JSONObject())
        }
    }

    private fun _queryAccountVotingInfosCore(account_data: JSONObject, resultHash: JSONObject, level: Int, checked_hash: JSONObject): Promise {
        val options = account_data.getJSONObject("options")

        //  设置标记，防止两个帐号循环设置代理导致死循环。
        checked_hash.put(account_data.getString("id"), true)
        val voting_account_id = options.getString("voting_account")

        //  未设置代理帐号，则返回。
        val parameters = getDefaultParameters()
        val voting_proxy_to_self = parameters.getString("voting_proxy_to_self")
        val proxy_to_self = voting_account_id == voting_proxy_to_self

        if (proxy_to_self) {
            for (vote_id in options.getJSONArray("votes").forin<String>()) {
                resultHash.put(vote_id!!, true)
            }
            return Promise._resolve(jsonObjectfromKVS("voting_hash", resultHash, "voting_account", account_data,
                    "proxy_level", level, "have_proxy", level != 0))
        }

        //  最大递归层数
        if (level >= parameters.getInt("voting_proxy_max_level")) {
            return Promise._resolve(jsonObjectfromKVS("voting_hash", resultHash, "voting_account", account_data,
                    "proxy_level", level, "have_proxy", level != 0))
        }
        //  代理帐号以前查询过了，循环代理。直接返回。
        if (checked_hash.has(voting_account_id)) {
            return Promise._resolve(jsonObjectfromKVS("voting_hash", resultHash, "voting_account", account_data,
                    "proxy_level", level, "have_proxy", level != 0))
        }

        //  当前帐号设置了代理，继续递归查询。
        //  TODO:fowallet 统计数据
        Logger.d("[Voting Proxy] Query proxy account: ${voting_account_id}, level: ${level + 1}")
        return queryAllObjectsInfo(jsonArrayfrom(voting_account_id), null, null, true, null).then {
            val data_hash = it as JSONObject
            var proxy_account_data = data_hash.getJSONObject(voting_account_id)
            return@then _queryAccountVotingInfosCore(proxy_account_data, resultHash, level + 1, checked_hash)
        }
    }


}