//
//  VCBlindBalanceImport.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import "VCBlindBalanceImport.h"
#import "MyTextView.h"
#import "ViewTipsInfoCell.h"

#import "VCStealthTransferHelper.h"
#import "VCQrScan.h"

#import "GrapheneSerializer.h"
#import "GraphenePublicKey.h"

enum
{
    kVcUser = 0,
    kVcSubmitButton,
    kVcTips,
    
    kVcMax,
};

enum
{
    kVcSubUserTitle = 0,        //  标题
    kVcSubUserReceipt,          //  收据内容输入框
    
    kVcSubUserMax
};

@interface VCBlindBalanceImport ()
{
    NSString*               _receipt;
    WsPromiseObject*        _result_promise;
    
    UITableViewBase*        _mainTableView;
    MyTextView*             _tv_receipt;
    ViewBlockLabel*         _lbImport;
    ViewTipsInfoCell*       _cell_tips;
}

@end

@implementation VCBlindBalanceImport

-(void)dealloc
{
    if (_tv_receipt){
        _tv_receipt.delegate = nil;
        _tv_receipt = nil;
    }
    
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    
    _lbImport = nil;
    _receipt = nil;
    _result_promise = nil;
    _cell_tips = nil;
}

- (id)initWithReceipt:(NSString*)receipt result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _receipt = receipt;
        _result_promise = result_promise;
    }
    return self;
}

/*
 *  (private) 扫一扫按钮点击
 */
