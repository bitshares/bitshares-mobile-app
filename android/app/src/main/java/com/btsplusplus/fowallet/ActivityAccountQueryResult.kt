package com.btsplusplus.fowallet

import android.os.Bundle
import android.widget.EditText
import bitshares.GrapheneConnectionManager
import bitshares.TempManager
import bitshares.forin
import bitshares.jsonArrayfrom
import com.btsplusplus.fowallet.utils.ModelUtils
import kotlinx.android.synthetic.main.activity_account_query_result.*
import org.json.JSONArray
import org.json.JSONObject

class ActivityAccountQueryResult : BtsppActivity() {

    private var _searchType = ENetworkSearchType.enstAccount
    private lateinit var _tf_search_watcher: UtilsDigitTextWatcher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_account_query_result)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _searchType = args.get("kSearchType") as ENetworkSearchType

        //  初始化UI
        drawUI()

        //  事件 - 取消按钮
        text_cancel_from_service_account_query.setOnClickListener { view ->
            this.hideSoftKeyboard()
            finish()
        }

        //  输入框
        val tf = findViewById<EditText>(R.id.tf_search_field)
        _tf_search_watcher = UtilsDigitTextWatcher().set_tf(tf).set_alpha_text_inputfield(true)
        tf.addTextChangedListener(_tf_search_watcher)
        _tf_search_watcher.on_value_changed(::onSearchTextChanged)
    }

    private fun drawUI() {
        when (_searchType) {
            ENetworkSearchType.enstAccount -> {
                tf_search_field.hint = resources.getString(R.string.kSearchPlaceholderAccount)
            }
            ENetworkSearchType.enstAssetAll, ENetworkSearchType.enstAssetSmart, ENetworkSearchType.enstAssetUIA -> {
                tf_search_field.hint = resources.getString(R.string.kSearchPlaceholderAsset)
            }
            else -> assert(false)
        }
    }

    /**
     *  (private) 搜索字符串发生变化。
     */
    private fun onSearchTextChanged(str_search_text: String) {
        val api_name: String
        val searchString: String

        when (_searchType) {
            ENetworkSearchType.enstAccount -> {
                api_name = "lookup_accounts"
                searchString = str_search_text.toLowerCase()
            }
            else -> {
                api_name = "list_assets"
                searchString = str_search_text.toUpperCase()
            }
        }

        if (searchString.isNotEmpty()) {
            val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            conn.async_exec_db(api_name, jsonArrayfrom(searchString, 20)).then {
                processSearchResult(it as JSONArray, searchString)
                return@then null
            }.catch {
                //  TODO:toast
            }
        } else {
            processSearchResult(null, searchString)
        }
    }

    private fun isSearchMatched(account_name: String, searchText: String): Boolean {
        val idx = account_name.indexOf(searchText)
        return idx == 0
    }

    private fun processSearchResult(data_array: JSONArray?, searchString: String) {
        //  已经关闭，不处理搜索结果。
        if (isFinishing) {
            return
        }

        //  清空
        lyt_search_result_view.removeAllViews()

        //  筛选是否匹配
        if (data_array != null) {
            when (_searchType) {
                ENetworkSearchType.enstAccount -> _onSearchAccount(data_array, searchString)
                ENetworkSearchType.enstAssetAll, ENetworkSearchType.enstAssetUIA, ENetworkSearchType.enstAssetSmart -> _onSearchAsset(data_array, searchString)
                else -> assert(false)
            }
        }
    }

    private fun _onSearchAccount(data_array: JSONArray, searchString: String) {
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
            val name = data[0].toString()
            val oid = data[1].toString()
            val v = ViewUtils.auxGenSearchAccountLineView(this, name, oid, data) {
                TempManager.sharedTempManager().call_query_account_callback(this, JSONObject().apply {
                    put("name", name)
                    put("id", oid)
                })
            }
            lyt_search_result_view.addView(v)
        }
    }

    private fun _onSearchAsset(data_array: JSONArray, searchString: String) {
        val list = mutableListOf<JSONObject>()
        for (asset in data_array.forin<JSONObject>()) {
            val symbol = asset!!.getString("symbol")

            if (_searchType == ENetworkSearchType.enstAssetSmart) {
                //  跳过UIA
                if (!ModelUtils.assetIsSmart(asset)) {
                    continue
                }
            } else if (_searchType == ENetworkSearchType.enstAssetUIA) {
                //  跳过智能币
                if (ModelUtils.assetIsSmart(asset)) {
                    continue
                }
            }

            if (isSearchMatched(symbol, searchString)) {
                list.add(asset)
            }
        }
        //  按照帐号名字长度升序排列（即匹配度高的排在前面） 比如 搜索：freedom16，那么 freedom168就排在freedom1613前面。
        list.sortBy { it.getString("symbol").length }

        //  添加到列表
        for (data in list) {
            val v = ViewUtils.auxGenSearchAccountLineView(this, data.getString("symbol"), data.getString("id"), data) {
                TempManager.sharedTempManager().call_query_account_callback(this, it as JSONObject)
            }
            lyt_search_result_view.addView(v)
        }
    }

}
