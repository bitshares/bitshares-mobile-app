package com.btsplusplus.fowallet

import android.content.Context
import android.os.Bundle
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_permission_edit.*
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

class ActivityPermissionEdit : BtsppActivity() {

    private var _old_authority_hash = JSONObject()          //  修改前的权限信息（KEY：key_threshold  VALUE：BOOL）
    private var _old_weightThreshold = 0                    //  修改前的通过阈值

    private lateinit var _permission_item: JSONObject
    private var _maximum_authority_membership = 0
    private lateinit var _result_promise: Promise

    private var _permissionList = mutableListOf<JSONObject>()
    private var _weightThreshold = 0

    /**
     *  初始化数据
     */
    private fun _initPermissionList() {
        val raw = _permission_item.getJSONObject("raw")
        _weightThreshold = raw.getInt("weight_threshold")
        _old_weightThreshold = _weightThreshold
        raw.getJSONArray("account_auths").forEach<JSONArray> { item ->
            assert(item!!.length() == 2)
            val key = item.getString(0)
            val threshold = item.getInt(1)
            _old_authority_hash.put("${key}_$threshold", true)
            _permissionList.add(JSONObject().apply {
                put("key", key)
                put("threshold", threshold)
                put("isaccount", true)
            })
        }
        raw.getJSONArray("key_auths").forEach<JSONArray> { item ->
            assert(item!!.length() == 2)
            val key = item.getString(0)
            val threshold = item.getInt(1)
            _old_authority_hash.put("${key}_$threshold", true)
            _permissionList.add(JSONObject().apply {
                put("key", key)
                put("threshold", threshold)
                put("iskey", true)
            })
        }
        raw.getJSONArray("address_auths").forEach<JSONArray> { item ->
            assert(item!!.length() == 2)
            val key = item.getString(0)
            val threshold = item.getInt(1)
            _old_authority_hash.put("${key}_$threshold", true)
            _permissionList.add(JSONObject().apply {
                put("key", key)
                put("threshold", threshold)
                put("isaddr", true)
            })
        }
        //  根据权重降序排列
        _sort_permission_list()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_permission_edit)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _permission_item = args.getJSONObject("permission")
        _maximum_authority_membership = args.getInt("maximum_authority_membership")
        _result_promise = args.get("result_promise") as Promise

        //  初始化部分数据
        _initPermissionList()

        //  类型 & 阈值
        tv_permission_type_from_edit_permission.text = _permission_item.getString("title")
        _refreshUI()

