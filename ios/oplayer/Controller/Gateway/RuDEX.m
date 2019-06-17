//
//  RuDEX.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "RuDEX.h"
#import "OrgUtils.h"

@interface RuDEX()
{
}

@end

@implementation RuDEX

- (void)dealloc
{
}

- (WsPromise*)queryCoinList
{
    id api_base = [self.api_config_json objectForKey:@"base"];
    id coin_list = [self.api_config_json objectForKey:@"coin_list"];
    assert(coin_list);
    
    return [OrgUtils asyncFetchUrl:[NSString stringWithFormat:@"%@%@", api_base, coin_list] args:nil];
}

- (NSArray*)processCoinListData:(NSArray*)data_array balanceHash:(NSDictionary*)balanceHash
{
    //{
    //    backingCoin = PPY;
    //    confirmations =     {
    //        type = irreversible;
    //    };
    //    depositAllowed = 1;
    //    description = "PeerPlays currency";
    //    gatewayWallet = "rudex-gateway";
    //    issuer = "rudex-ppy";
    //    issuerId = "1.2.353611";
    //    memoSupport = 1;
    //    minAmount = 20000;
    //    name = Peerplays;
    //    precision = 5;
    //    symbol = PPY;
    //    walletType = peerplays;
    //    withdrawalAllowed = 1;
    //},
    NSMutableArray* result = [NSMutableArray array];
    if (data_array && [data_array isKindOfClass:[NSArray class]] && [data_array count] > 0){
        for (id item in data_array) {
            BOOL enableDeposit = [[item objectForKey:@"depositAllowed"] boolValue];
            BOOL enableWithdraw = [[item objectForKey:@"withdrawalAllowed"] boolValue];
            NSDecimalNumber* n_minAmount = [NSDecimalNumber decimalNumberWithMantissa:[item[@"minAmount"] unsignedLongLongValue]
                                                                             exponent:-[item[@"precision"] integerValue]
                                                                           isNegative:NO];
            //  网络确认数
            NSString* confirm_block_number = @"";
            id confirmations = [item objectForKey:@"confirmations"];
            if (confirmations && [[[confirmations objectForKey:@"type"] lowercaseString] isEqualToString:@"blocks"]){
                confirm_block_number = [NSString stringWithFormat:@"%@", [confirmations objectForKey:@"value"]];
            }
            
            NSString* symbol = [item[@"symbol"] uppercaseString];
            assert(symbol);
            assert(balanceHash);
            id balance_item = [balanceHash objectForKey:symbol] ?: @{@"iszero":@YES};
            
            GatewayAssetItemData* appext = [[GatewayAssetItemData alloc] init];
            appext.enableWithdraw = enableWithdraw;
            appext.enableDeposit = enableDeposit;
            appext.symbol = symbol;
            appext.backSymbol = [item[@"backingCoin"] uppercaseString];
            appext.name = item[@"name"];
            appext.intermediateAccount = item[@"issuerId"] ?: item[@"issuer"];
            appext.balance = balance_item;
            appext.depositMinAmount = [NSString stringWithFormat:@"%@", n_minAmount];
            appext.withdrawMinAmount = [NSString stringWithFormat:@"%@", n_minAmount];
            appext.withdrawGateFee = @"";
            appext.supportMemo = [[item objectForKey:@"memoSupport"] boolValue];
            appext.confirm_block_number = confirm_block_number;
            appext.coinType = item[@"symbol"];
            appext.backingCoinType = item[@"backingCoin"];
            
            id new_item = [item mutableCopy];
            [new_item setObject:appext forKey:@"kAppExt"];
            [result addObject:[new_item copy]];
        }
    }
    return result;
}

- (WsPromise*)requestDepositAddress:(id)item fullAccountData:(id)fullAccountData vc:(VCBase*)vc
{
    assert(item);
    GatewayAssetItemData* appext = [item objectForKey:@"kAppExt"];
    assert(appext);
    
    id account_data = [fullAccountData objectForKey:@"account"];
    
    //  if memo not supported - should request deposit address
    if (![[item objectForKey:@"memoSupport"] boolValue]){
        id walletType = [item objectForKey:@"walletType"];
        assert(walletType);
        id request_deposit_address_base = [self.api_config_json objectForKey:@"request_deposit_address"];
        id final_url = [NSString stringWithFormat:@"%@%@", self.api_config_json[@"base"],
                        [NSString stringWithFormat:request_deposit_address_base, walletType]];
        
        return [self requestDepositAddressCore:item
                                        appext:appext
                   request_deposit_address_url:final_url
                             full_account_data:fullAccountData
                                            vc:vc];
    }
    
    //  if support memo (memo is fixed now = dex:bitshares-account-name eg. dex:btsacc)
    NSString* inputAddress = nil;
    id gatewayWallet = [item objectForKey:@"gatewayWallet"];
    if (gatewayWallet && ![gatewayWallet isEqualToString:@""]){
        inputAddress = gatewayWallet;
    }
    id account_name = account_data[@"name"];
    NSString* inputMemo = [NSString stringWithFormat:@"dex:%@", account_name];
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        if (inputAddress){
            id depositItem = @{
                               @"inputAddress":inputAddress,
                               @"inputCoinType":[appext.backingCoinType lowercaseString],
                               @"inputMemo":inputMemo,
                               @"outputAddress":account_name,
                               @"outputCoinType":[appext.coinType lowercaseString],
                               };
            resolve(depositItem);
        }else{
            resolve(NSLocalizedString(@"kVcDWErrTipsRequestDepositAddrFailed", @"获取充币地址异常，请联系网关客服。"));
        }
    }];
}

/**
 *  验证地址、备注、数量是否有效
 */
- (WsPromise*)checkAddress:(id)item address:(NSString*)address memo:(NSString*)memo amount:(NSString*)amount
{
    //  TODO:仅验证地址
    
    id walletType = [item objectForKey:@"walletType"];
    assert(walletType);
    
    id check_address_base = [self.api_config_json objectForKey:@"check_address"];
    id final_url = [NSString stringWithFormat:@"%@%@", self.api_config_json[@"base"],
                    [NSString stringWithFormat:check_address_base, walletType]];
    
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        id post_args = @{
                         @"address":address,
                         };
        [[[OrgUtils asyncPostUrl_jsonBody:final_url args:post_args] then:(^id(id resp_data) {
            if (resp_data && [resp_data isKindOfClass:[NSDictionary class]] && [[resp_data objectForKey:@"isValid"] boolValue]){
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

@end

