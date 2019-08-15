package bitshares

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Context.CLIPBOARD_SERVICE
import android.content.pm.PackageManager
import android.content.res.Resources
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.telephony.TelephonyManager
import android.util.TypedValue
import android.widget.ImageView
import com.btsplusplus.fowallet.R
import com.qingmei2.library.encode.QRCodeEncoder
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.math.BigDecimal
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

class Utils {

    companion object {

        var screen_width: Float = 0f
        var screen_height: Float = 0f

        private fun readJson(ctx: Context, fileName: String): String {
            val reader = InputStreamReader(ctx.resources.assets.open(fileName), "UTF-8")
            var buffer_reader = BufferedReader(reader)
            val string_builder = StringBuilder()
            var line = buffer_reader.readLine()
            while (line != null) {
                string_builder.append(line)
                line = buffer_reader.readLine()
            }
            buffer_reader.close()
            reader.close()
            return string_builder.toString()
        }

        fun readJsonToArray(ctx: Context, fileName: String): JSONArray {
            return JSONArray(readJson(ctx, fileName))
        }

        fun readJsonToMap(ctx: Context, fileName: String): JSONObject {
            return JSONObject(readJson(ctx, fileName))
        }

        fun randInt(n: Int): Int {
            return (Math.random() * n).toInt()
        }

        /**
         * (public) 帐号格式有效性判断　TODO:fowallet 格式细节
         */
        fun isValidBitsharesAccountName(account_name: String): Boolean {
            if (account_name.isEmpty()) {
                return false
            }
            if (account_name.length > 32) {
                return false
            }

            val parts_ary = account_name.split('.')
            if (parts_ary.size >= 2) {
                for (part in parts_ary) {
                    //  每个分段必须3位以上
                    if (part.length < 3) {
                        return false
                    }
                    val format = "\\A[a-z]+.*"
                    if (!isRegularMatch(part, format)) {
                        return false
                    }
                }
            }

            val format = "\\A[a-z]+(?:[a-z0-9\\-\\.])*[a-z0-9]\\z"
            if (isRegularMatch(account_name, format)) {
                return true
            }
            return false
        }

        /**
         * (public) 帐号模式：帐号密码格式是否正确　TODO:fowallet 格式细节
         * 格式：12位以上，包含大小写和数字。
         */
        fun isValidBitsharesAccountPassword(password: String): Boolean {
            if (password.length < 12) {
                return false
            }

            //  大写、小写、数字检测
            val format1 = ".*[A-Z]+.*"
            val format2 = ".*[a-z]+.*"
            val format3 = ".*[0-9]+.*"

            for (format in arrayOf(format1, format2, format3)) {
                if (!isRegularMatch(password, format)) {
                    return false
                }
            }
            return true
        }

        /**
         *  (public) 钱包模式：钱包密码格式是否正确 TODO:fowallet 格式细节
         *  格式：8位以上，包含大小写和数字。
         */
        fun isValidBitsharesWalletPassword(password: String): Boolean {
            if (password.length < 8) {
                return false
            }

            //  大写、小写、数字检测
            val format1 = ".*[A-Z]+.*"
            val format2 = ".*[a-z]+.*"
            val format3 = ".*[0-9]+.*"

            for (format in arrayOf(format1, format2, format3)) {
                if (!isRegularMatch(password, format)) {
                    return false
                }
            }
            return true
        }

        /**
         *  (public) 原像格式是否正确　TODO:fowallet 格式细节
         *  格式：20位以上，包含大写字母和数字。
         */
        fun isValidHTCLPreimageFormat(preimage: String?): Boolean {
            if (preimage == null) {
                return false
            }
            if (preimage.length < 20) { //TODO:fowallet cfg
                return false
            }

            //  大写、数字检测
            val format1 = ".*[A-Z]+.*"
            val format3 = ".*[0-9]+.*"

            for (format in arrayOf(format1, format3)) {
                if (!isRegularMatch(preimage, format)) {
                    return false
                }
            }
            return true
        }

        /**
         *  是否是有效的16进制字符串检测。
         */
        fun isValidHexString(hexstring: String?): Boolean {
            if (hexstring == null) {
                return false
            }
            if (hexstring.length % 2 != 0) {
                return false
            }
            //  A-F、a-f、0-9 组成
            val pre = "^[A-Fa-f0-9]+$"
            if (!isRegularMatch(hexstring, pre)) {
                return false
            }
            return true
        }

        /**
         * text是否匹配正则
         */
        private fun isRegularMatch(text: String, format: String): Boolean {
            val pattern = java.util.regex.Pattern.compile(format)
            val m = pattern.matcher(text)
            return m.matches()
        }

        /**
         * 格式校验：是否有效的数字（小数or整数）
         */
        fun isValidDigit(text: String): Boolean {
            val format = "^[\\.0-9]+$"
            return isRegularMatch(text, format)
        }

        /**
         * 辅助 - 根据字符串获取 BigDecimal 对象，如果字符串以小数点结尾，则默认添加0。
         */
        fun auxGetStringDecimalNumberValue(str: String): BigDecimal {
            if (str.isEmpty()) {
                return BigDecimal.ZERO
            } else {
                //  以小数点结尾则在默认添加0。
                val regular_str = str.fixComma()
                if (regular_str.isNotEmpty() && regular_str.indexOf('.') == str.length - 1) {
                    return BigDecimal("${regular_str}0")
                } else {
                    return BigDecimal(regular_str)
                }
            }
        }

        /**
         *  对于价格 or 数量类型的输入，判断是否是有效输入等。
         *  规则：
         *  1、不能有多个小数点
         *  2、不能以小数点开头
         *  3、不能包含字母等非数字输入
         *  4、小数位数不能超过 precision
         */
        fun isValidAmountOrPriceInput(str: String, precision: Int): Boolean {
            //  空字符串不处理
            if (str.isEmpty()) {
                return true
            }

            val regular_str = str.fixComma()

//            //  非数字
//            if (!isValidDigit(regular_str)){
//                return false
//            }

            //  第一个字母不能是小数点
            val dianPos = regular_str.indexOf('.')
            if (dianPos == 0) {
                return false
            }

            //  是否有小数点
            val isHaveDian: Boolean = dianPos >= 0
            if (isHaveDian) {
                //  存在多个小数点，无效输入。
                if (regular_str.indexOf('.', dianPos + 1) >= 0) {
                    return false
                }
                //  小数位数过多
                val fraction_digits = regular_str.length - (dianPos + 1)
                if (fraction_digits > precision) {
                    return false
                }
            }

            //  有效输入
            return true
        }

        /**
         * 格式化时间戳为 BTS 网络时间字符串格式。格式：2018-06-04T13:03:57。
         */
        fun formatBitsharesTimeString(ts: Long): String {
            val d = Date(ts * 1000)
            val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss")
            f.timeZone = java.util.TimeZone.getTimeZone("UTC")
            val s = f.format(d)
            return s
        }

        /**
         *  是否是BTS终身会员判断
         */
        fun isBitsharesVIP(membership_expiration_date_string: String?): Boolean {
            return if (membership_expiration_date_string != null && membership_expiration_date_string != "") {
                //  会员过期日期为 -1 则为终身会员。
                parseBitsharesTimeString(membership_expiration_date_string) < 0
            } else {
                false
            }
        }

        /**
         *  (private) 计算已经解冻的余额数量。（可提取的）REMARK：按照币龄解冻策略
         */
        private fun _calcVestingBalanceAmount_cdd_vesting_policy(policy: JSONArray, vesting: JSONObject): Long {
            //  TODO:fowallet 其他的类型不支持。
            assert(policy.getInt(0) == EBitsharesVestingPolicy.ebvp_cdd_vesting_policy.value)
            val policy_data = policy.getJSONObject(1)

            //  vesting seconds     REMARK：解冻周期最低1秒。
            val vesting_seconds = max(policy_data.getLong("vesting_seconds"), 1L)

            //  last update timestamp
            val coin_seconds_earned_last_update_ts = parseBitsharesTimeString(policy_data.getString("coin_seconds_earned_last_update"))
            val now_ts = now_ts()

            //  my balance & already earned seconds
            val total_balance_amount = vesting.getJSONObject("balance").getString("amount").toLong()
            val coin_seconds_earned = policy_data.getString("coin_seconds_earned").toLong()

            //  recalc real 'coin_seconds_earned' value
            var final_earned = coin_seconds_earned
            if (now_ts > coin_seconds_earned_last_update_ts) {
                val delta_seconds = now_ts - coin_seconds_earned_last_update_ts
                val delta_coin_seconds = total_balance_amount * delta_seconds
                val coin_seconds_earned_max = total_balance_amount * vesting_seconds
                final_earned = min(coin_seconds_earned + delta_coin_seconds, coin_seconds_earned_max)
            }

            val withdraw_max = floor(final_earned.toDouble() / vesting_seconds.toDouble()).toLong()
            assert(withdraw_max <= total_balance_amount)

            return withdraw_max
        }

        /**
         *  (private) 计算已经解冻的余额数量。（可提取的）REMARK：立即解冻策略
         */
        private fun _calcVestingBalanceAmount_instant_vesting_policy(policy: JSONArray, vesting: JSONObject): Long {
            //{
            //    balance =     {
            //        amount = 109944860;
            //        "asset_id" = "1.3.4072";
            //    };
            //    "balance_type" = "market_fee_sharing";
            //    id = "1.13.24212";
            //    owner = "1.2.114363";
            //    policy =     (
            //                  2,
            //                  {
            //                  }
            //                  );
            //}
            return vesting.getJSONObject("balance").getString("amount").toLong()
        }

        /**
         *  (public) 计算已经解冻的余额数量。（可提取的）
         */
        fun calcVestingBalanceAmount(vesting: JSONObject): Long {
            val policy = vesting.getJSONArray("policy")
            return when (policy.getInt(0)) {
                EBitsharesVestingPolicy.ebvp_cdd_vesting_policy.value -> _calcVestingBalanceAmount_cdd_vesting_policy(policy, vesting)
                EBitsharesVestingPolicy.ebvp_instant_vesting_policy.value -> _calcVestingBalanceAmount_instant_vesting_policy(policy, vesting)
                else -> {
                    //  TODO:ebvp_linear_vesting_policy
                    assert(false)
                    0
                }
            }
        }

        /**
         * 解析 BTS 网络时间字符串，返回 1970 到现在的秒数。格式：2018-06-04T13:03:57。
         */
        fun parseBitsharesTimeString(time: String): Long {
            val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss")
            f.timeZone = java.util.TimeZone.getTimeZone("UTC")
            val d = f.parse(time)
            return (d.time / 1000.0).toLong()
        }

        /**
         * 格式化：帐号历史日期显示格式。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
         */
        fun fmtAccountHistoryTimeShowString(time: String): String {
            if (time == "") {
                return "00-00 00:00"
            }
            val ts = parseBitsharesTimeString(time)
            val d = Date(ts * 1000)
            val f = SimpleDateFormat("MM-dd HH:mm")
            val s = f.format(d)
            return s
        }

        /**
         *  格式化：交易历史时间显示格式  24小时内，直接显示时分秒，24小时以外了则显示 x天前。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
         */
        fun fmtTradeHistoryTimeShowString(ctx: Context, time: String): String {
            val ts = parseBitsharesTimeString(time)
            val now_ts = now_ts()
            val diff_ts = now_ts - ts
            if (diff_ts < 86400) {
                val d = Date(ts * 1000)
                val f = SimpleDateFormat("HH:mm:ss")
                return f.format(d)
            } else {
                return String.format(R.string.kLabelTradeHisNdayAgo.xmlstring(ctx), (diff_ts / 86400).toInt())
            }
        }

        /**
         * 格式化：限价单过期日期显示格式。REMARK：以当前时区格式化，BTS默认时间是UTC。北京时间当前时区会+8。
         */
        fun fmtLimitOrderTimeShowString(time: String): String {
            val ts = parseBitsharesTimeString(time)
            val d = Date(ts * 1000)
            val f = SimpleDateFormat("yyyy/MM/dd")
            val s = f.format(d)
            return s
        }

        /**
         *  格式化：喂价发布日期。
         */
        fun fmtFeedPublishDateString(ctx: Context, time: String): String {
            val ts = parseBitsharesTimeString(time)
            //  REMARK：本地时间不准确的情况下该差值可能为负数，故取 MAX。
            val diff_ts = max(now_ts() - ts, 0L)
            if (diff_ts < 60) {
                return String.format(R.string.kVcFeedNsecAgo.xmlstring(ctx), diff_ts)
            } else if (diff_ts < 3600) {
                return String.format(R.string.kVcFeedNminAgo.xmlstring(ctx), (diff_ts / 60).toInt())
            } else if (diff_ts < 86400) {
                return String.format(R.string.kVcFeedNhourAgo.xmlstring(ctx), (diff_ts / 3600).toInt())
            } else {
                return String.format(R.string.kVcFeedNDayAgo.xmlstring(ctx), (diff_ts / 86400).toInt())
            }
        }

        /**
         *  格式化：解冻周期。
         */
        fun fmtVestingPeriodDateString(ctx: Context, seconds: Long): String {
            if (seconds < 60) {
                return String.format(R.string.kVestingCellPeriodSec.xmlstring(ctx), seconds.toString())
            } else if (seconds < 3600) {
                val min = (seconds / 60).toInt()
                return String.format(R.string.kVestingCellPeriodMin.xmlstring(ctx), min.toString())
            } else if (seconds < 86400) {
                val hour = (seconds / 3600).toInt()
                return String.format(R.string.kVestingCellPeriodHour.xmlstring(ctx), hour.toString())
            } else {
                val day = (seconds / 86400).toInt()
                return String.format(R.string.kVestingCellPeriodDay.xmlstring(ctx), day.toString())
            }
        }

        /**
         * 当前时间戳。   单位：秒。
         */
        fun now_ts(): Long {
            return (Date().time / 1000.0).toLong()
        }

        /**
         *  把DP单位转PX单位
         */
        fun toDp(v: Float, res: Resources): Int {
            return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, res.displayMetrics).toInt()
        }

