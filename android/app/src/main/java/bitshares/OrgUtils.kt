package bitshares

import android.content.Context
import android.os.Looper
import com.btsplusplus.fowallet.NativeInterface
import com.btsplusplus.fowallet.R
import com.btsplusplus.fowallet.utils.BigDecimalHandler
import com.crashlytics.android.Crashlytics
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.math.BigDecimal
import java.math.BigInteger
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import java.net.URLEncoder
import java.text.DecimalFormat
import kotlin.math.max
import kotlin.math.pow

class OrgUtils {

    companion object {

        /**
         * 初始化（启动时调用）
         */
        fun initDir(ctx: Context) {
            _file_base_dir = ctx.filesDir.path
            Crashlytics.setString("BaseDir", _file_base_dir)
        }

        /**
         * 获取版本依赖文件的完整文件名（路径）       /AppCache/ver/#{curr_version}_filename
         */
        fun makeFullPathByVerStorage(): String {
            //  TODO:未完成
            return ""
        }

        /**
         *  获取webserver导入目录
         */
        fun getAppDirWebServerImport(): String {
            return makePathFromApplicationFilesDirectory("${kAppLocalFileNameBase}/${kAppLocalFileNameByAppStorage}/${kAppWebServerImportDir}/")
        }

        /**
         * 获取app依赖文件的完整文件名（路径）      /AppCache/app/filename
         */
        fun makeFullPathByAppStorage(filename: String): String {
            return makePathFromApplicationFilesDirectory("${kAppLocalFileNameBase}/${kAppLocalFileNameByAppStorage}/${filename}")
        }

        private var _file_base_dir: String? = null
        private fun makePathFromApplicationFilesDirectory(filename: String): String {
            return "${_file_base_dir!!}/${filename}"
        }

        /**
         * (public) 写入文件
         */
        fun write_file(fullpath: String, data: ByteArray): Boolean {
            try {
                var file = File(fullpath)
                if (!file.exists()) {
                    file.mkdirs()
                }
                file.delete()
                file.writeBytes(data)
                return true
            } catch (e: Exception) {
                return false
            }
        }

        /**
         * (public) 读取文件，失败返回 null。
         */
        fun load_file(fullpath: String): ByteArray? {
            try {
                return File(fullpath).readBytes()
            } catch (e: Exception) {
                return null
            }
        }

        fun write_file_from_json(fullpath: String, json: JSONObject): Boolean {
            return write_file(fullpath, json.toString().utf8String())
        }

        fun load_file_as_json(fullpath: String): JSONObject? {
            var data = load_file(fullpath)
            if (data == null) {
                return null
            }
            val str = data.utf8String()
            try {
                return JSONObject(str)
            } catch (e: Exception) {
                return null
            }
        }

        /**
         * 根据 get_full_accounts 接口返回的所有用户信息计算用户所有资产信息、挂单信息、抵押信息、债务信息等。
         * 返回值 {validBalancesHash, limitValuesHash, callValuesHash, debtValuesHash}
         */
        fun calcUserAssetDetailInfos(full_account_data: JSONObject): JSONObject {
            //  --- 整理资产 ---
            //  a.计算所有资产的总挂单量信息
            val limit_orders_values = JSONObject()
            val limit_orders = full_account_data.optJSONArray("limit_orders")
            if (limit_orders != null) {
                for (order in limit_orders) {
                    //  限价单卖 base 资产，卖的数量为 for_sale 字段。sell_price 只是价格信息。
                    val sell_asset_id = order!!.getJSONObject("sell_price").getJSONObject("base").getString("asset_id")
                    val sell_amount = BigInteger(order.getString("for_sale"))
                    //  所有挂单累加
                    var value = limit_orders_values.opt(sell_asset_id) as? BigInteger
                    value = value?.add(sell_amount) ?: sell_amount
                    limit_orders_values.put(sell_asset_id, value)
                }
            }
            //  b.计算所有资产的总抵押量信息（目前抵押资产仅有BTS）和总债务信息（CNY、USD等）
            val call_orders_values = JSONObject()
            val debt_values = JSONObject()
            val call_orders = full_account_data.optJSONArray("call_orders")
            if (call_orders != null) {
                for (order in call_orders) {
                    val call_price = order!!.getJSONObject("call_price")
                    //  a.计算抵押
                    val asset_id = call_price.getJSONObject("base").getString("asset_id")
                    val amount = BigInteger(order.getString("collateral"))
                    //  所有抵押累加
                    var value = call_orders_values.opt(asset_id) as? BigInteger
                    value = value?.add(amount) ?: amount
                    call_orders_values.put(asset_id, value)
                    //  b.计算债务
                    val debt_asset_id = call_price.getJSONObject("quote").getString("asset_id")
                    val debt_amount = BigInteger(order.getString("debt"))
                    //  所有债务累加
                    var debt_value = debt_values.opt(debt_asset_id) as? BigInteger
                    debt_value = debt_value?.add(debt_amount) ?: debt_amount
                    debt_values.put(debt_asset_id, debt_value)
                }
            }
            //  c.去掉余额为0的资产
            val validBalancesHash = JSONObject()
            for (balance in full_account_data.getJSONArray("balances")) {
                if (balance!!.getString("balance").toLong() != 0L) {
                    validBalancesHash.put(balance.getString("asset_type"), balance)
                }
            }
            //  d.添加必须显示的资产（BTS、有挂单没余额、有抵押没余额、有债务没余额）
            val core_asset = validBalancesHash.optJSONObject(BTS_NETWORK_CORE_ASSET_ID)
            //  没余额，初始化默认值。
            if (core_asset == null) {
                validBalancesHash.put(BTS_NETWORK_CORE_ASSET_ID, jsonObjectfromKVS("asset_type", BTS_NETWORK_CORE_ASSET_ID, "balance", 0))
            }
            for (asset_id in limit_orders_values.keys()) {
                val asset = validBalancesHash.optJSONObject(asset_id)
                //  没余额，初始化默认值。
                if (asset == null) {
                    validBalancesHash.put(asset_id, jsonObjectfromKVS("asset_type", asset_id, "balance", 0))
                }
            }
            for (asset_id in call_orders_values.keys()) {
                val asset = validBalancesHash.optJSONObject(asset_id)
                //  没余额，初始化默认值。
                if (asset == null) {
                    validBalancesHash.put(asset_id, jsonObjectfromKVS("asset_type", asset_id, "balance", 0))
                }
            }
            for (asset_id in debt_values.keys()) {
                val asset = validBalancesHash.optJSONObject(asset_id)
                //  没余额，初始化默认值。
                if (asset == null) {
                    validBalancesHash.put(asset_id, jsonObjectfromKVS("asset_type", asset_id, "balance", 0))
                }
            }
            //  返回
            return jsonObjectfromKVS("validBalancesHash", validBalancesHash, "limitValuesHash", limit_orders_values, "callValuesHash", call_orders_values, "debtValuesHash", debt_values)
        }

        /**
         *  (public) 计算在爆仓时最少需要卖出的资产数量，如果没设置目标抵押率则全部卖出。如果有设置则根据目标抵押率计算。
         */
        fun calcSettlementSellNumbers(call_order: JSONObject, debt_precision: Int, collateral_precision: Int, feed_price: BigDecimal, call_price: BigDecimal, mcr: BigDecimal, mssr: BigDecimal): BigDecimal {
            val collateral = call_order.getString("collateral")
            val debt = call_order.getString("debt")
            val n_collateral = bigDecimalfromAmount(collateral, collateral_precision)
            val n_debt = bigDecimalfromAmount(debt, debt_precision)

            val ceil_handler = BigDecimalHandler(BigDecimal.ROUND_UP, collateral_precision)

            val target_collateral_ratio = call_order.optString("target_collateral_ratio", null)
            if (target_collateral_ratio != null) {
                //  卖出部分，只要抵押率回到目标抵押率即可。
                //  =============================================================
                //  公式：n为最低卖出数量
                //  即 新抵押率 = 新总估值 / 新总负债
                //
                //  (collateral - n) * feed_price
                //  -----------------------------  >= target_collateral_ratio
                //  (debt - n * feed_price / mssr)
                //
                //  即:
                //          target_collateral_ratio * debt - feed_price * collateral
                //  n >= --------------------------------------------------------------
                //          feed_price * (target_collateral_ratio / mssr - 1)
                //  =============================================================
                var n_target_collateral_ratio = bigDecimalfromAmount(target_collateral_ratio, 3)

                //  目标抵押率和MCR之间取最大值
                if (n_target_collateral_ratio < mcr) {
                    n_target_collateral_ratio = mcr
                }

                //  开始计算
                val n1 = n_target_collateral_ratio.multiply(n_debt).subtract(feed_price.multiply(n_collateral))
                val n2 = feed_price.multiply(n_target_collateral_ratio.divide(mssr, kBigDecimalDefaultMaxPrecision, kBigDecimalDefaultRoundingMode).subtract(BigDecimal.ONE))
                return n1.divide(n2, ceil_handler.scale, ceil_handler.roundingMode)
            } else {
                //  卖出部分，覆盖所有债务即可。
                return n_debt.divide(call_price, ceil_handler.scale, ceil_handler.roundingMode)
            }
        }

        /**
         * (public) 计算强平触发价格。
         * call_price = (debt × MCR) ÷ collateral
         */
        fun calcSettlementTriggerPrice(debt_amount: String, collateral_amount: String, debt_precision: Int, collateral_precision: Int, n_mcr: BigDecimal, invert: Boolean, handler: BigDecimalHandler?, set_divide_precision: Boolean): BigDecimal {
            val n_debt = bigDecimalfromAmount(debt_amount, debt_precision)
            val n_collateral = bigDecimalfromAmount(collateral_amount, collateral_precision)

            var n = n_debt.multiply(n_mcr)
            if (set_divide_precision) {
                val cell_hanndler = handler
                        ?: BigDecimalHandler(BigDecimal.ROUND_UP, if (invert) collateral_precision else debt_precision)
                n = if (invert) {
                    BigDecimal.ONE.divide(n.divide(n_collateral, kBigDecimalDefaultMaxPrecision, kBigDecimalDefaultRoundingMode), cell_hanndler.scale, cell_hanndler.roundingMode)
                } else {
                    n.divide(n_collateral, cell_hanndler.scale, cell_hanndler.roundingMode)
                }
            } else {
                n = n.divide(n_collateral, kBigDecimalDefaultMaxPrecision, kBigDecimalDefaultRoundingMode)
                if (invert) {
                    n = BigDecimal.ONE.divide(n, kBigDecimalDefaultMaxPrecision, kBigDecimalDefaultRoundingMode)
                }
            }

            return n
        }

        /**
         *  (public) 合并普通盘口信息和爆仓单信息。
         */
        fun mergeOrderBook(normal_order_book: JSONObject, settlement_data: JSONObject?): JSONObject {
            if (settlement_data != null && settlement_data.optInt("settlement_account_number") > 0) {
                var bidArray = normal_order_book.getJSONArray("bids")
                var askArray = normal_order_book.getJSONArray("asks")

                val n_call_price = settlement_data.get("call_price_market") as BigDecimal
                val f_call_price = n_call_price.toDouble()

                val new_array = JSONArray()
                var new_amount_sum = 0.0
                var inserted = false
                val invert = settlement_data.getBoolean("invert")

                for (item in (if (invert) bidArray else askArray).forin<JSONObject>()) {
                    val order = item!!
                    val f_price = order.getDouble("price")
                    val f_quote = order.getDouble("quote")
                    val keep = if (invert) {
                        f_price > f_call_price
                    } else {
                        f_price < f_call_price
                    }
                    if (keep) {
                        new_amount_sum += f_quote
                        new_array.put(order)
                        continue
                    }
                    if (!inserted) {
                        //  insert
                        val quote_amount: Double
                        val base_amount: Double
                        val total_sell_amount = (settlement_data.get("total_sell_amount") as BigDecimal).toDouble()
                        val total_buy_amount = (settlement_data.get("total_buy_amount") as BigDecimal).toDouble()
                        if (invert) {
                            quote_amount = total_buy_amount
                            base_amount = total_sell_amount
                        } else {
                            quote_amount = total_sell_amount
                            base_amount = total_buy_amount
                        }
                        new_amount_sum += quote_amount

                        new_array.put(JSONObject().apply {
                            put("price", f_call_price)
                            put("quote", quote_amount)
                            put("base", base_amount)
                            put("sum", new_amount_sum)
                            put("iscall", true)
                        })

                        inserted = true
                    }

                    new_amount_sum += f_quote
                    val base = order.get("base")
                    new_array.put(JSONObject().apply {
                        put("price", f_price)
                        put("quote", f_quote)
                        put("base", base)
                        put("sum", new_amount_sum)
                    })
                }

                if (invert) {
                    bidArray = new_array
                } else {
                    askArray = new_array
                }

                //  返回新的 order book
                return jsonObjectfromKVS("bids", bidArray, "asks", askArray)
            } else {
                return normal_order_book
            }
        }

        /**
         *  计算资产真实价格
         */
        fun calcAssetRealPrice(amount: Any, precision: Int): Double {
            val d = amount.toString().toLong()
            val fPrecision = Math.pow(10.0, precision.toDouble())
            return d / fPrecision
        }

        /**
         * 根据 price_item 计算价格。REMARK：price_item 包含 base 和 quote 对象，base 和 quote 包含 asset_id 和 amount 字段。
         */
        fun calcPriceFromPriceObject(price_item: JSONObject, base_id: String, base_precision: Int, quote_precision: Int, invert: Boolean = false, roundingMode: Int = BigDecimal.ROUND_HALF_UP, set_divide_precision: Boolean = true): BigDecimal? {
            val item01 = price_item.getJSONObject("base")
            val item02 = price_item.getJSONObject("quote")
            val base: JSONObject
            val quote: JSONObject
            if (item01.getString("asset_id") == base_id) {
                base = item01
                quote = item02
            } else {
                base = item02
                quote = item01
            }

            val s_base_amount = base.getString("amount")
            val s_quote_amount = quote.getString("amount")
            //  REMARK：价格失效（比如喂价过期等情况）
            if (s_base_amount.toLong() == 0L || s_quote_amount.toLong() == 0L) {
                return null
            }

            val n_base = bigDecimalfromAmount(s_base_amount, base_precision)
            val n_quote = bigDecimalfromAmount(s_quote_amount, quote_precision)

            return if (set_divide_precision) {
                if (invert) {
                    n_base.divide(n_quote, base_precision, roundingMode)
                } else {
                    n_quote.divide(n_base, quote_precision, roundingMode)
                }
            } else {
                if (invert) {
                    n_base.divide(n_quote, kBigDecimalDefaultMaxPrecision, roundingMode)
                } else {
                    n_quote.divide(n_base, kBigDecimalDefaultMaxPrecision, roundingMode)
                }
            }
        }

        /**
         * 格式化数字，可以指定是否用逗号分组。
         */
        fun formatFloatValue(value: Double, precision: Int, has_comma: Boolean = true): String {
            val repeat_s = "#".repeat(max(precision, 1))
            val decimalFormat = DecimalFormat(",###.${repeat_s}")
            //  是否有逗号分组分隔符
            decimalFormat.isGroupingUsed = has_comma
            return decimalFormat.format(value)
        }

        fun formatAssetString(value: String, precision: Int, has_comma: Boolean = true): String {
            val v = value.toDouble()
            val p = 10.0f.pow(precision)
            return formatFloatValue(v / p, precision, has_comma)
        }

        /**
         *  (public) format 'ASSET' object to string, e.g.: 2323.32BTS
         */
        fun formatAssetAmountItem(asset_json: JSONObject): String {
            val asset_id = asset_json.getString("asset_id")
            val amount = asset_json.getString("amount")
            val asset = ChainObjectManager.sharedChainObjectManager().getChainObjectByID(asset_id)
            val num = formatAssetString(amount, asset.getInt("precision"))
            return "${num}${asset.getString("symbol")}"
        }

        /**
         * 异步等待，单位毫秒。
         */
        fun asyncWait(ms: Long): Promise {
            val p = Promise()
            android.os.Handler(Looper.getMainLooper()).postDelayed({ p.resolve(true) }, ms)
            return p
        }

        /**
         * 异步POST请求：表单参数。
         */
        fun asyncPost(url: String, args: JSONObject): Promise {
            val p = Promise()
            _asyncExecRequest(p, url, body = _makeKeyValueString(args), headers = JSONObject().apply {
                put("Content-Type", "application/x-www-form-urlencoded")
            })
            return p
        }

        /**
         * 异步POST请求：body参数
         */
        fun asyncPost_jsonBody(url: String, args: JSONObject): Promise {
            val p = Promise()
            _asyncExecRequest(p, url, body = args.toString(), headers = JSONObject().apply {
                put("Content-Type", "application/json")
            })
            return p
        }

        /**
         * 异步GET请求
         */
        fun asyncJsonGet(url: String, args: JSONObject? = null): Promise {
            val p = Promise()
            var finalurl = url
            if (args != null) {
                finalurl = "$url?${_makeKeyValueString(args)}"
            }
            _asyncExecRequest(p, finalurl, body = null)
            return p
        }

        private fun _makeKeyValueString(args: JSONObject): String {
            val list = mutableListOf<String>()
            args.keys().forEach { key ->
                list.add("$key=${URLEncoder.encode(args.getString(key))}")
            }
            return list.joinToString("&")
        }

        private fun _asyncExecRequest(p: Promise, url: String, body: String?, headers: JSONObject? = null) {
            Thread(Runnable {
                var input: InputStream? = null
                var output: ByteArrayOutputStream? = null
                try {
                    //  open network connection
                    val conn = URL(url).openConnection() as HttpURLConnection
                    conn.connectTimeout = 10 * 1000
                    conn.useCaches = false
                    conn.doInput = true

                    //  append headers
                    headers?.let {
                        it.keys().forEach { key ->
                            conn.setRequestProperty(key, it.getString(key))
                        }
                    }

                    //  write data if post
                    if (body != null) {
                        //  POST
                        conn.requestMethod = "POST"
                        conn.doOutput = true
                        conn.outputStream.write(body.utf8String())
                    } else {
                        //  GET
                        conn.requestMethod = "GET"
                    }

                    //  wait response
                    val code = conn.responseCode
                    if (code == 200 || code == 201) {
                        //  read
                        input = conn.inputStream
                        output = ByteArrayOutputStream()
                        val buff = ByteArray(256)
                        while (true) {
                            val n = input.read(buff)
                            if (n < 0) {
                                break
                            }
                            if (n > 0) {
                                output.write(buff, 0, n)
                            }
                        }
                        val resp = output.toByteArray().utf8String()
                        //  return - ok
                        try {
                            p.resolve(JSONObject(resp))
                        } catch (e: JSONException) {
                            p.resolve(JSONArray(resp))
                        }
                    } else {
                        //  return - error
                        p.reject("error code: $code")
                    }
                } catch (e: Exception) {
                    //  TODO:统计错误
                    //  return - error
                    p.reject("Exception: ${e.message}")
                } finally {
                    input?.close()
                    output?.close()
                }
            }).start()
        }

        /**
         * 异步获取 InetAddress
         */
        fun asyncGetLocalHostAddress(): Promise {
            val p = Promise()
            Thread(Runnable {
                try {
                    p.resolve(InetAddress.getLocalHost())
                } catch (e: Exception) {
                    p.resolve(null)
                }
            }).start()
            return p
        }

        /**
         * 根据私钥种子字符串生成 WIF 格式私钥。
         */
        fun genBtsWifPrivateKey(seed: ByteArray): String {
            val prikey = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_seed(seed)
            return genBtsWifPrivateKeyByPrivateKey32(prikey!!)
        }

        /**
         * 根据32字节原始私钥生成 WIF 格式私钥
         */
        fun genBtsWifPrivateKeyByPrivateKey32(private_key32: ByteArray): String {
            return NativeInterface.sharedNativeInterface().bts_private_key_to_wif(private_key32)!!
        }

        /**
         * 根据私钥种子字符串生成 BTS 地址字符串。
         */
        fun genBtsAddressFromPrivateKeySeed(seed: String): String? {
            val prikey = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_seed(seed.utf8String())
            if (prikey == null) {
                return null
            }
            return NativeInterface.sharedNativeInterface().bts_gen_address_from_private_key32(prikey, ChainObjectManager.sharedChainObjectManager().grapheneAddressPrefix.utf8String())?.utf8String()
        }

        /**
         * 根据 WIF格式私钥 字符串生成 BTS 地址字符串。
         */
        fun genBtsAddressFromWifPrivateKey(private_key_wif: String): String? {
            val prikey = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_wif_privatekey(private_key_wif.utf8String())
            if (prikey == null) {
                return null
            }
            return NativeInterface.sharedNativeInterface().bts_gen_address_from_private_key32(prikey, ChainObjectManager.sharedChainObjectManager().grapheneAddressPrefix.utf8String())?.utf8String()
        }

        /**
         * (public) 根据【失去】和【得到】的资产信息计算订单方向行为（买卖、价格、数量等）
         */
        fun calcOrderDirectionInfos(priority_hash_args: JSONObject?, pay_asset_info: JSONObject, receive_asset_info: JSONObject): JSONObject {
            val chainMgr = ChainObjectManager.sharedChainObjectManager()

            val priority_hash = priority_hash_args ?: chainMgr.genAssetBasePriorityHash()

            val pay_asset = chainMgr.getChainObjectByID(pay_asset_info.getString("asset_id"))
            val receive_asset = chainMgr.getChainObjectByID(receive_asset_info.getString("asset_id"))

            //  计算base和quote资产：优先级高的资产作为 base
            val symbol_pay = pay_asset.getString("symbol")
            val symbol_receive = receive_asset.getString("symbol")

            val pay_asset_priority = priority_hash.optInt(symbol_pay, 0)
            val receive_asset_priority = priority_hash.optInt(symbol_receive, 0)

            var base_asset: JSONObject
            var quote_asset: JSONObject
            val base_amount: String
            val quote_amount: String
            var issell: Boolean
            if (pay_asset_priority > receive_asset_priority) {
                //  pay 作为 base 资产。支出 base，则为买入行为。
                issell = false
                base_asset = pay_asset
                quote_asset = receive_asset
                base_amount = pay_asset_info.getString("amount")
                quote_amount = receive_asset_info.getString("amount")
            } else {
                //  receive 作为 base 资产。获得 base，则为卖出行为。
                issell = true
                base_asset = receive_asset
                quote_asset = pay_asset
                base_amount = receive_asset_info.getString("amount")
                quote_amount = pay_asset_info.getString("amount")
            }

            // price = base / quote
            val base_precision = base_asset.getInt("precision")
            val quote_precision = quote_asset.getInt("precision")
            val base_precision_pow = 10.0f.pow(base_precision)
            val quote_precision_pow = 10.0f.pow(quote_precision)

            //  保留小数位数 买入行为：向上取整 卖出行为：向下取整
            val price = (base_amount.toDouble() / base_precision_pow) / (quote_amount.toDouble() / quote_precision_pow)
            val str_price = OrgUtils.formatFloatValue(price, base_precision)
            val str_base = OrgUtils.formatAssetString(base_amount, base_precision)
            val str_quote = OrgUtils.formatAssetString(quote_amount, quote_precision)

            //  返回
            val item = JSONObject()
            item.put("issell", issell)
            item.put("base", base_asset)
            item.put("quote", quote_asset)
            item.put("str_price", str_price)
            item.put("str_base", str_base)
            item.put("str_quote", str_quote)
            return item
        }

        /**
         *  获取 worker 类型。0:refund 1:vesting 2:burn
         */
        fun getWorkerType(worker_json_object: JSONObject): Int {
            val worker = worker_json_object.optJSONArray("worker")
            if (worker != null && worker.length() > 0) {
                return worker.getInt(0)
            }
            //  default is vesting worker
            return EBitsharesWorkType.ebwt_vesting.value
        }

        /**
         *  从操作的结果结构体中提取新对象ID。
         */
        fun extractNewObjectIDFromOperationResult(operation_result: JSONArray?): String? {
            if (operation_result != null && operation_result.length() == 2 && operation_result.getInt(0) == 1) {
                return operation_result.getString(1)
            }
            return null
        }

        /**
         *  从广播交易结果获取新生成的对象ID号（比如新的订单号、新HTLC号等）
         *  考虑到数据结构可能变更，加各种safe判断。
         *  REMARK：仅考虑一个 op 的情况，如果一个交易包含多个 op 则不支持。
         */
        fun extractNewObjectID(transaction_confirmation_list: JSONArray?): String? {
            val new_object_id = null
            if (transaction_confirmation_list != null && transaction_confirmation_list.length() > 0) {
                val trx = transaction_confirmation_list.getJSONObject(0).optJSONObject("trx")
                if (trx != null) {
                    val operation_results = trx.optJSONArray("operation_results")
                    if (operation_results != null) {
                        val operation_result = operation_results.optJSONArray(0)
                        return extractNewObjectIDFromOperationResult(operation_result)
                    }
                }
            }
            return new_object_id
        }

        /**
         *  提取OPDATA中所有的石墨烯ID信息。
         */
        fun extractObjectID(opcode: Int, opdata: JSONObject, container: JSONObject) {
            val fee = opdata.optJSONObject("fee")
            if (fee != null) {
                container.put(fee.getString("asset_id"), true)
            }
            //  TODO:fowallet 账号明细 、提案列表、提案确认等界面关于 OP 的描述。如果需要添加新的OP支持，需要修改。
            when (opcode) {
                EBitsharesOperations.ebo_transfer.value -> {
                    container.put(opdata.getString("from"), true)
                    container.put(opdata.getString("to"), true)
                    container.put(opdata.getJSONObject("amount").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_limit_order_create.value -> {
                    container.put(opdata.getString("seller"), true)
                    container.put(opdata.getJSONObject("amount_to_sell").getString("asset_id"), true)
                    container.put(opdata.getJSONObject("min_to_receive").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_limit_order_cancel.value -> {
                    container.put(opdata.getString("fee_paying_account"), true)
                }
                EBitsharesOperations.ebo_call_order_update.value -> {
                    container.put(opdata.getString("funding_account"), true)
                    container.put(opdata.getJSONObject("delta_collateral").getString("asset_id"), true)
                    container.put(opdata.getJSONObject("delta_debt").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_fill_order.value -> {
                    container.put(opdata.getString("account_id"), true)
                    container.put(opdata.getJSONObject("pays").getString("asset_id"), true)
                    container.put(opdata.getJSONObject("receives").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_account_create.value -> {
                    container.put(opdata.getString("registrar"), true)
                    container.put(opdata.getString("referrer"), true)
                }
                EBitsharesOperations.ebo_account_update.value -> {
                    container.put(opdata.getString("account"), true)
                    val owner = opdata.optJSONObject("owner")
                    if (owner != null) {
                        owner.getJSONArray("account_auths").forEach<JSONArray> { item ->
                            assert(item!!.length() == 2)
                            val account_id = item.getString(0)
                            container.put(account_id, true)
                        }
                    }
                    val active = opdata.optJSONObject("active")
                    if (active != null) {
                        active.getJSONArray("account_auths").forEach<JSONArray> { item ->
                            assert(item!!.length() == 2)
                            val account_id = item.getString(0)
                            container.put(account_id, true)
                        }
                    }
                }
                EBitsharesOperations.ebo_account_whitelist.value -> {
                    container.put(opdata.getString("authorizing_account"), true)
                    container.put(opdata.getString("account_to_list"), true)
                }
                EBitsharesOperations.ebo_account_upgrade.value -> {
                    container.put(opdata.getString("account_to_upgrade"), true)
                }
                EBitsharesOperations.ebo_account_transfer.value -> {
                    container.put(opdata.getString("account_id"), true)
                    container.put(opdata.getString("new_owner"), true)
                }
                EBitsharesOperations.ebo_asset_create.value -> {
                    container.put(opdata.getString("issuer"), true)
                }
                EBitsharesOperations.ebo_asset_update.value -> {
                    container.put(opdata.getString("issuer"), true)
                    container.put(opdata.getString("asset_to_update"), true)
                }
                EBitsharesOperations.ebo_asset_update_bitasset.value -> {
                    container.put(opdata.getString("issuer"), true)
                    container.put(opdata.getString("asset_to_update"), true)
                }
                EBitsharesOperations.ebo_asset_update_feed_producers.value -> {
                    container.put(opdata.getString("issuer"), true)
                    container.put(opdata.getString("asset_to_update"), true)
                }
                EBitsharesOperations.ebo_asset_issue.value -> {
                    container.put(opdata.getString("issuer"), true)
                    container.put(opdata.getString("issue_to_account"), true)
                    container.put(opdata.getJSONObject("asset_to_issue").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_asset_reserve.value -> {
                    container.put(opdata.getString("payer"), true)
                    container.put(opdata.getJSONObject("amount_to_reserve").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_asset_fund_fee_pool.value -> {
                    container.put(opdata.getString("from_account"), true)
                    container.put(opdata.getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_asset_settle.value -> {
                    container.put(opdata.getString("account"), true)
                    container.put(opdata.getJSONObject("amount").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_asset_global_settle.value -> {
                    container.put(opdata.getString("issuer"), true)
                    container.put(opdata.getString("asset_to_settle"), true)
                }
                EBitsharesOperations.ebo_asset_publish_feed.value -> {
                    container.put(opdata.getString("publisher"), true)
                    container.put(opdata.getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_witness_create.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_witness_update.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_proposal_create.value -> {
                    container.put(opdata.getString("fee_paying_account"), true)
                }
                EBitsharesOperations.ebo_proposal_update.value -> {
                    container.put(opdata.getString("fee_paying_account"), true)
                }
                EBitsharesOperations.ebo_proposal_delete.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_withdraw_permission_create.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_withdraw_permission_update.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_withdraw_permission_claim.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_withdraw_permission_delete.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_committee_member_create.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_committee_member_update.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_committee_member_update_global_parameters.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_vesting_balance_create.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_vesting_balance_withdraw.value -> {
                    container.put(opdata.getString("owner"), true)
                    container.put(opdata.getJSONObject("amount").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_worker_create.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_custom.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_assert.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_balance_claim.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_override_transfer.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_transfer_to_blind.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_blind_transfer.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_transfer_from_blind.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_asset_settle_cancel.value -> {
                    //  TODO:
                }
                EBitsharesOperations.ebo_asset_claim_fees.value -> {
                    container.put(opdata.getString("issuer"), true)
                    container.put(opdata.getJSONObject("amount_to_claim").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_asset_update_issuer.value -> {
                    container.put(opdata.getString("issuer"), true)
                    container.put(opdata.getString("asset_to_update"), true)
                    container.put(opdata.getString("new_issuer"), true)
                }
                EBitsharesOperations.ebo_htlc_create.value -> {
                    container.put(opdata.getString("from"), true)
                    container.put(opdata.getString("to"), true)
                    container.put(opdata.getJSONObject("amount").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_htlc_redeem.value -> {
                    container.put(opdata.getString("redeemer"), true)
                }
                EBitsharesOperations.ebo_htlc_redeemed.value -> {
                    container.put(opdata.getString("redeemer"), true)
                    container.put(opdata.getString("to"), true)
                    container.put(opdata.getJSONObject("amount").getString("asset_id"), true)
                }
                EBitsharesOperations.ebo_htlc_extend.value -> {
                    container.put(opdata.getString("update_issuer"), true)
                }
                EBitsharesOperations.ebo_htlc_refund.value -> {
                    container.put(opdata.getString("to"), true)
                }
                else -> {
                }
            }
        }

        /**
         *  转换OP数据为UI显示数据。
         */
        fun processOpdata2UiData(opcode: Int, opdata: JSONObject, opresult: JSONArray?, isproposal: Boolean, ctx: Context): JSONObject {
            val chainMgr = ChainObjectManager.sharedChainObjectManager()

            var name = R.string.kOpType_unknown_op.xmlstring(ctx)
            var desc = String.format(R.string.kOpDesc_unknown_op.xmlstring(ctx), opcode.toString())
            var color = R.color.theme01_textColorMain

            when (opcode) {
                EBitsharesOperations.ebo_transfer.value -> {
                    name = R.string.kOpType_transfer.xmlstring(ctx)
                    val from = chainMgr.getChainObjectByID(opdata.getString("from")).getString("name")
                    val to = chainMgr.getChainObjectByID(opdata.getString("to")).getString("name")
                    val str_amount = formatAssetAmountItem(opdata.getJSONObject("amount"))
                    desc = String.format(R.string.kOpDesc_transfer.xmlstring(ctx), from, str_amount, to)
                }
                EBitsharesOperations.ebo_limit_order_create.value -> {
                    val user = chainMgr.getChainObjectByID(opdata.getString("seller")).getString("name")
                    val info = OrgUtils.calcOrderDirectionInfos(null, opdata.getJSONObject("amount_to_sell"), opdata.getJSONObject("min_to_receive"))

                    val base_symbol = info.getJSONObject("base").getString("symbol")
                    val quote_symbol = info.getJSONObject("quote").getString("symbol")
                    val str_price = info.getString("str_price")
                    val str_quote = info.getString("str_quote")

                    if (info.getBoolean("issell")) {
                        name = R.string.kOpType_limit_order_create_sell.xmlstring(ctx)
                        color = R.color.theme01_sellColor
                        desc = String.format(R.string.kOpDesc_limit_order_create_sell.xmlstring(ctx), user, "${str_price}${base_symbol}/${quote_symbol}", "${str_quote}${quote_symbol}")
                    } else {
                        name = R.string.kOpType_limit_order_create_buy.xmlstring(ctx)
                        color = R.color.theme01_buyColor
                        desc = String.format(R.string.kOpDesc_limit_order_create_buy.xmlstring(ctx), user, "${str_price}${base_symbol}/${quote_symbol}", "${str_quote}${quote_symbol}")
                    }
                }
                EBitsharesOperations.ebo_limit_order_cancel.value -> {
                    name = R.string.kOpType_limit_order_cancel.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("fee_paying_account")).getString("name")
                    desc = String.format(R.string.kOpDesc_limit_order_cancel.xmlstring(ctx), user, opdata.getString("order"))
                }
                EBitsharesOperations.ebo_call_order_update.value -> {
                    name = R.string.kOpType_call_order_update.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("funding_account")).getString("name")
                    //  REMARK：这2个字段可能为负数。
                    val delta_collateral = opdata.getJSONObject("delta_collateral")
                    val delta_debt = opdata.getJSONObject("delta_debt")
                    val collateral_asset = chainMgr.getChainObjectByID(delta_collateral.getString("asset_id"))
                    val debt_asset = chainMgr.getChainObjectByID(delta_debt.getString("asset_id"))
                    val n_coll = OrgUtils.formatAssetString(delta_collateral.getString("amount"), collateral_asset.getInt("precision"))
                    val n_debt = OrgUtils.formatAssetString(delta_debt.getString("amount"), debt_asset.getInt("precision"))
                    val symbol_coll = collateral_asset.getString("symbol")
                    val symbol_debt = debt_asset.getString("symbol")
                    desc = String.format(R.string.kOpDesc_call_order_update.xmlstring(ctx), user, "${n_coll}${symbol_coll}", "${n_debt}${symbol_debt}")
                }
                EBitsharesOperations.ebo_fill_order.value -> {
                    name = R.string.kOpType_fill_order.xmlstring(ctx)

                    val user = chainMgr.getChainObjectByID(opdata.getString("account_id")).getString("name")
                    val isCallOrder = opdata.getString("order_id").split(".")[1].toInt() == EBitsharesObjectType.ebot_call_order.value
                    val info = OrgUtils.calcOrderDirectionInfos(null, opdata.getJSONObject("pays"), opdata.getJSONObject("receives"))

                    val base_symbol = info.getJSONObject("base").getString("symbol")
                    val quote_symbol = info.getJSONObject("quote").getString("symbol")
                    val str_price = info.getString("str_price")
                    val str_quote = info.getString("str_quote")

                    if (info.getBoolean("issell")) {
                        desc = String.format(R.string.kOpDesc_fill_order_sell.xmlstring(ctx), user, "${str_price}${base_symbol}/${quote_symbol}", "${str_quote}${quote_symbol}")
                    } else {
                        desc = String.format(R.string.kOpDesc_fill_order_buy.xmlstring(ctx), user, "${str_price}${base_symbol}/${quote_symbol}", "${str_quote}${quote_symbol}")
                    }
                    if (isCallOrder) {
                        color = R.color.theme01_callOrderColor
                    }
                }
                EBitsharesOperations.ebo_account_create.value -> {
                    name = R.string.kOpType_account_create.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("registrar")).getString("name")
                    desc = String.format(R.string.kOpDesc_account_create.xmlstring(ctx), user, opdata.getString("name"))
                }
                EBitsharesOperations.ebo_account_update.value -> {
                    name = R.string.kOpType_account_update.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("account")).getString("name")
                    desc = String.format(R.string.kOpDesc_account_update.xmlstring(ctx), user)
                }
                EBitsharesOperations.ebo_account_whitelist.value -> {
                    name = R.string.kOpType_account_whitelist.xmlstring(ctx)

                    val new_listing_flag = opdata.getInt("new_listing")
                    val in_white_list = new_listing_flag.and(EBitsharesWhiteListFlag.ebwlf_white_listed.value) != 0
                    val in_black_list = new_listing_flag.and(EBitsharesWhiteListFlag.ebwlf_black_listed.value) != 0

                    val authorizing_account = chainMgr.getChainObjectByID(opdata.getString("authorizing_account")).getString("name")
                    val account_to_list = chainMgr.getChainObjectByID(opdata.getString("account_to_list")).getString("name")

                    if (in_white_list && in_black_list) {
                        desc = String.format(R.string.kOpDesc_account_whitelist_both.xmlstring(ctx), authorizing_account, account_to_list)
                    } else if (in_white_list) {
                        desc = String.format(R.string.kOpDesc_account_whitelist_white.xmlstring(ctx), authorizing_account, account_to_list)
                    } else if (in_black_list) {
                        desc = String.format(R.string.kOpDesc_account_whitelist_black.xmlstring(ctx), authorizing_account, account_to_list)
                    } else {
                        desc = String.format(R.string.kOpDesc_account_whitelist_none.xmlstring(ctx), authorizing_account, account_to_list)
                    }
                }
                EBitsharesOperations.ebo_account_upgrade.value -> {
                    name = R.string.kOpType_account_upgrade.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("account_to_upgrade")).getString("name")
                    if (opdata.optBoolean("upgrade_to_lifetime_member", false)) {
                        desc = String.format(R.string.kOpDesc_account_upgrade_member.xmlstring(ctx), user)
                    } else {
                        desc = String.format(R.string.kOpDesc_account_upgrade.xmlstring(ctx), user)
                    }
                }
                EBitsharesOperations.ebo_account_transfer.value -> {
                    name = R.string.kOpType_account_transfer.xmlstring(ctx)
                    desc = R.string.kOpDesc_account_transfer.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_create.value -> {
                    name = R.string.kOpType_asset_create.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("issuer")).getString("name")
                    desc = String.format(R.string.kOpDesc_asset_create.xmlstring(ctx), user, opdata.getString("symbol"))
                }
                EBitsharesOperations.ebo_asset_update.value -> {
                    name = R.string.kOpType_asset_update.xmlstring(ctx)
                    val symbol = chainMgr.getChainObjectByID(opdata.getString("asset_to_update")).getString("symbol")
                    desc = String.format(R.string.kOpDesc_asset_update.xmlstring(ctx), symbol)
                }
                EBitsharesOperations.ebo_asset_update_bitasset.value -> {
                    name = R.string.kOpType_asset_update_bitasset.xmlstring(ctx)
                    desc = R.string.kOpDesc_asset_update_bitasset.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_update_feed_producers.value -> {
                    name = R.string.kOpType_asset_update_feed_producers.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("asset_to_update")).getString("name")
                    desc = String.format(R.string.kOpDesc_asset_update_feed_producers.xmlstring(ctx), user)
                }
                EBitsharesOperations.ebo_asset_issue.value -> {
                    name = R.string.kOpType_asset_issue.xmlstring(ctx)
                    desc = R.string.kOpDesc_asset_issue.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_reserve.value -> {
                    name = R.string.kOpType_asset_reserve.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("payer")).getString("name")
                    desc = String.format(R.string.kOpDesc_asset_reserve.xmlstring(ctx), user, formatAssetAmountItem(opdata.getJSONObject("amount_to_reserve")))
                }
                EBitsharesOperations.ebo_asset_fund_fee_pool.value -> {
                    name = R.string.kOpType_asset_fund_fee_pool.xmlstring(ctx)
                    desc = R.string.kOpDesc_asset_fund_fee_pool.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_settle.value -> {
                    name = R.string.kOpType_asset_settle.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("account")).getString("name")
                    desc = String.format(R.string.kOpDesc_asset_settle.xmlstring(ctx), user, formatAssetAmountItem(opdata.getJSONObject("amount")))
                }
                EBitsharesOperations.ebo_asset_global_settle.value -> {
                    name = R.string.kOpType_asset_global_settle.xmlstring(ctx)
                    desc = R.string.kOpDesc_asset_global_settle.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_publish_feed.value -> {
                    name = R.string.kOpType_asset_publish_feed.xmlstring(ctx)
                    desc = R.string.kOpDesc_asset_publish_feed.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_witness_create.value -> {
                    name = R.string.kOpType_witness_create.xmlstring(ctx)
                    desc = R.string.kOpDesc_witness_create.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_witness_update.value -> {
                    name = R.string.kOpType_witness_update.xmlstring(ctx)
                    desc = R.string.kOpDesc_witness_update.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_proposal_create.value -> {
                    name = R.string.kOpType_proposal_create.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("fee_paying_account")).getString("name")
                    val new_proposal_id = extractNewObjectIDFromOperationResult(opresult)
                    if (new_proposal_id != null) {
                        desc = String.format(R.string.kOpDesc_proposal_create_with_id.xmlstring(ctx), user, new_proposal_id)
                    } else {
                        desc = String.format(R.string.kOpDesc_proposal_create.xmlstring(ctx), user)
                    }
                }
                EBitsharesOperations.ebo_proposal_update.value -> {
                    name = R.string.kOpType_proposal_update.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("fee_paying_account")).getString("name")
                    desc = String.format(R.string.kOpDesc_proposal_update.xmlstring(ctx), user, opdata.getString("proposal"))
                }
                EBitsharesOperations.ebo_proposal_delete.value -> {
                    name = R.string.kOpType_proposal_delete.xmlstring(ctx)
                    desc = R.string.kOpDesc_proposal_delete.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_withdraw_permission_create.value -> {
                    name = R.string.kOpType_withdraw_permission_create.xmlstring(ctx)
                    desc = R.string.kOpDesc_withdraw_permission_create.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_withdraw_permission_update.value -> {
                    name = R.string.kOpType_withdraw_permission_update.xmlstring(ctx)
                    desc = R.string.kOpDesc_withdraw_permission_update.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_withdraw_permission_claim.value -> {
                    name = R.string.kOpType_withdraw_permission_claim.xmlstring(ctx)
                    desc = R.string.kOpDesc_withdraw_permission_claim.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_withdraw_permission_delete.value -> {
                    name = R.string.kOpType_withdraw_permission_delete.xmlstring(ctx)
                    desc = R.string.kOpDesc_withdraw_permission_delete.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_committee_member_create.value -> {
                    name = R.string.kOpType_committee_member_create.xmlstring(ctx)
                    desc = R.string.kOpDesc_committee_member_create.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_committee_member_update.value -> {
                    name = R.string.kOpType_committee_member_update.xmlstring(ctx)
                    desc = R.string.kOpDesc_committee_member_update.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_committee_member_update_global_parameters.value -> {
                    name = R.string.kOpType_committee_member_update_global_parameters.xmlstring(ctx)
                    desc = R.string.kOpDesc_committee_member_update_global_parameters.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_vesting_balance_create.value -> {
                    name = R.string.kOpType_vesting_balance_create.xmlstring(ctx)
                    desc = R.string.kOpDesc_vesting_balance_create.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_vesting_balance_withdraw.value -> {
                    name = R.string.kOpType_vesting_balance_withdraw.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("owner")).getString("name")
                    desc = String.format(R.string.kOpDesc_vesting_balance_withdraw.xmlstring(ctx), user, formatAssetAmountItem(opdata.getJSONObject("amount")))
                }
                EBitsharesOperations.ebo_worker_create.value -> {
                    name = R.string.kOpType_worker_create.xmlstring(ctx)
                    desc = R.string.kOpDesc_worker_create.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_custom.value -> {
                    name = R.string.kOpType_custom.xmlstring(ctx)
                    desc = R.string.kOpDesc_custom.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_assert.value -> {
                    name = R.string.kOpType_assert.xmlstring(ctx)
                    desc = R.string.kOpDesc_assert.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_balance_claim.value -> {
                    name = R.string.kOpType_balance_claim.xmlstring(ctx)
                    desc = R.string.kOpDesc_balance_claim.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_override_transfer.value -> {
                    name = R.string.kOpType_override_transfer.xmlstring(ctx)
                    desc = R.string.kOpDesc_override_transfer.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_transfer_to_blind.value -> {
                    name = R.string.kOpType_transfer_to_blind.xmlstring(ctx)
                    desc = R.string.kOpDesc_transfer_to_blind.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_blind_transfer.value -> {
                    name = R.string.kOpType_blind_transfer.xmlstring(ctx)
                    desc = R.string.kOpDesc_blind_transfer.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_transfer_from_blind.value -> {
                    name = R.string.kOpType_transfer_from_blind.xmlstring(ctx)
                    desc = R.string.kOpDesc_transfer_from_blind.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_settle_cancel.value -> {
                    name = R.string.kOpType_asset_settle_cancel.xmlstring(ctx)
                    desc = R.string.kOpDesc_asset_settle_cancel.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_claim_fees.value -> {
                    name = R.string.kOpType_asset_claim_fees.xmlstring(ctx)
                    val user = chainMgr.getChainObjectByID(opdata.getString("issuer")).getString("name")
                    desc = String.format(R.string.kOpDesc_asset_claim_fees.xmlstring(ctx), user, formatAssetAmountItem(opdata.getJSONObject("amount_to_claim")))
                }
                EBitsharesOperations.ebo_fba_distribute.value -> {
                    name = R.string.kOpType_fba_distribute.xmlstring(ctx)
                    desc = R.string.kOpDesc_fba_distribute.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_bid_collateral.value -> {
                    name = R.string.kOpType_bid_collateral.xmlstring(ctx)
                    desc = R.string.kOpDesc_bid_collateral.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_execute_bid.value -> {
                    name = R.string.kOpType_execute_bid.xmlstring(ctx)
                    desc = R.string.kOpDesc_execute_bid.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_claim_pool.value -> {
                    name = R.string.kOpType_asset_claim_pool.xmlstring(ctx)
                    desc = R.string.kOpDesc_asset_claim_pool.xmlstring(ctx)
                    //  TODO:待细化
                }
                EBitsharesOperations.ebo_asset_update_issuer.value -> {
                    name = R.string.kOpType_asset_update_issuer.xmlstring(ctx)
                    val issuer = chainMgr.getChainObjectByID(opdata.getString("issuer")).getString("name")
                    val asset_to_update = chainMgr.getChainObjectByID(opdata.getString("asset_to_update")).getString("symbol")
                    val new_issuer = chainMgr.getChainObjectByID(opdata.getString("new_issuer")).getString("name")
                    desc = String.format(R.string.kOpDesc_asset_update_issuer.xmlstring(ctx), issuer, asset_to_update, new_issuer)
                }
                EBitsharesOperations.ebo_htlc_create.value -> {
                    name = R.string.kOpType_htlc_create.xmlstring(ctx)
                    val from = chainMgr.getChainObjectByID(opdata.getString("from")).getString("name")
                    val to = chainMgr.getChainObjectByID(opdata.getString("to")).getString("name")
                    val str_amount = formatAssetAmountItem(opdata.getJSONObject("amount"))
                    val new_htlc_id = extractNewObjectIDFromOperationResult(opresult)
                    if (new_htlc_id != null) {
                        desc = String.format(R.string.kOpDesc_htlc_create_with_id.xmlstring(ctx), from, str_amount, to, new_htlc_id)
                    } else {
                        desc = String.format(R.string.kOpDesc_htlc_create.xmlstring(ctx), from, str_amount, to)
                    }
                }
                EBitsharesOperations.ebo_htlc_redeem.value -> {
                    name = R.string.kOpType_htlc_redeem.xmlstring(ctx)
                    val hex_preimage = opdata.getString("preimage")
                    assert(Utils.isValidHexString(hex_preimage))
                    val raw_preimage = hex_preimage.hexDecode()
                    val redeemer = chainMgr.getChainObjectByID(opdata.getString("redeemer")).getString("name")
                    desc = String.format(R.string.kOpDesc_htlc_redeem.xmlstring(ctx), redeemer, raw_preimage.utf8String(), opdata.getString("htlc_id"))
                }
                EBitsharesOperations.ebo_htlc_redeemed.value -> {
                    name = R.string.kOpType_htlc_redeemed.xmlstring(ctx)
                    val redeemer = chainMgr.getChainObjectByID(opdata.getString("redeemer")).getString("name")
                    val to = chainMgr.getChainObjectByID(opdata.getString("to")).getString("name")
                    val str_amount = formatAssetAmountItem(opdata.getJSONObject("amount"))
                    desc = String.format(R.string.kOpDesc_htlc_redeemed.xmlstring(ctx), redeemer, str_amount, to, opdata.getString("htlc_id"))
                }
                EBitsharesOperations.ebo_htlc_extend.value -> {
                    name = R.string.kOpType_htlc_extend.xmlstring(ctx)
                    val update_issuer = chainMgr.getChainObjectByID(opdata.getString("update_issuer")).getString("name")
                    desc = String.format(R.string.kOpDesc_htlc_extend.xmlstring(ctx), update_issuer, opdata.getString("seconds_to_add"), opdata.getString("htlc_id"))
                }
                EBitsharesOperations.ebo_htlc_refund.value -> {
                    name = R.string.kOpType_htlc_refund.xmlstring(ctx)
                    val to = chainMgr.getChainObjectByID(opdata.getString("to")).getString("name")
                    desc = String.format(R.string.kOpDesc_htlc_refund.xmlstring(ctx), to, opdata.getString("htlc_id"))
                }
                else -> {
                }
            }
            if (isproposal) {
                name = String.format(R.string.kOpType_proposal_prefix.xmlstring(ctx), name)
            }
            return jsonObjectfromKVS("name", name, "desc", desc, "color", color)
        }
    }

}