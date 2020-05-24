package com.btsplusplus.fowallet

class NativeInterface {

    external fun rmd160(buffer: ByteArray): ByteArray

    external fun sha1(buffer: ByteArray): ByteArray

    external fun sha256(buffer: ByteArray): ByteArray

    external fun sha512(buffer: ByteArray): ByteArray

    external fun bts_get_shared_secret(private_key: ByteArray, public_key: ByteArray): ByteArray?

    external fun bts_aes256_encrypt_to_hex(aes_seed: ByteArray, srcptr: ByteArray): ByteArray?
    external fun bts_aes256_decrypt_from_hex(aes_seed: ByteArray, hexsrc: ByteArray): ByteArray?

    external fun bts_aes256cbc_encrypt(secret: ByteArray, src: ByteArray): ByteArray?
    external fun bts_aes256cbc_decrypt(secret: ByteArray, src: ByteArray): ByteArray?

    external fun bts_aes256_decrypt_with_checksum(private_key32: ByteArray, public_key: ByteArray, nonce: ByteArray, message: ByteArray): ByteArray?
    external fun bts_aes256_encrypt_with_checksum(private_key32: ByteArray, public_key: ByteArray, nonce: ByteArray, message: ByteArray): ByteArray?

    external fun bts_gen_private_key_from_seed(seed: ByteArray): ByteArray?

    external fun bts_private_key_to_wif(private_key32: ByteArray): String?

    external fun bts_public_key_to_address(public_key: ByteArray, address_prefix: ByteArray): ByteArray?

    external fun bts_verify_private_key(private_key: ByteArray): Boolean

    external fun bts_gen_public_key(private_key32: ByteArray): ByteArray?

    external fun bts_gen_address_from_private_key32(private_key32: ByteArray, address_prefix: ByteArray): ByteArray?

    external fun bts_gen_private_key_from_wif_privatekey(wif_privatekey: ByteArray): ByteArray?

    external fun bts_gen_public_key_from_b58address(address: ByteArray, address_prefix: ByteArray): ByteArray?

    external fun bts_privkey_tweak_add(seckey: ByteArray, tweak: ByteArray): ByteArray?

    external fun bts_pubkey_tweak_add(pubkey: ByteArray, tweak: ByteArray): ByteArray?

    external fun bts_base58_encode(data: ByteArray): ByteArray?
    external fun bts_base58_decode(data: ByteArray): ByteArray?

    external fun bts_merchant_invoice_decode(b58str: ByteArray): ByteArray?

    external fun bts_save_wallet(wallet_jsonbin: ByteArray, password: ByteArray, entropy: ByteArray): ByteArray?

    external fun bts_load_wallet(wallet_buffer: ByteArray, password: ByteArray): ByteArray?

    external fun bts_sign_buffer(sign_buffer: ByteArray, sign_private_key32: ByteArray): ByteArray?

    external fun bts_gen_pedersen_commit(blind_factor: ByteArray, value: Long): ByteArray?
    external fun bts_gen_pedersen_blind_sum(blinds_in: Array<Any>, non_neg: Long): ByteArray?
    external fun bts_gen_range_proof_sign(min_value: Long, commit: ByteArray, commit_blind: ByteArray, nonce: ByteArray, base10_exp: Long, min_bits: Long, actual_value: Long): ByteArray?

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