        /**
         * 获取APP版本号
         */
        fun appVersionName(ctx: Context): String {
            try {
                val package_info = ctx.packageManager.getPackageInfo(ctx.packageName, 0)
                return package_info.versionName
            } catch (e: PackageManager.NameNotFoundException) {
                //  TODO:代码里内置版本号，每次都要修改，虽然仅仅在获取异常的时候才会用到，考虑放到config。？
                return "2.6"
            }
        }

        /**
         * 比较版本
         * pVer1大于pVer2返回1，小于返回－1，否则返回0。
         */
        fun compareVersion(ver1: String, ver2: String): Int {
            val ver1ary = ver1.split('.')
            val ver2ary = ver2.split('.')
            val n1 = ver1ary.size
            val n2 = ver2ary.size
            val n = min(n1, n2)

            //  v1 大于 v2 返回正，v1 小于 v2 返回负。
            for (i in 0 until n) {
                val v1 = ver1ary[i].toInt()
                val v2 = ver2ary[i].toInt()
                if (v1 > v2) {
                    return 1
                }
                if (v1 < v2) {
                    return -1
                }
            }
            return 0
        }

        /**
         *  获取手机网络类型（2G/3G/4G）
         *  4G为LTE，联通的3G为UMTS或HSDPA，电信的3G为EVDO，移动和联通的2G为GPRS或EGDE，电信的2G为CDMA。
         */
        private fun getNetWorkClass(context: Context): Int {
            val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            return when (telephonyManager.networkType) {
                TelephonyManager.NETWORK_TYPE_GPRS -> kNETWORK_CLASS_2_G
                TelephonyManager.NETWORK_TYPE_EDGE -> kNETWORK_CLASS_2_G
                TelephonyManager.NETWORK_TYPE_CDMA -> kNETWORK_CLASS_2_G
                TelephonyManager.NETWORK_TYPE_1xRTT -> kNETWORK_CLASS_2_G
                TelephonyManager.NETWORK_TYPE_IDEN -> kNETWORK_CLASS_2_G

                TelephonyManager.NETWORK_TYPE_UMTS -> kNETWORK_CLASS_3_G
                TelephonyManager.NETWORK_TYPE_EVDO_0 -> kNETWORK_CLASS_3_G
                TelephonyManager.NETWORK_TYPE_EVDO_A -> kNETWORK_CLASS_3_G
                TelephonyManager.NETWORK_TYPE_HSDPA -> kNETWORK_CLASS_3_G
                TelephonyManager.NETWORK_TYPE_HSUPA -> kNETWORK_CLASS_3_G
                TelephonyManager.NETWORK_TYPE_HSPA -> kNETWORK_CLASS_3_G
                TelephonyManager.NETWORK_TYPE_EVDO_B -> kNETWORK_CLASS_3_G
                TelephonyManager.NETWORK_TYPE_EHRPD -> kNETWORK_CLASS_3_G
                TelephonyManager.NETWORK_TYPE_HSPAP -> kNETWORK_CLASS_3_G

                TelephonyManager.NETWORK_TYPE_LTE -> kNETWORK_CLASS_4_G
                else -> kNETWORK_CLASS_UNKNOWN
            }
        }

