//
//  VCAbout.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCAbout.h"
#import "NativeAppDelegate.h"
#import "AppCacheManager.h"

@interface VCAbout ()

@end

@implementation VCAbout

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    //  关于图标
    UIImage* image = [UIImage imageNamed:@"abouticon"];
    CGFloat iconAreaViewHeight = image.size.height + 16 + 32;
    
    UIView* iconAreaView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenRect.size.width, iconAreaViewHeight)];
    [self.view addSubview:iconAreaView];
    
    UIImageView* iconView = [[UIImageView alloc] initWithImage:image];
    iconView.frame = CGRectMake((screenRect.size.width - image.size.width) / 2.0f, 16, image.size.width, image.size.height);
    [iconAreaView addSubview:iconView];
    
    UILabel* appnamever = [[UILabel alloc] initWithFrame:CGRectMake(0, 16 + image.size.height, screenRect.size.width, 32)];
    appnamever.lineBreakMode = NSLineBreakByTruncatingTail;
    appnamever.numberOfLines = 1;
    appnamever.backgroundColor = [UIColor clearColor];
    appnamever.textColor = [ThemeManager sharedThemeManager].textColorGray;
    appnamever.textAlignment = NSTextAlignmentCenter;
    appnamever.font = [UIFont systemFontOfSize:13];
    appnamever.text = [NSString stringWithFormat:@"%@ v%@", NSLocalizedString(@"kAppName", @"BTS++"), [NativeAppDelegate appShortVersion]];
    [iconAreaView addSubview:appnamever];
    
    //  关于介绍的说明文档部分
    UITextView* tv_main;
    tv_main = [[UITextView alloc] initWithFrame:CGRectMake(0, iconAreaViewHeight, screenRect.size.width, screenRect.size.height - [self heightForStatusAndNaviBar] - iconAreaViewHeight)];
    tv_main.dataDetectorTypes = UIDataDetectorTypeAll;
    [tv_main setFont:[UIFont systemFontOfSize:16]];
    [self.view addSubview:tv_main];
    tv_main.editable = NO;
    tv_main.backgroundColor = [UIColor clearColor];
    tv_main.dataDetectorTypes = UIDataDetectorTypeNone;
    tv_main.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    NSMutableArray* lines = [NSMutableArray array];
    
    //  介绍&主程序版本号 TODO:fowallet 介绍
    [lines addObject:NSLocalizedString(@"kAboutMainDesc", @"BTS++是基于比特股石墨烯技术，从产品体验出发，采用原生技术开发的一款可媲美一流中心化交易所的去中心化交易所（DEX）产品。")];
    [lines addObject:@"\n"];
    [lines addObject:NSLocalizedString(@"kAboutContactUs", @"联系我们")];
    [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"kAboutWechat", @"微信：%@"), @"bts-pp"]];
    [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"kAboutEmail", @"邮箱：%@"), @"contact@btsplusplus.com"]];
    [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"kAboutTelegram", @"电报：%@"), @"https://t.me/btsplusplus"]];
    [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"kAboutWebsite", @"网站：%@"), @"http://btspp.io"]];
    [lines addObject:[NSString stringWithFormat:@"\n%@ v%@", NSLocalizedString(@"kAppName", @"BTS++"), [NativeAppDelegate appVersion]]];
    
#if APPSTORE_CHANNEL
    [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"kAboutChannelAppStore", @"(商店版 & 渠道 %@)"), @(kAppChannelID)]];
#else
    [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"kAboutChannelWebsite", @"(官网版 & 渠道 %@)"), @(kAppChannelID)]];
#endif  //  APPSTORE_CHANNEL
    
    //  是否调试版
#if DEBUG
    [lines addObject:NSLocalizedString(@"kAboutDebugVersion", @"(调试版)")];
#endif
    if ([ChainObjectManager sharedChainObjectManager].isTestNetwork){
        [lines addObject:NSLocalizedString(@"kAboutTestnet", @"(测试网络)")];
    }
    
    tv_main.text = [lines componentsJoinedByString:@"\n"];
}

-(void)dealloc
{
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
