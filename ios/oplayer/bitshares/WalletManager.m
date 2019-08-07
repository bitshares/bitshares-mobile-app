//
//  WalletManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "WalletManager.h"
#import "OrgUtils.h"
#import "AppCommon.h"
#import "Extension.h"

#import "ChainObjectManager.h"

#include "bts_wallet_core.h"

#include <sys/types.h>
#include <sys/sysctl.h>
#import <sys/utsname.h>

#pragma mark- for Wallet
//let WalletTcomb = struct(
//                         {
//                         public_name: Str,
//                         created: Dat,
//                         last_modified: Dat,
//                         backup_date: maybe(Dat),
//                         password_pubkey: Str,
//                         encryption_key: Str,
//                         encrypted_brainkey: maybe(Str),
//                         brainkey_pubkey: Str,
//                         brainkey_sequence: Num,             - 必须：下一个密钥生成时用的index。如果是导入密钥（这个索引不会增加)
//                         brainkey_backup_date: maybe(Dat),
//                         deposit_keys: maybe(Obj),
//                             // password_checksum: Str,
//                         chain_id: Str
//                         },
//                         "WalletTcomb"
//                         );
//
//let PrivateKeyTcomb = struct(
//                             {
//                                 id: maybe(Num),                   - 非必须，仅对应key数量（1、2、3等）
//                             pubkey: Str,                      - 必须
//                             label: maybe(Str),                - 非必须
//                             import_account_names: maybe(Arr), - 非必须
//                             brainkey_sequence: maybe(Num),    - 可选（如果是直接导入密钥到钱包，这索引不存在，直接通过钱包创建密钥，才会存在。）
//                             encrypted_key: Str                - 必须
//                             },
//                             "PrivateKeyTcomb"
//                             );

#pragma mark- for WalletManager
static WalletManager *_sharedWalletManager = nil;
static int _unique_nonce_entropy = -1;              //  辅助生成 unique64 用的熵

@interface WalletManager()
{
    NSArray*                _brainkey_dictionary;           //  脑密钥字典
    
    NSDictionary*           _wallet_object_json;            //  [仅钱包模式存在] 钱包文件解密后的json
    NSString*               _wallet_password;               //  [仅钱包模式存在] 钱包密码
    NSMutableDictionary*    _private_keys_hash;             //  [钱包+账号模式都存在] 内存中存在的所有私有信息    Key：PublicKey   Value：WIFPrivateKey
}
@end

@implementation WalletManager

/**
 *  (public) 辅助生成 nonce uint64 数字
 */
+ (NSString*)genUniqueNonceUint64
{
    int entropy = [self _genUniqueNonceEntropy];
    NSTimeInterval now_sec = ceil([[NSDate date] timeIntervalSince1970]);
    uint64_t value = (uint64_t)(now_sec * 1000);
    value = (value << 8) | (entropy & 0xff);
    return [NSString stringWithFormat:@"%@", @(value)];
}

+ (int)_genUniqueNonceEntropy
{
    if (_unique_nonce_entropy < 0){
        NSData* data = [self secureRandomByte32];
        _unique_nonce_entropy = *(const char*)[data bytes];
    }else{
        _unique_nonce_entropy = (_unique_nonce_entropy + 1) % 256;
    }
    return _unique_nonce_entropy;
}

/**
 *  创建安全的随机字节(16进制返回，结果为64字节。)
 */
+ (NSString*)secureRandomByte32Hex
{
    NSData* data = [self secureRandomByte32];
    assert([data length] == 32);
    return [data hex_encode];
}

/**
 *  创建安全的随机字节
 */
+ (NSData*)secureRandomByte32
{
    struct utsname systemInfo = {0, };
    uname(&systemInfo);
    
    NSString* model = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    UIDevice* device = [UIDevice currentDevice];
    NSString* pUniqueString = [NSString stringWithFormat:@"time:%f|random:%u", [[NSDate date] timeIntervalSince1970] * 1000, arc4random()];
    NSString* entropy = [NSString stringWithFormat:@"%@|%@|%@|%@|%@",
                         model,
                         device.systemVersion,
                         device.name,
                         device.systemName,
                         pUniqueString];
    
    unsigned char digest[32] = {0, };
    unsigned char hex_output[64+1] = {0, };
    
    sha256((const unsigned char*)[entropy UTF8String], (const size_t)[entropy length], digest);
    hex_encode(digest, sizeof(digest), hex_output);
    
    NSString* d1 = [[NSString alloc] initWithBytes:hex_output length:sizeof(hex_output)-1 encoding:NSUTF8StringEncoding];
    entropy = [NSString stringWithFormat:@"ios:d1:%@|date:%@|rand:%u", d1, [NSDate date], arc4random()];
    
    sha256((const unsigned char*)[entropy UTF8String], (const size_t)[entropy length], digest);
    
    return [[NSData alloc] initWithBytes:digest length:sizeof(digest)];
}

/**
 *  (public) 随机生成私钥
 */
+ (NSString*)randomPrivateKeyWIF
{
    return [OrgUtils genBtsWifPrivateKey:[self secureRandomByte32Hex]];
}

/**
 *  (public) 【静态方法】判断给定私钥列表对于指定权限的状态（足够、部分、完整、无权限）。（active权限、owner权限）
 */
+ (EAccountPermissionStatus)calcPermissionStatus:(NSDictionary*)raw_permission_json privateKeysHash:(NSDictionary*)privateKeyHash
{
    assert(privateKeyHash);
    assert(raw_permission_json);
    NSUInteger weight_threshold = [[raw_permission_json objectForKey:@"weight_threshold"] unsignedIntegerValue];
    assert(weight_threshold > 0);
    NSUInteger curr_weights = 0;
    BOOL miss_partial_key = NO;
    id key_auths = [raw_permission_json objectForKey:@"key_auths"];
    if (key_auths && [key_auths count] > 0){
        for (id pair in key_auths) {
            assert([pair count] == 2);
            id pubkey = [pair firstObject];
            NSUInteger weight = [[pair lastObject] unsignedIntegerValue];
            if ([privateKeyHash objectForKey:pubkey]){
                curr_weights += weight;
            }else{
                miss_partial_key = YES;
            }
        }
    }
    if (curr_weights >= weight_threshold){
        if (miss_partial_key){
            //  足够权限：可以签署交易。
            return EAPS_ENOUGH_PERMISSION;
        }else{
            //  所有权限：可以签署交易。
            return EAPS_FULL_PERMISSION;
        }
    } else if (curr_weights > 0){
        //  部分权限：不可单独签署交易。
        return EAPS_PARTIAL_PERMISSION;
    } else {
        //  无权限：不可签署交易。
        return EAPS_NO_PERMISSION;
    }
}

