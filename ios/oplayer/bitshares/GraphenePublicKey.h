//
//  GraphenePublicKey.h
//  UIDemo
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>
#import "GraphenePrivateKey.h"

#import "bts_wallet_core.h"

@interface GraphenePublicKey : NSObject

+ (id)fromWifPublicKey:(NSString*)wif_public_key;

- (id)initWithSecp256k1PublicKey:(const secp256k1_pubkey_compressed*)public_key;
- (id)initWithPrivateKey:(GraphenePrivateKey*)private_key;

- (secp256k1_pubkey_compressed*)getKeyData;
- (NSString*)toWifString;

- (GraphenePublicKey*)child:(const digest_sha256*)child;

/*
 *  (public) 生成变形的 to_public_key，仅用做验证。没发计算出原 to_public_key。
 */
- (GraphenePublicKey*)genToToTo:(NSData*)commitment;

@end
