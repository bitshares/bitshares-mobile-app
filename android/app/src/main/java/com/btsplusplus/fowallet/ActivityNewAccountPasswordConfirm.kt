package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.EditText
import android.widget.TextView
import kotlinx.android.synthetic.main.activity_new_account_password_confirm.*
import org.json.JSONArray

class ActivityNewAccountPasswordConfirm : BtsppActivity() {

    lateinit var _et_password:EditText
    lateinit var _tv_select_account_permission:TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_new_account_password_confirm)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        _et_password = et_password_from_new_account_password_confirm
        _tv_select_account_permission = tv_select_account_arrow_from_new_account_permission_password_confirm

        // 账号名
        tv_account_name_from_new_account_password_confirm.text = "Saya07"

        // 选择账号
        layout_select_account_permission_from_new_account_password_confirm.setOnClickListener { onSelectAccountPermission() }

        // 箭头颜色
        iv_select_account_arrow_from_new_account_permission_password_confirm.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

        // 提交事件
        btn_submit_from_new_account_password_confirm.setOnClickListener { onBtnSubmit() }

        // 返回
        layout_back_from_new_account_password_confirm.setOnClickListener { finish() }

    }

    private fun onBtnSubmit(){

    }

    private fun onSelectAccountPermission(){
        val array_select = JSONArray().apply {
            put("修改账号和资金权限")
            put("修改资金权限")
            put("修改账号权限")
        }
        array_select.put("")
        var default_select = 0
        ViewDialogNumberPicker(this, "", array_select, null, default_select) { _index: Int, text: String ->
            _tv_select_account_permission.text = text
        }.show()

    }
}