- (void)onScanQrCodeButtonClicked
{
    [[[OrgUtils authorizationForCamera] then:(^id(id data) {
        WsPromiseObject* result_promise = [[WsPromiseObject alloc] init];
        VCQrScan* vc = [[VCQrScan alloc] initWithResultPromise:result_promise];
        vc.title = NSLocalizedString(@"kVcTitleQrScan", @"扫一扫");
        [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        [result_promise then:^id(id result) {
            if (result && [result isKindOfClass:[NSString class]]) {
                _tv_receipt.text = [result copy];
            }
            return nil;
        }];
        return nil;
    })] catch:(^id(id error) {
        [OrgUtils showMessage:[error reason]];
        return nil;
    })];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  扫一扫
    [self showRightImageButton:@"iconScan" action:@selector(onScanQrCodeButtonClicked) color:theme.textColorMain];
    
    //  UI - 隐私收据输入框
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    _tv_receipt = [[MyTextView alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width  - 32, 28 * 5)];
    _tv_receipt.dataDetectorTypes = UIDataDetectorTypeAll;
    [_tv_receipt setFont:[UIFont systemFontOfSize:16]];
    _tv_receipt.placeholder = NSLocalizedString(@"kVcStPlaceholderInputReceipt", @"请输入隐私转账收据。");
    _tv_receipt.backgroundColor = [UIColor clearColor];
    _tv_receipt.dataDetectorTypes = UIDataDetectorTypeNone;
    _tv_receipt.textColor = theme.textColorMain;
    _tv_receipt.tintColor = theme.tintColor;
    if (_receipt) {
        _tv_receipt.text = [_receipt copy];
    }
    
    //  UI - 主列表
    _mainTableView = [[UITableViewBase alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  登录按钮
    _lbImport = [self createCellLableButton:NSLocalizedString(@"kVcStBtnImportNow", @"立即导入")];
    
    //  UI - 提示信息
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:NSLocalizedString(@"kVcStTipUiImportReceipt", @"【温馨提示】\n导入收据同时支持APP生成的收据和CLI命令行钱包收据格式。\n如果隐私收据丢失，可尝试直接输入转账对应区块编号进行导入。\n如果是通过提案进行隐私转账，则不会生成隐私收据，在提案生效后直接输入创建提案时对应区块编号进行导入即可。")];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
}

- (void)endInput
{
    [super endInput];
    [_tv_receipt safeResignFirstResponder];
}

/*
 *  (private) 是否是已知收据判断。即收据的 to 字段是否是隐私账户中的地址或者隐私账户的变形格式地址。
 */
- (NSString*)guessRealToPublicKey:(id)stealth_memo d_commitment:(id)d_commitment blind_accounts:(NSArray*)blind_accounts
{
    assert(stealth_memo);
    assert(blind_accounts && [blind_accounts count] > 0);
    
    //  没有 to 属性作为未知收据处理。
    NSString* to = [stealth_memo objectForKey:@"to"];
    if (!to) {
        return nil;
    }
    
    //  是否是隐私账户中的地址判断
    for (NSString* blind_account_public_key in blind_accounts) {
        if ([blind_account_public_key isEqualToString:to]) {
            return blind_account_public_key;
        }
    }
    
    //  是否是隐私账户地址的变形地址判断
    for (NSString* blind_account_public_key in blind_accounts) {
        GraphenePublicKey* public_key = [GraphenePublicKey fromWifPublicKey:blind_account_public_key];
        if (!public_key) {
            continue;
        }
        if ([to isEqualToString:[[public_key genToToTo:d_commitment] toWifString]]) {
            return blind_account_public_key;
        }
    }
    
    //  未知收据
    return nil;
}

/*
 *  (private) 检测单个 operation。
 */
- (void)scanOneOperation:(id)op
              data_array:(NSMutableArray*)data_array
          blind_accounts:(NSArray*)blind_accounts
    enable_scan_proposal:(BOOL)enable_scan_proposal
{
    assert(op && [op count] == 2);
    assert(data_array);
    assert(blind_accounts);
    
    NSInteger optype = [[op objectAtIndex:0] integerValue];
    id opdata = [op objectAtIndex:1];
    
    //  创建提案：则考虑遍历提案的所有operation。
    if (optype == ebo_proposal_create) {
        if (enable_scan_proposal) {
            id proposed_ops = [opdata objectForKey:@"proposed_ops"];
            if (proposed_ops && [proposed_ops count] > 0) {
                for (id proposed_op in proposed_ops) {
                    [self scanOneOperation:[proposed_op objectForKey:@"op"]
                                data_array:data_array
                            blind_accounts:blind_accounts
                      enable_scan_proposal:NO]; //  REMARK：如果提案里包含创建提案，不重复处理。
                }
            }
        }
        return;
    } else if (optype == ebo_transfer_to_blind || optype == ebo_blind_transfer) {
        //  转入隐私账户 以及 隐私账户之间转账都存在新的收据生成。
        id outputs = [opdata objectForKey:@"outputs"];
        assert(outputs && [outputs count] > 0);
        if (!outputs || [outputs count] <= 0) {
            return;
        }
        for (id blind_output in outputs) {
            id stealth_memo = [blind_output objectForKey:@"stealth_memo"];
            //  该字段可选，跳过不存在该字段的收据。REMARK：官方命令行客户端等该字段不存在，目前已知BTS++支持该字段。
            if (!stealth_memo) {
                continue;
            }
            id d_commitment = [[blind_output objectForKey:@"commitment"] hex_decode];
            id real_to_key = [self guessRealToPublicKey:stealth_memo d_commitment:d_commitment blind_accounts:blind_accounts];
            if (real_to_key) {
                [data_array addObject:@{@"real_to_key": real_to_key, @"stealth_memo": stealth_memo}];
            }
        }
    }
    return;
}

/*
 *  (private) 扫描区块中的原始【隐私收据】信息。即可：outputs
 */
- (NSArray*)scanBlindReceiptFromBlockData:(NSDictionary*)block_data blind_accounts:(NSArray*)blind_accounts
{
    NSMutableArray* data_array = [NSMutableArray array];
    
    if (!block_data || ![block_data isKindOfClass:[NSDictionary class]]) {
        return data_array;
    }
    if (!blind_accounts || [blind_accounts count] <= 0) {
        return data_array;
    }
    
    id transactions = [block_data objectForKey:@"transactions"];
    if (!transactions || [transactions count] <= 0) {
        return data_array;
    }
    
    for (id trx in transactions) {
        id operations = [trx objectForKey:@"operations"];
        if (!operations || [operations count] <= 0) {
            continue;
        }
        for (id op in operations) {
            [self scanOneOperation:op data_array:data_array blind_accounts:blind_accounts enable_scan_proposal:YES];
        }
    }
    
    return data_array;
}

/*
 *  (private) 是否是区块号判断。
 */
- (BOOL)isValidBlockNum:(NSString*)str
{
    if (![OrgUtils isFullDigital:str]) {
        return NO;
    }
    NSDecimalNumber* n_block_num = [OrgUtils auxGetStringDecimalNumberValue:str];
    if (!n_block_num) {
        return NO;
    }
    NSDecimalNumber* n_min = [NSDecimalNumber zero];
    //  REMARK：最大区块号暂定10亿。
    NSDecimalNumber* n_max = [NSDecimalNumber decimalNumberWithMantissa:1000000000 exponent:0 isNegative:NO];
    if ([n_block_num compare:n_min] <= 0) {
        return NO;
    }
    if ([n_block_num compare:n_max] >= 0) {
        return NO;
    }
    return YES;
}

/**
 *  (private) 事件 - 点击导入。
 */
- (void)onSubmitClicked
{
    [self endInput];
    
    [self GuardWalletExistWithWalletMode:NSLocalizedString(@"kVcStealthTransferGuardWalletModeTips", @"隐私交易仅支持钱包模式，是否为当前的账号创建本地钱包文件？")
                                    body:^{
        id str_receipt = [NSString trim:_tv_receipt.text];
        id json = [VCStealthTransferHelper guessBlindReceiptString:str_receipt];
        if (!json && [self isValidBlockNum:str_receipt]) {
            //  尝试从区块编号恢复
            json = @{kAppBlindReceiptBlockNum:str_receipt};
        }
        if (!json) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcStImportTipInputValidReceiptText", @"请输入有效收据信息。")];
            return;
        }
        
        //  解锁钱包
        [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
            if (unlocked) {
                [self onImportReceiptCore:json];
            }
        }];
    }];
}

