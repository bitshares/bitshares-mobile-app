//
//  android_jni_entry.c
//  oplayer
//
//  Created by Aonichan on 16/1/15.
//
//
#include "android_jni_entry.h"
#include "bts_wallet_core.h"
#include <assert.h>

#pragma mark- for java native method

/**
 *  输出日志
 */
void __fowallet_printf(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    __android_log_vprint(ANDROID_LOG_DEBUG, "fowallet", format, ap);
    va_end(ap);
}

/**
 *  计算各种 hash 摘要
 */
JNIEXPORT jbyteArray
java_jni_entry_rmd160(JNIEnv* env, jobject self, 
    jbyteArray buffer)
{
    //  检查参数
    assert(buffer);
    if (!buffer){
        return NULL;
    }

    //  获取数据
    jbyte* buffer_ptr = (*env)->GetByteArrayElements(env, buffer, 0);
    jsize buffer_size = (*env)->GetArrayLength(env, buffer);

    //  调用API
    unsigned char digest20[20];
    rmd160((const unsigned char*)buffer_ptr, (const size_t)buffer_size, digest20);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, buffer, buffer_ptr, JNI_ABORT);

    //  返回
    jbyteArray retv = (*env)->NewByteArray(env, sizeof(digest20));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(digest20), (const jbyte*)digest20);
    return retv;
}

JNIEXPORT jbyteArray
java_jni_entry_sha1(JNIEnv* env, jobject self, 
    jbyteArray buffer)
{
    //  检查参数
    assert(buffer);
    if (!buffer){
        return NULL;
    }

    //  获取数据
    jbyte* buffer_ptr = (*env)->GetByteArrayElements(env, buffer, 0);
    jsize buffer_size = (*env)->GetArrayLength(env, buffer);

    //  调用API
    unsigned char digest20[20];
    sha1((const unsigned char*)buffer_ptr, (const size_t)buffer_size, digest20);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, buffer, buffer_ptr, JNI_ABORT);

    //  返回
    jbyteArray retv = (*env)->NewByteArray(env, sizeof(digest20));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(digest20), (const jbyte*)digest20);
    return retv;
}

JNIEXPORT jbyteArray
java_jni_entry_sha256(JNIEnv* env, jobject self, 
    jbyteArray buffer)
{
    //  检查参数
    assert(buffer);
    if (!buffer){
        return NULL;
    }

    //  获取数据
    jbyte* buffer_ptr = (*env)->GetByteArrayElements(env, buffer, 0);
    jsize buffer_size = (*env)->GetArrayLength(env, buffer);

    //  调用API
    unsigned char digest32[32];
    sha256((const unsigned char*)buffer_ptr, (const size_t)buffer_size, digest32);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, buffer, buffer_ptr, JNI_ABORT);

    //  返回
    jbyteArray retv = (*env)->NewByteArray(env, sizeof(digest32));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(digest32), (const jbyte*)digest32);
    return retv;
}

JNIEXPORT jbyteArray
java_jni_entry_sha512(JNIEnv* env, jobject self, 
    jbyteArray buffer)
{
    //  检查参数
    assert(buffer);
    if (!buffer){
        return NULL;
    }

    //  获取数据
    jbyte* buffer_ptr = (*env)->GetByteArrayElements(env, buffer, 0);
    jsize buffer_size = (*env)->GetArrayLength(env, buffer);

    //  调用API
    unsigned char digest64[64];
    sha512((const unsigned char*)buffer_ptr, (const size_t)buffer_size, digest64);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, buffer, buffer_ptr, JNI_ABORT);

    //  返回
    jbyteArray retv = (*env)->NewByteArray(env, sizeof(digest64));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(digest64), (const jbyte*)digest64);
    return retv;
}

/**
 *  (public) 获取 shared_secret，用于 aes 加解密。
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_get_shared_secret(JNIEnv* env, jobject self, 
    jbyteArray private_key, jbyteArray public_key)
{
    //  检查参数
    assert(private_key);
    assert(public_key);
    if (!private_key || !public_key){
        return NULL;
    }

    //  获取数据
    jbyte* private_key_ptr = (*env)->GetByteArrayElements(env, private_key, 0);
    jsize private_key_size = (*env)->GetArrayLength(env, private_key);

    jbyte* public_key_ptr = (*env)->GetByteArrayElements(env, public_key, 0);
    jsize public_key_size = (*env)->GetArrayLength(env, public_key);

    //  调用API
    secp256k1_pubkey_compressed pk = {0, };
    assert(public_key_size == sizeof(pk.data));
    memcpy(pk.data, public_key_ptr, sizeof(pk.data));

    unsigned char digest64[64];
    bool result = __bts_get_shared_secret((const unsigned char*)private_key_ptr, &pk, digest64);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, private_key, private_key_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, public_key, public_key_ptr, JNI_ABORT);

    //  返回
    if (result) {
        jbyteArray retv = (*env)->NewByteArray(env, sizeof(digest64));
        (*env)->SetByteArrayRegion(env, retv, 0, sizeof(digest64), (const jbyte*)digest64);
        return retv;
    } else {
        return NULL;
    }
}

/**
 *  Aes256 加密，返回16进制编码后内容。
 *  REMARK：hexoutput 的长度应该为 aes256_calc_output_size(srcsize) 的2倍。
 */    
JNIEXPORT jbyteArray
java_jni_entry_bts_aes256_encrypt_to_hex(JNIEnv* env, jobject self,
    jbyteArray aes_seed, jbyteArray srcptr)
{
    //  检查参数
    if (!aes_seed || !srcptr){
        return NULL;
    }

    //  获取数据
    jbyte* aes_seed_ptr = (*env)->GetByteArrayElements(env, aes_seed, 0);
    jsize aes_seed_size = (*env)->GetArrayLength(env, aes_seed);
    jbyte* srcptr_ptr = (*env)->GetByteArrayElements(env, srcptr, 0);
    jsize srcptr_size = (*env)->GetArrayLength(env, srcptr);

    //  调用API
    size_t hexoutput_size = __bts_aes256_calc_output_size(srcptr_size) * 2;
    unsigned char* hexoutput = (unsigned char*)malloc(hexoutput_size + 1);
    bool result = false;
    if (hexoutput){
        result = __bts_aes256_encrypt_to_hex((const unsigned char*)aes_seed_ptr, (const size_t)aes_seed_size, (const unsigned char*)srcptr_ptr, (const size_t)srcptr_size, hexoutput);
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, aes_seed, aes_seed_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, srcptr, srcptr_ptr, JNI_ABORT);

    //  返回

    //  分配内存失败
    if (!hexoutput){
        return NULL;
    }
    //  加密失败
    if (!result){
        free(hexoutput);
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, hexoutput_size);
    (*env)->SetByteArrayRegion(env, retv, 0, hexoutput_size, (const jbyte*)hexoutput);

    //  释放内存
    free(hexoutput);
    hexoutput = 0;

    return retv;
}

