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
import bitshares.Promise
import com.google.zxing.Result
import com.google.zxing.client.android.AutoScannerView
import com.google.zxing.client.android.BaseCaptureActivity
import com.google.zxing.utils.PicDecode
import kotlinx.android.synthetic.main.activity_qr_scan.*

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
        //  TODO:
        showToast(result)
    }

    override fun onBackPressed() {
        super.onBackPressed()
        finish()
    }

}
