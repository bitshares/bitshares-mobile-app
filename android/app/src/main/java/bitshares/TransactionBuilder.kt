package bitshares

import bitshares.serializer.T_operation
import bitshares.serializer.T_signed_transaction
import bitshares.serializer.T_transaction
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.math.BigDecimal
import java.nio.ByteBuffer
import java.nio.ByteOrder

class TransactionBuilder {

    private var _ref_block_num: Int = 0         //  uint16_t
    private var _ref_block_prefix: Long = 0     //  uint32_t
    private var _expiration: Long = 0           //  uint32_t
    private var _operations = JSONArray()
    private var _extensions = JSONArray()       //  REMARK:未来扩展用

    private var _signatures = JSONArray()       //  签名

    private var _signPubKeys = JSONObject()     //  该交易需要参与签名的公钥列表。REMARK：大部分都是手续费支付账号的资金公钥。
    private var _pubPriKeysHash = JSONObject()  //  特殊私钥列表，部分交易需要（隐私转账等）。KEY -> public key  VALUE -> WIF private key

    private var _tr_buffer: ByteArray? = null
    private var _signed: Boolean = false

    fun addSignKey(pubkey: String) {
        _signPubKeys.put(pubkey, true)
    }

    fun addSignKeys(pubkeyList: JSONArray) {
        pubkeyList.forEach<String> {
            _signPubKeys.put(it!!, true)
        }
    }

    /**
     *  (public) 添加签名用私钥，部分交易可能需要非钱包中的额外的私钥进行签名。
     */
    fun addSignPrivateKey(wifPrivateKey: String) {
        val pubKey = OrgUtils.genBtsAddressFromWifPrivateKey(wifPrivateKey)
        if (pubKey != null) {
            _pubPriKeysHash.put(pubKey, wifPrivateKey)
        }
    }

    fun add_operation(opcode: EBitsharesOperations, opdata: JSONObject) {
        _operations.put(jsonArrayfrom(opcode.value, opdata))
    }

    fun set_required_fees(asset_id: String?): Promise {
        val feeAssets = mutableListOf<String>()

        //  获取手续费的资产ID
        for (op_pair in _operations.forin<JSONArray>()) {
            val fee = op_pair!!.getJSONObject(1).getJSONObject("fee")
            //  EMARK：手动设置了fee则跳过了 不用查询了。
            if (BigDecimal(fee.getString("amount")) != BigDecimal.ZERO) {
                continue
            }
            val fee_asset_id = fee.getString("asset_id")
            if (!feeAssets.contains(fee_asset_id)) {
                feeAssets.add(fee_asset_id)
            }
        }
        if (feeAssets.size <= 0) {
            //  直接跳过
            return Promise._resolve(null)
        }

        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val allfees_promises = JSONArray()
        for (fee_asset_id in feeAssets) {
            allfees_promises.put(conn.async_exec_db("get_required_fees", jsonArrayfrom(operations_to_object(), fee_asset_id)))
        }

        return Promise.all(allfees_promises).then {
            val json_array = it as JSONArray

            //  获取所有 promise 中第一个 asset id的手续费。（数组格式：包含所有operation的手续费。）
            val first_asset_id_fees = json_array.getJSONArray(0)

            //  REMARK：如果OP为提案类型，这里会把提案的手续费以及提案中对应的所有实际OP的手续费全部返回。（因此需要判断。）
            var first_opfee = first_asset_id_fees.get(0)
            if (first_opfee is JSONArray) {
                //  仅第一个手续费对象是提案本身的的手续。
                first_opfee = first_opfee.getJSONObject(0)
            } else {
                assert(first_opfee is JSONObject)
            }

            _operations.forEach<JSONArray> { ops ->
                ops!!.getJSONObject(1).put("fee", first_opfee)
            }

            return@then first_asset_id_fees
        }
    }

    /**
     * (public) 广播交易到区块链网络
     */
    fun broadcast(broadcast_to_blockchain: Boolean): Promise {
        if (_tr_buffer != null) {
            return broadcast_core(broadcast_to_blockchain)
        } else {
            return finalize().then {
                return@then broadcast_core(broadcast_to_blockchain)
            }
        }
    }

