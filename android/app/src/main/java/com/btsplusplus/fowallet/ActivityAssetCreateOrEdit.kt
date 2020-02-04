package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.TextView
import bitshares.toList
import kotlinx.android.synthetic.main.activity_asset_create_or_edit.*
import org.json.JSONArray

class ActivityAssetCreateOrEdit : BtsppActivity() {

    lateinit var _et_asset_name_from_assets_create_or_edit: EditText
    lateinit var _et_max_supply_from_assets_create_or_edit: EditText
    lateinit var _et_asset_description_from_assets_create_or_edit: EditText

    lateinit var _tv_asset_precision_from_assets_create_or_edit: TextView
    lateinit var _tv_debit_asset_from_assets_create_or_edit: TextView
    lateinit var _tv_feed_valid_date_from_assets_create_or_edit: TextView
    lateinit var _tv_min_feed_quantity_from_assets_create_or_edit: TextView
    lateinit var _tv_force_clear_delay_from_assets_create_or_edit: TextView
    lateinit var _tv_force_clear_compensation_rate_from_assets_create_or_edit: TextView
    lateinit var _tv_preweek_max_clear_rate_from_assets_create_or_edit: TextView



    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_asset_create_or_edit)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        val tv_title = findViewById<TextView>(R.id.title)
        tv_title.text = "创建资产"

        // 资产名称
        _et_asset_name_from_assets_create_or_edit = et_asset_name_from_assets_create_or_edit

        // 最大供应量
        _et_max_supply_from_assets_create_or_edit = et_max_supply_from_assets_create_or_edit

        // 资产描述
        _et_asset_description_from_assets_create_or_edit = et_asset_description_from_assets_create_or_edit

        // 高级设置
        switch_advance_from_assets_create_or_edit.setOnCheckedChangeListener { _, isChecked: Boolean ->
            layout_advance_from_assets_create_or_edit.visibility = if (isChecked) View.VISIBLE else View.GONE
        }

        // 资产精度
        _tv_asset_precision_from_assets_create_or_edit = tv_asset_precision_from_assets_create_or_edit
        _tv_asset_precision_from_assets_create_or_edit.text = "5位小数"
        layout_asset_precision_from_assets_create_or_edit.setOnClickListener {
            onSelectAssetPrecision()
        }

        // 借贷抵押资产
        _tv_debit_asset_from_assets_create_or_edit = tv_debit_asset_from_assets_create_or_edit
        _tv_debit_asset_from_assets_create_or_edit.text = "BTS"
        layout_debit_asset_from_assets_create_or_edit.setOnClickListener {
            onSelectDebitAssetPrecision()
        }

        // 喂价有效期
        _tv_feed_valid_date_from_assets_create_or_edit = tv_feed_valid_date_from_assets_create_or_edit
        _tv_feed_valid_date_from_assets_create_or_edit.text = "1440 分钟"
        layout_feed_valid_date_from_assets_create_or_edit.setOnClickListener {
            onSelectFeedValidDate()
        }

        // 最少喂价数量
        _tv_min_feed_quantity_from_assets_create_or_edit = tv_min_feed_quantity_from_assets_create_or_edit
        _tv_min_feed_quantity_from_assets_create_or_edit.text = "1"
        layout_min_feed_quantity_from_assets_create_or_edit.setOnClickListener {
            onSelectMinFeedQuantity()
        }

        // 强清延迟时间
        _tv_force_clear_delay_from_assets_create_or_edit = tv_force_clear_delay_from_assets_create_or_edit
        _tv_force_clear_delay_from_assets_create_or_edit.text = "1440分钟"
        layout_force_clear_delay_from_assets_create_or_edit.setOnClickListener {
            onSelectForceClearDelay()
        }

        // 强清补偿比例
        _tv_force_clear_compensation_rate_from_assets_create_or_edit = tv_force_clear_compensation_rate_from_assets_create_or_edit
        _tv_force_clear_compensation_rate_from_assets_create_or_edit.text = "5%"
        layout_force_clear_compensation_rate_from_assets_create_or_edit.setOnClickListener {
            onSelectForceClearCompensationRate()
        }

        // 每周最大清算量
        _tv_preweek_max_clear_rate_from_assets_create_or_edit = tv_preweek_max_clear_rate_from_assets_create_or_edit
        _tv_preweek_max_clear_rate_from_assets_create_or_edit.text = "5%"
        layout_preweek_max_clear_rate_from_assets_create_or_edit.setOnClickListener {
            onSelectPreweekMaxClearRate()
        }

        // 创建
        btn_create_from_assets_create_or_edit.setOnClickListener {
            onCreateClicked()
        }

        layout_back_from_assets_create_or_edit.setOnClickListener {
            finish()
        }

    }

    // 选择资产精度
    private fun onSelectAssetPrecision(){
        val list = JSONArray().apply {
            put("3位小数")
            put("4位小数")
            put("5位小数")
        }
        ViewSelector.show(this, "请选择备用账号", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
            _tv_asset_precision_from_assets_create_or_edit.text = _value
        }
    }

    // 选择借贷抵押资产
    private fun onSelectDebitAssetPrecision(){
        val list = JSONArray().apply {
            put("BTS")
            put("AAA")
            put("BBB")
        }
        ViewSelector.show(this, "请选择借贷抵押资产", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
            _tv_debit_asset_from_assets_create_or_edit.text = _value
        }
    }

    // 选择喂价有效期
    private fun onSelectFeedValidDate(){
        val list = JSONArray().apply {
            put("1440")
            put("2000")
            put("3000")
        }
        ViewSelector.show(this, "请选择喂价有效期", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
            _tv_feed_valid_date_from_assets_create_or_edit.text = String.format("%s 分钟",_value)
        }
    }

    // 选择最少喂价数量
    private fun onSelectMinFeedQuantity(){
        val list = JSONArray().apply {
            put("1")
            put("5")
            put("10")
        }
        ViewSelector.show(this, "请选择最少喂价数量", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
            _tv_min_feed_quantity_from_assets_create_or_edit.text = _value
        }
    }

    // 选择强清延迟时间
    private fun onSelectForceClearDelay(){
        val list = JSONArray().apply {
            put("1440")
            put("2000")
            put("3000")
        }
        ViewSelector.show(this, "请选择强清延迟时间", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
            _tv_force_clear_delay_from_assets_create_or_edit.text = String.format("%s 分钟",_value)
        }
    }

    // 强清补偿比例
    private fun onSelectForceClearCompensationRate(){
        val list = JSONArray().apply {
            put("5%")
            put("10%")
            put("15%")
        }
        ViewSelector.show(this, "请选择强清补偿比例", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
            _tv_force_clear_compensation_rate_from_assets_create_or_edit.text = _value
        }
    }

    // 每周最大清算量
    private fun onSelectPreweekMaxClearRate(){
        val list = JSONArray().apply {
            put("5%")
            put("10%")
            put("15%")
        }
        ViewSelector.show(this, "请选择每周最大清算量", list.toList<String>().toTypedArray()) { index: Int, _value: String ->
            _tv_preweek_max_clear_rate_from_assets_create_or_edit.text = _value
        }
    }

    // 创建
    private fun onCreateClicked(){

    }
}