        /**
         *  获取手机连接的网络类型（是WIFI还是手机网络[2G/3G/4G]）
         */
        private fun getNetWorkStatus(context: Context): Int {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val networkInfo = connectivityManager.activeNetworkInfo
            if (networkInfo != null && networkInfo.isConnected) {
                val type = networkInfo.type
                if (type == ConnectivityManager.TYPE_WIFI) {
                    return kNETWORK_WIFI
                } else if (type == ConnectivityManager.TYPE_MOBILE) {
                    return getNetWorkClass(context)
                }
            }
            return kNETWORK_CLASS_UNKNOWN
        }

        /**
         * 当前连接是否为WIFI模式
         */
        fun isWifi(ctx: Context): Boolean {
            return getNetWorkStatus(ctx) == kNETWORK_WIFI
        }

        /**
         * 获取本机IPv4地址
         */
        fun getIpv4Address(ctx: Context): String? {
            val wifiManager = ctx.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            if (wifiManager == null) {
                return null
            }
            //  判断WiFi是否开启
            if (!wifiManager.isWifiEnabled) {
                return null
            }
            val wifiInfo = wifiManager.connectionInfo
            val ipAddress = wifiInfo.ipAddress
            return intToIp(ipAddress)
        }

        /**
         * 解析URI 返回 -> 协议，base, method，参数
         */
        fun parseUri(uri: String): HashMap<String, Any> {
            val return_params = hashMapOf<String, Any>()
            val params = JSONObject()
            val arr = uri.split("?")
            val arr1 = arr[0].split("://")
            val protocol = arr1[0]
            val arr2 = arr1[1].split("/")
            val base_name = arr2[0]
            val method_name = arr2[1]
            if (arr.size > 1 && arr[1].isNotEmpty()) {
                val query_str = arr[1]
                val pair_arr = query_str.split("&")
                pair_arr.forEach {
                    val strarr = it.split("=")
                    params.put(strarr[0], strarr[1])
                }
            }
            return_params["protocol"] = protocol
            return_params["base_name"] = base_name
            return_params["method_name"] = method_name
            return_params["params"] = params

            return return_params
        }

