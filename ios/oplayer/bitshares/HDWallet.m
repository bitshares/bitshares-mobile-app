//
//  HDWallet.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "HDWallet.h"
#import "Extension.h"
#import "bts_wallet_core.h"

#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonCryptoError.h>

#import "OrgUtils.h"

@interface HDWallet()
{
}
@end

@implementation HDWallet

@synthesize privateKey, chainCode, index, depth;

- (id)init
{
    self = [super init];
    if (self)
    {
        self.privateKey = nil;
        self.chainCode = nil;
    }
    return self;
}

- (id)initWithMasterSeed:(NSData*)seed
{
    self = [super init];
    if (self)
    {
        //  https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
        NSData* result = [[self class] hmacSHA512:seed key:@"Bitcoin seed"];
        const uint8_t* result_ptr = (const uint8_t*)result.bytes;
        self.privateKey = [[NSData alloc] initWithBytes:&result_ptr[0] length:32];
        self.chainCode = [[NSData alloc] initWithBytes:&result_ptr[32] length:32];
        self.index = 0;
        self.depth = 0;
    }
    return self;
}

- (void)dealloc
{
    self.privateKey = nil;
    self.chainCode = nil;
}

/**
 *  (public) 获取 WIF 格式私钥。
 */
- (NSString*)toWifPrivateKey
{
    assert(self.privateKey);
    return [OrgUtils genBtsWifPrivateKeyByPrivateKey32:self.privateKey];
}

/**
 *  (public) 获取 WIF 格式公钥。
 */
- (NSString*)toWifPublicKey
{
    return [OrgUtils genBtsAddressFromWifPrivateKey:[self toWifPrivateKey]];
}

+ (HDWallet*)fromMnemonic:(NSString*)mnemonic
{
    return [self fromMasterSeed:[self mnemonicToMasterSeed:mnemonic passphrase:@""]];
}

+ (HDWallet*)fromMasterSeed:(NSData*)seed
{
    assert(seed);
    return [[self alloc] initWithMasterSeed:seed];
}

- (HDWallet*)deriveBitshares:(EHDBitsharesPermissionType)type
{
    switch (type) {
        case EHDBPT_OWNER:
            return [self derive:@"m/48'/1'/0'/0'/0'"];
        case EHDBPT_ACTIVE:
            return [self derive:@"m/48'/1'/1'/0'/0'"];
        case EHDBPT_MEMO:
            return [self derive:@"m/48'/1'/3'/0'/0'"];
            break;
        default:
            break;
    }
    assert(NO);
    return nil;
}

- (HDWallet*)derive:(NSString*)path
{
    //  参考：https://github.com/cryptocoinjs/hdkey/blob/master/lib/hdkey.js
    
    //  REMARK: hardened const
    uint32_t HARDENED_OFFSET = 0x80000000;
    
    HDWallet* curr_hd = self;
    
    NSArray* entries = [path componentsSeparatedByString:@"/"];
    
    NSInteger idx = 0;
    for (NSString* src in entries) {
        if (idx == 0){
            assert([src isEqualToString:@"m"] || [src isEqualToString:@"M"]);
        }else{
            BOOL hardened = src.length >= 1 && [[src substringFromIndex:src.length - 1] isEqualToString:@"'"];
            
            uint32_t childIndex = hardened ? [[src substringToIndex:src.length - 1] intValue] : [src intValue];
            assert(childIndex <= HARDENED_OFFSET);
            if (hardened) {
                childIndex += HARDENED_OFFSET;
                curr_hd = [self deriveChildHardened:childIndex curr_hd:curr_hd];
            }else{
                //  TODO:暂不支持non-hardened
                assert(NO);
                curr_hd = [self deriveChildNonHardened:childIndex curr_hd:curr_hd];
            }
        }
        ++idx;
    }
    
    return curr_hd;
}

