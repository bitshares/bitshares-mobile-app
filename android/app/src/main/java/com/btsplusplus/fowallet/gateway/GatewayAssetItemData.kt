package com.btsplusplus.fowallet.gateway

import org.json.JSONObject

class GatewayAssetItemData {

    public var enableDeposit: Boolean = false
    public var enableWithdraw: Boolean = false

    public var symbol: String = ""
    public var backSymbol: String = ""
    public var name: String = ""

    public var intermediateAccount: String? = null
    public lateinit var balance: JSONObject

    public var depositMinAmount: String? = null
    public var withdrawMinAmount: String? = null
    public var withdrawGateFee: String? = null

    public var supportMemo: Boolean = false
    public var confirm_block_number: String? = null

    public var coinType: String = ""
    public var backingCoinType: String = ""

    public var depositMaxAmountOnce: String? = null
    public var depositMaxAmount24Hours: String? = null
    public var withdrawMaxAmountOnce: String? = null
    public var withdrawMaxAmount24Hours: String? = null

    public var gdex_backingCoinItem: JSONObject? = null
    public var open_withdraw_item: JSONObject? = null
    public var open_deposit_item: JSONObject? = null

}


