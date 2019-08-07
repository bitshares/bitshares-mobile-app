//
//  js_signer.c
//  oplayer
//
//  Created by Aonichan on 16/1/15.
//
//
#include <stdlib.h>
#include <string.h>

#include "bts_wallet_core.h"
#include "secp256k1.h"
#include "secp256k1_recovery.h"

#include "libbase58.h"

#include "rmd160.h"

#include "WjCryptLib_Sha1.h"
#include "WjCryptLib_Sha256.h"
#include "WjCryptLib_Sha512.h"
#include "WjCryptLib_AesCbc.h"

#include "LzmaLib.h"

/**
 *  临时缓冲区（不大于该缓冲区的临时buffer都可以使用）
 */
static unsigned char __bts_wallet_core_temp_buffer[2048];

struct __aes256_context
{
    unsigned char iv[16];
    unsigned char key[32];
};

#pragma mark- prototype

static void rmd160hex(const byte* message, const dword length, byte digest40[]);
static void gen_aes_context_from_seed(struct __aes256_context* ctx, const unsigned char* seed, const size_t seed_size);
static void gen_aes_context_from_sha512(struct __aes256_context* ctx, const unsigned char* hex_sha512);
static void gen_aes_context(struct __aes256_context* ctx, const unsigned char* iv, const unsigned char* key);
static bool get_shared_secret(const unsigned char private_key32[], secp256k1_pubkey* public_key, unsigned char output_shared_secret32_digest64[]);
static bool aes256_encrypt(const struct __aes256_context* ctx, const char* data, char* output, size_t output_size);
static bool aes256_decrypt(const struct __aes256_context* ctx, const char* data, const size_t size,  char* output, size_t* output_size);
static secp256k1_context* get_static_context();

#pragma mark- digest

/**
 *  (public) 计算 RMD160 摘要
 *
 *  From：https://homes.esat.kuleuven.be/~bosselae/ripemd160/
 *  参考：https://homes.esat.kuleuven.be/~bosselae/ripemd160/ps/AB-9601/hashtest.c
 */
#ifndef RMDsize
#define RMDsize 160
#endif
void rmd160(const unsigned char* message, const size_t length, unsigned char digest20[])
{
    dword         MDbuf[RMDsize/32];   /* contains (A, B, C, D(, E))   */
    dword         X[16];               /* current 16-word chunk        */
    unsigned int  i;                   /* counter                      */
    dword         nbytes;              /* # of bytes not yet processed */
    
    /* initialize */
    MDinit(MDbuf);
    
    /* process message in 16-word chunks */
    for (nbytes=(dword)length; nbytes > 63; nbytes-=64) {
        for (i=0; i<16; i++) {
            X[i] = BYTES_TO_DWORD(message);
            message += 4;
        }
        compress(MDbuf, X);
    }                                    /* length mod 64 bytes left */
    
    /* finish: */
    MDfinish(MDbuf, (byte*)message, (dword)length, 0);
    
    for (i=0; i<RMDsize/8; i+=4) {
        digest20[i]   =  MDbuf[i>>2];         /* implicit cast to byte  */
        digest20[i+1] = (MDbuf[i>>2] >>  8);  /*  extracts the 8 least  */
        digest20[i+2] = (MDbuf[i>>2] >> 16);  /*  significant bits.     */
        digest20[i+3] = (MDbuf[i>>2] >> 24);
    }
    
    return;
}

static void rmd160hex(const byte* message, const dword length, byte digest40[])
{
    byte digest20[20];
    rmd160(message, length, digest20);
    hex_encode(digest20, sizeof(digest20), digest40);
}

/**
 *  (public) 计算 SHA1 摘要（即SHA160）
 */
void sha1(const unsigned char* buffer, const size_t size, unsigned char digest20[])
{
    Sha1Context   sha1Context;
    SHA1_HASH     sha1Hash;
    
    Sha1Initialise( &sha1Context );
    Sha1Update( &sha1Context, buffer, (uint32_t)size);
    Sha1Finalise( &sha1Context, &sha1Hash );
    
    //  TODO:这个拷贝可以省略吗
    memcpy((void*)digest20, sha1Hash.bytes, sizeof(sha1Hash.bytes));
}

/**
 *  (public) 计算 SHA256 摘要
 */
void sha256(const unsigned char* buffer, const size_t size, unsigned char digest32[])
{
    Sha256Context   sha256Context;
    SHA256_HASH     sha256Hash;
    
    Sha256Initialise( &sha256Context );
    Sha256Update( &sha256Context, buffer, (uint32_t)size);
    Sha256Finalise( &sha256Context, &sha256Hash );
    
    //  TODO:这个拷贝可以省略吗
    memcpy((void*)digest32, sha256Hash.bytes, sizeof(sha256Hash.bytes));
}

