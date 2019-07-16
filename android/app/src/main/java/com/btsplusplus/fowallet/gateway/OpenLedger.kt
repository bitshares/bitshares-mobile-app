package com.btsplusplus.fowallet.gateway

import android.content.Context
import bitshares.*
import com.btsplusplus.fowallet.R
import com.btsplusplus.fowallet.ViewMask
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject

class OpenLedger : GatewayBase() {

    override fun queryCoinList(): Promise {
        val api_base = _api_config_json.getString("base")
        val assets = _api_config_json.getString("assets")
        val exchanges = _api_config_json.getString("exchanges")
        val p1 = OrgUtils.asyncJsonGet("$api_base$assets")
        val p2 = OrgUtils.asyncJsonGet("$api_base$exchanges")
        return Promise.all(p1, p2)
    }

    override fun processCoinListData(data_array: JSONArray, balanceHash: JSONObject): JSONArray? {
        val data_assets = data_array.optJSONArray(0)
        val data_exchanges = data_array.optJSONArray(1)
        //  任意一个接口不可用都算失败。
        if (data_assets == null || data_exchanges == null) {
            return null
        }

        val deposit_hash = JSONObject()
        val withdraw_hash = JSONObject()
        data_exchanges.forEach<JSONObject> { it ->
            val item = it!!
            val src = item.optJSONObject("source")
            val dst = item.optJSONObject("destination")
            if (src == null || dst == null) {
                return@forEach
            }
            if (src.getString("blockchain").toLowerCase() == "bitshares") {
                //  withdraw: bitshares to others
                withdraw_hash.put(src.getString("asset"), item)
            } else if (dst.getString("blockchain").toLowerCase() == "bitshares") {
                deposit_hash.put(dst.getString("asset"), item)
            }
        }

        val result = JSONArray()
        data_assets.forEach<JSONObject> { it ->
            val item = it!!

            if (item.getString("blockchain").toLowerCase() != "bitshares") {
                return@forEach
            }

            val asset_symbol = item.optString("code")
            if (asset_symbol == "") {
                return@forEach
            }

            val withdraw_item = withdraw_hash.optJSONObject(asset_symbol)
            val deposit_item = deposit_hash.optJSONObject(asset_symbol)
            if (withdraw_item == null || deposit_item == null) {
                return@forEach
            }

            //  status: 0 - disabled, 1 - functions in manual mode, 2 - functions in automatic mode
            val deposit_options = deposit_item.getJSONObject("options")
            val withdraw_options = withdraw_item.getJSONObject("options")
            val enableWithdraw = withdraw_options.isTrue("healthy") && withdraw_options.getInt("status") != 0
            val enableDeposit = deposit_options.isTrue("healthy") && deposit_options.getInt("status") != 0

            //  细节参考: https://github.com/bitshares/bitshares-ui/pull/2573/commits/8cc40ece6026b24a9becd0bf305b858e6d0d66c5
            val deposit_amount = deposit_item.getJSONObject("amount").getJSONObject("source")
            val withdraw_amount = withdraw_item.getJSONObject("amount").getJSONObject("destination")
            val deposit_limit = deposit_item.getJSONObject("limit").getJSONObject("source")
            val withdraw_limit = withdraw_item.getJSONObject("limit").getJSONObject("source")

            val symbol = asset_symbol.toUpperCase()
            val balance_item = balanceHash.optJSONObject(symbol)
                    ?: jsonObjectfromKVS("iszero", true)

            val backingCoin = withdraw_item.getJSONObject("destination").getString("asset").toUpperCase()

            val appext = GatewayAssetItemData()
            appext.enableWithdraw = enableWithdraw
            appext.enableDeposit = enableDeposit
            appext.symbol = symbol
            appext.backSymbol = backingCoin
            appext.name = item.getString("display_name")
            appext.intermediateAccount = null
            appext.balance = balance_item
            appext.depositMinAmount = auxValueToNumberString(deposit_amount.getString("min"), true)
            appext.withdrawMinAmount = auxValueToNumberString(withdraw_amount.getString("min"), true)
            appext.withdrawGateFee = auxValueToNumberString(withdraw_item.getJSONObject("fee").getJSONObject("source").getString("value"), true)
            appext.supportMemo = withdraw_item.getJSONObject("memo").getJSONObject("destination").isTrue("enabled")
            appext.confirm_block_number = null
            appext.coinType = symbol
            appext.backingCoinType = backingCoin
            appext.withdrawMaxAmountOnce = auxMinValue(withdraw_amount.getString("max"), withdraw_limit.getString("once"), true)
            appext.withdrawMaxAmount24Hours = auxValueToNumberString(withdraw_limit.getString("24h"), true)
            appext.depositMaxAmountOnce = auxMinValue(deposit_amount.getString("max"), deposit_limit.getString("once"), true)
            appext.depositMaxAmount24Hours = auxValueToNumberString(deposit_limit.getString("once"), true)

            appext.open_withdraw_item = withdraw_item
            appext.open_deposit_item = deposit_item

            item.put("kAppExt", appext)
            result.put(item)
        }

        return result
    }