/**
 *  Aes256 解密。
 *  output 的长度应该 不会超过源16进制编码后长度的一半。
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_aes256_decrypt_from_hex(JNIEnv* env, jobject self,
    jbyteArray aes_seed, jbyteArray hex_src)
{
    //  检查参数
    if (!aes_seed || !hex_src){
        return NULL;
    }

    //  获取数据
    jbyte* aes_seed_ptr = (*env)->GetByteArrayElements(env, aes_seed, 0);
    jsize aes_seed_size = (*env)->GetArrayLength(env, aes_seed);
    jbyte* hex_src_ptr = (*env)->GetByteArrayElements(env, hex_src, 0);
    jsize hex_src_size = (*env)->GetArrayLength(env, hex_src);
    assert((hex_src_size % 2) == 0);

    //  调用API
    size_t output_size = hex_src_size / 2;
    unsigned char* output = (unsigned char*)malloc(output_size);
    bool result = false;
    if (output){
        result = __bts_aes256_decrypt_from_hex((const unsigned char*)aes_seed_ptr, (const size_t)aes_seed_size, (const unsigned char*)hex_src_ptr, (const size_t)hex_src_size, output, &output_size);
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, aes_seed, aes_seed_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, hex_src, hex_src_ptr, JNI_ABORT);

    //  返回

    //  分配内存失败
    if (!output){
        return NULL;
    }
    //  解密失败
    if (!result){
        free(output);
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)output);

    //  释放内存
    free(output);
    output = 0;

    return retv;
}

/*
 *  (public) AES256-CBC 模式 加密/解密。
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_aes256cbc_encrypt(JNIEnv* env, jobject self,
    jbyteArray secret, jbyteArray src)
{
    //  检查参数
    if (!secret || !src){
        return NULL;
    }

    //  获取数据
    jbyte* secret_ptr = (*env)->GetByteArrayElements(env, secret, 0);
    jsize secret_size = (*env)->GetArrayLength(env, secret);
    jbyte* src_ptr = (*env)->GetByteArrayElements(env, src, 0);
    jsize src_size = (*env)->GetArrayLength(env, src);

    //  调用API
    size_t output_size = __bts_aes256_calc_output_size(src_size);

    unsigned char* output = (unsigned char*)malloc(output_size);
    bool result = false;
    if (output){
        digest_sha512 sha512_s = {0, };
        assert(sizeof(sha512_s.data) == secret_size);
        memcpy(sha512_s.data, secret_ptr, sizeof(sha512_s.data));
        result = __bts_aes256cbc_encrypt(&sha512_s, (const unsigned char*)src_ptr, (const size_t)src_size, output);
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, secret, secret_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, src, src_ptr, JNI_ABORT);

    //  返回

    //  分配内存失败
    if (!output){
        return NULL;
    }
    //  加密失败
    if (!result){
        free(output);
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)output);

    //  释放内存
    free(output);
    output = 0;

    return retv;
}

JNIEXPORT jbyteArray
java_jni_entry_bts_aes256cbc_decrypt(JNIEnv* env, jobject self,
    jbyteArray secret, jbyteArray src)
{
    //  检查参数
    if (!secret || !src){
        return NULL;
    }

    //  获取数据
    jbyte* secret_ptr = (*env)->GetByteArrayElements(env, secret, 0);
    jsize secret_size = (*env)->GetArrayLength(env, secret);
    jbyte* src_ptr = (*env)->GetByteArrayElements(env, src, 0);
    jsize src_size = (*env)->GetArrayLength(env, src);

    //  调用API
    size_t output_size = src_size;

    unsigned char* output = (unsigned char*)malloc(output_size);
    bool result = false;
    if (output){
        digest_sha512 sha512_s = {0, };
        assert(sizeof(sha512_s.data) == secret_size);
        memcpy(sha512_s.data, secret_ptr, sizeof(sha512_s.data));
        result = __bts_aes256cbc_decrypt(&sha512_s, (const unsigned char*)src_ptr, (const size_t)src_size, output, &output_size);
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, secret, secret_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, src, src_ptr, JNI_ABORT);

    //  返回

    //  分配内存失败
    if (!output){
        return NULL;
    }
    //  解密失败
    if (!result){
        free(output);
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)output);

    //  释放内存
    free(output);
    output = 0;

    return retv;
}

/**
 *  Aes核心解密（主要用于解密memo等）
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_aes256_decrypt_with_checksum(JNIEnv* env, jobject self,
    jbyteArray private_key32, jbyteArray public_key, jbyteArray nonce, jbyteArray message)
{
    //  检查参数
    if (!private_key32 || !public_key || !nonce || !message){
        return NULL;
    }

    //  获取数据
    jbyte* private_key32_ptr = (*env)->GetByteArrayElements(env, private_key32, 0);
    jsize private_key32_size = (*env)->GetArrayLength(env, private_key32);
    jbyte* public_key_ptr = (*env)->GetByteArrayElements(env, public_key, 0);
    jsize public_key_size = (*env)->GetArrayLength(env, public_key);
    jbyte* nonce_ptr = (*env)->GetByteArrayElements(env, nonce, 0);
    jsize nonce_size = (*env)->GetArrayLength(env, nonce);
    jbyte* message_ptr = (*env)->GetByteArrayElements(env, message, 0);
    jsize message_size = (*env)->GetArrayLength(env, message);

    //  调用API
    size_t output_size = (size_t)message_size;
    unsigned char* output = (unsigned char*)malloc(output_size);
    unsigned char* plain_ptr = 0;
    if (output){
        secp256k1_pubkey_compressed public_key_s = {0, };
        assert(public_key_size == sizeof(public_key_s.data));
        memcpy(&public_key_s.data, public_key_ptr, sizeof(public_key_s.data));
        plain_ptr = __bts_aes256_decrypt_with_checksum((const unsigned char*)private_key32_ptr, &public_key_s, (const char*)nonce_ptr, (const size_t)nonce_size, (const unsigned char*)message_ptr, (const size_t)message_size, output, &output_size);
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, private_key32, private_key32_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, public_key, public_key_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, nonce, nonce_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, message, message_ptr, JNI_ABORT);

    //  返回

    //  分配内存失败
    if (!output){
        return NULL;
    }

    //  解密失败
    if (!plain_ptr || !output_size){
        free(output);
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)plain_ptr);

    //  释放内存
    free(output);
    output = 0;

    return retv;
}

/**
 *  Aes核心加密（主要用于加密钱包、memo等）
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_aes256_encrypt_with_checksum(JNIEnv* env, jobject self,
    jbyteArray private_key32, jbyteArray public_key, jbyteArray nonce, jbyteArray message)
{
    //  检查参数
    if (!private_key32 || !public_key || !nonce || !message){
        return NULL;
    }

    //  获取数据
    jbyte* private_key32_ptr = (*env)->GetByteArrayElements(env, private_key32, 0);
    jsize private_key32_size = (*env)->GetArrayLength(env, private_key32);
    jbyte* public_key_ptr = (*env)->GetByteArrayElements(env, public_key, 0);
    jsize public_key_size = (*env)->GetArrayLength(env, public_key);
    jbyte* nonce_ptr = (*env)->GetByteArrayElements(env, nonce, 0);
    jsize nonce_size = (*env)->GetArrayLength(env, nonce);
    jbyte* message_ptr = (*env)->GetByteArrayElements(env, message, 0);
    jsize message_size = (*env)->GetArrayLength(env, message);

    //  调用API
    size_t output_size = __bts_aes256_encrypt_with_checksum_calc_outputsize((const size_t)message_size);
    unsigned char* output = (unsigned char*)malloc(output_size);
    bool result = false;
    if (output){
        secp256k1_pubkey_compressed public_key_s = {0, };
        assert(public_key_size == sizeof(public_key_s.data));
        memcpy(&public_key_s.data, public_key_ptr, sizeof(public_key_s.data));
        result = __bts_aes256_encrypt_with_checksum((const unsigned char*)private_key32_ptr, &public_key_s, (const char*)nonce_ptr, (const size_t)nonce_size, (const unsigned char*)message_ptr, (const size_t)message_size, output);
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, private_key32, private_key32_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, public_key, public_key_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, nonce, nonce_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, message, message_ptr, JNI_ABORT);

    //  返回

    //  分配内存失败
    if (!output){
        return NULL;
    }
    //  加密失败
    if (!result){
        free(output);
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)output);

    //  释放内存
    free(output);
    output = 0;

    return retv;
}

/**
 *  从seed种子初始化32字节私钥数组
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_gen_private_key_from_seed(JNIEnv* env, jobject self, 
    jbyteArray seed)
{
    //  检查参数
    if (!seed){
        return NULL;
    }

    //  获取数据
    jbyte* seed_ptr = (*env)->GetByteArrayElements(env, seed, 0);
    jsize seed_size = (*env)->GetArrayLength(env, seed);

    //  调用API
    unsigned char private_key[32] = {0, };
    __bts_gen_private_key_from_seed((const unsigned char*)seed_ptr, seed_size, private_key);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, seed, seed_ptr, JNI_ABORT);

    //  返回
    jbyteArray retv = (*env)->NewByteArray(env, sizeof(private_key));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(private_key), (const jbyte*)private_key);
    return retv;
}

/**
 *  格式化私钥为WIF格式
 */
