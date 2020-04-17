//
//  VCBlindBalance.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBlindBalance.h"
#import "ViewBlindBalanceCell.h"

#import "VCBlindBalanceImport.h"
#import "VCBlindTransfer.h"
#import "VCTransferFromBlind.h"

#import "GraphenePublicKey.h"
#import "GrapheneSerializer.h"
#import "BitsharesClientManager.h"

@interface VCBlindBalance ()
{
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCBlindBalance

-(void)dealloc
{
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self){
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)refreshUI
{
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
}

/*
 *  (private) 解密 stealth_confirmation 结构中的 encrypted_memo 数据。
 */
- (id)decryptStealthConfirmationMemo:(NSDictionary*)stealth_memo private_key:(GraphenePrivateKey*)private_key
{
    assert(stealth_memo);
    assert(private_key);
    GraphenePublicKey* one_time_key = [GraphenePublicKey fromWifPublicKey:[stealth_memo objectForKey:@"one_time_key"]];
    assert(one_time_key);
    
    digest_sha512 secret = {0, };
    if (![private_key getSharedSecret:one_time_key output:&secret]) {
        return nil;
    }
    
    id d_encrypted_memo = [stealth_memo objectForKey:@"encrypted_memo"];
    if ([d_encrypted_memo isKindOfClass:[NSString class]]) {
        d_encrypted_memo = [d_encrypted_memo hex_decode];
    }
    id decrypted_memo = [d_encrypted_memo aes256cbc_decrypt:&secret];
    if (!decrypted_memo) {
        return nil;
    }
    
    //  这里可能存在异常数据，需要捕获。
    id obj_decrypted_memo = nil;
    @try {
        obj_decrypted_memo = [T_stealth_confirmation_memo_data parse:decrypted_memo];
    } @catch (NSException *exception) {
        NSLog(@"Invalid receipt data.");
        return nil;
    }
    
    uint32_t check = *(uint32_t*)&secret.data[0];
    if ([[obj_decrypted_memo objectForKey:@"check"] unsignedIntValue] != check) {
        return nil;
    }
    
    return obj_decrypted_memo;
}

- (void)onImportBlindOutputReceipt
{
    //  TODO:6.0 测试数据（cli收据格式）
    id test_cli_receipt = @"2MVtjNuKHsh3o4FTe1RU6rcaf4JdimCtFjjKYjpyJdjfJvnMVz6xmamMxUXJneE9G8mfnAVKnYrA1fJUWuk8YCCyNigV5gt3RdtVBAYRftPqdTn4tdZAcJpPhTmAAmRA8qfwBNTCFF7arnDhC8CN7JoTxbW7p5ErhKk5FTAfNDbsfSdpRcWibWfpY4ZaWt9QMxoVhdP1z7";
    
    WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
    VCBlindBalanceImport* vc = [[VCBlindBalanceImport alloc] initWithReceipt:test_cli_receipt result_promise:result_promise];
    [self pushViewController:vc vctitle:@"导入收据" backtitle:kVcDefaultBackTitleName];
    [result_promise then:^id(id new_balance_data) {
        [OrgUtils makeToast:@"导入成功。"];
        [_mainTableView reloadData];
        return nil;
    }];
    return;
    
    //    [self importCliWalletReceipt];
    
    //  TODO:6.0 测试数据
    id test_receipt = @{
        @"commitment": @"03236ea4cbddeadac512fc0480033bfd9b335214c82bd9853fa423d3f2dba73400",
        @"one_time_key": @"TEST84BqEgYGoXvCeg3SiQ9U3KebJxJ9D6J7CHDv8c5gFuruXSwPWx",
        @"to": @"TEST79qgrss7qbgWxtbjtZMSVzUt1eEfUVzFLbWmZb5Dv2GwNvpg1r",
        @"encrypted_memo": @"c76597484bdf91e8dd672a6ff7204ee074856ac0b3bc463462f5839d1d7842f54dc516c49e7a277a58fb13c94abe9857cedefcd89d8b15d6cad3ef54bea5deba32dcf975c5f142c4e529b8469c547eff"
    };
    
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
            id active = [op_account objectForKey:@"active"];
            id my_to_pub = [[[active objectForKey:@"key_auths"] firstObject] objectAtIndex:0];
            
            id my_pubkey = [GraphenePublicKey fromWifPublicKey:my_to_pub];
            id d_commitment = [[test_receipt objectForKey:@"commitment"] hex_decode];
            id toto_pub = [my_pubkey genToToTo:d_commitment];
            id toto_wif_pub = [toto_pub toWifString];
            assert([toto_wif_pub isEqualToString:[test_receipt objectForKey:@"to"]]);
            
            
            
            GraphenePrivateKey* my_pri = [[WalletManager sharedWalletManager] getGraphenePrivateKeyByPublicKey:my_to_pub];
            assert(my_pri);
            id memo = [self decryptStealthConfirmationMemo:test_receipt private_key:my_pri];
            [self testTransferFromBlind:memo private_key:my_pri stealth_memo:test_receipt];
        }
    }];
    
    
    return;
    //  TODO:6.0
    //    [OrgUtils makeToast:@"导入隐私转账收据。"];
}

