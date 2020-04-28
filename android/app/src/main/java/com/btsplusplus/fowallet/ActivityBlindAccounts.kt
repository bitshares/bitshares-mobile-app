package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.LLAYOUT_MATCH
import bitshares.LLAYOUT_WARP
import bitshares.dp
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_blind_accounts.*
import org.json.JSONArray
import org.json.JSONObject

lateinit var _layout_account_list: LinearLayout
lateinit var _data_accounts: JSONArray

class ActivityBlindAccounts : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_accounts)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 初始化对象
        _layout_account_list = layout_account_list_of_blind_accounts

        _data_accounts = JSONArray()

        getData()
        refreshUI()


        // 右上角新增事件
        button_add_from_blind_accounts.setOnClickListener {
            onAddAccountClicked()
        }

        // 返回事件
        layout_back_from_blind_accounts.setOnClickListener { finish() }
    }

    private fun onAddAccountClicked(){
        ViewSelector.show(this, "", arrayOf("导入隐私账户","创建隐私账户")) { index: Int, result: String ->
            if (index === 0){
                goTo(ActivityBlindAccountImport::class.java, true)
            }
            if (index === 1){
                goTo(ActivityBlindBalanceImport::class.java, true)
            }
        }
    }

    private fun getData(){

        // Todo TEST DATA
        for (i in 0 until 5){
            _data_accounts.put(

                JSONObject().apply {
                    put("account_name","bob${i}")
                    put("account_address", "TEST5XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
                    put("sub_accounts", JSONArray().apply {

                        for (j in 0 until 2){
                            put(JSONObject().apply {

                                put("account_name",j.toString())
                                put("account_address", "TEST5XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")

                            })
                        }

                    })
                }
            )
        }
    }

    private fun createAccountCellCell(account_name: String, account_address: String, is_main_account: Boolean) : LinearLayout {
        val layout = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                setMargins(0, 0, 0, 10.dp)
            }
            orientation = LinearLayout.VERTICAL
        }

        // 账号名称
        val tv_account_name = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
            if (is_main_account){
                text = "主账户 ${account_name}"
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
            } else {
                text = "子账户 ${account_name}"
                setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            }
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15.0f)
        }

        // 账号地址
        val tv_account_address = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                setMargins(0, 10.dp, 0, 0)
            }
            text = account_address
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.5f)
            setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        }

        // 线
        val tv_line = ViewLine(this, 5.dp)

        layout.addView(tv_account_name)
        layout.addView(tv_account_address)
        layout.addView(tv_line)

        return layout
    }

    private fun createAccountView(data: JSONObject) : LinearLayout {
        val layout = LinearLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
                setMargins(0, 0, 0, 20.dp)
            }
            orientation = LinearLayout.VERTICAL
        }

        layout.addView(createAccountCellCell(data.getString("account_name"), data.getString("account_address"), true))
        data.getJSONArray("sub_accounts").forEach<JSONObject> {
            val _data = it!!
            layout.addView(createAccountCellCell(_data.getString("account_name"), _data.getString("account_address"), false))
        }

        return layout
    }

    private fun refreshUI(){
        _layout_account_list.removeAllViews()


        _data_accounts.forEach<JSONObject> {
            val data = it!!
            _layout_account_list.addView(createAccountView(data))
        }
    }
}
