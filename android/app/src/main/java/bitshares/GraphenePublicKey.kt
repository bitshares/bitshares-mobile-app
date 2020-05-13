package bitshares

import com.btsplusplus.fowallet.NativeInterface
import com.fowallet.walletcore.bts.ChainObjectManager

class GraphenePublicKey {

    companion object {

        fun fromWifPublicKey(wif_public_key: String?): GraphenePublicKey? {
            if (wif_public_key == null || wif_public_key.isEmpty()) {
                return null
            }
            val keydata = NativeInterface.sharedNativeInterface().bts_gen_public_key_from_b58address(wif_public_key.utf8String(),
                    ChainObjectManager.sharedChainObjectManager().grapheneAddressPrefix.utf8String())
            return if (keydata != null) {
                GraphenePublicKey().initWithSecp256k1PublicKey(keydata)
            } else {
                null
            }
        }

    }

    private var _key_data: ByteArray? = null

    fun initWithSecp256k1PublicKey(public_keydata: ByteArray): GraphenePublicKey {
        _key_data = public_keydata
        return this
    }

    fun initWithPrivateKey(private_key: GraphenePrivateKey): GraphenePublicKey {
        return GraphenePublicKey().initWithSecp256k1PublicKey(NativeInterface.sharedNativeInterface().bts_gen_public_key(private_key.getKeyData())!!)
    }

    fun getKeyData(): ByteArray {
        return _key_data!!
    }

    fun toWifString(): String {
        return NativeInterface.sharedNativeInterface().bts_public_key_to_address(_key_data!!,
                ChainObjectManager.sharedChainObjectManager().grapheneAddressPrefix.utf8String())!!.utf8String()
    }

    fun child(child: ByteArray): GraphenePublicKey {
        //  计算 offset
        val offset = sha256(_key_data!! + child)

        //  计算 child 公钥
        return GraphenePublicKey().initWithSecp256k1PublicKey(NativeInterface.sharedNativeInterface().bts_pubkey_tweak_add(_key_data!!, offset)!!)
    }

    /**
     *  (public) 生成变形的 to_public_key，仅用做验证。没发计算出原 to_public_key。
     */
    fun genToToTo(commitment: ByteArray): GraphenePublicKey {
        assert(commitment.size == 33)
        val to_digest = sha256(_key_data!! + commitment)
        return GraphenePrivateKey().initWithSecp256k1PrivateKey(to_digest).getPublicKey()
    }

}