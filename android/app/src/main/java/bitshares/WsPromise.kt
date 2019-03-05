package bitshares

import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject

class Promise {

    /**
     * 空值
     */
    class Null

    class WsPromiseException(message: String) : Exception(message) {
        companion object {
            fun throwException(error: Any?) {
                throw WsPromiseException.makeException(error)
            }

            private fun makeException(error: Any?): WsPromiseException {
                if (error != null && error is WsPromiseException) {
                    return error
                } else {
                    return WsPromiseException(error?.toString() ?: "unknown")
                }
            }
        }
    }

    /**
     *  有限状态机
     *  pending为初始状态
     *  fulfilled和rejected为结束状态（结束状态表示promise的生命周期已结束
     *
     *  状态转换关系为：pending->fulfilled，pending->rejected。
     *
     *  - resolve 解决，进入到下一个流程
     *  - reject 拒绝，跳转到捕获异常流程
     */
    enum class WsPromiseState(val type: Int) {
        WsPromiseStatePending(0),           //  初始状态
        WsPromiseStateFulfilled(1),         //  执行成功
        WsPromiseStateRejected(2),          //  执行失败
    }

    companion object {

        fun _resolve(obj: Any?): Promise {
            val p = Promise()
            p.resolve(obj)
            return p
        }

        fun _reject(obj: Any?): Promise {
            val p = Promise()
            p.reject(obj)
            return p
        }

        fun all(vararg args: Promise): Promise {
            val list = JSONArray()
            for (p in args) {
                list.put(p)
            }
            return all(list)
        }

        fun all(list: JSONArray): Promise {
            val p = Promise()
            val promise_size = list.length()
            if (promise_size > 0) {
                android.os.Handler().post {
                    var size = promise_size
                    var completedCount = 0
                    var promise_pending = true
                    var result = JSONArray()
                    for (i in 0 until size) {
                        result.put("")
                        (list.get(i) as Promise).tag = i
                    }
                    for (obj in list.forin<Promise>()) {
                        val promise = obj!!
                        promise.then {
                            result.put(promise.tag as Int, it ?: Null())
                            completedCount += 1
                            if (promise_pending && completedCount >= size) {
                                promise_pending = false
                                p.resolve(result)
                            }
                            return@then null
                        }.catch {
                            if (promise_pending) {
                                promise_pending = false
                                p.reject(it)
                            }
                        }
                    }
                }
            } else {
                p.resolve(ArrayList<Any?>())
            }
            return p
        }

        fun map(hash: JSONObject): Promise {
            val p = Promise()
            if (hash.length() > 0) {
                android.os.Handler().post {
                    var size = hash.length()
                    var completedCount = 0
                    var promise_pending = true
                    var result = JSONObject()
                    hash.keys().forEach { key ->
                        (hash.get(key) as Promise).tag = key
                    }
                    for (key in hash.keys()) {
                        val promise = hash.get(key) as Promise
                        promise.then {
                            result.put(promise.tag as String, it ?: Null())
                            completedCount += 1
                            if (promise_pending && completedCount >= size) {
                                promise_pending = false
                                p.resolve(result)
                            }
                            return@then null
                        }.catch {
                            if (promise_pending) {
                                promise_pending = false
                                p.reject(it)
                            }
                        }
                    }
                }
            } else {
                p.resolve(JSONObject())
            }
            return p
        }
    }

    private var _state = WsPromiseState.WsPromiseStatePending
    private var _resolve_callbacks = JSONArray()
    private var _reject_callbacks = JSONArray()
    private var _value: Any? = null
    var tag: Any? = null

    /**
     * 完成 promise，状态变更 pending -> fulfilled 。并处理回调。
     */
    fun resolve(data: Any?) {
        if (_state != WsPromiseState.WsPromiseStatePending) {
            return
        }
        _value = data
        state_changed(WsPromiseState.WsPromiseStateFulfilled)
        delay {
            resolve_invoke_core(data)
        }
    }

    private fun resolve_invoke_core(data: Any?) {
        _resolve_callbacks.forEach<((obj: Any?) -> Any?)> {
            it!!.invoke(data)
        }
    }

