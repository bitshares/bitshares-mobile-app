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
