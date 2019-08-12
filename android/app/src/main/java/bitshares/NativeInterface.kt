package com.btsplusplus.fowallet

class NativeInterface {

    external fun rmd160(buffer: ByteArray): ByteArray

    external fun sha1(buffer: ByteArray): ByteArray

    external fun sha256(buffer: ByteArray): ByteArray

    external fun sha512(buffer: ByteArray): ByteArray

    external fun bts_aes256_encrypt_to_hex(aes_seed: ByteArray, srcptr: ByteArray): ByteArray?

    external fun bts_aes256_decrypt_from_hex(aes_seed: ByteArray, hexsrc: ByteArray): ByteArray?

    external fun bts_aes256_encrypt_with_checksum(private_key32: ByteArray, public_key: ByteArray, nonce: ByteArray, message: ByteArray): ByteArray?

    external fun bts_gen_private_key_from_seed(seed: ByteArray): ByteArray?

    external fun bts_gen_public_key_compressed(public_key: ByteArray): ByteArray

    external fun bts_gen_public_key_uncompressed(public_key: ByteArray): ByteArray

    external fun bts_private_key_to_wif(private_key32: ByteArray): String?

    external fun bts_public_key_to_address(public_key: ByteArray, address_prefix: ByteArray): ByteArray?

    external fun bts_gen_address_from_private_key32(private_key32: ByteArray, address_prefix: ByteArray): ByteArray?

    external fun bts_gen_private_key_from_wif_privatekey(wif_privatekey: ByteArray): ByteArray?

    external fun bts_gen_public_key_from_b58address(address: ByteArray, address_prefix: ByteArray): ByteArray?

    external fun bts_privkey_tweak_add(seckey: ByteArray, tweak: ByteArray): ByteArray?

    external fun bts_pubkey_tweak_add(pubkey: ByteArray, tweak: ByteArray): ByteArray?

    external fun bts_save_wallet(wallet_jsonbin: ByteArray, password: ByteArray, entropy: ByteArray): ByteArray?

    external fun bts_load_wallet(wallet_buffer: ByteArray, password: ByteArray): ByteArray?

    external fun bts_sign_buffer(sign_buffer: ByteArray, sign_private_key32: ByteArray): ByteArray?

    companion object {

        // Used to load the 'native-lib' library on application startup.
        init {
            System.loadLibrary("fowallet")
        }

        private var _sharedNativeInterface = NativeInterface()

        fun sharedNativeInterface(): NativeInterface {
            return _sharedNativeInterface
        }
    }
}