JNIEXPORT jstring
java_jni_entry_bts_private_key_to_wif(JNIEnv* env, jobject self,
    jbyteArray private_key32)
{
    //  检查参数
    if (!private_key32){
        return NULL;
    }

    //  获取数据
    jbyte* private_key32_ptr = (*env)->GetByteArrayElements(env, private_key32, 0);
    jsize private_key32_size = (*env)->GetArrayLength(env, private_key32);
    assert(private_key32_size == 32);

    //  调用API
    unsigned char output[51+10] = {0, };
    size_t output_size = sizeof(output);
    __bts_private_key_to_wif((const unsigned char*)private_key32_ptr, output, &output_size);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, private_key32, private_key32_ptr, JNI_ABORT);

    //  返回
    output[output_size] = 0;
    jstring retv = (*env)->NewStringUTF(env, (const char*)output);
    return retv;
}

/**
 *  从公钥结构生成 BTS 地址字符串
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_public_key_to_address(JNIEnv* env, jobject self,
    jbyteArray public_key, jbyteArray address_prefix)
{
    //  检查参数
    if (!public_key || !address_prefix){
        return NULL;
    }

    //  获取数据
    jbyte* public_key_ptr = (*env)->GetByteArrayElements(env, public_key, 0);
    jsize public_key_size = (*env)->GetArrayLength(env, public_key);
    jbyte* address_prefix_ptr = (*env)->GetByteArrayElements(env, address_prefix, 0);
    jsize address_prefix_size = (*env)->GetArrayLength(env, address_prefix);

    //  调用API
    unsigned char output[51+10] = {0, };
    size_t output_size = sizeof(output);
    secp256k1_pubkey_compressed public_key_s = {0, };
    assert(public_key_size == sizeof(public_key_s.data));
    memcpy(&public_key_s.data, public_key_ptr, sizeof(public_key_s.data));
    __bts_public_key_to_address(&public_key_s, output, &output_size, (const char*)address_prefix_ptr, (const size_t)address_prefix_size);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, public_key, public_key_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, address_prefix, address_prefix_ptr, JNI_ABORT);

    //  返回
    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)output);

    return retv;
}

/**
 *  (public) 验证私钥是否有效，私钥有效范围。[1, secp256k1 curve order)。REMARK：大部分 lib 范围是 [1, secp256k1 curve order] 的闭区间，c库范围为开区间。
 */
