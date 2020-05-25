package bitshares

import com.btsplusplus.fowallet.NativeInterface
import com.fowallet.walletcore.bts.WalletManager

class GraphenePrivateKey {

    companion object {

        fun fromWifPrivateKey(wif_private_key: String?): GraphenePrivateKey? {
            if (wif_private_key == null || wif_private_key.isEmpty()) {
                return null
            }
            val keydata = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_wif_privatekey(wif_private_key.utf8String())
            return if (keydata != null) {
                GraphenePrivateKey().initWithSecp256k1PrivateKey(keydata)
            } else {
                null
            }
        }
    }

    private var _key_data: ByteArray? = null

    fun initWithSecp256k1PrivateKey(private_keydata: ByteArray): GraphenePrivateKey {
        assert(NativeInterface.sharedNativeInterface().bts_verify_private_key(private_keydata))
        _key_data = private_keydata
        return this
    }

    fun initWithSeed(seed: ByteArray): GraphenePrivateKey {
        return initWithSecp256k1PrivateKey(private_keydata = NativeInterface.sharedNativeInterface().bts_gen_private_key_from_seed(seed)!!)
    }

    fun initRandom(): GraphenePrivateKey {
        return initWithSeed(seed = WalletManager.secureRandomByte32())
    }

    fun getKeyData(): ByteArray {
        return _key_data!!
    }

    fun toWifString(): String {
        return NativeInterface.sharedNativeInterface().bts_private_key_to_wif(_key_data!!)!!
    }

    fun getPublicKey(): GraphenePublicKey {
        return GraphenePublicKey().initWithPrivateKey(this)
    }

    fun getSharedSecret(public_key: GraphenePublicKey): ByteArray? {
        return NativeInterface.sharedNativeInterface().bts_get_shared_secret(_key_data!!, public_key.getKeyData())
    }

    fun child(child: ByteArray): GraphenePrivateKey {
        val public_key = getPublicKey()
        val public_keydata = public_key.getKeyData()
        val offset = sha256(public_keydata + child)
        return GraphenePrivateKey().initWithSecp256k1PrivateKey(NativeInterface.sharedNativeInterface().bts_privkey_tweak_add(_key_data!!, offset)!!)
    }

}