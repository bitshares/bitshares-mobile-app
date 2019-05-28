package com.fowallet.walletcore.bts

import bitshares.*
import com.crashlytics.android.Crashlytics
import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.util.*

/**
 * websocket status
 */
enum class GrapheneSocketStatus(val value: Int) {
    pending(0),                 //  连接中
    logined(1),                 //  已连接
    closed(2),                  //  断开连接
}

const val kGwsKeepAliveINterval: Int = 5000
const val kGwsMaxSendLife: Int = 5
const val kGwsMaxRecvLife: Int = kGwsMaxSendLife * 2
const val kGwsConnectPromiseKey: String = "__connectPromiseCallback"

class GrapheneWebSocket {
    private var _webSocket: BtsWsClient? = null

    lateinit var _keepaliveCb: (sock: GrapheneWebSocket) -> Unit
    private var _cbId: Int = 0
    private var _cbs: MutableMap<String, Promise> = mutableMapOf()      //  普通请求的回调函数列表
    private var _subs: MutableMap<String, Any> = mutableMapOf()         //  订阅推送回调列表
    private var _unsub: MutableMap<String, Any> = mutableMapOf()        //  取消订阅
    private var _keepAliveTimer: Timer? = null
    private var _send_life: Int = 0
    private var _recv_life: Int = 0

    //  --------------------------
    private var _username: String = ""
    private var _password: String = ""
    private var _auto_reconnect: Boolean = true
    private var _reconnect_times: Int = 0
    private var _url_list = mutableListOf<String>()
    private var _api_list: Array<String>? = null
    private var _api_ids = mutableMapOf<String, Number>()

    private var _curr_wsnode: String = ""
    private var _wait_promises_queue = mutableListOf<Promise>()
    private var _conn_promise: Promise? = null
    private var _status = GrapheneSocketStatus.pending

    /**
     * (public) 调用请求
     */
    fun call(api_name: String, method: String, params: JSONArray): Promise {
        return wait().then {
            val api_id = _api_ids[api_name]
            if (api_id != null) {
                return@then exec(jsonArrayfrom(api_id, method, params))
            } else {
                return@then Promise._reject("unsupported apiname: ${api_name}")
            }
        }
    }

    /**
     * 是否连接并且登录成功
     */
    fun is_connected(): Boolean {
        return _status == GrapheneSocketStatus.logined
    }

    /**
     * 是否断开连接
     */
    private fun is_closed(): Boolean {
        return _status == GrapheneSocketStatus.closed
    }

    /**
     * 是否在连接中
     */
    fun is_pending(): Boolean {
        return _status == GrapheneSocketStatus.pending
    }

    /**
     * append a new node
     */
    fun add_node(url: String) {
        _url_list.add(url)
    }

    fun initWithServer(url: String, api_list: Array<String>, connect_timeout: Int, keepaliveCb: (sock: GrapheneWebSocket) -> Unit): GrapheneWebSocket {
        _url_list.add(url)

        _webSocket = null
        _keepaliveCb = keepaliveCb
        _api_list = api_list
        _auto_reconnect = true

        //  --- 开始初始化 ---
        reconnect()
        return this
    }

    /**
     * reconnect
     */
    fun manual_reconnect() {
        if (is_closed()) {
            reconnect()
        }
    }

    /**
     * (private) 获取连接的节点地址（根据数组大小进行轮询）
     */
    private fun gen_next_ws_node(): String {
        assert(_url_list.isNotEmpty())
        return _url_list[_reconnect_times++ % _url_list.size]
    }

    /**
     * (private) 开始连接
     */
    private fun reconnect() {
        //  gen url
        _curr_wsnode = gen_next_ws_node()

        //  当前请求数据
        _cbId = 0
        _cbs = mutableMapOf()
        _subs = mutableMapOf()
        _unsub = mutableMapOf()

        //  连接等待队列
        _wait_promises_queue = mutableListOf<Promise>()
        _api_ids = mutableMapOf<String, Number>()

        //  心跳数据
        _keepAliveTimer = null
        _send_life = kGwsMaxSendLife
        _recv_life = kGwsMaxRecvLife

        //  status
        _status = GrapheneSocketStatus.pending

        //  生成等待连接promise
        _conn_promise = Promise()
        _conn_promise!!.then {
            on_connect_responsed(it, null)
            return@then null
        }.catch {
            on_connect_responsed(null, it)
        }

        //  初始化websocket连接
        _webSocket = BtsWsClient(URI(_curr_wsnode), this, 5000)
        _webSocket!!.connect()
    }

