package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import bitshares.*
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_new_account_password_confirm.*
import org.json.JSONArray
import org.json.JSONObject

const val kModifyAllPermissions = 0         //  修改【账号权限】和【资金权限】
const val kModifyOnlyActivePermission = 1   //  仅修改【资金权限】
const val kModifyOnlyOwnerPermission = 2    //  仅修改【账号权限】

class ActivityNewAccountPasswordConfirm : BtsppActivity() {

    private var _curr_modify_range = kModifyAllPermissions

    private var _curr_password = ""
    private var _curr_pass_lang = EBitsharesAccountPasswordLang.ebap_lang_zh
    private var _new_account_name: String? = null   //  新账号名，注册时传递，修改密码则为nil。
    private var _scene = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_new_account_password_confirm)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _curr_password = args.getString("current_password")
        _curr_pass_lang = args.get("pass_lang") as EBitsharesAccountPasswordLang
        _new_account_name = args.optString("args", null)
        _scene = args.getInt("scene")

        //  初始化UI
        when (_scene) {
            kNewPasswordSceneRegAccount -> {
                //  注册账号
                btn_terms_of_service.visibility = View.VISIBLE
                layout_modify_range.visibility = View.GONE
                //  UI - 新账号名
                tv_your_account_name_title.text = resources.getString(R.string.kEditPasswordCellTItleYourNewAccountName)
                tv_curr_account_name_value.setText(_new_account_name!!)
                tv_curr_account_name_value.isEnabled = false
                //  UI - 提交按钮名字
                btn_submit.text = resources.getString(R.string.kLoginCellBtnAgreeAndReg)
                //  事件 - 用户协议
                btn_terms_of_service.setOnClickListener { onTermsOfServiceClicked() }
            }
            kNewPasswordSceneChangePassowrd -> {
                //  修改密码
                btn_terms_of_service.visibility = View.INVISIBLE
                layout_modify_range.visibility = View.VISIBLE
                //  UI - 账号名
                tv_your_account_name_title.text = resources.getString(R.string.kEditPasswordCellTitleCurrAccountName)
                tv_curr_account_name_value.setText(WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").getString("name"))
                tv_curr_account_name_value.isEnabled = false
                //  UI - 提交按钮名字
                btn_submit.text = resources.getString(R.string.kEditPasswordBtnSubmmit)
                //  UI - 修改范围
                _draw_ui_modify_range()
                //  事件 - 选择修改范围
                layout_modify_range_cell.setOnClickListener { onModifyRangeClicked() }
                //  UI - 箭头颜色
                img_arrow_modify_range.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
            }
            kNewPasswordSceneGenBlindAccountBrainKey -> {
                //  创建隐私账号
                btn_terms_of_service.visibility = View.INVISIBLE
                layout_modify_range.visibility = View.GONE
                //  UI - 别名
                tv_your_account_name_title.text = resources.getString(R.string.kVcStCellTitleAliasName)
                tv_curr_account_name_value.hint = resources.getString(R.string.kVcStPlaceholderInputAliasName)
                tv_curr_account_name_value.isEnabled = true
                //  UI - 提交按钮名字
                btn_submit.text = resources.getString(R.string.kEditPasswordBtnCreateBlindAccount)
            }
            else -> assert(false)
        }

        //  事件 - 提交事件
        btn_submit.setOnClickListener { onBtnSubmit() }

        //  事件 - 返回
        layout_back_from_new_account_password_confirm.setOnClickListener { finish() }
    }

    /**
     *  (private) 事件 - 查看用户协议
     */
    private fun onTermsOfServiceClicked() {
        val url = "https://btspp.io/${resources.getString(R.string.userAgreementHtmlFileName)}"
        goToWebView(resources.getString(R.string.kVcTitleAgreement), url)
    }

    /**
     *  (private) 描绘UI - 修改范围
     */
    private fun _draw_ui_modify_range() {
        when (_curr_modify_range) {
            kModifyAllPermissions -> tv_modify_range_value.text = resources.getString(R.string.kEditPasswordCellValueEditRangeOwnerAndActive)
            kModifyOnlyActivePermission -> tv_modify_range_value.text = resources.getString(R.string.kEditPasswordCellValueEditRangeOnlyActive)
            kModifyOnlyOwnerPermission -> tv_modify_range_value.text = resources.getString(R.string.kEditPasswordCellValueEditRangeOnlyOwner)
            else -> tv_modify_range_value.text = ""
        }
    }

    /**
     *  (private) 通过水龙头注册账号
     */
    private fun onRegisterAccountCore() {
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

        //  1、生成各种权限公钥。
        //  REMARK：这里memo单独分类出来，避免和active权限相同。
        val seed_owner = "${_new_account_name}owner$_curr_password"
        val seed_active = "${_new_account_name}active$_curr_password"
        val seed_memo = "${_new_account_name}memo$_curr_password"
        val owner_key = OrgUtils.genBtsAddressFromPrivateKeySeed(seed_owner)!!
        val active_key = OrgUtils.genBtsAddressFromPrivateKeySeed(seed_active)!!
        val memo_key = OrgUtils.genBtsAddressFromPrivateKeySeed(seed_memo)!!

        //  2、调用水龙头API注册
        OrgUtils.asyncCreateAccountFromFaucet(this, _new_account_name!!, owner_key, active_key, memo_key, "", BuildConfig.kAppChannelID).then {
            mask.dismiss()
            val err_msg = it as? String
            if (err_msg != null) {
                //  水龙头注册失败。
                btsppLogCustom("faucetFailed", jsonObjectfromKVS("err", err_msg))
                showToast(err_msg)
            } else {
                //  注册成功，直接重新登录。
                btsppLogCustom("registerEvent", jsonObjectfromKVS("mode", AppCacheManager.EWalletMode.kwmPasswordOnlyMode.value, "desc", "password"))
                UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), resources.getString(R.string.kLoginTipsRegFullOK), btn_cancel = null).then {
                    //  转到重新登录界面。
                    goTo(ActivityLogin::class.java, true, clear_navigation_stack = true)
                    return@then null
                }
            }
            return@then null
        }
    }

    /**
     *  (private) 查询最新账号数据（如果需要更新memokey则从链上查询）
     */
    private fun queryNewestAccountData(): Promise {
        val account_data = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")

        if (_curr_modify_range == kModifyAllPermissions || _curr_modify_range == kModifyOnlyActivePermission) {
            //  修改所有权限 or 修改资金权限的情况下，需要修改备注权限一起。则需要查询最新的账号数据。
            val p = Promise()

            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
            ChainObjectManager.sharedChainObjectManager().queryAccountData(account_data.getString("id")).then {
                mask.dismiss()
                val newestAccountData = it as? JSONObject
                if (newestAccountData != null && newestAccountData.has("id") && newestAccountData.has("name")) {
                    //  返回最新数据
                    p.resolve(newestAccountData)
                } else {
                    //  查询账号失败，返回nil。
                    p.reject(false)
                }
            }

            //  返回 Promise
            return p
        } else {
            //  仅修改账号权限，则不用修改备注。不用获取最新账号数据。
            return Promise._resolve(account_data)
        }
    }

    /**
     *  (private) 请求二次确认修改账号权限信息。
     */
    private fun _gotoAskUpdateAccount(new_account_data: JSONObject) {
        val value = resources.getString(R.string.kEditPasswordSubmitSecondTipsAsk)
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), value).then {
            if (it != null && it as Boolean) {
                //  解锁钱包or账号
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        _submitUpdateAccountCore(new_account_data)
                    }
                }
            }
        }
    }

    /**
     *  (private) 修改权限核心
     */
    private fun _submitUpdateAccountCore(new_account_data: JSONObject) {
        val uid = new_account_data.getString("id")
        val account_name = new_account_data.getString("name")

        var using_owner_authority = false
        val new_private_wif_list = JSONArray()

        //  构造OPDATA
        val op_data = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", ChainObjectManager.sharedChainObjectManager().grapheneCoreAssetID)
            })
            put("account", uid)

            //  修改资金权限 和 备注权限
            if (_curr_modify_range == kModifyAllPermissions || _curr_modify_range == kModifyOnlyActivePermission) {
                //  生成 active 公私钥。
                val seed_active = "${account_name}active$_curr_password"
                val public_key_active = OrgUtils.genBtsAddressFromPrivateKeySeed(seed_active)!!

                //  生成 memo 公私钥。
                val seed_memo = "${account_name}memo$_curr_password"
                val public_key_memo = OrgUtils.genBtsAddressFromPrivateKeySeed(seed_memo)!!

                //  修改资金权限
                put("active", JSONObject().apply {
                    put("weight_threshold", 1)
                    put("account_auths", JSONArray())
                    put("key_auths", JSONArray().apply {
                        put(jsonArrayfrom(public_key_active, 1))
                    })
                    put("address_auths", JSONArray())
                })

                //  修改备注权限
                val account_options = new_account_data.getJSONObject("options")
                put("new_options", JSONObject().apply {
                    put("memo_key", public_key_memo)
                    put("voting_account", account_options.getString("voting_account"))
                    put("num_witness", account_options.getInt("num_witness"))
                    put("num_committee", account_options.getInt("num_committee"))
                    put("votes", account_options.getJSONArray("votes"))
                })

                //  保存资金权限和备注私钥
                new_private_wif_list.put(OrgUtils.genBtsWifPrivateKey(seed_active.utf8String()))
                new_private_wif_list.put(OrgUtils.genBtsWifPrivateKey(seed_memo.utf8String()))
            }

            //  修改账户权限
            if (_curr_modify_range == kModifyAllPermissions || _curr_modify_range == kModifyOnlyOwnerPermission) {
                //  签名需要权限标记
                using_owner_authority = true

                //  生成 owner 公私钥。
                val seed_owner = "${account_name}owner$_curr_password"
                val public_key_owner = OrgUtils.genBtsAddressFromPrivateKeySeed(seed_owner)!!

                //  修改账户权限
                put("owner", JSONObject().apply {
                    put("weight_threshold", 1)
                    put("account_auths", JSONArray())
                    put("key_auths", JSONArray().apply {
                        put(jsonArrayfrom(public_key_owner, 1))
                    })
                    put("address_auths", JSONArray())
                })

                //  保存账户权限私钥
                new_private_wif_list.put(OrgUtils.genBtsWifPrivateKey(seed_owner.utf8String()))
            }
        }

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_account_update, using_owner_authority, false, op_data, new_account_data) { isProposal, _ ->
            assert(!isProposal)
            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().accountUpdate(op_data).then {
                if (WalletManager.sharedWalletManager().isPasswordMode()) {
                    //  密码模式：修改权限之后直接退出重新登录。
                    mask.dismiss()
                    //  [统计]
                    btsppLogCustom("txUpdateAccountPermissionFullOK", jsonObjectfromKVS("account", uid, "mode", "password"))
                    UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), resources.getString(R.string.kVcPermissionEditSubmitOkRelogin), btn_cancel = null).then {
                        //  注销
                        WalletManager.sharedWalletManager().processLogout()
                        //  转到重新登录界面。
                        goTo(ActivityLogin::class.java, true, clear_navigation_stack = true)
                        return@then null
                    }
                } else {
                    //  导入新密码对应私钥到当前钱包中
                    val walletMgr = WalletManager.sharedWalletManager()
                    val full_wallet_bin = walletMgr.walletBinImportAccount(null, new_private_wif_list)!!
                    AppCacheManager.sharedAppCacheManager().apply {
                        updateWalletBin(full_wallet_bin)
                        autoBackupWalletToWebdir(false)
                    }
                    //  重新解锁（即刷新解锁后的账号信息）。
                    val unlockInfos = walletMgr.reUnlock(this)
                    assert(unlockInfos.getBoolean("unlockSuccess"))

                    //  钱包模式：修改权限之后刷新账号信息即可。（可能当前账号不在拥有完整的active权限。）
                    ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(uid).then {
                        mask.dismiss()
                        val full_data = it as JSONObject
                        //  更新账号信息
                        AppCacheManager.sharedAppCacheManager().updateWalletAccountInfo(full_data)
                        //  [统计]
                        btsppLogCustom("txUpdateAccountPermissionFullOK", jsonObjectfromKVS("account", uid, "mode", "wallet"))
                        //  提示并退出
                        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), resources.getString(R.string.kVcPermissionEditSubmitOK02), btn_cancel = null).then {
                            //  直接返回最外层
                            BtsppApp.getInstance().finishActivityToNavigationTop()
                            return@then null
                        }
                        return@then null
                    }.catch {
                        mask.dismiss()
                        showToast(resources.getString(R.string.kVcPermissionEditSubmitOKAndRelaunchApp))
                        //  [统计]
                        btsppLogCustom("txUpdateAccountPermissionOK", jsonObjectfromKVS("account", uid, "mode", "wallet"))
                    }
                }
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txUpdateAccountPermissionFailed", jsonObjectfromKVS("account", uid))
            }
        }
    }

    /**
     *  (private) 事件 - 提交按钮点击
     */
    private fun onBtnSubmit() {
        //  校验参数
        val confirm_password = tf_confirm_password.text.toString()
        if (confirm_password != _curr_password) {
            showToast(resources.getString(R.string.kEditPasswordSubmitTipsConfirmFailed))
            return
        }

        when (_scene) {
            kNewPasswordSceneRegAccount -> {
                //  注册：新账号
                onRegisterAccountCore()
            }
            kNewPasswordSceneChangePassowrd -> {
                //  修改密码：先查询账号数据
                queryNewestAccountData().then {
                    //  二次确认
                    _gotoAskUpdateAccount(it as JSONObject)
                    return@then null
                }.catch {
                    showToast(resources.getString(R.string.tip_network_error))
                }
            }
            kNewPasswordSceneGenBlindAccountBrainKey -> {
                val str_alias_name = tv_curr_account_name_value.text.toString().trim()
                VcUtils.processImportBlindAccount(this, str_alias_name, _curr_password) { blind_account ->
                    //  转到账号管理界面
                    val self = this
                    goTo(ActivityBlindAccounts::class.java, true, clear_navigation_stack = true, args = JSONObject().apply {
                        put("title", self.resources.getString(R.string.kVcTitleBlindAccountsMgr))
                    })
                }
            }
            else -> assert(false)
        }
    }

    /**
     *  (private) 事件 - 修改范围CELL点击
     */
    private fun onModifyRangeClicked() {
        val self = this
        val items = JSONArray().apply {
            put(JSONObject().apply {
                put("title", self.resources.getString(R.string.kEditPasswordEditRangeListOwnerAndActive))
                put("type", kModifyAllPermissions)
            })
            put(JSONObject().apply {
                put("title", self.resources.getString(R.string.kEditPasswordEditRangeListOnlyActive))
                put("type", kModifyOnlyActivePermission)
            })
            put(JSONObject().apply {
                put("title", self.resources.getString(R.string.kEditPasswordEditRangeListOnlyOwner))
                put("type", kModifyOnlyOwnerPermission)
            })
        }
        var defaultIndex = 0
        for (item in items.forin<JSONObject>()) {
            if (item!!.getInt("type") == _curr_modify_range) {
                break
            }
            ++defaultIndex
        }

        //  显示列表
        ViewDialogNumberPicker(this, "", items, "title", defaultIndex) { _index: Int, text: String ->
            val result = items.getJSONObject(_index)
            val range = result.getInt("type")
            //  刷新UI
            if (range != _curr_modify_range) {
                _curr_modify_range = range
                _draw_ui_modify_range()
            }
        }.show()
    }
}