/**
 *  (public) 计算 SHA512 摘要
 */
void sha512(const unsigned char* buffer, const size_t size, unsigned char digest64[])
{
    Sha512Context   sha512Context;
    SHA512_HASH     sha512Hash;
    
    Sha512Initialise( &sha512Context );
    Sha512Update( &sha512Context, buffer, (uint32_t)size );
    Sha512Finalise( &sha512Context, &sha512Hash );
    
    //  TODO:这个拷贝可以省略吗
    memcpy((void*)digest64, sha512Hash.bytes, sizeof(sha512Hash.bytes));
}

#pragma mark- aes256 & cbc

/**
 *  (private) 根据种子字符串生成 aes256-cbc 加密解密上下文信息。
 */
static void gen_aes_context_from_seed(struct __aes256_context* ctx, const unsigned char* seed, const size_t seed_size)
{
    unsigned char digest64[64] = {0, };
    unsigned char digest128[128] = {0, };
    
    sha512(seed, seed_size, digest64);
    hex_encode(digest64, sizeof(digest64), digest128);
    
    gen_aes_context_from_sha512(ctx, digest128);
}

/**
 *  (private) 根据 16进制编码的 SHA512 摘要字符串生成 aes256-cbc 加密解密上下文信息。
 */
static void gen_aes_context_from_sha512(struct __aes256_context* ctx, const unsigned char* hex_sha512)
{
    hex_decode((const unsigned char*)&hex_sha512[0], 64, ctx->key);
    hex_decode((const unsigned char*)&hex_sha512[64], 32, ctx->iv);
}

/**
 *  (private) 直接根据 iv 和 key 信息生成 aes256-cbc 加密解密上下文信息。
 */
static void gen_aes_context(struct __aes256_context* ctx, const unsigned char* iv, const unsigned char* key)
{
    memcpy(ctx->iv, iv, sizeof(ctx->iv));
    memcpy(ctx->key, key, sizeof(ctx->key));
}

/**
 *  (private) 获取 shared_secret，终于用于 aes 加解密。    REMARK：public_key 会发生改变，如果有必要需要提前备份。
 */
static bool get_shared_secret(const unsigned char private_key32[], secp256k1_pubkey* public_key, unsigned char output_shared_secret32_digest64[])
{
    secp256k1_context* ctx_both = get_static_context();
    
    //  3.1、用私钥调整公钥
    int ret = secp256k1_ec_pubkey_tweak_mul(ctx_both, public_key, private_key32);
    if (!ret){
        return false;
    }
    
    //  3.2、调整完毕后的公钥序列化为非压缩格式，然后取X字段作为 shared_secret。
    unsigned char pubkey_tweaked_uncompressed[66] = {0,};
    size_t pubkey_tweaked_uncompressed_len = sizeof(pubkey_tweaked_uncompressed);
    (void)secp256k1_ec_pubkey_serialize(ctx_both, pubkey_tweaked_uncompressed, &pubkey_tweaked_uncompressed_len, public_key, SECP256K1_EC_UNCOMPRESSED);
    
    //  3.3、获取shared_secret（即X字段）然后计算sha512摘要。
    //  REMARK：pubkey_tweaked_uncompressed[1..32] 是pubkey的x值，33..65是y值
    sha512(&pubkey_tweaked_uncompressed[1], 32, output_shared_secret32_digest64);
    
    return true;
}

/**
 *  Aes加密，输出buffer需要手动padding，缓冲区长度必须是16点倍数。
 *
 *  REMARK: data 和 output 大小应该相同，output_size 为输入和输出流的大小。
 */
static bool aes256_encrypt(const struct __aes256_context* ctx, const char* data, char* output, size_t output_size)
{
    //  TODO:fowallet
    int error = AesCbcEncryptWithKey(ctx->key, sizeof(ctx->key), ctx->iv, data, output, (uint32_t)output_size);
    if (error != 0){
        //  TODO:fowallet
        return false;
    }
    return true;
}

/**
 *  (private) aes 解密
 */