JNIEXPORT jboolean
java_jni_entry_bts_verify_private_key(JNIEnv* env, jobject self,
    jbyteArray private_key)
{
    //  检查参数
    if (!private_key){
        return JNI_FALSE;
    }

    //  获取数据
    jbyte* private_key_ptr = (*env)->GetByteArrayElements(env, private_key, 0);
    jsize private_key_size = (*env)->GetArrayLength(env, private_key);

    //  调用API
    secp256k1_prikey pri_key_s = {0, };
    assert(sizeof(pri_key_s.data) == private_key_size);
    memcpy(pri_key_s.data, private_key_ptr, sizeof(pri_key_s.data));

    bool result = __bts_verify_private_key(&pri_key_s);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, private_key, private_key_ptr, JNI_ABORT);

    //  返回
    if (result) {
        return JNI_TRUE;
    } else {
        return JNI_FALSE;
    }
}

/**
 *  根据私钥创建公钥。
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_gen_public_key(JNIEnv* env, jobject self,
    jbyteArray private_key)
{
    //  检查参数
    if (!private_key){
        return NULL;
    }

    //  获取数据
    jbyte* private_key_ptr = (*env)->GetByteArrayElements(env, private_key, 0);
    jsize private_key_size = (*env)->GetArrayLength(env, private_key);

    //  调用API
    secp256k1_prikey pri_key_s = {0, };
    assert(sizeof(pri_key_s.data) == private_key_size);
    memcpy(pri_key_s.data, private_key_ptr, sizeof(pri_key_s.data));

    secp256k1_pubkey_compressed pub_key_s = {0, };
    bool result = __bts_gen_public_key(&pri_key_s, &pub_key_s);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, private_key, private_key_ptr, JNI_ABORT);

    //  返回
    if (result) {
        jbyteArray retv = (*env)->NewByteArray(env, sizeof(pub_key_s.data));
        (*env)->SetByteArrayRegion(env, retv, 0, sizeof(pub_key_s.data), (const jbyte*)pub_key_s.data);
        return retv;
    } else {
        return NULL;
    }
}

/**
 *  从 32 字节原始私钥生成 BTS 地址字符串
 */    
JNIEXPORT jbyteArray
java_jni_entry_bts_gen_address_from_private_key32(JNIEnv* env, jobject self,
    jbyteArray private_key32, jbyteArray address_prefix)
{
    //  检查参数
    if (!private_key32 || !address_prefix){
        return NULL;
    }

    //  获取数据
    jbyte* private_key32_ptr = (*env)->GetByteArrayElements(env, private_key32, 0);
    jsize private_key32_size = (*env)->GetArrayLength(env, private_key32);
    jbyte* address_prefix_ptr = (*env)->GetByteArrayElements(env, address_prefix, 0);
    jsize address_prefix_size = (*env)->GetArrayLength(env, address_prefix);
    // assert(private_key32_size == 32);

    //  调用API
    unsigned char output[51+10] = {0, };
    size_t output_size = sizeof(output);

    secp256k1_prikey pri_key_s = {0, };
    assert(sizeof(pri_key_s.data) == private_key32_size);
    memcpy(pri_key_s.data, private_key32_ptr, sizeof(pri_key_s.data));
    bool result = __bts_gen_address_from_private_key32(&pri_key_s, output, &output_size, (const char*)address_prefix_ptr, (const size_t)address_prefix_size);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, private_key32, private_key32_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, address_prefix, address_prefix_ptr, JNI_ABORT);

    //  返回
    if (!result){
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)output);

    return retv;
}

/**
 *  从 51 字节WIF格式的私钥)获取 32 字节原始私钥。
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_gen_private_key_from_wif_privatekey(JNIEnv* env, jobject self,
    jbyteArray wif_privatekey)
{
    //  检查参数
    if (!wif_privatekey){
        return NULL;
    }

    //  获取数据
    jbyte* wif_privatekey_ptr = (*env)->GetByteArrayElements(env, wif_privatekey, 0);
    jsize wif_privatekey_size = (*env)->GetArrayLength(env, wif_privatekey);

    //  调用API
    unsigned char private_key32_array[32] = {0,};
    bool result = __bts_gen_private_key_from_wif_privatekey((const unsigned char*)wif_privatekey_ptr, (const size_t)wif_privatekey_size, private_key32_array);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, wif_privatekey, wif_privatekey_ptr, JNI_ABORT);

    //  返回
    if (!result){
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, sizeof(private_key32_array));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(private_key32_array), (const jbyte*)private_key32_array);

    return retv;
}

/**
 *  从BTS地址初始化公钥结构体
 */    
JNIEXPORT jbyteArray
java_jni_entry_bts_gen_public_key_from_b58address(JNIEnv* env, jobject self,
    jbyteArray address, jbyteArray address_prefix)
{
    //  检查参数
    if (!address || !address_prefix){
        return NULL;
    }

    //  获取数据
    jbyte* address_ptr = (*env)->GetByteArrayElements(env, address, 0);
    jsize address_size = (*env)->GetArrayLength(env, address);
    jbyte* address_prefix_ptr = (*env)->GetByteArrayElements(env, address_prefix, 0);
    jsize address_prefix_size = (*env)->GetArrayLength(env, address_prefix);

    //  调用API
    secp256k1_pubkey_compressed pubkey = {0, };
    bool result = __bts_gen_public_key_from_b58address((const unsigned char*)address_ptr, (const size_t)address_size, (const size_t)address_prefix_size, &pubkey);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, address, address_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, address_prefix, address_prefix_ptr, JNI_ABORT);

    //  返回
    if (!result){
        return NULL;
    }

    //  拷贝整个结构体
    jbyteArray retv = (*env)->NewByteArray(env, sizeof(pubkey.data));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(pubkey.data), (const jbyte*)pubkey.data);

    return retv;
}