- (HDWallet*)deriveChildHardened:(uint32_t)childIndex curr_hd:(HDWallet*)curr_hd
{
    //  HMAC-SHA512(Key = cpar, Data = 0x00 || ser256(kpar) || ser32(i))
    uint8_t buffer[1 + 32 + 4] = {0, };
    memcpy(&buffer[1], curr_hd.privateKey.bytes,  curr_hd.privateKey.length);
    unsigned int bigChildIndex = NSSwapHostIntToBig(childIndex);
    memcpy(&buffer[1+32], &bigChildIndex, sizeof(childIndex));  //  REMARK：index is BigEndian
    
    NSData* result = [[self class] hmacSHA512:buffer data_size:sizeof(buffer) keydata:curr_hd.chainCode];
    uint8_t* ptr = (uint8_t*)result.bytes;
    NSData* il = [[NSData alloc] initWithBytes:&ptr[0] length:32];
    NSData* ir = [[NSData alloc] initWithBytes:&ptr[32] length:32];
    
    //  子私钥
    uint8_t new_private_key[32] = {0, };
    memcpy(new_private_key,  curr_hd.privateKey.bytes,  curr_hd.privateKey.length);
    if (!__bts_privkey_tweak_add(new_private_key, il.bytes)){
        return [self deriveChildHardened:childIndex + 1 curr_hd:curr_hd];
    }
    
    //  返回
    HDWallet* new_hd = [[HDWallet alloc] init];
    new_hd.privateKey = [[NSData alloc] initWithBytes:new_private_key length:sizeof(new_private_key)];
    new_hd.chainCode = ir;
    new_hd.index = childIndex;
    new_hd.depth = curr_hd.depth + 1;
    return new_hd;
}

- (HDWallet*)deriveChildNonHardened:(uint32_t)childIndex curr_hd:(HDWallet*)curr_hd
{
    //  TODO:不支持
    //  HMAC-SHA512(Key = cpar, Data = serP(point(kpar)) || ser32(i))
    NSAssert(NO, @"暂不支持");
    return nil;
}

/**
 *  (public) 【BIP39】根据助记词生成种子。
 *  参考：https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
 */
+ (NSData*)mnemonicToMasterSeed:(NSString*)mnemonic passphrase:(NSString*)passphrase
{
    //  为了从助记词中生成二进制种子，BIP39 采用 PBKDF2 函数推算种子，其参数如下：
    //  【助记词句子作为密码，"mnemonic" + passphrase 作为盐，2048 作为重复计算的次数，HMAC-SHA512 作为随机算法，512 位(64 字节)是期望得到的密钥长度】
    NSData* saltData = [[self _salt:passphrase] dataUsingEncoding:NSUTF8StringEncoding];
    NSData* passwordData = [mnemonic dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest64[CC_SHA512_DIGEST_LENGTH] = {0, };
    
    //  kCCParamError
    int result = CCKeyDerivationPBKDF(kCCPBKDF2,
                                      passwordData.bytes, passwordData.length,
                                      saltData.bytes, saltData.length,
                                      kCCPRFHmacAlgSHA512, 2048, digest64, sizeof(digest64));
    
    if (result != kCCSuccess) {
        return nil;
    }
    
    return [[NSData alloc] initWithBytes:digest64 length:sizeof(digest64)];
}

+ (NSString*)_salt:(NSString*)passphrase
{
    return [NSString stringWithFormat:@"mnemonic%@", passphrase ?: @""];
}

+ (NSData*)hmacSHA512:(NSData*)data key:(NSString*)key
{
    assert(data);
    assert(key);
    
    NSData* keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest64[CC_SHA512_DIGEST_LENGTH] = {0, };
    
    CCHmac(kCCHmacAlgSHA512, keyData.bytes, keyData.length, data.bytes, data.length, digest64);
    
    return [[NSData alloc] initWithBytes:digest64 length:sizeof(digest64)];
}

+ (NSData*)hmacSHA512:(const void*)data_ptr data_size:(const size_t)data_size keydata:(NSData*)keydata
{
    assert(data_ptr);
    assert(data_size);
    assert(keydata);
    
    uint8_t digest64[CC_SHA512_DIGEST_LENGTH] = {0, };
    
    CCHmac(kCCHmacAlgSHA512, keydata.bytes, keydata.length, data_ptr, data_size, digest64);
    
    return [[NSData alloc] initWithBytes:digest64 length:sizeof(digest64)];
}

@end
