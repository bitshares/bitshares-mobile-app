package com.btsplusplus.fowallet

import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_wallet_manager.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityWalletManager : BtsppActivity() {

    private var _data_array = mutableListOf<JSONObject>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_wallet_manager)

        setFullScreen()

        //  查询
        queryAllAccountInfos()

        //  返回按钮
        layout_back_from_page_of_wallet_and_muti_sign.setOnClickListener { finish() }

        // 导入更多钱包点击
        button_import_more_account_of_wallet_and_muti_sign.setOnClickListener { onImportMoreAccountClicked() }

        // 备份钱包点击
        button_backup_wallet_of_wallet_and_muti_sign.setOnClickListener { backupWallet() }
    }

    /**
     * 事件 - 备份按钮
     */
    private fun backupWallet() {
        goTo(ActivityWalletBackup::class.java, true)
    }

    /**
     * 事件 - 点击导入账号
     */
    private fun onImportMoreAccountClicked() {
        val wallet_import_account_max_num = ChainObjectManager.sharedChainObjectManager().getDefaultParameters().getInt("wallet_import_account_max_num")
        if (_data_array.size >= wallet_import_account_max_num) {
            showToast(String.format(R.string.kWalletTipsMaxImportAccount.xmlstring(this), wallet_import_account_max_num.toString()))
            return
        }
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                //  刷新
                refreshUI()
                var list = arrayOf(R.string.kWalletBtnImportMultiSignedAccount.xmlstring(this), R.string.kWalletBtnImportNormalAccount.xmlstring(this))
                ViewSelector.show(this, R.string.kWalletMenuTipsPleaseSelectImportType.xmlstring(this), list) { index: Int, result: String ->
                    when (index) {
                        0 -> onImportMultiSignAccountClicked()
                        1 -> onImportNormalAccountClicked()
                        else -> assert(false)
                    }
                }
            }
        }
    }

    /**
     *  事件 - 点击导入多签账号
     */
    private fun onImportMultiSignAccountClicked() {
        TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
            last_activity.goTo(ActivityWalletManager::class.java, true, back = true)
            onImportMultiSignAccountSelectOK(it)
        }
        goTo(ActivityAccountQueryBase::class.java, true)
    }

    private fun onImportMultiSignAccountSelectOK(account_item: JSONObject) {
        val accountName = account_item.getString("name")
        val walletMgr = WalletManager.sharedWalletManager()
        if (walletMgr.getAllAccountDataHash(true).has(accountName)) {
            showToast(R.string.kWalletTipsDuplicated.xmlstring(this))
            return
        }
        //  查询要导入的账号信息。
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(accountName).then {
            mask.dismiss()
            val full_data = it as JSONObject
            val account = full_data.getJSONObject("account")
            if (WalletManager.isMultiSignAccount(account)) {
                //  导入账号到钱包BIN文件中
                val full_wallet_bin = walletMgr.walletBinImportAccount(accountName, null)!!
                AppCacheManager.sharedAppCacheManager().apply {
                    updateWalletBin(full_wallet_bin)
                    autoBackupWalletToWebdir(true)
                }
                //  重新解锁（即刷新解锁后的账号信息）。
                val unlockInfos = walletMgr.reUnlock(this)
                assert(unlockInfos.getBoolean("unlockSuccess"))
                //  提示信息
                showToast(R.string.kWalletImportSuccess.xmlstring(this))
                //  重新查询&刷新界面
                queryAllAccountInfos()
            } else {
                showToast(String.format(R.string.kWalletTipsNotMultiSignAccount.xmlstring(this), accountName))
            }
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     *  事件 - 点击导入普通账号
     */
    private fun onImportNormalAccountClicked() {
        val result_promise = Promise()
        goTo(ActivityLogin::class.java, true, args = jsonObjectfromKVS("checkActivePermission", false, "result_promise", result_promise))
        result_promise.then {
            if (it != null && it as Boolean) {
                //  导入成功（刷新）
                queryAllAccountInfos()
            }
        }
    }

    /**
     * 事件 - 账号CELL点击
     */
    private fun onAccountListClicked(data: JSONObject) {
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                //  刷新
                refreshUI()
                var list = arrayOf(resources.getString(R.string.kWalletBtnSetCurrent), resources.getString(R.string.kWalletBtnRemoveAccount))
                ViewSelector.show(this, R.string.kWalletMemuTipsPleaseSelectCellAction.xmlstring(this), list) { index: Int, result: String ->
                    when (index) {
                        0 -> onSetCurrentAccountClicked(data)
                        1 -> onRemoveAccountClicked(data)
                        else -> assert(false)
                    }
                }
            }
        }
    }

    /**
     * 事件 - 设置当前账号
     */
    private fun onSetCurrentAccountClicked(data: JSONObject) {
        if (data.getBoolean("current")) {
            showToast(R.string.kWalletTipsSwitchCurrentAccountDone.xmlstring(this))
            return
        }
        val accountName = data.getString("name")
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()
        ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(accountName).then {
            mask.dismiss()
            val full_data = it as JSONObject
            //  设置当前账号
            val full_wallet_bin = WalletManager.sharedWalletManager().walletBinImportAccount(accountName, null)!!
            AppCacheManager.sharedAppCacheManager().apply {
                updateWalletBin(full_wallet_bin)
                autoBackupWalletToWebdir(true)
                setWalletCurrentAccount(accountName, full_data)
            }
            //  重新解锁（即刷新解锁后的账号信息）。
            val unlockInfos = WalletManager.sharedWalletManager().reUnlock(this)
            assert(unlockInfos.getBoolean("unlockSuccess"))
            //  提示信息
            showToast(R.string.kWalletTipsSwitchCurrentAccountDone.xmlstring(this))
            //  刷新
            refreshUI()
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     * 事件 - 删除账号
     */
    private fun onRemoveAccountClicked(data: JSONObject) {
        val walletMgr = WalletManager.sharedWalletManager()
        //  即将移除的账号
        val account_data_hash = walletMgr.getAllAccountDataHash(true)
        if (account_data_hash.length() <= 1) {
            showToast(R.string.kWalletTipsRemoveKeepOne.xmlstring(this))
            return
        }
        val accountName = data.getString("name")
        val accountData = account_data_hash.getJSONObject(accountName)

        //  如果删除当前账号（那么删除之后需要设置新的当前账号）
        var newCurrentName: String? = null
        val deleteCurrentAccount = walletMgr.getWalletAccountName()!! == accountName
        if (deleteCurrentAccount) {
            for (item in _data_array) {
                val name = item.getString("name")
                if (name != accountName) {
                    newCurrentName = name
                    break
                }
            }
        }

        //  要移除的账号的所有公钥
        val remove_account_pubkeys = WalletManager.getAllPublicKeyFromAccountData(accountData, null)

        //  其他账号的所有公钥
        val result = JSONObject()
        account_data_hash.values().forEach<JSONObject> {
            val account = it!!
            if (account.getString("name") != accountName) {
                WalletManager.getAllPublicKeyFromAccountData(account, result)
            }
        }

        //  筛选最终要移除的公钥：remove_account_pubkeys - result
        var will_delete_privatekey = false
        val final_remove_pubkey = JSONArray()
        remove_account_pubkeys.keys().forEach {
            if (!result.has(it)) {
                final_remove_pubkey.put(it)
                if (walletMgr.havePrivateKey(it)) {
                    will_delete_privatekey = true
                }
            }
        }

        //  删除
        if (will_delete_privatekey) {
            alerShowMessageConfirm(resources.getString(R.string.kWarmTips), R.string.kWalletTipsWarmMessage.xmlstring(this)).then {
                if (it != null && it as Boolean) {
                    removeAccountCore(accountName, final_remove_pubkey, newCurrentName)
                }
                return@then null
            }
        } else {
            removeAccountCore(accountName, final_remove_pubkey, newCurrentName)
        }
    }

    private fun removeAccountCore(accountName: String, pubkeyList: JSONArray, newCurrentName: String?) {
        if (newCurrentName != null) {
            val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
            mask.show()
            ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(newCurrentName).then {
                mask.dismiss()
                val full_data = it as JSONObject
                removeAccountCore2(accountName, pubkeyList, full_data)
                return@then null
            }.catch {
                mask.dismiss()
                showToast(resources.getString(R.string.tip_network_error))
            }
        } else {
            removeAccountCore2(accountName, pubkeyList, null)
        }
    }

    private fun removeAccountCore2(accountName: String, pubkeyList: JSONArray, newFullAccountData: JSONObject?) {
        //  移除账号核心
        val full_wallet_bin = WalletManager.sharedWalletManager().walletBinRemoveAccount(accountName, pubkeyList)!!
        AppCacheManager.sharedAppCacheManager().apply {
            updateWalletBin(full_wallet_bin)
            autoBackupWalletToWebdir(true)
            //  如果删除了当前账号，需要重新设置。
            if (newFullAccountData != null) {
                setWalletCurrentAccount(newFullAccountData.getJSONObject("account").getString("name"), newFullAccountData)
            }
        }
        //  重新解锁（即刷新解锁后的账号信息）。
        val unlockInfos = WalletManager.sharedWalletManager().reUnlock(this)
        assert(unlockInfos.getBoolean("unlockSuccess"))
        //  提示信息
        showToast(R.string.kWalletTipsRemoveAccountDone.xmlstring(this))
        //  重新查询&刷新界面
        queryAllAccountInfos()
    }

    /**
     *  描绘所有账号的列表。
     */
    private fun refreshDrawAllCell(data_array: MutableList<JSONObject>) {
        val layout_parent = layout_account_list_of_wallet_and_muti_sign
        layout_parent.removeAllViews()
        data_array.forEach {
            drawCell(layout_parent, it)
        }
    }

    private fun drawCell(layout_parent: LinearLayout, data: JSONObject) {

        var is_locked = data.getBoolean("locked")
        val is_current = data.getBoolean("current")

        val layout_list_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        layout_list_params.setMargins(0, 8.dp, 0, 10.dp)
        val layout_list = LinearLayout(this)
        layout_list.orientation = LinearLayout.HORIZONTAL
        layout_list.layoutParams = layout_list_params

        // 左侧 wrap
        val layout_left_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT, 5.0f)
        val layout_left = LinearLayout(this)
        layout_left.orientation = LinearLayout.VERTICAL
        layout_left.layoutParams = layout_left_params

        if (is_locked) {
            layout_left_params.gravity = Gravity.CENTER_VERTICAL
        }

        val small_font_size = 10.0f

        // 左侧 第一行
        val layout_left_line1_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT, 5.0f)
        val layout_left_line1 = LinearLayout(this)
        layout_left_line1.orientation = LinearLayout.HORIZONTAL
        layout_left_line1.layoutParams = layout_left_line1_params


        //  account name
        val tv_account_name = TextView(this)
        tv_account_name.text = data.getString("name")
        if (is_current) {
            tv_account_name.paint.isFakeBoldText = true
            tv_account_name.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 19.0f)
        } else {
            tv_account_name.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
        }

        //  current name flag
        val tv_tag_of_current_account_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        tv_tag_of_current_account_layout_params.setMargins(8, 0, 0, 0)
        tv_tag_of_current_account_layout_params.gravity = Gravity.CENTER_VERTICAL
        val tv_tag_of_current_account = TextView(this)
        tv_tag_of_current_account.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        tv_tag_of_current_account.text = resources.getString(R.string.kWalletCellCurrentAccount)
        tv_tag_of_current_account.setTextSize(TypedValue.COMPLEX_UNIT_DIP, small_font_size)
        tv_tag_of_current_account.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
        tv_tag_of_current_account.setPadding(2.dp, 0, 2.dp, 0)
        tv_tag_of_current_account.layoutParams = tv_tag_of_current_account_layout_params
        if (data.getBoolean("current")) {
            tv_account_name.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            tv_tag_of_current_account.visibility = View.VISIBLE
        } else {
            tv_account_name.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            tv_tag_of_current_account.visibility = View.INVISIBLE
        }

        layout_left_line1.addView(tv_account_name)
        layout_left_line1.addView(tv_tag_of_current_account)
        layout_left.addView(layout_left_line1)

        //  尚未锁定时才显示第二行权限。
        if (!is_locked) {
            // 左侧 第二行
            val layout_left_line2_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT, 5.0f)
            layout_left_line2_params.setMargins(0, 10, 0, 0)
            val layout_left_line2 = LinearLayout(this)
            layout_left_line2.orientation = LinearLayout.HORIZONTAL
            layout_left_line2.layoutParams = layout_left_line2_params

            // 账号权限
            val tv_tag_of_account_privilege_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            tv_tag_of_account_privilege_layout_params.setMargins(0, 0, 0, 0)
            val tv_tag_of_account_privilege = TextView(this)
            tv_tag_of_account_privilege.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            tv_tag_of_account_privilege.text = resources.getString(R.string.kWalletCellPermissionOwner)
            tv_tag_of_account_privilege.setTextSize(TypedValue.COMPLEX_UNIT_DIP, small_font_size)
            tv_tag_of_account_privilege.setPadding(2.dp, 0, 2.dp, 0)
            tv_tag_of_account_privilege.layoutParams = tv_tag_of_account_privilege_layout_params
            layout_left_line2.addView(tv_tag_of_account_privilege)
            when (data.getInt("owner_status")) {
                EAccountPermissionStatus.EAPS_NO_PERMISSION.value -> {
                    tv_tag_of_account_privilege.setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    tv_tag_of_account_privilege.background = resources.getDrawable(R.drawable.textview_border_grey)
                }
                EAccountPermissionStatus.EAPS_PARTIAL_PERMISSION.value -> {
                    tv_tag_of_account_privilege.setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                    tv_tag_of_account_privilege.background = resources.getDrawable(R.drawable.textview_border_highlight)
                }
                EAccountPermissionStatus.EAPS_ENOUGH_PERMISSION.value ->
                    tv_tag_of_account_privilege.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
                EAccountPermissionStatus.EAPS_FULL_PERMISSION.value ->
                    tv_tag_of_account_privilege.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
            }

            // 资金权限
            val tv_tag_of_capital_privilege_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            tv_tag_of_capital_privilege_layout_params.setMargins(8.dp, 0, 0, 0)
            val tv_tag_of_capital_privilege = TextView(this)
            tv_tag_of_capital_privilege.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            tv_tag_of_capital_privilege.text = resources.getString(R.string.kWalletCellPermissionActive)
            tv_tag_of_capital_privilege.setTextSize(TypedValue.COMPLEX_UNIT_DIP, small_font_size)
            tv_tag_of_capital_privilege.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
            tv_tag_of_capital_privilege.setPadding(2.dp, 0, 2.dp, 0)
            tv_tag_of_capital_privilege.layoutParams = tv_tag_of_capital_privilege_layout_params
            layout_left_line2.addView(tv_tag_of_capital_privilege)
            when (data.getInt("active_status")) {
                EAccountPermissionStatus.EAPS_NO_PERMISSION.value -> {
                    tv_tag_of_capital_privilege.setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    tv_tag_of_capital_privilege.background = resources.getDrawable(R.drawable.textview_border_grey)
                }
                EAccountPermissionStatus.EAPS_PARTIAL_PERMISSION.value -> {
                    tv_tag_of_capital_privilege.setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                    tv_tag_of_capital_privilege.background = resources.getDrawable(R.drawable.textview_border_highlight)
                }
                EAccountPermissionStatus.EAPS_ENOUGH_PERMISSION.value ->
                    tv_tag_of_capital_privilege.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
                EAccountPermissionStatus.EAPS_FULL_PERMISSION.value ->
                    tv_tag_of_capital_privilege.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
            }

            // 备注权限
            val tv_tag_of_remark_privilege_layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            tv_tag_of_remark_privilege_layout_params.setMargins(8.dp, 0, 0, 0)
            val tv_tag_of_remark_privilege = TextView(this)
            tv_tag_of_remark_privilege.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            tv_tag_of_remark_privilege.text = resources.getString(R.string.kWalletCellPermissionMemo)
            tv_tag_of_remark_privilege.setTextSize(TypedValue.COMPLEX_UNIT_DIP, small_font_size)
            tv_tag_of_remark_privilege.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
            tv_tag_of_remark_privilege.setPadding(2.dp, 0, 2.dp, 0)
            tv_tag_of_remark_privilege.layoutParams = tv_tag_of_remark_privilege_layout_params
            layout_left_line2.addView(tv_tag_of_remark_privilege)
            if (data.getBoolean("haveMemoPermission")) {
                tv_tag_of_remark_privilege.setBackgroundColor(resources.getColor(R.color.theme01_textColorHighlight))
            } else {
                tv_tag_of_remark_privilege.setTextColor(resources.getColor(R.color.theme01_textColorGray))
                tv_tag_of_remark_privilege.background = resources.getDrawable(R.drawable.textview_border_grey)
            }

            layout_left.addView(layout_left_line2)
        }

        var right_height = 40.dp
        if (is_locked) {
            right_height = LLAYOUT_WARP
        }

        //  右侧 wrap  箭头
        val layout_right_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, right_height, 1.0f)
        val layout_right = LinearLayout(this)
        layout_right.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        layout_right_params.gravity = Gravity.RIGHT
        layout_right.orientation = LinearLayout.VERTICAL
        layout_right.layoutParams = layout_right_params

        val iv_right_arrow = ImageView(this)
        iv_right_arrow.setImageDrawable(resources.getDrawable(R.drawable.ic_btn_right_arrow))
        iv_right_arrow.scaleType = ImageView.ScaleType.FIT_END
        layout_right.addView(iv_right_arrow)

        layout_list.addView(layout_left)
        layout_list.addView(layout_right)

        // 点击事件
        layout_list.setOnClickListener {
            onAccountListClicked(data)
        }

        // 线
        val lv_line = View(this)
        var layout_line_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(1.0f))
        lv_line.setBackgroundColor(resources.getColor(R.color.theme01_bottomLineColor))
        lv_line.layoutParams = layout_line_params

        layout_parent.addView(layout_list)
        layout_parent.addView(lv_line)
    }

    /**
     * 刷新UI（不重新查询）
     */
    private fun refreshUI() {
        val ary = JSONArray()
        _data_array.forEach {
            ary.put(it.getJSONObject("raw_json"))
        }
        onQueryAllAccountInfosResponse(ary)
    }

    private fun onQueryAllAccountInfosResponse(data_array: JSONArray) {
        //  本地钱包文件快捷查询信息
        AppCacheManager.sharedAppCacheManager().setWalletAccountDataList(data_array)
        //  更新列表数据
        _data_array.clear()
        val walletMgr = WalletManager.sharedWalletManager()
        val isLocked = walletMgr.isLocked()
        val currentAccoutName = walletMgr.getWalletAccountName()!!
        data_array.forEach<JSONObject> {
            val account_info = it!!
            val name = account_info.getString("name")
            val isCurrent = name == currentAccoutName
            if (isLocked) {
                //  锁定状态没法获取权限
                _data_array.add(jsonObjectfromKVS("name", name, "current", isCurrent, "raw_json", account_info, "locked", isLocked))
            } else {
                //  解锁状态下判断各种权限判断。
                val owner = account_info.getJSONObject("owner")
                val active = account_info.getJSONObject("active")
                val memo_key = account_info.getJSONObject("options").optString("memo_key")
                val owner_status = walletMgr.calcPermissionStatus(owner)
                val active_status = walletMgr.calcPermissionStatus(active)
                val haveMemoPermission = memo_key != "" && walletMgr.havePrivateKey(memo_key)
                _data_array.add(jsonObjectfromKVS("name", name, "current", isCurrent, "raw_json", account_info, "locked", isLocked,
                        "owner_status", owner_status.value, "active_status", active_status.value, "haveMemoPermission", haveMemoPermission))
            }
        }
        //  按照 current 字段降序排列。即：当前账号排列在最前
        _data_array.sortByDescending { it.getBoolean("current") }
        refreshDrawAllCell(_data_array)
    }

    /**
     * 重新查询&刷新UI
     */
    private fun queryAllAccountInfos() {
        val account_namelist = WalletManager.sharedWalletManager().getWalletAccountNameList()
        assert(account_namelist.length() > 0)

        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this)
        mask.show()

        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        conn.async_exec_db("lookup_account_names", jsonArrayfrom(account_namelist)).then {
            mask.dismiss()
            val data_array = it as JSONArray
            ChainObjectManager.sharedChainObjectManager().updateGrapheneObjectCache(data_array)
            onQueryAllAccountInfosResponse(data_array)
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }
}
