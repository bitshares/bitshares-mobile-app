package bitshares

import com.fowallet.walletcore.bts.GrapheneWebSocket
import org.json.JSONArray

class GrapheneConnection {

    var server_node_url = ""
    private var _wsrpc: GrapheneWebSocket? = null
    private var _api_list = arrayOf("database", "network_broadcast", "history")

    fun initWithNode(wssURL: String, max_retry_num: Int, connect_timeout: Int): GrapheneConnection {
        server_node_url = wssURL
        _wsrpc = GrapheneWebSocket().initWithServer(wssURL, _api_list, 0) { sock: GrapheneWebSocket ->
            onKeepAliveCallback(sock)
        }
        return this
    }

    /**
     *  关闭连接
     */
    fun close_connection() {
        _wsrpc?.close()
        _wsrpc = null
    }

    fun add_node(url: String) {
        _wsrpc?.add_node(url)
    }

    fun is_connect(): Boolean {
        return _wsrpc?.is_connected() ?: false
    }

    fun manual_reconnect() {
        _wsrpc?.manual_reconnect()
    }

    /**
     *  (private) 心跳
     */
    private fun onKeepAliveCallback(sock: GrapheneWebSocket) {
        if (sock.is_connected()) {
            async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom("2.1.0"))).then {
                //  TODO:Logger.d(String.format("onKeepAliveCallback done: %s", it.toString()))
                return@then null
            }.catch {
                //  TODO:Logger.d("onKeepAliveCallback error: %s", it.message)
            }
        }
    }

    /**
     * (public) 各种API请求接口
     */
    private fun async_exec(apiname: String, method: String, params: JSONArray = JSONArray()): Promise {
        return _wsrpc!!.call(apiname, method, params)
    }

    fun async_exec_db(method: String, params: JSONArray = JSONArray()): Promise {
        return async_exec("database", method, params)
    }

    fun async_exec_net(method: String, params: JSONArray = JSONArray()): Promise {
        return async_exec("network_broadcast", method, params)
    }

    fun async_exec_history(method: String, params: JSONArray = JSONArray()): Promise {
        return async_exec("history", method, params)
    }

}


