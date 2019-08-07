//
//  HDWallet.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>

/**
 *  BTS石墨烯私钥类型定义
 *  参考：https://github.com/satoshilabs/slips/issues/49。
 */
typedef enum EHDBitsharesPermissionType
{
    EHDBPT_OWNER = 0,       //  所有者权限
    EHDBPT_ACTIVE,          //  资金权限
    EHDBPT_MEMO,            //  备注权限
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
- (HDWallet*)derive:(NSString*)path;

@end
