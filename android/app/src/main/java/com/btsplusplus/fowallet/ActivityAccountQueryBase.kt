package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import kotlinx.android.synthetic.main.activity_account_query_base.*
import org.json.JSONObject

class ActivityAccountQueryBase : BtsppActivity() {

    var layout_search: LinearLayout? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_account_query_base)

        setFullScreen()

        layout_search = layout_search_from_service_account_query_index

        addDefaultResult(AppCacheManager.sharedAppCacheManager().get_all_fav_accounts().values().toList<JSONObject>().sortedBy({ it.getString("name") }))

        layout_back_from_services_account_query.setOnClickListener {
            finish()
        }

        //  监听
        edit_search_services_account_query.isFocusable = false
        edit_search_services_account_query.isFocusableInTouchMode = false
        edit_search_services_account_query.setOnClickListener {
            goTo(ActivityAccountQueryResult::class.java, false)
        }
    }

    private fun addDefaultResult(data_array: List<JSONObject>) {
        findViewById<TextView>(R.id.label_my_fav_n).text = String.format(resources.getString(R.string.kSearchTipsMyFavAccount), "${data_array.size}")
        for (data in data_array) {
            createCell(data.getString("name"), data.getString("id"))
        }
    }

    private fun createCell(s: String, oid: String) {
        val v = LinearLayout(this)
        val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(30f))
        layout_params.gravity = Gravity.CENTER_VERTICAL

        v.layoutParams = layout_params

        val tv: TextView = TextView(this)
        tv.text = s
        tv.gravity = Gravity.CENTER_VERTICAL
        tv.setTextColor(resources!!.getColor(R.color.theme01_textColorMain))

        val tv2: TextView = TextView(this)
        tv2.text = "#${oid}"
        tv2.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
        tv2.setTextColor(resources!!.getColor(R.color.theme01_textColorNormal))

        val layout_params2 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, toDp(30f))
        layout_params2.weight = 1.0f
        tv2.layoutParams = layout_params2

        v.addView(tv)
        v.addView(tv2)

        v.setOnClickListener {
            TempManager.sharedTempManager().call_query_account_callback(this, jsonObjectfromKVS("name", s, "id", oid))
        }

        layout_search!!.addView(v)
    }

}
