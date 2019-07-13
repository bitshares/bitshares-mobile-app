//
//  OpenLedger.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "OpenLedger.h"
#import "OrgUtils.h"
#import "VCBase.h"

@interface OpenLedger()
{
}

@end

@implementation OpenLedger

- (void)dealloc
{
}

- (WsPromise*)queryCoinList
{
    id api_base = [self.api_config_json objectForKey:@"base"];
    id assets = [self.api_config_json objectForKey:@"assets"];
    assert(assets);
    id exchanges = [self.api_config_json objectForKey:@"exchanges"];
    assert(exchanges);
    id p1 = [OrgUtils asyncFetchUrl:[NSString stringWithFormat:@"%@%@", api_base, assets] args:nil];
    id p2 = [OrgUtils asyncFetchUrl:[NSString stringWithFormat:@"%@%@", api_base, exchanges] args:nil];
    return [WsPromise all:@[p1, p2]];
}

- (NSArray*)processCoinListData:(NSArray*)data_array balanceHash:(NSDictionary*)balanceHash
{
    //  [asset]
    //{
    //    blockchain = bitshares;
    //    code = BTS;
    //    "display_code" = BTS;
    //    "display_name" = Bitshares;
    //    icons =     {
    //        large = "https://s2.coinmarketcap.com/static/img/coins/64x64/463.png";
    //        medium = "https://s2.coinmarketcap.com/static/img/coins/64x64/463.png";
    //        small = "https://s2.coinmarketcap.com/static/img/coins/64x64/463.png";
    //    };
    //    show =     {
    //        "openledger_dex_gateway" = 1;
    //    };
    //},
    
    //  exchange
    //{
    //    amount =     {
    //        destination =         {
    //            max = 50000000;
    //            min = "0.0001";
    //            mul = 0;
    //        };
    //        source =         {
    //            max = 5000000;
    //            min = "1e-08";
    //            mul = 0;
    //        };
    //    };
    //    destination =     {
    //        asset = "OPEN.DOGE";
    //        blockchain = bitshares;
    //    };
    //    fee =     {
    //        source =         {
    //            "fiat_currency" = "<null>";
    //            type = 0;
    //            value = 0;
    //        };
    //    };
    //    icon =     {
    //        destination =         {
    //            large = "https://s2.coinmarketcap.com/static/img/coins/64x64/74.png";
    //            medium = "https://s2.coinmarketcap.com/static/img/coins/64x64/74.png";
    //            small = "https://s2.coinmarketcap.com/static/img/coins/64x64/74.png";
    //        };
    //        source =         {
    //            large = "https://s2.coinmarketcap.com/static/img/coins/64x64/74.png";
    //            medium = "https://s2.coinmarketcap.com/static/img/coins/64x64/74.png";
    //            small = "https://s2.coinmarketcap.com/static/img/coins/64x64/74.png";
    //        };
    //    };
    //    id = 2;
    //    limit =     {
    //        source =         {
    //            24h = 49509208;
    //            once = 49509208;
    //        };
    //    };
    //    memo =     {
    //        destination =         {
    //            enabled = 1;
    //            label = Memo;
    //        };
    //        source =         {
    //            enabled = 0;
    //            label = "";
    //        };
    //    };
    //    options =     {
    //        comment = "";
    //        "default_destination_for_source" = 1;
    //        healthy = 1;
    //        "maintenance_reason" = "";
    //        show =         {
    //            "openledger_dex_gateway" = 1;
    //        };
    //        status = 2;
    //    };
    //    rate = 1;
    //    source =     {
    //        asset = DOGE;
    //        blockchain = dogecoin;
    //    };
    //},
    
    id data_assets = [data_array objectAtIndex:0];
    id data_exchanges = [data_array objectAtIndex:1];
    //  任意一个接口不可用都算失败。
    if (!data_assets || [data_assets isKindOfClass:[NSNull class]]){
        return nil;
    }
    if (!data_exchanges || [data_exchanges isKindOfClass:[NSNull class]]){
        return nil;
    }
    
    NSMutableDictionary* deposit_hash = [NSMutableDictionary dictionary];
    NSMutableDictionary* withdraw_hash = [NSMutableDictionary dictionary];
    for (id item in data_exchanges) {
        id src = [item objectForKey:@"source"];
        id dst = [item objectForKey:@"destination"];
        assert(src && dst);
        if (!src || !dst){
            continue;
        }
        if ([[[src objectForKey:@"blockchain"] lowercaseString] isEqualToString:@"bitshares"]){
            //  withdraw: bitshares to others
            assert([src objectForKey:@"asset"]);
            [withdraw_hash setObject:item forKey:[src objectForKey:@"asset"]];
        }else if ([[[dst objectForKey:@"blockchain"] lowercaseString] isEqualToString:@"bitshares"]){
            //  deposit: others to bitshares
            assert([dst objectForKey:@"asset"]);
            [deposit_hash setObject:item forKey:[dst objectForKey:@"asset"]];
        }
    }

    NSMutableArray* result = [NSMutableArray array];
    for (id item in data_assets) {
        if (![[[item objectForKey:@"blockchain"] lowercaseString] isEqualToString:@"bitshares"]){
            continue;
        }
        
        id asset_symbol = [item objectForKey:@"code"];
        assert(asset_symbol);
        if (!asset_symbol){
            continue;
        }
        
        id withdraw_item = [withdraw_hash objectForKey:asset_symbol];
        id deposit_item = [deposit_hash objectForKey:asset_symbol];
        if (!withdraw_item || !deposit_item){
            continue;
        }
        
        //  status: 0 - disabled, 1 - functions in manual mode, 2 - functions in automatic mode
        id deposit_options = [deposit_item objectForKey:@"options"];
        id withdraw_options = [withdraw_item objectForKey:@"options"];
        BOOL enableWithdraw = [[withdraw_options objectForKey:@"healthy"] boolValue] && [[withdraw_options objectForKey:@"status"] integerValue] != 0;
        BOOL enableDeposit = [[deposit_options objectForKey:@"healthy"] boolValue] && [[deposit_options objectForKey:@"status"] integerValue] != 0;
        
        //  细节参考: https://github.com/bitshares/bitshares-ui/pull/2573/commits/8cc40ece6026b24a9becd0bf305b858e6d0d66c5
        id deposit_amount = [[deposit_item objectForKey:@"amount"] objectForKey:@"source"];
        id withdraw_amount = [[withdraw_item objectForKey:@"amount"] objectForKey:@"destination"];
        id deposit_limit = [[deposit_item objectForKey:@"limit"] objectForKey:@"source"];
        id withdraw_limit = [[withdraw_item objectForKey:@"limit"] objectForKey:@"source"];
        
        NSString* symbol = [asset_symbol uppercaseString];
        assert(symbol);
        assert(balanceHash);
        id balance_item = [balanceHash objectForKey:symbol] ?: @{@"iszero":@YES};
        id backingCoin = [[[withdraw_item objectForKey:@"destination"] objectForKey:@"asset"] uppercaseString];

        GatewayAssetItemData* appext = [[GatewayAssetItemData alloc] init];
        appext.enableWithdraw = enableWithdraw;
        appext.enableDeposit = enableDeposit;
        appext.symbol = symbol;
        appext.backSymbol = backingCoin;
        appext.name = item[@"display_name"];
        appext.intermediateAccount = nil;   //  nil
        appext.balance = balance_item;
        appext.depositMinAmount = [self auxValueToNumberString:[deposit_amount objectForKey:@"min"] zero_as_nil:YES];
        appext.withdrawMinAmount = [self auxValueToNumberString:[withdraw_amount objectForKey:@"min"] zero_as_nil:YES];
        appext.withdrawGateFee = [self auxValueToNumberString:[[[withdraw_item objectForKey:@"fee"] objectForKey:@"source"] objectForKey:@"value"]
                                                  zero_as_nil:YES];
        appext.supportMemo = [[[[withdraw_item objectForKey:@"memo"] objectForKey:@"destination"] objectForKey:@"enabled"] boolValue];
        appext.confirm_block_number = nil;
        appext.coinType = symbol;
        appext.backingCoinType = backingCoin;
        appext.withdrawMaxAmountOnce = [self auxMinValue:[withdraw_amount objectForKey:@"max"]
                                                 value02:[withdraw_limit objectForKey:@"once"]
                                             zero_as_nil:YES];
        appext.withdrawMaxAmount24Hours = [self auxValueToNumberString:[withdraw_limit objectForKey:@"24h"] zero_as_nil:YES];
        appext.depositMaxAmountOnce = [self auxMinValue:[deposit_amount objectForKey:@"max"]
                                                value02:[deposit_limit objectForKey:@"once"]
                                            zero_as_nil:YES];
        appext.depositMaxAmount24Hours = [self auxValueToNumberString:[deposit_limit objectForKey:@"once"] zero_as_nil:YES];
        
        appext.open_withdraw_item = withdraw_item;
        appext.open_deposit_item = deposit_item;
        
        id new_item = [item mutableCopy];
        [new_item setObject:appext forKey:@"kAppExt"];
        [result addObject:[new_item copy]];
    }

    return result;
}

