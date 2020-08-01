package com.fowallet.walletcore.bts

import android.app.Activity
import android.content.Context
import bitshares.*
import com.btsplusplus.fowallet.R
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.StealthTransferUtils
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.max
import kotlin.math.min

/**
 *  (public) 隐私收据验证结果枚举。
 */
const val kBlindReceiptVerifyResultOK = 0                       //  验证通过（收据有效）
const val kBlindReceiptVerifyResultUnknownCommitment = 1        //  验证失败（未知收据）
const val kBlindReceiptVerifyResultLoopLimitError = 2           //  伪造承诺生成达到最大上限
const val kBlindReceiptVerifyResultCerError = 3                 //  非core资产汇率无效
const val kBlindReceiptVerifyResultFeePoolBalanceNotEnouth = 4  //  非core资产手续费池不足

class BitsharesClientManager {
    //  单例方法
    companion object {
        private var _sharedBitsharesClientManager = BitsharesClientManager()

        fun sharedBitsharesClientManager(): BitsharesClientManager {
            return _sharedBitsharesClientManager
        }
    }

    private fun process_transaction(tr: TransactionBuilder, broadcast_to_blockchain: Boolean = true): Promise {
        return tr.set_required_fees(null).then {
            return@then tr.broadcast(broadcast_to_blockchain)
        }.then { data ->
            //  TODO:fowallet 到这里就是交易广播成功 并且 回调已经执行了
            return@then data
        }
    }

