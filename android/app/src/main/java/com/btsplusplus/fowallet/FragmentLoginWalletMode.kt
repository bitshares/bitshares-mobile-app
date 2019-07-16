package com.btsplusplus.fowallet

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.support.v4.app.Fragment
import android.text.TextUtils
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import com.yanzhenjie.andserver.AndServer
import com.yanzhenjie.andserver.RequestHandler
import com.yanzhenjie.andserver.Server
import com.yanzhenjie.andserver.upload.HttpFileUpload
import com.yanzhenjie.andserver.upload.HttpUploadContext
import com.yanzhenjie.andserver.util.HttpRequestParser
import com.yanzhenjie.andserver.website.AssetsWebsite
import org.apache.commons.fileupload.disk.DiskFileItemFactory
import org.apache.httpcore.HttpEntityEnclosingRequest
import org.apache.httpcore.HttpRequest
import org.apache.httpcore.HttpResponse
import org.apache.httpcore.entity.StringEntity
import org.apache.httpcore.protocol.HttpContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.lang.Exception
import java.net.InetAddress

// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentLoginWalletMode.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentLoginWalletMode.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentLoginWalletMode : Fragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null
    private var listener: OnFragmentInteractionListener? = null

    private var _view: View? = null
    private var _ctx: Context? = null
    private var _webserver: Server? = null
    private var _importdir: String = ""
    private var _address: String? = null
    private var _dataArray = mutableListOf<JSONObject>()
    private var _inBackground: Boolean = true

    override fun onDestroy() {
        _webserver?.shutdown()
        super.onDestroy()
    }

    override fun onPause() {
        _inBackground = true
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        _inBackground = false
        if (_ctx != null) {
            _refreshFileListUI(_ctx!!)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            param1 = it.getString(ARG_PARAM1)
            param2 = it.getString(ARG_PARAM2)
        }
    }

    fun init(): FragmentLoginWalletMode {
        _importdir = OrgUtils.getAppDirWebServerImport()
        loadUploadDirFileList()
        return this
    }

    private fun loadUploadDirFileList() {
        _dataArray.clear()
        try {
            val list = File(_importdir).listFiles()
            list?.forEach {
                if (it.isFile) {
                    _dataArray.add(jsonObjectfromKVS("path", it.path, "name", it.name))
                }
            }
        } catch (e: Exception) {
            btsppLogCustom("webserver_scandir_error", jsonObjectfromKVS("message", e.message
                    ?: "unknown"))
        }
    }

    /**
     * 重新扫描文件、并刷新列表。
     */
    private fun refreshRecvFileList() {
        loadUploadDirFileList()
        _refreshFileListUI(_ctx!!)
    }

    private fun _refreshFileListUI(ctx: Context) {
        if (_inBackground) {
            return
        }
        val title_fmt = if (_webserver != null) R.string.kLoginTipsReceivedFileNumber.xmlstring(_ctx!!) else R.string.kLoginTipsLocalWalletFileNumber.xmlstring(_ctx!!)
        _view!!.findViewById<TextView>(R.id.label_txt_recv_n).text = String.format(title_fmt, _dataArray.size.toString())
        val layout = _view!!.findViewById<LinearLayout>(R.id.layout_select_file_of_fragment_login_wallet_mode)
        layout.removeAllViews()
        if (_dataArray.size > 0) {
            _dataArray.forEach {
                val data = it

                val cell = LinearLayout(ctx)
                val layout_params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 30.dp)
                layout_params.gravity = Gravity.CENTER_VERTICAL
                cell.layoutParams = layout_params

                //  名字
                val lbl_name = TextView(ctx)
                lbl_name.text = data.getString("name")
                lbl_name.gravity = Gravity.CENTER_VERTICAL
                lbl_name.setSingleLine(true)
                lbl_name.maxLines = 1
                lbl_name.ellipsize = TextUtils.TruncateAt.END
                lbl_name.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 4f)
                lbl_name.setTextColor(resources.getColor(R.color.theme01_textColorMain))
                cell.addView(lbl_name)

                //  导入
                val lbl_import = TextView(ctx)
                lbl_import.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 2f)
                lbl_import.text = _ctx!!.resources.getString(R.string.kLoginCellClickImport)
                lbl_import.gravity = Gravity.CENTER_VERTICAL or Gravity.RIGHT
                lbl_import.setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                cell.addView(lbl_import)

                //  绑定事件
                cell.setOnLongClickListener {
                    onRemoveWalletFile(ctx, data)
                    return@setOnLongClickListener true
                }
                cell.setOnClickListener {
                    onSelectWalletFile(ctx, data)
                }

                layout.addView(cell)
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        // Inflate the layout for this fragment
        _view = inflater.inflate(R.layout.fragment_login_wallet_mode, container, false)
        _ctx = inflater.context
        //  初始化webserver
        if (Utils.isWifi(_ctx!!)) {
            startInitWebserver(_ctx!!)
        } else {
            _view!!.findViewById<TextView>(R.id.text_ip_of_back_wallet).text = R.string.kLoginTipsOnlyViaWifiMainDesc.xmlstring(_ctx!!)
            _view!!.findViewById<TextView>(R.id.init_desc_message).text = R.string.kLoginTipsImportOnlyViaWIFI.xmlstring(_ctx!!)
        }
        return _view
    }

    /**
     * 上传文件
     */
    internal inner class UploadHandler : RequestHandler {
        override fun handle(request: HttpRequest, response: HttpResponse, context: HttpContext) {
            try {
                if (!HttpRequestParser.isMultipartContentRequest(request)) {
                    on_response(403, _ctx!!.resources.getString(R.string.registerLoginPageInvalidRequesting), response)
                }
                processFileUpload(request)
                on_response(200, _ctx!!.resources.getString(R.string.registerLoginPageUploadSuccessPleaseContinueForPhone), response)
            } catch (e: Exception) {
                btsppLogCustom("webserver_upload_error", jsonObjectfromKVS("message", e.message
                        ?: "unknown"))
                on_response(500, _ctx!!.resources.getString(R.string.registerLoginPageServerInternalError), response)
            }
        }

        private fun on_response(responseCode: Int, message: String, response: HttpResponse) {
            response.setStatusCode(responseCode)
            response.entity = StringEntity(message, "utf-8")
        }

        private fun processFileUpload(request: HttpRequest) {
            println(_importdir)
            val factory = DiskFileItemFactory(1024 * 1024, File(_importdir))
            val fileUpload = HttpFileUpload(factory)

            val context = HttpUploadContext(request as HttpEntityEnclosingRequest)
            val fileItems = fileUpload.parseRequest(context)

            var upload_ok: Boolean = false
            for (fileItem in fileItems) {
                if (!fileItem.isFormField) {
                    val name = fileItem.name
                    // val size = fileItem.size
                    val uploadedFile = File(_importdir, name)

                    val uploadFileDir = File(_importdir)
                    if (!uploadFileDir.exists()) {
                        uploadFileDir.mkdirs()
                    }
                    try {
                        fileItem.write(uploadedFile)
                    } catch (e: Exception) {
                        println(e.message.toString())
                    }
                    upload_ok = true
                }
            }
            //  刷新
            if (upload_ok) {
                delay_main {
                    refreshRecvFileList()
                }
            }
        }
    }

    private fun startInitWebserver(context: Context) {
        if (_webserver != null) {
            if (_address != null) {
                _view!!.findViewById<TextView>(R.id.text_ip_of_back_wallet).text = _address!!
            }
            return
        }
        val ipv4 = Utils.getIpv4Address(context)
        if (ipv4 == null) {
            _view!!.findViewById<TextView>(R.id.text_ip_of_back_wallet).text = _ctx!!.resources.getString(R.string.registerLoginWebServerErrorIp)
            return
        }
        //  REMARK：不能绑定到80端口，会出现无权限错误。
        val port = 9999
        val address = InetAddress.getByName(ipv4)
        val website = AssetsWebsite(context.assets, "www/${R.string.webserverUploadPage.xmlstring(context)}")
        _webserver = AndServer.serverBuilder().port(port).inetAddress(address!!).website(website).registerHandler("/upload", UploadHandler()).listener(object : Server.ServerListener {
            override fun onStarted() {
                _address = "${ipv4}:${port}"
                _view!!.findViewById<TextView>(R.id.text_ip_of_back_wallet).text = _address!!
            }

            override fun onError(e: Exception) {
                btsppLogCustom("webserver_upload_init_error", jsonObjectfromKVS("message", e.message
                        ?: "unknown"))
                _address = _ctx!!.resources.getString(R.string.registerLoginWebServerErrorInit)
                _view!!.findViewById<TextView>(R.id.text_ip_of_back_wallet).text = _address!!
            }

            override fun onStopped() {
            }
        }).build()
        _webserver!!.startup()
    }

    /**
     * 删除操作
     */
    private fun onRemoveWalletFile(ctx: Context, data: JSONObject) {
        UtilsAlert.showMessageConfirm(ctx, ctx.resources.getString(R.string.kWarmTips), String.format(ctx.resources.getString(R.string.registerLoginPageTipForDeleteFileForThisPhone), data.getString("name")), btn_ok = _ctx!!.resources.getString(R.string.kProposalCellBtnDelete), btn_cancel = _ctx!!.resources.getString(R.string.registerLoginPageClickWrong)).then {
            if (it != null && it as Boolean) {
                val file = File(data.getString("path"))
                if (file.exists() && file.isFile) {
                    if (file.delete()) {
                        System.gc()
                        //  刷新
                        refreshRecvFileList()
                    }
                }
            }
        }
    }

    /**
     * 导入操作
     */
    private fun onSelectWalletFile(ctx: Context, data: JSONObject) {
        UtilsAlert.showInputBox(ctx, ctx.resources.getString(R.string.kLoginTipsImportWalletTitle), ctx.resources.getString(R.string.unlockTipsPleaseInputWalletPassword), ctx.resources.getString(R.string.kLoginBtnImportNow)).then {
            val password = it as? String
            if (password != null) {
                processImportWalletCore(password, data)
            }
        }
    }

    private fun processImportWalletCore(wallet_password: String, data: JSONObject) {
        if (wallet_password == "") {
            showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsPleaseInputPassword))
            return
        }
        //  加载钱包对象
        val wallet_bindata = OrgUtils.load_file(data.getString("path"))
        if (wallet_bindata == null) {
            showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsReadWalletFailed))
            return
        }

        val walletMgr = WalletManager.sharedWalletManager()
        val wallet_object = walletMgr.loadFullWallet(wallet_bindata, wallet_password)
        if (wallet_object == null) {
            showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsInvalidFileOrPassword))
            return
        }

        //  加载成功判断钱包有效性
        val wallet = wallet_object.getJSONArray("wallet").getJSONObject(0)
        if (wallet.getString("chain_id") != ChainObjectManager.sharedChainObjectManager().grapheneChainID) {
            showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsNotBTSWallet))
            return
        }

        val linked_accounts = wallet_object.optJSONArray("linked_accounts")
        if (linked_accounts == null || linked_accounts.length() <= 0) {
            showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsWalletIsEmpty))
            return
        }

        val first_account = linked_accounts.getJSONObject(0)
        val first_name = first_account.getString("name")

        val private_keys = wallet_object.optJSONArray("private_keys")
        if (private_keys == null || private_keys.length() <= 0) {
            showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsWalletNoPrivateKey))
            return
        }

        val pubkey_list = JSONArray()
        val pubkey_keyitem_hash = JSONObject()
        private_keys.forEach<JSONObject> {
            val key_item = it!!
            val pubkey = key_item.getString("pubkey")
            pubkey_list.put(pubkey)
            pubkey_keyitem_hash.put(pubkey, key_item)
        }

        //  查询 Key 详情
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(this.activity!!), this.activity!!)
        mask.show()
        ChainObjectManager.sharedChainObjectManager().queryAccountDataHashFromKeys(pubkey_list).then {
            val account_data_hash = it as JSONObject
            if (account_data_hash.length() <= 0) {
                mask.dismiss()
                showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsWalletIsEmpty))
                return@then null
            }
            //  获取当前账号
            var currentAccountData: JSONObject? = null
            account_data_hash.values().forEach<JSONObject> {
                val account_data = it!!
                if (currentAccountData == null || first_name == account_data.getString("name")) {
                    currentAccountData = account_data
                }
            }
            //  查询当前账号的详细信息
            val current_account_id = currentAccountData!!.getString("id")
            val current_accout_name = currentAccountData!!.getString("name")

            return@then ChainObjectManager.sharedChainObjectManager().queryFullAccountInfo(current_account_id).then {
                mask.dismiss()
                val full_data = it as? JSONObject
                if (full_data == null) {
                    showToast(_ctx!!.resources.getString(R.string.kLoginImportTipsQueryAccountFailed))
                    return@then null
                }

                //  导入钱包不用验证active权限，允许无权限导入。

                //  保存钱包信息
                AppCacheManager.sharedAppCacheManager().setWalletInfo(AppCacheManager.EWalletMode.kwmFullWalletMode.value,
                        full_data, current_accout_name, wallet_bindata)
                //  导入成功 直接解锁。
                val unlockInfos = walletMgr.unLock(wallet_password, _ctx!!)
                assert(unlockInfos.getBoolean("unlockSuccess") && unlockInfos.optBoolean("haveActivePermission"))

                //  返回之前先关闭webserver
                _webserver?.shutdown()
                _webserver = null

                //  [统计]
                btsppLogCustom("loginEvent", jsonObjectfromKVS("mode", AppCacheManager.EWalletMode.kwmFullWalletMode.value, "desc", "wallet"))

                //  返回
                showToast(_ctx!!.resources.getString(R.string.kLoginTipsLoginOK))
                activity!!.finish()

                return@then null
            }
        }.catch {
            mask.dismiss()
            showToast(_ctx!!.resources.getString(R.string.tip_network_error))
        }
    }

    // TODO: Rename method, update argument and hook method into UI event
    fun onButtonPressed(uri: Uri) {
        listener?.onFragmentInteraction(uri)
    }

//    override fun onAttach(context: Context) {
//        super.onAttach(context)
//        if (context is OnFragmentInteractionListener) {
//            listener = context
//        } else {
//            throw RuntimeException(context.toString() + " must implement OnFragmentInteractionListener")
//        }
//    }

    override fun onDetach() {
        super.onDetach()
        listener = null
    }

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     *
     *
     * See the Android Training lesson [Communicating with Other Fragments]
     * (http://developer.android.com/training/basics/fragments/communicating.html)
     * for more information.
     */
    interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        fun onFragmentInteraction(uri: Uri)
    }

    companion object {
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param param1 Parameter 1.
         * @param param2 Parameter 2.
         * @return A new instance of fragment FragmentLoginWalletMode.
         */
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
                FragmentLoginWalletMode().apply {
                    arguments = Bundle().apply {
                        putString(ARG_PARAM1, param1)
                        putString(ARG_PARAM2, param2)
                    }
                }
    }
}
