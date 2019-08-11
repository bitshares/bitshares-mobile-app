package com.fowallet.walletcore.bts

import bitshares.*
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min


class BitsharesClientManager {
    //  单例方法
    companion object {
        private var _sharedBitsharesClientManager = BitsharesClientManager()

        fun sharedBitsharesClientManager(): BitsharesClientManager {
            return _sharedBitsharesClientManager
        }
    }

    private fun process_transaction(tr: TransactionBuilder): Promise {
        return tr.set_required_fees(null).then {
            return@then tr.broadcast()
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
            val allfees = it as JSONArray
            return@then allfees[0] as JSONObject
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
     *  转账
     */
    fun transfer(transfer_op_data: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_transfer, transfer_op_data)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(transfer_op_data.getString("from")))
        return process_transaction(tr)
    }

    /**
     *  更新帐号信息（投票等）
     */
    fun accountUpdate(account_update_op_data: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_account_update, account_update_op_data)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(account_update_op_data.getString("account")))
        return process_transaction(tr)
    }

    /**
     *  升级账号
     */
    fun accountUpgrde(account_upgrade_op_data: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_account_upgrade, account_upgrade_op_data)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(account_upgrade_op_data.getString("account_to_upgrade")))
        return process_transaction(tr)
    }

    /**
     *  更新保证金（抵押借贷）
     */
    fun callOrderUpdate(op_data: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_call_order_update, op_data)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(op_data.getString("funding_account")))
        return process_transaction(tr)
    }

    /**
     * 创建限价单
     */
    fun createLimitOrder(limit_order_op: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_limit_order_create, limit_order_op)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(limit_order_op.getString("seller")))
        return process_transaction(tr)
    }

    /**
     *  OP - 创建待解冻金额
     */
    fun vestingBalanceCreate(opdata: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_vesting_balance_create, opdata)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(opdata.getString("creator")))
        return process_transaction(tr)
    }

    /**
     *  OP - 提取待解冻金额
     */
    fun vestingBalanceWithdraw(opdata: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_vesting_balance_withdraw, opdata)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(opdata.getString("owner")))
        return process_transaction(tr)
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
            val tr = TransactionBuilder()
            tr.add_operation(EBitsharesOperations.ebo_proposal_create, op)
            tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(fee_paying_account_id))
            return@then process_transaction(tr)
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
     *  OP - 更新资产发行者
     */
    fun assetUpdateIssuer(opdata: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_asset_update_issuer, opdata)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(opdata.getString("issuer"), requireOwnerPermission = true))
        return process_transaction(tr)
    }

    /**
     *  OP - 创建HTLC合约
     */
    fun htlcCreate(opdata: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_htlc_create, opdata)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(opdata.getString("from")))
        return process_transaction(tr)
    }

    /**
     *  OP - 提取HTLC合约
     */
    fun htlcRedeem(opdata: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_htlc_redeem, opdata)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(opdata.getString("redeemer")))
        return process_transaction(tr)
    }

    /**
     *  OP - 扩展HTLC合约有效期
     */
    fun htlcExtend(opdata: JSONObject): Promise {
        val tr = TransactionBuilder()
        tr.add_operation(EBitsharesOperations.ebo_htlc_extend, opdata)
        tr.addSignKeys(WalletManager.sharedWalletManager().getSignKeysFromFeePayingAccount(opdata.getString("update_issuer")))
        return process_transaction(tr)
    }

}








