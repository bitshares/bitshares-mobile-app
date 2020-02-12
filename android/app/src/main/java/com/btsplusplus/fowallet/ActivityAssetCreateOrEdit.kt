package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.utils.ModelUtils
import kotlinx.android.synthetic.main.activity_asset_create_or_edit.*
import org.json.JSONObject
import java.math.BigDecimal

class ActivityAssetCreateOrEdit : BtsppActivity() {

    //  外部参数
    private lateinit var _result_promise: Promise
    private var _edit_asset: JSONObject? = null
    private var _edit_bitasset: JSONObject? = null

    //  实例变量
    private var _enable_more_args = false                   //  是否启用高级设置
    private var _symbol = ""                                //  资产符号
    private var _max_supply: BigDecimal? = null             //  最大供应量
    private var _market_fee_percent = 0                     //  交易手续费百分比
    private var _reward_percent = 0                         //  手续费引荐人分成比例
    private var _max_market_fee: BigDecimal? = null         //  单笔手续费最大值
    private var _description = ""                           //  描述信息
    private var _precision = 0                              //  资产精度
    private var _max_supply_editable = BigDecimal.ZERO      //  可编辑的最大供应量

    private var _bitasset_options_args: JSONObject? = null  //  智能币相关参数（默认为空）
    private var _issuer_permissions = 0                     //  权限
    private var _old_issuer_permissions = 0                 //  编辑之前的权限。（仅编辑资产才存在）
    private var _flags = 0                                  //  激活标记

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_create_or_edit)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _edit_asset = args.optJSONObject("kEditAsset")
        _edit_bitasset = args.optJSONObject("kEditBitAsset")
        _result_promise = args.get("result_promise") as Promise
        if (_edit_bitasset != null) {
            _bitasset_options_args = _edit_bitasset!!.getJSONObject("options").shadowClone()
        }
        genDefaultAssetArgs()

        //  初始化UI
        findViewById<TextView>(R.id.title).text = args.getString("kTitle")
        _drawUI_fixInfo()
        _drawUI_basicInfo()
        _drawUI_marketFeeInfo()
        _drawUI_permissionInfo()
        _drawUI_smartInfo()
        _drawUI_visible_onAdvSwitchChanged(false)
        _drawUI_button()
        _drawUI_tips()

        //  绑定事件
        //  TODO:4.0