static bool aes256_decrypt(const struct __aes256_context* ctx, const char* data, const size_t size, char* output, size_t* output_size)
{
    //  TODO:fowallet error待处理
    
    int error = AesCbcDecryptWithKey(ctx->key, sizeof(ctx->key), ctx->iv, data, output, (uint32_t)size);
    if (error != 0){
        //  TODO:fowallet
        return false;
    }
    
    size_t padding_size = (size_t)output[size - 1];
    if (padding_size <= 0 || padding_size > AES_BLOCK_SIZE){
        //  TODO:fowallet error
        return false;
    }
    *output_size = size - padding_size;
    return true;
}

#pragma mark- encode & decode

/**
 *  (private) Base58 编码 TODO：未完成
 */
static void base58_encode(const unsigned char* raw_data, const size_t raw_size, unsigned char output[], size_t* output_size)
{
    //  TODO:
    
    b58enc((char*)output, output_size, (const void*)raw_data, raw_size);
    
//    bool b58enc(char *b58, size_t *b58sz, const void *data, size_t binsz)
}

/**
 *  (private) Base58 解码 TODO：未完成
 */
static unsigned char* base58_decode(const unsigned char* b58_string, const size_t b58_size, unsigned char output[], size_t* output_size)
{
    size_t origin_output_size = *output_size;
    
    //  解码
    if (!b58tobin(output, output_size, (const char*)b58_string, b58_size)){
        return 0;
    }
    
    //  REMARK: output缓冲区如果过大，则可能前面存在一堆\0，需要移除。
    return &output[origin_output_size - *output_size];
}

/**
 *  (public) 16进制编码（TODO：待优化）
 */
void hex_encode(const unsigned char* raw_data, const size_t raw_size, unsigned char hex_output[])
{
    size_t fill_pos = 0;
    for (size_t i = 0; i < raw_size; ++i) {
        sprintf((char*)&hex_output[fill_pos], "%02x", raw_data[i]);
        fill_pos += 2;
    }
}

/**
 *  (public) 16进制解码（TODO：待优化）
 */
void hex_decode(const unsigned char* hex_string, const size_t hex_size, unsigned char raw_output[])
{
    size_t i;
    char holdingBuffer[3] = {0};
    unsigned hexToNumber;
    for( i=0; i<hex_size/2; i++ )
    {
        holdingBuffer[0] = hex_string[i*2 + 0];
        holdingBuffer[1] = hex_string[i*2 + 1];
        sscanf(holdingBuffer, "%x", &hexToNumber );
        raw_output[i] = (unsigned char)hexToNumber;
    }
}

#pragma mark- private key

/**
 *  获取上下文
 */
static secp256k1_context* get_static_context()
{
    static secp256k1_context* ctx_both = 0;
    if (!ctx_both){
        ctx_both  = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY | SECP256K1_CONTEXT_SIGN);
    }
    return ctx_both;
}

#pragma mark- export api

/**
 *  Aes256 加密，返回16进制编码后内容。
 *  REMARK：hexoutput 的长度应该为 __bts_aes256_calc_output_size(srcsize) 的2倍。
 */
bool __bts_aes256_encrypt_to_hex(const unsigned char* aes_seed, const size_t aes_seed_size,
                                 const unsigned char* srcptr, const size_t srcsize,
                                 unsigned char* hexoutput)
{
    struct __aes256_context aes_ctx;
    gen_aes_context_from_seed(&aes_ctx, aes_seed, aes_seed_size);
    
    size_t output_size = __bts_aes256_calc_output_size(srcsize);
    //  获取加解密缓冲区，如果 output_size 大于临时缓冲区大小，则动态分配，返回之前需要释放内存。
    unsigned char* output;
    if (output_size <= sizeof(__bts_wallet_core_temp_buffer)){
        output = __bts_wallet_core_temp_buffer;
    }else{
        output = malloc(output_size);
        if (!output){
            return false;
        }
    }
    
    //  拷贝下不修改源指针
    memcpy(output, srcptr, srcsize);
    
    //  填充input缓冲区(和output可以共用)：4字节checksum + 原message + padding内容
    //  PKCS5Padding：填充的原则是，如果长度少于16个字节，需要补满16个字节，补(16-len)个(16-len)例如：123这个节符串是3个字节，16-3= 13,补满后如：123+13个十进制的13。
    //  padding(最少1字节，最多16字节）
    size_t padding_value = output_size - srcsize;
    size_t padding_size = output_size - srcsize;
    memset(&output[srcsize], padding_value, padding_size);
    if (!aes256_encrypt(&aes_ctx, (const char*)output, (char*)output, output_size)){
        return false;
    }
    hex_encode(output, output_size, hexoutput);
    
    //  释放内存
    if (output_size > sizeof(__bts_wallet_core_temp_buffer)){
        free(output);
    }
    
    return true;
}