- (void)onImportReceiptCore:(id)receipt_json
{
    assert(receipt_json);
    id app_blind_receipt_block_num = [receipt_json objectForKey:kAppBlindReceiptBlockNum];
    if (app_blind_receipt_block_num) {
        id blind_accounts = [[[AppCacheManager sharedAppCacheManager] getAllBlindAccounts] allKeys];
        if (!blind_accounts || [blind_accounts count] <= 0) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcStImportTipPleaseImportYourBlindAccountFirst", @"您的隐私账户列表为空，请先前往账户管理界面导入隐私账号。")];
            return;
        }
        [VcUtils simpleRequest:self
                       request:[[ChainObjectManager sharedChainObjectManager] queryBlock:[app_blind_receipt_block_num unsignedIntegerValue]]
                      callback:^(id block_data) {
            id data_array = [self scanBlindReceiptFromBlockData:block_data
                                                 blind_accounts:blind_accounts];
            [self importStealthBalanceCore:data_array];
        }];
    } else {
        id to = [receipt_json objectForKey:@"to"];
        id to_pub = [GraphenePublicKey fromWifPublicKey:to];
        if (!to_pub) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcStImportTipInvalidReceiptNoToPublic", @"收据信息无效，收款地址未知。")];
            return;
        }
        [self importStealthBalanceCore:@[@{@"real_to_key": to, @"stealth_memo": receipt_json}]];
    }
}

- (void)importStealthBalanceCore:(NSArray*)data_array
{
    assert(data_array);
    if ([data_array count] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcStImportTipReceiptIsEmpty", @"收据数据为空。")];
        return;
    }
    
    NSMutableArray* miss_key_array = [NSMutableArray array];
    NSMutableArray* decrypt_failed_array = [NSMutableArray array];
    NSMutableArray* blind_balance_array = [NSMutableArray array];
    NSMutableDictionary* asset_ids = [NSMutableDictionary dictionary];
    
    for (id item in data_array) {
        id stealth_memo = [item objectForKey:@"stealth_memo"];
        id real_to_key = [item objectForKey:@"real_to_key"];
        
        //  错误1：缺少私钥
        GraphenePrivateKey* to_pri = [[WalletManager sharedWalletManager] getGraphenePrivateKeyByPublicKey:real_to_key];
        if (!to_pri) {
            [miss_key_array addObject:item];
            continue;
        }
        
        //  错误2：无效收据（解密失败or校验失败）
        id decrypted_memo = [self decryptStealthConfirmationMemo:stealth_memo private_key:to_pri];
        if (!decrypted_memo) {
            [decrypt_failed_array addObject:item];
            continue;
        }
        
        //  构造明文的隐私收据格式
        id blind_balance = @{
            @"real_to_key": real_to_key,
            @"one_time_key": [stealth_memo objectForKey:@"one_time_key"],
            @"to": [stealth_memo objectForKey:@"to"],
            @"decrypted_memo": @{
                    @"amount": [decrypted_memo objectForKey:@"amount"],
                    @"blinding_factor": [[decrypted_memo objectForKey:@"blinding_factor"] hex_encode],
                    @"commitment": [[decrypted_memo objectForKey:@"commitment"] hex_encode],
                    @"check": [decrypted_memo objectForKey:@"check"]
            }
        };
        [blind_balance_array addObject:blind_balance];
        [asset_ids setObject:@YES forKey:[[decrypted_memo objectForKey:@"amount"] objectForKey:@"asset_id"]];
    }
    
    //  链上验证所有是否有效
    NSUInteger total_blind_balance_count = [blind_balance_array count];
    if (total_blind_balance_count > 0) {
        [VcUtils simpleRequest:self
                       request:[[ChainObjectManager sharedChainObjectManager] queryAllGrapheneObjects:[asset_ids allKeys]]
                      callback:^(id data) {
            //  循环验证所有收据
            NSMutableArray* verify_success = [NSMutableArray array];
            NSMutableArray* verify_failed = [NSMutableArray array];
            [[self verifyAllBlindReceiptOnchain:blind_balance_array
                                 verify_success:verify_success
                                  verify_failed:verify_failed] then:^id(id data) {
                NSUInteger success_count = [verify_success count];
                if (success_count == total_blind_balance_count) {
                    //  全部校验成功
                    [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStImportTipSuccessN", @"成功导入 %@ 条隐私收据。"),
                                         @(success_count)]];
                    [self onImportSuccessful:verify_success];
                    return nil;
                }
                if (success_count > 0) {
                    //  部分校验成功，部分校验失败。
                    [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcStImportTipSuccessNandVerifyFailedN", @"成功导入 %@ 条收据，%@ 条校验失败。"),
                                         @(success_count),
                                         @([verify_failed count])]];
                    [self onImportSuccessful:verify_success];
                } else {
                    //  全部验证失败。
                    [OrgUtils makeToast:NSLocalizedString(@"kVcStImportTipInvalidReceiptOnchainVerifyFailed", @"收据信息无效，链上校验失败。")];
                }
                return nil;
            }];
        }];
    } else {
        if ([miss_key_array count] > 0) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcStImportTipInvalidReceiptMissPriKey", @"收据信息无效，收款地址私钥不存在。")];
        } else {
            // num of decrypt_failed_array > 0
            [OrgUtils makeToast:NSLocalizedString(@"kVcStImportTipInvalidReceiptSelfCheckingFailed", @"收据信息无效，自校验失败。")];
        }
    }
}

