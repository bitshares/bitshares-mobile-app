//
//  VCImportAccount.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCImportAccount.h"

#import "VCLoginPasswordMode.h"
#import "VCLoginBrainKeyMode.h"
#import "VCLoginPrivateKeyMode.h"
#import "VCTransfer.h"
#import "VCImportWallet.h"
#import "WalletManager.h"
#import "VCRegisterAccount.h"

@interface VCImportAccount ()
{
    ImportAccountSuccessCallback    _callback;
}

@end

@implementation VCImportAccount

@synthesize checkActivePermission;

-(void)dealloc
{
    _callback = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.checkActivePermission = YES;
    }
    return self;
}

- (id)initWithSuccessCallback:(ImportAccountSuccessCallback)callback
{
    self = [super init];
    if (self) {
        _callback = callback;
        self.checkActivePermission = YES;
    }
    return self;
}

- (NSArray*)getTitleStringArray
{
    if (checkActivePermission){
        //  登录
        return @[NSLocalizedString(@"kLoginPageModePassword", @"帐号模式"),
                 NSLocalizedString(@"kLoginPageModeBrainKey", @"助记词"),
                 NSLocalizedString(@"kLoginPageModePrivateKey", @"私钥模式"),
                 NSLocalizedString(@"kLoginPageModeWallet", @"钱包模式")];
    }else{
        //  导入账号
        return @[NSLocalizedString(@"kLoginPageModePassword", @"帐号模式"),
                 NSLocalizedString(@"kLoginPageModeBrainKey", @"助记词"),
                 NSLocalizedString(@"kLoginPageModePrivateKey", @"私钥模式")];
    }
}

- (NSArray*)getSubPageVCArray
{
    if (checkActivePermission){
        //  登录
        return @[[[VCLoginPasswordMode alloc] initWithOwner:self checkActivePermission:self.checkActivePermission],
                 [[VCLoginBrainKeyMode alloc] initWithOwner:self checkActivePermission:self.checkActivePermission],
                 [[VCLoginPrivateKeyMode alloc] initWithOwner:self checkActivePermission:self.checkActivePermission],
                 [[VCImportWallet alloc] initWithOwner:self]];
    }else{
        //  导入账号
        return @[[[VCLoginPasswordMode alloc] initWithOwner:self checkActivePermission:self.checkActivePermission],
                 [[VCLoginBrainKeyMode alloc] initWithOwner:self checkActivePermission:self.checkActivePermission],
                 [[VCLoginPrivateKeyMode alloc] initWithOwner:self checkActivePermission:self.checkActivePermission]];
    }
}

- (void)onRegisterBtnClicked
{
    //  TODO:子view需要处理键盘焦点
//    [self.view endEditing:YES];
//
//    [_tf_password safeResignFirstResponder];
//    [_tf_username safeResignFirstResponder];
    VCRegisterAccount* vc = [[VCRegisterAccount alloc] init];
    [self pushViewController:vc vctitle:NSLocalizedString(@"kVcTitleRegister", @"注册") backtitle:kVcDefaultBackTitleName];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  背景颜色
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  导入账号不提供注册（登录账号时候提供 ）& TODO:fowallet 测试网络暂时不提供注册。
    if (checkActivePermission && ![ChainObjectManager sharedChainObjectManager].isTestNetwork){
        [self showRightButton:NSLocalizedString(@"kLoginBtnRegister", @"注册") action:@selector(onRegisterBtnClicked)];
    }
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //  导入帐号成功回调
    if (_callback && [[WalletManager sharedWalletManager] isWalletExist]){
        [self delay:^{
            _callback();
        }];
    }
}

@end