/**
 *  Aes256 解密。
 *  output 的长度应该 不会超过源16进制编码后长度的一半。
 */
bool __bts_aes256_decrypt_from_hex(const unsigned char* aes_seed, const size_t aes_seed_size,
                                   const unsigned char* hex_srcptr, const size_t hex_srcsize,
                                   unsigned char* raw_output, size_t* raw_output_size)
{
    struct __aes256_context aes_ctx;
    gen_aes_context_from_seed(&aes_ctx, aes_seed, aes_seed_size);
    
    //  16进制解码
    assert((hex_srcsize % 2) == 0);
    size_t output_size = hex_srcsize / 2;
    unsigned char output[output_size];
    hex_decode(hex_srcptr, hex_srcsize, output);
    
    //  aes解密
    if (!aes256_decrypt(&aes_ctx, (const char*)output, output_size, (char*)raw_output, raw_output_size)){
        return false;
    }
    
    return true;
}

/**
 *  (public) 计算 aes 解密后长度。
 */
size_t __bts_aes256_calc_output_size(size_t input_size)
{
    //  PKCS5Padding：填充的原则是，如果长度少于16个字节，需要补满16个字节，补(16-len)个(16-len)例如：123这个节符串是3个字节，16-3= 13,补满后如：123+13个十进制的13。
    size_t mod = input_size % AES_BLOCK_SIZE;
    return input_size + AES_BLOCK_SIZE - mod;
}

/**
 *  (public) 计算 aes256_encrypt_with_checksum 加密输出 buffer 的大小。
 */
size_t __bts_aes256_encrypt_with_checksum_calc_outputsize(const size_t message_size)
{
    size_t input_size = message_size + 4;  //  message_size + checksum_size
    size_t output_size = __bts_aes256_calc_output_size(input_size);
    return output_size;
}

/**
 *  (public) 主要方法，用于memo、钱包等加密。
 */
bool __bts_aes256_encrypt_with_checksum(const unsigned char private_key32[], const secp256k1_pubkey* public_key,
                                       const char* nonce, const size_t nonce_size,
                                       const unsigned char* message, const size_t message_size, unsigned char* output)
{
    //  1、生成aes上下文
    secp256k1_pubkey pubkey = {0, };
    memcpy(&pubkey, public_key, sizeof(pubkey));
    
    unsigned char shared_secret_sha512[64] = {0,};
    if (!get_shared_secret(private_key32, &pubkey, shared_secret_sha512)){
        return false;
    }
    
    //  nonce + hex-shared_secret_sha512-size
    unsigned char seed_buffer[nonce_size + 128 + 1];
    if (nonce && nonce_size > 0){
        memcpy(seed_buffer, nonce, nonce_size);
    }
    hex_encode(shared_secret_sha512, sizeof(shared_secret_sha512), &seed_buffer[nonce_size]);
    seed_buffer[nonce_size + 128] = 0;  //  zero it!
    
    struct __aes256_context aes_ctx;
    gen_aes_context_from_seed(&aes_ctx, seed_buffer, nonce_size + 128);
    
    //  2、计算出checksum
    unsigned char digest32[32] = {0, };
    sha256(message, message_size, digest32);
    
    //  3、加密
    size_t input_size = message_size + 4;  //  message_size + checksum_size
    size_t output_size = __bts_aes256_calc_output_size(input_size);
    
    //  3.1、填充input缓冲区(和output可以共用)：4字节checksum + 原message + padding内容
    memcpy(&output[0], &digest32[0], 4);
    memcpy(&output[4], message, message_size);
    //  PKCS5Padding：填充的原则是，如果长度少于16个字节，需要补满16个字节，补(16-len)个(16-len)例如：123这个节符串是3个字节，16-3= 13,补满后如：123+13个十进制的13。
    //  padding(最少1字节，最多16字节）
    size_t padding_value = output_size - input_size;
    size_t padding_size = output_size - input_size;
    memset(&output[input_size], padding_value, padding_size);
    
    //  3.2、执行加密核心
    if (!aes256_encrypt(&aes_ctx, (const char*)output, (char*)output, output_size)){
        return false;
    }
    
    return true;
}

/**
 *  (public) 根据种子字符串生成私钥信息
 */
void __bts_gen_private_key_from_seed(const unsigned char* seed, const size_t seed_size, unsigned char private_key32[])
{
    sha256(seed, seed_size, private_key32);
}

/**
 *  从公钥结构获取压缩公钥 和 非压缩公钥
 */
