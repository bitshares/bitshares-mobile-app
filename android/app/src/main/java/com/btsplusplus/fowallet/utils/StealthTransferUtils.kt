package com.btsplusplus.fowallet.utils

import android.app.Activity
import bitshares.*
import bitshares.serializer.T_stealth_confirmation
import bitshares.serializer.T_stealth_confirmation_memo_data
import com.btsplusplus.fowallet.*
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.nio.ByteBuffer
import java.nio.ByteOrder

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

        /**
         *  (public) 根据 to_public_key 和 数量生成一个【隐私输出】。
         */
        fun genOneBlindOutput(to_public_key: GraphenePublicKey, n_amount: BigDecimal, asset: JSONObject, num_of_output: Int, used_blind_factor: ByteArray?): JSONObject {
            val one_time_key = GraphenePrivateKey().initRandom()
            val one_time_pub_key = one_time_key.getPublicKey()
            val one_time_key_secp256k1 = one_time_key.getKeyData()

            val secret = one_time_key.getSharedSecret(to_public_key)!!
            val child = sha256(secret)
            val nonce = sha256(one_time_key_secp256k1)
            //  使用指定的盲因子 or 根据 child 自动生成。
            val blind_factor = used_blind_factor ?: sha256(child)

            //  生成 blind_output 子属性：承诺
            val native_ptr = NativeInterface.sharedNativeInterface()

            val n_amount_pow = n_amount.multiplyByPowerOf10(asset.getInt("precision"))
            val i_amount = n_amount_pow.toLong()

            val commitment = native_ptr.bts_gen_pedersen_commit(blind_factor, i_amount)!!

            //  生成 blind_output 子属性：范围证明（仅多个输出时才需要，单个输出不需要。）
            var range_proof = ByteArray(0)
            if (num_of_output > 1) {
                range_proof = native_ptr.bts_gen_range_proof_sign(0, commitment, blind_factor, nonce, 0, 0, i_amount)!!
            }

            //  生成 blind_output 子属性：owner
            val out_owner = JSONObject().apply {
                put("weight_threshold", 1)
                put("account_auths", JSONArray())
                put("key_auths", JSONArray().apply {
                    put(jsonArrayfrom(to_public_key.child(child).toWifString(), 1))
                })
                put("address_auths", JSONArray())
            }

            val decrypted_memo = JSONObject().apply {
                //  put("from", "")
                put("amount", JSONObject().apply {
                    put("asset_id", asset.getString("id"))
                    put("amount", n_amount_pow.toPlainString())
                })
                put("blinding_factor", blind_factor)
                put("commitment", commitment)
                //  secret的前4个字节作为checksum
                put("check", ByteBuffer.wrap(secret).apply { order(ByteOrder.LITTLE_ENDIAN) }.int)
            }

            val blind_output = JSONObject().apply {
                put("commitment", commitment)
                put("range_proof", range_proof)
                put("owner", out_owner)
                put("stealth_memo", JSONObject().apply {
                    put("one_time_key", one_time_pub_key.toWifString())
                    //  REMARK：这里不直接存储 to_public_key，为了隐藏 to_public_key，与承诺一起生成新的公钥存储，仅为验证用。
                    //  如果省略 to 字段，则不方便验证该 output 的所属。
                    put("to", to_public_key.genToToTo(commitment).toWifString())
                    put("encrypted_memo", T_stealth_confirmation_memo_data.encode_to_bytes(decrypted_memo).aes256cbc_encrypt(secret))
                })
            }

            //  REMARK：仅作为收据保存。
            val blind_balance = JSONObject().apply {
                put("real_to_key", to_public_key.toWifString())
                put("one_time_key", blind_output.getJSONObject("stealth_memo").getString("one_time_key"))
                put("to", blind_output.getJSONObject("stealth_memo").getString("to"))
                put("decrypted_memo", JSONObject().apply {
                    put("amount", decrypted_memo.getJSONObject("amount"))
                    put("blinding_factor", blind_factor.hexEncode())
                    put("commitment", commitment.hexEncode())
                    put("check", decrypted_memo.getLong("check"))
                })
            }

            return JSONObject().apply {
                put("blind_output", blind_output)
                put("blind_factor", blind_factor)
                put("blind_balance", blind_balance)
            }
        }

        /**
         *  (public) 生成隐私输出参数。
         */
        fun genBlindOutputs(data_array_output: JSONArray, asset: JSONObject, input_blinding_factors: JSONArray?): JSONObject {
            val receipt_array = JSONArray()
            val num_of_output = data_array_output.length()

            for (item in data_array_output.forin<JSONObject>()) {
                //  REMARK：包含 blind_input 的情况下，新的 blind_output 的最后一个需要计算求和。
                //  1-output: BF1 + BF2 + BF3 = SUM(BF1 + BF2 + BF3)
                //  2-output: BF1 + BF2 + BF3 = BF4 + SUM(BF1 + BF2 + BF3) - BF4
                //  3-output: BF1 + BF2 + BF3 = BF5 + BF6 + SUM(BF1 + BF2 + BF3) - BF5 - BF6
                var final_blind_factor: ByteArray? = null
                if (input_blinding_factors != null && input_blinding_factors.length() > 0 && receipt_array.length() + 1 == num_of_output) {
                    //  最后一个blind_output的盲化因子需要求和
                    val blinds_in = arrayListOf<ByteArray>()
                    for (input_blind_factor in input_blinding_factors.forin<ByteArray>()) {
                        blinds_in.add(input_blind_factor!!)
                    }
                    for (v in receipt_array.forin<JSONObject>()) {
                        blinds_in.add(v!!.get("blind_factor") as ByteArray)
                    }
                    final_blind_factor = NativeInterface.sharedNativeInterface().bts_gen_pedersen_blind_sum(blinds_in.toArray(), input_blinding_factors.length().toLong())
                }

                receipt_array.put(genOneBlindOutput(GraphenePublicKey.fromWifPublicKey(item!!.getString("public_key"))!!,
                        item.get("n_amount") as BigDecimal,
                        asset,
                        num_of_output,
                        final_blind_factor))
            }

            val blind_outputs = mutableListOf<JSONObject>()
            for (item in receipt_array.forin<JSONObject>()) {
                blind_outputs.add(item!!.getJSONObject("blind_output"))
            }
            //  按照 commitment 升序排列。
            blind_outputs.sortBy { (it.get("commitment") as ByteArray).hexEncode() }

            return JSONObject().apply {
                put("receipt_array", receipt_array)
                put("blind_outputs", blind_outputs.toJsonArray())
            }
        }

        /**
         *  (public) 生成隐私输入参数。成功返回数组，失败返回 nil。
         *  extra_pub_pri_hash - 附近私钥Hash KEY：WIF_PUB_KEY   VALUE：GraphenePrivateKey*
         */
        fun genBlindInputs(ctx: Activity, data_array_input: JSONArray, output_blinding_factors: JSONArray?, output_sign_keys: JSONObject, extra_pub_pri_hash: JSONObject?): JSONArray? {
            val inputs = mutableListOf<JSONObject>()
            for (blind_balance in data_array_input.forin<JSONObject>()) {
                val to_pub = blind_balance!!.getString("real_to_key")
                var to_pri = WalletManager.sharedWalletManager().getGraphenePrivateKeyByPublicKey(to_pub)
                if (to_pri == null && extra_pub_pri_hash != null) {
                    to_pri = extra_pub_pri_hash.opt(to_pub) as? GraphenePrivateKey
                }
                if (to_pri == null) {
                    ctx.showToast(ctx.resources.getString(R.string.kVcStTipErrMissingReceiptPriKey))
                    return null
                }
                val one_time_key = GraphenePublicKey.fromWifPublicKey(blind_balance.getString("one_time_key"))!!
                val secret = to_pri.getSharedSecret(one_time_key)
                if (secret == null) {
                    ctx.showToast(ctx.resources.getString(R.string.kVcStTipErrInvalidBlindBalance))
                    return null
                }
                val child = sha256(secret)
                val child_prikey = to_pri.child(child)
                val child_to_pub = child_prikey.getPublicKey().toWifString()
                val decrypted_memo = blind_balance.getJSONObject("decrypted_memo")

                inputs.add(JSONObject().apply {
                    put("commitment", decrypted_memo.getString("commitment").hexDecode())
                    put("owner", JSONObject().apply {
                        put("weight_threshold", 1)
                        put("account_auths", JSONArray())
                        put("key_auths", JSONArray().apply { put(jsonArrayfrom(child_to_pub, 1)) })
                        put("address_auths", JSONArray())
                    })
                })

                output_blinding_factors?.put(decrypted_memo.getString("blinding_factor").hexDecode())
                output_sign_keys.put(child_prikey.toWifString(), child_to_pub)
            }

            //  按照 commitment 升序排列
            inputs.sortBy { (it.get("commitment") as ByteArray).hexEncode() }
            return inputs.toJsonArray()
        }

        /**
         *  (public) 对盲化因子数组求和，所有的都作为【正】因子对待。
         */
        fun blindSum(blinding_factors_array: JSONArray): ByteArray {
            assert(blinding_factors_array.length() > 0)

            val blinds_in = arrayListOf<ByteArray>()
            for (input_blind_factor in blinding_factors_array.forin<ByteArray>()) {
                blinds_in.add(input_blind_factor!!)
            }

            return NativeInterface.sharedNativeInterface().bts_gen_pedersen_blind_sum(blinds_in.toArray(), blinding_factors_array.length().toLong())!!
        }

        /**
         *  (public) 选择收据（隐私交易的的 input 部分）
         */
        fun processSelectReceipts(ctx: Activity, curr_blind_balance_arary: JSONArray?, callback: (new_blind_balance_array: JSONArray) -> Unit) {
            val default_selected = JSONObject()
            if (curr_blind_balance_arary != null && curr_blind_balance_arary.length() > 0) {
                for (blind_balance in curr_blind_balance_arary.forin<JSONObject>()) {
                    val commitment = blind_balance!!.getJSONObject("decrypted_memo").getString("commitment")
                    default_selected.put(commitment, true)
                }
            }
            val result_promise = Promise()
            ctx.goTo(ActivitySelectBlindBalance::class.java, true, args = JSONObject().apply {
                put("result_promise", result_promise)
                put("default_selected", default_selected)
            })
            result_promise.then {
                callback(it as JSONArray)
                return@then null
            }
        }

    }
}
