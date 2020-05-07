//
//  VCStealthTransferHelper.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//
#import "VCStealthTransferHelper.h"

#import "VCBase.h"
#import "VCSelectBlindBalance.h"

#import "GrapheneSerializer.h"
#import "GraphenePublicKey.h"

#import "Extension.h"

@implementation VCStealthTransferHelper

/*
 *  (public) 尝试解析隐私收据字符串为 json 格式。不是有效的收据则返回nil，成功返回 json 对象。
 *  支持两种收据字符串：
 *  1、APP收据字符串。
 *  2、cli命令行钱包收据字符串。
 */
+ (id)guessBlindReceiptString:(NSString*)base58_string
{
    if (!base58_string || base58_string.length <= 0) {
        return nil;
    }
    
    NSData* raw_data = [base58_string base58_decode];
    if (!raw_data || raw_data.length <= 0) {
        return nil;
    }
    
    //  1、尝试解析APP收据     收据格式 = base58(json(@{kAppBlindReceiptBlockNum:@"xxx"}))
    id app_receipt_json = [OrgUtils parse_json:raw_data];
    if (app_receipt_json && [app_receipt_json objectForKey:kAppBlindReceiptBlockNum]) {
        return app_receipt_json;
    }
    
    //  2、尝试解析cli命令行收据格式    收据格式 = base58(序列化(stealth_confirmation))
    @try {
        return [T_stealth_confirmation parse:raw_data];
    } @catch (NSException *exception) {
        NSLog(@"not stealth_memo data. guess failed.");
        return nil;
    }
    return nil;
}

/*
 *  (public) 根据 to_public_key 和 数量生成一个【隐私输出】。
 */
+ (NSDictionary*)genOneBlindOutput:(GraphenePublicKey*)to_public_key
                          n_amount:(NSDecimalNumber*)n_amount
                             asset:(id)asset
                     num_of_output:(NSUInteger)num_of_output
                 used_blind_factor:(NSData*)used_blind_factor
{
    assert(to_public_key);
    assert(n_amount);
    
    GraphenePrivateKey* one_time_key = [[GraphenePrivateKey alloc] initRandom];
    GraphenePublicKey* one_time_pub_key = [one_time_key getPublicKey];
    const secp256k1_prikey* one_time_key_secp256k1 = [one_time_key getKeyData];
    
    digest_sha512 secret;
    digest_sha256 child;
    blind_factor_type nonce;
    blind_factor_type blind_factor;
    
    [one_time_key getSharedSecret:to_public_key output:&secret];
    sha256(secret.data, sizeof(secret.data), child.data);
    sha256(one_time_key_secp256k1->data, sizeof(one_time_key_secp256k1->data), nonce.data);
    if (used_blind_factor) {
        //  使用指定的盲因子
        assert(sizeof(blind_factor.data) == used_blind_factor.length);
        memcpy(blind_factor.data, used_blind_factor.bytes, sizeof(blind_factor.data));
    } else {
        //  根据 child 自动生成。
        sha256(child.data, sizeof(child.data), blind_factor.data);
    }
    
    //  生成 blind_output 子属性：承诺
    id amount = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:[asset[@"precision"] integerValue]]];
    uint64_t i_amount = [amount unsignedLongLongValue];
    commitment_type commitment = {0, };
    __bts_gen_pedersen_commit(&commitment, &blind_factor, i_amount);
    
    //  生成 blind_output 子属性：范围证明（仅多个输出时才需要，单个输出不需要。）
    id range_proof = nil;
    if (num_of_output > 1) {
        unsigned char proof[5134];
        int proof_len = sizeof(proof);
        __bts_gen_range_proof_sign(0, &commitment, &blind_factor, &nonce, 0, 0, i_amount, proof, &proof_len);
        range_proof = [[NSData alloc] initWithBytes:proof length:proof_len];
    } else {
        range_proof = [NSData data];
    }
    
    id data_blind_factor = [[NSData alloc] initWithBytes:blind_factor.data length:sizeof(blind_factor.data)];
    id data_commitment = [[NSData alloc] initWithBytes:commitment.data length:sizeof(commitment.data)];
    
    //  生成 blind_output 子属性：owner
    id out_owner = @{
        @"weight_threshold":@1,
        @"account_auths":@[],
        @"key_auths":@[@[[[to_public_key child:&child] toWifString], @1]],
        @"address_auths":@[]
    };
    
    id decrypted_memo = @{
        //  @"from": @"",
        @"amount":@{@"asset_id":[asset objectForKey:@"id"], @"amount":@(i_amount)},
        @"blinding_factor": data_blind_factor,
        @"commitment": data_commitment,
        @"check": @(*(uint32_t*)&secret.data[0])
    };
    
    id blind_output = @{
        @"commitment": data_commitment,
        @"range_proof": range_proof,
        @"owner": out_owner,
        @"stealth_memo": @{
                @"one_time_key": [one_time_pub_key toWifString],
                //  REMARK：这里不直接存储 to_public_key，为了隐藏 to_public_key，与承诺一起生成新的公钥存储，仅为验证用。
                //  如果省略 to 字段，则不方便验证该 output 的所属。
                @"to": [[to_public_key genToToTo:data_commitment] toWifString],
                @"encrypted_memo":[[T_stealth_confirmation_memo_data encode_to_bytes:decrypted_memo] aes256cbc_encrypt:&secret]
        }
    };
    
    //  REMARK：仅作为收据保存。
    id blind_balance = @{
        @"real_to_key": [to_public_key toWifString],
        @"one_time_key": [[blind_output objectForKey:@"stealth_memo"] objectForKey:@"one_time_key"],
        @"to": [[blind_output objectForKey:@"stealth_memo"] objectForKey:@"to"],
        @"decrypted_memo": @{
                @"amount": [decrypted_memo objectForKey:@"amount"],
                @"blinding_factor": [[decrypted_memo objectForKey:@"blinding_factor"] hex_encode],
                @"commitment": [[decrypted_memo objectForKey:@"commitment"] hex_encode],
                @"check": [decrypted_memo objectForKey:@"check"]
        }
    };
    
    return @{
        @"blind_output": blind_output,
        @"blind_factor": data_blind_factor,
        @"blind_balance": blind_balance
    };
}