        /**
         * 创建二维码到 ImageView
         */
        fun createQRCodeImage(ctx: Context, text: String, out_image_view: ImageView) {
            //构造方法：
            val qrcode = QRCodeEncoder(ctx as Activity)

            qrcode.createQrCode2ImageView(text, out_image_view)

            //生成带Icon的二维码
            // qrCodeEncoder.createQrCode2ImageView(textContent, ivQRCode, R.mipmap.ic_launcher)
        }

        fun asyncCreateQRBitmap(ctx: Context, text: String, width: Int): Promise {
            val p = Promise()
            Thread(Runnable {
                p.resolve(QRCodeEncoder(ctx as Activity).createQrCode(text, width))
            }).start()
            return p
        }

        private fun intToIp(ipAddress: Int): String {
            return "${ipAddress.and(0XFF)}.${ipAddress.shr(8).and(0XFF)}.${ipAddress.shr(16).and(0XFF)}.${ipAddress.shr(24).and(0XFF)}"
        }

        /**
         * 复制到剪贴板
         */
        fun copyToClipboard(ctx: Context, str: String): Boolean {
            val mgr = ctx.getSystemService(CLIPBOARD_SERVICE) as? ClipboardManager
            if (mgr != null) {
                mgr.primaryClip = ClipData.newPlainText("text", str)
                return true
            }
            return false
        }

        /**
         * 读取剪贴板内容
         */
        fun readFromClipboard(ctx: Context): String {
            val mgr = ctx.getSystemService(CLIPBOARD_SERVICE) as? ClipboardManager
            if (mgr != null && mgr.hasPrimaryClip()) {
                val data = mgr.primaryClip
                if (data != null) {
                    val item = data.getItemAt(0)
                    return item.coerceToText(ctx).toString()
                }
            }
            return ""
        }
    }
}
