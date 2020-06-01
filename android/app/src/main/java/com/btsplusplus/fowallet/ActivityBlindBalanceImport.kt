package com.btsplusplus.fowallet

import android.Manifest
import android.os.Bundle
import bitshares.*
import bitshares.serializer.T_stealth_confirmation_memo_data
import com.btsplusplus.fowallet.utils.StealthTransferUtils
import com.btsplusplus.fowallet.utils.VcUtils
import com.btsplusplus.fowallet.utils.kAppBlindReceiptBlockNum
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import com.fowallet.walletcore.bts.kBlindReceiptVerifyResultOK
import kotlinx.android.synthetic.main.activity_blind_balance_import.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.nio.ByteBuffer
import java.nio.ByteOrder

class ActivityBlindBalanceImport : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_balance_import)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val receipt = args.optString("receipt", null)
        val result_promise = args.opt("result_promise") as? Promise

        //  初始化UI - 输入框
        val tf = tf_blind_receipt_text_raw
        if (receipt != null) {
            tf.setText(receipt)
        }

        //  事件 - 扫描
        btn_scan_qrcode.setOnClickListener { onScanQrCodeButtonClicked() }

        //  提交事件
        btn_import_submit.setOnClickListener { onSubmit(result_promise, tf.text.toString().trim()) }

        //  返回事件
        layout_back_from_blind_balance_import.setOnClickListener { finish() }
    }

    /**
     *  (private) 扫一扫按钮点击
     */
    private fun onScanQrCodeButtonClicked() {
        this.guardPermissions(Manifest.permission.CAMERA).then {
            when (it as Int) {
                EBtsppPermissionResult.GRANTED.value -> {
                    val result_promise = Promise()
                    goTo(ActivityQrScan::class.java, true, args = JSONObject().apply {
                        put("result_promise", result_promise)
                    })
                    result_promise.then {
                        (it as? String)?.let { result ->
                            tf_blind_receipt_text_raw.setText(result)
                        }
                    }
                }
                EBtsppPermissionResult.SHOW_RATIONALE.value -> {
                    showToast(resources.getString(R.string.kVcScanPermissionUserRejected))
                }
                EBtsppPermissionResult.DONT_ASK_AGAIN.value -> {
                    showToast(resources.getString(R.string.kVcScanPermissionGotoSetting))
                }
            }
            return@then null
        }
    }

    /**
     *  (private) 是否是已知收据判断。即收据的 to 字段是否是隐私账户中的地址或者隐私账户的变形格式地址。
     */
    private fun guessRealToPublicKey(stealth_memo: JSONObject, d_commitment: ByteArray, blind_accounts: JSONArray): String? {
        assert(blind_accounts.length() > 0)
        //  没有 to 属性作为未知收据处理。
        val to = stealth_memo.optString("to")
        if (to.isEmpty()) {
            return null
        }
        //  是否是隐私账户中的地址判断
        for (blind_account_public_key in blind_accounts.forin<String>()) {
            if (blind_account_public_key!! == to) {
                return blind_account_public_key
            }
        }
        //  是否是隐私账户地址的变形地址判断
        for (blind_account_public_key in blind_accounts.forin<String>()) {
            val public_key = GraphenePublicKey.fromWifPublicKey(blind_account_public_key)
            if (public_key == null) {
                continue
            }
            if (to == public_key.genToToTo(d_commitment).toWifString()) {
                return blind_account_public_key
            }
        }
        //  未知收据
        return null
    }

    /**
     *  (private) 检测单个 operation。
     */
    private fun scanOneOperation(op: JSONArray, data_array: JSONArray, blind_accounts: JSONArray, enable_scan_proposal: Boolean) {
        assert(op.length() == 2)
        val optype = op.getInt(0)
        val opdata = op.getJSONObject(1)

        //  创建提案：则考虑遍历提案的所有operation。
        if (optype == EBitsharesOperations.ebo_proposal_create.value) {
            if (enable_scan_proposal) {
                val proposed_ops = opdata.optJSONArray("proposed_ops")
                if (proposed_ops != null && proposed_ops.length() > 0) {
                    for (proposed_op in proposed_ops.forin<JSONObject>()) {
                        //  REMARK：如果提案里包含创建提案，不重复处理。
                        scanOneOperation(proposed_op!!.getJSONArray("op"), data_array, blind_accounts, enable_scan_proposal = false)
                    }
                }
            }
        } else if (optype == EBitsharesOperations.ebo_transfer_to_blind.value || optype == EBitsharesOperations.ebo_blind_transfer.value) {
            //  转入隐私账户 以及 隐私账户之间转账都存在新的收据生成。
            val outputs = opdata.getJSONArray("outputs")
            assert(outputs.length() > 0)
            if (outputs.length() <= 0) {
                return
            }
            for (blind_output in outputs.forin<JSONObject>()) {
                val stealth_memo = blind_output!!.optJSONObject("stealth_memo")
                //  该字段可选，跳过不存在该字段的收据。REMARK：官方命令行客户端等该字段不存在，目前已知BTS++支持该字段。
                if (stealth_memo == null) {
                    continue
                }
                val d_commitment = blind_output.getString("commitment").hexDecode()
                val real_to_key = guessRealToPublicKey(stealth_memo, d_commitment, blind_accounts)
                if (real_to_key != null && real_to_key.isNotEmpty()) {
                    data_array.put(JSONObject().apply {
                        put("real_to_key", real_to_key)
                        put("stealth_memo", stealth_memo)
                    })
                }
            }
        }
        return
    }

    /**
     *  (private) 扫描区块中的原始【隐私收据】信息。即可：outputs
     */
    private fun scanBlindReceiptFromBlockData(block_data: JSONObject?, blind_accounts: JSONArray): JSONArray {
        val data_array = JSONArray()
        if (block_data == null) {
            return data_array
        }

        if (blind_accounts.length() <= 0) {
            return data_array
        }

        val transactions = block_data.optJSONArray("transactions")
        if (transactions == null || transactions.length() <= 0) {
            return data_array
        }

        for (trx in transactions.forin<JSONObject>()) {
            val operations = trx!!.optJSONArray("operations")
            if (operations == null || operations.length() <= 0) {
                continue
            }

            for (op in operations.forin<JSONArray>()) {
                scanOneOperation(op!!, data_array, blind_accounts, enable_scan_proposal = true)
            }
        }

        return data_array
    }

    private fun isValidBlockNum(str: String): Boolean {
        if (!Utils.isFullDigital(str)) {
            return false
        }
        val n_block_num = BigDecimal(str)
        val n_min = BigDecimal.ZERO
        //  REMARK：最大区块号暂定10亿。
        val n_max = BigDecimal("1000000000")
        if (n_block_num <= n_min) {
            return false
        }
        if (n_block_num >= n_max) {
            return false
        }
        return true
    }

    private fun onSubmit(result_promise: Promise?, receipt: String) {
        guardWalletExistWithWalletMode(resources.getString(R.string.kVcStealthTransferGuardWalletModeTips)) {
            var json = StealthTransferUtils.guessBlindReceiptString(receipt)
            if (json == null && isValidBlockNum(receipt)) {
                //  尝试从区块编号恢复
                json = JSONObject().apply {
                    put(kAppBlindReceiptBlockNum, receipt)
                }
            }
            if (json == null) {
                showToast(resources.getString(R.string.kVcStImportTipInputValidReceiptText))
                return@guardWalletExistWithWalletMode
            }

            //  解锁钱包
            guardWalletUnlocked(false) { unlocked ->
                if (unlocked) {
                    onImportReceiptCore(json, result_promise)
                }
            }
        }
    }

    private fun onImportReceiptCore(receipt_json: JSONObject, result_promise: Promise?) {
        if (receipt_json.has(kAppBlindReceiptBlockNum)) {
            val blind_accounts = AppCacheManager.sharedAppCacheManager().getAllBlindAccounts().keys().toJSONArray()
            if (blind_accounts.length() <= 0) {
                showToast(resources.getString(R.string.kVcStImportTipPleaseImportYourBlindAccountFirst))
                return
            }
            val app_blind_receipt_block_num = receipt_json.getLong(kAppBlindReceiptBlockNum)
            VcUtils.simpleRequest(this, ChainObjectManager.sharedChainObjectManager().queryBlock(app_blind_receipt_block_num)) {
                val block_data = it as? JSONObject
                val data_array = scanBlindReceiptFromBlockData(block_data, blind_accounts)
                importStealthBalanceCore(data_array, result_promise)
            }
        } else {
            val to = receipt_json.getString("to")
            val to_pub = GraphenePublicKey.fromWifPublicKey(to)
            if (to_pub == null) {
                showToast(resources.getString(R.string.kVcStImportTipInvalidReceiptNoToPublic))
                return
            }
            importStealthBalanceCore(jsonArrayfrom(JSONObject().apply {
                put("real_to_key", to)
                put("stealth_memo", receipt_json)
            }), result_promise)
        }
    }

    private fun importStealthBalanceCore(data_array: JSONArray, result_promise: Promise?) {
        if (data_array.length() <= 0) {
            showToast(resources.getString(R.string.kVcStImportTipReceiptIsEmpty))
            return
        }

        val miss_key_array = JSONArray()
        val decrypt_failed_array = JSONArray()
        val blind_balance_array = JSONArray()
        val asset_ids = JSONObject()

        for (item in data_array.forin<JSONObject>()) {
            val stealth_memo = item!!.getJSONObject("stealth_memo")
            val real_to_key = item.getString("real_to_key")
            //  错误1：缺少私钥
            val to_pri = WalletManager.sharedWalletManager().getGraphenePrivateKeyByPublicKey(real_to_key)
            if (to_pri == null) {
                miss_key_array.put(item)
                continue
            }

            //  错误2：无效收据（解密失败or校验失败）
            val decrypted_memo = decryptStealthConfirmationMemo(stealth_memo, to_pri)
            if (decrypted_memo == null) {
                decrypt_failed_array.put(item)
                continue
            }

            //  构造明文的隐私收据格式
            val blind_balance = JSONObject().apply {
                put("real_to_key", real_to_key)
                put("one_time_key", stealth_memo.getString("one_time_key"))
                put("to", stealth_memo.getString("to"))
                put("decrypted_memo", JSONObject().apply {
                    put("amount", decrypted_memo.get("amount"))
                    put("blinding_factor", (decrypted_memo.get("blinding_factor") as ByteArray).hexEncode())
                    put("commitment", (decrypted_memo.get("commitment") as ByteArray).hexEncode())
                    put("check", decrypted_memo.get("check"))
                })
            }
            blind_balance_array.put(blind_balance)
            asset_ids.put(decrypted_memo.getJSONObject("amount").getString("asset_id"), true)
        }

        //  链上验证所有是否有效
        val total_blind_balance_count = blind_balance_array.length()
        if (total_blind_balance_count > 0) {
            VcUtils.simpleRequest(this, ChainObjectManager.sharedChainObjectManager().queryAllGrapheneObjects(asset_ids.keys().toJSONArray())) {
                //  循环验证所有收据
                val verify_success = JSONArray()
                val verify_failed = JSONArray()
                verifyAllBlindReceiptOnchain(blind_balance_array, verify_success, verify_failed).then {
                    val success_count = verify_success.length()
                    if (success_count == total_blind_balance_count) {
                        //  全部校验成功
                        showToast(String.format(resources.getString(R.string.kVcStImportTipSuccessN), success_count.toString()))
                        onImportSuccessful(verify_success, result_promise)
                        return@then null
                    }
                    if (success_count > 0) {
                        //  部分校验成功，部分校验失败。
                        showToast(String.format(resources.getString(R.string.kVcStImportTipSuccessNandVerifyFailedN), success_count.toString(), verify_failed.length().toString()))
                        onImportSuccessful(verify_success, result_promise)
                    } else {
                        //  全部验证失败
                        showToast(resources.getString(R.string.kVcStImportTipInvalidReceiptOnchainVerifyFailed))
                    }
                    return@then null
                }
            }
        } else {
            if (miss_key_array.length() > 0) {
                showToast(resources.getString(R.string.kVcStImportTipInvalidReceiptMissPriKey))
            } else {
                //  num of decrypt_failed_array > 0
                showToast(resources.getString(R.string.kVcStImportTipInvalidReceiptSelfCheckingFailed))
            }
        }
    }


    /**
     *  (private) 解密 stealth_confirmation 结构中的 encrypted_memo 数据。
     */
    private fun decryptStealthConfirmationMemo(stealth_memo: JSONObject, private_key: GraphenePrivateKey): JSONObject? {
        val one_time_key = GraphenePublicKey.fromWifPublicKey(stealth_memo.getString("one_time_key"))!!
        val secret = private_key.getSharedSecret(one_time_key)
        if (secret == null) {
            return null
        }

        //  解密
        val encrypted_memo = stealth_memo.get("encrypted_memo")
        val d_encrypted_memo = if (encrypted_memo is String) {
            encrypted_memo.hexDecode()
        } else {
            encrypted_memo as ByteArray
        }
        val decrypted_memo = d_encrypted_memo.aes256cbc_decrypt(secret)
        if (decrypted_memo == null) {
            return null
        }

        //  这里可能存在异常数据，需要捕获。
        val obj_decrypted_memo = try {
            T_stealth_confirmation_memo_data.parse(decrypted_memo) as? JSONObject
        } catch (e: Exception) {
            //  Invalid receipt data.
            null
        }
        if (obj_decrypted_memo == null) {
            return null
        }

        //  校验checksuum REMARK：这里读取LittleEndian
        if (ByteBuffer.wrap(secret).apply { order(ByteOrder.LITTLE_ENDIAN) }.int != obj_decrypted_memo.getInt("check")) {
            return null
        }

        return obj_decrypted_memo
    }

    private fun verifyAllBlindReceiptOnchain(blind_balance_array: JSONArray, verify_success: JSONArray, verify_failed: JSONArray): Promise {
        if (blind_balance_array.length() <= 0) {
            return Promise._resolve(true)
        } else {
            val blind_balance = blind_balance_array.getJSONObject(0)
            blind_balance_array.remove(0)
            return BitsharesClientManager.sharedBitsharesClientManager().verifyBlindReceipt(this, blind_balance).then {
                val result = it as Int
                //  TODO:7.0 其他错误考虑提示？
                when (result) {
                    kBlindReceiptVerifyResultOK -> verify_success.put(blind_balance)
                    else -> verify_failed.put(blind_balance)
                }
                return@then verifyAllBlindReceiptOnchain(blind_balance_array, verify_success, verify_failed)
            }
        }
    }

    /**
     *  (private) 导入成功
     */
    private fun onImportSuccessful(blind_balance_array: JSONArray, result_promise: Promise?) {
        //  持久化存储
        if (blind_balance_array.length() > 0) {
            val pAppCache = AppCacheManager.sharedAppCacheManager()
            for (blind_balance in blind_balance_array.forin<JSONObject>()) {
                pAppCache.appendBlindBalance(blind_balance!!)
            }
            pAppCache.saveWalletInfoToFile()
        }
        //  返回
        result_promise?.resolve(true)
        finish()
    }
}