    /**
     * 拒绝 promise，状态变更 pending -> rejected 。并处理回调。
     */
    fun reject(data: Any?) {
        if (_state != WsPromiseState.WsPromiseStatePending) {
            return
        }
        _value = data
        state_changed(WsPromiseState.WsPromiseStateRejected)
        delay {
            reject_invoke_core(data)
        }
    }

    private fun reject_invoke_core(data: Any?) {
        _reject_callbacks.forEach<((obj: Any?) -> Any?)> {
            it!!.invoke(data)
        }
    }

    /**
     * (public) then操作
     */
    fun then(onResolved: (obj: Any?) -> Any?): Promise {
        return then_core(onResolved, ::default_onRejected)
    }

    /**
     * (public) catch操作
     */
    fun error(onRejected: (obj: Any?) -> Unit): Promise {
        val onRejectedWithReturnValue: (obj: Any?) -> Any? = label@{ data ->
            onRejected(data)
            return@label null
        }
        return then_core(::default_onResolved, onRejectedWithReturnValue)
    }

    /**
     * (public) error的别名
     */
    fun catch(onRejected: (obj: Any?) -> Unit): Promise {
        return error(onRejected)
    }

    /**
     * 延迟执行
     */
    private fun delay(body: () -> Unit) {
        android.os.Handler(Looper.getMainLooper()).postDelayed({ body() }, 1L)
    }

    /**
     * then操作核心。public 的 then 和 catch 都是该方法的封装。
     */
    private fun then_core(onResolved: (obj: Any?) -> Any?, onRejected: (obj: Any?) -> Any?): Promise {
        var promise_new = Promise()
        when (_state) {
            WsPromiseState.WsPromiseStateFulfilled -> {
                try {
                    val x = onResolved(_value)
                    if (x != null && x is Promise) {
                        x.then {
                            return@then promise_new.resolve(it)
                        }.catch {
                            promise_new.reject(it)
                        }
                    } else {
                        promise_new.resolve(x)
                    }
                } catch (e: WsPromiseException) {
                    promise_new.reject(e)
                }
            }
            WsPromiseState.WsPromiseStateRejected -> {
                try {
                    val x = onRejected(_value)
                    if (x != null && x is Promise) {
                        x.then {
                            return@then promise_new.resolve(it)
                        }.catch {
                            promise_new.reject(it)
                        }
                    } else {
                        promise_new.resolve(x)
                    }
                } catch (e: WsPromiseException) {
                    promise_new.reject(e)
                }
            }
            WsPromiseState.WsPromiseStatePending -> {
                var temponResolved: (obj: Any?) -> Any? = label@{ data ->
                    try {
                        val x = onResolved(data)
                        if (x != null && x is Promise) {
                            x.then {
                                return@then promise_new.resolve(it)
                            }.catch {
                                promise_new.reject(it)
                            }
                        } else {
                            promise_new.resolve(x)
                        }
                    } catch (e: WsPromiseException) {
                        promise_new.reject(e)
                    }
                    return@label null
                }
                var temponRejected: (obj: Any?) -> Any? = label@{ data ->
                    try {
                        val x = onRejected(data)
                        if (x != null && x is Promise) {
                            x.then {
                                return@then promise_new.resolve(it)
                            }.catch {
                                promise_new.reject(it)
                            }
                        } else {
                            promise_new.resolve(x)
                        }
                    } catch (e: WsPromiseException) {
                        promise_new.reject(e)
                    }
                    return@label null
                }
                _resolve_callbacks.put(temponResolved)
                _reject_callbacks.put(temponRejected)
            }
        }
        return promise_new
    }

    private fun default_onResolved(obj: Any?): Any? {
        return obj
    }

    private fun default_onRejected(obj: Any?): Any? {
        WsPromiseException.throwException(obj)
        return null
    }

    private fun state_changed(new_state: WsPromiseState) {
        if (_state != WsPromiseState.WsPromiseStatePending) {
            return
        }
        _state = new_state
    }
}
