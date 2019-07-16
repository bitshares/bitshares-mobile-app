package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.*
import bitshares.*
import com.btsplusplus.fowallet.kline.TradingPair
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.max
import kotlin.math.min

class ActivityIndexCollateral : BtsppActivity() {

    private var _debtPair: TradingPair? = null
    private var _nMaintenanceCollateralRatio: BigDecimal? = null
    private var _nCurrMortgageRate: BigDecimal? = null
    private var _nCurrFeedPrice: BigDecimal? = null

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
        val debt_asset_list = chainMgr.getDebtAssetList()
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
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_feed_settlement"))
            goToWebView(resources.getString(R.string.kDebtTipTitleFeedAndCallPrice), "https://btspp.io/qam.html#qa_feed_settlement")
        }
        findViewById<ImageView>(R.id.tip_link_ratio).setOnClickListener {
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_ratio"))
            goToWebView(resources.getString(R.string.kDebtTipTitleWhatIsRatio), "https://btspp.io/qam.html#qa_ratio")
        }
        findViewById<ImageView>(R.id.tip_link_target_ratio).setOnClickListener {
            //  [统计]
            btsppLogCustom("qa_tip_click", jsonObjectfromKVS("qa", "qa_target_ratio"))
            goToWebView(resources.getString(R.string.kDebtTipTitleWhatIsTargetRatio), "https://btspp.io/qam.html#qa_target_ratio")
        }

        //  监听事件
        findViewById<TextView>(R.id.btn_reset_all).setOnClickListener { onResetCLicked() }
        findViewById<TextView>(R.id.btn_select_debt_asset).setOnClickListener { onSelectDebtAssetClicked() }
        _curve_slider_ratio = UtilsCurveSlider(findViewById<SeekBar>(R.id.slider_ratio)).init_with_range(400, 0.0, 6.0)
        _curve_slider_target_ratio = UtilsCurveSlider(findViewById<SeekBar>(R.id.slider_target_ratio)).init_with_range(400, 0.0, 4.0)
        _curve_slider_ratio.on_value_changed { onSliderRatioValueChanged(it) }
        _curve_slider_target_ratio.on_value_changed { onSliderTargetRatioValueChanged(it) }

        var tf = findViewById<EditText>(R.id.tf_debt)
        _tf_debt_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_debtPair!!._basePrecision)
        tf.addTextChangedListener(_tf_debt_watcher!!)
        _tf_debt_watcher!!.on_value_changed(::onDebtAmountChanged)

        tf = findViewById<EditText>(R.id.tf_coll)
        _tf_coll_watcher = UtilsDigitTextWatcher().set_tf(tf).set_precision(_debtPair!!._quotePrecision)
        tf.addTextChangedListener(_tf_coll_watcher!!)
        _tf_coll_watcher!!.on_value_changed(::onCollAmountChanged)

        //  最大还款、全部抵押
        findViewById<TextView>(R.id.btn_pay_max).setOnClickListener { onTailerPayMaxClicked() }
        findViewById<TextView>(R.id.btn_debt_max).setOnClickListener { onTailerDebtMaxClicked() }

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
        if (n_rest_coll.compareTo(zero) < 0) {
            showToast(resources.getString(R.string.kDebtTipCollNotEnough))
            return
        }

        //  可用余额不足
        val n_balance_debt = _getDebtBalance()
        val n_rest_debt = n_balance_debt.add(n_delta_debt)
        if (n_rest_debt.compareTo(zero) < 0) {
            showToast(String.format(resources.getString(R.string.kDebtTipAvailableNotEnough), _debtPair!!._baseAsset.getString("symbol")))
            return
        }

        //  抵押率判断
        //  【BSIP30】在爆仓状态可以上调抵押率，不再强制要求必须上调到多少，但抵押率不足最低要求时不能增加借款
        assert(_nCurrMortgageRate != null)
        if (_nCurrMortgageRate!!.compareTo(_nMaintenanceCollateralRatio) < 0 && n_delta_debt.compareTo(zero) > 0) {
            showToast(String.format(resources.getString(R.string.kDebtTipRatioTooLow), _nMaintenanceCollateralRatio!!.toPlainString()))
            return
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
     * 事件 - 最大还款
     */
    private fun onTailerPayMaxClicked() {
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
     * 事件 - 全部抵押
     */
    private fun onTailerDebtMaxClicked() {
        val n_total = _getTotalCollateralNumber()
        var new_str: String = ""
        if (n_total.compareTo(BigDecimal.ZERO) != 0) {
            new_str = n_total.toPlainString()
        }
        _tf_coll_watcher?.set_new_text(new_str)
        onCollAmountChanged(new_str)
    }

    /**
     * (private) 输入框值变化 - 借款数量
     */
    private fun onDebtAmountChanged(str: String) {
        if (_nCurrFeedPrice == null) {
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
        if (_nCurrFeedPrice == null) {
            return
        }
        assert(_nCurrMortgageRate != null)
        val n_coll = Utils.auxGetStringDecimalNumberValue(str)
        val n_debt = _calcDebtNumber(n_coll, _nCurrMortgageRate!!)
        _refreshUI_coll_available(n_coll, false)
        _refreshUI_debt_available(n_debt, true)
        _refreshUI_SettlementTriggerPrice()
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
        var list = ChainObjectManager.sharedChainObjectManager().getDebtAssetList()
        ViewSelector.show(this, resources.getString(R.string.kDebtTipSelectDebtAsset), list.toList<String>().toTypedArray()) { index: Int, result: String ->
            processSelectNewDebtAsset(list.getString(index))
        }
    }

    private fun processSelectNewDebtAsset(newDebtAssetSymbol: String) {
        //   选择的就是当前资产，直接返回。
        if (newDebtAssetSymbol == _debtPair!!._baseAsset.getString("symbol")) {
            return
        }
        //  获取背书资产
        val newDebtAsset = ChainObjectManager.sharedChainObjectManager().getAssetBySymbol(newDebtAssetSymbol)
        //  获取当前资产喂价信息
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this), this)
        mask.show()
        _asyncQueryFeedPrice(newDebtAsset).then {
            mask.dismiss()
            _debtPair = TradingPair().initWithBaseAsset(newDebtAsset, _debtPair!!._quoteAsset)
            //  切换了资产（更新输入框可输入的精度信息）
            _tf_debt_watcher?.set_precision(_debtPair!!._basePrecision)?.clear()
            _tf_coll_watcher?.set_precision(_debtPair!!._quotePrecision)?.clear()
            _refreshUI(_isUserLogined(), it as JSONObject)
            return@then null
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     *  重置 - 借款数量、抵押数量、抵押率、目标抵押率
     */
    private fun onResetCLicked() {
        val debt_callorder = _getCallOrder()
        if (debt_callorder != null) {
            val n_debt = bigDecimalfromAmount(debt_callorder.getString("debt"), _debtPair!!._basePrecision)
            val n_coll = bigDecimalfromAmount(debt_callorder.getString("collateral"), _debtPair!!._quotePrecision)
            _tf_debt_watcher!!.set_new_text(n_debt.toPriceAmountString())
            _tf_coll_watcher!!.set_new_text(n_coll.toPriceAmountString())
            //  计算抵押率
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
    fun _refreshUI_ratio(reset_slider: Boolean) {
        assert(_nMaintenanceCollateralRatio != null)
        val label = findViewById<TextView>(R.id.label_txt_curr_ratio)
        label.setTextColor(resources.getColor(_getCollateralRatioColor()))
        if (_nCurrMortgageRate != null) {
            val value = _nCurrMortgageRate!!.toDouble()
            label.text = String.format("%s %.2f", resources.getString(R.string.kVcRankRatio), value.toFloat())
            if (reset_slider) {
                val parameters = ChainObjectManager.sharedChainObjectManager().getDefaultParameters()
                val mcr = _nMaintenanceCollateralRatio!!.toDouble()
                _curve_slider_ratio.set_min(min(value, mcr))
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
    fun _getCollateralRatioColor(): Int {
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
        if (n_debt.compareTo(n_zero) == 0 || n_coll.compareTo(n_zero) == 0) {
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
        val lbl_changed = findViewById<TextView>(R.id.label_txt_coll_available_changed)

        val n_total = _getTotalCollateralNumber()
        val n_available = n_total.subtract(new_tf_value)
        val quote_symbol = _debtPair!!._quoteAsset.getString("symbol")
        lbl_available.text = "${resources.getString(R.string.kDebtLableAvailable)} $n_available${quote_symbol}"

        //  变化量
        var n_balance = BigDecimal.ZERO
        if (_collateralBalance != null) {
            n_balance = bigDecimalfromAmount(_collateralBalance!!.getString("amount"), _debtPair!!._quotePrecision)
        }
        val n_diff = n_available.subtract(n_balance)
        val result = n_diff.compareTo(BigDecimal.ZERO)
        if (result != 0) {
            if (result > 0) {
                lbl_changed.text = "+${n_diff}"
                lbl_changed.setTextColor(resources.getColor(R.color.theme01_buyColor))
            } else {
                lbl_changed.text = "${n_diff}"
                lbl_changed.setTextColor(resources.getColor(R.color.theme01_sellColor))
            }
        } else {
            lbl_changed.text = ""
        }
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
        val lbl_changed = findViewById<TextView>(R.id.label_txt_debt_available_changed)

        //  可用余额
        val n_available = _getDebtBalance().add(n_add_debt)
        val base_symbol = _debtPair!!._baseAsset.getString("symbol")
        lbl_available.text = "${resources.getString(R.string.kDebtLableAvailable)} $n_available${base_symbol}"

        //  变化量
        val result = n_add_debt.compareTo(BigDecimal.ZERO)
        if (result != 0) {
            if (result > 0) {
                lbl_changed.text = "+${n_add_debt}"
                lbl_changed.setTextColor(resources.getColor(R.color.theme01_buyColor))
            } else {
                lbl_changed.text = "${n_add_debt}"
                lbl_changed.setTextColor(resources.getColor(R.color.theme01_sellColor))
            }
        } else {
            lbl_changed.text = ""
        }

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
        assert(_nCurrFeedPrice != null)
        assert(n_debt.compareTo(BigDecimal.ZERO) != 0)
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
    private fun _calcDebtNumber(n_coll: BigDecimal, rate: BigDecimal): BigDecimal {
        assert(_nCurrFeedPrice != null)
        assert(rate.compareTo(BigDecimal.ZERO) != 0)
        return n_coll.multiply(_nCurrFeedPrice!!).divide(rate, _debtPair!!._basePrecision, BigDecimal.ROUND_DOWN)
    }

    /**
     *  计算抵押物数量  公式：抵押物数量 = 抵押率 * 负债 / 喂价
     */
    private fun _calcCollNumber(n_debt: BigDecimal, rate: BigDecimal): BigDecimal {
        assert(_nCurrFeedPrice != null)
        assert(_nCurrFeedPrice!!.compareTo(BigDecimal.ZERO) != 0)
        return n_debt.multiply(rate).divide(_nCurrFeedPrice!!, _debtPair!!._quotePrecision, BigDecimal.ROUND_UP)
    }

    /**
     * (private) 刷新目标抵押率
     */
    private fun _refreshUI_target_ratio(ratio_: BigDecimal?, reset_slider: Boolean) {
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
        assert(asset != null)
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        return conn.async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom(asset.getString("bitasset_data_id")))).then {
            val data_array = it as JSONArray
            return@then data_array.getJSONObject(0)
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
            val mcr = new_feed_price_data.getJSONObject("current_feed").getString("maintenance_collateral_ratio")
            _nMaintenanceCollateralRatio = bigDecimalfromAmount(mcr, 3)
        }

        //  生成新的债仓信息
        _genCallOrderHash(bLogined)

        //  更新UI

        //  UI - 按钮
        if (bLogined) {
            findViewById<Button>(R.id.btn_submit_core).text = resources.getString(R.string.kOpType_call_order_update)
        } else {
            findViewById<Button>(R.id.btn_submit_core).text = resources.getString(R.string.kNormalCellBtnLogin)
        }

        //  UI - 喂价
        val base_symbol = _debtPair!!._baseAsset.getString("symbol")
        val quote_symbol = _debtPair!!._quoteAsset.getString("symbol")
        if (_nCurrFeedPrice != null) {
            findViewById<TextView>(R.id.label_txt_curr_feed).text = "${resources.getString(R.string.kVcFeedCurrentFeedPrice)} ${_nCurrFeedPrice!!.toPlainString()}${base_symbol}/${quote_symbol}"
        } else {
            findViewById<TextView>(R.id.label_txt_curr_feed).text = "${resources.getString(R.string.kVcFeedCurrentFeedPrice)} --${base_symbol}/${quote_symbol}"
        }

        //  UI - 你的强平触发价
        onResetCLicked()

        //  UI - 列表
        _refreshUITableInfos()
    }

    /**
     * 刷新其他信息，参考iOS的TableView部分
     */
    private fun _refreshUITableInfos() {
        findViewById<TextView>(R.id.txt_debt_asset_name).text = _debtPair!!._baseAsset.getString("symbol")
        findViewById<TextView>(R.id.txt_coll_asset_name).text = _debtPair!!._quoteAsset.getString("symbol")
    }

    /**
     * (private) 初始化债仓信息
     */
    private fun _genCallOrderHash(bLogined: Boolean) {
        if (bLogined) {
            val wallet_account_info = WalletManager.sharedWalletManager().getWalletAccountInfo()!!
            val account_id = wallet_account_info.getJSONObject("account").getString("id")

            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            val debt_asset_list = chainMgr.getDebtAssetList()

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
                var new_balance: JSONObject
                if (old >= fee) {
                    new_balance = jsonObjectfromKVS("asset_id", fee_asset_id, "amount", old - fee)
                } else {
                    new_balance = jsonObjectfromKVS("asset_id", fee_asset_id, "amount", 0)
                }
                balances_hash.put(fee_asset_id, new_balance)
            }


            //  3、获取抵押物（BTS）的余额信息
            _collateralBalance = balances_hash.optJSONObject(BTS_NETWORK_CORE_ASSET_ID)
            if (_collateralBalance == null) {
                _collateralBalance = jsonObjectfromKVS("asset_id", BTS_NETWORK_CORE_ASSET_ID, "amount", 0)
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
            debt_asset_list.forEach<String> {
                val debt_symbol = it!!
                val debt_asset = chainMgr.getAssetBySymbol(debt_symbol)
                val oid = debt_asset.getString("id")
                var balance = balances_hash.optJSONObject(oid)
                if (balance == null) {
                    //  默认值
                    balance = jsonObjectfromKVS("asset_id", oid, "amount", 0)
                }
                var info: JSONObject
                val callorder = call_orders_hash.optJSONObject(oid)
                if (callorder != null) {
                    info = jsonObjectfromKVS("balance", balance, "debt_asset", debt_asset, "callorder", callorder)
                } else {
                    info = jsonObjectfromKVS("balance", balance, "debt_asset", debt_asset)
                }
                //  保存到Hash
                _callOrderHash!!.put(debt_symbol, info)
                _callOrderHash!!.put(oid, info)
            }
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
