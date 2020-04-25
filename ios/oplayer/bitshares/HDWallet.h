//
//  HDWallet.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>

/*
 *  BTS石墨烯私钥类型定义
 *  SLIP48：https://github.com/satoshilabs/slips/blob/master/slip-0048.md
 *  更多讨论：https://github.com/satoshilabs/slips/issues/49。
 *  相关：https://wiki.trezor.io/Cryptocurrency_standards
 */
typedef enum EHDBitsharesPermissionType
{
    EHDBPT_OWNER = 0,           //  所有者权限
    EHDBPT_ACTIVE,              //  资金权限
    EHDBPT_MEMO,                //  备注权限
    EHDBPT_STEALTH_MAINKEY,     //  隐私主地址（OP：39、40、41）
    EHDBPT_STEALTH_CHILDKEY,    //  隐私主地址的派生子地址
} EHDBitsharesPermissionType;

@interface HDWallet : NSObject

@property (nonatomic, strong) NSData* privateKey;
@property (nonatomic, strong) NSData* chainCode;
@property (nonatomic, assign) uint32_t index;
@property (nonatomic, assign) NSInteger depth;

/**
 *  (public) 获取 WIF 格式私钥。
 */
- (NSString*)toWifPrivateKey;

/**
 *  (public) 获取 WIF 格式公钥。
 */
- (NSString*)toWifPublicKey;

+ (HDWallet*)fromMnemonic:(NSString*)mnemonic;
+ (HDWallet*)fromMasterSeed:(NSData*)seed;

- (HDWallet*)deriveBitshares:(EHDBitsharesPermissionType)type;
/*
 *  (public) 派生隐私地址的子地址。根据主地址私钥作为seed。
 */
- (HDWallet*)deriveBitsharesStealthChildKey:(NSUInteger)child_key_index;
- (HDWallet*)derive:(NSString*)path;

@end
