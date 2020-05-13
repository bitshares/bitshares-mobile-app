package com.btsplusplus.fowallet.utils

import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ModelUtils {

    companion object {


        /**
         *  (public) 资产 - 判断资产是否允许强清
         */
        fun assetCanForceSettle(asset_object: JSONObject): Boolean {
            val flags = asset_object.getJSONObject("options").getInt("flags")
            if (flags.and(EBitsharesAssetFlags.ebat_disable_force_settle.value) != 0) {
                return false
            }
            return true
        }

        /**
         *  (public) 资产 - 判断资产是否允许发行人全局清算
         */
        fun assetCanGlobalSettle(asset_object: JSONObject): Boolean {
            val issuer_permissions = asset_object.getJSONObject("options").getInt("issuer_permissions")
            return issuer_permissions.and(EBitsharesAssetFlags.ebat_global_settle.value) != 0
        }

        /**
         *  (public) 资产 - 判断资产是否允许隐私转账
         */
        fun assetAllowConfidential(asset_object: JSONObject): Boolean {
            val flags = asset_object.getJSONObject("options").getInt("flags")
            if (flags.and(EBitsharesAssetFlags.ebat_disable_confidential.value) != 0) {
                return false
            }
            return true
        }

        /**
         *  (public) 资产 - 资产是否允许覆盖转账（强制转账）
         */
        fun assetCanOverride(asset_object: JSONObject): Boolean {
            val flags = asset_object.getJSONObject("options").getInt("flags")
            return flags.and(EBitsharesAssetFlags.ebat_override_authority.value) != 0
        }

        /**
         *  (public) 资产 - 是否所有转账都需要发行人审核
         */
        fun assetIsTransferRestricted(asset_object: JSONObject): Boolean {
            val flags = asset_object.getJSONObject("options").getInt("flags")
            return flags.and(EBitsharesAssetFlags.ebat_transfer_restricted.value) != 0
        }

        /**
         *  (public) 资产 - 资产是否需要持有人属于白名单判断。
         */
        fun assetNeedWhiteList(asset_object: JSONObject): Boolean {
            val flags = asset_object.getJSONObject("options").getInt("flags")
            return flags.and(EBitsharesAssetFlags.ebat_white_list.value) != 0
        }

        /**
         *  (public) 资产 - 是否已经全局清算判断
         */
        fun assetHasGlobalSettle(bitasset_object: JSONObject): Boolean {
            return !isNullPrice(bitasset_object.getJSONObject("settlement_price"))
        }

        /**
         *  (public) 资产 - 是否是智能币判断
         */
        fun assetIsSmart(asset: JSONObject): Boolean {
            val bitasset_data_id = asset.optString("bitasset_data_id", "")
            return bitasset_data_id.isNotEmpty()
        }

        /**
         *  (public) 资产 - 是否是链核心资产判断
         */
        fun assetIsCore(asset: JSONObject): Boolean {
            return asset.getString("id") == ChainObjectManager.sharedChainObjectManager().grapheneCoreAssetID
        }

        /**
         *  (public) 判断是否价格无效
         */
        fun isNullPrice(price: JSONObject): Boolean {
            val core_asset_id = ChainObjectManager.sharedChainObjectManager().grapheneCoreAssetID
            if (core_asset_id == price.getJSONObject("base").getString("asset_id") &&
                    core_asset_id == price.getJSONObject("quote").getString("asset_id")) {
                return true
            }
            return false
        }

        /**
         *  (public) 根据汇率换算手续费。
         */
        fun multiplyAndRoundupNetworkFee(core_asset: JSONObject, asset: JSONObject, n_core_fee: BigDecimal, core_exchange_rate: JSONObject): BigDecimal? {
            val core_asset_id = core_asset.getString("id")
            val core_precision = core_asset.getInt("precision")

            val asset_id = asset.getString("id")
            val precision = asset.getInt("precision")

            val n_zero = BigDecimal.ZERO

            val base = core_exchange_rate.getJSONObject("base")
            val quote = core_exchange_rate.getJSONObject("quote")
            if (core_asset_id == base.getString("asset_id")) {
                if (asset_id != quote.getString("asset_id")) {
                    //  null price
                    return null
                }
                //  quote / base * n_core_fee
                val n_base = bigDecimalfromAmount(base.getString("amount"), core_precision)
                if (n_base <= n_zero) {
                    //  error price
                    return null
                }
                val n_quote = bigDecimalfromAmount(quote.getString("amount"), precision)
                return n_core_fee.multiply(n_quote).divide(n_base, precision, BigDecimal.ROUND_UP)
            } else if (core_asset_id == quote.getString("asset_id")) {
                if (asset_id != base.getString("asset_id")) {
                    //  null price
                    return null
                }
                //  base / quote * n_core_fee
                val n_quote = bigDecimalfromAmount(quote.getString("amount"), core_precision)
                if (n_quote <= n_zero) {
                    //  error price
                    return null
                }
                val n_base = bigDecimalfromAmount(base.getString("amount"), precision)
                return n_core_fee.multiply(n_base).divide(n_quote, precision, BigDecimal.ROUND_UP)
            } else {
                assert(false) { "invalid core_exchange_rate" }
            }
            return null
        }

        /**
         *  (public) 辅助方法 - 从full account data获取指定资产等余额信息，返回 NSDecimalNumber 对象，没有找到对应资产则返回 ZERO 对象。
         */
        fun findAssetBalance(full_account_data: JSONObject, asset_id: String, asset_precision: Int): BigDecimal {
            val balances = full_account_data.optJSONArray("balances")
            if (balances != null && balances.length() > 0) {
                for (balance_object in balances.forin<JSONObject>()) {
                    if (asset_id == balance_object!!.getString("asset_type")) {
                        return bigDecimalfromAmount(balance_object.getString("balance"), asset_precision)
                    }
                }
            }
            return BigDecimal.ZERO
        }

        fun findAssetBalance(full_account_data: JSONObject, asset: JSONObject): BigDecimal {
            return findAssetBalance(full_account_data, asset.getString("id"), asset.getInt("precision"))
        }

        /**
         *  (public) 从石墨烯ID列表获取依赖的ID列表。
         */
        fun collectDependence(source_oid_list: JSONArray, keystring_or_keyarray: Any): JSONArray {
            val ary: JSONArray
            if (keystring_or_keyarray is String) {
                ary = jsonArrayfrom(keystring_or_keyarray)
            } else {
                ary = keystring_or_keyarray as JSONArray
            }
            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            val id_hash = JSONObject()
            for (oid in source_oid_list.forin<String>()) {
                var target_obj: Any?
                val obj = chainMgr.getChainObjectByID(oid!!)
                target_obj = obj
                for (level_key in ary.forin<String>()) {
                    val target_obj_as_hash = target_obj as JSONObject
                    target_obj = target_obj_as_hash.opt(level_key!!)
                    if (target_obj == null) {
                        break
                    }
                }
                if (target_obj != null && target_obj is String) {
                    id_hash.put(target_obj, true)
                }
            }
            return id_hash.keys().toJSONArray()
        }

        /**
         *  (public) 计算平均数
         */
        fun calculateAverage(total: BigDecimal, n: BigDecimal, result_precision: Int): BigDecimal {
            return total.divide(n, result_precision, BigDecimal.ROUND_DOWN)
        }

        /**
         *  (public) 计算总数
         */
        fun calTotal(avg: BigDecimal, n: BigDecimal, result_precision: Int): BigDecimal {
            return avg.multiply(n).setScale(result_precision, BigDecimal.ROUND_DOWN)
        }

        /**
         *  (public) 处理链上返回的限价单信息，方便UI显示。
         *  filterTradingPair - 筛选当前交易对相关订单，可为nil。
         */
        fun processLimitOrders(limit_orders: JSONArray?, filterTradingPair: TradingPair?): MutableList<JSONObject> {
            val dataArray = mutableListOf<JSONObject>()

            if (limit_orders == null) {
                return dataArray
            }

            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            for (order in limit_orders.forin<JSONObject>()) {
                val sell_price = order!!.getJSONObject("sell_price")
                val base = sell_price.getJSONObject("base")
                val quote = sell_price.getJSONObject("quote")
                val base_id = base.getString("asset_id")
                val quote_id = quote.getString("asset_id")

                //  筛选当前交易对相关订单，并根据当前交易对确定买卖方向。
                var issell = false
                if (filterTradingPair != null) {
                    if (base_id == filterTradingPair._baseId && quote_id == filterTradingPair._quoteId) {
                        //  买单：卖出 CNY
                        issell = false
                    } else if (base_id == filterTradingPair._quoteId && quote_id == filterTradingPair._baseId) {
                        //  卖单：卖出 BTS
                        issell = true
                    } else {
                        //  其他交易对的订单
                        continue
                    }
                }
                val base_asset = chainMgr.getChainObjectByID(base_id)
                val quote_asset = chainMgr.getChainObjectByID(quote_id)
                val base_precision = base_asset.getInt("precision")
                val quote_precision = quote_asset.getInt("precision")
                val base_value = OrgUtils.calcAssetRealPrice(base.getString("amount"), base_precision)
                val quote_value = OrgUtils.calcAssetRealPrice(quote.getString("amount"), quote_precision)
                //  REMARK：没筛选的情况下，根据资产优先级自动计算买卖方向。
                if (filterTradingPair == null) {
                    val assetBasePriority = chainMgr.genAssetBasePriorityHash()
                    val base_priority = assetBasePriority.optInt(base_asset.getString("symbol"), 0)
                    val quote_priority = assetBasePriority.optInt(quote_asset.getString("symbol"), 0)
                    issell = base_priority <= quote_priority
                }

                //  REMARK: base 是卖出的资产，除以 base 则为卖价(每1个 base 资产的价格)。反正 base / quote 则为买入价。
                var price: Double
                var price_str: String
                var amount_str: String
                var total_str: String
                var base_sym: String
                var quote_sym: String
                if (!issell) {
                    //  buy     price = base / quote
                    price = base_value / quote_value
                    price_str = OrgUtils.formatFloatValue(price, base_precision)
                    val total_real = OrgUtils.calcAssetRealPrice(order.getString("for_sale"), base_precision)
                    val amount_real = total_real / price
                    amount_str = OrgUtils.formatFloatValue(amount_real, quote_precision)
                    total_str = OrgUtils.formatAssetString(order.getString("for_sale"), base_precision)
                    base_sym = base_asset.getString("symbol")
                    quote_sym = quote_asset.getString("symbol")
                } else {
                    //  sell    price = quote / base
                    price = quote_value / base_value
                    price_str = OrgUtils.formatFloatValue(price, quote_precision)
                    amount_str = OrgUtils.formatAssetString(order.getString("for_sale"), base_precision)
                    val for_sale_real = OrgUtils.calcAssetRealPrice(order.getString("for_sale"), base_precision)
                    val total_real = price * for_sale_real
                    total_str = OrgUtils.formatFloatValue(total_real, quote_precision)
                    base_sym = quote_asset.getString("symbol")
                    quote_sym = base_asset.getString("symbol")
                }
                //  REMARK：特殊处理，如果按照 base or quote 的精度格式化出价格为0了，则扩大精度重新格式化。
                if (price_str == "0") {
                    price_str = OrgUtils.formatFloatValue(price, 8)
                }

                dataArray.add(JSONObject().apply {
                    put("time", order.getString("expiration"))
                    put("issell", issell)
                    put("price", price_str)
                    put("amount", amount_str)
                    put("total", total_str)
                    put("base_symbol", base_sym)
                    put("quote_symbol", quote_sym)
                    put("id", order.getString("id"))
                    put("seller", order.getString("seller"))
                    put("raw_order", order)
                })
            }
            //  按照ID降序
            dataArray.sortByDescending { it.getString("id").split(".").last().toInt() }
            //  返回
            return dataArray
        }
    }
}
