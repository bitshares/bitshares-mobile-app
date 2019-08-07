//
//  VCCommonLogic.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//
#import "VCBase.h"
#import "VCCommonLogic.h"
#import "VCUserAssets.h"
#import "VCUserOrders.h"
#import "WalletManager.h"
#import "OrgUtils.h"

@implementation VCCommonLogic

+ (void)viewUserLimitOrders:(VCBase*)this account:(NSString*)account_id tradingPair:(TradingPair*)tradingPair
{
    //  [统计]
    [OrgUtils logEvents:@"event_view_userlimitorders" params:@{@"account":account_id}];
    
    [this showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  1、查帐号数据
    WsPromise* p1 = [[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:account_id];
    
    //  2、帐号历史
    GrapheneApi* api_history = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_history;
    
    //  !!!! TODO:fowallet可以历史记录，方便继续查询。考虑添加。 if (history && history.size) most_recent = history.first().get("id");
    //  查询最新的 100 条记录。
    id stop = [NSString stringWithFormat:@"1.%@.0", @(ebot_operation_history)];
    id start = [NSString stringWithFormat:@"1.%@.0", @(ebot_operation_history)];
    //  start - 从指定ID号往前查询（包含该ID号），如果指定ID为0，则从最新的历史记录往前查询。结果包含 start。
    //  stop  - 指定停止查询ID号（结果不包含该ID），如果指定为0，则查询到最早的记录位置（or达到limit停止。）结果不包含该 stop ID。
    WsPromise* p2 = [api_history exec:@"get_account_history" params:@[account_id, stop, @100, start]];
    
    //  查询全部
    [[[WsPromise all:@[p1, p2]] then:(^id(id data_array) {
        id full_account_data = [data_array objectAtIndex:0];
        id account_history = [data_array objectAtIndex:1];
        
        NSMutableDictionary* asset_id_hash = [NSMutableDictionary dictionary];
        //  限价单
        id limit_orders = [full_account_data objectForKey:@"limit_orders"];
        if (limit_orders && [limit_orders count] > 0){
            for (id order in limit_orders) {
                id sell_price = [order objectForKey:@"sell_price"];
                [asset_id_hash setObject:@YES forKey:[[sell_price objectForKey:@"base"] objectForKey:@"asset_id"]];
                [asset_id_hash setObject:@YES forKey:[[sell_price objectForKey:@"quote"] objectForKey:@"asset_id"]];
            }
        }
        
        //  成交历史
        NSMutableArray* tradeHistory = [NSMutableArray array];
        if (account_history && [account_history count] > 0){
            for (id history in account_history) {
                id op = [history objectForKey:@"op"];
                if ([[op firstObject] integerValue] == ebo_fill_order){
                    [tradeHistory addObject:history];
                    id fill_info = [op objectAtIndex:1];
                    [asset_id_hash setObject:@YES forKey:[[fill_info objectForKey:@"pays"] objectForKey:@"asset_id"]];
                    [asset_id_hash setObject:@YES forKey:[[fill_info objectForKey:@"receives"] objectForKey:@"asset_id"]];
                }
            }
        }
        
        //  查询 & 缓存
        return [[[ChainObjectManager sharedChainObjectManager] queryAllAssetsInfo:[asset_id_hash allKeys]] then:(^id(id asset_hash) {
            [this hideBlockView];
            //  忽略该参数 asset_hash，因为 ChainObjectManager 已经缓存。
            VCUserOrdersPages* vc = [[VCUserOrdersPages alloc] initWithUserFullInfo:full_account_data tradeHistory:tradeHistory tradingPair:tradingPair];
            vc.title = NSLocalizedString(@"kVcTitleOrderManagement", @"订单管理");
            [this pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
            return nil;
        })];
    })] catch:(^id(id error) {
        [this hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

+ (void)viewUserAssets:(VCBase*)this account:(NSString*)account_name_or_id
{
    //  [统计]
    [OrgUtils logEvents:@"event_view_userassets" params:@{@"account":account_name_or_id}];
    
    [this showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [[[chainMgr queryFullAccountInfo:account_name_or_id] then:(^id(id full_account_data) {
        NSLog(@"%@", full_account_data);
        
        NSDictionary* userAssetDetailInfos = [OrgUtils calcUserAssetDetailInfos:full_account_data];
        NSArray* args = [[userAssetDetailInfos objectForKey:@"validBalancesHash"] allKeys];
        NSArray* debt_asset_ids = [[userAssetDetailInfos objectForKey:@"debtValuesHash"] allKeys];
        
        //  查询所有资产信息
        return [[chainMgr queryAllAssetsInfo:args] then:(^id(id asset_hash) {
            id debt_bitasset_data_id_list = [debt_asset_ids ruby_map:(^id(id debt_asset_id) {
                return [chainMgr getChainObjectByID:debt_asset_id][@"bitasset_data_id"];
            })];
            
            //  查询所有智能资产的喂价和MCR、MSSR等信息
            return [[chainMgr queryAllGrapheneObjects:debt_bitasset_data_id_list] then:(^id(id data) {
                [this hideBlockView];
                
                VCAccountInfoPages* vc = [[VCAccountInfoPages alloc] initWithUserAssetDetailInfos:userAssetDetailInfos
                                                                                        assetHash:asset_hash
                                                                                      accountInfo:full_account_data];
                
                id target_name = [[full_account_data objectForKey:@"account"] objectForKey:@"name"];
                if ([[WalletManager sharedWalletManager] isMyselfAccount:target_name]){
                    vc.title = NSLocalizedString(@"kVcTitleMyBalance", @"我的资产");
                }else{
                    vc.title = target_name;
                }
                
                [this pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
                return nil;
            })];
        })];
    })] catch:(^id(id error) {
        [this hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

/**
 *  根据私钥登录（导入）区块链账号。
 */
+ (void)onLoginWithKeysHash:(VCBase*)this
                       keys:(NSDictionary*)pub_pri_keys_hash
      checkActivePermission:(BOOL)checkActivePermission
             trade_password:(NSString*)pTradePassword
                 login_mode:(EWalletMode)login_mode
                 login_desc:(NSString*)login_desc
    errMsgInvalidPrivateKey:(NSString*)errMsgInvalidPrivateKey errMsgActivePermissionNotEnough:(NSString*)errMsgActivePermissionNotEnough
{
    assert([pub_pri_keys_hash count] > 0);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    [this showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[chainMgr queryAccountDataHashFromKeys:[pub_pri_keys_hash allKeys]] then:(^id(id account_data_hash) {
        if ([account_data_hash count] <= 0){
            [this hideBlockView];
            [OrgUtils makeToast:errMsgInvalidPrivateKey];
            return nil;
        }
        id account_data_list = [account_data_hash allValues];
        //  TODO:一个私钥关联多个账号
#ifndef DEBUG
        if ([account_data_list count] >= 2){
            NSString* name_join_strings = [[account_data_list ruby_map:(^id(id src) {
                return [src objectForKey:@"name"];
            })] componentsJoinedByString:@","];
            CLS_LOG(@"ONE KEY %@ ACCOUNTS: %@", @([account_data_list count]), name_join_strings);
        }
#endif
        //  默认选择第一个账号 TODO:弹框选择一个
        id account_data = [account_data_list firstObject];
        return [[chainMgr queryFullAccountInfo:account_data[@"id"]] then:(^id(id full_data) {
            [this hideBlockView];
            
            if (!full_data || [full_data isKindOfClass:[NSNull class]])
            {
                //  这里的帐号信息应该存在，因为帐号ID是通过 get_key_references 返回的。
                [OrgUtils makeToast:NSLocalizedString(@"kLoginImportTipsQueryAccountFailed", @"查询帐号信息失败，请稍后再试。")];
                return nil;
            }
            
            //  获取账号数据
            id account = [full_data objectForKey:@"account"];
            NSString* accountName = account[@"name"];
            
            //  验证Active权限，导入钱包时不验证。
            if (checkActivePermission){
                //  获取active权限数据
                id account_active = [account objectForKey:@"active"];
                assert(account_active);
                
                //  检测权限是否足够签署需要active权限的交易。
                EAccountPermissionStatus status = [WalletManager calcPermissionStatus:account_active
                                                                      privateKeysHash:pub_pri_keys_hash];
                if (status == EAPS_NO_PERMISSION){
                    [OrgUtils makeToast:errMsgInvalidPrivateKey];
                    return nil;
                }else if (status == EAPS_PARTIAL_PERMISSION){
                    [OrgUtils makeToast:errMsgActivePermissionNotEnough];
                    return nil;
                }
            }
            
            //  筛选账号 account 所有公钥对应的私钥。（即：有效私钥）
            NSMutableDictionary* account_all_pubkeys = [WalletManager getAllPublicKeyFromAccountData:account result:nil];
            NSMutableArray* valid_private_wif_keys = [NSMutableArray array];
            for (NSString* pubkey in pub_pri_keys_hash) {
                if ([[account_all_pubkeys objectForKey:pubkey] boolValue]){
                    [valid_private_wif_keys addObject:[pub_pri_keys_hash objectForKey:pubkey]];
                }
            }
            assert([valid_private_wif_keys count] > 0);
            
            if (!checkActivePermission){
                //  导入账号到现有钱包BIN文件中
                id full_wallet_bin = [[WalletManager sharedWalletManager] walletBinImportAccount:accountName
                                                                               privateKeyWifList:[valid_private_wif_keys copy]];
                assert(full_wallet_bin);
                [[AppCacheManager sharedAppCacheManager] updateWalletBin:full_wallet_bin];
                [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                //  重新解锁（即刷新解锁后的账号信息）。
                id unlockInfos = [[WalletManager sharedWalletManager] reUnlock];
                assert(unlockInfos && [[unlockInfos objectForKey:@"unlockSuccess"] boolValue]);
                
                //  返回
                [TempManager sharedTempManager].importToWalletDirty = YES;
                [this.myNavigationController tempDisableDragBack];
                [OrgUtils showMessageUseHud:NSLocalizedString(@"kWalletImportSuccess", @"导入完成")
                                       time:1
                                     parent:this.navigationController.view
                            completionBlock:^{
                                [this.myNavigationController tempEnableDragBack];
                                [this.navigationController popViewControllerAnimated:YES];
                            }];
            }else{
                //  创建完整钱包模式
                id full_wallet_bin = [[WalletManager sharedWalletManager] genFullWalletData:accountName
                                                                           private_wif_keys:[valid_private_wif_keys copy]
                                                                            wallet_password:pTradePassword];
                
                //  保存钱包信息
                [[AppCacheManager sharedAppCacheManager] setWalletInfo:login_mode
                                                           accountInfo:full_data
                                                           accountName:accountName
                                                         fullWalletBin:full_wallet_bin];
                [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                //  导入成功 用交易密码 直接解锁。
                id unlockInfos = [[WalletManager sharedWalletManager] unLock:pTradePassword];
                assert(unlockInfos &&
                       [[unlockInfos objectForKey:@"unlockSuccess"] boolValue] &&
                       [[unlockInfos objectForKey:@"haveActivePermission"] boolValue]);
                //  [统计]
                [OrgUtils logEvents:@"loginEvent" params:@{@"mode":@(login_mode), @"desc":login_desc ?: @"unknown"}];
                
                //  返回
                [this.myNavigationController tempDisableDragBack];
                [OrgUtils showMessageUseHud:NSLocalizedString(@"kLoginTipsLoginOK", @"登录成功。")
                                       time:1
                                     parent:this.navigationController.view
                            completionBlock:^{
                                [this.myNavigationController tempEnableDragBack];
                                [this.navigationController popViewControllerAnimated:YES];
                            }];
            }
            return nil;
        })];
    })] catch:(^id(id error) {
        [this hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    })];
}

+ (void)showPicker:(VCBase*)this selectAsset:(NSArray*)assets title:(NSString*)title callback:(void (^)(id selectItem))callback
{
    NSArray* itemlist = [assets ruby_map:(^id(id src) {
        return [src objectForKey:@"symbol"];
    })];
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:this
                                                       message:title
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:itemlist
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
         if (buttonIndex != cancelIndex){
             callback([assets objectAtIndex:buttonIndex]);
         }
     }];
}

+ (void)showPicker:(VCBase*)this
      object_lists:(NSArray*)object_lists
               key:(NSString*)key
             title:(NSString*)title
          callback:(void (^)(id selectItem))callback
{
    NSArray* itemlist = [object_lists ruby_map:(^id(id src) {
        return [src objectForKey:key];
    })];
    
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:this
                                                       message:title
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:itemlist
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
         if (buttonIndex != cancelIndex){
             callback([object_lists objectAtIndex:buttonIndex]);
         }
     }];
}

@end