/**
 *  (public)【静态方法】判断给定的密钥列表是否足够授权指定权限（active权限、owner权限）
 */
+ (BOOL)canAuthorizeThePermission:(NSDictionary*)raw_permission_json privateKeysHash:(NSDictionary*)privateKeyHash
{
    EAccountPermissionStatus status = [self calcPermissionStatus:raw_permission_json privateKeysHash:privateKeyHash];
    if (status == EAPS_ENOUGH_PERMISSION || status == EAPS_FULL_PERMISSION){
        return YES;
    }else{
        return NO;
    }
}

+(WalletManager *)sharedWalletManager
{
    @synchronized(self)
    {
        if(!_sharedWalletManager)
        {
            _sharedWalletManager = [[WalletManager alloc] init];
        }
        return _sharedWalletManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _brainkey_dictionary = nil;

        _wallet_object_json = nil;
        _wallet_password = nil;
        _private_keys_hash = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
}

/**
 *  判断指定帐号是否是登录帐号自身。自己的帐号返回 YES，他人的帐号返回 NO。
 */
- (BOOL)isMyselfAccount:(NSString*)account_name
{
    if (!account_name){
        return NO;
    }
    
    //  尚未登录，钱包不存在，返回NO。
    if (![self isWalletExist]){
        return NO;
    }
    
    //  帐号名字和钱包中存储的帐号名一致，则是自己的帐号。
    if ([[self getWalletAccountName] isEqualToString:account_name]){
        return YES;
    }
    
    return NO;
}

- (BOOL)isWalletExist
{
    return kwmNoWallet != [self getWalletMode];
}

/**
 *  (public) 是否缺少完整的帐号信息，在注册的时候低概率注册成功，但获取帐号信息失败了。
 */
- (BOOL)isMissFullAccountData
{
    if ([self getWalletAccountInfo]){
        return NO;
    }else{
        return YES;
    }
}

/**
 *  (public) 获取本地钱包信息
 */
- (NSDictionary*)getWalletInfo
{
    return [[AppCacheManager sharedAppCacheManager] getWalletInfo];
}

- (EWalletMode)getWalletMode
{
    return (EWalletMode)[[[self getWalletInfo] objectForKey:@"kWalletMode"] integerValue];
}

- (BOOL)isPasswordMode
{
    return [self getWalletMode] == kwmPasswordOnlyMode;
}

- (NSDictionary*)getWalletAccountInfo
{
    return [[self getWalletInfo] objectForKey:@"kAccountInfo"];
}

- (NSString*)getWalletAccountName
{
    return [[self getWalletInfo] objectForKey:@"kAccountName"];
}

- (BOOL)isLocked
{
    //  无钱包
    if (![self isWalletExist]){
        return YES;
    }
    
    //  存在钱包信息，则说明已经解锁。（钱包模式）
    if (_wallet_object_json){
        return NO;
    }
    
    //  内存中有私钥信息，则说明已解锁。（账号模式）
    if ([_private_keys_hash count] > 0){
        return NO;
    }
    
    //  锁定中
    return YES;
}

/**
 *  (public) 锁定帐号
 */
- (void)Lock
{
    _wallet_object_json = nil;
    _wallet_password = nil;
    [_private_keys_hash removeAllObjects];
}

/**
 *  (public) 解锁帐号，返回 {@"unlockSuccess":@"解锁是否成功", @"err":@"错误信息", "haveActivePermission":@"是否有足够的资金权限"}。
 */
- (NSDictionary*)unLock:(NSString*)password
{
    //  先锁定
    [self Lock];
    //  继续解锁
    EWalletMode m = [self getWalletMode];
    switch (m) {
        case kwmPasswordOnlyMode:
        {
            return [self _unLockPasswordMode:password];
        }
            break;
        case kwmPasswordWithWallet:
        case kwmPrivateKeyWithWallet:
        case kwmBrainKeyWithWallet:
        case kwmFullWalletMode:
        {
            return [self _unLockFullWallet:password];
        }
            break;
        default:
        {
            return @{@"unlockSuccess":@NO, @"err":[NSString stringWithFormat:NSLocalizedString(@"kWalletUnlockFailedUnknowMode", @"解锁失败，未知的帐号模式：%@。"), @(m)]};
        }
            break;
    }
    assert(false);
    return nil;
}

/**
 *  (public) 刷新解锁信息（仅针对钱包模式）
 */
- (NSDictionary*)reUnlock
{
    assert(_wallet_password);
    return [self unLock:_wallet_password];
}

/**
 *  (private) 解锁：密码模式
 */
- (NSDictionary*)_unLockPasswordMode:(NSString*)password
{
    assert(password);
    assert([self isPasswordMode]);
    
    id full_data = [self getWalletAccountInfo];
    if (!full_data){
        return @{@"unlockSuccess":@NO, @"haveActivePermission":@NO, @"err":@"no account data"};
    }
    
    id account = [full_data objectForKey:@"account"];
    id account_name = [account objectForKey:@"name"];
    
    //  通过账号密码计算active和owner私钥信息。
    id active_seed = [NSString stringWithFormat:@"%@active%@", account_name, password];
    id active_private_wif = [OrgUtils genBtsWifPrivateKey:active_seed];
    id owner_seed = [NSString stringWithFormat:@"%@owner%@", account_name, password];
    id owner_private_wif = [OrgUtils genBtsWifPrivateKey:owner_seed];
    NSString* active_pubkey = [OrgUtils genBtsAddressFromWifPrivateKey:active_private_wif];
    NSString* owner_pubkey = [OrgUtils genBtsAddressFromWifPrivateKey:owner_private_wif];
    assert(active_pubkey);
    assert(owner_pubkey);
    
    //  保存到内存
    [_private_keys_hash removeAllObjects];
    [_private_keys_hash setObject:active_private_wif forKey:active_pubkey];
    [_private_keys_hash setObject:owner_private_wif forKey:owner_pubkey];
    
    if ([self canAuthorizeThePermission:[account objectForKey:@"active"]]){
        //  解锁成功 & 有权限OK
        return @{@"unlockSuccess":@YES, @"haveActivePermission":@YES, @"err":@"ok"};
    }else{
        //  解锁失败 & 权限不足：私钥不正确（即密码不正确。）
        [_private_keys_hash removeAllObjects];
        return @{@"unlockSuccess":@NO, @"haveActivePermission":@NO,
                 @"err":NSLocalizedString(@"kLoginSubmitTipsAccountPasswordIncorrect", @"密码不正确，请重新输入。")};
    }
}

/**
 *  (private) 解锁：完整钱包模式
 */
- (NSDictionary*)_unLockFullWallet:(NSString*)wallet_password
{
    assert(wallet_password);
    if (!wallet_password){
        return @{@"unlockSuccess":@NO, @"err":NSLocalizedString(@"kWalletInvalidWalletPassword", @"钱包密码无效。")};
    }
    id wallet_info = [self getWalletInfo];
    NSString* hex_wallet_bin = [wallet_info objectForKey:@"kFullWalletBin"];
    assert(hex_wallet_bin);
    if (!hex_wallet_bin){
        return @{@"unlockSuccess":@NO, @"err":NSLocalizedString(@"kWalletInvalidWalletFile", @"钱包文件无效。")};
    }
    
    _wallet_object_json = [self loadFullWalletFromHex:hex_wallet_bin wallet_password:wallet_password];
    if (!_wallet_object_json){
        return @{@"unlockSuccess":@NO, @"err":NSLocalizedString(@"kWalletIncorrectWalletPassword", @"钱包密码不正确。")};
    }
    
    NSArray* private_keys = [_wallet_object_json objectForKey:@"private_keys"];
    assert(private_keys);
    
    id wallet = [[_wallet_object_json objectForKey:@"wallet"] firstObject];
    assert(wallet);
    
    //  1、用钱包的 encryption_key 解密后的值作为密钥解密 active encrypted_key 私钥
    _wallet_password = [wallet_password copy];
    id data_encryption_buffer = [self auxAesDecryptFromHex:[wallet_password dataUsingEncoding:NSUTF8StringEncoding]
                                                      data:[wallet objectForKey:@"encryption_key"]];
    assert(data_encryption_buffer);
    
    //  2、解密钱包中存在的所有私钥。
    [_private_keys_hash removeAllObjects];
    for (id key_item in private_keys) {
        id pubkey = [key_item objectForKey:@"pubkey"];
        assert(pubkey);
        id data_private_key32 = [self auxAesDecryptFromHex:data_encryption_buffer data:[key_item objectForKey:@"encrypted_key"]];
        id private_key_wif = [OrgUtils genBtsWifPrivateKeyByPrivateKey32:data_private_key32];
        assert(private_key_wif);
        [_private_keys_hash setObject:private_key_wif forKey:pubkey];
    }
    
    id full_data = [self getWalletAccountInfo];
    if (!full_data){
        return @{@"unlockSuccess":@YES, @"haveActivePermission":@NO, @"err":NSLocalizedString(@"kWalletNoAccountData", @"无账号数据。")};
    }
    id account = [full_data objectForKey:@"account"];
    if ([self canAuthorizeThePermission:[account objectForKey:@"active"]]){
        return @{@"unlockSuccess":@YES, @"haveActivePermission":@YES, @"err":@"ok"};
    }else{
        return @{@"unlockSuccess":@YES, @"haveActivePermission":@NO, @"err":NSLocalizedString(@"kWalletPermissionNoEnough", @"权限不足。")};
    }
}

/**
 *  (public) 获取所有账号，并以“name”或者“id“作为KEY构造Hash返回。
 */
- (NSMutableDictionary*)getAllAccountDataHash:(BOOL)hashKeyIsName
{
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    
    NSString* hashKey = hashKeyIsName ? @"name" : @"id";
    id localWalletInfo = [self getWalletInfo];
    assert(localWalletInfo);
    id accountDataList = [localWalletInfo objectForKey:@"kAccountDataList"];
    if (accountDataList && [accountDataList count] > 0){
        for (id accountData in accountDataList) {
            id keyValue = [accountData objectForKey:hashKey];
            assert(keyValue);
            [result setObject:accountData forKey:keyValue];
        }
    }
    
    id currentFullAccountData = [localWalletInfo objectForKey:@"kAccountInfo"];
    if (currentFullAccountData){
        id accountData = [currentFullAccountData objectForKey:@"account"];
        id keyValue = [accountData objectForKey:hashKey];
        assert(keyValue);
        [result setObject:accountData forKey:keyValue];
    }
    
    return result;
}

/**
 *  获取钱包中所有账号列表。（仅有一个主账号。）
 *  钱包已解锁则从BIN文件账号列表字段获取，未解锁则从Cache获取。
 */
- (NSArray*)getWalletAccountNameList
{
    if ([self isLocked] || [self isPasswordMode]){
        NSMutableDictionary* result = [self getAllAccountDataHash:YES];
        assert([result count] > 0);
        return [result allKeys];
    }else{
        assert(_wallet_object_json);
        id linked_accounts = [_wallet_object_json objectForKey:@"linked_accounts"];
        assert(linked_accounts);
        assert([linked_accounts count] > 0);
        id chain_id = [ChainObjectManager sharedChainObjectManager].grapheneChainID;
        NSMutableArray* result = [NSMutableArray array];
        for (id account_item in linked_accounts) {
            if ([[account_item objectForKey:@"chainId"] isEqualToString:chain_id]){
                [result addObject:[account_item objectForKey:@"name"]];
            }
        }
        return [result copy];
    }
}

/**
 *  (public) 获取当前钱包中有完整"指定"权限的所有账号列表。REMARK：如果列表为空(所有账号都没权限)，则全部返回。
 */
- (NSArray*)getFeePayingAccountList:(BOOL)requireActivePermission
{
    //  获取所有账号
    NSArray* allAccountDataList = [[self getAllAccountDataHash:YES] allValues];
    
    //  判断本地钱包包含哪些账号的Active权限
    assert(![self isLocked]);
    NSString* permissionKey = requireActivePermission ? @"active" : @"owner";
    NSMutableArray* haveActivePermissionAccountList = [NSMutableArray array];
    for (id account_info in allAccountDataList) {
        assert(account_info);
        id permissionItem = [account_info objectForKey:permissionKey];
        if ([self canAuthorizeThePermission:permissionItem]){
            [haveActivePermissionAccountList addObject:account_info];
        }
    }
    
    //  REMARK：有满足权限的账号则仅返回满足权限的列表，否则全部返回。
    if ([haveActivePermissionAccountList count] > 0){
        return [haveActivePermissionAccountList copy];
    }else{
        return allAccountDataList;
    }
}


/**
 *  是否存在指定公钥的私钥对象。
 */
- (BOOL)havePrivateKey:(NSString*)publicKey
{
    assert(![self isLocked]);
    return !![_private_keys_hash objectForKey:publicKey];
}

/**
 *  (public) 判断指定权限是否需要多签。
 */
+ (BOOL)isMultiSignPermission:(id)raw_permission_json
{
    assert(raw_permission_json);
    //  账号参与多签
    id account_auths = [raw_permission_json objectForKey:@"account_auths"];
    if (account_auths && [account_auths count] > 0){
        return YES;
    }
    
    //  地址多签（几乎没用到）
    id address_auths = [raw_permission_json objectForKey:@"address_auths"];
    if (address_auths && [address_auths count] > 0){
        return YES;
    }
    
    //  私钥参与多签
    id key_auths = [raw_permission_json objectForKey:@"key_auths"];
    if (key_auths && [key_auths count] >= 2){
        return YES;
    }
    
    //  普通权限：无多签
    return NO;
}

/**
 *  (public) 判断指定账号否需要多签。
 */
+ (BOOL)isMultiSignAccount:(NSDictionary*)account_data
{
    assert(account_data);
    
    //  Active 权限多签
    id active = [account_data objectForKey:@"active"];
    assert(active);
    if ([self isMultiSignPermission:active]){
        return YES;
    }
    
    //  Owner 权限多签
    id owner = [account_data objectForKey:@"owner"];
    assert(owner);
    if ([self isMultiSignPermission:owner]){
        return YES;
    }
    
    //  普通账号：无多签
    return NO;
}

/**
 *  (public) 提取账号数据中所有公钥数据。
 */
+ (NSMutableDictionary*)getAllPublicKeyFromAccountData:(NSDictionary*)account_data result:(NSMutableDictionary*)result
{
    assert(account_data);
    if (!result){
        result = [NSMutableDictionary dictionary];
    }
    id active = [account_data objectForKey:@"active"];
    id owner = [account_data objectForKey:@"owner"];
    assert(active);
    assert(owner);
    id active_key_auths = [active objectForKey:@"key_auths"];
    id owner_key_auths = [owner objectForKey:@"key_auths"];
    assert(active_key_auths);
    assert(owner_key_auths);
    for (id item in active_key_auths) {
        assert([item count] == 2);
        [result setObject:@YES forKey:[item firstObject]];
    }
    for (id item in owner_key_auths) {
        assert([item count] == 2);
        [result setObject:@YES forKey:[item firstObject]];
    }
    id options = [account_data objectForKey:@"options"];
    assert(options);
    [result setObject:@YES forKey:options[@"memo_key"]];
    return result;
}

/**
 *  获取本地钱包中需要参与【指定权限、active或owner等】签名的必须的 公钥列表。
 */
- (NSArray*)getSignKeys:(NSDictionary*)raw_permission_json
{
    assert(![self isLocked]);
    assert(raw_permission_json);
    
    NSMutableArray* result = [NSMutableArray array];
    
    NSUInteger weight_threshold = [[raw_permission_json objectForKey:@"weight_threshold"] unsignedIntegerValue];
    assert(weight_threshold > 0);
    
    NSUInteger curr_weights = 0;
    id key_auths = [raw_permission_json objectForKey:@"key_auths"];
    if (key_auths && [key_auths count] > 0){
        for (id pair in key_auths) {
            assert([pair count] == 2);
            id pubkey = [pair firstObject];
            NSUInteger weight = [[pair lastObject] unsignedIntegerValue];
            if ([self havePrivateKey:pubkey]){
                [result addObject:pubkey];
                curr_weights += weight;
                if (curr_weights >= weight_threshold){
                    break;
                }
            }
        }
    }
    
    //  确保权限足够（返回的KEY签名之后的阈值之后达到触发阈值）
    assert([self canAuthorizeThePermission:raw_permission_json]);
    
    return [result copy];
}

/**
 *  根据手续费支付账号ID获取本地钱包中需要参与签名的 公钥列表。REMARK：手续费支付账号应该在本地钱包中存在。
 */
- (NSArray*)getSignKeysFromFeePayingAccount:(NSString*)fee_paying_account
{
    return [self getSignKeysFromFeePayingAccount:fee_paying_account requireOwnerPermission:NO];
}
- (NSArray*)getSignKeysFromFeePayingAccount:(NSString*)fee_paying_account requireOwnerPermission:(BOOL)requireOwnerPermission
{
    NSString* permissionKey = requireOwnerPermission ? @"owner" : @"active";
    
    assert(fee_paying_account);
    id accountDataList = [[self getWalletInfo] objectForKey:@"kAccountDataList"];
    if (accountDataList && [accountDataList count] > 0){
        for (id accountData in accountDataList) {
            if ([[accountData objectForKey:@"id"] isEqualToString:fee_paying_account]){
                return [self getSignKeys:[accountData objectForKey:permissionKey]];
            }
        }
    }
    
    //  没有 kAccountDataList 字段则获取当前完整账号信息。（账号模式可能不存在 kAccountDataList 字段。）
    id currentFullData = [self getWalletAccountInfo];
    if (currentFullData){
        id accountData = [currentFullData objectForKey:@"account"];
        if (accountData && [[accountData objectForKey:@"id"] isEqualToString:fee_paying_account]){
            return [self getSignKeys:[accountData objectForKey:permissionKey]];
        }
    }
    
    //  not reached...
    assert(false);
    return nil;
}

/**
 *  是否有足够的权限状态判断。（本地钱包中的私钥是否足够签署交易，否则视为提案交易。）
 */
- (EAccountPermissionStatus)calcPermissionStatus:(NSDictionary*)raw_permission_json
{
    assert(![self isLocked]);
    assert(_private_keys_hash);
    return [[self class] calcPermissionStatus:raw_permission_json privateKeysHash:_private_keys_hash];
}

/**
 *  本地钱包的密钥是否足够授权指定权限（active权限、owner权限）
 */
- (BOOL)canAuthorizeThePermission:(NSDictionary*)raw_permission_json
{
    assert(![self isLocked]);
    assert(_private_keys_hash);
    return  [[self class] canAuthorizeThePermission:raw_permission_json privateKeysHash:_private_keys_hash];
}

/**
 *  (public) 用一组私钥签名交易。成功返回签名数据的数组，失败返回 nil。
 */
- (NSArray*)signTransaction:(NSData*)sign_buffer signKeys:(NSArray*)pubKeyList
{
    assert(sign_buffer);
    assert(pubKeyList && [pubKeyList count] > 0);
    //  未解锁 返回失败
    if ([self isLocked]){
        return nil;
    }
    NSMutableArray* result = [NSMutableArray array];
    unsigned char private_key32[32] = {0, };
    unsigned char signature65[65] = {0, };
    for (id pubKey in pubKeyList) {
        NSString* private_key_wif = [_private_keys_hash objectForKey:pubKey];
        assert(private_key_wif);
        //  生成原始私钥
        bool ret = __bts_gen_private_key_from_wif_privatekey((const unsigned char*)[private_key_wif UTF8String],
                                                             (const size_t)private_key_wif.length, private_key32);
        if (!ret){
            //  私钥无效
            return nil;
        }
        //  签名
        ret = __bts_sign_buffer([sign_buffer bytes], [sign_buffer length], private_key32, signature65);
        if (!ret){
            //  签名失败
            return nil;
        }
        [result addObject:[[NSData alloc] initWithBytes:signature65 length:sizeof(signature65)]];
    }
    return [result copy];
}

/**
 *  (public) 加密并生成 memo 信息结构体，失败返回 nil。
 */
- (NSDictionary*)genMemoObject:(NSString*)memo_string from_public:(NSString*)from_public to_public:(NSString*)to_public
{
    assert(![self isLocked]);
    assert(memo_string);
    assert(from_public);
    assert(to_public);
    
    //  1、获取和 from_public 对应的备注私钥
    NSString* from_public_private_key_wif = [_private_keys_hash objectForKey:from_public];
    if (!from_public_private_key_wif){
        return nil;
    }
    
    unsigned char memo_private_key32[32] = {0, };
    bool ret = __bts_gen_private_key_from_wif_privatekey((const unsigned char*)[from_public_private_key_wif UTF8String],
                                                         (const size_t)from_public_private_key_wif.length, memo_private_key32);
    if (!ret){
        return nil;
    }
    
    //  2、获取接收方的公钥
    secp256k1_pubkey pubkey={0,};
    ret = __bts_gen_public_key_from_b58address((const unsigned char*)[to_public UTF8String], (const size_t)[to_public length],
                                                    [[ChainObjectManager sharedChainObjectManager].grapheneAddressPrefix length], 
                                                    &pubkey);
    if (!ret){
        //  TODO:fowallet 统计错误
        return nil;
    }
    
    //  3、生成加密用 nonce
    id nonce = [[self class] genUniqueNonceUint64];
    
    NSData* message_data = [memo_string dataUsingEncoding:NSUTF8StringEncoding];
    size_t message_size = (size_t)[message_data length];
    const unsigned char* message = (const unsigned char*)[message_data bytes];
    size_t output_size = __bts_aes256_encrypt_with_checksum_calc_outputsize(message_size);
    unsigned char output[output_size];
    
    //  4、加密
    ret =__bts_aes256_encrypt_with_checksum(memo_private_key32, &pubkey, [nonce UTF8String], [nonce length], message, message_size, output);
    if (!ret){
        //  TODO:fowallet 统计错误
        return nil;
    }
    
    //  REMARK：加密后的 data 不能 json 序列化的，需要hexencode，否则会crash。
    id memo_data = [[NSData alloc] initWithBytes:output length:output_size];
    assert(memo_data);
    
    //  返回
    return @{@"from":from_public, @"to":to_public, @"nonce":nonce, @"message":memo_data};
}

#pragma mark- for wallet manager

/**
 *  (public) 加载完成钱包文件
 */
- (NSDictionary*)loadFullWalletFromHex:(NSString*)hex_wallet_bin wallet_password:(NSString*)wallet_password
{
    return [self loadFullWallet:[OrgUtils hexDecode:hex_wallet_bin] wallet_password:wallet_password];
}

- (NSDictionary*)loadFullWallet:(NSData*)wallet_bin wallet_password:(NSString*)wallet_password
{
    assert(wallet_bin);
    size_t final_output_size = 0;
    unsigned char* output_data = __bts_load_wallet((const unsigned char*)[wallet_bin bytes], (const size_t)[wallet_bin length],
                                                   (const unsigned char*)[wallet_password UTF8String], (const size_t)[wallet_password length],
                                                   &final_output_size);
    if (!output_data){
        //  TODO:fowallet 目前暂时无法区分 无效的钱包文件 or 密码不正确
        return nil;
    }
    
    id data = [[NSData alloc] initWithBytes:output_data length:final_output_size];
    
    //  释放内存
    free(output_data);
    output_data = 0;
    
    //  解析JSON
    NSError* err = nil;
    id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
    if (err || !response){
        return nil;
    }
    
    return response;
}

/**
 *  (public) 在当前“已解锁”的钱包中移除账号和私钥数据。
 */
- (NSData*)walletBinRemoveAccount:(NSString*)accountName pubkeyList:(NSArray*)pubkeyList
{
    assert(![self isPasswordMode]);
    assert(![self isLocked]);
    assert(_wallet_object_json);
    
    //  账号和公钥至少存在一个。
    assert(accountName || (pubkeyList && [pubkeyList count] > 0));
    
    //  1、构造 linked_accounts
    id old_linked_accounts = [_wallet_object_json objectForKey:@"linked_accounts"];
    assert(old_linked_accounts);
    assert([old_linked_accounts count] > 0);
    //  钱包中的账号列表默认为之前的老账号。
    NSArray* final_linked_accounts = old_linked_accounts;
    if (accountName){
        NSMutableArray* new_linked_accounts = [NSMutableArray array];
        id chain_id = [ChainObjectManager sharedChainObjectManager].grapheneChainID;
        for (NSDictionary* account in old_linked_accounts) {
            if (![[account objectForKey:@"chainId"] isEqualToString:chain_id] || ![[account objectForKey:@"name"] isEqualToString:accountName]){
                //  保留
                [new_linked_accounts addObject:account];
            }
        }
        //  设置钱包中的账号列表。
        final_linked_accounts = [new_linked_accounts copy];
        //  最后一个账号不可删除。
        assert([final_linked_accounts count] > 0);
    }
    
    id old_wallet = [[_wallet_object_json objectForKey:@"wallet"] firstObject];
    assert(old_wallet);
    
    //  2、构造 private_keys
    id old_private_keys = [_wallet_object_json objectForKey:@"private_keys"];
    assert(old_private_keys);
    NSArray* final_private_keys = old_private_keys;
    if (pubkeyList && [pubkeyList count] > 0){
        assert(_wallet_password);
        
        NSMutableDictionary* remove_pubkey_hash = [NSMutableDictionary dictionary];
        for (id pubkey in pubkeyList) {
            [remove_pubkey_hash setObject:@YES forKey:pubkey];
        }
        
        NSMutableArray* new_private_keys = [NSMutableArray array];
        for (id item in old_private_keys) {
            id pubkey = [item objectForKey:@"pubkey"];
            assert(pubkey);
            if (![[remove_pubkey_hash objectForKey:pubkey] boolValue]){
                //  保留
                [new_private_keys addObject:item];
            }
        }
        
        //  设置私钥列表。
        final_private_keys = [new_private_keys copy];
    }
    
    //  3、构造 wallet
    NSString* last_modified = [self genWalletTimeString:ceil([[NSDate date] timeIntervalSince1970])];
    id new_wallet = [old_wallet mutableCopy];
    [new_wallet setObject:last_modified forKey:@"last_modified"];
    
    //  4、final object
    id final_object = @{
                        @"linked_accounts":final_linked_accounts,
                        @"private_keys":final_private_keys,
                        @"wallet":@[[new_wallet copy]],
                        };
    
    //  5、创建二进制钱包并返回
    return [self _genFullWalletData:final_object walletPassword:_wallet_password];
}

/**
 *  (public) 在当前“已解锁”的钱包中导入账号or私钥数据。REMARK：如果导入的账号名已经存在则设置为当前账号。
 */
- (NSData*)walletBinImportAccount:(NSString*)accountName privateKeyWifList:(NSArray*)privateKeyWifList
{
    assert(![self isPasswordMode]);
    assert(![self isLocked]);
    assert(_wallet_object_json);
    
    //  导入账号和导入私钥至少存在一个。
    assert(accountName || (privateKeyWifList && [privateKeyWifList count] > 0));
    
    //  1、构造 linked_accounts
    id old_linked_accounts = [_wallet_object_json objectForKey:@"linked_accounts"];
    assert(old_linked_accounts);
    assert([old_linked_accounts count] > 0);
    //  钱包中的账号列表默认为之前的老账号。
    NSArray* final_linked_accounts = old_linked_accounts;
    if (accountName){
        NSMutableArray* new_linked_accounts = [NSMutableArray array];
        //  导入账号 or 设置当前账号
        id chain_id = [ChainObjectManager sharedChainObjectManager].grapheneChainID;
        NSDictionary* exist_account_item = nil;
        for (NSDictionary* account in old_linked_accounts) {
            if ([[account objectForKey:@"chainId"] isEqualToString:chain_id] &&
                [[account objectForKey:@"name"] isEqualToString:accountName]){
                exist_account_item = account;
            }else{
                [new_linked_accounts addObject:account];
            }
        }
        if (exist_account_item){
            //  账号已经存在：则调整到首位，设置为当前账号。
            [new_linked_accounts insertObject:exist_account_item atIndex:0];
        }else{
            //  账号不存在：新增，放到末尾。
            id new_linked_account = @{
                                      @"chainId":chain_id,
                                      @"name":accountName
                                      };
            [new_linked_accounts addObject:new_linked_account];
        }
        //  设置钱包中的账号列表。
        final_linked_accounts = [new_linked_accounts copy];
    }

    id old_wallet = [[_wallet_object_json objectForKey:@"wallet"] firstObject];
    assert(old_wallet);
    
    //  2、构造 private_keys
    id old_private_keys = [_wallet_object_json objectForKey:@"private_keys"];
    assert(old_private_keys);
    NSArray* final_private_keys = old_private_keys;
    if (privateKeyWifList && [privateKeyWifList count] > 0){
        assert(_wallet_password);
        NSMutableDictionary* exist_pubkey_hash = [NSMutableDictionary dictionary];
        NSMutableArray* new_private_keys = [NSMutableArray array];
        for (id item in old_private_keys) {
            id pubkey = [item objectForKey:@"pubkey"];
            assert(pubkey);
            [new_private_keys addObject:item];
            [exist_pubkey_hash setObject:@YES forKey:pubkey];
        }
        
        //  1、用钱包的 encryption_key 解密后的值作为密钥解密 active encrypted_key 私钥
        id data_encryption_buffer = [self auxAesDecryptFromHex:[_wallet_password dataUsingEncoding:NSUTF8StringEncoding]
                                                          data:[old_wallet objectForKey:@"encryption_key"]];
        assert(data_encryption_buffer);
        
        unsigned char private_key32_array[32];
        for (NSString* private_wif in privateKeyWifList) {
            id pubkey = [OrgUtils genBtsAddressFromWifPrivateKey:private_wif];
            assert(pubkey);
            if (!pubkey){
                continue;
            }
            //  已存在，不用重复导入。
            if ([[exist_pubkey_hash objectForKey:pubkey] boolValue]){
                continue;
            }
            if (!__bts_gen_private_key_from_wif_privatekey((const unsigned char*)[private_wif UTF8String],
                                                           (const size_t)private_wif.length, private_key32_array)){
                continue;
            }
            id encrypted_key = [self auxAesEncryptToHex:data_encryption_buffer
                                                   data:[[NSData alloc] initWithBytes:private_key32_array length:sizeof(private_key32_array)]];
            if (!encrypted_key){
                continue;
            }
            [new_private_keys addObject:@{@"id":@([new_private_keys count] + 1), @"encrypted_key":encrypted_key, @"pubkey":pubkey}];
            [exist_pubkey_hash setObject:@YES forKey:pubkey];
        }
        //  设置私钥列表。
        final_private_keys = [new_private_keys copy];
    }
    
    //  3、构造 wallet
    NSString* last_modified = [self genWalletTimeString:ceil([[NSDate date] timeIntervalSince1970])];
    id new_wallet = [old_wallet mutableCopy];
    [new_wallet setObject:last_modified forKey:@"last_modified"];
    
    //  4、final object
    id final_object = @{
                        @"linked_accounts":final_linked_accounts,
                        @"private_keys":final_private_keys,
                        @"wallet":@[[new_wallet copy]],
                        };
    
    //  5、创建二进制钱包并返回
    return [self _genFullWalletData:final_object walletPassword:_wallet_password];
}

/**
 *  (private) 通过钱包文件JSON对象创建完整钱包对象。直接返回二进制bin。
 */
- (NSData*)_genFullWalletData:(NSDictionary*)walletObject walletPassword:(NSString*)walletPassword
{
    assert(walletObject);
    assert(walletPassword);
    
    NSError* err = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:walletObject
                                                   options:NSJSONReadingAllowFragments
                                                     error:&err];
    if (err || !data){
        NSLog(@"serialization simple wallet failed, %@", err);
        return nil;
    }
    
    size_t output_size = 0;
    NSString* entropy = [[self class] secureRandomByte32Hex];
    unsigned char* output_data = __bts_save_wallet((const unsigned char*)[data bytes], (const size_t)[data length],
                                                   (const unsigned char*)[walletPassword UTF8String], (const size_t)[walletPassword length],
                                                   (const unsigned char*)[entropy UTF8String], (const size_t)[entropy length],
                                                   &output_size);
    if (!output_data || !output_size){
        NSLog(@"save wallet failed...");
        return nil;
    }
    
    id wallet_bin = [[NSData alloc] initWithBytes:output_data length:output_size];
    
    //  释放内存
    free(output_data);
    output_data = 0;
    
    return wallet_bin;
}

