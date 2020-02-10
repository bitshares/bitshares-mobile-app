package com.btsplusplus.fowallet.utils

import bitshares.*
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
            if (price.getJSONObject("base").getString("amount").toLong() == 0L ||
                    price.getJSONObject("quote").getString("amount").toLong() == 0L) {
                return true
            }
            return false
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
            return avg.multiply(n).setScale(result_precision)
        }

    }
}
