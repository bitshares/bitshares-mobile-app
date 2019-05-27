package com.btsplusplus.fowallet

import android.content.Context
import android.os.Bundle
import android.widget.TextView
import bitshares.*
import com.yanzhenjie.andserver.AndServer
import com.yanzhenjie.andserver.Server
import com.yanzhenjie.andserver.SimpleRequestHandler
import com.yanzhenjie.andserver.view.View
import com.yanzhenjie.andserver.website.AssetsWebsite
import kotlinx.android.synthetic.main.activity_wallet_backup.*
import org.apache.httpcore.HttpRequest
import org.apache.httpcore.HttpResponse
import org.apache.httpcore.entity.FileEntity
import java.io.File
import java.lang.Exception
import java.net.InetAddress
import java.text.SimpleDateFormat
import java.util.*

class ActivityWalletBackup : BtsppActivity() {

    private var _webserver: Server? = null
    private var _fullpath: String = ""
    private var _filename: String = ""

    override fun onDestroy() {
        _webserver?.shutdown()
        _webserver = null
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_wallet_backup)

        layout_back_from_backup_wallet.setOnClickListener { finish() }

        //  导出钱包
        if (backupWalletToWebdir()) {
            //  初始化webserver
            val nowifi = Utils.isWifi(this)
            if (!nowifi) {
                findViewById<TextView>(R.id.label_txt_address_or_error).text = resources.getString(R.string.kBackupWalletOnlyViaWIFI)
            } else {
                startInitWebserver(this)
            }
        } else {
            findViewById<TextView>(R.id.label_txt_address_or_error).text = resources.getString(R.string.registerLoginTipBackupError)
        }
    }

    /**
     *  (private) 备份钱包bin到web目录供用户下载。
     */
    private fun backupWalletToWebdir(): Boolean {
        val wallet_info = AppCacheManager.sharedAppCacheManager().getWalletInfo()
        val hex_wallet_bin = wallet_info.getString("kFullWalletBin")
        val wallet_bin = hex_wallet_bin.hexDecode()

        val prefix = SimpleDateFormat("yyyyMMdd").format(Date())
        _filename = "${prefix}_${wallet_info.getString("kAccountName")}.bin"
        _fullpath = "${OrgUtils.getAppDirWebServerImport()}${_filename}"

        //  [统计]
        btsppLogCustom("action_backupwallet", jsonObjectfromKVS("prefix", prefix, "account", wallet_info.optString("kAccountName", "")))

        return OrgUtils.write_file(_fullpath, wallet_bin)
    }

    /**
     * 下载文件
     */
    internal inner class DownloadHandler : SimpleRequestHandler() {
        override fun handle(request: HttpRequest?, response: HttpResponse?): View {
            val httpEntity = FileEntity(File(_fullpath))
            val view = com.yanzhenjie.andserver.view.View(200, httpEntity)
            view.addHeader("Content-Disposition", "attachment;filename=${_filename}")
            return view
        }
    }

    private fun startInitWebserver(context: Context) {
        if (_webserver != null) {
            return
        }
        val ipv4 = Utils.getIpv4Address(context)
        if (ipv4 == null) {
            findViewById<TextView>(R.id.label_txt_address_or_error).text = R.string.registerLoginWebServerErrorIp.xmlstring(context)
            return
        }
        //  REMARK：不能绑定到80端口，会出现无权限错误。
        val port = 9999
        val address = InetAddress.getByName(ipv4)
        val website = AssetsWebsite(context.assets, "www/${R.string.webserverDownloadPage.xmlstring(context)}")
        _webserver = AndServer.serverBuilder().port(port).inetAddress(address!!).website(website).registerHandler("/download", DownloadHandler()).listener(object : Server.ServerListener {
            override fun onStarted() {
                findViewById<TextView>(R.id.label_txt_address_or_error).text = "${ipv4}:${port}"
            }

            override fun onError(e: Exception) {
                btsppLogCustom("webserver_download_init_error", jsonObjectfromKVS("message", e.message
                        ?: "unknown"))
                findViewById<TextView>(R.id.label_txt_address_or_error).text = R.string.registerLoginWebServerErrorInit.xmlstring(context)
            }

            override fun onStopped() {
            }
        }).build()
        _webserver!!.startup()
    }
}
