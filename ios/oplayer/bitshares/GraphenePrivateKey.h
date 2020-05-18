//
//  GraphenePrivateKey.h
//  UIDemo
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>
#import "bts_wallet_core.h"

@class GraphenePublicKey;
@interface GraphenePrivateKey : NSObject

+ (id)fromWifPrivateKey:(NSString*)wif_private_key;

- (id)initWithSecp256k1PrivateKey:(const secp256k1_prikey*)private_key;
- (id)initWithSeed:(NSData*)seed;
- (id)initRandom;

- (secp256k1_prikey*)getKeyData;
- (NSString*)toWifString;
- (GraphenePublicKey*)getPublicKey;

- (BOOL)getSharedSecret:(GraphenePublicKey*)public_key output:(digest_sha512*)outpout;
- (GraphenePrivateKey*)child:(const digest_sha256*)child;

@end
