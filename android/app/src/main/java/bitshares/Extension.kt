package bitshares

import android.content.Context
import android.content.res.Resources
import android.os.Looper
import android.util.TypedValue
import android.widget.EditText
import android.widget.LinearLayout
import com.btsplusplus.fowallet.NativeInterface
import com.crashlytics.android.answers.Answers
import com.crashlytics.android.answers.CustomEvent
import com.flurry.android.FlurryAgent
import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import kotlin.math.pow

/**
 * 扩展JSONArray，提供 for in 支持。
 */
inline operator fun JSONArray.iterator(): Iterator<JSONObject?> {
    return (0 until length()).asSequence().map { get(it) as? JSONObject }.iterator()
}

inline fun <reified T> JSONArray.forin(): Iterator<T?> {
    return (0 until length()).asSequence().map { get(it) as? T }.iterator()
}

/**
 * 扩展JSONArray，提供 forEach 遍历方法。
 */
inline fun <reified T> JSONArray.forEach(action: (T?) -> Unit) {
    (0 until length()).forEach { action(get(it) as? T) }
}

/**
 * 16进制编码、解码
 */
fun ByteArray.hexEncode() = this.map { String.format("%02x", (it.toInt() and 0xFF)) }.joinToString(separator = "")

fun String.hexDecode() = ByteArray(this.length / 2) { this.substring(it * 2, it * 2 + 2).toInt(16).toByte() }

/**
 * 获取UTF8的char*
 */
fun String.utf8String() = this.toByteArray(Charsets.UTF_8)

/**
 * 获取UTF8的String
 */
fun ByteArray.utf8String() = String(this, Charsets.UTF_8)

/**
 * 快速构造JSONArray
 */
fun jsonArrayfrom(vararg args: Any): JSONArray {
    val ary = JSONArray()
    for (obj in args) {
        ary.put(obj)
    }
    return ary
}

/**
 * 快速构造JSONObject
 */
fun jsonObjectfromKVS(vararg args: Any): JSONObject {
    val retv = JSONObject()
    assert(args.size % 2 == 0)
    for (i in 0 until args.size step 2) {
        val key = args[i] as String
        val value = args[i + 1]
        retv.put(key, value)
    }
    return retv
}

/**
 * 返回所有值
 */
fun JSONObject.values(): JSONArray {
    val ary = JSONArray()
    for (k in keys()) {
        ary.put(this.get(k))
    }
    return ary
}

/**
 * 千万别用 getBoolean 这个API！！！！！！
 */
fun JSONObject.isTrue(key: String): Boolean {
    if (!has(key)) {
        return false
    }
    val s = getString(key)
    if (s.equals("true", true)) {
        return true
    }
    if (s.equals("false", true)) {
        return false
    }
    return s.toLong() != 0L
}

/**
 * 直接put一个数组
 */
fun JSONArray.putAll(ary: JSONArray) {
    for (i in 0 until ary.length()) {
        this.put(ary.get(i))
    }
}

/**
 * 获取首元素
 */
inline fun <reified T> JSONArray.first(): T? {
    val size = length()
    if (size <= 0) {
        return null
    } else {
        return get(0) as T
    }
}

/**
 * 获取尾元素
 */
inline fun <reified T> JSONArray.last(): T? {
    val size = length()
    if (size <= 0) {
        return null
    } else {
        return get(size - 1) as T
    }
}

inline fun <reified T> JSONArray.toList(): List<T> {
    val retv = mutableListOf<T>()
    for (i in 0 until length()) {
        retv.add(get(i) as T)
    }
    return retv
}

inline fun <reified T> List<T>.toJsonArray(): JSONArray {
    val retv = JSONArray()
    for (v in this) {
        retv.put(v)
    }
    return retv
}

/**
 * 计算摘要信息
 */
fun rmd160(buffer: ByteArray): ByteArray {
    return NativeInterface.sharedNativeInterface().rmd160(buffer)
}

fun sha1(buffer: ByteArray): ByteArray {
    return NativeInterface.sharedNativeInterface().sha1(buffer)
}

fun sha256(buffer: ByteArray): ByteArray {
    return NativeInterface.sharedNativeInterface().sha256(buffer)
}

fun sha512(buffer: ByteArray): ByteArray {
    return NativeInterface.sharedNativeInterface().sha512(buffer)
}

fun sha256hex(buffer: ByteArray): String {
    return sha256(buffer).hexEncode()
}

fun sha512hex(buffer: ByteArray): String {
    return sha512(buffer).hexEncode()
}

/**
 * 空扩展
 */
