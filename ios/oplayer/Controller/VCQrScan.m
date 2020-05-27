//
//  VCQrScan.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCQrScan.h"
#import "SGQRCode.h"
#import "OrgUtils.h"

#import "VCBlindBalanceImport.h"
#import "VCStealthTransferHelper.h"
#import "VCScanNormalString.h"
#import "VCScanAccountName.h"
#import "VCScanPrivateKey.h"
#import "VCScanTransfer.h"
#import "ChainObjectManager.h"

@interface VCQrScan () {
    SGQRCodeObtain* obtain;
    WsPromiseObject* _result_promise;
}
@property (nonatomic, strong) SGQRCodeScanView *scanView;
@property (nonatomic, strong) UIButton *flashlightBtn;
@property (nonatomic, strong) UILabel *promptLabel;
@property (nonatomic, assign) BOOL isSelectedFlashlightBtn;
@property (nonatomic, strong) UIView *bottomView;
@end

@implementation VCQrScan

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //  二维码开启方法
    [obtain startRunningWithBefore:nil completion:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.scanView addTimer];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.scanView removeTimer];
    [self removeFlashlightBtn];
    [obtain stopRunning];
}

- (void)dealloc {
    _result_promise = nil;
    [self removeScanningView];
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = [UIColor blackColor];
    
    [self showRightButton:NSLocalizedString(@"kVcScanNaviTitleRightAlbum", @"相册") action:@selector(rightBarButtonItenAction)];
    
    obtain = [SGQRCodeObtain QRCodeObtain];
    
    [self setupQRCodeScan];
    [self.view addSubview:self.scanView];
    [self.view addSubview:self.promptLabel];
    [self.view addSubview:self.bottomView];
}

/**
 *  转到：普通结果界面。
 */
- (void)_gotoNormalResult:(NSString*)result
{
    [self hideBlockView];
    VCScanNormalString* vc = [[VCScanNormalString alloc] initWithResult:result];
    [self clearPushViewController:vc vctitle:NSLocalizedString(@"kVcTitleQrScanResultNormal", @"扫描结果") backtitle:kVcDefaultBackTitleName];
}

/**
 *  二维码结果：私钥情况处理。
 */
- (void)_processScanResultAsPrivateKey:(NSString*)privateKey pubkey:(NSString*)pubkey
{
    [[[self bapi_db_exec:@"get_key_references" params:@[@[pubkey]]] then:(^id(id data) {
        id account_id_ary = [data safeObjectAtIndex:0];
        if (!account_id_ary || [account_id_ary count] <= 0){
            //  私钥没在区块链注册过。
            [self _gotoNormalResult:privateKey];
            return nil;
        }
        return [[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:[account_id_ary objectAtIndex:0]] then:(^id(id full_data) {
            if (!full_data || [full_data isKindOfClass:[NSNull class]]){
                //  查询帐号信息失败，请稍后再试。
                [self _gotoNormalResult:privateKey];
                return nil;
            }
            //  转到私钥导入界面。
            [self hideBlockView];
            VCBase* vc = [[VCScanPrivateKey alloc] initWithPriKey:privateKey pubKey:pubkey fullAccountData:full_data];
            [self clearPushViewController:vc vctitle:NSLocalizedString(@"kVcTitleQrScanResultPriKey", @"导入私钥") backtitle:kVcDefaultBackTitleName];
            return nil;
        })];
    })] catch:(^id(id error) {
        [self _gotoNormalResult:privateKey];
        return nil;
    })];
}

/**
 *  二维码结果：商家收款发票情况处理。
 */
