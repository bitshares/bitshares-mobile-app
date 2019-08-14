//
//  AppCacheManager.h
//  oplayer
//
//  Created by SYALON on 13-11-4.
//
//

#import <Foundation/Foundation.h>

typedef enum EWalletMode
{
    kwmNoWallet = 0,            //  无钱包
    kwmPasswordOnlyMode,        //  普通密码模式
    kwmPasswordWithWallet,      //  密码登录+钱包模式
    kwmPrivateKeyWithWallet,    //  活跃私钥+钱包模式
    kwmFullWalletMode,          //  完整钱包模式（兼容官方客户端的钱包格式）
    kwmBrainKeyWithWallet       //  助记词+钱包模式
} EWalletMode;

@interface AppCacheManager : NSObject

///<    单例
+(AppCacheManager*)sharedAppCacheManager;

#pragma mark- initialize
-(void)initload;
-(void)saveToFile;
-(void)saveCacheToFile;
-(void)saveWalletInfoToFile;
-(void)saveObjectCacheToFile;
-(void)saveFavAccountsToFile;
-(void)saveFavMarketsToFile;
-(void)saveCustomMarketsToFile;

#pragma mark- garphene object cache
- (AppCacheManager*)update_object_cache:(NSString*)object_id object:(NSDictionary*)object;
- (NSDictionary*)get_object_cache:(NSString*)object_id now_ts:(NSTimeInterval)now_ts;
- (NSDictionary*)get_object_cache:(NSString*)object_id;

#pragma mark- fav accounts
- (NSDictionary*)get_all_fav_accounts;
- (AppCacheManager*)set_fav_account:(NSDictionary*)account_info;
- (void)remove_fav_account:(NSString*)account_name;

#pragma mark- fav markets
- (NSDictionary*)get_all_fav_markets;
- (BOOL)is_fav_market:(NSString*)quote_symbol base:(NSString*)base_symbol;
- (AppCacheManager*)set_fav_markets:(NSString*)quote_symbol base:(NSString*)base_symbol;
- (void)remove_fav_markets:(id)fav_item;
- (void)remove_fav_markets:(NSString*)quote_symbol base:(NSString*)base_symbol;

#pragma mark- for custom markets
- (NSDictionary*)get_all_custom_markets;
- (BOOL)is_custom_market:(NSString*)quote_symbol base:(NSString*)base_symbol;
- (AppCacheManager*)set_custom_markets:(id)quote_asset base:(NSString*)base_symbol;
- (AppCacheManager*)remove_custom_markets:(id)custom_item;
- (AppCacheManager*)remove_custom_markets:(NSString*)quote_symbol base:(NSString*)base_symbol;

#pragma mark- pref
-(NSObject*)getPref:(NSString*)key;
-(NSObject*)getPref:(NSString*)key defaultValue:(NSObject*)defaultValue;
-(AppCacheManager*)setPref:(NSString*)key value:(NSObject*)value;
-(AppCacheManager*)deletePref:(NSString*)key;

#pragma mark- cache
-(id)nativeCacheHash;
-(id)getNativeCacheForKey:(NSString*)pKey;
-(AppCacheManager*)setNativeCacheObject:(id)object forKey:(NSString*)pKey;

#pragma mark- for wallet info
- (NSDictionary*)getWalletInfo;
- (void)removeWalletInfo;
/**
 *  (public) 更新本地钱包帐号信息
 *  walletMode      - 帐号模式
 *  fullAccountInfo - 帐号完整信息（可能为空、注册成但查询失败时则为空。）
 *  accountName     - 帐号名（不能为空）
 *  fullWalletBin   - 钱包二进制bin文件（除了帐号模式以外都存在）
 */
- (void)setWalletInfo:(NSInteger)walletMode
          accountInfo:(id)fullAccountInfo
          accountName:(NSString*)accountName
        fullWalletBin:(NSData*)fullWalletBin;

/**
 *  (public) 设置钱包中当前活跃账号（当前操作的账号）
 */
- (void)setWalletCurrentAccount:(NSString*)currAccountName fullAccountData:(id)fullAccountData;

/**
 *  (public) 保存钱包中的账号信息（和BIN中的账号信息应该同步）
 */
- (void)setWalletAccountDataList:(NSArray*)accountDataList;

/**
 *  更新钱包BIN信息
 */
- (void)updateWalletBin:(NSData*)fullWalletBin;

/**
 *  (public) 更新本地帐号数据
 */
- (void)updateWalletAccountInfo:(id)accountInfo;

/**
 *  备份钱包bin到web目录供用户下载。（也供 iTunes 备份）
 *  hasDatePrefix - 备份文件是否添加日期前缀（在账号管理处手动备份等则添加，其他自动备份等不用添加）
 */
- (BOOL)autoBackupWalletToWebdir:(BOOL)hasDatePrefix;

#pragma mark- first time
- (double)getFirstRunTime;
- (void)recordFirstRunTime:(void (^)())firstrun_callback;
- (BOOL)isFirstRunWithVersion:(NSString*)pVersion;
- (void)saveFirstRunWithVersion:(NSString*)pVersion;

@end
