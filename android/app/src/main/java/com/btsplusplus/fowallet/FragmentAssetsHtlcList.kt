package com.btsplusplus.fowallet

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.support.v4.app.Fragment
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
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

    private var _full_account_data: JSONObject? = null
    private var _data_array = mutableListOf<JSONObject>()
    private lateinit var _layout_wrap: LinearLayout

    override fun onInitParams(args: Any?) {
        _full_account_data = args as JSONObject
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        val v: View = inflater.inflate(R.layout.fragment_assets_htlc_list, container, false)
        _layout_wrap = v.findViewById(R.id.layout_my_assets_htlc_list_from_my_fragment)
        return v
    }

    /**
     *  (private) 查询账号关联的HTLC对象信息（包含FROM和TO）。
     */
    private fun _queryUserHTLCObjectList(): Promise {
        val account = _full_account_data!!.getJSONObject("account")
        val uid = account.getString("id")

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        if (_full_account_data!!.optJSONArray("htlcs") != null) {
            //  3.0.1 之后版本添加了获取HTLC相关API，full accounts也包含了HTLC对象信息。直接查询账号信息即可。
            return chainMgr.queryFullAccountInfo(uid).then {
                val full_data = it as JSONObject
                return@then full_data.optJSONArray("htlcs")
            }
        } else {
            //  3.0.1 及其之前版本，获取HTLC的接口尚未完成。full accounts也未包含HTLC对象信息。这里直接从账号明细里获取。但存在缺陷。
            //  TODO：特别注意：如果API节点配置的账户历史明细太低，可能漏掉部分HTLC对象。又或者用户的账号交易记录太多，HTLC对象也可能被漏掉 。

            val stop = "1.${EBitsharesObjectType.ebot_operation_history.value}.0"
            val start = "1.${EBitsharesObjectType.ebot_operation_history.value}.0"

            val api_conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
            val api_history = api_conn.async_exec_history("get_account_history_operations", jsonArrayfrom(uid, EBitsharesOperations.ebo_htlc_create.value, stop, start, 100))

            return api_history.then { data_array ->
                val htlc_id_hash = JSONObject()
                if (data_array != null && data_array is JSONArray && data_array.length() > 0) {
                    data_array.forEach<JSONObject> { op_history ->
                        val new_object_id = OrgUtils.extractNewObjectIDFromOperationResult(op_history!!.optJSONArray("result"))
                        if (new_object_id != null) {
                            htlc_id_hash.put(new_object_id, true)
                        }
                    }
                }
                val htlc_id_list = htlc_id_hash.keys().toJSONArray()
                return@then chainMgr.queryAllGrapheneObjectsSkipCache(htlc_id_list).then {
                    val data_hash = it as JSONObject
                    return@then data_hash.values()
                }
            }
        }
    }

    fun queryUserHTLCs() {
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        activity?.let { ctx ->
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()

            _queryUserHTLCObjectList().then {
                val htlc_list = it as? JSONArray
                val query_ids = JSONObject()

                htlc_list?.forEach<JSONObject> { htlc ->
                    val transfer = htlc!!.getJSONObject("transfer")
                    query_ids.put(transfer.getString("from"), true)
                    query_ids.put(transfer.getString("to"), true)
                    query_ids.put(transfer.getString("asset_id"), true)
                }

                //  查询 & 缓存
                val p1 = chainMgr.queryAllGrapheneObjects(query_ids.keys().toJSONArray())
                val p2 = chainMgr.queryGlobalProperties()

                return@then Promise.all(p1, p2).then {
                    mask.dismiss()
                    onQueryUserHTLCsResponsed(ctx, htlc_list)
                    return@then null
                }
            }.catch {
                mask.dismiss()
                showToast(R.string.tip_network_error.xmlstring(ctx))
            }
            return@let
        }
    }

    private fun onQueryUserHTLCsResponsed(ctx: Context, data_array: JSONArray?) {
        //  更新数据
        _data_array.clear()

        if (data_array != null && data_array.length() > 0) {
            val my_id = WalletManager.sharedWalletManager().getWalletAccountInfo()?.optJSONObject("account")?.optString("id", null)
            data_array.forEach<JSONObject> { htlc ->
                val transfer = htlc!!.getJSONObject("transfer")
                var side = kMySideOther
                if (my_id != null) {
                    if (my_id.equals(transfer.getString("from"))) {
                        side = kMySideFrom
                    } else if (my_id.equals(transfer.getString("to"))) {
                        side = kMySideTo
                    }
                }
                val m_htlc = JSONObject(htlc.toString())
                m_htlc.put("kSide", side)
                _data_array.add(JSONObject(m_htlc.toString()))
            }
        }

        //  根据ID降序排列
        _data_array.sortByDescending { it.getString("id").split(".").last().toInt() }

        //  更新显示
        refreshUI(ctx)
    }

    private fun refreshUI(ctx: Context) {
        _layout_wrap.removeAllViews()
        if (_data_array.size > 0) {
            val chainMgr = ChainObjectManager.sharedChainObjectManager()
            _data_array.forEachIndexed { index, htlc ->
                val view = createCell(ctx, htlc, chainMgr, index)
                _layout_wrap.addView(view)
            }
        } else {
            _layout_wrap.addView(ViewUtils.createEmptyCenterLabel(ctx, ctx.resources.getString(R.string.kVcHtlcNoAnyObjects)))
        }
    }

    private fun createCell(ctx: Context, htlc: JSONObject, chainMgr: ChainObjectManager, index: Int): LinearLayout {
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
        val hash_type = hash_lock.getJSONArray("preimage_hash").getInt(0)
        val hash_type_str = when (hash_type) {
            EBitsharesHtlcHashType.EBHHT_RMD160.value -> "RIPEMD160"
            EBitsharesHtlcHashType.EBHHT_SHA1.value -> "SHA1"
            EBitsharesHtlcHashType.EBHHT_SHA256.value -> "SHA256"
            else -> String.format(R.string.kVcHtlcListHashTypeValueUnknown.xmlstring(ctx), hash_type)
        }

        val hash_value = hash_lock.getJSONArray("preimage_hash").getString(1).toUpperCase()

        // 父级 layout
        val layout_parent = LinearLayout(ctx)
        layout_parent.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP).apply {
            if (index > 0) {
                setMargins(0, 8.dp, 0, 0)
            }
        }
        layout_parent.orientation = LinearLayout.VERTICAL

        // 第一行 左: id  右 过期时间
        val font_size = 11.0f
        val height_header = 28.dp
        val height_row = 28.dp
        val height_actions = 40.dp

        val layout_wrap01 = LinearLayout(ctx)
        layout_wrap01.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, height_header)
        layout_wrap01.orientation = LinearLayout.HORIZONTAL
        layout_wrap01.gravity = Gravity.CENTER_VERTICAL
        layout_wrap01.apply {
            val tv1 = TextView(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                text = "${index + 1}. #$id"
                paint.isFakeBoldText = true
            }
            val tv2 = TextView(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f).apply {
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorGray))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                text = String.format(R.string.kVcOrderExpired.xmlstring(ctx), Utils.fmtLimitOrderTimeShowString(expiration))
            }
            addView(tv1)
            addView(tv2)
        }

        // 第二行 左: 付款账号 xxxx  右 收款账号 xxxxx
        val layout_wrap02 = LinearLayout(ctx)
        layout_wrap02.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, height_row).apply {
            setMargins(0, 0, 0, 0)
        }
        layout_wrap02.orientation = LinearLayout.HORIZONTAL
        layout_wrap02.gravity = Gravity.CENTER_VERTICAL
        layout_wrap02.apply {
            val ly_left = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                val tv1 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = R.string.kVcHtlcListCellFrom.xmlstring(ctx)
                    paint.isFakeBoldText = true
                }
                val tv2 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                        setMargins(3.dp, 0.dp, 0.dp, 0.dp)
                    }
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = from
                    paint.isFakeBoldText = true
                }
                addView(tv1)
                addView(tv2)
            }
            val ly_right = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
                val tv1 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = R.string.kVcHtlcListCellTo.xmlstring(ctx)
                    paint.isFakeBoldText = true
                }
                val tv2 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        setMargins(3.dp, 0.dp, 0.dp, 0.dp)
                    }
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = to
                    paint.isFakeBoldText = true
                }
                addView(tv1)
                addView(tv2)
            }
            addView(ly_left)
            addView(ly_right)
        }

        // 第三行 左: 转账类型 xxxx  右 转账金额 xxxxx
        val layout_wrap03 = LinearLayout(ctx)
        layout_wrap03.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, height_row).apply {
            setMargins(0, 0, 0, 0)
        }
        layout_wrap03.orientation = LinearLayout.HORIZONTAL
        layout_wrap03.gravity = Gravity.CENTER_VERTICAL
        layout_wrap03.apply {
            val ly_left = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                val tv1 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = R.string.kVcHtlcListTransferDir.xmlstring(ctx)
                    paint.isFakeBoldText = true
                }
                val tv2 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                        setMargins(3.dp, 0.dp, 0.dp, 0.dp)
                    }
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    if (isPay) {
                        setTextColor(resources.getColor(R.color.theme01_sellColor))
                        text = R.string.kVcHtlcListTransferDirPayment.xmlstring(ctx)
                    } else {
                        setTextColor(resources.getColor(R.color.theme01_buyColor))
                        text = R.string.kVcHtlcListTransferDirIncome.xmlstring(ctx)
                    }
                    paint.isFakeBoldText = true
                }
                addView(tv1)
                addView(tv2)
            }
            val ly_right = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, LLAYOUT_WARP)
                val tv1 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = R.string.kVcHtlcListTransferAmount.xmlstring(ctx)
                    paint.isFakeBoldText = true
                }
                val tv2 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        setMargins(3.dp, 0.dp, 0.dp, 0.dp)
                    }
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = transfer_amount
                    paint.isFakeBoldText = true
                }
                addView(tv1)
                addView(tv2)
            }
            addView(ly_left)
            addView(ly_right)
        }

        // 第四行 左: 原像长度 xxxx  右 哈希类型 xxxxx
        val layout_wrap04 = LinearLayout(ctx)
        layout_wrap04.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, height_row).apply {
            setMargins(0, 0, 0, 0)
        }
        layout_wrap04.orientation = LinearLayout.HORIZONTAL
        layout_wrap04.gravity = Gravity.CENTER_VERTICAL
        layout_wrap04.apply {
            val ly_left = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                val tv1 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = R.string.kVcHtlcListPreimageLength.xmlstring(ctx)
                    paint.isFakeBoldText = true
                }
                val tv2 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                        setMargins(3.dp, 0.dp, 0.dp, 0.dp)
                    }
                    gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = size.toString()
                    paint.isFakeBoldText = true
                }
                addView(tv1)
                addView(tv2)
            }
            val ly_right = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f)
                val tv1 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                    setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = R.string.kVcHtlcListHashType.xmlstring(ctx)
                    paint.isFakeBoldText = true
                }
                val tv2 = TextView(ctx).apply {
                    layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                        setMargins(3.dp, 0.dp, 0.dp, 0.dp)
                    }
                    setTextColor(resources.getColor(R.color.theme01_textColorMain))
                    setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                    text = hash_type_str
                    paint.isFakeBoldText = true
                }
                addView(tv1)
                addView(tv2)
            }
            addView(ly_left)
            addView(ly_right)
        }

        // 第五行 左: 原像哈希 xxxxxxx
        val layout_wrap05 = LinearLayout(ctx)
        layout_wrap05.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, height_row).apply {
            setMargins(0, 0, 0, 0)
        }
        layout_wrap05.orientation = LinearLayout.HORIZONTAL
        layout_wrap05.gravity = Gravity.CENTER_VERTICAL
        layout_wrap05.apply {
            val tv1 = TextView(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP)
                gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorNormal))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                text = R.string.kVcHtlcListHashValue.xmlstring(ctx)
                paint.isFakeBoldText = true
            }
            val tv2 = TextView(ctx).apply {
                layoutParams = LinearLayout.LayoutParams(LLAYOUT_WARP, LLAYOUT_WARP).apply {
                    gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
                    setMargins(3.dp, 0.dp, 0.dp, 0.dp)
                }
                gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
                setTextColor(resources.getColor(R.color.theme01_textColorMain))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, font_size)
                setSingleLine(true)
                ellipsize = TextUtils.TruncateAt.valueOf("MIDDLE")
                text = hash_value
                paint.isFakeBoldText = true
            }
            addView(tv1)
            addView(tv2)
        }
        layout_wrap05.setOnClickListener {
            if (Utils.copyToClipboard(ctx, hash_value)) {
                showToast(String.format(R.string.kVcHtlcListCopyPreimageHashOK.xmlstring(ctx), hash_value))
            }
        }

        //  actions row
        var layout_wrap06: LinearLayout? = null
        if (kSide == kMySideFrom || kSide == kMySideTo) {
            layout_wrap06 = LinearLayout(ctx)
            layout_wrap06.layoutParams = LinearLayout.LayoutParams(LLAYOUT_MATCH, height_actions).apply {
                setMargins(0, 0, 0, 0)
            }
            layout_wrap06.orientation = LinearLayout.HORIZONTAL
            layout_wrap06.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
            layout_wrap06.apply {

                if (kSide == kMySideFrom) {
                    val button_extend = TextView(ctx).apply {
                        gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                        setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                        text = R.string.kVcHtlcListBtnExtend.xmlstring(ctx)
                    }
                    button_extend.setOnClickListener {
                        _onHtlcActionExtendExpiryClicked(ctx, htlc)
                    }
                    addView(button_extend)
                }
                if (kSide == kMySideTo) {
                    val button_redeem = TextView(ctx).apply {
                        layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f).apply {
                            gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                        }
                        gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                        setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                        text = R.string.kVcHtlcListBtnRedeem.xmlstring(ctx)
                    }
                    button_redeem.setOnClickListener {
                        _onHtlcActionRedeemClicked(ctx, htlc)
                    }
                    val button_create = TextView(ctx).apply {
                        layoutParams = LinearLayout.LayoutParams(0, LLAYOUT_WARP, 1f).apply {
                            gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                        }
                        gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
                        setTextColor(resources.getColor(R.color.theme01_textColorHighlight))
                        setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13.0f)
                        text = R.string.kVcHtlcListBtnCreate.xmlstring(ctx)
                    }
                    button_create.setOnClickListener {
                        _onHtlcActionCreateClicked(ctx, htlc)
                    }

                    addView(button_redeem)
                    addView(button_create)
                }
            }
        }

        layout_parent.addView(layout_wrap01)
        layout_parent.addView(layout_wrap02)
        layout_parent.addView(layout_wrap03)
        layout_parent.addView(layout_wrap04)
        layout_parent.addView(layout_wrap05)
        layout_parent.addView(ViewLine(ctx, 0.dp, 0.dp))
        if (layout_wrap06 != null) {
            layout_parent.addView(layout_wrap06)
            layout_parent.addView(ViewLine(ctx, 0.dp, 0.dp))
        }
        return layout_parent
    }

    private fun _gotoCreateHTLC(ctx: Context, htlc: JSONObject, fullaccountdata: JSONObject) {
        val to_id = htlc.getJSONObject("transfer").getString("from")
        val to_name = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(to_id).getString("name")
        val send_data = JSONObject().apply {
            put("full_userdata", fullaccountdata)
            put("mode", EHtlcDeployMode.EDM_HASHCODE.value)
            put("havePreimage", false)
            put("ref_htlc", htlc)
            put("ref_to", JSONObject().apply {
                put("id", to_id)
                put("name", to_name)
            })
        }
        (ctx as Activity).goTo(ActivityCreateHtlcContract::class.java, true, args = send_data)
    }

    /**
     * (private) 部署副合约点击
     */
    private fun _onHtlcActionCreateClicked(ctx: Context, htlc: JSONObject) {
        if (WalletManager.sharedWalletManager().isMyselfAccount(_full_account_data!!.getJSONObject("account").getString("name"))) {
            _gotoCreateHTLC(ctx, htlc, _full_account_data!!)
        } else {
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()
            val p1 = (ctx as Activity).get_full_account_data_and_asset_hash(WalletManager.sharedWalletManager().getWalletAccountName()!!)
            val p2 = ChainObjectManager.sharedChainObjectManager().queryFeeAssetListDynamicInfo()  //  查询手续费兑换比例、手续费池等信息
            Promise.all(p1, p2).then {
                mask.dismiss()
                val data = it as JSONArray
                _gotoCreateHTLC(ctx, htlc, data.getJSONObject(0))
                return@then null
            }.catch { err ->
                mask.dismiss()
                showToast(R.string.tip_network_error.xmlstring(ctx))
            }
        }
    }

    private fun _onHtlcActionRedeemClicked(ctx: Context, htlc: JSONObject, preimage: String) {
        if (preimage.isEmpty()) {
            showToast(R.string.kVcHtlcListTipsInputValidPreimage.xmlstring(ctx))
            return
        }

        //  构造请求
        val opaccount = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val account_id = opaccount.getString("id")
        val htlc_id = htlc.getString("id")

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", ChainObjectManager.sharedChainObjectManager().grapheneCoreAssetID)
            })
            put("htlc_id", htlc_id)
            put("redeemer", account_id)
            put("preimage", preimage.utf8String())
        }

        (ctx as Activity).GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_htlc_redeem, false, false, op, opaccount) { isProposal: Boolean, proposal_create_args: JSONObject? ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().htlcRedeem(op).then {
                mask.dismiss()
                showToast(String.format(R.string.kVcHtlcListTipsRedeemOK.xmlstring(ctx), htlc_id))
                //  [统计]
                btsppLogCustom("txHtlcRedeemFullOK", jsonObjectfromKVS("redeemer", account_id, "htlc_id", htlc_id))
                //  刷新当前 Activity
                queryUserHTLCs()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                btsppLogCustom("txHtlcRedeemFailed", jsonObjectfromKVS("redeemer", account_id, "htlc_id", htlc_id))
            }
        }
    }

    /**
     * (private) 赎回合约点击
     **/
    private fun _onHtlcActionRedeemClicked(ctx: Context, htlc: JSONObject) {
        UtilsAlert.showInputBox(ctx, R.string.kVcHtlcListAskTitleRedeem.xmlstring(ctx), R.string.kVcHtlcListAskPlaceholderRedeem.xmlstring(ctx), is_password = false).then {
            if (it != null && it is String) {
                val tfvalue = it
                (ctx as Activity).guardWalletUnlocked(false) { unlocked ->
                    if (unlocked) {
                        _onHtlcActionRedeemClicked(ctx, htlc, tfvalue)
                    }
                }
            }
        }
    }

    /**
     * (private) 延长合约有效期请求部分
     */
    private fun _onHtlcActionExtendExpiryClicked(ctx: Context, htlc: JSONObject, seconds: Int) {
        assert(seconds > 0)

        //  构造请求
        val opaccount = WalletManager.sharedWalletManager().getWalletAccountInfo()!!.getJSONObject("account")
        val account_id = opaccount.getString("id")
        val htlc_id = htlc.getString("id")

        val op = JSONObject().apply {
            put("fee", JSONObject().apply {
                put("amount", 0)
                put("asset_id", ChainObjectManager.sharedChainObjectManager().grapheneCoreAssetID)
            })
            put("htlc_id", htlc_id)
            put("update_issuer", account_id)
            put("seconds_to_add", seconds)
        }

        (ctx as Activity).GuardProposalOrNormalTransaction(EBitsharesOperations.ebo_htlc_extend, false, false, op, opaccount) { isProposal: Boolean, proposal_create_args: JSONObject? ->
            assert(!isProposal)
            //  请求网络广播
            val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
            mask.show()
            BitsharesClientManager.sharedBitsharesClientManager().htlcExtend(op).then {
                mask.dismiss()
                showToast(String.format(R.string.kVcHtlcListTipsExtendOK.xmlstring(ctx), htlc_id))
                //  [统计]
                btsppLogCustom("txHtlcExtendFullOK", jsonObjectfromKVS("update_issuer", account_id, "htlc_id", htlc_id))
                //  刷新当前 Activity
                queryUserHTLCs()
                return@then null
            }.catch { err ->
                mask.dismiss()
                showGrapheneError(err)
                btsppLogCustom("txHtlcExtendFailed", jsonObjectfromKVS("update_issuer", account_id, "htlc_id", htlc_id))
            }
        }
    }

    /**
     * (private) 延长有效期点击
     */
    private fun _onHtlcActionExtendExpiryClicked(ctx: Context, htlc: JSONObject) {
        val gp = ChainObjectManager.sharedChainObjectManager().getObjectGlobalProperties()
        val extensions = gp.getJSONObject("parameters").opt("extensions")
        if (extensions == null || !(extensions is JSONObject)) {
            showToast(R.string.kVcHtlcListTipsErrorMissParams.xmlstring(ctx))
            return
        }
        val updatable_htlc_options = extensions.optJSONObject("updatable_htlc_options")
        if (updatable_htlc_options == null) {
            showToast(R.string.kVcHtlcListTipsErrorMissParams.xmlstring(ctx))
            return
        }
        val max_timeout_secs = updatable_htlc_options.getInt("max_timeout_secs")
        val now_ts = Utils.now_ts()
        val htlc_expiration = Utils.parseBitsharesTimeString(htlc.getJSONObject("conditions").getJSONObject("time_lock").getString("expiration"))
        val max_add_seconds = max_timeout_secs - (htlc_expiration - now_ts)
        val max_add_days = max_add_seconds / 86400

        if (max_add_days <= 0) {
            showToast(R.string.kVcHtlcListTipsErrorMaxExpire.xmlstring(ctx))
            return
        }

        val list = JSONArray()
        for (day in 1..max_add_days) {
            val name = String.format(R.string.kVcHtlcListExtendNDayFmt.xmlstring(ctx), day.toString())
            list.put(JSONObject().apply {
                put("name", name)
                put("value", day.toInt())
            })
        }

        ViewDialogNumberPicker(ctx, R.string.kVcHtlcListTipsSelectExtendDays.xmlstring(ctx), list, "name", 0) { _index: Int, txt: String ->
            val extend_day = list.getJSONObject(_index).getInt("value")
            val message = String.format(R.string.kVcHtlcListTipsExtendConfirm.xmlstring(ctx), extend_day.toString())
            UtilsAlert.showMessageConfirm(ctx, R.string.kWarmTips.xmlstring(ctx), message).then {
                if (it != null && it as Boolean) {
                    (ctx as Activity).guardWalletUnlocked(false) { unlocked ->
                        if (unlocked) {
                            _onHtlcActionExtendExpiryClicked(ctx, htlc, extend_day * 3600 * 24)
                        }
                    }
                }
            }
        }.show()
    }
}