/**
 *  加法调整公私钥
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_privkey_tweak_add(JNIEnv* env, jobject self,
    jbyteArray seckey, jbyteArray tweak)
{
    //  检查参数
    if (!seckey || !tweak){
        return NULL;
    }

    //  获取数据
    jbyte* seckey_ptr = (*env)->GetByteArrayElements(env, seckey, 0);
    jsize seckey_size = (*env)->GetArrayLength(env, seckey);
    jbyte* tweak_ptr = (*env)->GetByteArrayElements(env, tweak, 0);

    jbyteArray retv = NULL;
    if (__bts_privkey_tweak_add((unsigned char*)seckey_ptr, (const unsigned char*)tweak_ptr)) {
        retv = (*env)->NewByteArray(env, seckey_size);
        (*env)->SetByteArrayRegion(env, retv, 0, seckey_size, (const jbyte*)seckey_ptr);
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, seckey, seckey_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, tweak, tweak_ptr, JNI_ABORT);

    return retv;
}

JNIEXPORT jbyteArray
java_jni_entry_bts_pubkey_tweak_add(JNIEnv* env, jobject self,
    jbyteArray pubkey, jbyteArray tweak)
{
    //  检查参数
    if (!pubkey || !tweak){
        return NULL;
    }

    //  获取数据
    jbyte* pubkey_ptr = (*env)->GetByteArrayElements(env, pubkey, 0);
    jsize pubkey_size = (*env)->GetArrayLength(env, pubkey);
    jbyte* tweak_ptr = (*env)->GetByteArrayElements(env, tweak, 0);

    //  构造publick key结构体
    secp256k1_pubkey_compressed public_key_s = {0, };
    assert(pubkey_size == sizeof(public_key_s.data));
    memcpy(&public_key_s.data, pubkey_ptr, sizeof(public_key_s.data));

    jbyteArray retv = NULL;
    if (__bts_pubkey_tweak_add(&public_key_s, (const unsigned char*)tweak_ptr)) {
        //  拷贝整个结构体
        retv = (*env)->NewByteArray(env, sizeof(public_key_s.data));
        (*env)->SetByteArrayRegion(env, retv, 0, sizeof(public_key_s.data), (const jbyte*)public_key_s.data);
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, pubkey, pubkey_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, tweak, tweak_ptr, JNI_ABORT);
    
    return retv;
}

/*
 *  (public) Base58编码/解码。
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_base58_encode(JNIEnv* env, jobject self,
    jbyteArray data)
{
    //  检查参数
    if (!data){
        return NULL;
    }

    //  获取数据
    jbyte* data_ptr = (*env)->GetByteArrayElements(env, data, 0);
    jsize data_size = (*env)->GetArrayLength(env, data);

    size_t output_size = data_size * 2;   
    unsigned char* output = (unsigned char*)malloc(output_size + 1);
    if (output) {
        __bts_base58_encode((const unsigned char*)data_ptr, (const size_t)data_size, output, &output_size); 
    }

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, data, data_ptr, JNI_ABORT);

    if (output) {
        //  REMARK: 这个 output_size 的长度包含了 '\0'，需要移除。
        jbyteArray retv = (*env)->NewByteArray(env, output_size - 1);
        (*env)->SetByteArrayRegion(env, retv, 0, output_size - 1, (const jbyte*)output);
        //  释放
        free(output);
        return retv;
    } else {
        return NULL;
    }
}

JNIEXPORT jbyteArray
java_jni_entry_bts_base58_decode(JNIEnv* env, jobject self,
    jbyteArray data)
{
    //  检查参数
    if (!data){
        return NULL;
    }

    //  获取数据
    jbyte* data_ptr = (*env)->GetByteArrayElements(env, data, 0);
    jsize data_size = (*env)->GetArrayLength(env, data);

    size_t output_size = data_size + 1;   
    unsigned char* output = (unsigned char*)malloc(output_size + 1);
    unsigned char* result_ptr = NULL;
    if (output) {
        result_ptr = __bts_base58_decode((const unsigned char*)data_ptr, (const size_t)data_size, output, &output_size); 
    }
    
    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, data, data_ptr, JNI_ABORT);

    if (result_ptr) {
        jbyteArray retv = (*env)->NewByteArray(env, output_size);
        (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)result_ptr);
        //  释放
        free(output);
        return retv;
    } else {
        return NULL;
    }
}

/**
 *  解码商人协议发票数据。
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_merchant_invoice_decode(JNIEnv* env, jobject self,
    jbyteArray b58str)
{
    //  检查参数
    if (!b58str){
        return NULL;
    }

    //  获取数据
    jbyte* b58str_ptr = (*env)->GetByteArrayElements(env, b58str, 0);
    jsize b58str_size = (*env)->GetArrayLength(env, b58str);

    size_t output_size = 0;
    unsigned char* pInvoice = __bts_merchant_invoice_decode((const unsigned char*)b58str_ptr, (const size_t)b58str_size, &output_size);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, b58str, b58str_ptr, JNI_ABORT);

    //  返回
    if (!pInvoice || output_size == 0) {
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)pInvoice);

    return retv;
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
JNIEXPORT jbyteArray
java_jni_entry_bts_save_wallet(JNIEnv* env, jobject self,
    jbyteArray wallet_jsonbin, jbyteArray password, jbyteArray entropy)
{
    //  检查参数
    if (!wallet_jsonbin || !password || !entropy){
        return NULL;
    }

    //  获取数据
    jbyte* wallet_jsonbin_ptr = (*env)->GetByteArrayElements(env, wallet_jsonbin, 0);
    jsize wallet_jsonbin_size = (*env)->GetArrayLength(env, wallet_jsonbin);

    jbyte* password_ptr = (*env)->GetByteArrayElements(env, password, 0);
    jsize password_size = (*env)->GetArrayLength(env, password);

    jbyte* entropy_ptr = (*env)->GetByteArrayElements(env, entropy, 0);
    jsize entropy_size = (*env)->GetArrayLength(env, entropy);

    //  调用API
    size_t output_size = 0;
    unsigned char* output_data = __bts_save_wallet((const unsigned char*)wallet_jsonbin_ptr, (const size_t)wallet_jsonbin_size, (const unsigned char*)password_ptr, (const size_t)password_size, (const unsigned char*)entropy_ptr, (const size_t)entropy_size, &output_size);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, wallet_jsonbin, wallet_jsonbin_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, password, password_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, entropy, entropy_ptr, JNI_ABORT);

    //  返回
    if (!output_data || !output_size){
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, output_size, (const jbyte*)output_data);

    //  释放内存
    free(output_data);
    output_data = 0;

    return retv;
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
JNIEXPORT jbyteArray
java_jni_entry_bts_load_wallet(JNIEnv* env, jobject self,
    jbyteArray wallet_buffer, jbyteArray password)
{
    //  检查参数
    if (!wallet_buffer || !password){
        return NULL;
    }

    //  获取数据
    jbyte* wallet_buffer_ptr = (*env)->GetByteArrayElements(env, wallet_buffer, 0);
    jsize wallet_buffer_size = (*env)->GetArrayLength(env, wallet_buffer);

    jbyte* password_ptr = (*env)->GetByteArrayElements(env, password, 0);
    jsize password_size = (*env)->GetArrayLength(env, password);

    //  调用API
    size_t final_output_size = 0;
    unsigned char* output_data = __bts_load_wallet((const unsigned char*)wallet_buffer_ptr, (const size_t)wallet_buffer_size, (const unsigned char*)password_ptr, (const size_t)password_size, &final_output_size);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, wallet_buffer, wallet_buffer_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, password, password_ptr, JNI_ABORT);

    //  返回
    if (!output_data){
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, final_output_size);
    (*env)->SetByteArrayRegion(env, retv, 0, final_output_size, (const jbyte*)output_data);

    //  释放内存
    free(output_data);
    output_data = 0;

    return retv;
}

/**
 *  (public) 签名
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_sign_buffer(JNIEnv* env, jobject self,
    jbyteArray sign_buffer, jbyteArray sign_private_key32)
{
    //  检查参数
    if (!sign_buffer || !sign_private_key32){
        return NULL;
    }

    //  获取数据
    jbyte* sign_buffer_ptr = (*env)->GetByteArrayElements(env, sign_buffer, 0);
    jsize sign_buffer_size = (*env)->GetArrayLength(env, sign_buffer);

    jbyte* sign_private_key32_ptr = (*env)->GetByteArrayElements(env, sign_private_key32, 0);
    jsize sign_private_key32_size = (*env)->GetArrayLength(env, sign_private_key32);

    //  调用API
    secp256k1_compact_signature signature = {0, };
    bool result = __bts_sign_buffer((const unsigned char*)sign_buffer_ptr, (const size_t)sign_buffer_size, (const unsigned char*)sign_private_key32_ptr, &signature);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, sign_buffer, sign_buffer_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, sign_private_key32, sign_private_key32_ptr, JNI_ABORT);

    //  返回
    if (!result){
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, sizeof(signature.data));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(signature.data), (const jbyte*)signature.data);
    return retv;
}

/*
 *  (public) 根据盲化因子和数据生成佩德森承诺。
 */
