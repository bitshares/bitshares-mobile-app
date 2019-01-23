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
//#import "ScanSuccessJumpVC.h"

#import "VCScanNormalString.h"
#import "VCScanPrivateKey.h"
#import "ChainObjectManager.h"

@interface VCQrScan () {
    SGQRCodeObtain *obtain;
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

    /// 二维码开启方法
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
    NSLog(@"VCQrScan - dealloc");
    [self removeScanningView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = [UIColor blackColor];
    
    [self showRightButton:@"相册" action:@selector(rightBarButtonItenAction)];
    
    obtain = [SGQRCodeObtain QRCodeObtain];
    
    [self setupQRCodeScan];
//    [self setupNavigationBar];
    [self.view addSubview:self.scanView];
    [self.view addSubview:self.promptLabel];
    /// 为了 UI 效果
    [self.view addSubview:self.bottomView];
}

/**
 *  转到：普通结果界面。
 */
- (void)_gotoNormalResult:(NSString*)result
{
    [self hideBlockView];
    VCScanNormalString* vc = [[VCScanNormalString alloc] initWithResult:result];
    [self clearPushViewController:vc vctitle:@"扫描结果" backtitle:kVcDefaultBackTitleName];
}

/**
 *  二维码结果：私钥情况处理。
 */
- (void)_processScanResultAsPrivateKey:(NSString*)privateKey pubkey:(NSString*)pubkey
{
    [[[self bapi_db_exec:@"get_key_references" params:@[@[pubkey]]] then:(^id(id data) {
        id account_id_ary = [data safeObjectAtIndex:0];
        if (!account_id_ary || [account_id_ary count] <= 0){
            NSLog(@"私钥不正确，请重新输入。");
            [self _gotoNormalResult:privateKey];
            return nil;
        }
        return [[[ChainObjectManager sharedChainObjectManager] queryFullAccountInfo:[account_id_ary objectAtIndex:0]] then:(^id(id full_data) {
            if (!full_data || [full_data isKindOfClass:[NSNull class]]){
                NSLog(@"查询帐号信息失败，请稍后再试。");
                [self _gotoNormalResult:privateKey];
                return nil;
            }
            //  转到私钥导入界面。
            [self hideBlockView];
            VCBase* vc = [[VCScanPrivateKey alloc] initWithPriKey:privateKey pubKey:pubkey fullAccountData:full_data];
            [self clearPushViewController:vc vctitle:@"私钥信息" backtitle:kVcDefaultBackTitleName];
            return nil;
        })];
    })] catch:(^id(id error) {
        [self _gotoNormalResult:privateKey];
        return nil;
    })];
}
/**
 *  处理二维码识别or扫描的结果。
 */
- (void)processScanResult:(NSString*)result
{
    assert(result);
    //  TODO:fowallet 多语言
    [self showBlockViewWithTitle:@"正在处理..."];
    [self delay:^{
        //  1、判断是否是BTS私钥。
        NSString* btsAddress = [OrgUtils genBtsAddressFromWifPrivateKey:result];
        if (btsAddress){
            [self _processScanResultAsPrivateKey:result pubkey:btsAddress];
            return;
        }
        //  其他：普通字符串
        [self _gotoNormalResult:result];
    }];
}

- (void)setupQRCodeScan {
    __weak typeof(self) weakSelf = self;
    
    SGQRCodeObtainConfigure *configure = [SGQRCodeObtainConfigure QRCodeObtainConfigure];
    configure.sampleBufferDelegate = YES;
    [obtain establishQRCodeObtainScanWithController:self configure:configure];
    [obtain setBlockWithQRCodeObtainScanResult:^(SGQRCodeObtain *obtain, NSString *result) {
        if (result) {
//            [weakSelf showBlockViewWithTitle:@"正在处理..."];
//            [MBProgressHUD SG_showMBProgressHUDWithModifyStyleMessage:@"正在处理..." toView:weakSelf.view];
            [obtain stopRunning];
            [obtain playSoundName:@"SGQRCode.bundle/sound.caf"];

            [weakSelf processScanResult:result];
//
//            //  TODO:
////            ScanSuccessJumpVC *jumpVC = [[ScanSuccessJumpVC alloc] init];
////            jumpVC.comeFromVC = ScanSuccessJumpComeFromWC;
////            jumpVC.jump_URL = result;
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                [weakSelf hideBlockView];
//                [OrgUtils showMessage:result];
////                [MBProgressHUD SG_hideHUDForView:weakSelf.view];
////                [weakSelf.navigationController pushViewController:jumpVC animated:YES];
//            });
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

//- (void)setupNavigationBar {
//    self.navigationItem.title = @"扫一扫";
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"相册" style:(UIBarButtonItemStyleDone) target:self action:@selector(rightBarButtonItenAction)];
//}

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
        //  TODO:
//        [weakSelf showBlockViewWithTitle:@"正在处理..."];
//        [MBProgressHUD SG_showMBProgressHUDWithModifyStyleMessage:@"正在处理..." toView:weakSelf.view];
        if (result == nil) {
            NSLog(@"暂未识别出二维码");
            [OrgUtils makeToast:@"未发现二维码。" position:@"CSToastPositionCenter"];
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                [MBProgressHUD SG_hideHUDForView:weakSelf.view];
//                [MBProgressHUD SG_showMBProgressHUDWithOnlyMessage:@"未发现二维码/条形码" delayTime:1.0];
//            });
        } else {
            [OrgUtils showMessage:result];
//            ScanSuccessJumpVC *jumpVC = [[ScanSuccessJumpVC alloc] init];
//            jumpVC.comeFromVC = ScanSuccessJumpComeFromWC;
//            if ([result hasPrefix:@"http"]) {
//                jumpVC.jump_URL = result;
//            } else {
//                jumpVC.jump_bar_code = result;
//            }
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                [MBProgressHUD SG_hideHUDForView:weakSelf.view];
//                [weakSelf.navigationController pushViewController:jumpVC animated:YES];
//            });
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
        _promptLabel.text = @"将二维码放入框内, 即可自动扫描。";
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
