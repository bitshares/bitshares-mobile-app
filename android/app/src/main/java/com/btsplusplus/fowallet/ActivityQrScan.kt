package com.btsplusplus.fowallet

import android.Manifest
import android.annotation.TargetApi
import android.app.Activity
import android.app.usage.UsageEvents
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.provider.MediaStore
import android.util.Log
import android.view.MotionEvent
import android.view.SurfaceView
import android.view.View

import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RelativeLayout
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast

import com.btsplusplus.fowallet.R
import com.google.zxing.Result
import com.google.zxing.client.android.AutoScannerView
import com.google.zxing.client.android.BaseCaptureActivity
import com.google.zxing.listener.ResultListener
import com.google.zxing.utils.PicDecode

import android.content.pm.PackageManager.PERMISSION_GRANTED

/**
 * 模仿微信的扫描界面
 */
class ActivityQrScan : BaseCaptureActivity() {
    private var getMaxZoomRunnable: Runnable? = null
    private var surfaceView: SurfaceView? = null
    private var autoScannerView: AutoScannerView? = null

    private var mTitle: TextView? = null
    private var lLeft: LinearLayout? = null
    private var lRight: LinearLayout? = null
    private var titlebarBackground: RelativeLayout? = null
    private var mSeekbar: SeekBar? = null
    private var mSelect: ImageView? = null
//    private val intent = Intent()
    private var isTorchOpenning = false

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent) {
        super.onActivityResult(requestCode, resultCode, data)
        val uri: Uri
        var uriTemp: Uri? = null
        if (resultCode == Activity.RESULT_OK) {//识别返回的本地二维码图片
            try {
                uriTemp = data.data
//                Log.e(tag, resultCode.toString() + "onActivityResult " + uriTemp!!.path)
            } catch (e: Exception) {
                e.printStackTrace()
            }

            if (uriTemp != null) {
                uri = uriTemp
            } else {

                return
            }
            //  TODO:
//            resultThread = Thread(Runnable {
//                try {
//                    bitmap = MediaStore.Images.Media.getBitmap(contentResolver, uri)
//
//                    result = PicDecode.scanImage(this@WeChatCaptureActivity, uri)!!.text
//
//                    if (result != "") {
//                        this@WeChatCaptureActivity.runOnUiThread { putResult(result) }
//                    } else {
//                        return@Runnable
//                    }
//                } catch (e: Exception) {
//                    result = "无结果"
//                    this@WeChatCaptureActivity.runOnUiThread { putResult(result) }
//                    e.printStackTrace()
//                    Log.e(tag, e.message)
//                }
//            })
//            resultThread!!.start()
        }
    }

    @TargetApi(Build.VERSION_CODES.M)
    override//检查摄像头权限
    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (checkSelfPermission(Manifest.permission.CAMERA) != PERMISSION_GRANTED) {
            toast("获取摄像头权限失败")
        }
        if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PERMISSION_GRANTED) {
            toast("获取内部存储权限失败")
        }
    }

    internal fun toast(s: String) {
        //  TODO:
//        Toast.makeText(this@WeChatCaptureActivity, s, Toast.LENGTH_SHORT).show()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_qr_scan)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (checkSelfPermission(Manifest.permission.CAMERA) != PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.CAMERA), 101)
            }
            if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), 102)
            }
        }

//        //---------------------------
        titlebarBackground = findViewById<View>(R.id.titlebar_background) as RelativeLayout
        surfaceView = findViewById<View>(R.id.preview_view) as SurfaceView
        autoScannerView = findViewById<View>(R.id.autoscanner_view) as AutoScannerView
        mTitle = findViewById<View>(R.id.titlebar_tv_title) as TextView
        lLeft = findViewById<View>(R.id.titlebar_ll_left) as LinearLayout
        lRight = findViewById<View>(R.id.titlebar_ll_right) as LinearLayout
        mSeekbar = findViewById<View>(R.id.zoom_seekbar) as SeekBar
//        mSelect = findViewById<View>(R.id.iv_select_photo) as ImageView
//        //---------------------------

        //---------------------------
        surfaceView!!.setOnTouchListener { v, event ->
            //触摸对焦
            if (event.action == MotionEvent.ACTION_DOWN) {
                getCameraManager().focus()
            }
            false
        }