- (WsPromise*)requestDepositAddress:(id)item fullAccountData:(id)fullAccountData vc:(VCBase*)vc
{
    assert(item);
    GatewayAssetItemData* appext = [item objectForKey:@"kAppExt"];
    assert(appext);
    id deposit_item = appext.open_deposit_item;
    id exchanges_id = [deposit_item objectForKey:@"id"];
    assert(exchanges_id);
    
    id account_data = [fullAccountData objectForKey:@"account"];
    id outputAddress = [account_data objectForKey:@"name"];
    
    id request_deposit_address_base = [self.api_config_json objectForKey:@"request_deposit_address"];
    id final_url = [NSString stringWithFormat:@"%@%@", self.api_config_json[@"base"], [NSString stringWithFormat:request_deposit_address_base, exchanges_id]];
    
    id args = @{
                @"destination_address":outputAddress,
                @"destination_memo":@""
                };
    
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [vc showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[OrgUtils asyncFetchUrl:final_url args:args] then:(^id(id resp_data) {
            [vc hideBlockView];
            //{
            //    address = xxxaddress;
            //    memo = "<null>";
            //}
            if (resp_data && [resp_data isKindOfClass:[NSDictionary class]]){
                id addr = [resp_data objectForKey:@"address"];
                if (!addr){
                    resolve(NSLocalizedString(@"kVcDWErrTipsRequestDepositAddrFailed", @"获取充币地址异常，请联系网关客服。"));
                    return nil;
                }
                id memo = [resp_data objectForKey:@"memo"];
                if (!memo){
                    memo = [NSNull null];
                }
                id depositItem = @{
                                   @"inputAddress":addr,
                                   @"inputCoinType":[appext.backingCoinType lowercaseString],
                                   @"inputMemo":memo,
                                   @"outputAddress":outputAddress,
                                   @"outputCoinType":[appext.coinType lowercaseString],
                                   };
                resolve(depositItem);
            }else{
                resolve(NSLocalizedString(@"kVcDWErrTipsRequestDepositAddrFailed", @"获取充币地址异常，请联系网关客服。"));
            }
            return nil;
        })] catch:(^id(id error) {
            [vc hideBlockView];
            resolve(NSLocalizedString(@"kVcDWErrTipsRequestDepositAddrFailed", @"获取充币地址异常，请联系网关客服。"));
            return nil;
        })];
    }];
}