fun Any?.toString(): String {
    if (this == null) return ""
    return toString()
}

/**
 * tap操作
 */
inline fun <reified T> T.tap(body: (self: T) -> Unit): T {
    body(this)
    return this
}

/**
 * byte 转 无符号
 */
fun Byte.toUnsignedInt() = toInt() and 0xFF

/**
 * 格式化BigDecimal的显示字符串
 */
fun BigDecimal.toPriceAmountString(precision: Int = -1): String {
    val final_precision = if (precision < 0) {
        this.scale()
    } else {
        precision
    }
    return OrgUtils.formatFloatValue(this.toDouble(), final_precision, false)
}

/**
 * 列表转换
 */
fun Iterator<String>.toJSONArray(): JSONArray {
    val list = JSONArray()
    for (key in this) {
        list.put(key)
    }
    return list
}

/**
 * 设置文字，并且光标设置到结尾。
 */
fun EditText.setTextAndSelect(str: String) {
    this.setText(str)
    this.setSelection(this.text.toString().length)
}

/**
 * 调度到主线程运行
 */
fun delay_main(body: () -> Unit) {
    android.os.Handler(Looper.getMainLooper()).postDelayed({ body() }, 1L)
}

/**
 * 构造石墨烯网络，【数量】类型的的 BigDecimal 对象。
 */
fun bigDecimalfromAmount(str: String, precision: BigDecimal): BigDecimal {
    return BigDecimal(str).divide(precision)
}

fun bigDecimalfromAmount(str: String, precision: Int): BigDecimal {
    return bigDecimalfromAmount(str, BigDecimal.valueOf(10.0.pow(precision))).setScale(precision)
}

/**
 * Fabric/Flurry统计
 */
fun btsppLogCustom(event_name: String, args: JSONObject? = null) {
    //  统计Fabric日志
    try {
        val event = CustomEvent(event_name)
        if (args != null) {
            args.keys().forEach { key ->
                //  REMARK：Answer这个属性字符串长度有限制。
                var value = args.get(key).toString()
                if (value.length > 64) {
                    value = value.substring(0, 63)
                }
                event.putCustomAttribute(key, value)
            }
        }
        Answers.getInstance().logCustom(event)
    } catch (e: Exception) {
        //  ...
    }

    //  统计Flurry日志
    try {
        if (args != null) {
            val event_args = mutableMapOf<String, String>()
            args.keys().forEach { key ->
                event_args[key] = args.get(key).toString()
            }
            FlurryAgent.logEvent(event_name, event_args)
        } else {
            FlurryAgent.logEvent(event_name)
        }
    } catch (e: Exception) {
        //  ...
    }
}


/**
 * DP 和 PX 转换
 * 来源 https://www.jianshu.com/p/3520c63e1e0c
 */
private val metrics = Resources.getSystem().displayMetrics

/**
 * 正常编码中一般只会用到 [dp]/[sp] 和 [px] ;
 * 其中[dp]/[sp] 会根据系统分辨率将输入的dp/sp值转换为对应的px
 * 而[px]只是返回自身，目的是表明自己是px值
 */
val Float.dp: Float      // [xxhdpi](360 -> 1080)
    get() = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, this, metrics)

val Int.dp: Int      // [xxhdpi](360 -> 1080)
    get() = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, this.toFloat(), metrics).toInt()

val Float.sp: Float      // [xxhdpi](360 -> 1080)
    get() = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, this, metrics)

val Int.sp: Int      // [xxhdpi](360 -> 1080)
    get() = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, this.toFloat(), metrics).toInt()

val Number.px: Number      // [xxhdpi](360 -> 360)
    get() = this


/**
 * 在(可能存在的?)某些特殊情况会需要将px值转换为对应的dp/sp
 * 对应方法[Number.px2dp]/[Number.px2sp]
 */
val Number.px2dp: Int       // [xxhdpi](360 -> 120)
    get() = (this.toFloat() / metrics.density).toInt()

val Number.px2sp: Int       // [xxhdpi](360 -> 120)
    get() = (this.toFloat() / metrics.scaledDensity).toInt()

/**
 *  获取XML字符串
 */
inline fun Int.xmlstring(ctx: Context): String {
    return ctx.resources.getString(this)
}

/**
 * 简单替换逗号为小数点。部分语言环境下小数点为逗号，存在部分崩溃问题。
 */
inline fun String.fixComma(): String {
    return this.replace(",", ".")
}

const val LLAYOUT_MATCH = LinearLayout.LayoutParams.MATCH_PARENT
const val LLAYOUT_WARP = LinearLayout.LayoutParams.WRAP_CONTENT