JNIEXPORT jbyteArray
java_jni_entry_bts_gen_pedersen_commit(JNIEnv* env, jobject self,
    jbyteArray blind_factor, jlong value)
{
    //  检查参数
    if (!blind_factor){
        return NULL;
    }

    //  获取数据
    jbyte* blind_factor_ptr = (*env)->GetByteArrayElements(env, blind_factor, 0);
    jsize blind_factor_size = (*env)->GetArrayLength(env, blind_factor);

    //  调用API
    blind_factor_type blind_factor_s = {0, };
    assert(sizeof(blind_factor_s.data) == blind_factor_size);
    memcpy(blind_factor_s.data, blind_factor_ptr, sizeof(blind_factor_s.data));

    //  TODO: jlong < uint64 未处理
    commitment_type commitment = {0, };
    bool result = __bts_gen_pedersen_commit(&commitment, &blind_factor_s, (const uint64_t)value);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, blind_factor, blind_factor_ptr, JNI_ABORT);

    //  返回
    if (!result){
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, sizeof(commitment.data));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(commitment.data), (const jbyte*)commitment.data);
    return retv;
}

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_pedersen_blind_sum(JNIEnv* env, jobject self,
    jobjectArray blinds_in, jlong non_neg)
{
    //  检查参数
    if (!blinds_in){
        return NULL;
    }

    //  获取数据
    jsize blinds_in_size = (*env)->GetArrayLength(env, blinds_in);
    if (blinds_in_size <= 0) {
      return NULL;
    }

    //  获取参数
    const unsigned char* blinds[blinds_in_size];
    for (jsize i = 0; i < blinds_in_size; ++i)
    {
      jobject blind = (*env)->GetObjectArrayElement(env, blinds_in, i);
      jbyte* blind_ptr_ptr = (*env)->GetByteArrayElements(env, (jbyteArray)blind, 0);
      blinds[i] = (const unsigned char*)blind_ptr_ptr;
    }

    //  调用API
    blind_factor_type blind_factor = {0, };
    bool result = __bts_gen_pedersen_blind_sum(blinds, (const size_t)blinds_in_size, (uint32_t)non_neg, &blind_factor);

    //  释放参数数据
    for (jsize i = 0; i < blinds_in_size; ++i)
    {
      jobject blind = (*env)->GetObjectArrayElement(env, blinds_in, i);
      (*env)->ReleaseByteArrayElements(env, blind, (jbyte*)blinds[i], JNI_ABORT);
    }

    //  返回
    if (!result){
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, sizeof(blind_factor.data));
    (*env)->SetByteArrayRegion(env, retv, 0, sizeof(blind_factor.data), (const jbyte*)blind_factor.data);
    return retv;
}

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_range_proof_sign(JNIEnv* env, jobject self,
    jlong min_value, jbyteArray commit, jbyteArray commit_blind, jbyteArray nonce, jlong base10_exp, jlong min_bits, jlong actual_value)
{
    //  检查参数
    if (!commit || !commit_blind || !nonce){
        return NULL;
    }

    //  获取数据
    jbyte* commit_ptr = (*env)->GetByteArrayElements(env, commit, 0);
    jsize commit_size = (*env)->GetArrayLength(env, commit);

    jbyte* commit_blind_ptr = (*env)->GetByteArrayElements(env, commit_blind, 0);
    jsize commit_blind_size = (*env)->GetArrayLength(env, commit_blind);

    jbyte* nonce_ptr = (*env)->GetByteArrayElements(env, nonce, 0);
    jsize nonce_size = (*env)->GetArrayLength(env, nonce);

    //  获取API调用需要参数
    commitment_type commit_s = {0, };
    blind_factor_type commit_blind_s = {0, };
    blind_factor_type nonce_s = {0, };

    assert(sizeof(commit_s.data) == commit_size);
    memcpy(commit_s.data, commit_ptr, sizeof(commit_s.data));

    assert(sizeof(commit_blind_s.data) == commit_blind_size);
    memcpy(commit_blind_s.data, commit_blind_ptr, sizeof(commit_blind_s.data));

    assert(sizeof(nonce_s.data) == nonce_size);
    memcpy(nonce_s.data, nonce_ptr, sizeof(nonce_s.data));

    //  调用API
    unsigned char proof[5134];
    int proof_len = sizeof(proof);

    //  TODO: jlong < uint64 未处理
    bool result = __bts_gen_range_proof_sign(0, &commit_s, &commit_blind_s, &nonce_s, (int8_t)base10_exp, (uint8_t)min_bits, (uint64_t)actual_value, proof, &proof_len);

    //  释放参数数据
    (*env)->ReleaseByteArrayElements(env, commit, commit_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, commit_blind, commit_blind_ptr, JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env, nonce, nonce_ptr, JNI_ABORT);

    //  返回
    if (!result){
        return NULL;
    }

    jbyteArray retv = (*env)->NewByteArray(env, proof_len);
    (*env)->SetByteArrayRegion(env, retv, 0, proof_len, (const jbyte*)proof);
    return retv;
}