void __bts_gen_public_key_compressed(const secp256k1_pubkey* public_key, unsigned char output33[])
{
    size_t output_size = 33;
    (void)secp256k1_ec_pubkey_serialize(get_static_context(), output33, &output_size, public_key, SECP256K1_EC_COMPRESSED);
}

void __bts_gen_public_key_uncompressed(const secp256k1_pubkey* public_key, unsigned char output65[])
{
    size_t output_size = 65;
    (void)secp256k1_ec_pubkey_serialize(get_static_context(), output65, &output_size, public_key, SECP256K1_EC_UNCOMPRESSED);
}

/**
 *  格式化私钥为WIF格式
 */
void __bts_private_key_to_wif(const unsigned char private_key32[], unsigned char wif_output51[], size_t* wif_output_size)
{
    const size_t private_key_size = 32;
    
    //  __bts_wallet_core_temp_buffer内存格式：0x80 + 32B-privatekey + digest32
    
    __bts_wallet_core_temp_buffer[0] = 0x80;
    memcpy(&__bts_wallet_core_temp_buffer[1], private_key32, private_key_size);
    
    unsigned char digest32[32] = {0, };
    sha256(__bts_wallet_core_temp_buffer, private_key_size + 1, digest32);
    sha256(digest32, sizeof(digest32), &__bts_wallet_core_temp_buffer[private_key_size + 1]);
    
    //  base58 编码   REMARK：从第0个字节开始取37个字节  1Byte(ver) + 32Byte(key) + 32Byte(digest)
    size_t output_size = *wif_output_size;
    base58_encode(&__bts_wallet_core_temp_buffer[0], 1 + private_key_size + 4, wif_output51, &output_size);
    
    //  REMARK: 这个 output_size 的长度包含了 '\0'，需要移除。
    *wif_output_size = output_size - 1;
}

/**
 *  从公钥结构生成 BTS 地址字符串
 */
void __bts_public_key_to_address(const secp256k1_pubkey* public_key, unsigned char address_output[], size_t* address_output_size,
                                 const char* address_prefix, const size_t address_prefix_size)
{
    assert(address_prefix);
    assert(address_prefix_size > 0);
    
    unsigned char output[33 + 4] = {0, };
    
    //  生成压缩格式公钥
    __bts_gen_public_key_compressed(public_key, output);
    
    //  生成压缩格式公钥的摘要信息
    unsigned char digest20[20] = {0, };
    rmd160(output, 33, digest20);
    
    //  拼接压缩格式公钥和 4 字节摘要信息
    memcpy(&output[33], digest20, 4);
    
    //  base58 编码
    size_t encode_buffer_size = *address_output_size - address_prefix_size;
    base58_encode(output, sizeof(output), &address_output[address_prefix_size], &encode_buffer_size);
    
    //  添加前缀
    memcpy(address_output, address_prefix, address_prefix_size);
    
    //  REMARK: 这个 encode_buffer_size 的长度包含了 '\0'，需要移除。
    *address_output_size = encode_buffer_size - 1 + address_prefix_size;
}

/**
 *  从 32 字节原始私钥生成 BTS 地址字符串
 */
bool __bts_gen_address_from_private_key32(const unsigned char private_key32[],
                                          unsigned char address_output[], size_t* address_output_size,
                                          const char* address_prefix, const size_t address_prefix_size)
{
    secp256k1_pubkey pubkey = {0, };
    if (!secp256k1_ec_pubkey_create(get_static_context(), &pubkey, private_key32)){
        return false;
    }
    
    __bts_public_key_to_address(&pubkey, address_output, address_output_size, address_prefix, address_prefix_size);
    return true;
}

/**
 *  从 51 字节WIF格式的私钥)获取 32 字节原始私钥。
 */
bool __bts_gen_private_key_from_wif_privatekey(const unsigned char* wif_privatekey, const size_t wif_privatekey_size, unsigned char private_key32[])
{
    //  base58解码
    unsigned char temp_buffer[51] = {0,};   //  REMARK:这个缓冲区大小能够容纳地址b58解码后的数据即可，基本大小只有37字节，51是WIF格式长度。
    size_t output_size = sizeof(temp_buffer);
    const unsigned char* pOutput = base58_decode(wif_privatekey, wif_privatekey_size, temp_buffer, &output_size);
    if (!pOutput){
        return false;
    }
    //  base58解码后的第一个字节为版本号，应该为0x80。
    unsigned char version = *&pOutput[0];
    if (version != 0x80){
        return false;
    }
    
    //  pOutput长度为37字节，等于（0x80+32字节原始私钥+4字节checksum）
    unsigned char checksum[4] = {0, };
    memcpy(checksum, &pOutput[output_size - 4], 4);
    
    //  计算真实的 checksum
    unsigned char digest32[32] = {0, };
    unsigned char new_digest32[32] = {0, };
    sha256(pOutput, output_size - 4, digest32);
    sha256(digest32, sizeof(digest32), new_digest32);
    
    //  比较 checksum
    if (0 != memcmp(checksum, new_digest32, 4)){
        //  校验失败
        return false;//TODO:failed
    }
    
    //  获取原始私钥（不包含第一个字节）
    memcpy(private_key32, &pOutput[1], 32);
    
    return true;
}


