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
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TableRow
import android.widget.TextView
import bitshares.*
import com.btsplusplus.fowallet.utils.VcUtils
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.max

/**
 * A simple [Fragment] subclass.
 * Activities that contain this fragment must implement the
 * [FragmentFeedPrice.OnFragmentInteractionListener] interface
 * to handle interaction events.
 * Use the [FragmentFeedPrice.newInstance] factory method to
 * create an instance of this fragment.
 *
 */
class FragmentFeedPrice : BtsppFragment() {

    private var listener: OnFragmentInteractionListener? = null

    private var _ctx: Context? = null
    private var _currentView: View? = null
    private var _waiting_draw_infos: JSONObject? = null

    private lateinit var _curr_asset: JSONObject

    override fun onInitParams(args: Any?) {
        val json = args as JSONObject
        _curr_asset = json.getJSONObject("curr_asset")
    }

    fun setCurrentAsset(newAsset: JSONObject) {
        _curr_asset = newAsset
    }

    override fun onControllerPageChanged() {
        waitingOnCreateView().then {
            queryDetailFeedInfos(it as Context)
        }
    }

    private fun queryDetailFeedInfos(ctx: Context) {
        val mask = ViewMask(R.string.kTipsBeRequesting.xmlstring(ctx), ctx)
        mask.show()
        val conn = GrapheneConnectionManager.sharedGrapheneConnectionManager().any_connection()
        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        chainMgr.queryAssetData(_curr_asset.getString("id")).then {
            val assetData = it as? JSONObject
            if (assetData == null) {
                mask.dismiss()
                showToast(resources.getString(R.string.kNormalErrorInvalidArgs))
                return@then null
            }

            val promise_map = JSONObject()

            //  1、查询喂价者信息
            val publisher_type: EBitsharesFeedPublisherType
            val flags = assetData.getJSONObject("options").getInt("flags")
            if (flags.and(EBitsharesAssetFlags.ebat_witness_fed_asset.value) != 0) {
                //  由见证人提供喂价
                promise_map.put("kQueryWitness", chainMgr.queryActiveWitnessDataList())
                publisher_type = EBitsharesFeedPublisherType.ebfpt_witness
            } else if (flags.and(EBitsharesAssetFlags.ebat_committee_fed_asset.value) != 0) {
                //  由理事会成员提供喂价
                promise_map.put("kQueryCommittee", chainMgr.queryActiveCommitteeDataList())
                publisher_type = EBitsharesFeedPublisherType.ebfpt_committee
            } else {
                //  由指定账号提供喂价
                publisher_type = EBitsharesFeedPublisherType.ebfpt_custom
            }

            //  2、查询喂价信息（REMARK：不查询缓存）
            val bitasset_data_id = assetData.getString("bitasset_data_id")
            promise_map.put("kQueryFeedData", chainMgr.queryAllGrapheneObjectsSkipCache(jsonArrayfrom(bitasset_data_id)))

            return@then Promise.map(promise_map).then {
                val datamap = it as JSONObject

                val feed_infos = chainMgr.getChainObjectByID(bitasset_data_id)
                val feeds = feed_infos.getJSONArray("feeds")

                val idHash = JSONObject()
                val active_publisher_ids = JSONArray()

                if (publisher_type == EBitsharesFeedPublisherType.ebfpt_witness) {
                    datamap.getJSONArray("kQueryWitness").forEach<JSONObject> {
                        val account_id = it!!.getString("witness_account")
                        active_publisher_ids.put(account_id)
                        idHash.put(account_id, true)
                    }
                } else if (publisher_type == EBitsharesFeedPublisherType.ebfpt_committee) {
                    datamap.getJSONArray("kQueryCommittee").forEach<JSONObject> {
                        val account_id = it!!.getString("committee_member_account")
                        active_publisher_ids.put(account_id)
                        idHash.put(account_id, true)
                    }
                }
                feeds.forEach<JSONArray> {
                    val ary = it!!
                    val account_id = ary.getString(0)
                    if (publisher_type == EBitsharesFeedPublisherType.ebfpt_custom) {
                        active_publisher_ids.put(account_id)
                    }
                    idHash.put(account_id, true)
                }

                //  查询依赖信息
                val short_backing_asset = feed_infos.getJSONObject("options").getString("short_backing_asset")
                idHash.put(short_backing_asset, true)
                return@then chainMgr.queryAllGrapheneObjects(idHash.keys().toJSONArray()).then {
                    onQueryFeedInfoResponsed(assetData, feed_infos, feeds, active_publisher_ids, publisher_type)
                    mask.dismiss()
                    return@then null
                }
            }
        }.catch {
            mask.dismiss()
            showToast(resources.getString(R.string.tip_network_error))
        }
    }