    /**
     * (private) 事件 - 连接成功 or 连接失败
     */
    private fun on_connect_responsed(data: Any?, error: Any?) {
        if (error != null) {
            _status = GrapheneSocketStatus.closed
            for (promise in _wait_promises_queue) {
                promise.reject(error)
            }
            _wait_promises_queue.clear()
        } else {
            if (is_closed()) {
                on_login_responsed(null, "closed on pending...")
            } else {
                exec(jsonArrayfrom(1, "login", jsonArrayfrom(_username, _password))).then {
                    on_login_responsed(it, null)
                    return@then null
                }.catch { err ->
                    on_login_responsed(null, err)
                }
            }
        }
    }

    /**
     * (private) 事件 - 登录成功 or 登录失败
     */
    private fun on_login_responsed(data: Any?, error: Any?) {
        if (error != null) {
            _status = GrapheneSocketStatus.closed
            for (promise in _wait_promises_queue) {
                promise.reject(error)
            }
            _wait_promises_queue.clear()
        } else {
            val promise_list = JSONArray()
            _api_list!!.forEach {
                promise_list.put(exec(jsonArrayfrom(1, it, JSONArray())))
            }
            Promise.all(promise_list).then {
                on_api_init_responsed(it as? JSONArray, null)
                return@then null
            }.catch { err ->
                on_api_init_responsed(null, err)
            }
        }
    }

    /**
     * (private) 事件 - 初始化APIID 成功 or 失败
     */
    private fun on_api_init_responsed(data_array: JSONArray?, error: Any?) {
        if (error != null) {
            _status = GrapheneSocketStatus.closed
            for (promise in _wait_promises_queue) {
                promise.reject(error)
            }
            _wait_promises_queue.clear()
        } else {
            var idx = 0
            for (api_id in data_array!!.forin<Number>()) {
                _api_ids[_api_list!![idx++]] = api_id!!
            }
            _status = GrapheneSocketStatus.logined
            for (promise in _wait_promises_queue) {
                promise.resolve(this)
            }
            _wait_promises_queue.clear()
        }
    }

    /**
     * (private) 等待连接成功
     */
    private fun wait(): Promise {
        if (is_connected()) {
            return Promise._resolve(this)
        }
        if (is_closed() && !_auto_reconnect) {
            return Promise._reject("websocket disconnected...")
        }
        if (is_closed()) {
            reconnect()
        }
        var p = Promise()
        _wait_promises_queue.add(p)
        return p
    }

    /**
     * (private) 处理请求
     */
    private fun exec(params: JSONArray): Promise {
        //  已经断线
        if (is_closed()) {
            return Promise._reject("websocket disconnected...")
        }

        //  TODO:该方法待check

        // 计算器
        _cbId++

        //  部分方法特殊处理
        val method: String = params[1] as String
        if (method == "set_subscribe_callback" ||
                method == "subscribe_to_market" ||
                method == "broadcast_transaction_with_callback" ||
                method == "set_pending_transaction_callback") {

            val old_sub_params = params[2] as JSONArray
            val sub_callback = old_sub_params[0]

            //  订阅的callback替换为cbId传送到服务器。
            old_sub_params.put(0, _cbId.toString())

            //  保存订阅callback
            _subs[_cbId.toString()] = sub_callback
        }

        //  取消订阅
        if (method == "unsubscribe_from_market" || method == "unsubscribe_from_accounts") {
            val old_sub_params = params[2] as JSONArray
            val unsub_callback = old_sub_params[0]
            _subs.keys.forEach {
                val cb = _subs[it]
                if (cb === unsub_callback) {
                    _unsub[_cbId.toString()] = it
                    return@forEach
                }
            }
            //  移除第一个 callback 参数
            val sub_params_mutable = JSONArray()
            var idx = 0
            for (obj in old_sub_params.forin<Any>()) {
                if (idx != 0) {
                    sub_params_mutable.put(obj)
                }
                ++idx
            }
            params.put(2, sub_params_mutable)
        }


        //  TODO:fowallet 取消订阅 unsubscribe_from_market unsubscribe_from_accounts

        //  序列化
        val data = jsonObjectfromKVS("id", _cbId, "method", "call", "params", params)

        //  构造promise对象并发送数据
        _send_life = kGwsMaxSendLife

        val p = Promise()
        try {
            val send_data = data.toString()
            _webSocket!!.send(send_data)
            assert(_cbs[_cbId.toString()] == null)
            _cbs[_cbId.toString()] = p
        } catch (e: Exception) {
            p.reject(e)
        }
        return p
    }

