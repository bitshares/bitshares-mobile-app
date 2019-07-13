//
//  VCRegisterAccount.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCRegisterAccount.h"

#import "VCRegisterPasswordMode.h"
#import "VCRegisterWalletMode.h"
#import "VCBtsaiWebView.h"

#import "WalletManager.h"

@interface VCRegisterAccount ()
{
    ImportAccountSuccessCallback    _callback;
}

@end

@implementation VCRegisterAccount

-(void)dealloc
{
    _callback = nil;
}

- (id)initWithSuccessCallback:(ImportAccountSuccessCallback)callback
{
    self = [super init];
    if (self) {
        _callback = callback;
    }
    return self;
}

- (NSArray*)getTitleStringArray
{
    return @[NSLocalizedString(@"kLoginPageModeWallet", @"钱包模式"),
             NSLocalizedString(@"kLoginPageModePassword", @"帐号模式")];
}

- (NSArray*)getSubPageVCArray
{
    return @[[[VCRegisterWalletMode alloc] initWithOwner:self], [[VCRegisterPasswordMode alloc] initWithOwner:self]];
}

- (void)onRBtnAgreementClicked
{
    VCBtsaiWebView* vc = [[VCBtsaiWebView alloc] initWithUrl:@"https://btspp.io/agreement.html"];
    vc.title = NSLocalizedString(@"kVcTitleAgreement", @"用户协议和服务条款");
    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    [self showRightButton:NSLocalizedString(@"kBtnAppAgreement", @"服务条款") action:@selector(onRBtnAgreementClicked)];
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
