package bitshares

import com.fowallet.walletcore.bts.GrapheneWebSocket
import org.json.JSONArray
import org.json.JSONObject

class GrapheneConnection {

    companion object {

        /**
         *  (public) 测试单个节点
         *  return_connect_obj - 是否返回连接对象，如果不返回则会自动释放。
         */
        fun checkNodeStatus(node: JSONObject, max_retry_num: Int, connect_timeout: Int, return_connect_obj: Boolean): Promise {
            val p = Promise()

            val conn = GrapheneConnection().initWithNode(node.getString("url"), max_retry_num, connect_timeout)
            //  REMARK：2.11.0 同 get_chain_properties，获取链ID等基本属性。
            conn.async_exec_db("get_objects", jsonArrayfrom(jsonArrayfrom("2.11.0", BTS_DYNAMIC_GLOBAL_PROPERTIES_ID))).then {
                val data_array = it as JSONArray

                val chain_properties = data_array.getJSONObject(0)
                val latest_obj = data_array.getJSONObject(1)

                p.resolve(JSONObject().apply {
                    put("connected", true)
                    put("conn_obj", if (return_connect_obj) conn else null)
                    put("chain_properties", chain_properties)
                    put("latest_obj", latest_obj)
                })
                return@then null
            }.catch {
                p.resolve(JSONObject().apply {
                    put("connected", false)
                })
            }

            return p
        }
    }

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


