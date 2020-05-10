package com.btsplusplus.fowallet

import android.os.Bundle
import android.view.View
import android.widget.TextView
import bitshares.*
import kotlinx.android.synthetic.main.activity_otc_mc_ad_update.*
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal

class ActivityOtcMcAdUpdate : BtsppActivity() {

    private lateinit var _ad_type_list: JSONArray
    private lateinit var _asset_type_list: JSONArray

    private lateinit var _auth_info: JSONObject
    private lateinit var _merchant_detail: JSONObject
    private var _user_type = OtcManager.EOtcUserType.eout_merchant
    private var _result_promise: Promise? = null
    private lateinit var _ad_infos: JSONObject
    private var _bNewAd = false

    private var _assetList: JSONArray? = null //  服务器可用的资产列表
    private var _currBalance: BigDecimal? = null

    private fun onDeleteAdClicked() {
        UtilsAlert.showMessageConfirm(this, resources.getString(R.string.kWarmTips), resources.getString(R.string.kOtcMcAdTipAskDelete)).then {
            if (it != null && it as Boolean) {
                guardWalletUnlocked(true) { unlocked ->
                    if (unlocked) {
                        val otc = OtcManager.sharedOtcManager()
                        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
                        otc.merchantDeleteAd(otc.getCurrentBtsAccount(), _ad_infos.getString("adId")).then {
                            mask.dismiss()
                            showToast(resources.getString(R.string.kOtcMcAdSubmitTipDeleteOK))
                            //  返回上一个界面并刷新
                            _result_promise?.resolve(true)
                            _result_promise = null
                            finish()
                            return@then null
                        }.catch { err ->
                            mask.dismiss()
                            otc.showOtcError(this, err)
                        }
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_mc_ad_update)
        // 设置全屏
        setFullScreen()

        //  获取参数
        val args = btspp_args_as_JSONObject()
        _auth_info = args.getJSONObject("auth_info")
        _merchant_detail = args.getJSONObject("merchant_detail")
        _user_type = args.get("user_type") as OtcManager.EOtcUserType
        _result_promise = args.opt("result_promise") as? Promise
        val curr_ad_info = args.optJSONObject("ad_info")
        if (curr_ad_info != null) {
            _bNewAd = false
            _ad_infos = curr_ad_info.shadowClone()
        } else {
            _bNewAd = true
            //  初始化新广告的部分默认值 TODO:3.0 后期可调整
            _ad_infos = JSONObject().apply {
                put("legalCurrencySymbol", OtcManager.sharedOtcManager().getFiatCnyInfo().getString("legalCurrencySymbol"))
                put("priceType", OtcManager.EOtcPriceType.eopt_price_fixed.value)
            }
        }

        //  UI - 导航栏标题
        if (_bNewAd) {
            btn_delete_ad.visibility = View.INVISIBLE
            findViewById<TextView>(R.id.title).text = resources.getString(R.string.kVcTitleOtcMcCreateAd)
            btn_submit_01.text = resources.getString(R.string.kOtcMcAdBtnPublishAd)
            btn_submit_02.text = resources.getString(R.string.kOtcMcAdBtnSaveAd)
        } else {
            findViewById<TextView>(R.id.title).text = resources.getString(R.string.kVcTitleOtcMcUpdateAd)
            btn_delete_ad.setOnClickListener { onDeleteAdClicked() }
            if (_ad_infos.getInt("status") == OtcManager.EOtcAdStatus.eoads_online.value) {
                btn_submit_01.text = resources.getString(R.string.kOtcMcAdBtnUpdateAd)
            } else {
                btn_submit_01.text = resources.getString(R.string.kOtcMcAdBtnUpdateAndUpAd)
            }
            btn_submit_02.visibility = View.GONE
        }

        //  描绘数据
        refreshUI()

        //  各种事件
        if (_bNewAd) {
            //  新建时才可点击
            layout_ad_type.setOnClickListener { onAdTypeClicked() }
            layout_asset_symbol.setOnClickListener { onAssetSymbolClicked() }
        }
        layout_your_price.setOnClickListener { onYourPriceClicked() }
        layout_trade_amount.setOnClickListener { onTradeAmountClicked() }
        layout_min_limit.setOnClickListener { onMinLimitClicked() }
        layout_max_limit.setOnClickListener { onMaxLimitClicked() }
        layout_remark.setOnClickListener { onRemarkClicked() }
        if (_bNewAd) {
            btn_submit_01.setOnClickListener { onSubmitClicked(false) }
            btn_submit_02.setOnClickListener { onSubmitClicked(true) }
        } else {
            btn_submit_01.setOnClickListener { onSubmitClicked(false) }
        }
        layout_back_from_otc_mc_ad_update.setOnClickListener { finish() }

        //  查询数据
        queryAssetsAndBalance()
    }

    private fun onlyQueryBalance(assetSymbol: String, success_callback: () -> Unit) {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

        otc.queryMerchantAssetBalance(otc.getCurrentBtsAccount(), _merchant_detail.getString("otcAccount"), _merchant_detail.getInt("id"),
                assetSymbol).then {
            mask.dismiss()
            val data = it as JSONObject
            _currBalance = Utils.auxGetStringDecimalNumberValue(data.getString("data"))
            success_callback()
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

    private fun onQueryAssetsAndBalanceResponsed(data_hash: JSONObject) {
        _assetList = data_hash.getJSONObject("kQueryAssetList").optJSONArray("data")
        //  兼容
        if (_assetList != null && _assetList!!.length() == 0) {
            _assetList = null
        }
        if (_bNewAd) {
            _currBalance = null
        } else {
            _currBalance = Utils.auxGetStringDecimalNumberValue(data_hash.getJSONObject("kQueryBalance").getString("data"))
        }
        refreshUI()
    }

    private fun queryAssetsAndBalance() {
        val otc = OtcManager.sharedOtcManager()
        val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }

        val promise_map = JSONObject()
        promise_map.put("kQueryAssetList", otc.queryAssetList(OtcManager.EOtcAssetType.eoat_digital))
        if (!_bNewAd) {
            promise_map.put("kQueryBalance", otc.queryMerchantAssetBalance(otc.getCurrentBtsAccount(),
                    _merchant_detail.getString("otcAccount"), _merchant_detail.getInt("id"),
                    _ad_infos.getString("assetSymbol")))
        }
        Promise.map(promise_map).then {
            mask.dismiss()
            onQueryAssetsAndBalanceResponsed(it as JSONObject)
            return@then null
        }.catch { err ->
            mask.dismiss()
            otc.showOtcError(this, err)
        }
    }

    private fun refreshUI() {
        _drawUI_All()
    }

    private fun _drawUI_All() {
        //  1、广告类型
        if (_ad_infos.has("adType")) {
            if (_ad_infos.getInt("adType") == OtcManager.EOtcAdType.eoadt_merchant_buy.value) {
                tv_ad_type.text = resources.getString(R.string.kOtcMcAdEditCellAdTypeValueBuy)
                tv_ad_type.setTextColor(resources.getColor(R.color.theme01_buyColor))
            } else {
                tv_ad_type.text = resources.getString(R.string.kOtcMcAdEditCellAdTypeValueSell)
                tv_ad_type.setTextColor(resources.getColor(R.color.theme01_sellColor))
            }
        } else {
            tv_ad_type.text = resources.getString(R.string.kOtcMcAdEditCellAdTypeValueSelectPlaceholder)
            tv_ad_type.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
        //  新建的时候才可以编辑该字段
        if (!_bNewAd) {
            img_icon_arrow_ad_type.visibility = View.GONE
        } else {
            img_icon_arrow_ad_type.visibility = View.VISIBLE
        }

        //  2、数字资产
        if (_ad_infos.has("assetSymbol")) {
            tv_asset_symbol.text = _ad_infos.getString("assetSymbol")
            if (_bNewAd) {
                tv_asset_symbol.setTextColor(resources.getColor(R.color.theme01_textColorMain))
            } else {
                tv_asset_symbol.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
            }
        } else {
            tv_asset_symbol.text = resources.getString(R.string.kOtcMcAdEditCellAssetValueSelectPlaceholder)
            tv_asset_symbol.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
        //  新建的时候才可以编辑该字段
        if (!_bNewAd) {
            img_icon_arrow_asset_symbol.visibility = View.GONE
        } else {
            img_icon_arrow_asset_symbol.visibility = View.VISIBLE
        }

        //  3、法币 TODO:3.0 暂时固定一种
        tv_fiat_name.text = resources.getString(R.string.kOtcMcAdEditCellFiatAssetValueCN)
        if (_bNewAd) {
            tv_fiat_name.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            tv_fiat_name.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        }

        //  4、定价方式
        when (_ad_infos.getInt("priceType")) {
            OtcManager.EOtcPriceType.eopt_price_fixed.value -> {
                tv_price_type.text = resources.getString(R.string.kOtcMcAdEditCellPriceTypeFixed)
            }
            else -> {
                assert(false)
                tv_price_type.text = String.format(resources.getString(R.string.kOtcMcAdEditCellPriceTypeUnknown), _ad_infos.getString("priceType"))
            }
        }
        if (_bNewAd) {
            tv_price_type.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            tv_price_type.setTextColor(resources.getColor(R.color.theme01_textColorNormal))
        }

        //  5、您的价格
        _drawUI_cell_value(tv_your_price, _ad_infos.optString("price", null),
                resources.getString(R.string.kOtcMcAdEditCellYourPlacePlaceholder), true)

        //  6、交易数量
        _drawUI_cell_value(tv_trade_amount, _ad_infos.optString("quantity", null),
                resources.getString(R.string.kOtcMcAdEditCellAmountPlaceholder), false)

        //  7、可用
        if (_currBalance != null) {
            tv_balance.text = "${_currBalance!!.toPlainString()} ${_ad_infos.getString("assetSymbol")}"
        } else {
            tv_balance.text = "--"
        }

        //  8、最小限额
        _drawUI_cell_value(tv_min_limit, _ad_infos.optString("lowestLimit", null),
                resources.getString(R.string.kOtcMcAdEditCellMinLimitPlaceholder), true)

        //  9、最大限额
        _drawUI_cell_value(tv_max_limit, _ad_infos.optString("maxLimit", null),
                resources.getString(R.string.kOtcMcAdEditCellMaxLimitPlaceholder), true)

        //  10、交易说明
        _drawUI_cell_value(tv_remark, _ad_infos.optString("remark", null),
                resources.getString(R.string.kOtcMcAdEditCellRemarkPlaceholder), false)
    }

    private fun _drawUI_cell_value(label: TextView, value: Any?, default_text: String, fiatPrefix: Boolean) {
        if (value != null) {
            if (fiatPrefix) {
                label.text = "${OtcManager.sharedOtcManager().getFiatCnyInfo().getString("legalCurrencySymbol")}${value.toString()}"
            } else {
                label.text = value.toString()
            }
            label.setTextColor(resources.getColor(R.color.theme01_textColorMain))
        } else {
            label.text = default_text
            label.setTextColor(resources.getColor(R.color.theme01_textColorGray))
        }
    }

    /**
     * (private) 选择广告类型
     */
    private fun onAdTypeClicked() {
        assert(_bNewAd)

        val adTypeList = jsonArrayfrom(OtcManager.EOtcAdType.eoadt_merchant_buy, OtcManager.EOtcAdType.eoadt_merchant_sell)
        val nameList = jsonArrayfrom(resources.getString(R.string.kOtcMcAdEditCellAdTypeValueBuy), resources.getString(R.string.kOtcMcAdEditCellAdTypeValueSell))

        ViewSelector.show(this, "", nameList.toList<String>().toTypedArray()) { index: Int, _: String ->
            val select_ad_type = adTypeList.get(index) as OtcManager.EOtcAdType
            if (!_ad_infos.has("adType") || _ad_infos.getInt("adType") != select_ad_type.value) {
                _ad_infos.put("adType", select_ad_type.value)
                refreshUI()
            }
        }
    }

    /**
     * (private) 选择数字资产
     */
    private fun onAssetSymbolClicked() {
        assert(_bNewAd)
        if (_assetList == null) {
            return
        }
        val list = JSONArray()
        for (item in _assetList!!.forin<JSONObject>()) {
            list.put(item!!.getString("assetSymbol"))
        }

        ViewSelector.show(this, resources.getString(R.string.kOtcMcAdTipAskSelectAsset), list.toList<String>().toTypedArray()) { index: Int, _: String ->
            val select_asset_symbol = list.getString(index)
            var current_asset_symbol = _ad_infos.optString("assetSymbol", null)
            if (current_asset_symbol == null || current_asset_symbol != select_asset_symbol) {
                current_asset_symbol = select_asset_symbol
                onlyQueryBalance(current_asset_symbol) {
                    _ad_infos.put("assetSymbol", current_asset_symbol)
                    //  REMARK：切换数字资产的时候清空价格和交易数量。
                    _ad_infos.remove("price")
                    _ad_infos.remove("quantity")
                    //  刷新
                    refreshUI()
                }
            }
        }
    }

    private fun onYourPriceClicked() {
        val iFiatAssetPrecision = OtcManager.sharedOtcManager().getFiatCnyInfo().getInt("assetPrecision")
        UtilsAlert.showInputBox(this, title = resources.getString(R.string.kOtcMcAdTipAskInputYourPriceTitle),
                placeholder = resources.getString(R.string.kOtcMcAdTipAskInputYourPricePlaceholder),
                is_password = false, iDecimalPrecision = iFiatAssetPrecision).then {
            val value = it as? String
            if (value != null) {
                val n_value = Utils.auxGetStringDecimalNumberValue(value)
                if (n_value.compareTo(BigDecimal.ZERO) == 0) {
                    _ad_infos.remove("price")
                } else {
                    _ad_infos.put("price", n_value.toPlainString())
                }
                refreshUI()
            }
            return@then null
        }
    }

    private fun _getCurrentAsset(assetSymbol: String): JSONObject? {
        for (asset in _assetList!!.forin<JSONObject>()) {
            if (asset!!.getString("assetSymbol") == assetSymbol) {
                return asset
            }
        }
        return null
    }

    private fun onTradeAmountClicked() {
        if (_assetList == null) {
            return
        }

        val current_asset_symbol = _ad_infos.optString("assetSymbol", null)
        if (current_asset_symbol == null || current_asset_symbol.isEmpty()) {
            showToast(resources.getString(R.string.kOtcMcAdSelectAmountTipFirstSelectAsset))
            return
        }

        val current_asset = _getCurrentAsset(current_asset_symbol)
        if (current_asset == null) {
            showToast(String.format(resources.getString(R.string.kOtcMcAdSelectAmountTipUnkownAsset), current_asset_symbol))
            return
        }

        val assetPrecision = current_asset.getInt("assetPrecision")
        UtilsAlert.showInputBox(this, title = resources.getString(R.string.kOtcMcAdTipAskInputAmountTitle),
                placeholder = resources.getString(R.string.kOtcMcAdTipAskInputAmountPlaceholder),
                is_password = false, iDecimalPrecision = assetPrecision).then {
            val value = it as? String
            if (value != null) {
                val n_value = Utils.auxGetStringDecimalNumberValue(value)
                if (n_value.compareTo(BigDecimal.ZERO) == 0) {
                    _ad_infos.remove("quantity")
                } else {
                    _ad_infos.put("quantity", n_value.toPlainString())
                }
                refreshUI()
            }
            return@then null
        }
    }

    private fun onMinLimitClicked() {
        UtilsAlert.showInputBox(this, title = resources.getString(R.string.kOtcMcAdTipAskInputMinLimitTitle),
                placeholder = resources.getString(R.string.kOtcMcAdTipAskInputMinLimitPlaceholder),
                is_password = false, iDecimalPrecision = 0).then {
            val value = it as? String
            if (value != null) {
                val n_value = Utils.auxGetStringDecimalNumberValue(value)
                if (n_value.compareTo(BigDecimal.ZERO) == 0) {
                    _ad_infos.remove("lowestLimit")
                } else {
                    _ad_infos.put("lowestLimit", n_value.toPlainString())
                }
                refreshUI()
            }
            return@then null
        }
    }

    private fun onMaxLimitClicked() {
        UtilsAlert.showInputBox(this, title = resources.getString(R.string.kOtcMcAdTipAskInputMaxLimitTitle),
                placeholder = resources.getString(R.string.kOtcMcAdTipAskInputMaxLimitPlaceholder),
                is_password = false, iDecimalPrecision = 0).then {
            val value = it as? String
            if (value != null) {
                val n_value = Utils.auxGetStringDecimalNumberValue(value)
                if (n_value.compareTo(BigDecimal.ZERO) == 0) {
                    _ad_infos.remove("maxLimit")
                } else {
                    _ad_infos.put("maxLimit", n_value.toPlainString())
                }
                refreshUI()
            }
            return@then null
        }
    }

    private fun onRemarkClicked() {
        UtilsAlert.showInputBox(this, title = resources.getString(R.string.kOtcMcAdTipAskInputRemarkTitle),
                placeholder = resources.getString(R.string.kOtcMcAdTipAskInputRemarkPlaceholder),
                is_password = false).then {
            val value = it as? String
            if (value != null) {
                _ad_infos.put("remark", value)
                refreshUI()
            }
            return@then null
        }
    }

    /**
     * (private) 事件 - 提交
     */
    private fun onSubmitClicked(onlySaveAd: Boolean) {
        if (!_ad_infos.has("adType")) {
            showToast(resources.getString(R.string.kOtcMcAdSubmitTipPleaseSelectAdType))
            return
        }
        val adType = _ad_infos.getInt("adType")
        val assetSymbol = _ad_infos.optString("assetSymbol", null)
        if (assetSymbol == null || assetSymbol.isEmpty()) {
            showToast(resources.getString(R.string.kOtcMcAdSubmitTipPleaseSelectAsset))
            return
        }

        val current_asset = _getCurrentAsset(assetSymbol)
        if (current_asset == null) {
            showToast(String.format(resources.getString(R.string.kOtcMcAdSelectAmountTipUnkownAsset), assetSymbol))
            return
        }

        val lowestLimit = _ad_infos.optInt("lowestLimit")
        if (lowestLimit <= 0) {
            showToast(resources.getString(R.string.kOtcMcAdSubmitTipPleaseInputMinLimit))
            return
        }
        val maxLimit = _ad_infos.optInt("maxLimit")
        if (maxLimit <= 0) {
            showToast(resources.getString(R.string.kOtcMcAdSubmitTipPleaseInputMaxLimit))
            return
        }
        if (lowestLimit >= maxLimit) {
            showToast(resources.getString(R.string.kOtcMcAdSubmitTipErrorMaxLimit))
            return
        }
        if (lowestLimit % 100 != 0 || maxLimit % 100 != 0) {
            showToast(resources.getString(R.string.kOtcMcAdSubmitTipErrorMinOrMaxLimitValue))
            return
        }

        val n_price = Utils.auxGetStringDecimalNumberValue(_ad_infos.optString("price"))
        if (n_price <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kOtcMcAdSubmitTipPleaseInputPrice))
            return
        }

        val n_quantity = Utils.auxGetStringDecimalNumberValue(_ad_infos.optString("quantity"))
        if (n_quantity <= BigDecimal.ZERO) {
            showToast(resources.getString(R.string.kOtcMcAdSubmitTipPleaseInputAmount))
            return
        }

        //  【商家出售】的情况需要判断余额是否足够。
        if (adType == OtcManager.EOtcAdType.eoadt_merchant_sell.value) {
            if (n_quantity > _currBalance) {
                showToast(resources.getString(R.string.kOtcMcAdSubmitTipBalanceNotEnough))
                return
            }
        }

        //  参数校验完毕开始执行操作
        guardWalletUnlocked(true) { unlocked ->
            if (unlocked) {
                val otc = OtcManager.sharedOtcManager()
                val ad_args = if (_bNewAd) {
                    JSONObject().apply {
                        //put("adId", "")
                        put("adType", adType)
                        put("assetId", current_asset.getString("assetId"))
                        put("assetSymbol", _ad_infos.getString("assetSymbol"))
                        put("btsAccount", otc.getCurrentBtsAccount())
                        put("legalCurrencySymbol", _ad_infos.getString("legalCurrencySymbol"))
                        put("lowestLimit", lowestLimit.toString())
                        put("maxLimit", maxLimit.toString())
                        put("merchantId", _merchant_detail.getInt("id"))
                        put("otcBtsId", _merchant_detail.getString("otcAccountId"))
                        put("price", n_price.toPlainString())
                        put("priceType", _ad_infos.getInt("priceType"))
                        put("quantity", n_quantity.toPlainString())
                        put("remark", _ad_infos.optString("remark"))
                    }
                } else {
                    JSONObject().apply {
                        put("adId", _ad_infos.getString("adId"))
                        put("adType", adType)
                        put("assetId", _ad_infos.getString("assetId"))
                        put("assetSymbol", _ad_infos.getString("assetSymbol"))
                        put("btsAccount", otc.getCurrentBtsAccount())
                        put("legalCurrencySymbol", _ad_infos.getString("legalCurrencySymbol"))
                        put("lowestLimit", lowestLimit.toString())
                        put("maxLimit", maxLimit.toString())
                        put("merchantId", _ad_infos.getInt("merchantId"))
                        put("otcBtsId", _ad_infos.getString("otcBtsId"))
                        put("price", n_price.toPlainString())
                        put("priceType", _ad_infos.getInt("priceType"))
                        put("quantity", n_quantity.toPlainString())
                        put("remark", _ad_infos.optString("remark"))
                    }
                }
                val mask = ViewMask(resources.getString(R.string.kTipsBeRequesting), this).apply { show() }
                val p1 = if (onlySaveAd) otc.merchantCreateAd(ad_args) else otc.merchantUpdateAd(ad_args)
                p1.then {
                    mask.dismiss()
                    if (_bNewAd) {
                        if (onlySaveAd) {
                            showToast(resources.getString(R.string.kOtcMcAdSubmitTipSaveOK))
                        } else {
                            showToast(resources.getString(R.string.kOtcMcAdSubmitTipPublishOK))
                        }
                    } else {
                        showToast(resources.getString(R.string.kOtcMcAdSubmitTipUpdateOK))
                    }
                    //  返回上一个界面并刷新
                    _result_promise?.resolve(true)
                    _result_promise = null
                    finish()
                    return@then null
                }.catch { err ->
                    mask.dismiss()
                    otc.showOtcError(this, err)
                }
            }
        }
    }

}