//        // 资产名称
//        _et_asset_name_from_assets_create_or_edit = et_asset_name_from_assets_create_or_edit
//
//        // 最大供应量
//        _et_max_supply_from_assets_create_or_edit = et_max_supply_from_assets_create_or_edit
//
//        // 资产描述
//        _et_asset_description_from_assets_create_or_edit = et_asset_description_from_assets_create_or_edit
//
//        // 高级设置
//        switch_advance_from_assets_create_or_edit.setOnCheckedChangeListener { _, isChecked: Boolean ->
//            layout_advance_from_assets_create_or_edit.visibility = if (isChecked) View.VISIBLE else View.GONE
//        }
//
//        // 资产精度
//        _tv_asset_precision_from_assets_create_or_edit = tv_asset_precision_from_assets_create_or_edit
//        _tv_asset_precision_from_assets_create_or_edit.text = "5位小数"
//        layout_asset_precision_from_assets_create_or_edit.setOnClickListener {
//            onSelectAssetPrecision()
//        }
//
//        // 借贷抵押资产
//        _tv_debit_asset_from_assets_create_or_edit = tv_debit_asset_from_assets_create_or_edit
//        _tv_debit_asset_from_assets_create_or_edit.text = "BTS"
//        layout_debit_asset_from_assets_create_or_edit.setOnClickListener {
//            onSelectDebitAssetPrecision()
//        }
//
//        // 喂价有效期
//        _tv_feed_valid_date_from_assets_create_or_edit = tv_feed_valid_date_from_assets_create_or_edit
//        _tv_feed_valid_date_from_assets_create_or_edit.text = "1440 分钟"
//        layout_feed_valid_date_from_assets_create_or_edit.setOnClickListener {
//            onSelectFeedValidDate()
//        }
//
//        // 最少喂价数量
//        _tv_min_feed_quantity_from_assets_create_or_edit = tv_min_feed_quantity_from_assets_create_or_edit
//        _tv_min_feed_quantity_from_assets_create_or_edit.text = "1"
//        layout_min_feed_quantity_from_assets_create_or_edit.setOnClickListener {
//            onSelectMinFeedQuantity()
//        }
//
//        // 强清延迟时间
//        _tv_force_clear_delay_from_assets_create_or_edit = tv_force_clear_delay_from_assets_create_or_edit
//        _tv_force_clear_delay_from_assets_create_or_edit.text = "1440分钟"
//        layout_force_clear_delay_from_assets_create_or_edit.setOnClickListener {
//            onSelectForceClearDelay()
//        }
//
//        // 强清补偿比例
//        _tv_force_clear_compensation_rate_from_assets_create_or_edit = tv_force_clear_compensation_rate_from_assets_create_or_edit
//        _tv_force_clear_compensation_rate_from_assets_create_or_edit.text = "5%"
//        layout_force_clear_compensation_rate_from_assets_create_or_edit.setOnClickListener {
//            onSelectForceClearCompensationRate()
//        }
//
//        // 每周最大清算量
//        _tv_preweek_max_clear_rate_from_assets_create_or_edit = tv_preweek_max_clear_rate_from_assets_create_or_edit
//        _tv_preweek_max_clear_rate_from_assets_create_or_edit.text = "5%"
//        layout_preweek_max_clear_rate_from_assets_create_or_edit.setOnClickListener {
//            onSelectPreweekMaxClearRate()
//        }

        //  事件 - 提交按钮
        btn_submit.setOnClickListener { onCreateClicked() }

        //  事件 - 返回
        layout_back_from_assets_create_or_edit.setOnClickListener { finish() }
    }

    /**
     *  初始化 智能币默认参数
     */
    private fun genDefaultSmartCoinArgs() {
        if (_bitasset_options_args == null) {
            _bitasset_options_args = JSONObject().apply {
                put("feed_lifetime_sec", 1440 * 60)
                put("minimum_feeds", 1)
                put("force_settlement_delay_sec", 1440 * 60)
                put("force_settlement_offset_percent", 5 * GRAPHENE_1_PERCENT)
                put("maximum_force_settlement_volume", 5 * GRAPHENE_1_PERCENT)
            }
        }
    }

    /**
     *  初始化 资产默认参数
     */
    private fun genDefaultAssetArgs() {
        if (isCreateAsset()) {
            //  创建
            updatePrecision(5)
            _symbol = ""
            _max_supply = null
            _description = ""

            _issuer_permissions = EBitsharesAssetFlags.ebat_issuer_permission_mask_uia.value
            _flags = 0

            _market_fee_percent = 0
            _max_market_fee = null
            _reward_percent = 0
        } else {
            //  编辑
            updatePrecision(_edit_asset!!.getInt("precision"))
            _symbol = _edit_asset!!.getString("symbol")
            val asset_options = _edit_asset!!.getJSONObject("options")
            _max_supply = bigDecimalfromAmount(asset_options.getString("max_supply"), _precision)
            _description = asset_options.optString("description")

            _issuer_permissions = asset_options.getInt("issuer_permissions")
            _flags = asset_options.getInt("flags")
            //  记录编辑之前的权限
            _old_issuer_permissions = _issuer_permissions

            _market_fee_percent = asset_options.getInt("market_fee_percent")
            _max_market_fee = bigDecimalfromAmount(asset_options.getString("max_market_fee"), _precision)
            _reward_percent = asset_options.getJSONObject("extensions").optInt("reward_percent")
        }
    }

    private fun updatePrecision(precision: Int) {
        assert(precision >= 0 && precision <= 12)
        _precision = precision
        _max_supply_editable = bigDecimalfromAmount(GRAPHENE_MAX_SHARE_SUPPLY.toString(), _precision)
    }

    /**
     *  （private) 辅助 - 判断UI操作行为
     */
    private fun isEditSmartInfo(): Boolean {
        return _edit_asset != null && _edit_bitasset != null
    }

    private fun isEditBasicInfo(): Boolean {
        return _edit_asset != null && _edit_bitasset == null
    }

    private fun isCreateAsset(): Boolean {
        return _edit_asset == null && _edit_bitasset == null
    }

    private fun isEditAsset(): Boolean {
        return !isCreateAsset()
    }

    /**
     *  描绘 - 固定信息（编辑资产时存在）
     */
    private fun _drawUI_fixInfo() {
        if (isEditAsset()) {
            layout_segment_fixinfos.visibility = View.VISIBLE

            tv_fixed_asset_symbol.text = _edit_asset!!.getString("symbol")
            tv_fixed_asset_precision.text = String.format(resources.getString(R.string.kVcAssetMgrCellValueAssetPrecision), _edit_asset!!.getString("precision"))
        } else {
            layout_segment_fixinfos.visibility = View.GONE
        }
    }

    /**
     *  (private) 设置控件可见性 - 高级设置开关变更时
     */
    private fun _drawUI_visible_onAdvSwitchChanged(on: Boolean) {
        if (isCreateAsset()) {
            _enable_more_args = on

            if (_enable_more_args) {
                layout_basic_asset_precision.visibility = View.VISIBLE
                layout_basic_asset_precision_line.visibility = View.VISIBLE

                _drawUI_smartInfo()
            } else {
                layout_basic_asset_precision.visibility = View.GONE
                layout_basic_asset_precision_line.visibility = View.GONE

                layout_segment_smartinfos.visibility = View.GONE
            }
        }
    }

    /**
     *  描绘 - 基本信息（创建和更新资产都存在，但不同）
     */
    private fun _drawUI_basicInfo() {
        if (isCreateAsset()) {
            layout_segment_basicinfos.visibility = View.VISIBLE

            layout_basic_asset_symbol.visibility = View.VISIBLE
            layout_btn_switch_adv.visibility = View.VISIBLE
            layout_basic_asset_precision.visibility = View.VISIBLE
            layout_basic_asset_symbol_line.visibility = View.VISIBLE
            layout_btn_switch_adv_line.visibility = View.VISIBLE
            layout_basic_asset_precision_line.visibility = View.VISIBLE

            //  事件 - 高级设置
            btn_switch_adv.setOnCheckedChangeListener { _, isChecked: Boolean -> _drawUI_visible_onAdvSwitchChanged(isChecked) }
        } else if (isEditBasicInfo()) {
            layout_segment_basicinfos.visibility = View.VISIBLE

            layout_basic_asset_symbol.visibility = View.GONE
            layout_btn_switch_adv.visibility = View.GONE
            layout_basic_asset_precision.visibility = View.GONE
            layout_basic_asset_symbol_line.visibility = View.GONE
            layout_btn_switch_adv_line.visibility = View.GONE
            layout_basic_asset_precision_line.visibility = View.GONE
        } else {
            layout_segment_basicinfos.visibility = View.GONE
        }
    }

    /**
     *  描绘 - 手续费信息
     */
    private fun _drawUI_marketFeeInfo() {
        if (isEditBasicInfo() && _flags.and(EBitsharesAssetFlags.ebat_charge_market_fee.value) != 0) {
            layout_segment_marketfeeinfos.visibility = View.VISIBLE
        } else {
            layout_segment_marketfeeinfos.visibility = View.GONE
        }
    }

    /**
     *  (private)  设置控件可见性 - 智能币相关的权限信息字段
     */
    private fun _drawUI_visible_smartPermissionRows(isSmartCorin: Boolean) {
        if (isSmartCorin) {
            layout_permission_disabled_force_settlements.visibility = View.VISIBLE
            layout_permission_allow_global_settle.visibility = View.VISIBLE
            layout_permission_allow_witness_feed.visibility = View.VISIBLE
            layout_permission_allow_committee_feed.visibility = View.VISIBLE

            layout_permission_disabled_force_settlements_line.visibility = View.VISIBLE
            layout_permission_allow_global_settle_line.visibility = View.VISIBLE
            layout_permission_allow_witness_feed_line.visibility = View.VISIBLE
            layout_permission_allow_committee_feed_line.visibility = View.VISIBLE
        } else {
            layout_permission_disabled_force_settlements.visibility = View.GONE
            layout_permission_allow_global_settle.visibility = View.GONE
            layout_permission_allow_witness_feed.visibility = View.GONE
            layout_permission_allow_committee_feed.visibility = View.GONE

            layout_permission_disabled_force_settlements_line.visibility = View.GONE
            layout_permission_allow_global_settle_line.visibility = View.GONE
            layout_permission_allow_witness_feed_line.visibility = View.GONE
            layout_permission_allow_committee_feed_line.visibility = View.GONE
        }
    }

    /**
     *  描绘 - 权限信息（编辑资产存在）
     */
    private fun _drawUI_permissionInfo() {
        if (isEditBasicInfo()) {
            layout_segment_permissioninfos.visibility = View.VISIBLE

            _drawUI_visible_smartPermissionRows(ModelUtils.assetIsSmart(_edit_asset!!))
        } else {
            layout_segment_permissioninfos.visibility = View.GONE
        }
    }

    /**
     *  (private)  设置控件可见性 - 智能币相关字段
     */
    private fun _drawUI_visible_smartRows(isSmartCorin: Boolean) {
        if (isSmartCorin) {
            layout_smart_feed_lifetime.visibility = View.VISIBLE
            layout_smart_min_feed_num.visibility = View.VISIBLE
            layout_smart_delay_for_settle.visibility = View.VISIBLE
            layout_smart_offset_settle.visibility = View.VISIBLE
            layout_smart_max_settle_volume.visibility = View.VISIBLE

            layout_smart_feed_lifetime_line.visibility = View.VISIBLE
            layout_smart_min_feed_num_line.visibility = View.VISIBLE
            layout_smart_delay_for_settle_line.visibility = View.VISIBLE
            layout_smart_offset_settle_line.visibility = View.VISIBLE
            layout_smart_max_settle_volume_line.visibility = View.VISIBLE
        } else {
            layout_smart_feed_lifetime.visibility = View.GONE
            layout_smart_min_feed_num.visibility = View.GONE
            layout_smart_delay_for_settle.visibility = View.GONE
            layout_smart_offset_settle.visibility = View.GONE
            layout_smart_max_settle_volume.visibility = View.GONE

            layout_smart_feed_lifetime_line.visibility = View.GONE
            layout_smart_min_feed_num_line.visibility = View.GONE
            layout_smart_delay_for_settle_line.visibility = View.GONE
            layout_smart_offset_settle_line.visibility = View.GONE
            layout_smart_max_settle_volume_line.visibility = View.GONE
        }
    }

    /**
     *  描绘 - 智能币信息（更新智能币和创建资产高级设置存在）
     */
    private fun _drawUI_smartInfo() {
        if ((isCreateAsset() && _enable_more_args) || isEditSmartInfo()) {
            layout_segment_smartinfos.visibility = View.VISIBLE

            if (isEditSmartInfo()) {
                _drawUI_visible_smartRows(true)
            } else {
                _drawUI_visible_smartRows(_bitasset_options_args != null)
            }
        } else {
            layout_segment_smartinfos.visibility = View.GONE
        }
    }

    /**
     *  描绘 - 提交按钮名字
     */
    private fun _drawUI_button() {
        if (isCreateAsset()) {
            btn_submit.text = resources.getString(R.string.kVcAssetMgrAssetCreateButton)
        } else if (isEditBasicInfo()) {
            btn_submit.text = resources.getString(R.string.kVcAssetMgrAssetUpdateAssetButton)
        } else {
            btn_submit.text = resources.getString(R.string.kVcAssetMgrAssetUpdateBitassetButton)
        }
    }

    /**
     *  描绘 - 底部提示信息
     */
    private fun _drawUI_tips() {
        if (isCreateAsset()) {
            layout_tips_info_segment.visibility = View.VISIBLE
            layout_tips_info_segment.text = resources.getString(R.string.kVcAssetMgrCreateUiTipsCreate)
        } else if (isEditBasicInfo()) {
            layout_tips_info_segment.visibility = View.VISIBLE
            layout_tips_info_segment.text = resources.getString(R.string.kVcAssetMgrCreateUiTipsUpdateAsset)
        } else {
            layout_tips_info_segment.visibility = View.GONE
        }
    }

