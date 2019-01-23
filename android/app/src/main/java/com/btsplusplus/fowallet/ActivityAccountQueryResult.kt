package com.btsplusplus.fowallet

import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import kotlinx.android.synthetic.main.activity_account_query_result.*
import org.json.JSONArray

class ActivityAccountQueryResult : BtsppActivity() {

    var search_editor: EditText? = null

    var layout_search: LinearLayout? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_account_query_result)

        // cancel
        text_cancel_from_service_account_query.setOnClickListener { view ->
            this.hideSoftKeyboard()
            finish()
        }

        search_editor = edit_search_account_obj_for_search
        layout_search = layout_search_from_service_account_query

        var watcher: ThisTextWatcher? = ThisTextWatcher()
        watcher!!.ctx = this

        search_editor!!.addTextChangedListener(watcher)

        setFullScreen()
    }

    class ThisTextWatcher : TextWatcher {

        //        var layout_wrap: LinearLayout? = null
        var ctx: ActivityAccountQueryResult? = null

        override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {

        }

        override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {

        }

        private fun createCell(s: String, oid: String) {
            val v = LinearLayout(ctx)
            val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ctx!!.toDp(30f))
            layout_params.gravity = Gravity.CENTER_VERTICAL

            v.layoutParams = layout_params

            val tv: TextView = TextView(ctx)
            tv.text = s
            tv.gravity = Gravity.CENTER_VERTICAL
            tv.setTextColor(ctx!!.resources!!.getColor(R.color.theme01_textColorMain))

            val tv2: TextView = TextView(ctx)
            tv2.text = "#${oid}"
            tv2.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
            tv2.setTextColor(ctx!!.resources!!.getColor(R.color.theme01_textColorNormal))

            val layout_params2 = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, ctx!!.toDp(30f))
            layout_params2.weight = 1.0f
            tv2.layoutParams = layout_params2

            v.addView(tv)
            v.addView(tv2)

            v.setOnClickListener {
                TempManager.sharedTempManager().call_query_account_callback(ctx!!, jsonObjectfromKVS("name", s, "id", oid))
            }

            ctx!!.layout_search!!.addView(v)
        }

        private fun isSearchMatched(account_name: String, searchText: String): Boolean {
            val idx = account_name.indexOf(searchText)
            return idx == 0
        }

        private fun processSearchResult(data_array: JSONArray, searchString: String) {
            ctx!!.layout_search!!.removeAllViews()

            //  筛选是否匹配
            val list = mutableListOf<JSONArray>()
            for (data in data_array.forin<JSONArray>()) {
                if (isSearchMatched(data!![0].toString(), searchString)) {
                    list.add(data)
                }
            }

            //  按照帐号名字长度升序排列（即匹配度高的排在前面） 比如 搜索：freedom16，那么 freedom168就排在freedom1613前面。
            list.sortBy { it[0].toString().length }

            //  添加到列表
            for (data in list) {
                createCell(data[0].toString(), data[1].toString())
            }
        }

        override fun afterTextChanged(s: Editable) {
            val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            val searchString = s.toString().toLowerCase()

            if (searchString.isNotEmpty()) {
                conn.async_exec_db("lookup_accounts", jsonArrayfrom(searchString, 20)).then {
                    ctx?.runOnMainUI {
                        processSearchResult(it as JSONArray, searchString)
                    }
                    return@then null
                }.catch {
                    //  TODO:toast
                }
            } else {
                ctx!!.layout_search!!.removeAllViews()
            }
        }
    }
}