    /**
     * (public) 从网络计算手续费 / calcuate fees from network
     */
    fun calcOperationFee(op_data: JSONObject, op_code: EBitsharesOperations): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(op_code, op_data)
        return tr.set_required_fees(null).then {
            val first_asset_id_fees = it as? JSONArray
            if (first_asset_id_fees == null || first_asset_id_fees.length() <= 0) {
                return@then op_data.getJSONObject("fee")
            } else {
                //  参考 set_required_fees 的请求部分。
                return@then first_asset_id_fees.getJSONObject(0)
            }
        }
    }

    /**
     * 取消限价单
     */
    fun cancelLimitOrders(opdata_array: JSONArray): Promise {
        val tr = TransactionBuilder()
        opdata_array.forEach<JSONObject> { opdata ->
            tr.add_operation(EBitsharesOperations.ebo_limit_order_cancel, opdata!!)
            tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(opdata.getString("fee_paying_account")))
        }
        return process_transaction(tr)
    }

    /**
     *  OP - 执行单个 operation 的交易。（可指定是否需要 owner 权限。）
     */
    fun runSingleTransaction(opdata: JSONObject, opcode: EBitsharesOperations, fee_paying_account: String, require_owner_permission: Boolean = false): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(opcode, opdata)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(fee_paying_account, requireOwnerPermission = require_owner_permission))
        return process_transaction(tr)
    }

    /**
     *  创建理事会成员 REMARK：需要终身会员权限。    TODO：未完成
     */
    fun createMemberCommittee(): Promise {
        //  TODO:
        return Promise()
    }

    /**
     *  创建见证人成员 REMARK：需要终身会员权限。    TODO：未完成
     */
    fun createWitness(): Promise {
        //  TODO:
        return Promise()
    }

    /**
     *  OP - 转账（简化版）
     */
    fun simpleTransfer(ctx: Context, from_name: String, to_name: String, asset_name: String,
                       amount: String, memo: String?, memo_extra_keys: JSONObject?, sign_pub_keys: JSONArray?,
                       broadcast: Boolean): Promise {
        assert(!WalletManager.sharedWalletManager().isLocked())

        val p = Promise()

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val p1 = chainMgr.queryFullAccountInfo(from_name)
        val p2 = chainMgr.queryAccountData(to_name)
        val p3 = chainMgr.queryAssetData(asset_name)
        Promise.all(p1, p2, p3).then {
            val data_array = it as? JSONArray
            val full_from_account = data_array?.optJSONObject(0)
            val to_account = data_array?.optJSONObject(1)
            val asset = data_array?.optJSONObject(2)
            _transferWithFullFromAccount(ctx, full_from_account, to_account, asset, amount, memo, memo_extra_keys, sign_pub_keys, p, broadcast)
            return@then null
        }.catch {
            p.reject(JSONObject().apply {
                put("err", R.string.tip_network_error.xmlstring(ctx))
            })
        }

        return p
    }

    fun simpleTransfer2(ctx: Context, full_from_account: JSONObject, to_account: JSONObject, asset: JSONObject,
                        amount: String, memo: String?, memo_extra_keys: JSONObject?, sign_pub_keys: JSONArray?,
                        broadcast: Boolean): Promise {
        val p = Promise()
        _transferWithFullFromAccount(ctx, full_from_account, to_account, asset, amount, memo, memo_extra_keys, sign_pub_keys, p, broadcast)
        return p
    }

    private fun _transferWithFullFromAccount(ctx: Context, full_from_account: JSONObject?, to_account: JSONObject?, asset: JSONObject?,
                                             amount: String, memo: String?, memo_extra_keys: JSONObject?, sign_pub_keys: JSONArray?,
                                             p: Promise, broadcast: Boolean) {

        //  检测链上数据有效性
        if (full_from_account == null || to_account == null || asset == null) {
            p.resolve(JSONObject().apply {
                put("err", R.string.kTxBlockDataError.xmlstring(ctx))
            })
            return
        }
        val from_account = full_from_account.getJSONObject("account")
        val from_id = from_account.getString("id")
        val to_id = to_account.getString("id")
        if (from_id == to_id) {
            p.resolve(JSONObject().apply {
                put("err", R.string.kVcTransferSubmitTipFromToIsSame.xmlstring(ctx))
            })
            return
        }

        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val walletMgr = WalletManager.sharedWalletManager()

        val asset_id = asset.getString("id")
        val asset_precision = asset.getInt("precision")

        //  检测转账资产数量是否足够
        val n_amount = Utils.auxGetStringDecimalNumberValue(amount)
        val n_amount_pow = n_amount.multiplyByPowerOf10(asset_precision)

        val bBalanceEnough = ModelUtils.findAssetBalance(full_from_account, asset_id, asset_precision) >= n_amount
        if (!bBalanceEnough) {
            p.resolve(JSONObject().apply {
                put("err", String.format(R.string.kTxBalanceNotEnough.xmlstring(ctx), asset.getString("symbol")))
            })
            return
        }

        //  生成转账备注信息
        var memo_object: JSONObject? = null
        if (memo != null) {
            val from_public_memo = from_account.getJSONObject("options").getString("memo_key")
            val to_public_memo = to_account.getJSONObject("options").getString("memo_key")
            memo_object = walletMgr.genMemoObject(memo, from_public_memo, to_public_memo, memo_extra_keys)
            if (memo_object == null) {
                p.resolve(JSONObject().apply {
                    put("err", R.string.kTxMissMemoPriKey.xmlstring(ctx))
                })
                return
            }
        }

        //  构造转账结构
        val op = JSONObject().apply {
            put("fee", jsonObjectfromKVS("amount", 0, "asset_id", chainMgr.grapheneCoreAssetID))
            put("from", from_id)
            put("to", to_id)
            put("amount", jsonObjectfromKVS("amount", n_amount_pow.toPlainString(), "asset_id", asset_id))
            put("memo", memo_object)    //  maybe null
        }

        //  转账
        _transfer(op, broadcast, sign_pub_keys).then {
            p.resolve(JSONObject().apply {
                put("tx", it)
            })
            return@then null
        }.catch {
            p.reject(it)
        }
    }

    /**
     *  转账
     */
    fun transfer(transfer_op_data: JSONObject): Promise {
        return _transfer(transfer_op_data, broadcast = true, sign_pub_keys = null)
    }

    private fun _transfer(transfer_op_data: JSONObject, broadcast: Boolean = true, sign_pub_keys: JSONArray? = null): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_transfer, transfer_op_data)
        if (sign_pub_keys != null && sign_pub_keys.length() > 0) {
            tr.addSignKeys(sign_pub_keys)
        } else {
            tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(transfer_op_data.getString("from")))
        }
        return process_transaction(tr, broadcast_to_blockchain = broadcast)
    }

    /**
     *  更新帐号信息（投票等）
     */
    fun accountUpdate(opdata: JSONObject): Promise {
        //  REMARK：修改 owner 需要 owner 权限。
        var requireOwnerPermission = false
        if (opdata.has("owner")) {
            requireOwnerPermission = true
        }
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_account_update, opdata.getString("account"), require_owner_permission = requireOwnerPermission)
    }

    /**
     *  升级账号
     */
    fun accountUpgrade(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_account_upgrade, opdata.getString("account_to_upgrade"))
    }

    /**
     *  OP - 转移账号
     */
    fun accountTransfer(opdata: JSONObject): Promise {
        //  TODO:后续处理，链尚不支持。
        assert(false) { "not supported" }
        //  eval: No registered evaluator for operation ${op}"
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_account_transfer, opdata.getString("account_id"))
    }

    /**
     *  更新保证金（抵押借贷）
     */
    fun callOrderUpdate(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_call_order_update, opdata.getString("funding_account"))
    }

    /**
     * 创建限价单
     */
    fun createLimitOrder(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_limit_order_create, opdata.getString("seller"))
    }

    /**
     *  OP - 创建待解冻金额
     */
    fun vestingBalanceCreate(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_vesting_balance_create, opdata.getString("creator"))
    }

    /**
     *  OP - 提取待解冻金额
     */
    fun vestingBalanceWithdraw(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_vesting_balance_withdraw, opdata.getString("owner"))
    }

    /**
     *  OP - 创建提案
     */
    fun proposalCreate(opcode: EBitsharesOperations, opdata: JSONObject, opaccount: JSONObject, proposal_create_args: JSONObject): Promise {
        val kFeePayingAccount = proposal_create_args.getJSONObject("kFeePayingAccount")
        val kApprovePeriod = proposal_create_args.getInt("kApprovePeriod")
        val kReviewPeriod = proposal_create_args.getInt("kReviewPeriod")

        assert(kFeePayingAccount != null)
        assert(kApprovePeriod > 0)

        val fee_paying_account_id = kFeePayingAccount.getString("id")

        return _wrap_opdata_with_fee(opcode, opdata).then {
            val opdata_with_fee = it as JSONObject

            //  提案有效期
            var proposal_lifetime_sec = kApprovePeriod + kReviewPeriod

            //  提案审核期
            var review_period_seconds = kReviewPeriod

            //  获取全局参数
            val gp = ChainObjectManager.sharedChainObjectManager().getObjectGlobalProperties()
            val parameters = gp.optJSONObject("parameters")
            if (parameters != null) {
                //  不能 超过最大值（当前值28天）
                val maximum_proposal_lifetime = parameters.getInt("maximum_proposal_lifetime")
                proposal_lifetime_sec = min(maximum_proposal_lifetime, proposal_lifetime_sec)

                //  不能低于最低值（当前值1小时）
                val committee_proposal_review_period = parameters.getInt("committee_proposal_review_period")
                review_period_seconds = max(committee_proposal_review_period, review_period_seconds)
            }
            assert(proposal_lifetime_sec > 0)
            assert(review_period_seconds < proposal_lifetime_sec)

            //  过期时间戳
            val now_sec = Utils.now_ts()
            val expiration_ts = now_sec + proposal_lifetime_sec

            val op = jsonObjectfromKVS(
                    "fee", jsonObjectfromKVS("amount", 0, "asset_id", BTS_NETWORK_CORE_ASSET_ID),
                    "fee_paying_account", fee_paying_account_id,
                    "expiration_time", expiration_ts,
                    "proposed_ops", jsonArrayfrom(jsonObjectfromKVS("op", jsonArrayfrom(opcode.value, opdata_with_fee)))
            )

            assert(opaccount.getString("id") != BTS_GRAPHENE_COMMITTEE_ACCOUNT || kReviewPeriod > 0)

            //  添加审核期
            if (kReviewPeriod > 0) {
                op.put("review_period_seconds", review_period_seconds)
            }

            //  创建交易
            return@then runSingleTransaction(op, EBitsharesOperations.ebo_proposal_create, fee_paying_account_id)
        }
    }

    /**
     *  (private) 返回包含手续费对象的 opdata。
     */
    private fun _wrap_opdata_with_fee(opcode: EBitsharesOperations, opdata: JSONObject): Promise {
        val p = Promise()
        val opdata_fee = opdata.optJSONObject("fee")
        if (opdata_fee == null || opdata_fee.getString("amount").toLong() == 0L) {
            //  计算手续费
            calcOperationFee(opdata, opcode).then {
                val fee_price_item = it as JSONObject
                opdata.put("fee", fee_price_item)
                p.resolve(opdata)
                return@then null
            }.catch { err ->
                p.reject(err)
            }
        } else {
            //  有手续费直接返回。
            p.resolve(opdata)
        }
        return p
    }

    /**
     *  OP - 更新提案（添加授权or移除授权）
     */
    fun proposalUpdate(opdata: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_proposal_update, opdata)

        //  获取所有需要签名的KEY
        val walletMgr = WalletManager.sharedWalletManager()
        val idAccountDataHash = walletMgr.getAllAccountDataHash(false)

        opdata.getJSONArray("active_approvals_to_add").forEach<String> { uid ->
            val account_data = idAccountDataHash.getJSONObject(uid!!)
            tr.addSignKeys(walletMgr.getSignKeys(account_data.getJSONObject("active")))
        }
        opdata.getJSONArray("active_approvals_to_remove").forEach<String> { uid ->
            val account_data = idAccountDataHash.getJSONObject(uid!!)
            tr.addSignKeys(walletMgr.getSignKeys(account_data.getJSONObject("active")))
        }
        opdata.getJSONArray("owner_approvals_to_add").forEach<String> { uid ->
            val account_data = idAccountDataHash.getJSONObject(uid!!)
            tr.addSignKeys(walletMgr.getSignKeys(account_data.getJSONObject("owner")))
        }
        opdata.getJSONArray("owner_approvals_to_remove").forEach<String> { uid ->
            val account_data = idAccountDataHash.getJSONObject(uid!!)
            tr.addSignKeys(walletMgr.getSignKeys(account_data.getJSONObject("owner")))
        }
        opdata.getJSONArray("key_approvals_to_add").forEach<String> { pubkey ->
            assert(walletMgr.havePrivateKey(pubkey!!))
            tr.addSignKey(pubkey)
        }
        opdata.getJSONArray("key_approvals_to_remove").forEach<String> { pubkey ->
            assert(walletMgr.havePrivateKey(pubkey!!))
            tr.addSignKey(pubkey)
        }

        //  手续费支付账号也需要签名
        tr.addSignKeys(walletMgr.getSignKeysFromFeePayingAccount(opdata.getString("fee_paying_account")))

        return process_transaction(tr)
    }

    /**
     *  OP -创建资产。
     */
    fun assetCreate(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_create, opdata.getString("issuer"))
    }

    /**
     *  OP -全局清算资产。
     */
    fun assetGlobalSettle(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_global_settle, opdata.getString("issuer"))
    }

    /**
     *  OP -清算资产。
     */
    fun assetSettle(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_settle, opdata.getString("account"))
    }

    /**
     *  OP -更新资产基本信息。
     */
    fun assetUpdate(opdata: JSONObject): Promise {
        //  REMARK：HARDFORK_CORE_199_TIME 硬分叉之后 new_issuer 不可更新，需要更新调用单独的接口更新。
        assert(!opdata.has("new_issuer"))
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_update, opdata.getString("issuer"))
    }

    /**
     *  OP -更新智能币相关信息。
     */
    fun assetUpdateBitasset(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_update_bitasset, opdata.getString("issuer"))
    }

    /**
     *  OP -更新智能币的喂价人员信息。
     */
    fun assetUpdateFeedProducers(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_update_feed_producers, opdata.getString("issuer"))
    }

    /**
     *  OP -销毁资产（减少当前供应量）REMARK：不能对智能资产进行操作。
     */
    fun assetReserve(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_reserve, opdata.getString("payer"))
    }

    /**
     *  OP -发行资产给某人
     */
    fun assetIssue(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_issue, opdata.getString("issuer"))
    }

    /**
     *  OP -注资资产的手续费池资金
     */
    fun assetFundFeePool(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_fund_fee_pool, opdata.getString("from_account"))
    }

    /**
     *  OP -提取资产的手续费池资金
     */
    fun assetClaimPool(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_claim_pool, opdata.getString("issuer"))
    }

    /**
     *  OP - 更新资产发行者
     */
    fun assetUpdateIssuer(opdata: JSONObject): Promise {
        //  TODO:7.0 待测试
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_update_issuer, opdata.getString("issuer"), require_owner_permission = true)
    }

    /**
     *  OP -提取资产的市场手续费资金
     */
    fun assetClaimFees(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_asset_claim_fees, opdata.getString("issuer"))
    }

    /**
     *  OP - 断言
     */
    fun assert(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_assert, opdata.getString("fee_paying_account"))
    }

    /**
     *  OP - 转入隐私账号
     */
    fun transferToBlind(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_transfer_to_blind, opdata.getString("from"))
    }

    /**
     *  (private) 从隐私收据转出到公开账号or其他隐私账户。
     */
    private fun _transferFromBlindInput2PublicOrBlind(opdata: JSONObject, signPriKeyHash: JSONObject, opcode: EBitsharesOperations): Promise {

        val tr = TransactionBuilder()
        tr.add_operation(opcode, opdata)

        assert(opdata.has("inputs"))
        for (blind_input in opdata.getJSONArray("inputs").forin<JSONObject>()) {
            for (item in blind_input!!.getJSONObject("owner").getJSONArray("key_auths").forin<JSONArray>()) {
                tr.addSignKey(item!!.getString(0))
            }
        }

        for (priKey in signPriKeyHash.keys()) {
            tr.addSignPrivateKey(priKey)
        }

        return process_transaction(tr)
    }

    /**
     *  OP - 从隐私账号转出
     */
    fun transferFromBlind(opdata: JSONObject, signPriKeyHash: JSONObject): Promise {
        return _transferFromBlindInput2PublicOrBlind(opdata, signPriKeyHash, EBitsharesOperations.ebo_transfer_from_blind)
    }

    /**
     *  OP - 隐私转账
     */
    fun blindTransfer(opdata: JSONObject, signPriKeyHash: JSONObject): Promise {
        return _transferFromBlindInput2PublicOrBlind(opdata, signPriKeyHash, EBitsharesOperations.ebo_blind_transfer)
    }

    private fun _verifyBlindReceiptCore(promise: Promise, ctx: Activity, check_blind_balance: JSONObject) {
        //  本地检测（已经成功导入的则不用继续链上验证。）
        if (AppCacheManager.sharedAppCacheManager().isHaveBlindBalance(check_blind_balance)) {
            promise.resolve(kBlindReceiptVerifyResultOK)
            return
        }

        /**
         *  链上验证原理：
         *  1、直接构造隐私交易进行转账，如果待check的收据异常则链上验证直接通过。
         *  2、构造一条伪造收据作为第二个inputs一起提交。目的如下：
         *      a. 伪造的收据链上不存在，必定转账失败，可终于终止交易。
         *      b. 伪造交易的金额可以随意设置，但保证大于手续费即可。否则手续费不足则会提前触发异常。承诺是否存在必须在 do_evaluate 中才能判断，提前则无法确定。
         *      c. 伪造的交易承诺必须大于待check承诺，保证inputs升序，且位于第二个位置，否则在第一个位置时待check的收据尚未check就已经报错了。
         *  3、解析链端返回的错误信息，确认结果。
         */

        //  输入1：待验证的隐私收据。
        val check_amount = check_blind_balance.getJSONObject("decrypted_memo").getJSONObject("amount")
        val check_commitment = check_blind_balance.getJSONObject("decrypted_memo").getString("commitment")
        val check_asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(check_amount.getString("asset_id"))
        val check_precision = check_asset.getInt("precision")
        val n_check_amount = bigDecimalfromAmount(check_amount.getString("amount"), check_precision)

        //  输入2：伪造的隐私收据 TODO:7.0 伪造金额如何选择？可考虑core资产最大值
        val fake_random_prikey = GraphenePrivateKey().initRandom()
        val fake_random_pubkey = fake_random_prikey.getPublicKey()
        val fake_extra_pub_pri_hash = JSONObject().apply {
            put(fake_random_pubkey.toWifString(), fake_random_prikey)
        }
        val fake_receipt_amount = BigDecimal.valueOf(99999999L)

        //  REMARK：循环生成有效的伪造承诺。必须确保伪造的承诺大于带校验的承诺，那样inputs升序排列之后才可以保证先检测待校验收据。
        var fake_blind_balance: JSONObject
        var fake_commitment: String
        var fake_count = 0

        while (true) {
            val fake_output_args = StealthTransferUtils.genOneBlindOutput(fake_random_pubkey, fake_receipt_amount, check_asset, 1, null)
            fake_blind_balance = fake_output_args.getJSONObject("blind_balance")
            fake_commitment = fake_blind_balance.getJSONObject("decrypted_memo").getString("commitment")
            if (check_commitment < fake_commitment) {
                break
            } else {
                //  配置：最大循环次数
                fake_count += 1
                if (fake_count >= 10000) {
                    promise.resolve(kBlindReceiptVerifyResultLoopLimitError)
                    return
                }
            }
        }

        //  计算手续费金额和输出金额
        //  总的输入金额 = 总的输出金额 + 手续费金额
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        var n_fee = chainMgr.getNetworkCurrentFee(EBitsharesOperations.ebo_blind_transfer, null, null, BigDecimal.ONE)
        if (n_fee != null && check_asset.getString("id") != chainMgr.grapheneCoreAssetID) {
            val core_exchange_rate = check_asset.getJSONObject("options").getJSONObject("core_exchange_rate")
            n_fee = ModelUtils.multiplyAndRoundupNetworkFee(chainMgr.getChainObjectByID(chainMgr.grapheneCoreAssetID), check_asset,
                    n_fee, core_exchange_rate)
        }
        if (n_fee == null) {
            //  汇率数据异常
            promise.resolve(kBlindReceiptVerifyResultCerError)
            return
        }
        val n_fee_pow = n_fee.multiplyByPowerOf10(check_precision)

        //  输出1：临时构造一个输出，输出金额只需要大于0即可。（不会实际提取）
        val n_tmp_output_amount = fake_receipt_amount.add(n_check_amount).subtract(n_fee)
        assert(n_tmp_output_amount > BigDecimal.ZERO)
        val tmp_blind_output = JSONObject().apply {
            put("public_key", GraphenePrivateKey().initRandom().getPublicKey().toWifString())
            put("n_amount", n_tmp_output_amount)
        }

        //  生成 OP 的 inputs 和 outputs 数据。
        val trx_sign_keys = JSONObject()
        val input_blinding_factors = JSONArray()
        val inputs = StealthTransferUtils.genBlindInputs(ctx, jsonArrayfrom(check_blind_balance, fake_blind_balance), input_blinding_factors, trx_sign_keys, fake_extra_pub_pri_hash)!!
        val blind_output_args = StealthTransferUtils.genBlindOutputs(jsonArrayfrom(tmp_blind_output), check_asset, input_blinding_factors)

        //  构造交易OP
        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("asset_id", check_asset.getString("id"))
                put("amount", n_fee_pow.toPlainString())
            })
            put("inputs", inputs)
            put("outputs", blind_output_args.getJSONArray("blind_outputs"))
        }

        //  尝试交易
        blindTransfer(op, trx_sign_keys).then {
            //  REMARK：不会到达，第二个伪造的承诺必定触发异常。
            promise.resolve(false)
            return@then null
        }.catch { err ->
            //  交易处理流程：
            //  push_transaction
            //  _apply_transaction
            //  trx validate
            //      operation_validate  //  for all
            //  verify_authority
            //  apply_operation         //  for all
            //      evaluate(arg 3)
            //      start_evaluate
            //      evaluate(arg 1)
            //      prepare_fee         //  Insufficient Fee Paid
            //      do_evaluate
            //      apply
            //      convert_fee
            //      pay_fee
            //      do_apply

            //  解析错误信息：
            //  1、构造正确的签名
            //  2、构造伪造收据（满足手续费）
            //  3、确保在 do_evaluate 中触发异常。

            //code = 3054001;
            //data =     {
            //    code = 3054001;
            //    message = "Attempting to claim an unknown prior commitment";
            //    name = "blind_transfer_unknown_commitment";
            //    stack =         (
            //                     {
            //        context =                 {
            //            file = "confidential_evaluator.cpp";
            //            hostname = "";
            //            level = error;
            //            line = 138;
            //            method = "do_evaluate";
            //            "thread_name" = "th_a";
            //            timestamp = "2020-05-01T04:53:52";
            //        };
            //        data =                 {
            //            commitment = 03cb719e894ac71ddf347e1c51e0872da34c3179ded7292ce5fe72f1d2c8cf2371;
            //        };
            //        format = "";
            //    }

            var verify_result = kBlindReceiptVerifyResultUnknownCommitment
            var unknown_commitment: String? = null

            try {
                val json = if (err is Promise.WsPromiseException) {
                    JSONObject(err.message.toString())
                } else {
                    JSONObject(err.toString())
                }
                val data = json.optJSONObject("data")
                if (data != null) {
                    val name = data.optString("name", null) ?: data.optString("message", null)
                    if (name != null && name.isNotEmpty()) {
                        val stack = data.optJSONArray("stack")
                        if (stack != null && stack.length() > 0) {
                            //  a. 承诺不存在错误
                            if (name.indexOf("unknown_commitment") >= 0 || name.indexOf("unknown prior commitment") >= 0) {
                                unknown_commitment = stack.optJSONObject(0)?.optJSONObject("data")?.optString("commitment", null)
                                //  链上验证通过（收据存在、金额正确）
                                if (unknown_commitment != null && unknown_commitment == fake_commitment) {
                                    verify_result = kBlindReceiptVerifyResultOK
                                }
                            }
                            //  b. 手续费池余额不足错误（仅针对非core资产）
                            if (unknown_commitment == null) {
                                val first_stack_format = stack.optJSONObject(0).optString("format", null)?.toLowerCase()
                                //  "core_fee_paid <= fee_asset_dyn_data->fee_pool: Fee pool balance of '${b}' is less than the ${r} required to convert ${c}"
                                if (first_stack_format != null && first_stack_format.indexOf("fee pool balance") >= 0) {
                                    //  验证结果：手续费池不足
                                    verify_result = kBlindReceiptVerifyResultFeePoolBalanceNotEnouth
                                }
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                //  ...
            }

            //  返回
            promise.resolve(verify_result)
        }
    }

    /**
     *  OP - 验证隐私收据有效性。返回 kBlindReceiptVerify 枚举结果。REMARK：构造一个特殊的 blind_transfer 请求，获取错误信息。
     */
    fun verifyBlindReceipt(ctx: Activity, check_blind_balance: JSONObject): Promise {
        val p = Promise()
        _verifyBlindReceiptCore(p, ctx, check_blind_balance)
        return p
    }

    /**
     *  OP - 创建HTLC合约
     */
    fun htlcCreate(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_htlc_create, opdata.getString("from"))
    }

    /**
     *  OP - 提取HTLC合约
     */
    fun htlcRedeem(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_htlc_redeem, opdata.getString("redeemer"))
    }

    /**
     *  OP - 扩展HTLC合约有效期
     */
    fun htlcExtend(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_htlc_extend, opdata.getString("update_issuer"))
    }

    /**
     *  OP - 创建锁仓（投票）
     */
    fun ticketCreate(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_ticket_create, opdata.getString("account"))
    }

    /**
     *  OP - 更新锁仓（投票）
     */
    fun ticketUpdate(opdata: JSONObject): Promise {
        return runSingleTransaction(opdata, EBitsharesOperations.ebo_ticket_update, opdata.getString("account"))
    }
}








