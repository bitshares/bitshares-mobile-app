package com.btsplusplus.fowallet

import android.os.Bundle
import android.text.SpannableStringBuilder
import android.text.TextUtils
import android.view.View
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import kotlinx.android.synthetic.main.activity_create_htlc_contract.*
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.pow


class ActivityCreateHtlcContract : BtsppActivity() {

    private var _mode: Int? = null
    private var _have_preimage: Boolean = false

    private var _ref_htlc: JSONObject? = null       //  根据合约A作为参考部署合约B，该字段可能为nil。（REMARK：以下几个字段相关联。）
    private var _ref_to: JSONObject? = null
    private var _htlc_a_expiration: Long = 0        //  合约A等过期时间。
    private var _htlc_b_reserved_time: Int = 0      //  合约B部署时预留安全时间。
    private var _lock_field: Boolean = false        //  是否锁定部分字段。（不可编辑）

    private var _full_account_data: JSONObject? = null
    private var _default_asset: JSONObject? = null

    private var _balances_hash: JSONObject? = null
    private var _fee_item: JSONObject? = null
    private var _asset_list: JSONArray? = null
    private var _transfer_args: JSONObject? = null
    private var _n_available: Double = 0.0
    private var _s_available: String = ""
    private var _tf_amount_watcher: UtilsDigitTextWatcher? = null

    private var _const_hashtype_list: JSONArray? = null
    private var _const_expire_list: JSONArray? = null

    private var _currHashType: JSONObject? = null
    private var _currExpire: JSONObject? = null
    private var _currPreimageLength: Int = 0

