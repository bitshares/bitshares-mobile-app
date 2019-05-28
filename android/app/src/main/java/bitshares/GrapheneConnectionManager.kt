package bitshares

import com.fowallet.walletcore.bts.ChainObjectManager
import com.orhanobut.logger.Logger
import org.json.JSONObject

class GrapheneConnectionManager {

    private var _connection_list: MutableList<GrapheneConnection> = mutableListOf()
    private var _available_connlist: MutableList<GrapheneConnection> = mutableListOf()
    private var _last_connection: GrapheneConnection? = null

    companion object {

        private var _sharedGrapheneConnectionManager = GrapheneConnectionManager()

        fun sharedGrapheneConnectionManager(): GrapheneConnectionManager {
            return _sharedGrapheneConnectionManager
        }
    }

    fun haveAnyAvailableConnection(): Boolean {
        return _available_connlist.isNotEmpty()
    }

    /**
     *  (public) 初始化网络连接。
     */
    fun Start(wssServerlangKey: String): Promise {
        //  重连的时候先清理连接
        _connection_list.clear()
        _available_connlist.clear()
        _last_connection = null

        //  初始化所有连接
        val network_infos = ChainObjectManager.sharedChainObjectManager().getCfgNetWorkInfos()
        assert(network_infos != null)
        val max_retry_num = network_infos.getInt("max_retry_num")
        val connect_timeout = network_infos.getInt("connect_timeout")

        //  1、获取服务器动态配置的api结点信息
        val wssUrlHash = JSONObject()
        val serverConfig = SettingManager.sharedSettingManager().serverConfig
        if (serverConfig != null) {
            val serverWssNodes = serverConfig.optJSONObject("wssNodes")
            if (serverWssNodes != null) {
                val defaultList = serverWssNodes.optJSONArray("default")
                val langList = serverWssNodes.optJSONArray(wssServerlangKey)
                if (defaultList != null && defaultList.length() > 0) {
                    defaultList.forEach<String> {
                        wssUrlHash.put(it!!, true)
                    }
                }
                if (langList != null && langList.length() > 0) {
                    langList.forEach<String> {
                        wssUrlHash.put(it!!, true)
                    }
                }
            }
        }

        //  2、获取app内配置的api结点信息
        val wslist = network_infos.getJSONArray("ws_node_list")
        if (wslist != null && wslist.length() > 0) {
            for (i in 0 until wslist.length()) {
                val node = wslist.getJSONObject(i)
                wssUrlHash.put(node.getString("url"), true)
            }
        }

        //  初始化所有结点
        wssUrlHash.keys().forEach { url ->
            _connection_list.add(GrapheneConnection().initWithNode(url, max_retry_num, connect_timeout))
        }

        //  没有结点，直接初始化失败。
        if (_connection_list.count() <= 0) {
            return Promise._reject(Exception("No"))
        }

        //  执行连接请求，任意一个结点连接成功则返回。
        val total_conn_number = _connection_list.count()
        val any_promise = Promise()
        var err_number = 0
        for (conn: GrapheneConnection in _connection_list) {
            //  连接结点服务器，该promise不用catch，通过then的返回值判断成功与否。
            conn.async_exec_db("get_config").then {
                //  refresh fast-conn urllist
                if (_available_connlist.isNotEmpty()) {
                    _available_connlist[0].add_node(conn.server_node_url)
                }
                _available_connlist.add(conn)
                any_promise.resolve(true)
                return@then null
            }.catch {
                //  所有结点都连接失败，则初始化失败。
                if (++err_number >= total_conn_number) {
                    any_promise.reject(false)
                }
            }
        }
        return any_promise
    }


    /**
     *  (public) 获取任意可用的连接。
     */
    fun any_connection(): GrapheneConnection {
        //  TODO:fowallet 根据连接速度选择
        for (conn: GrapheneConnection in _available_connlist) {
            if (conn.is_connect()) {
                _last_connection = conn
                return conn
            }
        }

        //  全部都未连接，则返回第一个，会自动重连。
        _last_connection = if (_available_connlist.size > 0) {
            _available_connlist.first()
        } else {
            _connection_list.first()
        }
        Logger.d("any_connection: closed")
        return _last_connection!!
    }

    /**
     *  (public) 获取上次执行请求的连接，如果该连接异常了则自动获取另外的连接。
     */
    fun last_connection(): GrapheneConnection {
        if (_last_connection != null) {
            return _last_connection!!
        }
        return any_connection()
    }


    /**
     *  (public) 重连所有已断开的连接，后台回到前台考虑执行。
     */
    fun reconnect_all() {
        //  ...
    }

}