//
//        lRight!!.setOnClickListener {
//            //闪光灯
//
//
//            if (isTorchOpenning) {
//                isTorchOpenning = false
//                lRight!!.setBackgroundColor(resources.getColor(R.color.transparent))
//            } else {
//                isTorchOpenning = true
//                lRight!!.setBackgroundColor(resources.getColor(R.color.viewfinder_mask))
//            }
//            getCameraManager().setTorch(isTorchOpenning)
//        }
//
//        lLeft!!.setOnClickListener { finish() }
//
//        mSelect!!.setOnClickListener { selectPic() }
//
//        mSeekbar!!.progress = 0//监听滑动栏数值，变焦
//        mSeekbar!!.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
//            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
//                getCameraManager().zoom(progress)
//            }
//
//            override fun onStartTrackingTouch(seekBar: SeekBar) {
//                if (mSeekbar!!.max == 0) {
////                    if (handlerZoom != null) {
////                        handlerZoom!!.postDelayed(getMaxZoomRunnable, 10)
////                    }
//                }
//            }
//
//            override fun onStopTrackingTouch(seekBar: SeekBar) {
//
//            }
//        })
//        //获取最大变焦值
//        getMaxZoomRunnable = Runnable {
//            var max = 0
//            try {
//                max = getCameraManager().maxZoom
//                Log.d("maxZoom", max.toString() + "")
//            } catch (e: Exception) {
//                e.printStackTrace()
//            }
//
//            runOnUiThread {
//                try {
//                    mSeekbar!!.max = max
//                } catch (e: Exception) {
//                    e.printStackTrace()
//                }
//            }
//        }
//        val handlerZoom = Handler()
//        handlerZoom!!.postDelayed(getMaxZoomRunnable, 100)


    }

    override fun onResume() {
        super.onResume()
        autoScannerView!!.setCameraManager(cameraManager)
    }

    override fun onDestroy() {
//        Log.d(tag, "回收内存")
//        colorPrimary = 0
//        mSelect!!.setImageResource(0)
//
//        if (resultThread != null) {
//            resultThread = null
//        }
//        if (handlerZoom != null) {
//            handlerZoom!!.removeCallbacksAndMessages(null)
//        }
//        handlerZoom = null
        System.gc()


        super.onDestroy()
    }

    override fun getSurfaceView(): SurfaceView {
        return if (surfaceView == null) findViewById<View>(R.id.preview_view) as SurfaceView else surfaceView!!
    }

    override fun dealDecode(rawResult: Result, barcode: Bitmap, scaleFactor: Float) {
//        result = rawResult.text
//        bitmap = null
//        putResult(result)
        //        对此次扫描结果不满意可以调用
        //        reScan();
    }

    private fun selectPic() {//选择本地二维码
        val innerIntent = Intent()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            innerIntent.action = Intent.ACTION_GET_CONTENT
        } else {
            innerIntent.action = Intent.ACTION_PICK
        }
        innerIntent.type = "image/*"
        val wrapperIntent = Intent.createChooser(innerIntent, "选择二维码图片")
        startActivityForResult(wrapperIntent, 1002)
    }

    private fun putResult(result: String) {//返回扫描结果
        intent.putExtra("result", result)
        playBeepSoundAndVibrate()
        setResult(1001, intent)//返回string结果
//        if (resultListener != null) {
//            resultListener!!.onResult(result)
//        }
        if (result !== "无结果") {
            delayFinish(100)
        }
    }


    private fun delayFinish(time: Long) {
        Handler().postDelayed({ finish() }, time)
    }

    override fun onBackPressed() {
        super.onBackPressed()
        finish()
    }

//    companion object {
//        var bitmap: Bitmap? = null
//        private val tag = "WeChatCaptureActivity"
//        private var colorPrimary = 0
//        private var title = "二维码扫描"
//        private var resultListener: ResultListener? = null
//        private var handlerZoom: Handler? = null
//        private var resultThread: Thread? = null
//        private var max = 0
//        var result: String
//
//
//        fun init(context: Activity, resultListener: ResultListener?, colorPrimary: Int, title: String) {
//            var colorPrimary = colorPrimary
//            try {//检查颜色是否为0
//                if (title != "") {
//                    this.title = title
//                }
//                if (colorPrimary == 0) {
//                    colorPrimary = context.resources.getColor(R.color.colorPrimary)
//                } else {
//                    Log.d(tag, colorPrimary.toString() + "")
//                }
//            } catch (e: Exception) {
//                colorPrimary = context.resources.getColor(R.color.colorPrimary)
//                e.printStackTrace()
//            }
//
//            this.colorPrimary = colorPrimary//主题色
//
//
//            if (resultListener != null) {//结果监听器
//                this.resultListener = resultListener
//            } else {
//                this.resultListener = null
//            }
//
//            bitmap = null
//            try {
//                context.startActivityForResult(Intent().setClass(context, this::class.java), 1001)
//            } catch (e: Exception) {
//                e.printStackTrace()
//            }
//
//        }
//    }
}
