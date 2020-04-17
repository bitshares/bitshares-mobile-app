//
//  VCBlindBalanceImport.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//
#import "VCBlindBalanceImport.h"
#import "MyTextView.h"

#import "GrapheneSerializer.h"
#import "GraphenePublicKey.h"

enum
{
    kVcUser = 0,
    kVcSubmitButton,
    
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  TODO:6.0 lang
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    _tv_receipt = [[MyTextView alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width  - 32, 28 * 5)];
    _tv_receipt.dataDetectorTypes = UIDataDetectorTypeAll;
    [_tv_receipt setFont:[UIFont systemFontOfSize:16]];
    _tv_receipt.placeholder = @"请输入隐私转账收据。";
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
    _lbImport = [self createCellLableButton:@"立即导入"];
}

- (void)endInput
{
    [super endInput];
    [_tv_receipt safeResignFirstResponder];
}

/**
 *  (private) 事件 - 点击导入。
 */
- (void)onSubmitClicked
{
    //  TODO:6.0 暂时只支持了 cliwallet 钱包格式收据
    
    id str_receipt = [NSString trim:_tv_receipt.text];
    if (!str_receipt || [str_receipt isEqualToString:@""]) {
        [OrgUtils makeToast:@"请输入收据信息。"];
        return;
    }
    id data_receipt = [str_receipt base58_decode];
    assert(data_receipt);
    
    id stealth_conf = [T_stealth_confirmation parse:data_receipt];
    assert(stealth_conf);
    id to = [stealth_conf objectForKey:@"to"];
    id to_pub = [GraphenePublicKey fromWifPublicKey:to];
    if (!to_pub) {
        [OrgUtils makeToast:@"无效收据信息，收款地址未知。"];
        return;
    }
    
    //  TODO:6.0
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            [self importStealthBalanceCore:stealth_conf to:to];
        }
    }];
}

- (void)importStealthBalanceCore:(NSDictionary*)stealth_conf to:(NSString*)wif_to_public
{
    GraphenePrivateKey* to_pri = [[WalletManager sharedWalletManager] getGraphenePrivateKeyByPublicKey:wif_to_public];
    if (!to_pri) {
        [OrgUtils makeToast:@"无效收据信息，收款地址私钥不存在。"];
        return;
    }
    id memo = [self decryptStealthConfirmationMemo:stealth_conf private_key:to_pri];
    if (!memo) {
        [OrgUtils makeToast:@"无效收据信息，解密失败。"];
        return;
    }
    //  TODO:6.0 data
    //@"real_to_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",  //  仅显示用
    //@"one_time_key": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53", //  转账用
    //@"to": @"TEST71jaNWV7ZfsBRUSJk6JfxSzEB7gvcS7nSftbnFVDeyk6m3xj53",           //  没用到
    //@"decrypted_memo": @{
    //    @"amount": @{@"asset_id": @"1.3.0", @"amount": @12300000},              //  转账用，显示用。
    //    @"blinding_factor": @"",                                                //  转账用
    //    @"commitment": @"",                                                     //  转账用
    //    @"check": @331,                                                         //  导入check用，显示用。
    //}
    id blind_balance = @{
        @"real_to_key": wif_to_public,
        @"one_time_key": [stealth_conf objectForKey:@"one_time_key"],
        @"to": wif_to_public,
        @"decrypted_memo": @{
                //  TODO:6.0
        }
    };
    [self onImportSuccessful:blind_balance];
}

/*
 *  (private) 导入成功
 */
- (void)onImportSuccessful:(id)blind_balance
{
    if (_result_promise) {
        [_result_promise resolve:blind_balance];
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
    if (indexPath.section == kVcUser) {
        switch (indexPath.row) {
            case kVcSubUserReceipt:
                return _tv_receipt.bounds.size.height;
            default:
                break;
        }
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
    if (indexPath.section == kVcUser)
    {
        switch (indexPath.row) {
            case kVcSubUserTitle:
            {
                //  TODO:6.0 lang
                UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
                cell.backgroundColor = [UIColor clearColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = @"收据";
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
        return nil;
        
    }else
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