/**
 *  (public) 创建完整钱包对象。直接返回二进制bin。
 */
- (NSData*)genFullWalletData:(NSString*)account_name
            private_wif_keys:(NSArray*)private_wif_keys
             wallet_password:(NSString*)wallet_password
{
    //  生成json格式钱包
    id full_wallet_object = [self genFullWalletObject:account_name
                                     private_wif_keys:private_wif_keys
                                      wallet_password:wallet_password];
    if (!full_wallet_object){
        NSLog(@"gen full wallet failed...");
        return nil;
    }
    
    //  生成二进制格式钱包
    return [self _genFullWalletData:full_wallet_object walletPassword:wallet_password];
}

/**
 *  (public) 创建完整钱包对象。
 */
- (NSDictionary*)genFullWalletObject:(NSString*)account_name
                    private_wif_keys:(NSArray*)private_wif_keys
                     wallet_password:(NSString*)wallet_password
{
    assert(account_name);
    assert(wallet_password);
    
    //  --- 1、生成&加密 核心密钥（用钱包密码（即交易密码）进行加密）
    //  生成：核心密钥seed（用于加密钱包里的活跃密钥、帐号密钥、脑密钥(一大串助记符)等）
    
    //  TODO:fowallet 错误统计
    
    //  1、随机生成主密码
    NSData* encryption_buffer32 = [[self class] secureRandomByte32];
    
    //  2、主密码（用钱包密码加密）
    NSString* encryption_key = [self auxAesEncryptToHex:[wallet_password dataUsingEncoding:NSUTF8StringEncoding] data:encryption_buffer32];
    if (!encryption_key){
        return nil;
    }
    
    //  3、用主密码加密 owner、active、memo、brain等所有信息。
    
    //  part1
    NSMutableArray* private_keys = [NSMutableArray array];
    unsigned char private_key32_array[32];
    for (NSString* private_wif in private_wif_keys) {
        if (!private_wif || [private_wif isEqualToString:@""]){
            continue;
        }
        id pubkey = [OrgUtils genBtsAddressFromWifPrivateKey:private_wif];
        assert(pubkey);
        if (!pubkey){
            return nil;
        }
        if (!__bts_gen_private_key_from_wif_privatekey((const unsigned char*)[private_wif UTF8String],
                                                       (const size_t)private_wif.length, private_key32_array)){
            return nil;
        }
        id encrypted_key = [self auxAesEncryptToHex:encryption_buffer32
                                               data:[[NSData alloc] initWithBytes:private_key32_array length:sizeof(private_key32_array)]];
        if (!encrypted_key){
            return nil;
        }
        [private_keys addObject:@{@"id":@([private_keys count] + 1), @"encrypted_key":encrypted_key, @"pubkey":pubkey}];
    }
    
    //  4、生成脑密钥
    NSString* brainkey_plaintext = [self suggestBrainKey];
    id brainkey_pubkey = [OrgUtils genBtsAddressFromPrivateKeySeed:brainkey_plaintext];
    id encrypted_brainkey = [self auxAesEncryptToHex:encryption_buffer32 data:[brainkey_plaintext dataUsingEncoding:NSUTF8StringEncoding]];
    if (!encrypted_brainkey){
        return nil;
    }
    
    //  5、开始构造完成钱包结构
    NSString* wallet_password_address = [OrgUtils genBtsAddressFromPrivateKeySeed:wallet_password];
    if (!wallet_password_address){
        return nil;
    }
    NSString* created_time = [self genWalletTimeString:ceil([[NSDate date] timeIntervalSince1970])];
    
    //  part2
    id linked_account = @{
                          @"chainId":[ChainObjectManager sharedChainObjectManager].grapheneChainID,
                          @"name":account_name
                          };
    
    //  part3
    id wallet = @{
                  @"public_name":@"default",
                  @"created":created_time,
                  @"last_modified":created_time,
                  //@"backup_date":@"",         //  刚创建不存在该字段
                  
                  @"password_pubkey":wallet_password_address,
                  @"encryption_key":encryption_key,
                  @"encrypted_brainkey":encrypted_brainkey,
                  
                  @"brainkey_pubkey":brainkey_pubkey,
                  @"brainkey_sequence":@0,
                  
                  @"chain_id":[ChainObjectManager sharedChainObjectManager].grapheneChainID,
                  @"author":@"BTS++",           //  add by btspp team
                  };
    
    id final_object = @{
                        @"linked_accounts":@[linked_account],
                        @"private_keys":[private_keys copy],
                        @"wallet":@[wallet],
                        };
    
    //  返回
    return final_object;
}