/**
 *  验证地址、备注、数量是否有效
 */
- (WsPromise*)checkAddress:(id)item address:(NSString*)address memo:(NSString*)memo amount:(NSString*)amount
{
    //  REMARK：验证地址、备注、数量
    assert(item);
    GatewayAssetItemData* appext = [item objectForKey:@"kAppExt"];
    assert(appext);
    id exchanges_item = appext.open_withdraw_item;
    id exchanges_id = [exchanges_item objectForKey:@"id"];
    assert(exchanges_id);
    
    id validate_method = [self.api_config_json objectForKey:@"validate"];
    id final_url = [NSString stringWithFormat:@"%@%@", self.api_config_json[@"base"], [NSString stringWithFormat:validate_method, exchanges_id]];
    
    id args = @{
                @"amount":amount,
                @"recipient":address,
                @"memo":memo ?: @""
                };
    
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [[[OrgUtils asyncPostUrl_jsonBody:final_url args:args] then:(^id(id resp_data) {
            if ([[resp_data objectForKey:@"valid_amount"] boolValue] &&
                [[resp_data objectForKey:@"valid_recipient"] boolValue] &&
                [[resp_data objectForKey:@"valid_memo"] boolValue]){
                resolve(@YES);
            }else{
                resolve(@NO);
            }
            return nil;
        })] catch:(^id(id error) {
            resolve(@NO);
            return nil;
        })];
    }];
}

/**
 *  (public) 查询提币网关中间账号以及转账需要备注的memo信息。
 */
- (WsPromise*)queryWithdrawIntermediateAccountAndFinalMemo:(GatewayAssetItemData*)appext
                                                   address:(NSString*)address
                                                      memo:(NSString*)memo
                                   intermediateAccountData:(NSDictionary*)intermediateAccountData
{
    id exchanges_item = appext.open_withdraw_item;
    id exchanges_id = [exchanges_item objectForKey:@"id"];
    assert(exchanges_id);
    
    id request_deposit_address_base = [self.api_config_json objectForKey:@"request_deposit_address"];
    id final_url = [NSString stringWithFormat:@"%@%@", self.api_config_json[@"base"], [NSString stringWithFormat:request_deposit_address_base, exchanges_id]];
    
    id args = @{
                @"destination_address":address,
                @"destination_memo":memo ?: @""
                };
    
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [[[OrgUtils asyncFetchUrl:final_url args:args] then:(^id(id resp_data) {
            //{
            //    address = xxxaddress;
            //    memo = "<null>";
            //}
            if (resp_data && [resp_data isKindOfClass:[NSDictionary class]]){
                id addr = [resp_data objectForKey:@"address"];
                id memo = [resp_data objectForKey:@"memo"];
                if (!addr || !memo){
                    resolve(nil);
                    return nil;
                }
                //  继续查询账号信息
                [[[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:address] then:(^id(id full_data) {
                    if (!full_data || [full_data isKindOfClass:[NSNull class]])
                    {
                        resolve(nil);
                        return nil;
                    }
                    id depositItem = @{
                                       @"intermediateAccount":addr,
                                       @"finalMemo":memo,
                                       @"intermediateAccountData":full_data,
                                       };
                    resolve(depositItem);
                    return nil;
                })] catch:(^id(id error) {
                    resolve(nil);
                    return nil;
                })];
            }else{
                resolve(nil);
            }
            return nil;
        })] catch:(^id(id error) {
            resolve(nil);
            return nil;
        })];
    }];
}

@end

