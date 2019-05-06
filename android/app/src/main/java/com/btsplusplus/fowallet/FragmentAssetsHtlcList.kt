package com.btsplusplus.fowallet

import android.app.Activity
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
import com.btsplusplus.fowallet.ViewEx.ViewLine
import com.crashlytics.android.answers.Answers
import com.fowallet.walletcore.bts.BitsharesClientManager
import com.fowallet.walletcore.bts.ChainObjectManager
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONArray
import org.json.JSONObject

// TODO: Rename parameter arguments, choose names that match
// the fragment initialization parameters, e.g. ARG_ITEM_NUMBER
private const val ARG_PARAM1 = "param1"
private const val ARG_PARAM2 = "param2"

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentAssetsHtlcList.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentAssetsHtlcList.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentAssetsHtlcList : BtsppFragment() {

    private val kMySideFrom = 0                //  我是付款方
    private val kMySideTo = 1                  //  我是收款方
    private val kMySideOther = 2               //  我吃吃瓜群众（仅查看别人的合约信息）

    lateinit var _ctx: Context
    private var _loadStartID: Int = 0
    private var _full_account_data: JSONObject? = null
    lateinit var _dataArray: JSONArray
    lateinit var _layout_wrap: LinearLayout

    override fun onInitParams(args: Any?) {
        _full_account_data = args as JSONObject
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        val v: View = inflater.inflate(R.layout.fragment_assets_htlc_list, container, false)
        _layout_wrap = v.findViewById(R.id.layout_my_assets_htlc_list_from_my_fragment)

        _ctx = inflater.context
        _dataArray = JSONArray()
        queryUserHTLCs()

        return v
    }


    private fun queryUserHTLCs(){
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        val mask = ViewMesk(R.string.kTipsBeRequesting.xmlstring(_ctx),_ctx)
        val account = _full_account_data!!.getJSONObject("account")
        val uid = account.optString("id")
        assert(uid != null)

        //  TODO:2.1 REMARK: !!!!!! 因为core-team的database api尚未完成 !!!!，这里直接从用户明细里获取HTLC编号。
        //  TODO：特别注意：如果API节点配置的账户历史明细太低，可能漏掉部分HTLC对象。又或者用户的账号交易记录太多，HTLC对象也可能被漏掉 。
        //  TODO：后期data base api更新后处理。

        val stop = "1.${EBitsharesObjectType.ebot_operation_history.value}.0"
        val start = "1.${EBitsharesObjectType.ebot_operation_history.value}.0"

        val htlc_id_hash = JSONObject()
        val api_conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val api_history = api_conn.async_exec_history("get_account_history_operations", jsonArrayfrom(uid, EBitsharesOperations.ebo_htlc_create.value, stop, start, 100))
        api_history.then { data_array ->

            if (data_array != null && data_array is JSONArray && data_array.length() > 0){
                data_array.forEach<JSONObject> { op_history ->
                    val new_object_id = OrgUtils.extractNewObjectIDFromOperationResult(op_history!!.optJSONArray("result"))
                    if (new_object_id != null){
                        htlc_id_hash.put(new_object_id, true)
                    }
                }
            }
            val htlc_id_list = htlc_id_hash.keys().toJSONArray()
            return@then chainMgr.queryAllGrapheneObjectsSkipCache(htlc_id_list).then {
                val data_hash = it as JSONObject
                val query_ids = JSONObject()

                val htlc_list = data_hash.values()
                htlc_list.forEach<JSONObject> { htlc ->
                    val transfer = htlc!!.optJSONObject("transfer")
                    assert(transfer != null)
                    query_ids.put(transfer.getString("from"),true)
                    query_ids.put(transfer.getString("to"),true)
                    query_ids.put(transfer.getString("asset_id"),true)
                }
                //  查询 & 缓存
                val p1 = chainMgr.queryAllGrapheneObjects(query_ids.keys().toJSONArray())
                val p2 = chainMgr.queryGlobalProperties()

                return@then Promise.all(jsonArrayfrom(p1, p2)).then {
                    mask.dismiss()
                    onQueryUserHTLCsResponsed(htlc_list)
                    return@then null
                }
            }
        }.catch {
            mask.dismiss()
            showToast(R.string.tip_network_error.xmlstring(_ctx))
        }
    }

    private fun removeAllDataArray(){
        var i = 0
        while (i < _dataArray.length()) {
            _dataArray.remove(i)
            i++
        }
    }

    private fun onQueryUserHTLCsResponsed(data_array: JSONArray?){
        //  更新数据
        removeAllDataArray()

        if ( data_array != null && data_array.length() >0 ){
            val my_id = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account").optString("id")
            data_array.forEach<JSONObject> { htlc ->
                val transfer = htlc!!.optJSONObject("transfer")
                assert(transfer != null)
                var side = kMySideOther
                if (my_id != null){
                    if (my_id.equals(transfer.getString("from"))){
                        side = kMySideFrom
                    } else if (my_id.equals(transfer.getString("to"))){
                        side = kMySideTo
                    }
                }
                val m_htlc = JSONObject(htlc.toString())
                m_htlc.put("kSide",side)
                _dataArray.put(JSONObject(m_htlc.toString()))
            }
        }

        //  根据ID降序排列
        if (_dataArray.length() > 0){
            _dataArray = _dataArray.toList<JSONObject>().sortedByDescending {
                return@sortedByDescending it.getString("id").split(".").last().toInt()
            }.toJsonArray()
        }

        //  更新显示
        refreshUI()
    }

    private fun refreshUI(){
        _layout_wrap.removeAllViews()
        var index = 0
        val chainMgr = ChainObjectManager.sharedChainObjectManager()
        _dataArray.forEach<JSONObject> { htlc ->
            if (htlc != null) {
                val view = createCell(htlc,chainMgr,index)
                _layout_wrap.addView(view)
                index++
            }
        }
    }

    private fun createCell(htlc: JSONObject, chainMgr: ChainObjectManager,index: Int) : LinearLayout{
        val id = htlc.getString("id")
        val transfer = htlc.getJSONObject("transfer")
        val conditions = htlc.getJSONObject("conditions")
        val kSide = htlc.optInt("kSide")

        val hash_lock = conditions.getJSONObject("hash_lock")
        val time_lock = conditions.getJSONObject("time_lock")
        val expiration = time_lock.getString("expiration")

        val from = chainMgr.getChainObjectByID(transfer.getString("from")).getString("name")
        val to = chainMgr.getChainObjectByID(transfer.getString("to")).getString("name")

        val isPay = _full_account_data!!.getJSONObject("account").getString("id").equals(transfer.getString("from"))
        val transfer_amount = OrgUtils.formatAssetAmountItem(transfer)

        val size = hash_lock.getInt("preimage_size")
        val hash_type = hash_lock.getJSONArray("preimage_hash").first<Int>()
        var hash_type_str = String.format(R.string.kVcHtlcListHashTypeValueUnknown.xmlstring(_ctx),hash_type)
        when(hash_type){
            EBitsharesHtlcHashType.EBHHT_RMD160.value -> hash_type_str = "RIPEMD160"
            EBitsharesHtlcHashType.EBHHT_SHA1.value -> hash_type_str = "SHA1"
            EBitsharesHtlcHashType.EBHHT_SHA256.value -> hash_type_str = "SHA256"
        }

        val have_value = hash_lock.getJSONArray("preimage_hash").last<String>()

        // 父级 layout
        val layout_parent = LinearLayout(_ctx)
        layout_parent.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            if (index > 0){
                setMargins(0,10.dp,0,0)
            }
        }
        layout_parent.orientation = LinearLayout.VERTICAL

        // 第一行 左: id  右 过期时间
        val layout_wrap01 = LinearLayout(_ctx)
        layout_wrap01.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
        layout_wrap01.orientation = LinearLayout.HORIZONTAL
        layout_wrap01.gravity = Gravity.CENTER_VERTICAL
        layout_wrap01.apply {
            val tv1 = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1f)
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                textSize = 7.5f.dp
                text = "${index + 1}.#${id}"
            }
            val tv2 = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1f).apply {
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorGray))
                textSize = 6.0f.dp
                text = String.format(R.string.kVcOrderExpired.xmlstring(_ctx),Utils.fmtLimitOrderTimeShowString(expiration))
            }
            addView(tv1)
            addView(tv2)
        }

        // 第二行 左: 付款账号 xxxx  右 收款账号 xxxxx
        val layout_wrap02 = LinearLayout(_ctx)
        layout_wrap02.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0.dp,0.dp,0.dp,0.dp)
        }
        layout_wrap02.orientation = LinearLayout.HORIZONTAL
        layout_wrap02.gravity = Gravity.CENTER_VERTICAL
        layout_wrap02.apply {
            val ly_left = LinearLayout(_ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                val tv1 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    textSize = 5.5f.dp
                    text = R.string.kVcHtlcListCellFrom.xmlstring(_ctx)
                }
                val tv2 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                        setMargins(2.dp, 0.dp, 0.dp, 0.dp)
                    }
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    textSize = 5.0f.dp
                    text = from
                }
                addView(tv1)
                addView(tv2)
            }
            val ly_right = LinearLayout(_ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                val tv1 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    textSize = 5.5f.dp
                    text = R.string.kVcHtlcListCellTo.xmlstring(_ctx)
                }
                val tv2 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        setMargins(2.dp, 0.dp, 0.dp, 0.dp)
                    }
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    textSize = 5.0f.dp
                    text = to
                }
                addView(tv1)
                addView(tv2)
            }
            addView(ly_left)
            addView(ly_right)
        }

        // 第三行 左: 转账类型 xxxx  右 转账金额 xxxxx
        val layout_wrap03 = LinearLayout(_ctx)
        layout_wrap03.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0.dp,10.dp,0.dp,0.dp)
        }
        layout_wrap03.orientation = LinearLayout.HORIZONTAL
        layout_wrap03.gravity = Gravity.CENTER_VERTICAL
        layout_wrap03.apply {
            val ly_left = LinearLayout(_ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                val tv1 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    textSize = 5.5f.dp
                    text = R.string.kVcHtlcListTransferDir.xmlstring(_ctx)
                }
                val tv2 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                        setMargins(2.dp, 0.dp, 0.dp, 0.dp)
                    }
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_sellColor))
                    textSize = 5.0f.dp
                    if (isPay) {
                        text = R.string.kVcHtlcListTransferDirPayment.xmlstring(_ctx)
                    } else {
                        text = R.string.kVcHtlcListTransferDirIncome.xmlstring(_ctx)
                    }
                }
                addView(tv1)
                addView(tv2)
            }
            val ly_right = LinearLayout(_ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                val tv1 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    textSize = 5.5f.dp
                    text = R.string.kVcHtlcListTransferAmount.xmlstring(_ctx)
                }
                val tv2 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        setMargins(2.dp, 0.dp, 0.dp, 0.dp)
                    }
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    textSize = 5.0f.dp
                    text = transfer_amount
                }
                addView(tv1)
                addView(tv2)
            }
            addView(ly_left)
            addView(ly_right)
        }

        // 第四行 左: 原像长度 xxxx  右 哈希类型 xxxxx
        val layout_wrap04 = LinearLayout(_ctx)
        layout_wrap04.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0.dp,5.dp,0.dp,0.dp)
        }
        layout_wrap04.orientation = LinearLayout.HORIZONTAL
        layout_wrap04.gravity = Gravity.CENTER_VERTICAL
        layout_wrap04.apply {
            val ly_left = LinearLayout(_ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                val tv1 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    textSize = 5.5f.dp
                    text = R.string.kVcHtlcListPreimageLength.xmlstring(_ctx)
                }
                val tv2 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                        setMargins(2.dp, 0.dp, 0.dp, 0.dp)
                    }
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    textSize = 5.0f.dp
                    text = size.toString()
                }
                addView(tv1)
                addView(tv2)
            }
            val ly_right = LinearLayout(_ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                val tv1 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    textSize = 5.5f.dp
                    text = R.string.kVcHtlcListHashType.xmlstring(_ctx)
                }
                val tv2 = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        setMargins(2.dp, 0.dp, 0.dp, 0.dp)
                    }
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    textSize = 5.0f.dp
                    text = hash_type_str
                }
                addView(tv1)
                addView(tv2)
            }
            addView(ly_left)
            addView(ly_right)
        }

        // 第五行 左: 原像哈希 xxxxxxx
        val layout_wrap05 = LinearLayout(_ctx)
        layout_wrap05.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0.dp,5.dp,0.dp,0.dp)
        }
        layout_wrap05.orientation = LinearLayout.HORIZONTAL
        layout_wrap05.gravity = Gravity.CENTER_VERTICAL
        layout_wrap05.apply {
            val tv1 = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                textSize = 5.5f.dp
                text = R.string.kVcHtlcListHashValue.xmlstring(_ctx)
            }
            val tv2 = TextView(_ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setMargins(2.dp, 0.dp, 0.dp, 0.dp)
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                textSize = 5.0f.dp
                setSingleLine(true)
                ellipsize = TextUtils.TruncateAt.valueOf("MIDDLE")
                text = have_value!!.toUpperCase()
            }
            addView(tv1)
            addView(tv2)
        }

        val layout_wrap06 = LinearLayout(_ctx)
        layout_wrap06.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            setMargins(0.dp,0.dp,0.dp,0.dp)
        }
        layout_wrap06.orientation = LinearLayout.HORIZONTAL
        layout_wrap06.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
        layout_wrap06.apply {

            if (kSide == kMySideFrom) {
                val button_extend = TextView(_ctx).apply {
                    gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                    textSize = 7.0f.dp
                    text = R.string.kVcHtlcListBtnExtend.xmlstring(_ctx)
                }
                button_extend.setOnClickListener {
                    _onHtlcActionExtendExpiryClicked(htlc)
                }
                addView(button_extend)
            }
            if (kSide == kMySideTo) {
                val button_redeem = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1f).apply {
                        gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                    }
                    gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                    textSize = 7.0f.dp
                    text = R.string.kVcHtlcListBtnRedeem.xmlstring(_ctx)
                }
                button_redeem.setOnClickListener {
                    _onHtlcActionRedeemClicked(htlc)
                }
                val button_create = TextView(_ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP,1f).apply {
                        gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                    }
                    gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                    textSize = 7.0f.dp
                    text = R.string.kVcHtlcListBtnCreate.xmlstring(_ctx)
                }
                button_create.setOnClickListener {
                    _onHtlcActionCreateClicked(htlc)
                }

                addView(button_redeem)
                addView(button_create)
            }
        }

        layout_parent.addView(layout_wrap01)
        layout_parent.addView(layout_wrap02)
        layout_parent.addView(layout_wrap03)
        layout_parent.addView(ViewLine(_ctx,5.dp, 5.dp))
        layout_parent.addView(layout_wrap04)
        layout_parent.addView(layout_wrap05)
        layout_parent.addView(ViewLine(_ctx,5.dp, 5.dp))
        layout_parent.addView(layout_wrap06)
        layout_parent.addView(ViewLine(_ctx,5.dp, 5.dp))
        return layout_parent
    }

    private fun _gotoCreateHTLC(htlc: JSONObject, fullaccountdata: JSONObject){
        val to_id = htlc.getJSONObject("transfer").getString("from")
        val to_name = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(to_id).optString("name")
        assert(to_name != null)
        val send_data = JSONObject()
        send_data.put("full_userdata",jsonArrayfrom(fullaccountdata))
        send_data.put("mode",EHtlcDeployMode.EDM_HASHCODE.value)
        send_data.put("havePreimage",false)
        send_data.put("ref_htlc",htlc)
        send_data.put("ref_to",JSONObject().apply {
            put("id",to_id)
            put("name",to_name)
        })
        (_ctx as Activity).goTo(ActivityCreateHtlcContract::class.java, true, args = send_data)
    }

    private fun _onHtlcActionCreateClicked(htlc: JSONObject){
        if (WalletManager.sharedWalletManager().isMyselfAccount(_full_account_data!!.getJSONObject("account").getString("name"))){
            _gotoCreateHTLC(htlc,_full_account_data!!)
        } else {
            val mesk = ViewMesk(R.string.kTipsBeRequesting.xmlstring(_ctx),_ctx)
            mesk.show()
            val p1 = (_ctx as Activity).get_full_account_data_and_asset_hash(WalletManager.sharedWalletManager().getWalletAccountName()!!)
            val p2 = ChainObjectManager.sharedChainObjectManager().queryFeeAssetListDynamicInfo()  //  查询手续费兑换比例、手续费池等信息
            Promise.all(jsonArrayfrom(p1,p2)).then {
                val data = id as JSONArray
                mesk.dismiss()
                _gotoCreateHTLC(htlc,data.getJSONObject(0))
                return@then null
            }.catch { err ->
                mesk.dismiss()
            }
        }
    }

    fun _onHtlcActionRedeemClicked(htlc: JSONObject, preimage: String) {
        if (preimage.isEmpty()) {
            showToast(R.string.kVcHtlcListTipsInputValidPreimage.xmlstring(_ctx))
            return
        }

        //  构造请求
        val opaccount = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.optJSONObject("account")
        assert(opaccount != null)
        val account_id = opaccount.optString("id")
        assert(opaccount != null)
        val htlc_id = htlc.optString("id")
        assert(htlc_id != null)

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount",0)
                put("asset_id",ChainObjectManager.sharedChainObjectManager().grapheneChainID)
            })
            put("htlc_id",htlc_id)
            put("redeemer",account_id)
            put("preimage",preimage.utf8String())
        }


        (_ctx as Activity).GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_htlc_redeem,false,false,op,opaccount) { isProposal: Boolean, proposal_create_args: JSONObject? ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMesk(R.string.kTipsBeRequesting.xmlstring(_ctx),_ctx)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().htlcRedeem(op).then {
                val transaction_confirmation = it as JSONObject
                mask.dismiss()
                showToast( String.format(R.string.kVcHtlcListTipsRedeemOK.xmlstring(_ctx), htlc_id))
                //  [统计] Todo 未封装
                // Answers.logCustomEventWithName("txHtlcRedeemFullOK",JSONObject().apply {
                //    put("redeemer",account_id)
                //    put("htlc_id",htlc_id)
                // })

                // 刷新当前 Activity
                queryUserHTLCs()

                return@then null
            }.catch { err ->
                mask.dismiss()

                // Todo remove 临时的错误提示
                showToast(R.string.tip_network_error.xmlstring(_ctx))

                // Todo 未封装
                // OrgUtils.showGrapheneError(err)

                // Todo 未封装
                // Answers.logCustomEventWithName("txHtlcRedeemFailed",JSONObject().apply {
                //    put("redeemer",account_id)
                //    put("htlc_id",htlc_id)
                //})
            }
        }
    }

    private fun _onHtlcActionRedeemClicked(htlc: JSONObject) {
        UtilsAlert.showInputBox(_ctx,R.string.kVcHtlcListAskTitleRedeem.xmlstring(_ctx),R.string.kVcHtlcListAskPlaceholderRedeem.xmlstring(_ctx)).then {
            if (it != null && it is String) {
                val tfvalue = it
                (_ctx as Activity).guardWalletUnlocked(false){ unlocked ->
                    if (unlocked) {
                        _onHtlcActionRedeemClicked(htlc,tfvalue)
                    }
                }
            }
        }
    }

    private fun _onHtlcActionExtendExpiryClicked(htlc: JSONObject, seconds: Int) {
        assert(seconds > 0)

        //  构造请求
        val opaccount = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.optJSONObject("account")
        assert(opaccount != null)
        val account_id = opaccount.optString("id")
        assert(account_id != null)
        val htlc_id = htlc.optString("id")
        assert(htlc_id != null)

        val op = JSONObject().apply {
            put("fee",JSONObject().apply {
                put("amount", 0)
                put("asset_id", ChainObjectManager.sharedChainObjectManager().grapheneCoreAssetID)
            })
            put("htlc_id",htlc_id)
            put("update_issuer",account_id)
            put("seconds_to_add",seconds)
        }

        (_ctx as Activity).GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_htlc_extend,false,false,op,opaccount) { isProposal: Boolean, proposal_create_args: JSONObject? ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMesk(R.string.kTipsBeRequesting.xmlstring(_ctx),_ctx)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().htlcExtend(op).then{
                val transaction_confirmation = it
                mask.dismiss()
                showToast(String.format(R.string.kVcHtlcListTipsExtendOK.xmlstring(_ctx),htlc_id))

                //  [统计] Todo 未封装
                // Answers.logCustomEventWithName("txHtlcExtendFullOK",JSONObject().apply {
                //    put("update_issuer",account_id)
                //    put("htlc_id",htlc_id)
                // })

                // 刷新当前 Activity
                 queryUserHTLCs()

                return@then null
            }.catch { err ->
                mask.dismiss()

                // Todo 未封装
                // OrgUtils.showGrapheneError(err)

                // Todo 未封装
                // Answers.logCustomEventWithName("txHtlcExtendFailed",JSONObject().apply {
                //    put("update_issuer",account_id)
                //    put("htlc_id",htlc_id)
                //})
            }
        }
    }

    private fun _onHtlcActionExtendExpiryClicked(htlc: JSONObject) {
        val gp = ChainObjectManager.sharedChainObjectManager().getObjectGlobalProperties()
        assert(gp != null)
        val _extensions = gp.getJSONObject("parameters").get("extensions")
        if (_extensions == null || !(_extensions is JSONObject)){
            showToast(R.string.kVcHtlcListTipsErrorMissParams.xmlstring(_ctx))
            return
        }
        val extensions = _extensions as JSONObject
        val updatable_htlc_options = extensions.optJSONObject("updatable_htlc_options")
        if (updatable_htlc_options == null) {
            showToast(R.string.kVcHtlcListTipsErrorMissParams.xmlstring(_ctx))
            return
        }
        val max_timeout_secs = updatable_htlc_options.getInt("max_timeout_secs")
        val now_ts = Utils.now_ts()
        val htlc_expiration = Utils.parseBitsharesTimeString(htlc.getJSONObject("conditions").getJSONObject("time_lock").getString("expiration"))
        val max_add_seconds = max_timeout_secs -  (htlc_expiration - now_ts)
        val max_add_days = max_add_seconds / 86400

        if (max_add_days <= 0){
            showToast(R.string.kVcHtlcListTipsErrorMaxExpire.xmlstring(_ctx))
            return
        }
        val list = JSONArray()
        val select_list = Array<String>(max_add_days.toInt()){
            return@Array ""
        }
        for ( day in 1 .. max_add_days ) {
            list.put(JSONObject().apply {
                put("name",String.format(R.string.kVcHtlcListExtendNDayFmt.xmlstring(_ctx),day))
                put("value",day)
            })
            select_list.set((day-1).toInt(), String.format(R.string.kVcHtlcListExtendNDayFmt.xmlstring(_ctx),day))
        }

        val default_select = 0
        ViewDialogNumberPicker(_ctx, R.string.kVcHtlcListTipsSelectExtendDays.xmlstring(_ctx), select_list, default_select){ _index: Int, txt: String ->
            val extend_day = list.getJSONObject(_index).getLong("value").toInt()
            val message = String.format(R.string.kVcHtlcListTipsExtendConfirm.xmlstring(_ctx),extend_day.toString())
            UtilsAlert.showMessageConfirm(_ctx, R.string.kWarmTips.xmlstring(_ctx), message).then {
                if (it != null && it as Boolean) {

                    (_ctx as Activity).guardWalletUnlocked(false){
                        val unlocked = it
                        if (unlocked != null && unlocked is Boolean && unlocked) {
                            _onHtlcActionExtendExpiryClicked(htlc,extend_day * 3600 * 24)
                        }
                    }
                }
            }
        }.show()
    }
}
