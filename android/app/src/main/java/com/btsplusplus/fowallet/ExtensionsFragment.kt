package com.btsplusplus.fowallet

import android.support.v4.app.Fragment
import bitshares.dp

fun Fragment.toDp(v: Float): Int {
    return v.dp.toInt()
}

/**
 * 获取对应的 activity
 */
inline fun <reified T> Fragment.getOwner(): T? {
    return activity as? T
}