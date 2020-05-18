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

#include "libbase58.h"

#include "rmd160.h"

#include "WjCryptLib_Sha1.h"
#include "WjCryptLib_Sha256.h"
#include "WjCryptLib_Sha512.h"
#include "WjCryptLib_AesCbc.h"

#include "LzmaLib.h"

/*
 *  别名
 */
typedef secp256k1_context_t secp256k1_context;

/**
 *  临时缓冲区（不大于该缓冲区的临时buffer都可以使用）
 */
static unsigned char __bts_wallet_core_temp_buffer[2048 * 4];

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
    
    //  拷贝
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
 *  (public) 获取 shared_secret，用于 aes 加解密。    REMARK：public_key 会发生改变，如果有必要需要提前备份。
 */
bool __bts_get_shared_secret(const unsigned char private_key32[], secp256k1_pubkey_compressed* public_key, unsigned char output_shared_secret32_digest64[])
{
    secp256k1_context* ctx_both = get_static_context();
    
    //  3.1、用私钥调整公钥
    int ret = secp256k1_ec_pubkey_tweak_mul(ctx_both, public_key->data, sizeof(public_key->data), private_key32);
    if (!ret){
        return false;
    }
    
    //  3.3、获取shared_secret（即X字段）然后计算sha512摘要。不论是否压缩格式，x值都在1..32位置。
    assert(sizeof(public_key->data) == 33);
    sha512(&public_key->data[1], sizeof(public_key->data) - 1, output_shared_secret32_digest64);
    
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
 *  获取上下文（支持佩德森承诺和范围证明）
 */
static secp256k1_context* get_static_context()
{
    static secp256k1_context* ctx_both = 0;
    if (!ctx_both){
        ctx_both  = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY |
                                             SECP256K1_CONTEXT_SIGN |
                                             SECP256K1_CONTEXT_RANGEPROOF |
                                             SECP256K1_CONTEXT_COMMIT);
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

/*
 *  (public) AES256-CBC 模式 加密/解密。
 */
bool __bts_aes256cbc_encrypt(const digest_sha512* secret, const unsigned char* srcptr, const size_t srcsize, unsigned char* output)
{
    assert(secret);
    assert(srcptr);
    assert(output);
    
    struct __aes256_context aes_ctx;
    gen_aes_context(&aes_ctx, &secret->data[32], &secret->data[0]);
    
    size_t output_size = __bts_aes256_calc_output_size(srcsize);
    
    memcpy(output, srcptr, srcsize);
    
    size_t padding_value = output_size - srcsize;
    size_t padding_size = output_size - srcsize;
    memset(&output[srcsize], padding_value, padding_size);
    
    if (!aes256_encrypt(&aes_ctx, (const char*)output, (char*)output, output_size)){
        return false;
    }
    
    return true;
}

bool __bts_aes256cbc_decrypt(const digest_sha512* secret, const unsigned char* srcptr, const size_t srcsize,
                             unsigned char* output, size_t* output_size)
{
    assert(secret);
    assert(srcptr);
    assert(output);
    assert(output_size);
    
    struct __aes256_context aes_ctx;
    gen_aes_context(&aes_ctx, &secret->data[32], &secret->data[0]);
    
    if (!aes256_decrypt(&aes_ctx, (const char*)srcptr, srcsize, (char*)output, output_size)){
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

/*
 *  (public) 主要方法，用于memo、钱包等解密。
 *  解密失败返回 0，解密成功返回指向数据缓冲区的指针。
 */
unsigned char* __bts_aes256_decrypt_with_checksum(const unsigned char private_key32[], const secp256k1_pubkey_compressed* public_key,
                                                  const char* nonce, const size_t nonce_size,
                                                  const unsigned char* message, const size_t message_size,
                                                  unsigned char* output, size_t* final_output_size)
{
    assert(final_output_size);
    
    //  1、生成aes上下文
    secp256k1_pubkey_compressed pubkey = {0, };
    memcpy(&pubkey, public_key, sizeof(pubkey));
    
    unsigned char shared_secret_sha512[64] = {0,};
    if (!__bts_get_shared_secret(private_key32, &pubkey, shared_secret_sha512)){
        return 0;
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
    
    //  2、解密 REMARK：解密后的数据大小应该小于等于加密数据长度的，故output缓冲区设置为加密数据长度即可。
    size_t output_size = *final_output_size;
    if (!aes256_decrypt(&aes_ctx, (const char*)message, message_size, (char*)output, &output_size)) {
        return 0;
    }
    //  解密失败(小于checksum长度)
    const size_t checksum_size = 4;
    if (output_size < checksum_size) {
        return 0;
    }
    
    //  3、校验
    unsigned char new_digest32[32] = {0, };
    sha256(&output[checksum_size], output_size - checksum_size, new_digest32);
    if (0 != memcmp(new_digest32, output, checksum_size)) {
        return 0;
    }
    
    //  4、返回
    *final_output_size  = output_size - checksum_size;
    return &output[checksum_size];
}

/**
 *  (public) 主要方法，用于memo、钱包等加密。
 */
bool __bts_aes256_encrypt_with_checksum(const unsigned char private_key32[], const secp256k1_pubkey_compressed* public_key,
                                        const char* nonce, const size_t nonce_size,
                                        const unsigned char* message, const size_t message_size, unsigned char* output)
{
    //  1、生成aes上下文
    secp256k1_pubkey_compressed pubkey = {0, };
    memcpy(&pubkey, public_key, sizeof(pubkey));
    
    unsigned char shared_secret_sha512[64] = {0,};
    if (!__bts_get_shared_secret(private_key32, &pubkey, shared_secret_sha512)){
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
 *  (public) 根据种子字符串生成私钥信息。会自动校验私钥有效性。
 */
void __bts_gen_private_key_from_seed(const unsigned char* seed, const size_t seed_size, unsigned char private_key32[])
{
    assert(private_key32);
    //  根据 seed 计算摘要生成 private key。
    sha256(seed, seed_size, private_key32);
    //  如果是有效的私钥则直接返回
    if (secp256k1_ec_seckey_verify(get_static_context(), private_key32)) {
        return;
    }
    //  无效的私钥循环重新生成。
    //  REMARK：私钥有效范围。[1, secp256k1 curve order)。REMARK：大部分 lib 范围是 [1, secp256k1 curve order] 的闭区间，c库范围为开区间。
    while (true) {
        sha256(private_key32, 32, private_key32);
        if (secp256k1_ec_seckey_verify(get_static_context(), private_key32)) {
            break;
        }
    }
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
void __bts_public_key_to_address(const secp256k1_pubkey_compressed* public_key,
                                 unsigned char address_output[], size_t* address_output_size,
                                 const char* address_prefix, const size_t address_prefix_size)
{
    assert(address_prefix);
    assert(address_prefix_size > 0);
    
    unsigned char output[33 + 4] = {0, };
    
    //  生成压缩格式公钥
    memcpy(output, public_key->data, sizeof(public_key->data));
    
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

/*
 *  (public) 验证私钥是否有效，私钥有效范围。[1, secp256k1 curve order)。REMARK：大部分 lib 范围是 [1, secp256k1 curve order] 的闭区间，c库范围为开区间。
 */
bool __bts_verify_private_key(const secp256k1_prikey* prikey)
{
    assert(prikey);
    if (!secp256k1_ec_seckey_verify(get_static_context(), prikey->data)) {
        return false;
    }
    return true;
}

/*
 *  (public) 根据私钥创建公钥。
 */
bool __bts_gen_public_key(const secp256k1_prikey* prikey, secp256k1_pubkey_compressed* output_pubkey)
{
    assert(prikey);
    assert(output_pubkey);
    int pubkey_len = sizeof(output_pubkey->data);
    if (!secp256k1_ec_pubkey_create(get_static_context(), output_pubkey->data, &pubkey_len, prikey->data, 1)) {
        return false;
    }
    return true;
}

/**
 *  从 32 字节原始私钥生成 BTS 地址字符串
 */
bool __bts_gen_address_from_private_key32(const secp256k1_prikey* prikey,
                                          unsigned char address_output[], size_t* address_output_size,
                                          const char* address_prefix, const size_t address_prefix_size)
{
    secp256k1_pubkey_compressed pubkey = {0, };
    
    int pubkey_len = sizeof(pubkey.data);
    if (!secp256k1_ec_pubkey_create(get_static_context(), pubkey.data, &pubkey_len, prikey->data, 1)) {
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
                                          const size_t address_prefix_size, secp256k1_pubkey_compressed* output_public)
{
    assert(address_prefix_size > 0);
    if (address_size <= address_prefix_size) {
        return false;
    }
    assert(address_prefix_size < address_size);
    
    //  BTS地址移除前缀之后进行base58解码
    unsigned char temp_buffer[53] = {0,};   //  REMARK:这个缓冲区大小能够容纳地址b58解码后的数据即可，基本大小只有37字节，53是地址长度。
    
    size_t output_size = sizeof(temp_buffer);
    const unsigned char* pOutput = base58_decode(&address[address_prefix_size], address_size-address_prefix_size, temp_buffer, &output_size);
    if (!pOutput || output_size <= 4){
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
    assert(sizeof(output_public->data) == 33);
    memcpy(output_public->data, pOutput, sizeof(output_public->data));
    
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

bool __bts_pubkey_tweak_add(secp256k1_pubkey_compressed* pubkey, const unsigned char tweak[])
{
    int ret = secp256k1_ec_pubkey_tweak_add(get_static_context(), pubkey->data, sizeof(pubkey->data), tweak);
    if (!ret){
        return false;
    }
    
    return true;
}

/*
 *  (public) Base58编码。REMARK：请确保 output 输出缓冲区的大小至少为原输入流字节数的 1.38 倍。可建议区 2.0 作为缓冲区。
 */
void __bts_base58_encode(const unsigned char* data_ptr, const size_t data_size, unsigned char* output, size_t* output_size)
{
    assert(data_ptr);
    assert(data_size);
    assert(output);
    assert(output_size);
    //  REMARK：base58编码后的大小在1.38倍附近。
    base58_encode(data_ptr, data_size, output, output_size);
}

/*
 *  (public) Base58解码。REMARK：解码后到数据长度小于base58字符串长度。
 *  返回值 - 解码成功指向解码后的数据流指针，否则返回 NULL 指针。
 */
unsigned char* __bts_base58_decode(const unsigned char* b58str_ptr, const size_t b58str_size, unsigned char* output, size_t* output_size)
{
    assert(b58str_ptr);
    assert(b58str_size);
    assert(output);
    assert(output_size);
    
    return base58_decode(b58str_ptr, b58str_size, output, output_size);
}

/**
 *  解码商人协议发票数据。
 */
unsigned char* __bts_merchant_invoice_decode(const unsigned char* b58str_ptr, const size_t b58str_size, size_t* output_size)
{
    //  REMARK：base58解码后的大小在1.38倍附近。
    unsigned char lzma_buffer[b58str_size * 2];
    size_t lzma_output_size = sizeof(lzma_buffer);
    const unsigned char* pLzmaBuffer = base58_decode(b58str_ptr, b58str_size, lzma_buffer, &lzma_output_size);
    if (!pLzmaBuffer){
        return 0;
    }
    
    uint64_t uncompressed_size = 0;
    memcpy(&uncompressed_size, &pLzmaBuffer[LZMA_PROPS_SIZE], sizeof(uint64_t));
    if (UINT64_MAX != uncompressed_size && uncompressed_size > sizeof(__bts_wallet_core_temp_buffer)) {
        return 0;
    }
    size_t uncompressed_buffer_size = sizeof(__bts_wallet_core_temp_buffer);
    size_t compressed_size = lzma_output_size - LZMA_PROPS_SIZE - sizeof(uint64_t) ;
    
    int result = LzmaUncompress(__bts_wallet_core_temp_buffer, &uncompressed_buffer_size,
                                &pLzmaBuffer[LZMA_PROPS_SIZE + sizeof(uint64_t)], &compressed_size,
                                pLzmaBuffer, LZMA_PROPS_SIZE);
    if (result != SZ_OK){
        //  TODO:uncompress failed...，是否需要统计。
        return 0;
    }
    if (output_size) {
        *output_size = uncompressed_buffer_size;
    }
    
    __bts_wallet_core_temp_buffer[uncompressed_buffer_size] = 0;
    return __bts_wallet_core_temp_buffer;
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
    //  Uncompressed Size is stored as unsigned 64-bit little endian integer.
    //  A special value of 0xFFFF_FFFF_FFFF_FFFF indicates that Uncompressed Size is unknown
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
    secp256k1_pubkey_compressed password_pubkey = {0, };
    int password_pubkey_len = sizeof(password_pubkey.data);
    if (!secp256k1_ec_pubkey_create(ctx_both, password_pubkey.data, &password_pubkey_len, password_private_key, 1)) {
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
    secp256k1_pubkey_compressed onetime_pubkey = {0, };
    int onetime_pubkey_len = sizeof(onetime_pubkey.data);
    if (!secp256k1_ec_pubkey_create(ctx_both, onetime_pubkey.data, &onetime_pubkey_len, onetime_private_key, 1)) {
        goto save_failed;
    }
    
    //  append 33 pubkey
    memcpy(output, onetime_pubkey.data, sizeof(onetime_pubkey.data));
    
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
    
    //  1、根据钱包密码创建私钥（32字节）
    unsigned char password_private_key[32] = {0, };
    __bts_gen_private_key_from_seed(password, password_len, password_private_key);
    
    //  2、从bin文件的前33字节压缩过的公钥字符串恢复公钥对象
    secp256k1_pubkey_compressed pubkey = {0, };
    assert(sizeof(pubkey.data) == 33);
    if (wallet_buffer_size < sizeof(pubkey.data)) {
        return 0;
    }
    memcpy(pubkey.data, wallet_buffer, sizeof(pubkey.data));
    
    //  3、根据私钥和公钥生成 shared_secret，用于 aes 算法解密。
    unsigned char shared_secret_sha512[64] = {0,};
    if (!__bts_get_shared_secret(password_private_key, &pubkey, shared_secret_sha512)){
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
    //  Uncompressed Size is stored as unsigned 64-bit little endian integer.
    //  A special value of 0xFFFF_FFFF_FFFF_FFFF indicates that Uncompressed Size is unknown
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

static int extended_nonce_function( unsigned char *nonce32, const unsigned char *msg32,
                                   const unsigned char *key32, unsigned int attempt,
                                   const void *data ) {
    unsigned int* extra = (unsigned int*) data;
    (*extra)++;
    return secp256k1_nonce_function_default( nonce32, msg32, key32, *extra, 0 );
};

static bool is_canonical( const secp256k1_compact_signature* sign ) {
    const unsigned char* c = sign->data;
    return !(c[1] & 0x80)
    && !(c[1] == 0 && !(c[2] & 0x80))
    && !(c[33] & 0x80)
    && !(c[33] == 0 && !(c[34] & 0x80));
}

/**
 *  (public) 签名
 */
bool __bts_sign_buffer(const unsigned char* sign_buffer, const size_t sign_buffer_size,
                       const unsigned char sign_private_key32[], secp256k1_compact_signature* output_signature)
{
    assert(output_signature);
    
    //  获取上下文
    secp256k1_context* ctx_both = get_static_context();
    
    //  计算待签名buffer的sha256签名
    unsigned char digest32[32] = {0, };
    sha256(sign_buffer, sign_buffer_size, digest32);
    
    bool require_canonical = true;
    int recid;
    unsigned int counter = 0;
    //  循环计算签名，直到找到合适的 canonical 签名。
    do
    {
        if (!secp256k1_ecdsa_sign_compact(ctx_both, digest32,
                                          &output_signature->data[1],
                                          sign_private_key32,
                                          extended_nonce_function,
                                          &counter, &recid)) {
            return false;
        }
    } while(require_canonical && !is_canonical(output_signature));
    output_signature->data[0] = 27 + 4 + recid;
    
    return true;
}

/**
 *  (public) 根据盲化因子和数据生成佩德森承诺。
 */
bool __bts_gen_pedersen_commit(commitment_type* commitment, blind_factor_type* blind_factor, const uint64_t value)
{
    assert(commitment);
    assert(blind_factor);
    assert(value > 0);
    
    if (!secp256k1_pedersen_commit(get_static_context(), commitment->data, blind_factor->data, value)) {
        return false;
    }
    
    return true;
}

bool __bts_gen_pedersen_blind_sum(const unsigned char * const *blinds_in, const size_t blinds_in_size, uint32_t non_neg,
                                  blind_factor_type* result)
{
    assert(result);
    assert(blinds_in);

    if (!secp256k1_pedersen_blind_sum(get_static_context(), result->data, blinds_in, (int)blinds_in_size, non_neg)) {
        return false;
    }
    return true;
}

/*
 *  (public) 生成范围证明
 */
bool __bts_gen_range_proof_sign(uint64_t min_value, const commitment_type* commit,
                                const blind_factor_type* commit_blind,
                                const blind_factor_type* nonce,
                                int8_t base10_exp, uint8_t min_bits, uint64_t actual_value,
                                unsigned char* output_proof, int* proof_len) {
    
    assert(output_proof);
    assert(proof_len && *proof_len >= 5134);
    
    if (secp256k1_rangeproof_sign(get_static_context(), output_proof, proof_len, min_value, commit->data, commit_blind->data, nonce->data,
                                  base10_exp, min_bits, actual_value)) {
        return true;
    }
    return false;
}