- (WsPromise*)verifyAllBlindReceiptOnchain:(NSMutableArray*)blind_balance_array
                            verify_success:(NSMutableArray*)verify_success
                             verify_failed:(NSMutableArray*)verify_failed
{
    assert(blind_balance_array);
    assert(verify_success);
    assert(verify_failed);
    
    if ([blind_balance_array count] <= 0) {
        return [WsPromise resolve:@YES];
    } else {
        id blind_balance = [blind_balance_array firstObject];
        [blind_balance_array removeObjectAtIndex:0];
        return [[[BitsharesClientManager sharedBitsharesClientManager] verifyBlindReceipt:blind_balance] then:^id(id result) {
            //  TODO:7.0 其他错误考虑提示？
            switch ([result integerValue]) {
                case kBlindReceiptVerifyResultOK:
                    [verify_success addObject:blind_balance];
                    break;
                default:
                    [verify_failed addObject:blind_balance];
                    break;
            }
            return [self verifyAllBlindReceiptOnchain:blind_balance_array verify_success:verify_success verify_failed:verify_failed];
        }];
    }
}

/*
 *  (private) 导入成功
 */
- (void)onImportSuccessful:(id)blind_balance_array
{
    //  持久化存储
    if (blind_balance_array && [blind_balance_array count] > 0) {
        AppCacheManager* pAppCahce = [AppCacheManager sharedAppCacheManager];
        for (id blind_balance in blind_balance_array) {
            [pAppCahce appendBlindBalance:blind_balance];
        }
        [pAppCahce saveWalletInfoToFile];
    }
    //  返回
    if (_result_promise) {
        [_result_promise resolve:@YES];
    }
    [self closeOrPopViewController];
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

#pragma mark-
#pragma UITextFieldDelegate delegate method

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self endInput];
    return YES;
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcMax;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcUser:
        {
            switch (indexPath.row) {
                case kVcSubUserReceipt:
                    return _tv_receipt.bounds.size.height;
                default:
                    break;
            }
        }
            break;
        case kVcTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    return tableView.rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcUser){
        return kVcSubUserMax;
    }else{
        return 1;
    }
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcUser:
        {
            switch (indexPath.row) {
                case kVcSubUserTitle:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.text = NSLocalizedString(@"kVcStCellTitleReceipt", @"收据");
                    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                    cell.hideBottomLine = YES;
                    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
                    return cell;
                }
                    break;
                case kVcSubUserReceipt:
                {
                    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.showCustomBottomLine = YES;
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.accessoryView = _tv_receipt;
                    return cell;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case kVcSubmitButton:
        {
            //  提交事件
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.hideBottomLine = YES;
            cell.hideTopLine = YES;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbImport cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcTips:
            return _cell_tips;
        default:
            break;
    }
    assert(false);
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        if (indexPath.section == kVcSubmitButton){
            [self onSubmitClicked];
        }
    }];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endInput];
}

@end