    /**
     * (privage) 交易签名
     */
    private fun sign() {
        if (_signed) {
            return
        }

        assert(_tr_buffer != null)

        //  TODO:动态判断该交易需要哪些签名。比如修改账号权限，需要ownerkey
        val walletMgr = WalletManager.sharedWalletManager()

        val sign_buffer = ByteArrayOutputStream()
        sign_buffer.write(ChainObjectManager.sharedChainObjectManager().grapheneChainID.hexDecode())
        sign_buffer.write(_tr_buffer)

        //  签名
        val sig_array = walletMgr.signTransaction(sign_buffer.toByteArray(), _signPubKeys.keys().toJSONArray(), extra_keys_hash = _pubPriKeysHash)
        if (sig_array == null) {
            //  TODO:fowallet 在提交请求的瞬间 钱包锁定了？？请求中，禁止锁定钱包功能添加。
            assert(!walletMgr.isLocked())
            //  TODO:throw
        }
        _signatures.putAll(sig_array!!)

        //  设置标记
        _signed = true
    }

    /**
     * (private) 广播交易 核心
     */
    private fun broadcast_core(broadcast: Boolean): Promise {
        val p = Promise()

        //  1、签名
        sign()

        assert(_tr_buffer != null)
        assert(_signatures.length() > 0)
        assert(_operations.length() > 0)

        //  2、获取需要广播的json对象（包含签名信息）
        val opdata = jsonObjectfromKVS("ref_block_num", _ref_block_num,
                "ref_block_prefix", _ref_block_prefix,
                "expiration", _expiration,
                "operations", _operations,
                "extensions", _extensions,
                "signatures", _signatures)
        val obj = T_signed_transaction.encode_to_object(opdata)

        if (broadcast) {
            //  3、执行广播请求
            val cc: (Boolean, Any?) -> Boolean = cc@{ success, data ->
                if (success) {
                    //  REMARK:一定要确保在网络异常的情况下也要回调该callback，否则这里会卡死。
                    p.resolve(data)
                } else {
                    p.reject("websocket error.")
                }
                //  回调之后删除 callback
                return@cc true
            }

            val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            conn.async_exec_net("broadcast_transaction_with_callback", jsonArrayfrom(cc, obj)).then { data ->
                //  广播成功，等待网络通知执行 cc 回调。
//            NSLog(@"broadcast_transaction_with_callback response: %@", data);
                return@then data
            }.catch { error ->
                p.reject(error)
            }
        } else {
            //  直接返回待广播的数据
            p.resolve(obj)
        }

        return p
    }

    /**
     * (private) 冻结交易数据，准备广播。
     */
    private fun finalize(): Promise {
        assert(_tr_buffer == null)
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return conn.async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom(BTS_DYNAMIC_GLOBAL_PROPERTIES_ID))).then {
            val data_array = it as JSONArray
            val data = data_array[0] as JSONObject
            //  1、过期时间戳设置
            val head_block_sec = Utils.parseBitsharesTimeString(data.getString("time"))
            val now_sec = Utils.now_ts()
            val base_expiration_sec: Long
            if (now_sec - head_block_sec >= 30) {
                base_expiration_sec = head_block_sec
            } else {
                if (now_sec > head_block_sec)
                    base_expiration_sec = now_sec
                else
                    base_expiration_sec = head_block_sec
            }
            _expiration = base_expiration_sec + BTS_CHAIN_EXPIRE_IN_SECS
            //  2、更新 ref_block_num
            _ref_block_num = data.getInt("head_block_number") and 0xffff
            //  3、更新 ref_block_prefix
            val byte_block_id = data.getString("head_block_id").hexDecode()
            //  TODO:待测试 Int可能为负数
            //  REMARK：这里读取LittleEndian
            _ref_block_prefix = ByteBuffer.wrap(byte_block_id).apply { order(ByteOrder.LITTLE_ENDIAN) }.getLong(4)

            //  4、TODO:如果operations的op有finalize方法，也需要调用进行处理。

            //  5、序列化
            val opdata = jsonObjectfromKVS("ref_block_num", _ref_block_num,
                    "ref_block_prefix", _ref_block_prefix,
                    "expiration", _expiration,
                    "operations", _operations,
                    "extensions", _extensions)
            _tr_buffer = T_transaction.encode_to_bytes(opdata)

            return@then data
        }
    }

    /**
     * (private) 所有 operation 转换为 object 对象。
     */
    private fun operations_to_object(): JSONArray {
        var ary = JSONArray()
        _operations.forEach<JSONArray> {
            ary.put(T_operation.encode_to_object(it!!))
        }
        return ary
    }
}