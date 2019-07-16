package com.btsplusplus.fowallet.gateway

import android.content.Context
import bitshares.*
import com.btsplusplus.fowallet.R
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

open class GatewayBase {

    protected lateinit var _api_config_json: JSONObject

    open fun initWithApiConfig(api_config: JSONObject): GatewayBase {
        _api_config_json = api_config
        return this
    }

    /**
     * 获取网关资产列表
     */
    open fun queryCoinList(): Promise {
        val api_base = _api_config_json.getString("base")
        val coin_list = _api_config_json.getString("coin_list")
        val active_wallets = _api_config_json.getString("active_wallets")
        val trading_pairs = _api_config_json.getString("trading_pairs")

        val coinlist_url = "$api_base$coin_list"
        val active_wallets_url = "$api_base$active_wallets"
        val trading_pairs_url = "$api_base$trading_pairs"

        val p1 = OrgUtils.asyncJsonGet(coinlist_url)
        val p2 = OrgUtils.asyncJsonGet(active_wallets_url)
        val p3 = OrgUtils.asyncJsonGet(trading_pairs_url)

        return Promise.all(p1, p2, p3)
    }

    /**
     *  处理资产信息，生成app标准格式。
     */
    open fun processCoinListData(data_array: JSONArray, balanceHash: JSONObject): JSONArray? {
        //  Openledger responsed data
        //{
        //    "allow_deposit" = 0;
        //    "allow_withdrawal" = 0;
        //    authorized = "<null>";
        //    backingCoinType = eosdac;
        //    coinPriora = 0;
        //    coinType = "open.eosdac";
        //    gateFee = "0.000000";
        //    intermediateAccount = "openledger-dex";
        //    "is_return_active" = 0;
        //    maintenanceReason = "Under maintenance";
        //    name = "OL EOSDAC";
        //    notAuthorizedReasons = "<null>";
        //    precision = "100000.00000000000000000000";
        //    restricted = 0;
        //    supportsOutputMemos = 1;
        //    symbol = "OPEN.EOSDAC";
        //    transactionFee = 0;
        //    walletName = "BitShares 2.0";
        //    walletSymbol = "OPEN.EOSDAC";
        //    walletType = bitshares2;
        //    withdrawalLimit24h = "-1";
        //},
        //{
        //    "allow_deposit" = 1;
        //    "allow_withdrawal" = 1;
        //    authorized = "<null>";
        //    backingCoinType = "<null>";
        //    coinPriora = 0;
        //    coinType = bitcny;
        //    gateFee = "40.000000";
        //    intermediateAccount = "openledger-dex";
        //    "is_return_active" = 1;
        //    maintenanceReason = "";
        //    name = BITCNY;
        //    notAuthorizedReasons = "<null>";
        //    precision = "10000.00000000000000000000";
        //    restricted = 0;
        //    supportsOutputMemos = 0;
        //    symbol = BITCNY;
        //    transactionFee = 0;
        //    walletName = "Ethereum BITCNY token";
        //    walletSymbol = BITCNY;
        //    walletType = bitcny;
        //    withdrawalLimit24h = "-1";
        //},

        //  GDEX responsed data
        //{
        //    authorized = "<null>";
        //    backingCoinType = "<null>";
        //    coinPriora = 1;
        //    coinType = btc;
        //    gateFee = "0.001";
        //    intermediateAccount = "gdex-wallet";
        //    maintenanceReason = "";
        //    maxAmount = 999999999;
        //    minAmount = "0.002";
        //    name = bitcoin;
        //    notAuthorizedReasons = "<null>";
        //    precision = 100000000;
        //    restricted = 0;
        //    supportsOutputMemos = 0;
        //    symbol = BTC;
        //    transactionFee = 0;
        //    walletName = BTC;
        //    walletSymbol = BTC;
        //    walletType = btc;
        //},
        //{
        //    authorized = "<null>";
        //    backingCoinType = btc;
        //    coinPriora = 1;
        //    coinType = "gdex.btc";
        //    gateFee = 0;
        //    intermediateAccount = "gdex-wallet";
        //    maintenanceReason = "";
        //    maxAmount = 999999999;
        //    minAmount = "0.00000001";
        //    name = bitcoin;
        //    notAuthorizedReasons = "<null>";
        //    precision = 100000000;
        //    restricted = 0;
        //    supportsOutputMemos = 0;
        //    symbol = "GDEX.BTC";
        //    transactionFee = 0;
        //    walletName = "bitshares2.0";
        //    walletSymbol = "GDEX.BTC";
        //    walletType = "bitshares2.0";
        //}

        assert(data_array.length() == 3)
        val data_coinlist = data_array.get(0) as? JSONArray
        val data_active_wallets = data_array.get(1) as? JSONArray
        val data_trading_pairs = data_array.get(2) as? JSONArray

        //  任意一个接口不可用都算失败。
        if (data_coinlist == null || data_active_wallets == null || data_trading_pairs == null) {
            return null
        }

        //  把3个接口数据整合
        //  - 可用兑换对
        val trading_hash = JSONObject()
        for (item in data_trading_pairs.forin<JSONObject>()) {
            val inputCoinType = item!!.optString("inputCoinType")
            val outputCoinType = item.optString("outputCoinType")
            if (inputCoinType == "" || outputCoinType == "") {
                continue
            }
            trading_hash.put(inputCoinType, outputCoinType)
        }

        //  - 可用钱包
        val wallettype_hash = JSONObject()
        data_active_wallets.forEach<String> { walletType ->
            wallettype_hash.put(walletType!!, true)
        }

        val coin_hash = JSONObject()
        val coin_wallettype_hash = JSONObject()
        for (item in data_coinlist.forin<JSONObject>()) {
            val coinType = item!!.optString("coinType")
            if (coinType == "") {
                continue
            }
            coin_hash.put(coinType, item)
            val walletType = item.optString("walletType")
            if (walletType == "") {
                continue
            }
            coin_wallettype_hash.put(coinType, walletType)
        }

        val result = JSONArray()
        for (it in data_coinlist.forin<JSONObject>()) {
            val item = it!!
            var backingCoinType = item.optString("backingCoinType")
            if (backingCoinType != "") {
                //  背书资产不存在
                val backingCoinItem = coin_hash.optJSONObject(backingCoinType)
                if (backingCoinItem == null) {
                    continue
                }

                val coinType = item.getString("coinType")

                //  是否可兑换
                var enableDeposit = trading_hash.optString(backingCoinType) == coinType
                var enableWithdraw = trading_hash.optString(coinType) == backingCoinType

                //  TODO:1.6 openledger的 active_wallet 不包含 bitshares2.0钱包 暂时不判断

                //  获取资产对应的walletType
                val back_walletType = coin_wallettype_hash.optString(backingCoinType)
                if (back_walletType != "") {
                    //  主资产和备书资产钱包维护，则禁止充提。
                    if (!wallettype_hash.optBoolean(back_walletType)) {
                        enableDeposit = false
                        enableWithdraw = false
                    }
                } else {
                    enableDeposit = false
                    enableWithdraw = false
                }

                //  for openledger fields, only check backing coin.
                if (backingCoinItem.has("allow_deposit") && !backingCoinItem.isTrue("allow_deposit")) {
                    enableDeposit = false
                }
                if (backingCoinItem.has("allow_withdrawal") && !backingCoinItem.isTrue("allow_withdrawal")) {
                    enableWithdraw = false
                }

                //  TODO:wallet for openledger wrong backingCoinType
                val backingCoinWalletSymbol = backingCoinItem.optString("walletSymbol").toLowerCase()
                if (backingCoinWalletSymbol != backingCoinType) {
                    //  TODO:openledger eosdac、eos.eosdac
                    //  CLS_LOG(@"incorrect backingCoinType: %@", backingCoinType);
                    backingCoinType = backingCoinWalletSymbol
                }

                val symbol = item.getString("symbol").toUpperCase()
                val balance_item = balanceHash.optJSONObject(symbol)
                        ?: jsonObjectfromKVS("iszero", true)

                val appext = GatewayAssetItemData()
                appext.enableWithdraw = enableWithdraw
                appext.enableDeposit = enableDeposit
                appext.symbol = symbol
                appext.backSymbol = backingCoinItem.getString("symbol").toUpperCase()
                appext.name = item.getString("name")
                appext.intermediateAccount = item.getString("intermediateAccount")
                appext.balance = balance_item
                appext.depositMinAmount = item.optString("minAmount")
                appext.withdrawMinAmount = backingCoinItem.optString("minAmount")
                appext.withdrawGateFee = backingCoinItem.optString("gateFee")
                appext.supportMemo = item.isTrue("supportsOutputMemos")
                appext.coinType = item.getString("coinType")
                appext.backingCoinType = backingCoinType
                appext.gdex_backingCoinItem = backingCoinItem;

                item.put("kAppExt", appext)
                result.put(item)
            }
        }

        return result
    }

