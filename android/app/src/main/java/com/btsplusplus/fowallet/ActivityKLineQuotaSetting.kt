package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.app.AlertDialog
import android.widget.LinearLayout
import android.widget.TextView
import kotlinx.android.synthetic.main.activity_kline_quota_setting.*

class ActivityKLineQuotaSetting : AppCompatActivity() {

    private lateinit var m_layout_ma: LinearLayout
    private lateinit var m_layout_boll: LinearLayout

    private lateinit var m_dialog_main: AlertDialog
    private lateinit var m_dialog_select: AlertDialog

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_kline_quota_setting)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()


        m_layout_ma = layout_ma_setting_of_kline_quota_setting
        m_layout_boll = layout_boll_setting_of_kline_quota_setting

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

    private fun onMaViewClick(select_index: Int){

        val values = Array(100, { i -> (i+1).toString() })

        m_dialog_select = ViewSelector.show(this,"", values){ _index: Int, result: String ->

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
        }
    }

    private fun onBollViewClick(select_index: Int){

        val values = Array(100, { i -> (i+1).toString() })

        m_dialog_select = ViewSelector.show(this,"", values){ _index: Int, result: String ->

            when (select_index) {
                0 -> {
                    tv_bolln_value_of_kline_quota_setting.text = result
                }
                1 -> {
                    tv_bollp_value_of_kline_quota_setting.text = result
                }
            }
        }
    }


    private fun onMainViewClick(){
        m_dialog_main = ViewSelector.show(this,"", arrayOf(resources.getString(R.string.klineQuotaSettingPageTextNotDisplay),"MA","BOLL")){ index: Int, result: String ->
            hideMaAndBollLayout()
            tv_main_view_of_kline_quota_setting.text = result
            when (index) {
                1 -> {
                    m_layout_ma.visibility = LinearLayout.VISIBLE
                }
                2 -> {
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
