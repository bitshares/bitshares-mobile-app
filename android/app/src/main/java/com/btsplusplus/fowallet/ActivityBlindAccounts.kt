package com.btsplusplus.fowallet

import android.os.Bundle
import android.text.TextUtils
import android.util.TypedValue
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_blind_accounts.*
import org.json.JSONArray
import org.json.JSONObject

/**
 *  枚举 - 账号管理操作类型枚举
 */
const val kActionTypeGenChildKey = 0
const val kActionTypeCopyKey = 1

class ActivityBlindAccounts : BtsppActivity() {

    private var _result_promise: Promise? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_accounts)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        findViewById<TextView>(R.id.title).text = args.getString("title")
        _result_promise = args.opt("result_promise") as? Promise

        //  初始化UI
        refreshUI()

        //  右上角按钮（地址管理模式才存在、选择模式不存在。）
        if (isSelectMode()) {
            button_add_from_blind_accounts.visibility = View.INVISIBLE
        } else {
            button_add_from_blind_accounts.setOnClickListener { onAddAccountClicked() }
        }

        //  返回事件
        layout_back_from_blind_accounts.setOnClickListener { finish() }
    }

    private fun isSelectMode(): Boolean {
        return _result_promise != null
    }

    private fun onAddAccountClicked() {
        ViewSelector.show(this, "", arrayOf(resources.getString(R.string.kVcStActionImportBlindAccount),
                resources.getString(R.string.kVcStActionCreateBlindAccount))) { index: Int, _: String ->
            if (index == 0) {
                val result_promise = Promise()
                goTo(ActivityBlindAccountImport::class.java, true, args = JSONObject().apply {
                    put("result_promise", result_promise)
                })
                result_promise.then {
                    val blind_account = it as? JSONObject
                    if (blind_account != null) {
                        //  刷新
                        refreshUI()
                    }
                }
            } else {
                val self = this
                goTo(ActivityNewAccountPassword::class.java, true, args = JSONObject().apply {
                    put("title", self.resources.getString(R.string.kVcTitleBackupYourPassword))
                    put("scene", kNewPasswordSceneGenBlindAccountBrainKey)
                })
            }
        }
    }

    private fun createAccountCellCell(section_item: JSONObject, blind_account: JSONObject, is_main_account: Boolean): LinearLayout {
        val layout = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                setMargins(0, 0, 0, 10.dp)
            }
            orientation = LinearLayout.VERTICAL
        }

        //    id blind_account = @{
        //        @"public_key": @"",
        //        @"alias_name": @"",
        //        @"parent_key": @"",
        //        @"child_key_index": @0
        //    };

        val self = this

        //  账号名称
        val tv_account_name = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
            if (is_main_account) {
                text = blind_account.optString("alias_name")
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 16.0f)
            } else {
                text = ViewUtils.genBlindAccountDisplayName(self, blind_account.getString("public_key"))
                setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            }
        }

        //  账号地址
        val tv_account_address = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                setMargins(0, 10.dp, 0, 0)
            }
            text = blind_account.getString("public_key")
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
            setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            setSingleLine(true)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.MIDDLE
        }

        //  线
        val tv_line = ViewLine(this, 5.dp)

        layout.addView(tv_account_name)
        layout.addView(tv_account_address)
        layout.addView(tv_line)

        //  事件 - 点击
        layout.setOnClickListener {
            onCellClicked(blind_account, section_item)
        }
        return layout
    }

    private fun onCellClicked(blind_account: JSONObject, section_item: JSONObject) {
        if (isSelectMode()) {
            //  选择 & 返回
            _result_promise!!.resolve(blind_account)
            finish()
        } else {
            //  管理
            onCellActionPopAction(blind_account, section_item)
        }
    }

    private fun onCellActionPopAction(blind_account: JSONObject, section_item: JSONObject) {
        val actions = JSONArray()
        val self = this

        val parent_key = blind_account.optString("parent_key")
        if (parent_key.isEmpty()) {
            //  主账号
            actions.put(JSONObject().apply {
                put("type", kActionTypeGenChildKey)
                put("name", self.resources.getString(R.string.kVcStActionCreateSubBlindAccount))
            })
        }

        actions.put(JSONObject().apply {
            put("type", kActionTypeCopyKey)
            put("name", self.resources.getString(R.string.kVcStActionCopyBlindAccountAddress))
        })

        ViewSelector.show(this, "", actions, "name") { index: Int, _: String ->
            when (actions.getJSONObject(index).getInt("type")) {
                kActionTypeGenChildKey -> {
                    val data_child_array = section_item.get("child") as MutableList<JSONObject>
                    //  可配置：限制子账号数量。扫描恢复收据验证to等时候容易一些。
                    val allow_maximum_child_account = 5
                    if (data_child_array.size >= allow_maximum_child_account) {
                        showToast(String.format(resources.getString(R.string.kVcStTipAllowMaximumChildAccount), allow_maximum_child_account.toString()))
                    } else {
                        //  正常创建子账户
                        guardWalletUnlocked(false) { unlocked ->
                            if (unlocked) {
                                onActionClickedGenChildKey(blind_account, section_item)
                            }
                        }
                    }
                }
                kActionTypeCopyKey -> {
                    if (Utils.copyToClipboard(this, blind_account.getString("public_key"))) {
                        showToast(resources.getString(R.string.kVcDWTipsCopyOK))
                    }
                }
            }
        }
    }

    private fun onActionClickedGenChildKey(blind_account: JSONObject, section_item: JSONObject) {
        val main_public_key = blind_account.getString("public_key")

        val walletMgr = WalletManager.sharedWalletManager()
        val main_pri_key = walletMgr.getGraphenePrivateKeyByPublicKey(main_public_key)
        if (main_pri_key == null) {
            showToast(resources.getString(R.string.kVcStTipErrMissMainAccountPrivateKey))
            return
        }

        val pri_keydata = main_pri_key.getKeyData()

        //  开始创建子KEY
        val hdk = HDWallet.fromMasterSeed(pri_keydata)

        //  计算新子账号索引（子账号已经根据索引升序排列了，直接区最后一个即可。）
        var new_child_key_index = 0
        val data_child_array = section_item.get("child") as MutableList<JSONObject>
        if (data_child_array.size > 0) {
            new_child_key_index = data_child_array.last().getInt("child_key_index") + 1
        }

        val child_key = hdk.deriveBitsharesStealthChildKey(new_child_key_index)
        val wif_child_pri_key = child_key.toWifPrivateKey()
        val wif_child_pub_key = OrgUtils.genBtsAddressFromWifPrivateKey(wif_child_pri_key)

        val child_blind_account = JSONObject().apply {
            put("public_key", wif_child_pub_key)
            put("alias_name", "")
            put("parent_key", main_public_key)
            put("child_key_index", new_child_key_index)
        }

        //  隐私交易子地址导入钱包
        val full_wallet_bin = walletMgr.walletBinImportAccount(null, jsonArrayfrom(wif_child_pri_key))!!
        AppCacheManager.sharedAppCacheManager().apply {
            appendBlindAccount(child_blind_account, auto_save = false)
            updateWalletBin(full_wallet_bin)
            autoBackupWalletToWebdir(false)
        }

        //  重新解锁（即刷新解锁后的账号信息）。
        val unlockInfos = walletMgr.reUnlock(this)
        assert(unlockInfos.getBoolean("unlockSuccess"))

        //  导入成功
        refreshUI()
        showToast(resources.getString(R.string.kVcStTipCreateChildBlindAccountSuccess))
    }

    private fun createAccountView(section_item: JSONObject): LinearLayout {
        val layout = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                setMargins(0, 0, 0, 20.dp)
            }
            orientation = LinearLayout.VERTICAL
        }

        //  主账号
        layout.addView(createAccountCellCell(section_item, section_item.getJSONObject("main"), is_main_account = true))

        //  子账号
        for (blind_account in section_item.get("child") as MutableList<JSONObject>) {
            layout.addView(createAccountCellCell(section_item, blind_account, is_main_account = false))
        }

        return layout
    }

    private fun loadBlindAccounts(): MutableList<JSONObject> {
        val dataArray = mutableListOf<JSONObject>()

        //    id blind_account = @{
        //        @"public_key": @"",
        //        @"alias_name": @"",
        //        @"parent_key": @"",
        //        @"child_key_index": @0
        //    };
        val sections = JSONObject()
        val child_list = JSONArray()

        val accounts_hash = AppCacheManager.sharedAppCacheManager().getAllBlindAccounts()
        for (public_key in accounts_hash.keys()) {
            val blind_account = accounts_hash.getJSONObject(public_key)
            val parent_key = blind_account.optString("parent_key")
            if (parent_key.isNotEmpty()) {
                //  子账号
                child_list.put(blind_account)
            } else {
                //  主账号
                sections.put(public_key, JSONObject().apply {
                    put("main", blind_account)
                    put("child", mutableListOf<JSONObject>())
                })
            }
        }
        for (blind_account in child_list.forin<JSONObject>()) {
            val parent_key = blind_account!!.getString("parent_key")
            assert(parent_key.isNotEmpty())
            val section_item = sections.getJSONObject(parent_key)
            (section_item.get("child") as MutableList<JSONObject>).add(blind_account)
        }

        //  排序：主账号根据地址排序、子账号根据索引升序排序。
        for (section_item in sections.values().forin<JSONObject>()) {
            dataArray.add(section_item!!)
        }
        dataArray.sortBy { it.getJSONObject("main").getString("public_key") }
        for (section_item in dataArray) {
            val child = section_item.get("child") as MutableList<JSONObject>
            if (child.size > 0) {
                child.sortBy { it.getInt("child_key_index") }
            }
        }

        return dataArray
    }

    private fun refreshUI() {
        val container = layout_account_list_of_blind_accounts
        container.removeAllViews()

        val data_array = loadBlindAccounts()
        if (data_array.size > 0) {
            for (item in data_array) {
                container.addView(createAccountView(item))
            }
        } else {
            //  无数据
            if (isSelectMode()) {
                container.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kVcStTipEmptyNoBlindAccount)))
            } else {
                container.addView(ViewUtils.createEmptyCenterLabel(this, resources.getString(R.string.kVcStTipEmptyNoBlindAccountCanImport)))
            }
        }
    }
}
