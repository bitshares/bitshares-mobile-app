package com.btsplusplus.fowallet

import android.graphics.Bitmap
import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.widget.TextView
import bitshares.Utils
import bitshares.dp
import bitshares.xmlstring
import kotlinx.android.synthetic.main.activity_blind_backup_receipt.*

class ActivityBlindBackupReceipt : BtsppActivity() {

    lateinit var _tv_receipt_address: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_backup_receipt)

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        val receipt_address = "22MZXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

        // qrcode
        Utils.asyncCreateQRBitmap(receipt_address, 150.dp).then { bitmap ->
            iv_qrcode_from_blind_backup_receipt.setImageBitmap(bitmap as Bitmap)
        }

        // 收据地址
        _tv_receipt_address = tv_receipt_address_from_blind_backup_receipt
        _tv_receipt_address.text = receipt_address

        // 复制按钮点击
        btn_copy_from_blind_backup_receipt.setOnClickListener {
            onCopyAddressClicked()
        }

        // 完成点击
        layout_finish_from_blind_backup_receipt.setOnClickListener {

        }

    }

    private fun onCopyAddressClicked() {
        if (Utils.copyToClipboard(this, _tv_receipt_address.text.toString())) {
            showToast(R.string.kVcDWTipsCopyAddrOK.xmlstring(this))
        }
    }
}
