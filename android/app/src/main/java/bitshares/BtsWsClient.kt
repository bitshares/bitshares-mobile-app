package bitshares

import com.fowallet.walletcore.bts.GrapheneWebSocket
import org.java_websocket.client.WebSocketClient
import org.java_websocket.drafts.Draft_6455
import org.java_websocket.handshake.ServerHandshake
import java.net.URI
import java.nio.ByteBuffer

class BtsWsClient : WebSocketClient {

    var gw: GrapheneWebSocket

    constructor(serverURI: URI, _gw: GrapheneWebSocket, connectTimeout: Int = 0) : super(serverURI, Draft_6455(), null, connectTimeout) {
        gw = _gw
    }

    override fun onOpen(handshakedata: ServerHandshake) {
        delay_main { gw.webSocketDidOpen() }
    }

    override fun onClose(code: Int, reason: String, remote: Boolean) {
        delay_main { gw.process_websocket_error_or_close("websocket events closed...") }
    }

    override fun onMessage(message: String) {
        delay_main { gw.didReceiveMessage(message) }
    }

    override fun onMessage(message: ByteBuffer) {
        delay_main { gw.didReceiveMessage(message) }
    }

    override fun onError(ex: Exception) {
        delay_main { gw.didFailWithError(ex) }
    }
}