/*
 *  (public) 生成隐私输出参数。
 */
+ (id)genBlindOutputs:(NSArray*)data_array_output asset:(NSDictionary*)asset input_blinding_factors:(NSArray*)input_blinding_factors
{
    assert(data_array_output);
    assert(asset);
    
    NSMutableArray* receipt_array = [NSMutableArray array];
    NSUInteger num_of_output = [data_array_output count];
    for (id item in data_array_output) {
        //  REMARK：包含 blind_input 的情况下，新的 blind_output 的最后一个需要计算求和。
        //  1-output: BF1 + BF2 + BF3 = SUM(BF1 + BF2 + BF3)
        //  2-output: BF1 + BF2 + BF3 = BF4 + SUM(BF1 + BF2 + BF3) - BF4
        //  3-output: BF1 + BF2 + BF3 = BF5 + BF6 + SUM(BF1 + BF2 + BF3) - BF5 - BF6
        NSData* final_blind_factor = nil;
        if (input_blinding_factors && [input_blinding_factors count] > 0 && [receipt_array count] + 1 == num_of_output) {
            //  最后一个blind_output的盲化因子需要求和
            size_t n = [input_blinding_factors count] + [receipt_array count];
            const unsigned char* blinds[n];
            NSInteger idx = 0;
            for (NSData* input_blind_factor in input_blinding_factors) {
                blinds[idx++] = input_blind_factor.bytes;
            }
            for (id item in receipt_array) {
                blinds[idx++] = ((NSData*)[item objectForKey:@"blind_factor"]).bytes;
            }
            blind_factor_type result = {0, };
            __bts_gen_pedersen_blind_sum(blinds, n, (uint32_t)[input_blinding_factors count], &result);
            final_blind_factor = [[NSData alloc] initWithBytes:result.data length:sizeof(result.data)];
        }
        
        [receipt_array addObject:[self genOneBlindOutput:[GraphenePublicKey fromWifPublicKey:[item objectForKey:@"public_key"]]
                                                n_amount:[item objectForKey:@"n_amount"]
                                                   asset:asset
                                           num_of_output:num_of_output
                                       used_blind_factor:final_blind_factor]];
    }
    
    NSMutableArray* blind_outputs = [NSMutableArray array];
    for (id item in receipt_array) {
        [blind_outputs addObject:[item objectForKey:@"blind_output"]];
    }
    
    [blind_outputs sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        id c1 = [obj1 objectForKey:@"commitment"];
        id c2 = [obj2 objectForKey:@"commitment"];
        return [[c1 hex_encode] compare:[c2 hex_encode]];
    })];
    
    return @{
        @"receipt_array": receipt_array,
        @"blind_outputs": [blind_outputs copy]
    };
}

/*
 *  (public) 生成隐私输入参数。成功返回数组，失败返回 nil。
 *  extra_pub_pri_hash - 附近私钥Hash KEY：WIF_PUB_KEY   VALUE：GraphenePrivateKey*
 */
