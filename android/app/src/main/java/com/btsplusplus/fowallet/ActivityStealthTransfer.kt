package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import kotlinx.android.synthetic.main.activity_stealth_transfer.*

class ActivityStealthTransfer : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_stealth_transfer)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 返回事件
        layout_back_from_stealth_transfer.setOnClickListener { finish() }


        // 点击跳转事件
        layout_account_manage_from_stealth_transfer.setOnClickListener {
            OnAccountManageClicked()
        }
        layout_my_receipt_from_stealth_transfer.setOnClickListener {
            onMyReceiptClicked()
        }
        layout_transfer_to_blind_from_stealth_transfer.setOnClickListener {
            onTransferToBlindClicked()
        }
        layout_transfer_from_blind_from_stealth_transfer.setOnClickListener {
            onTransferFromBlindClicked()
        }
        layout_blind_transfer_from_stealth_transfer.setOnClickListener {
            onBlindTransferClicked()
        }

        // 设置箭头颜色
        iv_account_manage_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        iv_my_receipt_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        iv_transfer_to_blind_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        iv_transfer_from_blind_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))
        iv_blind_transfer_right_arrow_from_stealth_transfer.setColorFilter(resources.getColor(R.color.theme01_textColorGray))

    }

    private fun OnAccountManageClicked(){

    }

    private fun onMyReceiptClicked(){

    }

    private fun onTransferToBlindClicked(){
        goTo(ActivityTransferToBlind::class.java, true)
    }

    private fun onTransferFromBlindClicked(){
        goTo(ActivityTransferFromBlind::class.java, true)
    }

    private fun onBlindTransferClicked(){
        goTo(ActivityBlindTransfer::class.java, true)
    }




}
