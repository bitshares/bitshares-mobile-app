package com.btsplusplus.fowallet

import android.content.Context
import android.graphics.PorterDuff
import android.os.Bundle
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.*
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.btsplusplus.fowallet.utils.ModelUtils
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.max

class ActivityIndexCollateral : BtsppActivity() {

    private var _debtPair: TradingPair? = null
    private var _nMaintenanceCollateralRatio: BigDecimal? = null
    private var _nCurrMortgageRate: BigDecimal? = null
    private var _nCurrFeedPrice: BigDecimal? = null                 //  当前喂价（如果查询数据失败，则可能为 nil。）

    private var _currAssetIsPredictionmarket = false                //  当前借款资产是否是预测市场（默认NO）
    private var _bLockDebt = true                                   //  是否锁定负债字段。

    private var _callOrderHash: JSONObject? = null
    private var _collateralBalance: JSONObject? = null
    private var _fee_item: JSONObject? = null

    private var _tf_debt_watcher: UtilsDigitTextWatcher? = null
    private var _tf_coll_watcher: UtilsDigitTextWatcher? = null

    lateinit var _curve_slider_ratio: UtilsCurveSlider
    lateinit var _curve_slider_target_ratio: UtilsCurveSlider

    /**
     * 重载 - 返回键按下
     */
    override fun onBackPressed() {
        goHome()
    }

    override fun onResume() {
        super.onResume()
        //  刷新UI
        _refreshUI(_isUserLogined(), null)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_index_collateral, navigationBarColor = R.color.theme01_tabBarColor)

        //  初始化数据
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val parameters = chainMgr.getDefaultParameters()
        _nMaintenanceCollateralRatio = BigDecimal.valueOf(parameters.getDouble("mcr_default"))
        _nCurrMortgageRate = BigDecimal.valueOf(parameters.getDouble("collateral_ratio_default"))
        //  初始化默认操作债仓
        val debt_asset_list = chainMgr.getMainSmartAssetList()
        assert(debt_asset_list.length() > 0)
        val currDebtAsset = chainMgr.getAssetBySymbol(debt_asset_list.getString(0))
        val collateralAsset = chainMgr.getChainObjectByID(BTS_NETWORK_CORE_ASSET_ID)
        _debtPair = TradingPair().initWithBaseAsset(currDebtAsset, collateralAsset)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 设置底部导航栏样式
        setBottomNavigationStyle(1)

        //  刷新数据
        _refreshUserData()

        //  帮助按钮
        findViewById<ImageView>(R.id.tip_link_curr_feed).setOnClickListener {
            VcUtils.gotoQaView(this, "qa_feed_settlement", resources.getString(R.string.kDebtTipTitleFeedAndCallPrice))
        }
        findViewById<ImageView>(R.id.tip_link_ratio).setOnClickListener {
            VcUtils.gotoQaView(this, "qa_ratio", resources.getString(R.string.kDebtTipTitleWhatIsRatio))
        }
        findViewById<ImageView>(R.id.tip_link_target_ratio).setOnClickListener {
            VcUtils.gotoQaView(this, "qa_target_ratio", resources.getString(R.string.kDebtTipTitleWhatIsTargetRatio))
        }

