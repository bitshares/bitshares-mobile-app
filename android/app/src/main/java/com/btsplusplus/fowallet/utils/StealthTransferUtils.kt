package com.btsplusplus.fowallet.utils

import android.app.Activity
import bitshares.*
import bitshares.serializer.T_stealth_confirmation
import com.btsplusplus.fowallet.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject

/**
 *  APP隐私收据区块编号key字段名定义。
 */
const val kAppBlindReceiptBlockNum = "abrbn"

/**
 *  隐私账户助记词校验码前缀。
 */
const val kAppBlindAccountBrainKeyCheckSumPrefix = "StealthTransfer"

class StealthTransferUtils {

    companion object {

        /**
         *  (public) 尝试解析隐私收据字符串为 json 格式。不是有效的收据则返回nil，成功返回 json 对象。
         *  支持两种收据字符串：
         *  1、APP收据字符串。
         *  2、cli命令行钱包收据字符串。
         */
        fun guessBlindReceiptString(base58string: String?): JSONObject? {
            if (base58string == null || base58string.isEmpty()) {
                return null
            }
            val raw_data = base58string.base58_decode()
            if (raw_data == null || raw_data.isEmpty()) {
                return null
            }

            //  1、尝试解析APP收据     收据格式 = base58(json(@{kAppBlindReceiptBlockNum:@"xxx"}))
            val app_receipt_json = raw_data.to_json_object()
            if (app_receipt_json != null && app_receipt_json.has(kAppBlindReceiptBlockNum)) {
                return app_receipt_json
            }

            //  2、尝试解析cli命令行收据格式    收据格式 = base58(序列化(stealth_confirmation))
            return try {
                T_stealth_confirmation.parse(raw_data) as? JSONObject
            } catch (E: Exception) {
                null
            }
        }
    }
}