JNIEXPORT jbyteArray
java_jni_entry_rmd160(JNIEnv* env, jobject self, 
    jbyteArray buffer);

JNIEXPORT jbyteArray
java_jni_entry_sha1(JNIEnv* env, jobject self, 
    jbyteArray buffer);

JNIEXPORT jbyteArray
java_jni_entry_sha256(JNIEnv* env, jobject self, 
    jbyteArray buffer);

JNIEXPORT jbyteArray
java_jni_entry_sha512(JNIEnv* env, jobject self, 
    jbyteArray buffer);

JNIEXPORT jbyteArray
java_jni_entry_bts_get_shared_secret(JNIEnv* env, jobject self, 
    jbyteArray private_key, jbyteArray public_key);

JNIEXPORT jbyteArray
java_jni_entry_bts_aes256_encrypt_to_hex(JNIEnv* env, jobject self,
    jbyteArray aes_seed, jbyteArray srcptr);

JNIEXPORT jbyteArray
java_jni_entry_bts_aes256_decrypt_from_hex(JNIEnv* env, jobject self,
    jbyteArray aes_seed, jbyteArray hex_src);

JNIEXPORT jbyteArray
java_jni_entry_bts_aes256cbc_encrypt(JNIEnv* env, jobject self,
    jbyteArray secret, jbyteArray src);

JNIEXPORT jbyteArray
java_jni_entry_bts_aes256cbc_decrypt(JNIEnv* env, jobject self,
    jbyteArray secret, jbyteArray src);

JNIEXPORT jbyteArray
java_jni_entry_bts_aes256_decrypt_with_checksum(JNIEnv* env, jobject self,
    jbyteArray private_key32, jbyteArray public_key, jbyteArray nonce, jbyteArray message);

JNIEXPORT jbyteArray
java_jni_entry_bts_aes256_encrypt_with_checksum(JNIEnv* env, jobject self,
    jbyteArray private_key32, jbyteArray public_key, jbyteArray nonce, jbyteArray message);

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_private_key_from_seed(JNIEnv* env, jobject self, 
    jbyteArray seed);

JNIEXPORT jstring
java_jni_entry_bts_private_key_to_wif(JNIEnv* env, jobject self,
    jbyteArray private_key32);

JNIEXPORT jbyteArray
java_jni_entry_bts_public_key_to_address(JNIEnv* env, jobject self,
    jbyteArray public_key, jbyteArray address_prefix);

JNIEXPORT jboolean
java_jni_entry_bts_verify_private_key(JNIEnv* env, jobject self,
    jbyteArray private_key);

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_public_key(JNIEnv* env, jobject self,
    jbyteArray private_key);

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_address_from_private_key32(JNIEnv* env, jobject self,
    jbyteArray private_key32, jbyteArray address_prefix);

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_private_key_from_wif_privatekey(JNIEnv* env, jobject self,
    jbyteArray wif_privatekey);

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_public_key_from_b58address(JNIEnv* env, jobject self,
    jbyteArray address, jbyteArray address_prefix);

JNIEXPORT jbyteArray
java_jni_entry_bts_privkey_tweak_add(JNIEnv* env, jobject self,
    jbyteArray seckey, jbyteArray tweak);

JNIEXPORT jbyteArray
java_jni_entry_bts_pubkey_tweak_add(JNIEnv* env, jobject self,
    jbyteArray pubkey, jbyteArray tweak);

JNIEXPORT jbyteArray
java_jni_entry_bts_base58_encode(JNIEnv* env, jobject self,
    jbyteArray data);

JNIEXPORT jbyteArray
java_jni_entry_bts_base58_decode(JNIEnv* env, jobject self,
    jbyteArray data);

JNIEXPORT jbyteArray
java_jni_entry_bts_merchant_invoice_decode(JNIEnv* env, jobject self,
    jbyteArray b58str);

JNIEXPORT jbyteArray
java_jni_entry_bts_save_wallet(JNIEnv* env, jobject self,
    jbyteArray wallet_jsonbin, jbyteArray password, jbyteArray entropy);

JNIEXPORT jbyteArray
java_jni_entry_bts_load_wallet(JNIEnv* env, jobject self,
    jbyteArray wallet_buffer, jbyteArray password);