bool __bts_gen_public_key_from_b58address(const unsigned char* address, const size_t address_size,
                                          const size_t address_prefix_size, secp256k1_pubkey* output_public)
{
    assert(address_prefix_size > 0);
    assert(address_prefix_size < address_size);
    
    //  BTS地址移除前缀之后进行base58解码
    unsigned char temp_buffer[53] = {0,};   //  REMARK:这个缓冲区大小能够容纳地址b58解码后的数据即可，基本大小只有37字节，53是地址长度。
    size_t output_size = sizeof(temp_buffer);
    const unsigned char* pOutput = base58_decode(&address[address_prefix_size], address_size-address_prefix_size, temp_buffer, &output_size);
    if (!pOutput){
        return false;
    }
 
    //  pOutput长度为37字节，等于（33字节压缩公钥+4字节checksum）
    unsigned char checksum[4] = {0, };
    memcpy(checksum, &pOutput[output_size - 4], 4);
    
    //  计算真实的 checksum
    unsigned char digest20[20] = {0, };
    rmd160(pOutput, (dword)(output_size - 4), digest20);
    
    //  比较 checksum
    if (0 != memcmp(checksum, digest20, 4)){
        //  校验失败
        return false;//TODO:failed
    }
    
    //  从33字节压缩过的公钥字符串恢复公钥对象
    int ret = secp256k1_ec_pubkey_parse(get_static_context(), output_public, pOutput, 33);
    if (!ret){
        //  解析失败
        return false;
    }
    
    return true;
}

bool __bts_privkey_tweak_add(unsigned char seckey[], const unsigned char tweak[])
{
    int ret = secp256k1_ec_privkey_tweak_add(get_static_context(), seckey, tweak);
    
    if (!ret){
        return false;
    }
    
    return true;
}