    /**
     *  (protected) 从网关服务器API接口查询充值地址。（REMARK：仅需要查询时才调用。）
     *  成功返回json，失败返回err。
     */
    protected open fun requestDepositAddressCore(item: JSONObject, appext_or_null: GatewayAssetItemData?, request_deposit_address_url: String?, fullAccountData: JSONObject, ctx: Context): Promise {
        val appext = appext_or_null ?: (item.get("kAppExt") as GatewayAssetItemData)

        val p = Promise()

        //  查询充值地址
        val account_data = fullAccountData.getJSONObject("account")

        val backingCoinType = appext.backingCoinType.toLowerCase()
        val coinType = appext.coinType.toLowerCase()

        val outputAddress = account_data.getString("name")

        //  获取默认的地址请求URL
        val final_url = request_deposit_address_url
                ?: "${_api_config_json.getString("base")}${_api_config_json.getString("request_deposit_address")}"
        val post_args = JSONObject().apply {
            put("inputCoinType", backingCoinType)
            put("outputCoinType", coinType)
            put("outputAddress", outputAddress)
        }

        OrgUtils.asyncPost_jsonBody(final_url, post_args).then {
            //{
            //    code = 8010010001;
            //    data = "<null>";
            //    message = "Content type 'application/x-www-form-urlencoded;charset=UTF-8' not supported";
            //}
            //{
            //    code = 8010030001;
            //    data = "<null>";
            //    message = "asset not found";
            //}
            val resp_data = it as? JSONObject
            if (resp_data == null || resp_data.optInt("code") != 0) {
                var message = resp_data?.optString("message") ?: ""
                if (message == "") {
                    message = R.string.kVcDWErrTipsRequestDepositAddrFailed.xmlstring(ctx)
                }
                p.resolve(message)
            } else {
                //{
                //    comment = "";
                //    inputAddress = 1GJ27czcFM57w8J57fnRZhzB6NjwMiQyyX;
                //    inputCoinType = btc;
                //    inputMemo = "<null>";
                //    outputAddress = saya01;
                //    outputCoinType = "gdex.btc";
                //    refundAddress = "";
                //}
                val inputAddress = resp_data.optString("inputAddress")
                if (inputAddress == "") {
                    p.resolve(R.string.kVcDWErrTipsRequestDepositAddrFailed.xmlstring(ctx))
                    return@then null
                }
                if (resp_data.optString("inputCoinType").toLowerCase() != backingCoinType) {
                    p.resolve(String.format(R.string.kVcDWErrTipsRequestDepositAddrFailed2.xmlstring(ctx), "inputCoinType"))
                    return@then null
                }
                if (resp_data.optString("outputCoinType").toLowerCase() != coinType) {
                    p.resolve(String.format(R.string.kVcDWErrTipsRequestDepositAddrFailed2.xmlstring(ctx), "outputCoinType"))
                    return@then null
                }
                //  获取成功。
                p.resolve(resp_data)
            }
            return@then null
        }.catch {
            p.resolve(R.string.tip_network_error.xmlstring(ctx))
        }
        return p
    }