        //  事件
        ly_threshold_value_from_edit_permission.setOnClickListener { _onPassThresholdClicked() }
        btn_add_one_from_edit_permission.setOnClickListener { _onAddOneClicked() }
        btn_submit_from_edit_permission.setOnClickListener { _onSubmitClicked() }
        layout_back_from_edit_permission.setOnClickListener { onBackClicked(null) }
    }

    /**
     *  (private) 排序
     */
    private fun _sort_permission_list() {
        _permissionList.sortByDescending { it.getInt("threshold") }
    }

    /**
     *  (private) 计算当前设置的所有权力实体的总阈值
     */
    private fun _calcAuthorityListTotalThreshold(): Int {
        var total_threshold = 0
        _permissionList.forEach { total_threshold += it.getInt("threshold") }
        return total_threshold
    }

    private fun _refreshUI() {
        _drawUI_passThreshold()
        _drawUI_authorityList()
    }

    /**
     *  描绘UI - 当前阈值
     */
    private fun _drawUI_passThreshold() {
        tv_threshold_value_from_edit_permission.text = _weightThreshold.toString()
        if (_weightThreshold == 0 || _weightThreshold > _calcAuthorityListTotalThreshold()) {
            //  门槛阈值太高：无效
            tv_threshold_value_from_edit_permission.setTextColor(resources.getColor(R.color.theme01_sellColor))
        } else {
            tv_threshold_value_from_edit_permission.setTextColor(resources.getColor(R.color.theme01_buyColor))
        }
    }

    private fun _drawAuthorityLine(ctx: Context, title: String, weight: String, btn: String, authority_item: JSONObject? = null): LinearLayout {
        val is_title = authority_item == null
        return LinearLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, 28.dp).apply {
                setMargins(0, 5.dp, 0, 0)
            }
            orientation = LinearLayout.HORIZONTAL

            //  管理者
            val layout_left = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL

                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 6.0f).apply {
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                }
                val tv_authority_name = TextView(ctx).apply {
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                    if (is_title) {
                        setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    } else {
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    }
                    text = title
                    setSingleLine(true)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                }
                addView(tv_authority_name)
            }

            //  权重
            val layout_center = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL

                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 3.0f).apply {
                    setMargins(16.dp, 0, 0, 0)
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                }
                val tv_weight = TextView(ctx).apply {
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                    if (is_title) {
                        setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    } else {
                        setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    }
                    text = weight
                }
                addView(tv_weight)
            }

            //  操作
            val layout_right = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL

                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1.5f).apply {
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                }
                val tv_remove = TextView(ctx).apply {
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14.0f)
                    text = btn
                    if (is_title) {
                        setTextColor(resources.getColor(R.color.theme01_textColorGray))
                    } else {
                        setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                        setOnClickListener { _onRemoveOneClicked(authority_item!!) }
                    }
                }
                addView(tv_remove)
            }

            addView(layout_left)
            addView(layout_center)
            addView(layout_right)
        }
    }

    /**
     *  描绘UI - 权限实体列表
     */
    private fun _drawUI_authorityList() {
        val layout_parent = ly_edit_public_key_from_edit_permission
        layout_parent.removeAllViews()

        val _this = this

        //  描绘标题
        layout_parent.addView(_drawAuthorityLine(_this, resources.getString(R.string.kVcPermissionEditTitleName),
                resources.getString(R.string.kVcPermissionEditTitleWeight), resources.getString(R.string.kVcPermissionEditTitleAction), null))

        //  描绘管理者
        _permissionList.forEach { item ->
            //  authority name
            var name = item.optString("name", null)
            if (name == null) {
                name = item.getString("key")
                if (item.optBoolean("isaccount")) {
                    name = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(name).getString("name")
                }
            }

            //  计算该授权实体占比权重（最大值限制为100%）。
            val threshold = item.getInt("threshold")
            var weight_percent = threshold.toDouble() * 100.0 / _weightThreshold.toDouble()
            if (threshold < _weightThreshold) {
                weight_percent = min(weight_percent, 99.0)
            }
            if (threshold > 0) {
                weight_percent = max(weight_percent, 1.0)
            }
            weight_percent = min(weight_percent, 100.0)

            //  描绘UI
            layout_parent.addView(_drawAuthorityLine(_this, name, "$threshold (${weight_percent.toInt()}%)", resources.getString(R.string.kVcPermissionEditBtnRemove), item))
        }
    }

    /**
     *  移除某管理者
     */
    private fun _onRemoveOneClicked(item: JSONObject) {
        _permissionList.remove(item)
        _refreshUI()
    }

    /**
     *  添加新权力实体
     */
    private fun _onAddOneClicked() {
        //  限制最大多签成员数
        if (_permissionList.size >= _maximum_authority_membership) {
            showToast(String.format(resources.getString(R.string.kVcPermissionEditTipsMaxAuthority), _maximum_authority_membership.toString()))
            return
        }

        //  转到添加权限界面
        val result_promise = Promise()
        goTo(ActivityPermissionAddOne::class.java, true, args = JSONObject().apply {
            put("result_promise", result_promise)
        })
        result_promise.then {
            //  @{@"key":key, @"name":name, @"isaccount":@(isaccount), @"threshold":@(threshold)}
            val json_data = it as JSONObject
            val key = json_data.getString("key")
            //  移除（重复的）
            for (item in _permissionList) {
                if (item.getString("key") == key) {
                    _permissionList.remove(item)
                    break
                }
            }
            //  添加
            _permissionList.add(json_data)
            //  根据权重降序排列
            _sort_permission_list()
            //  刷新
            _refreshUI()
            return@then null
        }
    }

    /*
     *  (private) 判断权限信息是否发生变化。
     */
    private fun _isModifiyed(): Boolean {
        //  1、判断阈值是否有修改
        if (_old_weightThreshold != _weightThreshold) {
            return true
        }

        //  2、权力实体数量发生变化（增加or减少）
        if (_permissionList.size != _old_authority_hash.length()) {
            return true
        }

        //  3、判断权力实体以及每个实体的权重是否有修改
        for (item in _permissionList) {
            val check_key = "${item.getString("key")}_${item.getInt("threshold")}"
            //  新KEY或新阈值在当前的权限信息中不存在，则说明已经修改。
            if (!_old_authority_hash.has(check_key)) {
                return true
            }
        }
        return false
    }

    /**
     *  提交修改
     */
    private fun _onSubmitClicked() {
        //  1、检测权限信息是否变化
        if (!_isModifiyed()) {
            showToast(resources.getString(R.string.kVcPermissionEditSubmitTipsNoChanged))
            return
        }

        //  2、检测阈值和权重配置是否正确。
        assert(_weightThreshold > 0)
        if (_weightThreshold > _calcAuthorityListTotalThreshold()) {
            showToast(resources.getString(R.string.kVcPermissionEditSubmitTipsInvalidPassThreshold))
            return
        }

        //  3、公钥二次确认。
        var exist_pubkey_authority = false
        for (item in _permissionList) {
            if (item.optBoolean("iskey")) {
                exist_pubkey_authority = true
                break
            }
        }
        if (exist_pubkey_authority) {
            alerShowMessageConfirm(resources.getString(R.string.kWarmTips), resources.getString(R.string.kVcPermissionEditSubmitSafeTipsPubkeyConfirm)).then {
                if (it != null && it as Boolean) {
                    _gotoAskUpdateAccount()
                }
                return@then null
            }
        } else {
            _gotoAskUpdateAccount()
        }
    }

    /**
     *  (private) 请求二次确认修改账号权限信息。
     */
    private fun _gotoAskUpdateAccount() {
        alerShowMessageConfirm(resources.getString(R.string.kWarmTips), resources.getString(R.string.kVcPermissionEditSubmitSafeTipsSecurityConfrim)).then {
            if (it != null && it as Boolean) {
                // 解锁钱包or账号
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        _submitUpdateAccountCore()
                    }
                }
            }
            return@then null
        }
    }

    /**
     *  (private) 修改权限核心
     */
    private fun _submitUpdateAccountCore() {
        val account = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val uid = account.getString("id")

        val account_auths = JSONArray()
        val key_auths = JSONArray()
        for (item in _permissionList) {
            val key = item.getString("key")
            val threshold = item.getInt("threshold")
            if (item.optBoolean("isaccount")) {
                account_auths.put(jsonArrayfrom(key, threshold))
            } else {
                key_auths.put(jsonArrayfrom(key, threshold))
            }
        }

        val authority = JSONObject().apply {
            put("weight_threshold", _weightThreshold)
            put("account_auths", account_auths)
            put("key_auths", key_auths)
            put("address_auths", JSONArray())
        }

        val type = _permission_item.get("type") as EBitsharesPermissionType
        var using_owner_authority = false

        val op_data = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", ChainObjectManager.sharedChainObjectManager().grapheneCoreAssetID)
            })
            put("account", uid)
            if (type == EBitsharesPermissionType.ebpt_owner) {
                using_owner_authority = true
                put("owner", authority)
            } else {
                assert(type == EBitsharesPermissionType.ebpt_active)
                using_owner_authority = false
                put("active", authority)
            }
        }

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_account_update, using_owner_authority, false, op_data, account) { isProposal, _ ->
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
                            //  返回
                            _result_promise.resolve(full_data)
                            onBackClicked(null)
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
     *  阈值点击
     */
    private fun _onPassThresholdClicked() {
        UtilsAlert.showInputBox(this, resources.getString(R.string.kVcPermissionEditNewPassThresholdTitle),
                resources.getString(R.string.kVcPermissionEditNewPassThresholdPlaceholder), resources.getString(R.string.kBtnOK), is_password = false, iDecimalPrecision = 0, iMaxLength = 7).then {
            val threshold_value = it as? String
            if (threshold_value != null) {
                val i_threshold = threshold_value.toIntOrNull()
                //  REMARK：单个 authority 的最大值是 65535，目前理事会参数最多10个 authority。这里目前配置最大范围可以容量 100+ authority。
                if (i_threshold == null || i_threshold < 1 || i_threshold > 9999999) {
                    showToast(resources.getString(R.string.kVcPermissionEditTipsInvalidPassThreshold))
                } else {
                    _weightThreshold = i_threshold
                    _refreshUI()
                }
            }
            return@then null
        }
    }
}