JNIEXPORT jbyteArray
java_jni_entry_bts_sign_buffer(JNIEnv* env, jobject self,
    jbyteArray sign_buffer, jbyteArray sign_private_key32);

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_pedersen_commit(JNIEnv* env, jobject self,
    jbyteArray blind_factor, jlong value);

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_pedersen_blind_sum(JNIEnv* env, jobject self,
    jobjectArray blinds_in, jlong non_neg);

JNIEXPORT jbyteArray
java_jni_entry_bts_gen_range_proof_sign(JNIEnv* env, jobject self,
    jlong min_value, jbyteArray commit, jbyteArray commit_blind, jbyteArray nonce, jlong base10_exp, jlong min_bits, jlong actual_value);

static JNINativeMethod jni_methods_table[] = 
{
    {"rmd160",                                  "([B)[B",                   (void*)java_jni_entry_rmd160},
    {"sha1",                                    "([B)[B",                   (void*)java_jni_entry_sha1},
    {"sha256",                                  "([B)[B",                   (void*)java_jni_entry_sha256},
    {"sha512",                                  "([B)[B",                   (void*)java_jni_entry_sha512},
    {"bts_get_shared_secret",                   "([B[B)[B",                 (void*)java_jni_entry_bts_get_shared_secret},
    {"bts_aes256_encrypt_to_hex",               "([B[B)[B",                 (void*)java_jni_entry_bts_aes256_encrypt_to_hex},
    {"bts_aes256_decrypt_from_hex",             "([B[B)[B",                 (void*)java_jni_entry_bts_aes256_decrypt_from_hex},
    {"bts_aes256cbc_encrypt",                   "([B[B)[B",                 (void*)java_jni_entry_bts_aes256cbc_encrypt},
    {"bts_aes256cbc_decrypt",                   "([B[B)[B",                 (void*)java_jni_entry_bts_aes256cbc_decrypt},
    {"bts_aes256_decrypt_with_checksum",        "([B[B[B[B)[B",             (void*)java_jni_entry_bts_aes256_decrypt_with_checksum},
    {"bts_aes256_encrypt_with_checksum",        "([B[B[B[B)[B",             (void*)java_jni_entry_bts_aes256_encrypt_with_checksum},
    {"bts_gen_private_key_from_seed",           "([B)[B",                   (void*)java_jni_entry_bts_gen_private_key_from_seed},
    {"bts_private_key_to_wif",                  "([B)Ljava/lang/String;",   (void*)java_jni_entry_bts_private_key_to_wif},
    {"bts_public_key_to_address",               "([B[B)[B",                 (void*)java_jni_entry_bts_public_key_to_address},
    {"bts_verify_private_key",                  "([B)Z",                    (void*)java_jni_entry_bts_verify_private_key},
    {"bts_gen_public_key",                      "([B)[B",                   (void*)java_jni_entry_bts_gen_public_key},
    {"bts_gen_address_from_private_key32",      "([B[B)[B",                 (void*)java_jni_entry_bts_gen_address_from_private_key32},
    {"bts_gen_private_key_from_wif_privatekey", "([B)[B",                   (void*)java_jni_entry_bts_gen_private_key_from_wif_privatekey},
    {"bts_gen_public_key_from_b58address",      "([B[B)[B",                 (void*)java_jni_entry_bts_gen_public_key_from_b58address},
    {"bts_privkey_tweak_add",                   "([B[B)[B",                 (void*)java_jni_entry_bts_privkey_tweak_add},
    {"bts_pubkey_tweak_add",                    "([B[B)[B",                 (void*)java_jni_entry_bts_pubkey_tweak_add},
    {"bts_base58_encode",                       "([B)[B",                   (void*)java_jni_entry_bts_base58_encode},
    {"bts_base58_decode",                       "([B)[B",                   (void*)java_jni_entry_bts_base58_decode},
    {"bts_merchant_invoice_decode",             "([B)[B",                   (void*)java_jni_entry_bts_merchant_invoice_decode},
    {"bts_save_wallet",                         "([B[B[B)[B",               (void*)java_jni_entry_bts_save_wallet},
    {"bts_load_wallet",                         "([B[B)[B",                 (void*)java_jni_entry_bts_load_wallet},
    {"bts_sign_buffer",                         "([B[B)[B",                 (void*)java_jni_entry_bts_sign_buffer},
    {"bts_gen_pedersen_commit",                 "([BJ)[B",                  (void*)java_jni_entry_bts_gen_pedersen_commit},
    {"bts_gen_pedersen_blind_sum",              "([Ljava/lang/Object;J)[B", (void*)java_jni_entry_bts_gen_pedersen_blind_sum},
    {"bts_gen_range_proof_sign",                "(J[B[B[BJJJ)[B",           (void*)java_jni_entry_bts_gen_range_proof_sign},
}; 

static int jniRegisterNativeMethods(JNIEnv* env, const char* className, const JNINativeMethod* gMethods, int numMethods)  
{
    jclass klass;  
    jint tmp;
  
    LOGD("Registering %s natives\n", className);  
    klass = (*env)->FindClass(env, className);  
    if (klass == NULL) 
    {  
        LOGD("Native registration unable to find class '%s'\n", className);  
        return -1;  
    }  
    tmp = (*env)->RegisterNatives(env, klass, gMethods, numMethods);
    if (tmp < 0) 
    {  
        LOGD("RegisterNatives failed for '%s', %d\n", className, tmp);  
        return -1;  
    }  
    return 0;  
}  
  
static int registerNativeMethods(JNIEnv *env) 
{
    return jniRegisterNativeMethods(env, "com/btsplusplus/fowallet/NativeInterface", jni_methods_table, sizeof(jni_methods_table) / sizeof(jni_methods_table[0]));  
} 

 // so入口
jint JNI_OnLoad(JavaVM* vm, void* reserved)
{
    JNIEnv* env;  
    if ((*vm)->GetEnv(vm, (void**)(&env), JNI_VERSION_1_4) != JNI_OK)  
    {  
        LOGD("get evn failed...\n");
        return -1;  
    }  

    if (registerNativeMethods(env) != JNI_OK) 
    {  
        return -1;  
    }

    return JNI_VERSION_1_4;  
}