    /**
     *  请求充值地址
     */
    open fun requestDepositAddress(item: JSONObject, fullAccountData: JSONObject, ctx: Context): Promise {
        val appext = item.get("kAppExt") as GatewayAssetItemData
        return requestDepositAddressCore(item, appext, null, fullAccountData, ctx)
    }

    /**
     *  验证地址、备注、数量是否有效
     */
    open fun checkAddress(item: JSONObject, address: String, memo: String?, amount: String): Promise {
        val appext = item.get("kAppExt") as GatewayAssetItemData
        val walletType = appext.gdex_backingCoinItem?.getString("walletType")

        val check_address_base = _api_config_json.getString("check_address")
        val api_base = _api_config_json.getString("base")
        val final_url = "$api_base${String.format(check_address_base, walletType)}"

        val p = Promise()
        OrgUtils.asyncJsonGet(final_url, jsonObjectfromKVS("address", address)).then {
            val json = it as? JSONObject
            if (json != null && json.isTrue("isValid")) {
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
    open fun queryWithdrawIntermediateAccountAndFinalMemo(appext: GatewayAssetItemData, address: String, memo: String?, intermediateAccountData: JSONObject?): Promise {
        //  GDEX & RUDEX 格式
        assert(intermediateAccountData != null)
        //  TODO:fowallet 很多特殊处理
        //  useFullAssetName        - 部分网关提币备注资产名需要 网关.资产
        //  assetWithdrawlAlias     - 部分网关部分币种提币备注和bts上资产名字不同。
        val assetName = appext.backSymbol
        val final_memo = if (memo != null && memo != "") {
            String.format("%s:%s:%s", assetName, address, memo)
        } else {
            String.format("%s:%s", assetName, address)
        }
        return Promise._resolve(JSONObject().apply {
            put("intermediateAccount", appext.intermediateAccount)
            put("finalMemo", final_memo)
            put("intermediateAccountData", intermediateAccountData)
        })
    }

    /**
     *  辅助 - 根据json的value获取对应的数字字符串。
     */
    open fun auxValueToNumberString(json_value: String, zero_as_nil: Boolean): String? {
        val value = BigDecimal(json_value)
        if (zero_as_nil && value.compareTo(BigDecimal.ZERO) == 0) {
            return null
        }
        return value.toPlainString()
    }

    /**
     *  辅助 - 根据json的value获取对应的数字字符串，并返回两者中较小的值。
     */
    open fun auxMinValue(json_value01: String, json_value02: String, zero_as_nil: Boolean): String? {
        val value01 = BigDecimal(json_value01)
        val value02 = BigDecimal(json_value02)
        val minValue = if (value01 <= value02) {
            value01
        } else {
            value02
        }
        if (zero_as_nil && minValue.compareTo(BigDecimal.ZERO) == 0) {
            return null
        }
        return minValue.toPlainString()
    }

}