bool __bts_pubkey_tweak_add(secp256k1_pubkey* pubkey, const unsigned char tweak[])
{
    int ret = secp256k1_ec_pubkey_tweak_add(get_static_context(), pubkey, tweak);
    
    if (!ret){
        return false;
    }
    
    return true;
}

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
unsigned char* __bts_save_wallet(const unsigned char* wallet_jsonbin, const size_t wallet_jsonbin_size,
                                 const unsigned char* password, const size_t password_len,
                                 const unsigned char* entropy, const size_t entropy_size, size_t* output_size)
{
    assert(wallet_jsonbin);
    assert(wallet_jsonbin_size > 0);
    assert(password);
    
    //  lzma压缩 buffer 和 最终结果 buffer。
    unsigned char* dstBuffer = 0;
    unsigned char* output = 0;
    
    //  获取上下文
    secp256k1_context* ctx_both = get_static_context();
    
    //  1、lzma压缩
    
    //  LZMA解压缩：
    //  参考：https://svn.python.org/projects/external/xz-5.0.3/doc/lzma-file-format.txt
    //  Header (1 + 4 + 8)
    //    +------------+----+----+----+----+--+--+--+--+--+--+--+--+
    //    | Properties |  Dictionary Size  |   Uncompressed Size   |
    //    +------------+----+----+----+----+--+--+--+--+--+--+--+--+
    const size_t compressHeaderSize = LZMA_PROPS_SIZE + sizeof(uint64_t);
    size_t destLen = wallet_jsonbin_size + 256;
    dstBuffer = malloc(compressHeaderSize + destLen);
    if (!dstBuffer){
        goto save_failed;
    }
    size_t nPropSize = LZMA_PROPS_SIZE;
    int result = LzmaCompress(&dstBuffer[compressHeaderSize], &destLen,
                              wallet_jsonbin, wallet_jsonbin_size,
                              &dstBuffer[0], &nPropSize, 1, 1<<24, 3, 0, 2, 32, 2);
    if (result == SZ_ERROR_OUTPUT_EOF){
        free(dstBuffer);    //  释放内存
        dstBuffer = 0;
        destLen = (wallet_jsonbin_size + 256) * 2;
        dstBuffer = malloc(compressHeaderSize + destLen);
        if (!dstBuffer){
            goto save_failed;
        }
        result = LzmaCompress(&dstBuffer[compressHeaderSize], &destLen,
                              wallet_jsonbin, wallet_jsonbin_size,
                              &dstBuffer[0], &nPropSize, 1, 1<<24, 3, 0, 2, 32, 2);
    }
    //  lzma压缩失败
    if (result != SZ_OK){
        goto save_failed;
    }
    //  压缩成功：设置长度信息
    *(uint64_t*)&dstBuffer[LZMA_PROPS_SIZE] = (uint64_t)wallet_jsonbin_size;
    size_t compressed_size = compressHeaderSize + destLen;
    
    //  2、生成密码的密钥对：私钥和公钥
    unsigned char password_private_key[32] = {0, };
    __bts_gen_private_key_from_seed(password, password_len, password_private_key);
    secp256k1_pubkey password_pubkey = {0, };
    if (!secp256k1_ec_pubkey_create(ctx_both, &password_pubkey, password_private_key)){
        goto save_failed;
    }
    
    //  3、生成随机加密私钥
    unsigned char onetime_private_key[32] = {0, };
    __bts_gen_private_key_from_seed(entropy, entropy_size, onetime_private_key);

    //  4、根据随机私钥和钱包密码公钥进行aes加密，并添加checksum。
    size_t test_output_size = __bts_aes256_encrypt_with_checksum_calc_outputsize(compressed_size);
    size_t final_output_size = 33 + test_output_size;
    output = malloc(final_output_size);
    if (!output){
        goto save_failed;
    }
    if (!__bts_aes256_encrypt_with_checksum(onetime_private_key, &password_pubkey, 0, 0, dstBuffer, compressed_size, &output[33])){
        goto save_failed;
    }
    free(dstBuffer);        //  释放内存
    dstBuffer = 0;
    
    //  5、生成 onetime publickey 附加到加密信息前面并返回。
    secp256k1_pubkey onetime_pubkey = {0, };
    if (!secp256k1_ec_pubkey_create(ctx_both, &onetime_pubkey, onetime_private_key)){
        goto save_failed;
    }
    //  append 33 pubkey
    __bts_gen_public_key_compressed(&onetime_pubkey, output);
    
    //  返回
    if (output_size){
        *output_size = final_output_size;
    }
    return output;
    
    //  失败处理
save_failed:
    if (dstBuffer){
        free(dstBuffer);
        dstBuffer = 0;
    }
    if (output){
        free(output);
        output = 0;
    }
    return 0;
}

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
unsigned char* __bts_load_wallet(const unsigned char* wallet_buffer, const size_t wallet_buffer_size,
                                 const unsigned char* password, const size_t password_len,
                                 size_t* final_output_size)
{
    assert(wallet_buffer);
    assert(wallet_buffer_size > 0);
    assert(password);
    
    //  获取上下文
    secp256k1_context* ctx_both = get_static_context();
    
    //  1、根据钱包密码创建私钥（32字节）
    unsigned char password_private_key[32] = {0, };
    __bts_gen_private_key_from_seed(password, password_len, password_private_key);
    
    //  2、从bin文件的前33字节压缩过的公钥字符串恢复公钥对象
    secp256k1_pubkey pubkey = {0, };
    int ret = secp256k1_ec_pubkey_parse(ctx_both, &pubkey, wallet_buffer, 33);
    if (!ret){
        return 0;
    }
    
    //  3、根据私钥和公钥生成 shared_secret，用于 aes 算法解密。
    unsigned char shared_secret_sha512[64] = {0,};
    if (!get_shared_secret(password_private_key, &pubkey, shared_secret_sha512)){
        return 0;
    }
    
    //  16进制编码 shared_secret_sha512
    unsigned char digest128[128 + 1] = {0, };
    hex_encode(shared_secret_sha512, sizeof(shared_secret_sha512), digest128);
    
    struct __aes256_context aes_ctx;
    //    gen_aes_context_from_seed(&aes_ctx, nonce + digest128, strlen(nonce+128));//TODO:nonce
    gen_aes_context_from_seed(&aes_ctx, digest128, 128);
    
    //  REMARK：aes-cbc解密后的大小不会超过原大小，因为加密时进行过填充，只能更大，不能更小。
    unsigned char output[wallet_buffer_size - 33];
    size_t output_size = sizeof(output);
    if (!aes256_decrypt(&aes_ctx, (const char*)&wallet_buffer[33], wallet_buffer_size-33, (char*)output, &output_size)){
        return 0;
    }
    
    //  解密后的缓冲区前4字节是后面所有数据的 checksum。
    const size_t checksum_size = 4;
    const unsigned char* compressed_buffer_ptr = &output[checksum_size];
    const size_t compressed_buffer_size = output_size - checksum_size;
    
    unsigned char digest32[32] = {0, };
    sha256(compressed_buffer_ptr, compressed_buffer_size, digest32);
    if (0 != memcmp(digest32, output, checksum_size))
    {
        //  TODO:checksum verify failed ~~,是否需要flurry统计;
        return 0;
    }
    
    //  LZMA解压缩：
    //  参考：https://svn.python.org/projects/external/xz-5.0.3/doc/lzma-file-format.txt
    //  Header (1 + 4 + 8)
    //    +------------+----+----+----+----+--+--+--+--+--+--+--+--+
    //    | Properties |  Dictionary Size  |   Uncompressed Size   |
    //    +------------+----+----+----+----+--+--+--+--+--+--+--+--+
    uint64_t uncompressed_size = 0;
    memcpy(&uncompressed_size, &compressed_buffer_ptr[LZMA_PROPS_SIZE], sizeof(uint64_t));
    unsigned char* uncompressed_buffer = malloc(uncompressed_size + 1);
    if (!uncompressed_buffer){
        return 0;
    }
    uncompressed_buffer[uncompressed_size] = 0;
    //  REMARK: 解压函数不太完善，这个 destLen 设置 buffer 的大小可能导致返回 SZ_ERROR_INPUT_EOF 错误，必须设置为 原始数据长度才可以。不能设置为 uncompressed_size + 1 !!
    size_t uncompressed_buffer_size = uncompressed_size;
    size_t compressed_size = compressed_buffer_size - LZMA_PROPS_SIZE - sizeof(uint64_t) ;
    
    int result = LzmaUncompress(uncompressed_buffer, &uncompressed_buffer_size,
                              &compressed_buffer_ptr[LZMA_PROPS_SIZE + sizeof(uint64_t)], &compressed_size,
                              compressed_buffer_ptr, LZMA_PROPS_SIZE);
    if (result != SZ_OK){
        //  TODO:uncompress failed...，是否需要统计。
        return 0;
    }
    
    //  返回
    if (final_output_size){
        *final_output_size = uncompressed_size;
    }
    return uncompressed_buffer;
}