- (void)testTransferFromBlind:(id)memo private_key:(GraphenePrivateKey*)private_key stealth_memo:(id)stealth_memo
{
    id amount = [memo objectForKey:@"amount"];
    id asset_id = [amount objectForKey:@"asset_id"];
    id amount_value = [amount objectForKey:@"amount"];
    
    id core_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:asset_id];
    NSInteger precision = [[core_asset objectForKey:@"precision"] integerValue];
    
    id n_fee = [[ChainObjectManager sharedChainObjectManager] getNetworkCurrentFee:ebo_transfer_from_blind kbyte:nil day:nil output:nil];
    
    uint64_t i_total_amount = [amount_value unsignedLongLongValue];
    id fee_amount = [NSString stringWithFormat:@"%@", [n_fee decimalNumberByMultiplyingByPowerOf10:precision]];
    uint64_t i_fee_amount = [fee_amount unsignedLongLongValue];
    
    
    GraphenePublicKey* one_time_key = [GraphenePublicKey fromWifPublicKey:[stealth_memo objectForKey:@"one_time_key"]];
    assert(one_time_key);
    digest_sha512 secret = {0, };
    if (![private_key getSharedSecret:one_time_key output:&secret]) {
        NSAssert(NO, @"");
    }
    digest_sha256 child = {0, };
    sha256(secret.data, sizeof(secret.data), child.data);
    //    GraphenePublicKey* child_pubkey = [[private_key getPublicKey] child:&child];
    GraphenePrivateKey* child_prikey = [private_key child:&child];
    
    //    id pk1 = [child_pubkey toWifString];
    id pk2 = [[child_prikey getPublicKey] toWifString];
    
    //  TODO:6.0 这里 asset_id 必须是 core 资产，其他资产等手续费需要换算汇率，而且fee和amount必须相同的资产ID。
    //  其他资产尚不支持
    id op = @{
        @"fee":@{@"asset_id":asset_id,@"amount":@(i_fee_amount)},
        @"amount":@{@"asset_id":asset_id,@"amount":@(i_total_amount-i_fee_amount)},
        @"to":@"1.2.64",//susu01 op_account[@"id"],
        @"blinding_factor":[memo objectForKey:@"blinding_factor"],
        @"inputs":@[@{
                        @"commitment":[memo objectForKey:@"commitment"],
                        @"owner":@{
                                @"weight_threshold":@1,
                                @"account_auths":@[],
                                @"key_auths":@[@[pk2, @1]],
                                @"address_auths":@[]
                        },
        }]
    };
    NSLog(@"%@", op);
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    id sign_key = @{
        [child_prikey toWifString]: pk2
    };
    
    [[[[BitsharesClientManager sharedBitsharesClientManager] transferFromBlind:op signPriKeyHash:sign_key] then:^id(id data) {
        NSLog(@"%@", data);
        [self hideBlockView];
        [OrgUtils makeToast:@"转出成功。"];
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  获取所有收据数据，收据格式：
    //    @"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //    @"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //    @"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //    @"decrypted_memo": @{
    //        @"amount": @{@"asset_id": @"1.3.0", @"amount": @12300000},              //  转账用，显示用。
    //        @"blinding_factor": @"",                                                //  转账用
    //        @"commitment": @"",                                                     //  转账用
    //        @"check": @331,                                                         //  导入check用，显示用。
    //    }
    [_dataArray addObjectsFromArray:[[[AppCacheManager sharedAppCacheManager] getAllBlindBalance] allValues]];
    //
    //    //  TODO:6.0 测试初始化数据
    //    [_dataArray addObject:@{
    //        @"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //        @"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //        @"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //        @"decrypted_memo": @{
    //            @"amount": @{@"asset_id": @"1.3.0", @"amount": @12300000},              //  转账用，显示用。
    //            @"blinding_factor": @"",                                                //  转账用
    //            @"commitment": @"",                                                     //  转账用
    //            @"check": @331,                                                         //  导入check用，显示用。
    //        }
    //    }];
    //    [_dataArray addObject:@{
    //        @"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //        @"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //        @"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //        @"decrypted_memo": @{
    //            @"amount": @{@"asset_id": @"1.3.0", @"amount": @32300000},              //  转账用，显示用。
    //            @"blinding_factor": @"",                                                //  转账用
    //            @"commitment": @"",                                                     //  转账用
    //            @"check": @132,                                                         //  导入check用，显示用。
    //        }
    //    }];
    //    [_dataArray addObject:@{
    //        @"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //        @"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //        @"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //        @"decrypted_memo": @{
    //            @"amount": @{@"asset_id": @"1.3.0", @"amount": @72300000},              //  转账用，显示用。
    //            @"blinding_factor": @"",                                                //  转账用
    //            @"commitment": @"",                                                     //  转账用
    //            @"check": @332,                                                         //  导入check用，显示用。
    //        }
    //    }];
    
    //  右上角按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onImportBlindOutputReceipt)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"没有任何隐私资产，可点击右上角导入转账收据。"];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    [self refreshUI];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28 + 24 * 2;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_blind_balance_cell";
    ViewBlindBalanceCell* cell = (ViewBlindBalanceCell*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewBlindBalanceCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
    cell.row = indexPath.row;
    [cell setTagData:indexPath.row];
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        //  TODO:6.0 lang
        [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                           message:nil
                                                            cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                             items:@[@"从隐私账户转出",
                                                                     @"隐私转账"]
                                                          callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
         {
            if (buttonIndex != cancelIndex){
                if (buttonIndex == 0){
                    //  TODO:6.0 test trasfer from blind
                    id blind_balance = [_dataArray objectAtIndex:indexPath.row];
                    VCTransferFromBlind* vc = [[VCTransferFromBlind alloc] initWithBlindBalance:blind_balance result_promise:nil];
                    [self pushViewController:vc vctitle:@"从隐私账户转出" backtitle:kVcDefaultBackTitleName];
                } else {
                    //  TODO:6.0 test trasfer from blind
                    id blind_balance = [_dataArray objectAtIndex:indexPath.row];
                    VCTransferFromBlind* vc = [[VCTransferFromBlind alloc] initWithBlindBalance:blind_balance result_promise:nil];
                    [self pushViewController:vc vctitle:@"从隐私账户转出" backtitle:kVcDefaultBackTitleName];
                }
            }
        }];
    }];
}

@end