    override fun requestDepositAddress(item: JSONObject, fullAccountData: JSONObject, ctx: Context): Promise {
        val appext = item.get("kAppExt") as GatewayAssetItemData
        val deposit_item = appext.open_deposit_item
        val exchanges_id = deposit_item!!.getString("id")

        val account_data = fullAccountData.getJSONObject("account")
        val outputAddress = account_data.getString("name")

        val request_deposit_address_base = _api_config_json.getString("request_deposit_address")
        val final_url = String.format("%s%s", _api_config_json.getString("base"), String.format(request_deposit_address_base, exchanges_id))

        val args = JSONObject().apply {
            put("destination_address", outputAddress)
            put("destination_memo", "")
        }

        val p = Promise()
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
        mask.show()
        OrgUtils.asyncJsonGet(final_url, args).then {
            mask.dismiss()

            val resp_data = it as? JSONObject
            if (resp_data != null) {
                val addr = resp_data.optString("address")
                if (addr == null) {
                    p.resolve(R.string.kVcDWErrTipsRequestDepositAddrFailed.xmlstring(ctx))
                    return@then null
                }
                val memo = resp_data.opt("memo") as? String
                val depositItem = JSONObject().apply {
                    put("inputAddress", addr)
                    put("inputCoinType", appext.backingCoinType.toLowerCase())
                    if (memo != null) {
                        put("inputMemo", memo)
                    }
                    put("outputAddress", outputAddress)
                    put("outputCoinType", appext.coinType.toLowerCase())
                }
                p.resolve(depositItem)

            } else {
                p.resolve(R.string.kVcDWErrTipsRequestDepositAddrFailed.xmlstring(ctx))
            }
            return@then null
        }.catch {
            mask.dismiss()
            p.resolve(R.string.kVcDWErrTipsRequestDepositAddrFailed.xmlstring(ctx))
        }
        return p
    }

    /**
     *  验证地址、备注、数量是否有效
     */
    override fun checkAddress(item: JSONObject, address: String, memo: String?, amount: String): Promise {
        val appext = item.get("kAppExt") as GatewayAssetItemData
        val exchanges_item = appext.open_withdraw_item
        val exchanges_id = exchanges_item!!.getString("id")

        val validate_method = _api_config_json.getString("validate")
        val final_url = String.format("%s%s", _api_config_json.getString("base"), String.format(validate_method, exchanges_id))

        val args = JSONObject().apply {
            put("amount", amount)
            put("recipient", address)
            put("memo", memo ?: "")
        }

        val p = Promise()

        OrgUtils.asyncPost_jsonBody(final_url, args).then {
            val resp_data = it as JSONObject
            if (resp_data.isTrue("valid_amount") && resp_data.isTrue("valid_recipient") && resp_data.isTrue("valid_memo")) {
                p.resolve(true)
            } else {
                p.resolve(false)
            }
            return@then null
        }.catch {
            p.resolve(false)
        }

        return p
    }

    /**
     *  (public) 查询提币网关中间账号以及转账需要备注的memo信息。
     */
    override fun queryWithdrawIntermediateAccountAndFinalMemo(appext: GatewayAssetItemData, address: String, memo: String?, intermediateAccountData: JSONObject?): Promise {
        val exchanges_item = appext.open_withdraw_item
        val exchanges_id = exchanges_item!!.getString("id")

        val request_deposit_address_base = _api_config_json.getString("request_deposit_address")
        val final_url = String.format("%s%s", _api_config_json.getString("base"), String.format(request_deposit_address_base, exchanges_id))

        val args = JSONObject().apply {
            put("destination_address", address)
            put("destination_memo", memo ?: "")
        }

        val p = Promise()

        OrgUtils.asyncJsonGet(final_url, args).then {
            val resp_data = it as? JSONObject

            if (resp_data != null) {
                val addr = resp_data.optString("address")
                val memo = resp_data.optString("memo")
                if (addr == null || memo == null) {
                    p.resolve(null)
                    return@then null
                }
                //  继续查询账号信息
                ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(address).then {
                    val full_data = it as? JSONObject
                    if (full_data == null) {
                        p.resolve(null)
                        return@then null
                    }
                    val depositItem = JSONObject().apply {
                        put("intermediateAccount", addr)
                        put("finalMemo", memo)
                        put("intermediateAccountData", full_data)
                    }
                    p.resolve(depositItem)
                    return@then null
                }.catch {
                    p.resolve(null)
                }
            } else {
                p.resolve(null)
            }
            return@then null
        }.catch {
            p.resolve(null)
        }

        return p
    }

}