+ (NSArray*)genBlindInputs:(NSArray*)data_array_input
   output_blinding_factors:(NSMutableArray*)output_blinding_factors
                 sign_keys:(NSMutableDictionary*)sign_keys
        extra_pub_pri_hash:(NSDictionary*)extra_pub_pri_hash
{
    assert(data_array_input);
    assert(sign_keys);
    
    NSMutableArray* inputs = [NSMutableArray array];
    
    for (id blind_balance in data_array_input) {
        id to_pub = [blind_balance objectForKey:@"real_to_key"];
        GraphenePrivateKey* to_pri = [[WalletManager sharedWalletManager] getGraphenePrivateKeyByPublicKey:to_pub];
        if (!to_pri && extra_pub_pri_hash) {
            to_pri = [extra_pub_pri_hash objectForKey:to_pub];
        }
        if (!to_pri) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrMissingReceiptPriKey", @"缺少收据私钥。")];
            return nil;
        }
        
        GraphenePublicKey* one_time_key = [GraphenePublicKey fromWifPublicKey:[blind_balance objectForKey:@"one_time_key"]];
        assert(one_time_key);
        
        digest_sha512 secret = {0, };
        if (![to_pri getSharedSecret:one_time_key output:&secret]) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcStTipErrInvalidBlindBalance", @"收据信息无效。")];
            return nil;
        }
        digest_sha256 child = {0, };
        sha256(secret.data, sizeof(secret.data), child.data);
        GraphenePrivateKey* child_prikey = [to_pri child:&child];
        id child_to_pub = [[child_prikey getPublicKey] toWifString];
        
        id decrypted_memo = [blind_balance objectForKey:@"decrypted_memo"];
        id input = @{
            @"commitment":[[decrypted_memo objectForKey:@"commitment"] hex_decode],
            @"owner":@{
                    @"weight_threshold":@1,
                    @"account_auths":@[],
                    @"key_auths":@[@[child_to_pub, @1]],
                    @"address_auths":@[]
            },
        };
        
        [inputs addObject:input];
        
        if (output_blinding_factors) {
            [output_blinding_factors addObject:[[decrypted_memo objectForKey:@"blinding_factor"] hex_decode]];
        }
        
        [sign_keys setObject:child_to_pub forKey:[child_prikey toWifString]];
    }
    
    //  排序
    [inputs sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        id c1 = [obj1 objectForKey:@"commitment"];
        id c2 = [obj2 objectForKey:@"commitment"];
        return [[c1 hex_encode] compare:[c2 hex_encode]];
    })];
    
    return [inputs copy];
}

/*
 *  (public) 对盲化因子数组求和，所有的都作为【正】因子对待。
 */
+ (NSData*)blindSum:(NSArray*)blinding_factors_array
{
    assert(blinding_factors_array);
    
    size_t n = [blinding_factors_array count];
    assert(n > 0);
    
    const unsigned char* blinds[n];
    
    NSInteger idx = 0;
    for (NSData* blinding_factor in blinding_factors_array) {
        blinds[idx++] = blinding_factor.bytes;
    }
    
    blind_factor_type result = {0, };
    __bts_gen_pedersen_blind_sum(blinds, n, (uint32_t)n, &result);
    
    return [[NSData alloc] initWithBytes:result.data length:sizeof(result.data)];
}

/*
 *  (public) 选择收据（隐私交易的的 input 部分）
 */
+ (void)processSelectReceipts:(VCBase*)this
     curr_blind_balance_arary:(NSArray*)curr_blind_balance_arary
                     callback:(void (^)(id new_blind_balance_array))callback
{
    assert(callback);
    [this delay:^{
        NSMutableDictionary* default_selected = [NSMutableDictionary dictionary];
        if (curr_blind_balance_arary && [curr_blind_balance_arary count] > 0) {
            for (id blind_balance in curr_blind_balance_arary) {
                id commitment = [[blind_balance objectForKey:@"decrypted_memo"] objectForKey:@"commitment"];
                assert([commitment isKindOfClass:[NSString class]]);
                [default_selected setObject:@YES forKey:commitment];
            }
        }
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCSelectBlindBalance* vc = [[VCSelectBlindBalance alloc] initWithResultPromise:result_promise default_selected:[default_selected copy]];
        [this pushViewController:vc
                         vctitle:NSLocalizedString(@"kVcTitleSelectBlindBalance", @"选择隐私收据")
                       backtitle:kVcDefaultBackTitleName];
        [result_promise then:(^id(id new_blind_balance_array) {
            assert(new_blind_balance_array);
            callback(new_blind_balance_array);
            return nil;
        })];
    }];
}

@end
