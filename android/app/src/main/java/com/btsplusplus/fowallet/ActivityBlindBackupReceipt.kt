package com.btsplusplus.fowallet

import android.graphics.Bitmap
import android.os.Bundle
import bitshares.Utils
import kotlinx.android.synthetic.main.activity_blind_backup_receipt.*

class ActivityBlindBackupReceipt : BtsppActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_blind_backup_receipt)

        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        val blind_receipt_string = args.getString("blind_receipt_string")

        //  初始化UI - 二维码
        iv_qrcode_from_blind_backup_receipt.setImageBitmap(args.get("qrbitmap") as Bitmap)

        //  UI - 收据信息
        tv_blind_receipt_string.text = blind_receipt_string

        //  复制按钮点击
        btn_copy_blind_receipt.setOnClickListener { onCopyAddressClicked(blind_receipt_string) }

        //  完成点击
        btn_navi_left_done.setOnClickListener { onDoneClicked() }
        btn_done.setOnClickListener { onDoneClicked() }
    }

    private fun onDoneClicked() {
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips),
                resources.getString(R.string.kVcStTipAskConfrimForCloseBackupReceiptUI)).then {
            if (it != null && it as Boolean) {
                //  关闭
                finish()
            }
        }
    }

    private fun onCopyAddressClicked(blind_receipt_string: String) {
        if (Utils.copyToClipboard(this, blind_receipt_string)) {
            showToast(resources.getString(R.string.kVcStTipReceiptBackupCopied))
        }
    }
}
