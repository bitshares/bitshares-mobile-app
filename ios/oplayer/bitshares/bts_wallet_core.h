//
//  bts_wallet_core.h
//  oplayer
//
//  Created by Aonichan on 16/1/15.
//
//

#ifndef __bts_wallet_core__
#define __bts_wallet_core__

#include "secp256k1.h"
#include "bts_chain_config.h"

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C"
{
#endif  //  __cplusplus
    
#include <stdio.h>
    
    /**
     *  计算各种 hash 摘要
     */
    extern void rmd160(const unsigned char* message, const size_t length, unsigned char digest20[]);
    extern void sha1(const unsigned char* buffer, const size_t size, unsigned char digest20[]);
    extern void sha256(const unsigned char* buffer, const size_t size, unsigned char digest32[]);
    extern void sha512(const unsigned char* buffer, const size_t size, unsigned char digest64[]);
    
    /**
     *  16进制编码&解码
     */
    extern void hex_encode(const unsigned char* raw_data, const size_t raw_size, unsigned char hex_output[]);
    extern void hex_decode(const unsigned char* hex_string, const size_t hex_size, unsigned char raw_output[]);
    
    /**
     *  Aes256 加密，返回16进制编码后内容。
     *  REMARK：hexoutput 的长度应该为 aes256_calc_output_size(srcsize) 的2倍。
     */
    extern bool __bts_aes256_encrypt_to_hex(const unsigned char* aes_seed, const size_t aes_seed_size,
                                            const unsigned char* srcptr, const size_t srcsize,
                                            unsigned char* hexoutput);
    
    /**
     *  Aes256 解密。
     *  output 的长度应该 不会超过源16进制编码后长度的一半。
     */
    extern bool __bts_aes256_decrypt_from_hex(const unsigned char* aes_seed, const size_t aes_seed_size,
                                              const unsigned char* hex_srcptr, const size_t hex_srcsize,
                                              unsigned char* raw_output, size_t* raw_output_size);
    
    /**
     *  (public) 计算 aes 解密后长度。
     */
    extern size_t __bts_aes256_calc_output_size(size_t input_size);
    
    /**
     *  计算 aes256_encrypt_with_checksum 加密输出 buffer 的大小。
     */
    extern size_t __bts_aes256_encrypt_with_checksum_calc_outputsize(const size_t message_size);
    
    /**
     *  Aes核心加密（主要用于加密钱包、memo等）
     */
    extern bool __bts_aes256_encrypt_with_checksum(const unsigned char private_key32[], const secp256k1_pubkey* public_key, const char* nonce, const size_t nonce_size, const unsigned char* message, const size_t message_size, unsigned char* output);
    
    /**
     *  从seed种子初始化32字节私钥数组
     */
    extern void __bts_gen_private_key_from_seed(const unsigned char* seed, const size_t seed_size, unsigned char private_key32[]);
    
    /**
     *  从公钥结构获取压缩公钥 和 非压缩公钥
     */
    extern void __bts_gen_public_key_compressed(const secp256k1_pubkey* public_key, unsigned char output33[]);
    extern void __bts_gen_public_key_uncompressed(const secp256k1_pubkey* public_key, unsigned char output65[]);
    
    /**
     *  格式化私钥为WIF格式
     */
    extern void __bts_private_key_to_wif(const unsigned char private_key32[], unsigned char wif_output51[], size_t* wif_output_size);
    
    /**
     *  从公钥结构生成 BTS 地址字符串
     */
    extern void __bts_public_key_to_address(const secp256k1_pubkey* public_key, unsigned char address_output[], size_t* address_output_size,
                                            const char* address_prefix, const size_t address_prefix_size);
    
    /**
     *  从 32 字节原始私钥生成 BTS 地址字符串
     */
    extern bool __bts_gen_address_from_private_key32(const unsigned char private_key32[],
                                                     unsigned char address_output[], size_t* address_output_size,
                                                     const char* address_prefix, const size_t address_prefix_size);
    
    /**
     *  从 51 字节WIF格式的私钥)获取 32 字节原始私钥。
     */
    extern bool __bts_gen_private_key_from_wif_privatekey(const unsigned char* wif_privatekey, const size_t wif_privatekey_size, unsigned char private_key32[]);
    
    /**
     *  从BTS地址初始化公钥结构体
     */
    extern bool __bts_gen_public_key_from_b58address(const unsigned char* address, const size_t address_size,
                                                     const size_t address_prefix_size, secp256k1_pubkey* output_public);
    
    
    /**
     *  加法调整公私钥
     */
    extern bool __bts_privkey_tweak_add(unsigned char seckey[], const unsigned char tweak[]);
    extern bool __bts_pubkey_tweak_add(secp256k1_pubkey* pubkey, const unsigned char tweak[]);
    
    /**
     *  保存：序列化钱包对象JSON字符串为二进制流。
     *  entropy     - 外部生成随机字符串的熵（根据系统也许不同，比如各种时间戳、随机数、系统信息、securerandom等）
     *
     *  ※ 注意：返回值需要释放
     *
     *  步骤：
     *      1、lzma压缩
     *      2、根据熵生成随机加密私钥
     *      3、根据随机私钥和钱包密码公钥进行aes加密，并添加checksum。
     *      4、返回内容 = 随机密钥的公钥 + aes加密后数据
     */
    extern unsigned char* __bts_save_wallet(const unsigned char* wallet_jsonbin, const size_t wallet_jsonbin_size,
                                            const unsigned char* password, const size_t password_len,
                                            const unsigned char* entropy, const size_t entropy_size, size_t* output_size);
    
    /**
     *  读取：反序列化钱包二进制流为JSON字符串。
     *
     *  ※ 注意：返回值需要释放
     *
     *  步骤：
     *      1、截取2进制流前33字节作为随机公钥
     *      2、利用随机公钥和钱包密码私钥解密剩余的2进制流，并校验checksum。
     *      3、lzma解压缩
     *      4、返回
     */
    extern unsigned char* __bts_load_wallet(const unsigned char* wallet_buffer, const size_t wallet_buffer_size,
                                            const unsigned char* password, const size_t password_len,
                                            size_t* final_output_size);
    
    /**
     *  (public) 签名
     */
    extern bool __bts_sign_buffer(const unsigned char* sign_buffer, const size_t sign_buffer_size,
                                  const unsigned char sign_private_key32[], unsigned char output_signature65[]);
    
#ifdef __cplusplus
}
#endif  //  __cplusplus

#endif /* __bts_wallet_core__ */