    private fun listener(response: JSONObject) {
        var callback_id = response.optString("id", "")

        var sub = false
        val method: String = response.optString("method")

        if (method == "notice") {
            sub = true
            callback_id = response.getJSONArray("params").getString(0)
        }

        var callback: Any? = null

        when (sub) {
            true -> callback = _subs[callback_id]
            false -> callback = _cbs[callback_id]
        }

        if (callback != null && sub) {

            //  订阅方法 callback
            val cb = callback as (Boolean, Any) -> Unit
            cb(true, response.getJSONArray("params")[1])

        } else if (callback != null && !sub) {

            //  普通请求 callback
            _cbs.remove(callback_id)

            //  API调用是否异常判断
            val resp_error = response.optJSONObject("error")
            callback = callback as Promise
            if (resp_error != null) {
                //  错误格式：
                //    @{"code":"1", @"data":@{@"code":@"code", @"message":@"base error message", @"name":@"xx", @"stack":@{}}, @"message":@"detail message"}
                //  [统计]
                val detail_error_message = resp_error.optString("message")
                //  统计Crash日志
                Crashlytics.log(detail_error_message)
                val error_data = resp_error.optJSONObject("data")
                if (error_data != null) {
                    val error_message = error_data.optString("message")
                    val error_code = error_data.optInt("code").toString()
                    val error_stack = error_data.optJSONArray("stack")
                    if (error_message != "" && error_code != "" && error_stack != null && error_stack.length() > 0) {
                        val stack_str = error_stack.last<JSONObject>().toString()
                        btsppLogCustom("api_error_${error_code}",
                                jsonObjectfromKVS("message", error_message, "detail_message", detail_error_message, "stack_str", stack_str))
                    }
                }
                //  返回
                callback.reject(resp_error)
            } else {
                callback.resolve(response.get("result"))
            }
            //  取消订阅
            val unsub_id = _unsub[callback_id]
            if (unsub_id != null) {
                _subs.remove(unsub_id)
                _unsub.remove(callback_id)
            }
        } else {
            assert(false)
        }
    }

    fun close() {
        process_websocket_error_or_close("user close...")
    }

    private fun startKeepAliveTimer() {
        if (_keepAliveTimer == null) {
            _keepAliveTimer = Timer()
            _keepAliveTimer!!.schedule(object : TimerTask() {
                override fun run() {
                    delay_main {
                        onKeepAliveTimerTick()
                    }
                }
            }, 5000, 5000)
        }
    }

    private fun stopKeepAliveTimer() {
        if (_keepAliveTimer != null) {
            _keepAliveTimer!!.cancel()
            _keepAliveTimer = null
        }
    }

    fun onKeepAliveTimerTick() {
        --_recv_life
        if (_recv_life <= 0) {
            process_websocket_error_or_close("heartbeat...")
            return
        }

        --_send_life
        if (_send_life <= 0) {
            if (_keepaliveCb != null) {
                _keepaliveCb(this)
            }
            _send_life = kGwsMaxSendLife
        }
    }


    /**
    Called when any message was received from a web socket.
    This method is suboptimal and might be deprecated in a future release.

    @param webSocket An instance of `SRWebSocket` that received a message.
    @param message   Received message. Either a `String` or `NSData`.
     */
    fun didReceiveMessage(message: Any) {
        //  重置接受数据包的心跳计数
        _recv_life = kGwsMaxRecvLife

        //  解析服务器响应为 json 格式
        var data: JSONObject? = null

        try {
            if (message::class == String::class) {
                data = JSONObject(message.toString().trim())
            } else {
                data = message as JSONObject
            }
        } catch (err: Exception) {
            process_websocket_error_or_close("websocket events message: invalid json, ${err.message}")
            return
        }
        listener(data)
    }

    /**
    Called when a given web socket was open and authenticated.

    @param webSocket An instance of `SRWebSocket` that was open.
     */
    fun webSocketDidOpen() {
        //  REMARK：心跳定时器
        startKeepAliveTimer()
        //  连接成功
        assert(_conn_promise != null)
        _conn_promise?.resolve("websocket opened...")
        _conn_promise = null
    }

    fun process_websocket_error_or_close(message: String) {
        if (is_closed()) {
            return
        }

        //  处于 pending、logined 状态则直接关闭
        _status = GrapheneSocketStatus.closed

        _conn_promise?.reject(message)
        _conn_promise = null

        //  取消心跳计时器
        stopKeepAliveTimer()

        //  通讯中或登录中异常：则当前的所有待完成promise全部reject
        if (_cbs.isNotEmpty()) {
            for ((_, v) in _cbs) {
                v.reject(message)
            }
            _cbs.clear()
        }
        if (_subs.isNotEmpty()) {
            for ((_, v) in _subs) {
                val cb = v as (Boolean, Any?) -> Unit
                cb.invoke(false, message)
            }
            _subs.clear()
        }

        //  关闭网络连接
        _webSocket?.close()
        _webSocket = null

        //  TODO:unse?
//        _unsub.clear()
    }

    fun didFailWithError(error: Exception) {
        process_websocket_error_or_close("websocket events error, ${error.message}")
    }

}