    private lateinit var _tv_amount: EditText
    private lateinit var _tv_preimage_or_hash: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_create_htlc_contract)

        //  获取参数val
        val args = btspp_args_as_JSONObject()
        _full_account_data = args.getJSONObject("full_userdata")

        _mode = args.getInt("mode")
        _have_preimage = args.getBoolean("havePreimage")
        _ref_htlc = args.optJSONObject("ref_htlc")
        _ref_to = args.optJSONObject("ref_to")

        _lock_field = _ref_htlc != null

        _tv_amount = et_amount_from_create_htlc_contract
        _tv_preimage_or_hash = if (_mode == EHtlcDeployMode.EDM_PREIMAGE.value) tv_preimage else tv_hashcode

        //  设置标题栏标题
        if (_lock_field) {
            title_from_create_htlc_contract.text = R.string.kVcTitleCreateSubHTLC.xmlstring(this)
        } else {
            title_from_create_htlc_contract.text = R.string.kVcTitleCreateHTLC.xmlstring(this)
        }

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  1、初始化：哈希类型列表 和 当前默认哈希算法
        _const_hashtype_list = JSONArray().apply {
            put(JSONObject().apply {
                put("name", "RIPEMD160")
                put("value", EBitsharesHtlcHashType.EBHHT_RMD160.value)
            })
            put(JSONObject().apply {
                put("name", "SHA1")
                put("value", EBitsharesHtlcHashType.EBHHT_SHA1.value)
            })
            put(JSONObject().apply {
                put("name", "SHA256")
                put("value", EBitsharesHtlcHashType.EBHHT_SHA256.value)
            })
        }
        _currHashType = _const_hashtype_list!!.getJSONObject(2)

        //  2、初始化 默认原像长度
        _currPreimageLength = _randomSecurePreimage().length

        //  3、初始化默认有效期
        //  TODO:fowallet 最大时间不能超过理事会 parameters.extensions.value.updatable_htlc_options; 配置。
        if (_mode == EHtlcDeployMode.EDM_PREIMAGE.value || _have_preimage) {
            //  主动创建时候的合约有效期（先创建）
            _const_expire_list = JSONArray().apply {
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNDayFmt), "3"))
                    put("value", 3600 * 24 * 3)
                })
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNDayFmt), "5"))
                    put("value", 3600 * 24 * 5)
                })
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNDayFmt), "7"))
                    put("value", 3600 * 24 * 7)
                })
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNDayFmt), "15"))
                    put("value", 3600 * 24 * 15)
                })
            }
            _currExpire = _const_expire_list!!.getJSONObject(1)
        } else {
            //  被动创建时候的合约有效期（后创建）
            _const_expire_list = JSONArray().apply {
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNHourFmt), "6"))
                    put("value", 3600 * 6)
                })
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNHourFmt), "12"))
                    put("value", 3600 * 12)
                })
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNDayFmt), "1"))
                    put("value", 3600 * 24 * 1)
                })
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNDayFmt), "2"))
                    put("value", 3600 * 24 * 2)
                })
                put(JSONObject().apply {
                    put("name", String.format(resources.getString(R.string.kVcHtlcCellValueNDayFmt), "3"))
                    put("value", 3600 * 24 * 3)
                })
            }
            _currExpire = _const_expire_list!!.getJSONObject(2)

            //  ※ 根据合约部署时修订默认有效期（必须小于对方合约）
            if (_lock_field) {
                val now_ts = Utils.now_ts()
                _htlc_a_expiration = Utils.parseBitsharesTimeString(_ref_htlc!!.getJSONObject("conditions").getJSONObject("time_lock").getString("expiration"))
                //  REMARK：预留至少一天。
                //  如果后部署的用户的有效期接近合约A的有效期，那么后部署的用户可能存在资金分享。（用户A在合约B即将到期的时候提取，那么用户B来不及提取合约A。）
                _htlc_b_reserved_time = 3600 * 24
                val mutable_list = JSONArray()
                for (it in _const_expire_list!!.forin<JSONObject>()) {
                    val item = it!!
                    val seconds = item.getInt("value")
                    if (now_ts + seconds <= _htlc_a_expiration - _htlc_b_reserved_time) {
                        mutable_list.put(item)
                    } else {
                        break
                    }
                }
                //  REMARK：没有满足条件的时间周期，默认第一个。但提示用户不可部署合约。
                if (mutable_list.length() <= 0) {
                    mutable_list.put(_const_expire_list!!.getJSONObject(0))
                }
                _const_expire_list = JSONArray().apply { putAll(mutable_list) }
                _currExpire = _const_expire_list!!.last()
            }
        }

        //  返回
        layout_back_from_create_htlc_contract.setOnClickListener { finish() }

        //  TO
        findViewById<LinearLayout>(R.id.cell_to_account).setOnClickListener {
            TempManager.sharedTempManager().set_query_account_callback { last_activity, it ->
                last_activity.goTo(ActivityCreateHtlcContract::class.java, true, back = true)
                _transfer_args!!.put("to", it)
                refreshUI()
            }
            goTo(ActivityAccountQueryBase::class.java, true)
        }

        //  ASSET
        findViewById<LinearLayout>(R.id.cell_transfer_asset).setOnClickListener {
            val list = mutableListOf<String>()
            for (asset in _asset_list!!) {
                list.add(asset!!.getString("symbol"))
            }
            ViewSelector.show(this, resources.getString(R.string.kVcTransferTipSelectAsset), list.toTypedArray()) { index: Int, result: String ->
                val select_asset = _asset_list!![index] as JSONObject
                //  选择发生变化则刷新
                if (select_asset.getString("symbol") != _transfer_args!!.getJSONObject("asset").getString("symbol")) {
                    setAsset(select_asset)
                    refreshUI()
                }
            }
        }

        //  事件 - 全部按钮
        findViewById<TextView>(R.id.btn_transfer_all).setOnClickListener {
            _tv_amount.setText(_s_available)
            _tv_amount.setSelection(_tv_amount.text.toString().length)
            //  onAmountChanged 会自动触发
        }

        //  初始化相关参数
        genTransferDefaultArgs(null)
        refreshUI()

        //  初始化事件
        _tf_amount_watcher = UtilsDigitTextWatcher().set_tf(_tv_amount).set_precision(_transfer_args!!.getJSONObject("asset").getInt("precision"))
        _tv_amount.addTextChangedListener(_tf_amount_watcher!!)
        _tf_amount_watcher!!.on_value_changed(::onAmountChanged)

        //  初始化控件状态
        initDefaultStatus()
    }

    /**
     *  随机生成安全的原像
     */
    private fun _randomSecurePreimage(): String {
        //  TODO:fowallet 最大原像不能超过 o.preimage_size <= htlc_options->max_preimage_size
        return String.format("BTSPP%sPREIMAGE", WalletManager.randomPrivateKeyWIF()).toUpperCase()
    }

    /**
     *  复制原像
     */
    private fun onCopyButtonClicked() {
        val preimage = _tv_preimage_or_hash.text.toString()
        if (Utils.copyToClipboard(this, preimage)) {
            showToast(String.format(R.string.kVcHtlcTipsPreimageCopied.xmlstring(this), preimage))
        }
    }

    /**
     *  粘贴哈希
     */
    private fun onPasteButtonClicked() {
        val hashcode = Utils.readFromClipboard(this)
        if (Utils.isValidHexString(hashcode)) {
            _tv_preimage_or_hash.setText(hashcode)
        }
    }

    private fun initDefaultStatus() {
        //  初始化原像和哈希模式控件默认状态
        if (_mode == EHtlcDeployMode.EDM_PREIMAGE.value) {
            //  from 原像
            layout_hashcode.visibility = View.GONE
            layout_preimage_length.visibility = View.GONE
            switch_advance_setting_of_create_htlc_contract.setOnCheckedChangeListener { _, isChecked: Boolean ->
                layout_hashtype_and_expiry_group.visibility = if (isChecked) View.VISIBLE else View.GONE
            }
            //  默认原像
            _tv_preimage_or_hash.text = SpannableStringBuilder(_randomSecurePreimage())
        } else {
            //  from 原像哈希
            layout_preimage.visibility = View.GONE
            layout_moresetting.visibility = View.GONE
            layout_hashtype_and_expiry_group.visibility = View.VISIBLE
        }

        //  ※ 锁定：根据对方合约创建
        if (_lock_field) {
            //  初始化【锁定】部分默认值
            val hash_lock = _ref_htlc!!.getJSONObject("conditions").getJSONObject("hash_lock")
            _currPreimageLength = hash_lock.getInt("preimage_size")
            val preimage_hash = hash_lock.getJSONArray("preimage_hash")
            assert(preimage_hash.length() == 2)
            val lock_hashtype = preimage_hash.getInt(0)
            _currHashType = null
            for (item in _const_hashtype_list!!.forin<JSONObject>()) {
                val hash_type = item!!
                if (hash_type.getInt("value") == lock_hashtype) {
                    _currHashType = hash_type
                    break
                }
            }
            assert(_currHashType != null)

            //  复制粘贴按钮
            tv_copy_preimage.visibility = View.GONE
            tv_paste_preimage_value.visibility = View.GONE

            //  原像hash ui 默认值 和 不可编辑
            _tv_preimage_or_hash.text = SpannableStringBuilder(preimage_hash.last<String>()!!.toUpperCase())
            _tv_preimage_or_hash.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            _tv_preimage_or_hash.ellipsize = TextUtils.TruncateAt.valueOf("END")
            _tv_preimage_or_hash.isEnabled = false
            _tv_preimage_or_hash.setFocusable(false)
            _tv_preimage_or_hash.keyListener = null

            lbl_hashcode.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tv_preimage_length.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            lbl_preimage_length.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tv_hashtype.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            lbl_hashtype.setTextColor(resources.getColor(R.color.theme01_textColorGray))
            tailer_arrow_hashtype.visibility = View.GONE
            tailer_arrow_preimage_length.visibility = View.GONE

            val tv_to = findViewById<TextView>(R.id.txt_value_to_name)
            tv_to.text = _ref_to!!.getString("name")
            tv_to.setTextColor(resources.getColor(R.color.theme01_buyColor))

            // 设置提交参数 to
            _transfer_args!!.put("to", _ref_to)
        } else {
            //  复制 or 粘贴按钮事件
            if (_mode == EHtlcDeployMode.EDM_PREIMAGE.value) {
                tv_copy_preimage.setOnClickListener { onCopyButtonClicked() }
            } else {
                tv_paste_preimage_value.setOnClickListener { onPasteButtonClicked() }
            }

            //  原像长度
            layout_preimage_length.setOnClickListener {
                var defaultIndex = 0
                val list = JSONArray()
                for (i in 1..256) {
                    if (i == _currPreimageLength) {
                        defaultIndex = list.length()
                    }
                    list.put(JSONObject().apply {
                        put("name", i.toString())
                        put("value", i)
                    })
                }
                ViewDialogNumberPicker(this, R.string.kVcHtlcPlaceholderInputPreimageLength.xmlstring(this), list, "name", defaultIndex) { _index: Int, txt: String ->
                    tv_preimage_length.text = txt
                    _currPreimageLength = list.getJSONObject(_index).getInt("value")
                }.show()
            }

            //  哈希算法
            layout_hashtype.setOnClickListener {
                var defaultIndex = 0
                val currValue = _currHashType!!.getInt("value")
                var idx = 0
                for (item in _const_hashtype_list!!.forin<JSONObject>()) {
                    if (item!!.getInt("value") == currValue) {
                        defaultIndex = idx
                        break
                    }
                    ++idx
                }
                ViewDialogNumberPicker(this, R.string.kVcHtlcPlaceholderInputHashType.xmlstring(this), _const_hashtype_list!!, "name", defaultIndex) { _index: Int, txt: String ->
                    tv_hashtype.text = txt
                    _currHashType = _const_hashtype_list!!.getJSONObject(_index)
                }.show()
            }
        }

        //  有效期
        layout_expiry.setOnClickListener {
            var defaultIndex = 0
            val currValue = _currExpire!!.getInt("value")
            var idx = 0
            for (item in _const_expire_list!!.forin<JSONObject>()) {
                if (item!!.getInt("value") == currValue) {
                    defaultIndex = idx
                    break
                }
                ++idx
            }
            ViewDialogNumberPicker(this, R.string.kVcHtlcPlaceholderInputExpire.xmlstring(this), _const_expire_list!!, "name", defaultIndex) { _index: Int, txt: String ->
                tv_expiry.text = txt
                _currExpire = _const_expire_list!!.getJSONObject(_index)
            }.show()
        }

        //  默认值
        tv_hashtype.text = _currHashType!!.getString("name")
        tv_expiry.text = _currExpire!!.getString("name")
        tv_preimage_length.text = _currPreimageLength.toString()

        //  创建按钮
        btn_create_htlc.setOnClickListener { gotoCreateHTLC() }
    }

    /**
     *  (private) 根据当前哈希算法获取对应的哈希值字节数。
     */
    private fun _calcHashValueByteSize(): Int {
        return when (_currHashType!!.getInt("value")) {
            EBitsharesHtlcHashType.EBHHT_RMD160.value -> 20   //  160 bits
            EBitsharesHtlcHashType.EBHHT_SHA1.value -> 20     //  160 bits
            EBitsharesHtlcHashType.EBHHT_SHA256.value -> 32   //  256 bits
            else -> 0
        }
    }

    /**
     *  (private) 根据当前哈希算法计算原像哈希值。
     */
    private fun _calcPreimageHashCode(preimage: ByteArray): ByteArray? {
        return when (_currHashType!!.getInt("value")) {
            EBitsharesHtlcHashType.EBHHT_RMD160.value ->
                rmd160(preimage)
            EBitsharesHtlcHashType.EBHHT_SHA1.value ->
                sha1(preimage)
            EBitsharesHtlcHashType.EBHHT_SHA256.value ->
                sha256(preimage)
            else -> null
        }
    }

    private fun gotoCreateHTLC() {
        //  === 转账基本参数有效性检测 ===
        //  TODO:fowallet 不足的时候否直接提示显示？？？
        if (!_fee_item!!.getBoolean("sufficient")) {
            showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }
        val from = _transfer_args!!.getJSONObject("from")
        val asset = _transfer_args!!.getJSONObject("asset")
        val to = _transfer_args!!.optJSONObject("to")
        if (to == null) {
            showToast(R.string.kVcTransferSubmitTipSelectTo.xmlstring(this))
            return
        }
        if (from.getString("id") == to.getString("id")) {
            showToast(R.string.kVcTransferSubmitTipFromToIsSame.xmlstring(this))
            return
        }

        //  TODO:fowallet to在黑名单中 风险提示。
        val str_amount = _tv_amount.text.toString()
        if (str_amount == "") {
            showToast(R.string.kVcTransferSubmitTipPleaseInputAmount.xmlstring(this))
            return
        }

        val n_amount = Utils.auxGetStringDecimalNumberValue(str_amount).toDouble()
        //  <= 0 判断
        if (n_amount <= 0) {
            showToast(R.string.kVcTransferSubmitTipPleaseInputAmount.xmlstring(this))
            return
        }

        if (_n_available < n_amount) {
            showToast(resources.getString(R.string.kVcTransferSubmitTipAmountNotEnough))
            return
        }

        //  提取有效期
        val claim_period_seconds = _currExpire!!.getInt("value")
        if (_lock_field) {
            val now_ts = Utils.now_ts()
            if (now_ts + claim_period_seconds > _htlc_a_expiration - _htlc_b_reserved_time) {
                showToast(R.string.kVcHtlcTipsExpireIsTooShort.xmlstring(this))
                return
            }
        }

        //  === 风险提示 ===
        val preimage_hash: ByteArray?
        val preimage_length: Int
        val message: String
        var title = resources.getString(R.string.kWarmTips)
        if (_mode == EHtlcDeployMode.EDM_PREIMAGE.value) {
            val preimage = _tv_preimage_or_hash.text.toString().trim()
            if (!Utils.isValidHTCLPreimageFormat(preimage)) {
                showToast(R.string.kVcHtlcTipsPreimageForm.xmlstring(this))
                return
            }
            val preimage_data = preimage.utf8String()
            preimage_hash = _calcPreimageHashCode(preimage_data)
            preimage_length = preimage_data.size
            message = R.string.kVcHtlcMessageCreateFromPreimage.xmlstring(this)
        } else {
            val hashvalue = _tv_preimage_or_hash.text.toString().trim()
            if (hashvalue == "") {
                showToast(R.string.kVcHtlcTipsInputPreimageHash.xmlstring(this))
                return
            }
            val hashvalue_bytesize = _calcHashValueByteSize()
            if (hashvalue.length != hashvalue_bytesize * 2) {
                showToast(R.string.kVcHtlcTipsInputValidPreimageHash.xmlstring(this))
                return
            }
            if (!Utils.isValidHexString(hashvalue)) {
                showToast(R.string.kVcHtlcTipsInputValidPreimageHash.xmlstring(this))
                return
            }
            preimage_hash = hashvalue.hexDecode()
            preimage_length = _currPreimageLength
            if (_have_preimage) {
                message = R.string.kVcHtlcMessageCreateFromHashHavePreimage.xmlstring(this)
            } else {
                title = R.string.kVcHtlcMessageTipsTitle.xmlstring(this)
                message = if (_lock_field) {
                    R.string.kVcHtlcMessageCreateFromHtlcObject.xmlstring(this)
                } else {
                    R.string.kVcHtlcMessageCreateFromHashNoPreimage.xmlstring(this)
                }
            }
        }

        UtilsAlert.showMessageConfirm(this, title, message).then {
            if (it != null && it as Boolean) {
                //  --- 参数大部分检测合法 执行请求 ---
                guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        _gotoCreateHTLCCore(from, to, asset, n_amount, preimage_hash!!, preimage_length, _currHashType!!.getInt("value"), claim_period_seconds)
                    }
                }
            }
            return@then null
        }
    }

    /**
     *  (private) 创建合约核心。
     */
    private fun _gotoCreateHTLCCore(from: JSONObject, to: JSONObject, asset: JSONObject, amount: Double, preimage_hash: ByteArray, preimage_length: Int, hashtype: Int, claim_period_seconds: Int) {
        val n_amount_pow = amount * 10.0.pow(asset.getInt("precision"))
        val fee_asset_id = _fee_item!!.getString("fee_asset_id")

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", fee_asset_id)
            })
            put("from", from.getString("id"))
            put("to", to.getString("id"))
            put("amount", JSONObject().apply {
                put("amount", n_amount_pow.toLong())
                put("asset_id", asset.getString("id"))
            })
            put("preimage_hash", JSONArray().apply {
                put(hashtype)
                put(preimage_hash)
            })
            put("preimage_size", preimage_length)
            put("claim_period_seconds", claim_period_seconds)
        }
        val opaccount = _full_account_data!!.getJSONObject("account")
        val opaccount_id = opaccount.getString("id")

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_htlc_create, false, false, op, opaccount) { isProposal: Boolean, proposal_create_args: JSONObject? ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().htlcCreate(op).then { transaction_confirmation ->
                val new_htlc_id = OrgUtils.extractNewObjectID(transaction_confirmation as? JSONArray)
                ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(opaccount_id).then {
                    mask.dismiss()
                    val full_data = it as JSONObject
                    _refreshUI_onSendDone(full_data)
                    showToast(R.string.kVcHtlcSubmitTipsFullOK.xmlstring(this))
                    //  [统计]
                    btsppLogCustom("txHtlcCreateFullOK", jsonObjectfromKVS("from", opaccount_id, "htlc_id", new_htlc_id
                            ?: ""))
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(R.string.kVcHtlcSubmitTipsOK.xmlstring(this))
                    //  [统计]
                    btsppLogCustom("txHtlcCreateOK", jsonObjectfromKVS("from", opaccount_id, "htlc_id", new_htlc_id
                            ?: ""))
                }
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txHtlcCreateFailed", jsonObjectfromKVS("from", opaccount_id))
            }
        }
    }

    // 以下内容从转账界面复制
    /**
     * (private) 转账数量发生变化。
     */
    private fun onAmountChanged(str_amount: String) {
        val asset = _transfer_args!!.getJSONObject("asset")
        //  无效输入
        val symbol = asset.getString("symbol")
        val tf = findViewById<TextView>(R.id.txt_value_avaiable)
        if (str_amount == "") {
            tf.text = "${_s_available}${symbol}"
            tf.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            return
        }
        val amount = Utils.auxGetStringDecimalNumberValue(str_amount).toDouble()
        if (amount > _n_available) {
            tf.text = "${_s_available}${symbol}(${resources.getString(R.string.kVcTransferSubmitTipAmountNotEnough)})"
            tf.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            tf.text = "${_s_available}${symbol}"
            tf.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
    }

    // Todo REMARK: 这个方法对比转账 仅仅手续费 fee_item 不同, 是否封装到 ExtersionActivity
    private fun genTransferDefaultArgs(full_account_data: JSONObject?) {
        //  保存当前帐号信息
        if (full_account_data != null) {
            _full_account_data = full_account_data
        }

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        //  初始化余额Hash(原来的是Array)
        _balances_hash = JSONObject()
        for (balance_object in _full_account_data!!.getJSONArray("balances")) {
            val asset_type = balance_object!!.getString("asset_type")
            val balance = balance_object.getString("balance")
            _balances_hash!!.put(asset_type, jsonObjectfromKVS("asset_id", asset_type, "amount", balance))
        }
        //  初始化默认值余额（从资产界面点击转账过来，该资产余额可能为0。）
        if (_default_asset != null) {
            val def_id = _default_asset!!.getString("id")
            val def_balance_item = _balances_hash!!.optJSONObject(def_id)
            if (def_balance_item == null) {
                _balances_hash!!.put(def_id, jsonObjectfromKVS("asset_id", def_id, "amount", 0))
            }
        }
        val balances_list = _balances_hash!!.values()
        //  计算手续费对象（更新手续费资产的可用余额，即减去手续费需要的amount）
        _fee_item = chainMgr.estimateFeeObject(EBitsharesOperations.ebo_htlc_create.value, balances_list)
        val fee_asset_id = _fee_item!!.getString("fee_asset_id")
        val fee_balance = _balances_hash!!.optJSONObject(fee_asset_id)
        if (fee_balance != null) {
            val fee = _fee_item!!.getString("amount").toDouble()
            val old = fee_balance.getString("amount").toDouble()
            val new_balance = JSONObject()
            new_balance.put("asset_id", fee_asset_id)
            if (old >= fee) {
                new_balance.put("amount", (old - fee).toLong())
            } else {
                new_balance.put("amount", 0)
            }
            _balances_hash!!.put(fee_asset_id, new_balance)
        }

        //  获取余额不为0的资产列表
        var none_zero_balances = JSONArray()
        for (balance_item in balances_list) {
            if (balance_item!!.getString("amount").toLong() != 0L) {
                none_zero_balances.put(balance_item)
            }
        }
        //  如果资产列表为空，则添加默认值。{BTS:0}
        if (none_zero_balances.length() <= 0) {
            val balance_object = jsonObjectfromKVS("asset_id", chainMgr.grapheneCoreAssetID, "amount", 0)
            none_zero_balances = jsonArrayfrom(balance_object)
            _balances_hash!!.put(balance_object.getString("asset_id"), balance_object)
        }

        //  获取资产详细信息列表
        _asset_list = JSONArray()
        for (balance_object in none_zero_balances) {
            _asset_list!!.put(chainMgr.getChainObjectByID(balance_object!!.getString("asset_id")))
        }
        assert(_asset_list!!.length() > 0)

        //  初始化转账默认参数：from、fee_asset
        var last_asset: JSONObject? = null
        if (_transfer_args != null) {
            //  REMARK：第二次调用该方法时才存在 last_asset，上次转账的资产。
            last_asset = _transfer_args!!.getJSONObject("asset")
        }
        _transfer_args = JSONObject()
        val account_info = _full_account_data!!.getJSONObject("account")
        _transfer_args!!.put("from", jsonObjectfromKVS("id", account_info.getString("id"), "name", account_info.getString("name")))
        if (_default_asset == null) {
            //  TODO:fowallet 默认值，优先选择CNY、没CNY选择BTS。TODO：USD呢？？
            for (asset in _asset_list!!) {
                if (asset!!.getString("id") == "1.3.113") {
                    _default_asset = asset
                    break
                }
            }
            if (_default_asset == null) {
                for (asset in _asset_list!!) {
                    if (asset!!.getString("id") == "1.3.0") {
                        _default_asset = asset
                        break
                    }
                }
            }
            if (_default_asset == null) {
                _default_asset = _asset_list!![0] as JSONObject
            }
        }
        val fee_asset = chainMgr.getChainObjectByID(_fee_item!!.getString("fee_asset_id"))
        _transfer_args!!.put("fee_asset", fee_asset)

        //  设置当前资产
        setAsset(last_asset ?: _default_asset!!)
    }

    private fun refreshUI() {
        findViewById<TextView>(R.id.txt_value_from_name).text = _transfer_args!!.getJSONObject("from").getString("name")
        val to = _transfer_args!!.optJSONObject("to")
        val to_txt = findViewById<TextView>(R.id.txt_value_to_name)
        if (to != null) {
            to_txt.text = to.getString("name")
            to_txt.setTextColor(resources.getColor(R.color.theme01_buyColor))
        } else {
            to_txt.text = resources.getString(R.string.kVcTransferTipSelectToAccount)
            to_txt.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
        findViewById<TextView>(R.id.txt_value_asset_name).text = _transfer_args!!.getJSONObject("asset").getString("symbol")
    }

    private fun _refreshUI_onSendDone(new_full_account_data: JSONObject) {
        _tf_amount_watcher?.clear()
//        findViewById<EditText>(R.id.tf_memo).text.clear()
        genTransferDefaultArgs(new_full_account_data)
        refreshUI()
    }

    /**
     * 设置待转账资产：更新可用余额等信息
     */
    private fun setAsset(new_asset: JSONObject) {
        _transfer_args!!.put("asset", new_asset)
        val new_asset_id = new_asset.getString("id")
        val balance = _balances_hash!!.getJSONObject(new_asset_id).getString("amount")

        val precision = new_asset.getInt("precision")
        _n_available = balance.toDouble() / 10.0.pow(precision)
        _s_available = OrgUtils.formatAssetString(balance.toString(), precision, has_comma = false)

        //  更新UI - 可用余额
        val symbol = new_asset.getString("symbol")
        findViewById<TextView>(R.id.txt_value_avaiable).text = "${_s_available}${symbol}"

        //  切换资产清除当前输入的数量
        _tf_amount_watcher?.set_precision(precision)?.clear()
    }
}