- (void)_processScanResultAsMerchantInvoice:(NSDictionary*)invoice raw:(NSString*)raw_string
{
    [[self _queryInvoiceDependencyData:[[invoice objectForKey:@"currency"] uppercaseString]
                                    to:[[invoice objectForKey:@"to"] lowercaseString]] then:(^id(id data_array) {
        id accountData = nil;
        id assetData = nil;
        if (data_array && [data_array count] == 2) {
            accountData = [data_array objectAtIndex:0];
            assetData = [data_array objectAtIndex:1];
        }
        if (!accountData || [accountData isKindOfClass:[NSNull class]] ||
            !assetData || [assetData isKindOfClass:[NSNull class]]) {
            //  查询依赖数据失败：转到普通界面。
            [self _gotoNormalResult:[NSString stringWithFormat:@"%@", invoice]];
        } else {
            //  转到账号名界面。
            [self hideBlockView];
            
            //  计算付款金额
            NSString* str_amount = nil;
            id line_items = [invoice objectForKey:@"line_items"];
            if (line_items && [line_items isKindOfClass:[NSArray class]]) {
                for (id item in line_items) {
                    id price = [item objectForKey:@"price"];
                    id quantity = [item objectForKey:@"quantity"];
                    if (price && quantity) {
                        id n_price = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", price]];
                        id n_quantity = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", quantity]];
                        if ([n_price compare:[NSDecimalNumber notANumber]] != 0 && [n_quantity compare:[NSDecimalNumber notANumber]] != 0) {
                            str_amount = [NSString stringWithFormat:@"%@", [n_price decimalNumberByMultiplyingBy:n_quantity]];
                        }
                    }
                }
            }
            
            //  可以不用登录（在支付界面再登录即可。）
            VCBase* vc = [[VCScanTransfer alloc] initWithTo:accountData asset:assetData amount:str_amount memo:[invoice objectForKey:@"memo"]];
            [self clearPushViewController:vc vctitle:NSLocalizedString(@"kVcTitleQrScanResultPay", @"支付") backtitle:kVcDefaultBackTitleName];
        }
        return nil;
    })];
}

/**
 *  二维码结果：鼓鼓收款情况处理。
 */
- (void)_processScanResultAsMagicWalletReceive:(NSString*)result pay_string:(NSString*)pay_string
{
    id ary = [pay_string componentsSeparatedByString:@"/"];
    NSString* account_id = [ary safeObjectAtIndex:0];
    NSString* asset_name = [ary safeObjectAtIndex:1];
    NSString* asset_amount = [ary safeObjectAtIndex:2];
    NSString* memo = [ary safeObjectAtIndex:3];
    //  REMARK：memo采用urlencode编号，需要解码，非asc字符会出错。
    if (memo && ![memo isEqualToString:@""]) {
        memo = [memo url_decode];
    }
    
    [[self _queryInvoiceDependencyData:asset_name
                                    to:account_id] then:(^id(id data_array) {
        id accountData = nil;
        id assetData = nil;
        if (data_array && [data_array count] == 2) {
            accountData = [data_array objectAtIndex:0];
            assetData = [data_array objectAtIndex:1];
        }
        if (!accountData || [accountData isKindOfClass:[NSNull class]] ||
            !assetData || [assetData isKindOfClass:[NSNull class]]) {
            //  查询依赖数据失败：转到普通界面。
            [self _gotoNormalResult:result];
        } else {
            //  转到账号名界面。
            [self hideBlockView];
            
            //  可以不用登录（在支付界面再登录即可。）
            VCBase* vc = [[VCScanTransfer alloc] initWithTo:accountData asset:assetData amount:asset_amount memo:memo];
            [self clearPushViewController:vc vctitle:NSLocalizedString(@"kVcTitleQrScanResultPay", @"支付") backtitle:kVcDefaultBackTitleName];
        }
        return nil;
    })];
}

/**
 *  (private) 是否是有效的账号数据判断。
 */
- (BOOL)_isValidAccountData:(NSDictionary*)accountData
{
    return accountData && [accountData objectForKey:@"id"] && [accountData objectForKey:@"name"];
}

/**
 *  (private) 查询收款依赖数据。
 */
- (WsPromise*)_queryInvoiceDependencyData:(NSString*)asset to:(NSString*)to
{
    return [WsPromise promise:(^(WsResolveHandler resolve, WsRejectHandler reject) {
        NSString* currency = asset;
        //  去掉bit前缀
        if (currency && currency.length > 3 && [currency rangeOfString:@"BIT"].location == 0) {
            currency = [currency substringFromIndex:3];
        }
        if (currency && to) {
            ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
            id p1 = [chainMgr queryAccountData:to];
            id p2 = [chainMgr queryAssetData:currency];
            [[WsPromise all:@[p1, p2]] then:(^id(id data) {
                resolve(data);
                return nil;
            })];
        } else {
            resolve(nil);
        }
    })];
}