/**
 *  (public) 签名
 */
bool __bts_sign_buffer(const unsigned char* sign_buffer, const size_t sign_buffer_size,
                       const unsigned char sign_private_key32[], unsigned char output_signature65[])
{
    //  获取上下文
    secp256k1_context* ctx_both = get_static_context();
    
    //  计算待签名buffer的sha256签名
    unsigned char digest32[32] = {0, };
    sha256(sign_buffer, sign_buffer_size, digest32);
    
    secp256k1_ecdsa_recoverable_signature sig = {0, };
    secp256k1_ecdsa_signature normal_sig = {0,};
    unsigned char output_der[128] = {0, };  //  REMARK：这个好像基本都只有70字节，网上有的参数是72。
    
    size_t output_der_len;
    int nonce = 0;
    int ret;
    
    //  循环计算签名，直到找到合适的 canonical 签名。
    while (1) {
        //  执行签名核心
        ret = secp256k1_ecdsa_sign_recoverable(ctx_both, &sig, digest32, sign_private_key32, NULL, &nonce);
        if (!ret){
            return false;
        }
        ++nonce;
        
        //  转换为普通签名
        (void)secp256k1_ecdsa_recoverable_signature_convert(ctx_both, &normal_sig, &sig);
        
        //  转换为der格式
        output_der_len = sizeof(output_der);
        ret = secp256k1_ecdsa_signature_serialize_der(ctx_both, output_der, &output_der_len, &normal_sig);
        if (!ret){
            return false;
        }
        
        //  判断是否是 canonical 签名
        unsigned char lenR = output_der[3];
        unsigned char lenS = output_der[5 + lenR];
        if (lenR == 32 && lenS == 32)
        {
            int recId = 0;
            (void)secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx_both, &output_signature65[1], &recId, &sig);
            recId += 4;     //  compressed
            recId += 27;    //  compact  //  24 or 27 :( forcing odd-y 2nd key candidate)
            
            //  存储在第一个字节。
            output_signature65[0] = (unsigned char)recId;
            break;
        }
    }
    
    return true;
}
