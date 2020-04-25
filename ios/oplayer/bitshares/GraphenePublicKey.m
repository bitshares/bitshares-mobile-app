//
//  GraphenePublicKey.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "GraphenePublicKey.h"
#import "ChainObjectManager.h"

@interface GraphenePublicKey()
{
    secp256k1_pubkey_compressed _key;
}
@end

@implementation GraphenePublicKey

-(void)dealloc
{
}

- (id)init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

+ (id)fromWifPublicKey:(NSString*)wif_public_key
{
    if (!wif_public_key || [wif_public_key isEqualToString:@""]) {
        return nil;
    }
    secp256k1_pubkey_compressed key;
    if (__bts_gen_public_key_from_b58address((const unsigned char*)[wif_public_key UTF8String], (const size_t)[wif_public_key length],
                                             [[ChainObjectManager sharedChainObjectManager].grapheneAddressPrefix length], &key)) {
        return [[self alloc] initWithSecp256k1PublicKey:&key];
    }
    return nil;
}

- (id)initWithSecp256k1PublicKey:(const secp256k1_pubkey_compressed*)public_key
{
    self = [super init];
    if (self)
    {
        assert(public_key);
        memcpy(_key.data, public_key->data, sizeof(_key.data));
    }
    return self;
}

- (id)initWithPrivateKey:(GraphenePrivateKey*)private_key
{
    self = [super init];
    if (self)
    {
        if (!__bts_gen_public_key([private_key getKeyData], &_key)) {
            NSAssert(NO, @"Invalid private key.");
        }
    }
    return self;
}

- (secp256k1_pubkey_compressed*)getKeyData
{
    return &_key;
}

- (NSString*)toWifString
{
    unsigned char output[51+10] = {0, };
    size_t output_size = sizeof(output);
    
    NSString* address_prefix = [ChainObjectManager sharedChainObjectManager].grapheneAddressPrefix;
    __bts_public_key_to_address(&_key, output, &output_size, [address_prefix UTF8String], address_prefix.length);
    
    return [[NSString alloc] initWithBytes:output length:output_size encoding:NSUTF8StringEncoding];
}

- (GraphenePublicKey*)child:(const digest_sha256*)child
{
    assert(child);
    
    unsigned char message[sizeof(_key.data) + sizeof(child->data)] = {0, };
    
    memcpy(message, _key.data, sizeof(_key.data));
    memcpy(&message[sizeof(_key.data)], child->data, sizeof(child->data));
    
    digest_sha256 offset = {0, };
    sha256(message, sizeof(message), offset.data);
    
    //  计算 child 公钥
    GraphenePublicKey* child_public_key = [[GraphenePublicKey alloc] initWithSecp256k1PublicKey:[self getKeyData]];
    __bts_pubkey_tweak_add([child_public_key getKeyData], offset.data);
    return child_public_key;
}

/*
 *  (public) 生成变形的 to_public_key，仅用做验证。没发计算出原 to_public_key。
 */
- (GraphenePublicKey*)genToToTo:(NSData*)commitment
{
    assert(commitment);
    assert(commitment.length == 33);
    
    unsigned char buf[sizeof(_key.data) + 33];
    memcpy(buf, _key.data, sizeof(_key.data));
    memcpy(&buf[sizeof(_key.data)], commitment.bytes, 33);
    
    secp256k1_prikey to_digest;
    sha256(buf, sizeof(buf), to_digest.data);
    
    return [[[GraphenePrivateKey alloc] initWithSecp256k1PrivateKey:&to_digest] getPublicKey];
}

@end