/**
 *  处理二维码识别or扫描的结果。
 */
- (void)processScanResult:(NSString*)result
{
    assert(result);
    result = [NSString trim:result];
    
    //  直接返回扫描结果
    if (_result_promise) {
        [_result_promise resolve:result];
        [self closeOrPopViewController];
        return;
    }
    
    //  空字符串
    if (!result || result.length <= 0) {
        [self _gotoNormalResult:result];
        return;
    }
    [self showBlockViewWithTitle:NSLocalizedString(@"kVcScanProcessingResult", @"正在处理...")];
    [self delay:^{
        //  1、判断是否是BTS私钥。
        NSString* btsAddress = [OrgUtils genBtsAddressFromWifPrivateKey:result];
        if (btsAddress){
            [self _processScanResultAsPrivateKey:result pubkey:btsAddress];
            return;
        }
        
        //  2、是不是比特股商家收款协议发票
        id invoice = [OrgUtils merchantInvoiceDecode:result];
        if (invoice) {
            [self _processScanResultAsMerchantInvoice:invoice raw:result];
            return;
        }
        
        //  3、是不是隐私收据判断。
        id blind_receipt_json = [VCStealthTransferHelper guessBlindReceiptString:result];
        if (blind_receipt_json) {
            [self hideBlockView];
            [self clearPushViewController:[[VCBlindBalanceImport alloc] initWithReceipt:result result_promise:nil]
                                  vctitle:NSLocalizedString(@"kVcTitleImportBlindReceipt", @"导入收据")
                                backtitle:kVcDefaultBackTitleName];
            return;
        }
        
        //  4、是不是鼓鼓收款码  bts://r/1/#{account_id}/#{asset_name}/#{asset_amount}/#{memo}
        NSRange prefix_range = [result rangeOfString:@"bts://r/1/" options:NSCaseInsensitiveSearch];
        if (prefix_range.location == 0) {
            [self _processScanResultAsMagicWalletReceive:result pay_string:[result substringFromIndex:prefix_range.length]];
            return;
        }
        
        //  5、查询是不是比特股账号名or账号ID
        [[[ChainObjectManager sharedChainObjectManager] queryAccountData:result] then:(^id(id accountData) {
            if ([self _isValidAccountData:accountData]) {
                //  转到账号名界面。
                [self hideBlockView];
                VCBase* vc = [[VCScanAccountName alloc] initWithAccountData:accountData];
                [self clearPushViewController:vc
                                      vctitle:NSLocalizedString(@"kVcTitleQrScanResultAccount", @"账号信息")
                                    backtitle:kVcDefaultBackTitleName];
            } else {
                //  其他：普通字符串
                [self _gotoNormalResult:result];
            }
            return nil;
        })];
    }];
}

- (void)setupQRCodeScan {
    __weak typeof(self) weakSelf = self;
    
    SGQRCodeObtainConfigure *configure = [SGQRCodeObtainConfigure QRCodeObtainConfigure];
    configure.sampleBufferDelegate = YES;
    [obtain establishQRCodeObtainScanWithController:self configure:configure];
    [obtain setBlockWithQRCodeObtainScanResult:^(SGQRCodeObtain *obtain, NSString *result) {
        if (result) {
            [obtain stopRunning];
            [obtain playSoundName:@"SGQRCode.bundle/sound.caf"];
            [weakSelf processScanResult:result];
        }
    }];
    [obtain setBlockWithQRCodeObtainScanBrightness:^(SGQRCodeObtain *obtain, CGFloat brightness) {
        if (brightness < - 1) {
            [weakSelf.view addSubview:weakSelf.flashlightBtn];
        } else {
            if (weakSelf.isSelectedFlashlightBtn == NO) {
                [weakSelf removeFlashlightBtn];
            }
        }
    }];
}