//
//    // 选择资产精度
//    private fun onSelectAssetPrecision() {
//        val list = JSONArray().apply {
//            put("3位小数")
//            put("4位小数")
//            put("5位小数")
//        }
//        ViewSelector.show(this, "请选择备用账号", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
//            _tv_asset_precision_from_assets_create_or_edit.text = _value
//        }
//    }
//
//    // 选择借贷抵押资产
//    private fun onSelectDebitAssetPrecision() {
//        val list = JSONArray().apply {
//            put("BTS")
//            put("AAA")
//            put("BBB")
//        }
//        ViewSelector.show(this, "请选择借贷抵押资产", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
//            _tv_debit_asset_from_assets_create_or_edit.text = _value
//        }
//    }
//
//    // 选择喂价有效期
//    private fun onSelectFeedValidDate() {
//        val list = JSONArray().apply {
//            put("1440")
//            put("2000")
//            put("3000")
//        }
//        ViewSelector.show(this, "请选择喂价有效期", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
//            _tv_feed_valid_date_from_assets_create_or_edit.text = String.format("%s 分钟", _value)
//        }
//    }
//
//    // 选择最少喂价数量
//    private fun onSelectMinFeedQuantity() {
//        val list = JSONArray().apply {
//            put("1")
//            put("5")
//            put("10")
//        }
//        ViewSelector.show(this, "请选择最少喂价数量", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
//            _tv_min_feed_quantity_from_assets_create_or_edit.text = _value
//        }
//    }
//
//    // 选择强清延迟时间
//    private fun onSelectForceClearDelay() {
//        val list = JSONArray().apply {
//            put("1440")
//            put("2000")
//            put("3000")
//        }
//        ViewSelector.show(this, "请选择强清延迟时间", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
//            _tv_force_clear_delay_from_assets_create_or_edit.text = String.format("%s 分钟", _value)
//        }
//    }
//
//    // 强清补偿比例
//    private fun onSelectForceClearCompensationRate() {
//        val list = JSONArray().apply {
//            put("5%")
//            put("10%")
//            put("15%")
//        }
//        ViewSelector.show(this, "请选择强清补偿比例", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
//            _tv_force_clear_compensation_rate_from_assets_create_or_edit.text = _value
//        }
//    }
//
//    // 每周最大清算量
//    private fun onSelectPreweekMaxClearRate() {
//        val list = JSONArray().apply {
//            put("5%")
//            put("10%")
//            put("15%")
//        }
//        ViewSelector.show(this, "请选择每周最大清算量", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
//            _tv_preweek_max_clear_rate_from_assets_create_or_edit.text = _value
//        }
//    }

    // 创建
    private fun onCreateClicked() {

    }
}