/**
 *  (public) 格式化时间戳为BTS官方钱包中的日期格式。格式：2018-07-15T01:45:19.731Z。
 */
- (NSString*)genWalletTimeString:(NSTimeInterval)time_secs
{
    //  当前时间
    if (time_secs <= 0){
        time_secs = ceil([[NSDate date] timeIntervalSince1970]);
    }
    
    //  REMARM：日期格式化为 1970-01-01T00:00:00 格式
    NSDate* d = [NSDate dateWithTimeIntervalSince1970:time_secs];
    
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    //  设置时区，按照UTC（0时区）格式化。
    [dateFormat setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    NSString* ds = [dateFormat stringFromDate:d];
    
    //  默认添加 .000（毫秒） 和 时区 Z。
    return [ds stringByAppendingString:@".000Z"];
}

/**
 *  (public) 根据脑密钥单词字符串生成对应的WIF格式私钥（脑密钥字符串作为seed）。
 */
- (NSString*)genBrainKeyPrivateWIF:(NSString*)brainKeyPlainText
{
    assert(brainKeyPlainText);
    brainKeyPlainText = [[self class] normalizeBrainKey:brainKeyPlainText];
    return [OrgUtils genBtsWifPrivateKey:brainKeyPlainText];
}

/**
 *  (public) 根据脑密钥单词字符串 和 HD子密钥索引编号 生成WIF格式私钥。REMARK：sha512(brainKey + " " + seq)作为seed。
 */
+ (NSString*)genPrivateKeyFromBrainKey:(NSString*)brainKeyPlainText sequence:(NSInteger)sequence
{
    assert(sequence >= 0);
    brainKeyPlainText = [self normalizeBrainKey:brainKeyPlainText];
    NSString* str = [NSString stringWithFormat:@"%@ %@", brainKeyPlainText, @(sequence)];
    
    NSData* str_data = [str dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char digest64[64] = {0, };
    sha512((const unsigned char*)[str_data bytes], (const size_t)[str_data length], digest64);
    
    return [OrgUtils genBtsWifPrivateKey:digest64 size:sizeof(digest64)];
}

/**
 *  (public) 随机生成脑密钥
 */
- (NSString*)suggestBrainKey
{
    NSArray* dictionary = [self _load_brainkey_dictionary];
    assert(dictionary);
    
    id randomBuffer = [[self class] secureRandomByte32];
    const unsigned char* bytes = [randomBuffer bytes];
    
    NSMutableArray* brainkey = [NSMutableArray array];
    
    int word_count = 16;
    int end = word_count * 2;
    double base = 65536.0;   // base = pow(2, 16)
    for (int i = 0; i < end; i += 2) {
        int num = (bytes[i] << 8) + bytes[i + 1];
        //  0...1
        double rndMultiplier = (double)num / base;
        assert(rndMultiplier < 1);
        int wordIndex = (int)round([dictionary count] * rndMultiplier);
        assert(wordIndex < [dictionary count]);
        [brainkey addObject:[dictionary objectAtIndex:wordIndex]];
    }
    return [[self class] normalizeBrainKey:[brainkey componentsJoinedByString:@" "]];
}

/**
 *  (public) 归一化脑密钥，按照不可见字符切分字符串，然后用标准空格连接。
 */
+ (NSString*)normalizeBrainKey:(NSString*)brainKey
{
    assert(brainKey);
    
    //  方便匹配正则，末尾添加一个空格作为不可见自负。
    brainKey = [brainKey stringByAppendingString:@" "];
    NSMutableArray* words = [NSMutableArray array];
    
    NSString* pattern = @"(\\S+)([\\s]+)";
    NSRegularExpression* regular = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray* matches = [regular matchesInString:brainKey options:0 range:NSMakeRange(0, brainKey.length)];
    if ([matches count] > 0){
        for (id match in matches) {
            //  取正则第一个括号匹配的值，索引1。索引0是匹配的整体。
            NSString* word = [brainKey substringWithRange:[match rangeAtIndex:1]];
            [words addObject:word];
        }
    }else{
        assert(NO);
    }
    
    //  返回
    return [words componentsJoinedByString:@" "];
}

//  (private) 辅助函数 - 加载脑密钥词典
- (NSArray*)_load_brainkey_dictionary
{
    if (!_brainkey_dictionary){
        NSString* bundlePath = [NSBundle mainBundle].resourcePath;
        NSString* fullPathInApp = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, kAppStaticDir, @"wallet_dictionary_en.json"];
        NSData* data = [NSData dataWithContentsOfFile:fullPathInApp];
        assert(data);
        NSString* rawdatajson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        assert(rawdatajson);
        id json = [NSJSONSerialization JSONObjectWithData:[rawdatajson dataUsingEncoding:NSUTF8StringEncoding]
                                                  options:NSJSONReadingAllowFragments error:nil];
        assert(json);
        id dictionary_string = [json objectForKey:@"en"];
        assert(dictionary_string);
        _brainkey_dictionary = [dictionary_string componentsSeparatedByString:@","];
        assert(_brainkey_dictionary);
    }
    return _brainkey_dictionary;
}

/**
 *  (public) 辅助 - Aes256加密，并返回16进制字符串，密钥 seed。
 */
- (NSString*)auxAesEncryptToHex:(NSData*)seed data:(NSData*)data
{
    assert(seed);
    assert(data);
    if (!data){
        return nil;
    }
    const size_t srcsize = [data length];
    size_t hexoutput_size = __bts_aes256_calc_output_size(srcsize) * 2;
    unsigned char hexoutput[hexoutput_size+1];
    bool result = __bts_aes256_encrypt_to_hex((const unsigned char*)[seed bytes], (const size_t)[seed length],
                                              (const unsigned char*)[data bytes], srcsize, hexoutput);
    if (!result){
        NSLog(@"encrypt_to_hex failed...");
        return nil;
    }
    id ret = [[NSString alloc] initWithBytes:hexoutput length:hexoutput_size encoding:NSUTF8StringEncoding];
    assert(ret);
    return ret;
}

/**
 *  (public) 辅助 - Aes256解密，输入16进制字符串，密钥 seed。
 */
- (NSData*)auxAesDecryptFromHex:(NSData*)seed data:(NSString*)hexdata
{
    assert(seed);
    assert(hexdata);
    if (!hexdata){
        return nil;
    }
    const size_t hexdata_size = [hexdata length];
    assert((hexdata_size % 2) == 0);
    size_t output_size = hexdata_size / 2;
    unsigned char output[output_size];
    bool result = __bts_aes256_decrypt_from_hex((const unsigned char*)[seed bytes], (const size_t)[seed length],
                                                (const unsigned char*)[hexdata UTF8String], hexdata_size, output, &output_size);
    if (!result){
        NSLog(@"decrypt_from_hex failed...");
        return nil;
    }
    id ret = [[NSData alloc] initWithBytes:output length:output_size];
    assert(ret);
    return ret;
}

@end