- (void)rightBarButtonItenAction {
    __weak typeof(self) weakSelf = self;
    
    [obtain establishAuthorizationQRCodeObtainAlbumWithController:nil];
    if (obtain.isPHAuthorization == YES) {
        [self.scanView removeTimer];
    }
    [obtain setBlockWithQRCodeObtainAlbumDidCancelImagePickerController:^(SGQRCodeObtain *obtain) {
        [weakSelf.view addSubview:weakSelf.scanView];
    }];
    [obtain setBlockWithQRCodeObtainAlbumResult:^(SGQRCodeObtain *obtain, NSString *result) {
        if (result == nil) {
            [OrgUtils makeToast:NSLocalizedString(@"kVcScanNoQrCode", @"未发现二维码。") position:@"CSToastPositionCenter"];
        } else {
            [weakSelf processScanResult:result];
        }
    }];
}

- (SGQRCodeScanView *)scanView {
    if (!_scanView) {
        _scanView = [[SGQRCodeScanView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 0.9 * self.view.frame.size.height)];
    }
    return _scanView;
}
- (void)removeScanningView {
    [self.scanView removeTimer];
    [self.scanView removeFromSuperview];
    self.scanView = nil;
}

- (UILabel *)promptLabel {
    if (!_promptLabel) {
        _promptLabel = [[UILabel alloc] init];
        _promptLabel.backgroundColor = [UIColor clearColor];
        CGFloat promptLabelX = 0;
        CGFloat promptLabelY = 0.73 * self.view.frame.size.height;
        CGFloat promptLabelW = self.view.frame.size.width;
        CGFloat promptLabelH = 25;
        _promptLabel.frame = CGRectMake(promptLabelX, promptLabelY, promptLabelW, promptLabelH);
        _promptLabel.textAlignment = NSTextAlignmentCenter;
        _promptLabel.font = [UIFont boldSystemFontOfSize:13.0];
        _promptLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
        _promptLabel.text = NSLocalizedString(@"kVcScanAutoScanTips", @"将二维码放入框内, 即可自动扫描。");
    }
    return _promptLabel;
}

- (UIView *)bottomView {
    if (!_bottomView) {
        _bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.scanView.frame), self.view.frame.size.width, self.view.frame.size.height - CGRectGetMaxY(self.scanView.frame))];
        _bottomView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _bottomView;
}

#pragma mark - - - 闪光灯按钮
- (UIButton *)flashlightBtn {
    if (!_flashlightBtn) {
        // 添加闪光灯按钮
        _flashlightBtn = [UIButton buttonWithType:(UIButtonTypeCustom)];
        CGFloat flashlightBtnW = 30;
        CGFloat flashlightBtnH = 30;
        CGFloat flashlightBtnX = 0.5 * (self.view.frame.size.width - flashlightBtnW);
        CGFloat flashlightBtnY = 0.55 * self.view.frame.size.height;
        _flashlightBtn.frame = CGRectMake(flashlightBtnX, flashlightBtnY, flashlightBtnW, flashlightBtnH);
        [_flashlightBtn setBackgroundImage:[UIImage imageNamed:@"SGQRCodeFlashlightOpenImage"] forState:(UIControlStateNormal)];
        [_flashlightBtn setBackgroundImage:[UIImage imageNamed:@"SGQRCodeFlashlightCloseImage"] forState:(UIControlStateSelected)];
        [_flashlightBtn addTarget:self action:@selector(flashlightBtn_action:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _flashlightBtn;
}

- (void)flashlightBtn_action:(UIButton *)button {
    if (button.selected == NO) {
        [obtain openFlashlight];
        self.isSelectedFlashlightBtn = YES;
        button.selected = YES;
    } else {
        [self removeFlashlightBtn];
    }
}

- (void)removeFlashlightBtn {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [obtain closeFlashlight];
        self.isSelectedFlashlightBtn = NO;
        self.flashlightBtn.selected = NO;
        [self.flashlightBtn removeFromSuperview];
    });
}

@end
