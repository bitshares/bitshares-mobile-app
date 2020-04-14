//
//  GraphenePrivateKey.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "GraphenePrivateKey.h"
#import "GraphenePublicKey.h"
#import "WalletManager.h"

@interface GraphenePrivateKey()
{
    secp256k1_prikey    _key;
}
@end

@implementation GraphenePrivateKey

- (void)dealloc
{
}

- (id)initWithSecp256k1PrivateKey:(const secp256k1_prikey*)private_key
{
    self = [super init];
    if (self)
    {
        assert(private_key);
        memcpy(_key.data, private_key->data, sizeof(_key.data));
    }
    return self;
}

- (id)initRandom
{
    self = [super init];
    if (self)
    {
        NSData* seed = [WalletManager secureRandomByte32];
        __bts_gen_private_key_from_seed(seed.bytes, seed.length, _key.data);
    }
    return self;
}

- (secp256k1_prikey*)getKeyData
{
    return &_key;
}

- (NSString*)toWifString
{
    unsigned char output[51 + 10] = {0, };
    size_t output_size = sizeof(output);
    
    __bts_private_key_to_wif(_key.data, output, &output_size);
    
    return [[NSString alloc] initWithBytes:output length:output_size encoding:NSUTF8StringEncoding];
}

- (GraphenePublicKey*)getPublicKey
{
    return [[GraphenePublicKey alloc] initWithPrivateKey:self];
}

- (BOOL)getSharedSecret:(GraphenePublicKey*)public_key output:(digest_sha512*)outpout
{
    assert(outpout);
    
    secp256k1_pubkey_compressed key;
    memcpy(key.data, [public_key getKeyData]->data, sizeof(key.data));
    if (__bts_get_shared_secret(_key.data, &key, outpout->data)) {
        return YES;
    }
    return NO;
}

- (GraphenePrivateKey*)child:(const digest_sha256*)child
{
    assert(child);
    
    GraphenePublicKey* public_key = [self getPublicKey];
    secp256k1_pubkey_compressed* secp256k1_pubkey = [public_key getKeyData];
    
    unsigned char message[sizeof(secp256k1_pubkey->data) + sizeof(child->data)] = {0, };
    
    memcpy(message, secp256k1_pubkey->data, sizeof(secp256k1_pubkey->data));
    memcpy(&message[sizeof(secp256k1_pubkey->data)], child->data, sizeof(child->data));
    
    digest_sha256 offset = {0, };
    sha256(message, sizeof(message), offset.data);
    
    GraphenePrivateKey* child_private_key = [[GraphenePrivateKey alloc] initWithSecp256k1PrivateKey:[self getKeyData]];
    __bts_privkey_tweak_add([child_private_key getKeyData]->data, offset.data);
    return child_private_key;
}

@end