    /**
     * 刷新喂价信息
     */
    private fun onQueryFeedInfoResponsed(asset: JSONObject, feed_infos: JSONObject, feeds: JSONArray, active_publisher_ids: JSONArray, publisher_type: EBitsharesFeedPublisherType) {
        //  REMARK：数据返回的时候界面尚未创建完毕先保存
        if (_currentView == null || this.activity == null) {
            _waiting_draw_infos = jsonObjectfromKVS("asset", asset, "infos", feed_infos, "data_array", feeds, "active_publisher_ids", active_publisher_ids, "publisher_type", publisher_type)
            return
        }

        val chainMgr = ChainObjectManager.sharedChainObjectManager()

        val bitAssetDataOptions = feed_infos.getJSONObject("options")
        val short_backing_asset_id = bitAssetDataOptions.getString("short_backing_asset")

        val asset_precision = asset.getInt("precision")

        val sba_asset = chainMgr.getChainObjectByID(short_backing_asset_id)
        val sba_asset_precision = sba_asset.getInt("precision")
        val feed_lifetime_sec = bitAssetDataOptions.getInt("feed_lifetime_sec")

        val curr_feed_price_item = feed_infos.getJSONObject("current_feed").getJSONObject("settlement_price")
        val n_curr_feed_price = OrgUtils.calcPriceFromPriceObject(curr_feed_price_item, short_backing_asset_id, sba_asset_precision, asset_precision)

        //  刷新UI - 当前喂价
        val str_feed_price = if (n_curr_feed_price != null) n_curr_feed_price.toPriceAmountString() else "--"
        _currentView!!.findViewById<TextView>(R.id.label_txt_curr_feed).text = String.format("%s %s %s/%s",
                resources.getString(R.string.kVcFeedCurrentFeedPrice), str_feed_price, asset.getString("symbol"), sba_asset.getString("symbol"))

        //  列表
        val publishedAccountHash = JSONObject()
        val list = mutableListOf<JSONObject>()

        val missed_list = JSONArray()
        val expired_list = JSONArray()
        val now_ts = Utils.now_ts()

        for (json in feeds.forin<JSONArray>()) {
            val publisher_account_id = json!!.getString(0)
            publishedAccountHash.put(publisher_account_id, true)

            val feed_info_ary = json.getJSONArray(1)
            val publish_date = feed_info_ary.getString(0)
            //  REMARK：指定喂价者多情况下，feed中永远存在数据，需要主动判断是否过期。见证人和理事会的情况下过期会自动从feed列表剔除。
            var expired = false
            if (publisher_type == EBitsharesFeedPublisherType.ebfpt_custom) {
                val publish_date_ts = Utils.parseBitsharesTimeString(publish_date)
                val diff_ts = max(now_ts - publish_date_ts, 0)
                if (diff_ts >= feed_lifetime_sec) {
                    expired = true
                }
            }

            val feed_data = feed_info_ary.getJSONObject(1)
            val name = chainMgr.getChainObjectByID(publisher_account_id).getString("name")
            val n_price = OrgUtils.calcPriceFromPriceObject(feed_data.getJSONObject("settlement_price"), short_backing_asset_id, sba_asset_precision, asset_precision)

            val change: BigDecimal
            if (n_curr_feed_price != null && n_price != null) {
                change = n_price.divide(n_curr_feed_price, 4, BigDecimal.ROUND_DOWN).subtract(BigDecimal.ONE).scaleByPowerOfTen(2)
            } else {
                change = BigDecimal.ZERO
            }

            if (n_price != null) {
                val v = jsonObjectfromKVS("name", name, "price", n_price, "diff", change, "date", publish_date, "expired", expired)
                if (expired) {
                    expired_list.put(v)
                } else {
                    list.add(v)
                }
            } else {
                //  REMARK：手动指定喂价者，但没发布信息。计算的价格为 nil。
                missed_list.put(JSONObject().apply {
                    put("name", name)
                    put("miss", true)
                })
            }
        }

        //  有效的喂价：按照价格降序排列
        list.sortByDescending { (it.get("price") as BigDecimal).toDouble() }

        //  添加过期的喂价（仅手动指定发布者的时候才存在）
        expired_list.forEach<JSONObject> { list.add(it!!) }

        //  添加未发布的喂价者信息
        missed_list.forEach<JSONObject> { list.add(it!!) }

        //  添加MISS的见证人
        active_publisher_ids.forEach<String> { account_id ->
            if (!publishedAccountHash.optBoolean(account_id!!, false)) {
                val name = chainMgr.getChainObjectByID(account_id).getString("name")
                list.add(JSONObject().apply {
                    put("name", name)
                    put("miss", true)
                })
            }
        }

        //  描绘
        val line_height = 28.0f
        val lay = _currentView!!.findViewById<LinearLayout>(R.id.layout_fragment_detail_feedprice)
        lay.removeAllViews()

        if (list.size > 0) {
            //  标题
            val name = when (publisher_type) {
                EBitsharesFeedPublisherType.ebfpt_witness -> resources.getString(R.string.kVcFeedWitnessName)
                EBitsharesFeedPublisherType.ebfpt_committee -> resources.getString(R.string.kVcFeedPublisherCommitteeName)
                else -> resources.getString(R.string.kVcFeedPublisherCustom)
            }
            lay.addView(createRow(_ctx!!, line_height, title = true, name = name))
            //  喂价数据
            list.forEach {
                val miss = it.optBoolean("miss")
                val expired = it.optBoolean("expired")
                lay.addView(
                        if (miss) {
                            createRow(_ctx!!, line_height, name = it.getString("name"), miss = true)
                        } else {
                            createRow(_ctx!!, line_height, it.getString("name"), it.get("price") as BigDecimal, it.get("diff") as BigDecimal, it.getString("date"), expired = expired)
                        }
                )
            }
        } else {
            lay.addView(ViewUtils.createEmptyCenterLabel(_ctx!!, R.string.kVcFeedNoFeedData.xmlstring(_ctx!!)))
        }
    }