        //  监听事件
        findViewById<TextView>(R.id.btn_reset_all).setOnClickListener { onResetCLicked() }
        findViewById<TextView>(R.id.btn_select_debt_asset).setOnClickListener { onSelectDebtAssetClicked() }
        _curve_slider_ratio = UtilsCurveSlider(findViewById<SeekBar>(R.id.slider_ratio)).init_with_range(400, 0.0, 6.0)
        _curve_slider_target_ratio = UtilsCurveSlider(findViewById<SeekBar>(R.id.slider_target_ratio)).init_with_range(400, 0.0, 4.0)
        _curve_slider_ratio.on_value_changed { onSliderRatioValueChanged(it) }
        _curve_slider_target_ratio.on_value_changed { onSliderTargetRatioValueChanged(it) }
        //  初始化滑动条颜色和图标
        findViewById<SeekBar>(R.id.slider_ratio).let { seek ->
            seek.progressDrawable.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight), PorterDuff.Mode.SRC_ATOP)
        }
        findViewById<SeekBar>(R.id.slider_target_ratio).let { seek ->
            seek.progressDrawable.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight), PorterDuff.Mode.SRC_ATOP)
        }

        var tf = findViewById<EditText>(R.id.tf_debt)
        _tf_debt_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_debtPair!!._basePrecision)
        tf.addTextChangedListener(_tf_debt_watcher!!)
        _tf_debt_watcher!!.on_value_changed(::onDebtAmountChanged)

        tf = findViewById<EditText>(R.id.tf_coll)
        _tf_coll_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_debtPair!!._quotePrecision)
        tf.addTextChangedListener(_tf_coll_watcher!!)
        _tf_coll_watcher!!.on_value_changed(::onCollAmountChanged)
        //  REMARK：重写数量输入框的touch事件，在没有输入借款金额的前提下，不弹出键盘（直接消耗掉事件)。
        tf.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_DOWN) {
                if (!_currAssetIsPredictionmarket) {
                    val n_debt = Utils.auxGetStringDecimalNumberValue(_tf_debt_watcher!!.get_tf_string())
                    if (n_debt <= BigDecimal.ZERO) {
                        showToast(resources.getString(R.string.kDebtTipPleaseInputDebtValueFirst))
                        endInput()
                        return@setOnTouchListener true
                    }
                }
            }
            return@setOnTouchListener false
        }

        //  最大还款、全部抵押
        findViewById<TextView>(R.id.btn_pay_max).setOnClickListener { onDebtTailerButtonClicked() }
        findViewById<TextView>(R.id.btn_debt_max).setOnClickListener { onCollTailerButtonClicked() }

        //  登录、调整债仓
        findViewById<Button>(R.id.btn_submit_core).setOnClickListener { onSubmitCoreClicked() }
    }

    /**
     * 事件 - 提交按钮（登录/调整债仓）
     */
    private fun onSubmitCoreClicked() {
        if (_isUserLogined()) {
            _onDebtActionClicked()
        } else {
            //  REMARK：这里不用 GuardWalletExist，仅跳转登录界面，登录后停留在交易界面，而不是登录后执行买卖操作。
            //  如果当前按钮显示的是买卖，那么应该继续处理，但这里按钮显示的就是登录，那么仅执行登录处理。
            goTo(ActivityLogin::class.java, true)
        }
    }

    /**
     * 执行调整债仓操作
     */
    private fun _onDebtActionClicked() {
        val bitasset_data = ChainObjectManager.sharedChainObjectManager().getChainObjectByIDSafe(_debtPair!!._baseAsset.getString("bitasset_data_id"))
        if (bitasset_data == null) {
            showToast(resources.getString(R.string.kDebtTipNetworkErrorPleaseRefresh))
            return
        }
        if (ModelUtils.assetHasGlobalSettle(bitasset_data)) {
            showToast(resources.getString(R.string.kDebtTipAssetHasGlobalSettled))
            return
        }
        //  非预测市场并且没有喂价
        if (!_currAssetIsPredictionmarket && _nCurrFeedPrice == null) {
            showToast(resources.getString(R.string.kDebtTipAssetNoValidFeedData))
            return
        }

        //  --- 检查参数有效性 ---
        val zero = BigDecimal.ZERO

        val n_new_debt = Utils.auxGetStringDecimalNumberValue(_tf_debt_watcher!!.get_tf_string())
        val n_new_coll = Utils.auxGetStringDecimalNumberValue(_tf_coll_watcher!!.get_tf_string())

        var n_old_debt = zero
        var n_old_coll = zero

        val debt_callorder = _getCallOrder()
        if (debt_callorder != null) {
            n_old_debt = bigDecimalfromAmount(debt_callorder.getString("debt"), _debtPair!!._basePrecision)
            n_old_coll = bigDecimalfromAmount(debt_callorder.getString("collateral"), _debtPair!!._quotePrecision)
        }

        val n_delta_coll = n_new_coll.subtract(n_old_coll)
        val n_delta_debt = n_new_debt.subtract(n_old_debt)

        //  参数无效（两个都为0，没有变化。）
        if (n_delta_coll.compareTo(zero) == 0 && n_delta_debt.compareTo(zero) == 0) {
            showToast(resources.getString(R.string.kDebtTipValueAndAmountNotChange))
            return
        }

        //  抵押物不足
        val n_balance_coll = bigDecimalfromAmount(_collateralBalance!!.getString("amount"), _debtPair!!._quotePrecision)
        val n_rest_coll = n_balance_coll.subtract(n_delta_coll)
        if (n_rest_coll < zero) {
            showToast(resources.getString(R.string.kDebtTipCollNotEnough))
            return
        }

        //  可用余额不足
        val n_balance_debt = _getDebtBalance()
        val n_rest_debt = n_balance_debt.add(n_delta_debt)
        if (n_rest_debt < zero) {
            showToast(String.format(resources.getString(R.string.kDebtTipAvailableNotEnough), _debtPair!!._baseAsset.getString("symbol")))
            return
        }

        //  非预测市场：各种情况下的抵押率判断
        if (!_currAssetIsPredictionmarket) {
            if (n_old_debt > zero) {
                if (n_new_debt > zero) {
                    //  更新债仓：新负债和旧负债都存在。
                    val n_new_ratio = _calcCollRate(n_new_debt, n_new_coll, false)
                    val n_old_ratio = _calcCollRate(n_old_debt, n_old_coll, false)
                    if (n_old_ratio < _nMaintenanceCollateralRatio!!) {
                        //  已经处于爆仓中
                        //  【BSIP30】在爆仓状态可以上调抵押率，不再强制要求必须上调到多少，但抵押率不足最低要求时不能增加借款
                        if (n_new_ratio < _nMaintenanceCollateralRatio!! && n_delta_debt > zero) {
                            showToast(String.format(resources.getString(R.string.kDebtTipRatioTooLow), _nMaintenanceCollateralRatio!!.toPlainString()))
                            return
                        }
                        if (n_new_ratio <= n_old_ratio) {
                            showToast(resources.getString(R.string.kDebtTipCannotAdjustMoreLowerRatio))
                            return
                        }
                    } else {
                        //  尚未爆仓
                        if (n_new_ratio < _nMaintenanceCollateralRatio!!) {
                            showToast(String.format(resources.getString(R.string.kDebtTipCollRatioCannotLessThanMCR), _nMaintenanceCollateralRatio!!.toPlainString()))
                            return
                        }
                    }
                } else {
                    //  关闭债仓：旧负债存在，新负债不存在。
                }
            } else {
                //  新开债仓：没有旧的负债
                if (n_new_debt <= zero) {
                    showToast(resources.getString(R.string.kDebtTipPleaseInputDebtValueFirst))
                    return
                }
                val n_new_ratio = _calcCollRate(n_new_debt, n_new_coll, false)
                if (n_new_ratio < _nMaintenanceCollateralRatio!!) {
                    showToast(String.format(resources.getString(R.string.kDebtTipCollRatioCannotLessThanMCR), _nMaintenanceCollateralRatio!!.toPlainString()))
                    return
                }
            }
        }

        if (!_fee_item!!.getBoolean("sufficient")) {
            showToast(resources.getString(R.string.kTipsTxFeeNotEnough))
            return
        }

        //  获取目标抵押率（小于MCR时取消设置）
        var n_target_ratio: BigDecimal? = BigDecimal(String.format("%.2f", _curve_slider_target_ratio.get_value().toFloat()).fixComma())
        if (n_target_ratio!!.compareTo(_nMaintenanceCollateralRatio) < 0) {
            n_target_ratio = null
        }

        //  --- 检测合法 执行请求 ---
        guardWalletUnlocked(false) { unlocked ->
            if (unlocked) {
                _processDebtActionCore(n_delta_coll, n_delta_debt, n_target_ratio)
            }
        }
    }

    private fun _processDebtActionCore(n_delta_coll: BigDecimal, n_delta_debt: BigDecimal, n_target_ratio: BigDecimal?) {
        val opaccount = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val funding_account = opaccount.getString("id")

        //  构造OP
        val coll = n_delta_coll.scaleByPowerOfTen(_debtPair!!._quotePrecision).toPriceAmountString(_debtPair!!._quotePrecision)
        val debt = n_delta_debt.scaleByPowerOfTen(_debtPair!!._basePrecision).toPriceAmountString(_debtPair!!._basePrecision)
        var target_ratio = 0L
        if (n_target_ratio != null) {
            target_ratio = n_target_ratio.scaleByPowerOfTen(3).toPriceAmountString(3).toLong()
        }
        val op = jsonObjectfromKVS("fee", jsonObjectfromKVS("amount", 0, "asset_id", _fee_item!!.getString("fee_asset_id")),
                "funding_account", funding_account,
                "delta_collateral", jsonObjectfromKVS("amount", coll, "asset_id", _debtPair!!._quoteId),
                "delta_debt", jsonObjectfromKVS("amount", debt, "asset_id", _debtPair!!._baseId),
                "extensions", if (n_target_ratio != null) {
            jsonObjectfromKVS("target_collateral_ratio", target_ratio)
        } else {
            JSONObject()
        }
        )

        //  确保有权限发起普通交易，否则作为提案交易处理。
        GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_call_order_update, false, false,
                op, opaccount) { isProposal, _ ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().callOrderUpdate(op).then {
                ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(funding_account).then {
                    mask.dismiss()
                    //  刷新UI
                    _refreshUI(true, null)
                    showToast(resources.getString(R.string.kDebtTipTxUpdatePositionFullOK))
                    //  [统计]
                    btsppLogCustom("txCallOrderUpdateFullOK", jsonObjectfromKVS("account", funding_account, "debt_asset", _debtPair!!._baseAsset.getString("symbol")))
                    return@then null
                }.catch {
                    mask.dismiss()
                    showToast(resources.getString(R.string.kDebtTipTxUpdatePositionOK))
                    //  [统计]
                    btsppLogCustom("txCallOrderUpdateOK", jsonObjectfromKVS("account", funding_account, "debt_asset", _debtPair!!._baseAsset.getString("symbol")))
                }
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                //  [统计]
                btsppLogCustom("txCallOrderUpdateFailed", jsonObjectfromKVS("account", funding_account, "debt_asset", _debtPair!!._baseAsset.getString("symbol")))
            }
        }
    }

    /**
     *  (private) 事件 - 锁 or 解锁按钮点击
     */
    private fun onLockClicked() {
        setNewLockStatus(!_bLockDebt)
    }

    private fun setNewLockStatus(bLockDebt: Boolean) {
        findViewById<ImageView>(R.id.img_icon_lock_debt).let { icon_lock_debt ->
            findViewById<ImageView>(R.id.img_icon_lock_ratio).let { icon_lock_ratio ->
                if (_currAssetIsPredictionmarket) {
                    //  预测市场不用锁
                    icon_lock_debt.visibility = View.GONE
                    icon_lock_ratio.visibility = View.GONE
                    //  取消事件
                    icon_lock_debt.setOnClickListener(null)
                    icon_lock_ratio.setOnClickListener(null)
                } else {
                    //  保存
                    _bLockDebt = bLockDebt
                    if (_bLockDebt) {
                        icon_lock_debt.visibility = View.VISIBLE
                        icon_lock_debt.setImageDrawable(resources.getDrawable(R.drawable.icon_locked))
                        icon_lock_debt.setColorFilter(resources.getColor(R.color.theme01_textColorNormal))

                        icon_lock_ratio.visibility = View.VISIBLE
                        icon_lock_ratio.setImageDrawable(resources.getDrawable(R.drawable.icon_unlocked))
                        icon_lock_ratio.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))
                    } else {
                        icon_lock_debt.visibility = View.VISIBLE
                        icon_lock_debt.setImageDrawable(resources.getDrawable(R.drawable.icon_unlocked))
                        icon_lock_debt.setColorFilter(resources.getColor(R.color.theme01_textColorHighlight))

                        icon_lock_ratio.visibility = View.VISIBLE
                        icon_lock_ratio.setImageDrawable(resources.getDrawable(R.drawable.icon_locked))
                        icon_lock_ratio.setColorFilter(resources.getColor(R.color.theme01_textColorNormal))
                    }
                    //  绑定事件
                    if (!icon_lock_debt.hasOnClickListeners()) {
                        icon_lock_debt.setOnClickListener { onLockClicked() }
                    }
                    if (!icon_lock_ratio.hasOnClickListeners()) {
                        icon_lock_ratio.setOnClickListener { onLockClicked() }
                    }
                }
                return@let
            }
            return@let
        }
    }

    /**
     *  关闭键盘
     */
    private fun endInput() {
        _tf_debt_watcher?.endInput()
        _tf_coll_watcher?.endInput()
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.let {
            it.hideSoftInputFromWindow(findViewById<EditText>(R.id.tf_coll).windowToken, 0)
            it.hideSoftInputFromWindow(findViewById<EditText>(R.id.tf_debt).windowToken, 0)
            return@let
        }
    }

    /**
     * 事件 - 还款按钮点击
     */
    private fun onDebtTailerButtonClicked() {
        //  关闭键盘
        endInput()

        //  计算执行最大还款之后，剩余的负债信息。
        var new_debt: BigDecimal = BigDecimal.ZERO
        val debt_callorder = _getCallOrder()
        if (debt_callorder != null) {
            val n_curr_debt = bigDecimalfromAmount(debt_callorder.getString("debt"), _debtPair!!._basePrecision)
            val balance = _getDebtBalance()
            if (balance.compareTo(n_curr_debt) < 0) {
                new_debt = n_curr_debt.subtract(balance)
            }
        }

        //  赋值
        var new_str = ""
        if (new_debt.compareTo(BigDecimal.ZERO) != 0) {
            new_str = new_debt.toPlainString()
        }
        _tf_debt_watcher?.set_new_text(new_str)
        onDebtAmountChanged(new_str)
    }

    /**
     * 事件 - 全部按钮点击
     */
    private fun onCollTailerButtonClicked() {
        //  关闭键盘
        endInput()

        if (!_currAssetIsPredictionmarket) {
            if (_bLockDebt) {
                val n_debt = Utils.auxGetStringDecimalNumberValue(_tf_debt_watcher!!.get_tf_string())
                if (n_debt <= BigDecimal.ZERO) {
                    showToast(resources.getString(R.string.kDebtTipPleaseInputDebtValueFirst))
                    return
                }
            } else {
                if (_nCurrMortgageRate == null || _nCurrMortgageRate!! <= BigDecimal.ZERO) {
                    showToast(resources.getString(R.string.kDebtTipPleaseAdjustRatioFirst))
                    return
                }
            }
        }
        val n_total = _getTotalCollateralNumber()
        var new_str = ""
        if (n_total.compareTo(BigDecimal.ZERO) != 0) {
            new_str = n_total.toPlainString()
        }
        _tf_coll_watcher?.set_new_text(new_str)
        onCollAmountChangedCore(new_str, if (_currAssetIsPredictionmarket) false else _bLockDebt)
    }

    /**
     * (private) 输入框值变化 - 借款数量
     */
    private fun onDebtAmountChanged(str: String) {
        if (!_currAssetIsPredictionmarket && _nCurrFeedPrice == null) {
            return
        }
        val n_debt = Utils.auxGetStringDecimalNumberValue(str)
        val n_coll = _calcCollNumber(n_debt, _nCurrMortgageRate!!)
        _refreshUI_debt_available(n_debt, false)
        _refreshUI_coll_available(n_coll, true)
        _refreshUI_SettlementTriggerPrice()
    }

    /**
     * (private) 输入框值变化 - 抵押物数量
     */
    private fun onCollAmountChanged(str: String) {
        onCollAmountChangedCore(str, if (_currAssetIsPredictionmarket) false else _bLockDebt)
    }

    /**
     *  (private) 输入框值变化 - 抵押物数量 核心逻辑
     */
    private fun onCollAmountChangedCore(str: String, affect_mortgage_rate_changed: Boolean) {
        if (!_currAssetIsPredictionmarket && _nCurrFeedPrice == null) {
            return
        }
        val n_coll = Utils.auxGetStringDecimalNumberValue(str)
        if (affect_mortgage_rate_changed) {
            //  抵押物变化 - 影响抵押率变化（负债不变）
            //  这里手动输入抵押物or点击全部按钮导致变化，都已经确保了debt不能为0。
            val n_debt = Utils.auxGetStringDecimalNumberValue(_tf_debt_watcher!!.get_tf_string())
            if (n_debt <= BigDecimal.ZERO) {
                return
            }
            _nCurrMortgageRate = _calcCollRate(n_debt, n_coll, false)
            _refreshUI_coll_available(n_coll, false)
            _refreshUI_debt_available(n_debt, false)
            _refreshUI_ratio(true)
            _refreshUI_SettlementTriggerPrice()
        } else {
            //  抵押物变化 - 影响债务变化（抵押率不变）
            val n_debt = _calcDebtNumber(n_coll, _nCurrMortgageRate!!)
            _refreshUI_coll_available(n_coll, false)
            _refreshUI_debt_available(n_debt, true)
            _refreshUI_SettlementTriggerPrice()
        }
    }

    /**
     * 滑动条值变化：抵押率
     */
    private fun onSliderRatioValueChanged(value: Double) {
        //  抵押率滑动条拖动
        _nCurrMortgageRate = BigDecimal(String.format("%.2f", value.toFloat()).fixComma())
        _refreshUI_ratio(false)
        if (_nCurrFeedPrice == null) {
            return
        }
        val n_debt = Utils.auxGetStringDecimalNumberValue(_tf_debt_watcher!!.get_tf_string())
        val n_coll = _calcCollNumber(n_debt, _nCurrMortgageRate!!)
        _refreshUI_coll_available(n_coll, true)
        _refreshUI_SettlementTriggerPrice()
    }

    /**
     * 滑动条值变化：目标抵押率
     */
    private fun onSliderTargetRatioValueChanged(value: Double) {
        //  目标抵押率滑动条拖动
        val n = BigDecimal(String.format("%.2f", value.toFloat()).fixComma())
        _refreshUI_target_ratio(n, false)
    }

    /**
     * 选择借贷资产
     */
    private fun onSelectDebtAssetClicked() {
        val self = this

        //  获取配置的默认列表
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val asset_list = JSONArray()
        chainMgr.getMainSmartAssetList().forEach<String> { symbol ->
            asset_list.put(chainMgr.getAssetBySymbol(symbol!!))
        }

        //  添加自定义选项
        asset_list.put(JSONObject().apply {
            put("symbol", self.resources.getString(R.string.kVcAssetMgrCellValueSmartBackingAssetCustom))
            put("is_custom", true)
        })

        //  选择列表
        ViewSelector.show(this, resources.getString(R.string.kDebtTipSelectDebtAsset), asset_list, "symbol") { index: Int, result: String ->
            val select_item = asset_list.getJSONObject(index)
            if (select_item.isTrue("is_custom")) {
                //  自定义搜索借贷资产
                TempManager.sharedTempManager().set_query_account_callback { last_activity, asset_info ->
                    last_activity.goTo(ActivityIndexCollateral::class.java, true, back = true)
                    processSelectNewDebtAsset(asset_info)
                }
                goTo(ActivityAccountQueryBase::class.java, true, args = JSONObject().apply {
                    put("kSearchType", ENetworkSearchType.enstAssetSmart)
                    put("kTitle", self.resources.getString(R.string.kVcTitleSearchAssets))
                })
            } else {
                //  从列表中选择结果
                processSelectNewDebtAsset(select_item)
            }
        }
    }

    private fun processSelectNewDebtAsset(newDebtAsset: JSONObject) {
        //   选择的就是当前资产，直接返回。
        if (newDebtAsset.getString("id") == _debtPair!!._baseAsset.getString("id")) {
            return
        }

        //  更新缓存
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        chainMgr.appendAssetCore(newDebtAsset)

        //  查询喂价、查询背书资产信息
        val p1 = _asyncQueryFeedPrice(newDebtAsset)
        val p2 = chainMgr.queryBackingAsset(newDebtAsset)

        VcUtils.simpleRequest(this, Promise.all(p1, p2)) {
            val data_array = it as JSONArray
            val feed_data = data_array.getJSONObject(0)
            val backing_asset = data_array.getJSONObject(1)
            _debtPair = TradingPair().initWithBaseAsset(newDebtAsset, backing_asset)
            //  切换了资产（更新输入框可输入的精度信息）
            _tf_debt_watcher?.set_precision(_debtPair!!._basePrecision)?.set_new_text("")
            _tf_coll_watcher?.set_precision(_debtPair!!._quotePrecision)?.set_new_text("")
            _refreshUI(_isUserLogined(), feed_data)
        }
    }

    /**
     *  重置 - 借款数量、抵押数量、抵押率、目标抵押率
     */
    private fun onResetCLicked() {
        //  重置 - 锁定状态
        setNewLockStatus(true)

        //  重置 - 借款数量、抵押数量、抵押率、目标抵押率
        val debt_callorder = _getCallOrder()
        if (debt_callorder != null) {
            val n_debt = bigDecimalfromAmount(debt_callorder.getString("debt"), _debtPair!!._basePrecision)
            val n_coll = bigDecimalfromAmount(debt_callorder.getString("collateral"), _debtPair!!._quotePrecision)
            _tf_debt_watcher!!.set_new_text(n_debt.toPriceAmountString())
            _tf_coll_watcher!!.set_new_text(n_coll.toPriceAmountString())
            //  计算抵押率（这里有债仓，debt不为0。）
            if (_nCurrFeedPrice != null) {
                _nCurrMortgageRate = _calcCollRate(n_debt, n_coll, false)
            } else {
                _nCurrMortgageRate = null
            }
            //  目标抵押率
            val target_collateral_ratio = debt_callorder.optString("target_collateral_ratio", "")
            if (target_collateral_ratio != "") {
                val n_target_collateral_ratio = bigDecimalfromAmount(target_collateral_ratio, 3)
                _refreshUI_target_ratio(n_target_collateral_ratio, true)
            } else {
                //  未设置 target_collateral_ratio
                _refreshUI_target_ratio(null, true)
            }
            _refreshUI_coll_available(n_coll, true)
            _refreshUI_debt_available(n_debt, true)
        } else {
            _tf_debt_watcher!!.set_new_text("")
            _tf_coll_watcher!!.set_new_text("")
            //  默认不设置 target_collateral_ratio
            _refreshUI_target_ratio(null, true)
            _refreshUI_coll_available(BigDecimal.ZERO, true)
            _refreshUI_debt_available(BigDecimal.ZERO, true)
            val parameters = ChainObjectManager.sharedChainObjectManager().getDefaultParameters()
            _nCurrMortgageRate = BigDecimal.valueOf(parameters.getDouble("collateral_ratio_default"))
        }
        //  重置 - 你的强平触发价
        _refreshUI_SettlementTriggerPrice()
        //  重置 - 抵押率
        _refreshUI_ratio(true)
    }

    /**
     * (private) 刷新抵押率
     */
    private fun _refreshUI_ratio(reset_slider: Boolean) {
        //  预测市场不显示
        if (_currAssetIsPredictionmarket) {
            return
        }

        assert(_nMaintenanceCollateralRatio != null)
        val label = findViewById<TextView>(R.id.label_txt_curr_ratio)
        label.setTextColor(resources.getColor(_getCollateralRatioColor()))
        if (_nCurrMortgageRate != null) {
            val value = _nCurrMortgageRate!!.toDouble()
            label.text = String.format("%s %.2f", resources.getString(R.string.kVcRankRatio), value.toFloat())
            if (reset_slider) {
                val parameters = ChainObjectManager.sharedChainObjectManager().getDefaultParameters()
                _curve_slider_ratio.set_min(0.0)
                _curve_slider_ratio.set_max(max(value, parameters.getDouble("max_ratio")))
                _curve_slider_ratio.set_value(value)
            }
        } else {
            label.text = "${resources.getString(R.string.kVcRankRatio)} --"
            if (reset_slider) {
                _curve_slider_ratio.set_min(0.0)
                _curve_slider_ratio.set_max(6.0)
                _curve_slider_ratio.set_value(0.0)
            }
        }
    }

    /**
     *  根据质押率获取对应颜色。
     */
    private fun _getCollateralRatioColor(): Int {
        //  0 - mcr     黄色（爆仓中）
        //  mcr - 250   红色（危险） - 卖出颜色
        //  250 - 400   白色（普通）
        //  400+        绿色（安全） - 买入颜色
        if (_nCurrMortgageRate != null) {
            val value = _nCurrMortgageRate!!.toFloat()
            val mcr = _nMaintenanceCollateralRatio!!.toFloat()
            if (value < mcr) {
                return R.color.theme01_callOrderColor
            } else if (value < 2.5f) {
                return R.color.theme01_sellColor
            } else if (value < 4.0f) {
                return R.color.theme01_textColorMain
            } else {
                return R.color.theme01_buyColor
            }
        } else {
            return R.color.theme01_textColorMain
        }
    }

    /**
     * (private) 刷新强平触发价
     */
    private fun _refreshUI_SettlementTriggerPrice() {
        val price_title = resources.getString(R.string.kDebtLableCallPrice)
        val base_symbol = _debtPair!!._baseAsset.getString("symbol")
        val quote_symbol = _debtPair!!._quoteAsset.getString("symbol")
        val suffix = "${base_symbol}/${quote_symbol}"

        val n_debt = Utils.auxGetStringDecimalNumberValue(findViewById<EditText>(R.id.tf_debt).text.toString())
        val n_coll = Utils.auxGetStringDecimalNumberValue(findViewById<EditText>(R.id.tf_coll).text.toString())
        val n_zero = BigDecimal.ZERO

        val label = findViewById<TextView>(R.id.label_txt_trigger_price)
        if (_currAssetIsPredictionmarket || n_debt.compareTo(n_zero) == 0 || n_coll.compareTo(n_zero) == 0) {
            label.text = "${price_title} --${suffix}"
            label.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            //  计算强平触发价 price = debt * 1.75 / coll
            var n = n_debt.multiply(_nMaintenanceCollateralRatio)
            n = n.divide(n_coll, _debtPair!!._basePrecision, BigDecimal.ROUND_UP)
            label.text = "${price_title} ${OrgUtils.formatFloatValue(n.toDouble(), _debtPair!!._basePrecision)}${suffix}"
            label.setTextColor(resources.getColor(_getCollateralRatioColor()))
        }
    }

    /**
     * (private) 刷新UI - 抵押物可用余额
     */
    private fun _refreshUI_coll_available(new_tf_value: BigDecimal, update_textfield: Boolean) {
        if (update_textfield) {
            if (new_tf_value.compareTo(BigDecimal.ZERO) == 0) {
                _tf_coll_watcher?.set_new_text("")
            } else {
                _tf_coll_watcher?.set_new_text(new_tf_value.toString())
            }
        }

        val lbl_available = findViewById<TextView>(R.id.label_txt_coll_available)

        val n_total = _getTotalCollateralNumber()
        val n_available = n_total.subtract(new_tf_value)
        val quote_symbol = _debtPair!!._quoteAsset.getString("symbol")
        lbl_available.text = "${resources.getString(R.string.kDebtLableAvailable)} $n_available ${quote_symbol}"

        if (n_available.compareTo(BigDecimal.ZERO) < 0) {
            lbl_available.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            lbl_available.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        }
    }

    /**
     * (private) 刷新UI - 借贷数量可用余额
     */
    private fun _refreshUI_debt_available(new_tf_value: BigDecimal, update_textfield: Boolean) {
        if (update_textfield) {
            if (new_tf_value.compareTo(BigDecimal.ZERO) == 0) {
                _tf_debt_watcher?.set_new_text("")
            } else {
                _tf_debt_watcher?.set_new_text(new_tf_value.toString())
            }
        }
        var n_curr_debt = BigDecimal.ZERO
        val debt_callorder = _getCallOrder()
        if (debt_callorder != null) {
            n_curr_debt = bigDecimalfromAmount(debt_callorder.getString("debt"), _debtPair!!._basePrecision)
        }
        //  新增借贷（可以为负。）
        val n_add_debt = new_tf_value.subtract(n_curr_debt)

        //  UI获取
        val lbl_available = findViewById<TextView>(R.id.label_txt_debt_available)

        //  可用余额
        val n_available = _getDebtBalance().add(n_add_debt)
        val base_symbol = _debtPair!!._baseAsset.getString("symbol")
        lbl_available.text = "${resources.getString(R.string.kDebtLableAvailable)} $n_available ${base_symbol}"

        if (n_available.compareTo(BigDecimal.ZERO) < 0) {
            lbl_available.setTextColor(resources.getColor(R.color.theme01_tintColor))
        } else {
            lbl_available.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        }
    }

    /**
     * 计算抵押率       公式：抵押率 = 抵押物数量 * 喂价 / 负债
     */
    private fun _calcCollRate(n_debt: BigDecimal, n_coll: BigDecimal, percent_result: Boolean): BigDecimal {
        //  REMARK：预测市场，抵押物数量和借款数量必须一致，不需要喂价。
        if (_currAssetIsPredictionmarket) {
            return BigDecimal.ONE
        }
        assert(_nCurrFeedPrice != null)
        assert(n_debt != BigDecimal.ZERO)
        val n = n_coll.multiply(_nCurrFeedPrice).divide(n_debt, 4, BigDecimal.ROUND_UP)
        if (percent_result) {
            //  返回百分比结果（精度2位）
            return n.multiply(BigDecimal.valueOf(100.0))
        } else {
            //  返回4位精度小数
            return n
        }
    }

    /**
     *  计算可借款数量  公式：借款 = 抵押物数量 * 喂价 / 抵押率
     */
    private fun _calcDebtNumber(n_coll: BigDecimal, rate: BigDecimal?): BigDecimal {
        //  REMARK：预测市场，抵押物数量和借款数量必须一致，不需要喂价。
        if (_currAssetIsPredictionmarket) {
            return n_coll
        }
        assert(rate != null)
        assert(_nCurrFeedPrice != null)
        //  抵押率为0，则债务为0，不随抵押物变化。
        if (rate!! <= BigDecimal.ZERO) {
            return BigDecimal.ZERO
        }
        return n_coll.multiply(_nCurrFeedPrice!!).divide(rate, _debtPair!!._basePrecision, BigDecimal.ROUND_DOWN)
    }

    /**
     *  计算抵押物数量  公式：抵押物数量 = 抵押率 * 负债 / 喂价
     */
    private fun _calcCollNumber(n_debt: BigDecimal, rate: BigDecimal?): BigDecimal {
        //  REMARK：预测市场，抵押物数量和借款数量必须一致，不需要喂价。
        if (_currAssetIsPredictionmarket) {
            return n_debt
        }
        assert(rate != null)
        assert(_nCurrFeedPrice != null)
        assert(_nCurrFeedPrice!!.compareTo(BigDecimal.ZERO) != 0)
        return n_debt.multiply(rate).divide(_nCurrFeedPrice!!, _debtPair!!._quotePrecision, BigDecimal.ROUND_UP)
    }

    /**
     * (private) 刷新目标抵押率
     */
    private fun _refreshUI_target_ratio(ratio_: BigDecimal?, reset_slider: Boolean) {
        //  预测市场不显示
        if (_currAssetIsPredictionmarket) {
            return
        }

        val ratio = ratio_ ?: BigDecimal.ZERO
        val value = ratio.toDouble()

        if (reset_slider) {
            val parameters = ChainObjectManager.sharedChainObjectManager().getDefaultParameters()
            _curve_slider_target_ratio.set_min(max(_nMaintenanceCollateralRatio!!.toDouble() - 0.3, 0.0))
            _curve_slider_target_ratio.set_max(max(value, parameters.getDouble("max_target_ratio")))
            _curve_slider_target_ratio.set_value(value)
        }

        //  ratio < _nMaintenanceCollateralRatio
        val label = findViewById<TextView>(R.id.label_txt_target_ratio)
        if (ratio.compareTo(_nMaintenanceCollateralRatio) < 0) {
            label.text = resources.getString(R.string.kDebtTipTargetRatioNotSet)
            label.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        } else {
            label.text = String.format("%s %.2f", resources.getString(R.string.kDebtTipTargetRatio), value.toFloat())
            label.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        }
    }

    /**
     * (private) 获取当前操作资产的债仓信息，债仓不存在则返回 nil。
     */
    private fun _getCallOrder(): JSONObject? {
        if (_callOrderHash != null) {
            return _callOrderHash!!.getJSONObject(_debtPair!!._baseAsset.getString("symbol")).optJSONObject("callorder")
        } else {
            return null
        }
    }

    /**
     *  (private) 获取总抵押物数量（已抵押的 + 可用的），未登录时候返回 0。
     */
    private fun _getTotalCollateralNumber(): BigDecimal {
        var n_coll = BigDecimal.ZERO
        var n_balance = BigDecimal.ZERO
        val debt_callorder = _getCallOrder()
        if (debt_callorder != null) {
            n_coll = bigDecimalfromAmount(debt_callorder.getString("collateral"), _debtPair!!._quotePrecision)
        }
        if (_collateralBalance != null) {
            n_balance = bigDecimalfromAmount(_collateralBalance!!.getString("amount"), _debtPair!!._quotePrecision)
        }
        return n_coll.add(n_balance)
    }

    /**
     *  (private) 获取当前借贷资产可用余额
     */
    private fun _getDebtBalance(): BigDecimal {
        if (_callOrderHash != null) {
            val debt = _callOrderHash!!.getJSONObject(_debtPair!!._baseAsset.getString("symbol"))
            return bigDecimalfromAmount(debt.getJSONObject("balance").getString("amount"), _debtPair!!._basePrecision)
        } else {
            return BigDecimal.ZERO
        }
    }

    /**
     * (private) 查询喂价信息
     */
    private fun _asyncQueryFeedPrice(debtAsset: JSONObject?): Promise {
        val asset = debtAsset ?: _debtPair!!._baseAsset
        val bitasset_data_id = asset.getString("bitasset_data_id")
        assert(bitasset_data_id.isNotEmpty())
        return ChainObjectManager.sharedChainObjectManager().queryAllGrapheneObjectsSkipCache(jsonArrayfrom(bitasset_data_id)).then {
            val resultHash = it as JSONObject
            return@then resultHash.getJSONObject(bitasset_data_id)
        }
    }

    /**
     * (private) 刷新用户数据
     */
    private fun _refreshUserData() {
        val bLogined = _isUserLogined()
        val promise_map = JSONObject()
        promise_map.put("kFeed", _asyncQueryFeedPrice(null))
        if (bLogined) {
            val account_id = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").getString("id")
            promise_map.put("kFullAccountData", ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_id))
        }
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()
        Promise.map(promise_map).then {
            mask.dismiss()
            val datamap = it as JSONObject
            _refreshUI(bLogined, datamap.getJSONObject("kFeed"))
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     * (private) 刷新界面 - 用户登录 or 用户数据更新了 or 用户选择了新的借款资产。
     */
    private fun _refreshUI(bLogined: Boolean, new_feed_price_data: JSONObject?) {
        //  更新喂价 和 MCR。
        if (new_feed_price_data != null) {
            _nCurrFeedPrice = _debtPair!!.calcShowFeedInfo(jsonArrayfrom(new_feed_price_data))
            _currAssetIsPredictionmarket = new_feed_price_data.isTrue("is_prediction_market")
            val mcr = new_feed_price_data.getJSONObject("current_feed").getString("maintenance_collateral_ratio")
            _nMaintenanceCollateralRatio = bigDecimalfromAmount(mcr, 3)
        }

        //  生成新的债仓信息
        _genCallOrderHash(bLogined)

        //  更新UI
        findViewById<TextView>(R.id.tf_tailer_coll_asset_symbol).text = _debtPair!!._quoteAsset.getString("symbol")
        findViewById<TextView>(R.id.tf_tailer_debt_asset_symbol).text = _debtPair!!._baseAsset.getString("symbol")

        //  UI - 按钮
        if (bLogined) {
            findViewById<Button>(R.id.btn_submit_core).text = resources.getString(R.string.kOpType_call_order_update)
        } else {
            findViewById<Button>(R.id.btn_submit_core).text = resources.getString(R.string.kNormalCellBtnLogin)
        }

        //  UI - 喂价
        val base_symbol = _debtPair!!._baseAsset.getString("symbol")
        val quote_symbol = _debtPair!!._quoteAsset.getString("symbol")
        if (!_currAssetIsPredictionmarket && _nCurrFeedPrice != null) {
            findViewById<TextView>(R.id.label_txt_curr_feed).text = "${resources.getString(R.string.kVcFeedCurrentFeedPrice)} ${_nCurrFeedPrice!!.toPlainString()}${base_symbol}/${quote_symbol}"
        } else {
            findViewById<TextView>(R.id.label_txt_curr_feed).text = "${resources.getString(R.string.kVcFeedCurrentFeedPrice)} --${base_symbol}/${quote_symbol}"
        }

        //  UI - 你的强平触发价
        onResetCLicked()

        //  UI - 提示信息
        findViewById<TextView>(R.id.tv_ui_tips).let { tv ->
            tv.text = if (_currAssetIsPredictionmarket) {
                resources.getString(R.string.kDebtWarmTipsForPM)
            } else {
                resources.getString(R.string.kDebtWarmTips)
            }
        }

        //  UI - 更新部分区域可见性
        findViewById<LinearLayout>(R.id.layout_ratio_and_tcr).let {
            if (_currAssetIsPredictionmarket) {
                it.visibility = View.GONE
            } else {
                it.visibility = View.VISIBLE
            }
        }
    }

    /**
     * (private) 初始化债仓信息
     */
    private fun _genCallOrderHash(bLogined: Boolean) {
        if (bLogined) {
            val wallet_account_info = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
            val account_id = wallet_account_info.getJSONObject("account").getString("id")

            val chainMgr = ChainObjectManager.sharedChainObjectManager()
//            val debt_asset_list = chainMgr.getDebtAssetList()

            //  REMARK：如果没执行 get_full_accounts 请求，则内存缓存不存在，则默认从登录时的帐号信息里获取。
            var full_account_data = chainMgr.getFullAccountDataFromCache(account_id)
            if (full_account_data == null) {
                full_account_data = wallet_account_info
            }

            //  1、初始化余额Hash(原来的是Array)
            val balances_hash = JSONObject()
            full_account_data.getJSONArray("balances").forEach<JSONObject> {
                val balance_object = it!!
                val asset_type = balance_object.getString("asset_type")
                val balance = balance_object.getString("balance")
                balances_hash.put(asset_type, jsonObjectfromKVS("asset_id", asset_type, "amount", balance))
            }
            val balances_list = balances_hash.values()

            //  2、计算手续费对象（更新手续费资产的可用余额，即减去手续费需要的amount）
            _fee_item = chainMgr.estimateFeeObject(EBitsharesOperations.ebo_call_order_update.value, balances_list)
            val fee_asset_id = _fee_item!!.getString("fee_asset_id")
            val fee_balance = balances_hash.optJSONObject(fee_asset_id)
            if (fee_balance != null) {
                val fee = _fee_item!!.getString("amount").toDouble()
                val old = fee_balance.getString("amount").toDouble()
                val new_balance: JSONObject
                if (old >= fee) {
                    new_balance = jsonObjectfromKVS("asset_id", fee_asset_id, "amount", old - fee)
                } else {
                    new_balance = jsonObjectfromKVS("asset_id", fee_asset_id, "amount", 0)
                }
                balances_hash.put(fee_asset_id, new_balance)
            }


            //  3、获取抵押物（BTS）的余额信息
            _collateralBalance = balances_hash.optJSONObject(_debtPair!!._quoteId)
            if (_collateralBalance == null) {
                _collateralBalance = jsonObjectfromKVS("asset_id", _debtPair!!._quoteId, "amount", 0)
            }

            //  4、获取当前持有的债仓
            val call_orders_hash = JSONObject()
            val call_orders = full_account_data.optJSONArray("call_orders")
            if (call_orders != null) {
                call_orders.forEach<JSONObject> {
                    val call_order = it!!
                    call_orders_hash.put(call_order.getJSONObject("call_price").getJSONObject("quote").getString("asset_id"), call_order)
                }
            }

            //  5、债仓和余额关联
            _callOrderHash = JSONObject()
            val debt_symbol = _debtPair!!._baseAsset.getString("symbol")
            val debt_asset = _debtPair!!._baseAsset
            val oid = debt_asset.getString("id")
            var balance = balances_hash.optJSONObject(oid)
            if (balance == null) {
                //  默认值
                balance = jsonObjectfromKVS("asset_id", oid, "amount", 0)
            }
            val info: JSONObject
            val callorder = call_orders_hash.optJSONObject(oid)
            if (callorder != null) {
                info = jsonObjectfromKVS("balance", balance, "debt_asset", debt_asset, "callorder", callorder)
            } else {
                info = jsonObjectfromKVS("balance", balance, "debt_asset", debt_asset)
            }
            //  保存到Hash
            _callOrderHash!!.put(debt_symbol, info)
            _callOrderHash!!.put(oid, info)
        } else {
            _callOrderHash = null
            _collateralBalance = null
            _fee_item = null
        }
    }

    /**
     * (private) 辅助方法 - 判断用户是否已经登录
     */
    private fun _isUserLogined(): Boolean {
        return WalletManager.sharedWalletManager().isWalletExist()
    }
}
