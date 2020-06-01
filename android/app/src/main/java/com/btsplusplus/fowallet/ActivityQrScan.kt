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
import bitshares.*
import com.btsplusplus.fowallet.utils.StealthTransferUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import com.google.zxing.Result
import com.google.zxing.client.android.AutoScannerView
import com.google.zxing.client.android.BaseCaptureActivity
import com.google.zxing.utils.PicDecode
import kotlinx.android.synthetic.main.activity_qr_scan.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.net.URLDecoder

/**
 * 二维码扫描界面
 */
class ActivityQrScan : BaseCaptureActivity() {
    private var surfaceView: SurfaceView? = null
    private var autoScannerView: AutoScannerView? = null
    private val kRequestCodeFromAlbum = 1001

    private var _result_promise: Promise? = null

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

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _result_promise = args.opt("result_promise") as? Promise

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
                    val innerIntent = Intent()
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
                        innerIntent.action = Intent.ACTION_GET_CONTENT
                    } else {
                        innerIntent.action = Intent.ACTION_PICK
                    }
                    innerIntent.type = "image/*"
                    val wrapperIntent = Intent.createChooser(innerIntent, resources.getString(R.string.kVcScanAlbumClickedTips))
                    startActivityForResult(wrapperIntent, kRequestCodeFromAlbum)
                }
                EBtsppPermissionResult.SHOW_RATIONALE.value -> {
                    showToast(resources.getString(R.string.kVcScanPermissionUserRejected))
                }
                EBtsppPermissionResult.DONT_ASK_AGAIN.value -> {
                    showToast(resources.getString(R.string.kVcScanPermissionGotoSetting))
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
     *  二维码结果：私钥情况处理。
     */
    private fun _processScanResultAsPrivateKey(privateKey: String, pubkey: String, mask: ViewMask) {
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        conn.async_exec_db("get_key_references", jsonArrayfrom(jsonArrayfrom(pubkey))).then {
            val key_data_array = it as? JSONArray
            if (key_data_array == null || key_data_array.length() <= 0) {
                _gotoNormalResult(privateKey, mask)
                return@then null
            }
            val account_id_ary = key_data_array.optJSONArray(0)
            if (account_id_ary == null || account_id_ary.length() <= 0) {
                _gotoNormalResult(privateKey, mask)
                return@then null
            }
            return@then ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(account_id_ary.getString(0)).then {
                val full_data = it as? JSONObject
                if (full_data == null) {
                    _gotoNormalResult(privateKey, mask)
                    return@then null
                }
                //  转到私钥导入界面。
                mask.dismiss()
                goTo(ActivityScanResultPrivateKey::class.java, true, clear_navigation_stack = true, args = JSONObject().apply {
                    put("privateKey", privateKey)
                    put("publicKey", pubkey)
                    put("fullAccountData", full_data)
                })
                return@then null
            }
        }.catch {
            _gotoNormalResult(privateKey, mask)
        }
    }

    /**
     *  二维码结果：商家收款发票情况处理。
     */
    private fun _processScanResultAsMerchantInvoice(invoice: JSONObject, raw: String, mask: ViewMask) {
        _queryInvoiceDependencyData(invoice.optString("currency", null)?.toUpperCase(), invoice.optString("to", null)?.toLowerCase()).then {
            val data_array = it as? JSONArray
            var accountData: JSONObject? = null
            var assetData: JSONObject? = null
            if (data_array != null && data_array.length() == 2) {
                accountData = data_array.optJSONObject(0)
                assetData = data_array.optJSONObject(1)
            }
            if (accountData == null || assetData == null) {
                //  查询依赖数据失败：转到普通界面。
                _gotoNormalResult(invoice.toString(), mask)
            } else {
                //  转到账号名界面。
                mask.dismiss()

                //  计算付款金额
                var str_amount: String? = null
                invoice.optJSONArray("line_items")?.forEach<JSONObject> {
                    val price = it!!.optString("price", null)
                    val quantity = it.optString("quantity", null)
                    if (price != null && quantity != null) {
                        try {
                            val n_price = BigDecimal(price)
                            val n_quantity = BigDecimal(quantity)
                            str_amount = n_price.multiply(n_quantity).toPlainString()
                        } catch (e: Exception) {
                            //  NAN: not a number
                        }
                    }
                }

                //  可以不用登录（在支付界面再登录即可。）
                goTo(ActivityScanResultTransfer::class.java, true, clear_navigation_stack = true, args = JSONObject().apply {
                    put("to", accountData)
                    put("asset", assetData)
                    put("amount", str_amount)
                    put("memo", invoice.optString("memo", null))
                })
            }
            return@then null
        }
    }

    /**
     *  二维码结果：鼓鼓收款情况处理。
     */
    private fun _processScanResultAsMagicWalletReceive(result: String, pay_string: String, mask: ViewMask) {
        val ary = pay_string.split("/")
        val size = ary.size

        val account_id = if (size > 0) ary[0] else null
        val asset_name = if (size > 1) ary[1] else null
        val asset_amount = if (size > 2) ary[2] else null
        var memo = if (size > 3) ary[3] else null
        //  REMARK：memo采用urlencode编号，需要解码，非asc字符会出错。
        if (memo != null && memo != "") {
            memo = URLDecoder.decode(memo)
        }

        _queryInvoiceDependencyData(asset_name, account_id).then {
            val data_array = it as? JSONArray
            var accountData: JSONObject? = null
            var assetData: JSONObject? = null
            if (data_array != null && data_array.length() == 2) {
                accountData = data_array.optJSONObject(0)
                assetData = data_array.optJSONObject(1)
            }
            if (accountData == null || assetData == null) {
                //  查询依赖数据失败：转到普通界面。
                _gotoNormalResult(result, mask)
            } else {
                mask.dismiss()

                //  可以不用登录（在支付界面再登录即可。）
                goTo(ActivityScanResultTransfer::class.java, true, clear_navigation_stack = true, args = JSONObject().apply {
                    put("to", accountData)
                    put("asset", assetData)
                    put("amount", asset_amount)
                    put("memo", memo)
                })
            }
            return@then null
        }
    }

    /**
     *  (private) 查询收款依赖数据。
     */
    private fun _queryInvoiceDependencyData(asset: String?, to: String?): Promise {
        var currency = asset
        //  去掉bit前缀
        if (currency != null && currency.length > 3 && currency.indexOf("BIT") == 0) {
            currency = currency.substring(3)
        }
        return if (currency != null && to != null) {
            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            val p1 = chainMgr.queryAccountData(to)
            val p2 = chainMgr.queryAssetData(currency)
            Promise.all(p1, p2)
        } else {
            Promise._resolve(null)
        }
    }

    /**
     * 处理二维码识别or扫描的结果。
     */
    private fun processScanResultCore(result: String) {
        val mask = ViewMask(resources.getString(R.string.kVcScanProcessingResult), this)
        mask.show()

        //  1、判断是否是BTS私钥。
        val btsAddress = OrgUtils.genBtsAddressFromWifPrivateKey(result)
        if (btsAddress != null) {
            _processScanResultAsPrivateKey(result, btsAddress, mask)
            return
        }
        //  2、是不是比特股商家收款协议发票
        val invoice = OrgUtils.merchantInvoiceDecode(result)
        if (invoice != null) {
            _processScanResultAsMerchantInvoice(invoice, result, mask)
            return
        }

        //  3、是不是隐私收据判断。
        val blind_receipt_json = StealthTransferUtils.guessBlindReceiptString(result)
        if (blind_receipt_json != null) {
            mask.dismiss()
            //  转到导入收据界面
            goTo(ActivityBlindBalanceImport::class.java, true, clear_navigation_stack = true, args = JSONObject().apply {
                put("receipt", result)
            })
            return
        }

        //  4、是不是鼓鼓收款码  bts://r/1/#{account_id}/#{asset_name}/#{asset_amount}/#{memo}
        val magic_prefix = "bts://r/1/"
        if (result.indexOf(magic_prefix, ignoreCase = true) == 0) {
            _processScanResultAsMagicWalletReceive(result, result.substring(magic_prefix.length), mask)
            return
        }
        //  5、查询是不是比特股账号名or账号ID
        ChainObjectManager.sharedChainObjectManager().queryAccountData(result).then {
            val accountData = it as? JSONObject
            if (_isValidAccountData(accountData)) {
                //  转到账号名界面。
                mask.dismiss()
                goTo(ActivityScanAccountName::class.java, true, clear_navigation_stack = true, args = accountData!!)
            } else {
                //  其他：普通字符串
                _gotoNormalResult(result, mask)
            }
            return@then null
        }
    }

    private fun processScanResult(result: String) {
        result.trim().let { s ->
            if (_result_promise != null) {
                //  直接返回扫描结果
                _result_promise?.resolve(s)
                finish()
            } else {
                //  处理扫描结果
                if (s.isNotEmpty()) {
                    delay_main { processScanResultCore(s) }
                } else {
                    _gotoNormalResult(s)
                }
            }
        }
    }

    private fun _gotoNormalResult(result: String, mask: ViewMask? = null) {
        mask?.dismiss()
        goTo(ActivityScanResultNormal::class.java, true, clear_navigation_stack = true, args = jsonObjectfromKVS("result", result))
    }

    /**
     *  (private) 是否是有效的账号数据判断。
     */
    private fun _isValidAccountData(accountData: JSONObject?): Boolean {
        return accountData != null && accountData.has("id") && accountData.has("name")
    }

    override fun onBackPressed() {
        super.onBackPressed()
        finish()
    }

}
