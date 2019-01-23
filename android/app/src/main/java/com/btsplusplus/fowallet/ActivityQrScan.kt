package com.btsplusplus.fowallet

//import com.dlazaro66.qrcodereaderview.QRCodeReaderView
import android.content.pm.PackageManager
import android.graphics.PointF
import android.os.Bundle
import android.support.v4.app.ActivityCompat
import android.support.v4.content.ContextCompat
import com.qingmei2.library.view.QRCodeScannerView
import kotlinx.android.synthetic.main.activity_qr_scan.*

//  TODO: pending

// 实现 QRCodeReaderView.OnQRCodeReadListener
class ActivityQrScan : BtsppActivity() {

    private lateinit var qrCodeReaderView: QRCodeScannerView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_qr_scan)

        qrCodeReaderView = findViewById(R.id.qrdecoderview)


//        qrCodeReaderView.setOnQRCodeReadListener(this)
//
//        // Use this function to enable/disable decoding
//        qrCodeReaderView.setQRDecodingEnabled(true)
//
//        // Use this function to change the autofocus interval (default is 5 secs)
        qrCodeReaderView.setAutofocusInterval(500L)
//
//        // Use this function to enable/disable Torch
//        qrCodeReaderView.setTorchEnabled(true)
//
//        // Use this function to set front camera preview
//        qrCodeReaderView.setFrontCamera()
//
//        // Use this function to set back camera preview
//        qrCodeReaderView.setBackCamera()

//        val callback :
        qrCodeReaderView.setOnQRCodeReadListener { text: String?, points: Array<out PointF>? ->
            Unit
            showToast(text!!, 2)
        }
//        qrCodeReaderView.setOnCheckCameraPermissionListener {  }
//        QRCodeScannerView.OnCheckCameraPermissionListener {  }
        qrCodeReaderView.setOnCheckCameraPermissionListener(QRCodeScannerView.OnCheckCameraPermissionListener {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                true
            } else {
                ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.CAMERA), 1)
                false
            }
        })
        qrCodeReaderView.setBackCamera()


        // 返回按钮事件
        layout_back_from_qrscan.setOnClickListener {
            finish()
        }

    }

//    // Called when your device have no camera
//    fun cameraNotFound() {
//        showToast("camera not found",2)
//    }
//
//    // Called when there's no QR codes in the camera preview image
//    fun QRCodeNotFoundOnCamImage() {
//
//    }
//
//    override fun onQRCodeRead(text: String?, points: Array<out PointF>?) {
//        showToast(text!!,2)
//    }
//
//    override protected fun onResume(){
//        super.onResume()
//        qrCodeReaderView.startCamera()
//    }
//
//    override fun onPause() {
//        super.onPause()
//        qrCodeReaderView.stopCamera()
//    }

}
