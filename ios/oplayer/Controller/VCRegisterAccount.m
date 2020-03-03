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
    //  TODO:2.9 url
    [self gotoWebView:[NSString stringWithFormat:@"%@%@", @"https://btspp.io/", NSLocalizedString(@"userAgreementHtmlFileName", @"agreement html file")]
                title:NSLocalizedString(@"kVcTitleAgreement", @"用户协议和服务条款")];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  事件 - 空白处点击
    self.enableTapSpaceEndInput = YES;
    
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
