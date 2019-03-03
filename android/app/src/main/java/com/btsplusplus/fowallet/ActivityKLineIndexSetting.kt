package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.app.AlertDialog
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.Promise
import bitshares.SettingManager
import bitshares.TempManager
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_kline_quota_setting.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityKLineIndexSetting : BtsppActivity() {

    private lateinit var m_layout_ma: LinearLayout
    private lateinit var m_layout_boll: LinearLayout

    private lateinit var m_dialog_main: AlertDialog
    private lateinit var m_dialog_select: AlertDialog

    private lateinit var _result_promise: Promise
    // private var _bResultCannelled: Boolean = false
    private lateinit var _picker_data_array: MutableList<Int>
    private lateinit var _configValueHash: JSONObject

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_kline_quota_setting)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //_bResultCannelled = true
        _picker_data_array = mutableListOf()
        val args = TempManager.sharedTempManager().get_args_as_JSONObject()
        _result_promise = args.get("result_promise") as Promise

        //val j = SettingManager.sharedSettingManager().getKLineIndexInfos().toString()
        _configValueHash = JSONObject(SettingManager.sharedSettingManager().getKLineIndexInfos().toString())

        m_layout_ma = layout_ma_setting_of_kline_quota_setting
        m_layout_boll = layout_boll_setting_of_kline_quota_setting

        loadSettingAndRefreshUI()

        layout_back_from_kline_quota_setting.setOnClickListener{
            finish()
        }
        layout_main_view_of_kline_quota_setting.setOnClickListener{
            onMainViewClick()
        }
        layout_ma1_of_kline_quota_setting.setOnClickListener{
            onMaViewClick(0)
        }
        layout_ma2_of_kline_quota_setting.setOnClickListener{
            onMaViewClick(1)
        }
        layout_ma3_of_kline_quota_setting.setOnClickListener{
            onMaViewClick(2)
        }
        layout_bolln_of_kline_quota_setting.setOnClickListener{
            onBollViewClick(0)
        }
        layout_bollp_of_kline_quota_setting.setOnClickListener{
            onBollViewClick(1)
        }
    }

    private fun loadSettingAndRefreshUI(){
        hideMaAndBollLayout()
        val main_value = _configValueHash.optString("kMain")
        if ( main_value == null || main_value.equals("") ){
            tv_main_view_of_kline_quota_setting.text = resources.getString(R.string.klineQuotaSettingPageTextNotDisplay)
        } else {
            val value_values = _configValueHash.getJSONArray("${main_value}_value")

            tv_main_view_of_kline_quota_setting.text = main_value.toUpperCase()
            if ( main_value.equals("ma") ) {
                m_layout_ma.visibility = LinearLayout.VISIBLE

                var _index = 0
                value_values.forEach<Int> {

                    when (_index) {
                        0 -> {
                            tv_ma1_value_of_kline_quota_setting.text = _index.toString()
                        }
                        1 -> {
                            tv_ma2_value_of_kline_quota_setting.text = _index.toString()
                        }
                        2 -> {
                            tv_ma3_value_of_kline_quota_setting.text = _index.toString()
                        }
                    }
                    _index++
                }
            }
            if ( main_value.equals("boll") ) {
                m_layout_boll.visibility = LinearLayout.VISIBLE

                var _index = 0
                value_values.forEach<Int> {

                    when (_index) {
                        0 -> {
                            tv_bolln_value_of_kline_quota_setting.text = _index.toString()
                        }
                        1 -> {
                            tv_bollp_value_of_kline_quota_setting.text = _index.toString()
                        }
                    }
                    _index++
                }
            }
        }
    }

    /**
     *  (private) 核心 确认交易，发送。
     */
    private fun onCommitCore(){
        val sConfigValueHash = _configValueHash.toString()
        SettingManager.sharedSettingManager().setUseConfig("kSettingKey_KLineIndexInfo",sConfigValueHash)
        // _bResultCannelled = false
    }

    private fun buildPickData(is_ma_picker: Boolean) : Array<String> {
        val ma_value_min = 2
        val ma_value_max = 91
        var _pick_index = 0
        val data_arr : Array<String>

        if ( is_ma_picker ) {
            data_arr = Array(90, {""})
            data_arr[0] = "0"  //  0 means 'hide'
            _pick_index = 1
        } else {
            data_arr = Array(89, {""})
        }
        for ( ma_value in ma_value_min until ma_value_max ) {
            data_arr[_pick_index] = ma_value.toString()
            _pick_index++
        }
        return data_arr
    }


    private fun onMaViewClick(select_index: Int){

        m_dialog_select = ViewSelector.show(this,"", buildPickData(true)){ _index: Int, result: String ->

            when (select_index) {
                0 -> {
                    tv_ma1_value_of_kline_quota_setting.text = result
                }
                1 -> {
                    tv_ma2_value_of_kline_quota_setting.text = result
                }
                2 -> {
                    tv_ma3_value_of_kline_quota_setting.text = result
                }
            }
            _configValueHash.getJSONArray("ma_value").put(select_index,result.toInt())

            m_dialog_select.dismiss()
        }
    }

    private fun onBollViewClick(select_index: Int){

        m_dialog_select = ViewSelector.show(this,"", buildPickData(false)){ _index: Int, result: String ->

            when (select_index) {
                0 -> {
                    _configValueHash.getJSONObject("boll_value").put("n", result.toInt())
                    tv_bolln_value_of_kline_quota_setting.text = result
                }
                1 -> {
                    _configValueHash.getJSONObject("boll_value").put("p", result.toInt())
                    tv_bollp_value_of_kline_quota_setting.text = result
                }
            }
            m_dialog_select.dismiss()
        }
    }


    private fun onMainViewClick(){
        m_dialog_main = ViewSelector.show(this,"", arrayOf(resources.getString(R.string.klineQuotaSettingPageTextNotDisplay),"MA","BOLL")){ index: Int, result: String ->
            hideMaAndBollLayout()
            tv_main_view_of_kline_quota_setting.text = result
            when (index) {
                0 -> {
                    _configValueHash.put("kMain","")
                }
                1 -> {
                    _configValueHash.put("kMain","ma")
                    m_layout_ma.visibility = LinearLayout.VISIBLE
                }
                2 -> {
                    _configValueHash.put("kMain","boll")
                    m_layout_boll.visibility = LinearLayout.VISIBLE
                }
            }
            m_dialog_main.dismiss()
        }
    }

    private fun hideMaAndBollLayout() {
        m_layout_ma.visibility = LinearLayout.GONE
        m_layout_boll.visibility = LinearLayout.GONE
    }
}
