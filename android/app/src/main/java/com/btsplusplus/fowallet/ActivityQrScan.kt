package com.btsplusplus.fowallet

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.view.MotionEvent
import android.view.SurfaceView
import android.view.View
import bitshares.OrgUtils
import bitshares.Promise
import bitshares.delay_main
import bitshares.jsonObjectfromKVS
import com.fowallet.walletcore.bts.ChainObjectManager
import com.google.zxing.Result
import com.google.zxing.client.android.AutoScannerView
import com.google.zxing.client.android.BaseCaptureActivity
import com.google.zxing.utils.PicDecode
import kotlinx.android.synthetic.main.activity_qr_scan.*
import org.json.JSONObject

/**
 * 二维码扫描界面
 */
class ActivityQrScan : BaseCaptureActivity() {
    private var surfaceView: SurfaceView? = null
    private var autoScannerView: AutoScannerView? = null
    private val kRequestCodeFromAlbum = 1001

    private fun _auto_identify_qrcode(data: Intent?): Promise {
        val p = Promise()
        Thread(Runnable {
            try {
                val uri = data?.data
                if (uri != null) {
                    val result = PicDecode.scanImage(this, uri)?.text
                    p.resolve(result)
                } else {
                    p.resolve(null)
                }
            } catch (e: Exception) {
                p.resolve(null)
            }
        }).start()
        return p
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode == Activity.RESULT_OK && requestCode == kRequestCodeFromAlbum) {
            _auto_identify_qrcode(data).then {
                val result = it as? String
                if (result != null) {
                    processScanResult(result)
                } else {
                    showToast(resources.getString(R.string.kVcScanNoQrCode))
                }
                return@then null
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_qr_scan)
        setFullScreen()

        surfaceView = findViewById<View>(R.id.preview_view) as SurfaceView
        autoScannerView = findViewById<View>(R.id.autoscanner_view) as AutoScannerView

        surfaceView!!.setOnTouchListener { _, event ->
            //  触摸对焦
            if (event.action == MotionEvent.ACTION_DOWN) {
                getCameraManager().focus()
            }
            return@setOnTouchListener false
        }

        //  事件
        btn_back.setOnClickListener { finish() }
        btn_album.setOnClickListener { onAlbumClicked() }
    }

    private fun onAlbumClicked() {
        this.guardPermissions(Manifest.permission.READ_EXTERNAL_STORAGE).then {
            when (it as Int) {
                EBtsppPermissionResult.GRANTED.value -> {
                    //  TODO:多语言
                    val innerIntent = Intent()
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
                        innerIntent.action = Intent.ACTION_GET_CONTENT
                    } else {
                        innerIntent.action = Intent.ACTION_PICK
                    }
                    innerIntent.type = "image/*"
                    val wrapperIntent = Intent.createChooser(innerIntent, "选择二维码图片")
                    startActivityForResult(wrapperIntent, kRequestCodeFromAlbum)
                }
                EBtsppPermissionResult.SHOW_RATIONALE.value -> {
                    showToast("请允许访问相册：${it}")
                }
                EBtsppPermissionResult.DONT_ASK_AGAIN.value -> {
                    showToast("请允许访问相册：${it}")
                }
            }
            return@then null
        }
    }

    override fun onResume() {
        super.onResume()
        autoScannerView!!.setCameraManager(cameraManager)
    }

    override fun getSurfaceView(): SurfaceView {
        return if (surfaceView == null) findViewById<View>(R.id.preview_view) as SurfaceView else surfaceView!!
    }

    override fun dealDecode(rawResult: Result, barcode: Bitmap, scaleFactor: Float) {
        processScanResult(rawResult.text)
    }

    /**
     * 处理二维码识别or扫描的结果。
     */
    private fun processScanResult(result: String) {
        val s = result.trim()
        if (s.isEmpty()) {
            _gotoNormalResult(s)
            return
        }
        delay_main {
            val mask = ViewMask(resources.getString(R.string.kVcScanProcessingResult), this)
            mask.show()
            //  1、判断是否是BTS私钥。
            val btsAddress = OrgUtils.genBtsAddressFromWifPrivateKey(s)
            if (btsAddress != null) {
                //  TODO:
            }
            //  2、是不是比特股商家收款协议发票
            //  TODO:
            //  3、是不是鼓鼓收款码  bts://r/1/#{account_id}/#{asset_name}/#{asset_amount}/#{memo}
            if (s.indexOf("bts://r/1/", ignoreCase = true) == 0) {
                //  TODO:
            }
            //  4、查询是不是比特股账号名or账号ID
            ChainObjectManager.sharedChainObjectManager().queryAccountData(s).then {
                val accountData = it as? JSONObject
                if (_isValidAccountData(accountData)) {
                    //  转到账号名界面。
                    mask.dismiss()
                    goTo(ActivityScanAccountName::class.java, true, close_self = true, args = accountData!!)
                } else {
                    //  其他：普通字符串
                    _gotoNormalResult(s, mask)
                }
                return@then null
            }
        }
    }

    private fun _gotoNormalResult(result: String, mask: ViewMask? = null) {
        mask?.dismiss()
        goTo(ActivityScanResultNormal::class.java, true, close_self = true, args = jsonObjectfromKVS("result", result))
    }

    /**
     *  (private) 是否是有效的账号数据判断。
     */
    fun _isValidAccountData(accountData: JSONObject?): Boolean {
        return accountData != null && accountData.has("id") && accountData.has("name")
    }

    override fun onBackPressed() {
        super.onBackPressed()
        finish()
    }

}