    private fun createRow(ctx: Context, line_height: Float, name: String, price: BigDecimal? = null, diff: BigDecimal? = null, date: String = "",
                          title: Boolean = false, miss: Boolean = false, expired: Boolean = false): TableRow {
        val row_height = Utils.toDp(line_height, this.resources)

        val color = if (title || miss || expired) R.color.theme01_textColorNormal else R.color.theme01_textColorMain

        val table_row = TableRow(ctx)
        val table_row_params = TableRow.LayoutParams(TableRow.LayoutParams.MATCH_PARENT, row_height)
        table_row.orientation = TableRow.HORIZONTAL
        table_row.layoutParams = table_row_params

        //  name
        val tv1 = ViewUtils.createTextView(ctx, name, 13f, color, false)
        tv1.setSingleLine(true)
        tv1.maxLines = 1
        tv1.ellipsize = TextUtils.TruncateAt.END
        val tv1_params = TableRow.LayoutParams(0, row_height)
        tv1_params.weight = 4f
        tv1_params.gravity = Gravity.CENTER_VERTICAL
        tv1.gravity = Gravity.LEFT or Gravity.CENTER_VERTICAL
        tv1.layoutParams = tv1_params

        //  price
        val price_str = price?.toPlainString()
                ?: (if (miss) "--" else R.string.kVcFeedPriceName.xmlstring(_ctx!!))
        val tv2 = ViewUtils.createTextView(ctx, price_str, 13f, color, false)
        tv2.setSingleLine(true)
        tv2.maxLines = 1
        tv2.ellipsize = TextUtils.TruncateAt.END
        val tv2_params = TableRow.LayoutParams(0, row_height)
        tv2_params.weight = 3f
        tv2_params.gravity = Gravity.CENTER_VERTICAL
        tv2.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
        tv2.layoutParams = tv2_params

        //  bias
        var diffstr = R.string.kVcFeedRate.xmlstring(_ctx!!)
        var diffcolor = color
        if (!title) {
            if (miss) {
                diffstr = "--"
            } else {
                diffstr = diff!!.toPlainString()
                val result = diff.compareTo(BigDecimal.ZERO)
                if (result > 0) {
                    diffstr = "+${diff.toPlainString()}"
                    diffcolor = R.color.theme01_buyColor
                } else if (result < 0) {
                    diffcolor = R.color.theme01_sellColor
                }
                diffstr = "${diffstr}%"
            }
        }
        val tv3 = ViewUtils.createTextView(ctx, diffstr, 13f, diffcolor, false)
        tv3.setSingleLine(true)
        tv3.maxLines = 1
        tv3.ellipsize = TextUtils.TruncateAt.END
        val tv3_params = TableRow.LayoutParams(0, row_height)
        tv3_params.weight = 2f
        tv3_params.gravity = Gravity.CENTER_VERTICAL
        tv3.gravity = Gravity.CENTER or Gravity.CENTER_VERTICAL
        tv3.layoutParams = tv3_params

        //  publish date
        val datestr = if (title) {
            resources.getString(R.string.kVcFeedPublishDate)
        } else if (miss) {
            resources.getString(R.string.kVcFeedNoData)
        } else if (expired) {
            resources.getString(R.string.kVcFeedExpired)
        } else {
            Utils.fmtFeedPublishDateString(_ctx!!, date)
        }
        val tv4 = ViewUtils.createTextView(ctx, datestr, 13f, color, false)
        tv4.setSingleLine(true)
        tv4.maxLines = 1
        tv4.ellipsize = TextUtils.TruncateAt.END
        val tv4_params = TableRow.LayoutParams(0, row_height)
        tv4_params.weight = 3f
        tv4_params.gravity = Gravity.CENTER_VERTICAL
        tv4.gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
        tv4.layoutParams = tv4_params

        table_row.addView(tv1)
        table_row.addView(tv2)
        table_row.addView(tv3)
        table_row.addView(tv4)

        return table_row
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? {
        super.onCreateView(inflater, container, savedInstanceState)
        _ctx = inflater.context
        val v: View = inflater.inflate(R.layout.fragment_feed_price, container, false)
        v.findViewById<ImageView>(R.id.tip_link_feedprice).setOnClickListener {
            VcUtils.gotoQaView(activity!!, "qa_feedprice", resources.getString(R.string.kVcTitleWhatIsFeedPrice))
        }
        _currentView = v
        //  refresh UI
        if (_waiting_draw_infos != null) {
            val asset = _waiting_draw_infos!!.getJSONObject("asset")
            val infos = _waiting_draw_infos!!.getJSONObject("infos")
            val data_array = _waiting_draw_infos!!.getJSONArray("data_array")
            val active_publisher_ids = _waiting_draw_infos!!.getJSONArray("active_publisher_ids")
            val publisher_type = _waiting_draw_infos!!.get("publisher_type") as EBitsharesFeedPublisherType
            _waiting_draw_infos = null
            onQueryFeedInfoResponsed(asset, infos, data_array, active_publisher_ids, publisher_type)
        }
        return v
    }

    // TODO: Rename method, update argument and hook method into UI event
    fun onButtonPressed(uri: Uri) {
        listener?.onFragmentInteraction(uri)
    }

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
}
