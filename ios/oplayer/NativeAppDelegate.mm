//
//  NativeAppDelegate.mm
//  oplayer
//
//  Created by SYALON on 13-8-1.
//
//

#import "NativeAppDelegate.h"
#import "SAMKeychain.h"
#import "AppCacheManager.h"
#import "ThemeManager.h"
#import "LangManager.h"

#import "VCMarketContainer.h"
#import "VCDebt.h"
#import "VCServices.h"
#import "VCMyself.h"

#import "GRCustomUITabBarItem.h"
#import <QuartzCore/QuartzCore.h>
#import "OrgUtils.h"

#import "MyTabBarController.h"
#import "MyNavigationController.h"

#include <sys/types.h>
#include <sys/sysctl.h>
#import <sys/utsname.h>

#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

//  for hook test
#import <objc/objc.h>
#import <objc/runtime.h>

#import "GrapheneSerializer.h"
#import <Flurry/Flurry.h>

@interface NativeAppDelegate()
{
}

-(void)processNetworkStatusChanged:(NetworkStatus)status;

@end

@implementation NativeAppDelegate

@synthesize alertViewWindow;
@synthesize currLanguage = _currLanguage;
@synthesize currNetStatus = _currNetStatus;
@synthesize networkreach = _reach;
@synthesize isLanguageCN,isLanguageSimpleChinese;

+(NativeAppDelegate*)sharedAppDelegate
{
    return (NativeAppDelegate*)[UIApplication sharedApplication].delegate;
}

/**
 *  网络类型判断
 */
-(BOOL)isNetworkViaWifi
{
    return _currNetStatus == ReachableViaWiFi;
}

-(BOOL)isNetworkVia2G3G
{
    return _currNetStatus == ReachableViaWWAN;
}

//NotReachable = 0,
//ReachableViaWiFi,
//ReachableViaWWAN,
//ReachableVia2G,
//ReachableVia3G,
//ReachableVia4G
-(int)currNetworkStatus
{
    return (int)_currNetStatus;
}

/**
 *  获取当前网络状态对应的描述字符串。
 */
- (NSString*)getNetworkStatusDesc
{
    switch ((int)_currNetStatus) {
        case 1:
            return @"WiFi";
        case 3:
            return @"2G";
        case 4:
            return @"3G";
        case 5:
            return @"4G";
        default:
            return @"Unknown";
    }
}

-(void)processNetworkStatusChanged:(NetworkStatus)status
{
    if (status != _currNetStatus)
    {
        if (_currNetStatus == ReachableViaWiFi)
        {
            //  TODO:fowallet WIFI网络切换到其他网络
        }
        _currNetStatus = status;
        //  TODO:fowallet 是否执行部分逻辑对应网络变更？
    }
}

-(void)onReachabilityChanged:(NSNotification*)note
{
    Reachability* curr = [note object];
    NSParameterAssert([curr isKindOfClass: [Reachability class]]);
    NetworkStatus netStatus = [curr currentReachabilityStatus];
    [self processNetworkStatusChanged:netStatus];
}

/**
 *  设备是否越狱判断
 */
+(BOOL)isJailbroken
{
    BOOL jailbroken = NO;
    NSString *cydiaPath = @"/Applications/Cydia.app";
    NSString *aptPath = @"/private/var/lib/apt/";
    if ([[NSFileManager defaultManager] fileExistsAtPath:cydiaPath]) {
        jailbroken = YES;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:aptPath]) {
        jailbroken = YES;
    }
    return jailbroken;
}

/**
 *  设备详细描述
 */
+(NSString*)deviceDetailDescription
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char* machine = (char*)malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString* pDetailModel = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    UIDevice* device = [UIDevice currentDevice];
    return [NSString stringWithFormat:@"%@|%@|%@", device.model, device.systemVersion, pDetailModel];
}

/**
 *  获取系统当前语言
 */
+(NSString*)getSystemLanguage
{
    NSArray* allLangs = [NSLocale preferredLanguages];
    return [allLangs objectAtIndex:0];
}

/**
 *  设备唯一ID号
 */
+(NSString*)deviceUniqueID
{
    NSString* service = @"com.btsplusplus.fowallet.app";
    NSString* account = @"com.btsplusplus.fowallet.uniqueid";
    
    NSString* pUniqueID_password = [SAMKeychain passwordForService:service account:account];
    if (!pUniqueID_password)
    {
        NSString* pUniqueString = [NSString stringWithFormat:@"time:%f|random:%u", [[NSDate date] timeIntervalSince1970] * 1000, arc4random()];
        pUniqueID_password = [OrgUtils md5:pUniqueString];
        [SAMKeychain setPassword:pUniqueID_password forService:service account:account];
    }
    
    return pUniqueID_password;
}

/**
 *  系统版本号
 */
+(NSInteger)systemVersion
{
    static NSUInteger _deviceSystemMajorVersion = -1;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _deviceSystemMajorVersion = [[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndex:0] intValue];
    });
    return _deviceSystemMajorVersion;
}

/**
 *  获取设备硬件信息（包含设备型号、系统版本、是否越狱）
 */
+ (NSString*)deviceInfo
{
    struct utsname systemInfo = {0, };
    uname(&systemInfo);
    
    NSString* model = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString* version = [[UIDevice currentDevice] systemVersion];
    
    //  返回格式：iPhone8,2 v9.3 [Jailbroken] 需要具体的型号在网上找吧
    NSString* device_and_version = [NSString stringWithFormat:@"%@ v%@", model, version];
    if ([self isJailbroken]){
        return [device_and_version stringByAppendingString:@" Jailbroken"];
    }else{
        return device_and_version;
    }
}

/**
 *  生成导航VC
 */
-(MyNavigationController*)newNavigationController:(UIViewController*)vc
{
    MyNavigationController* vcNav = [[MyNavigationController alloc] initWithRootViewController:vc];
    [self setupNavigationAttribute:vcNav];
    
//    //  REMARK：统计navibar vc
//    [Flurry logAllPageViewsForTarget:vcNav];
    
    return vcNav;
}

/**
 *  生成导航VC for ARC
 */
-(MyNavigationController*)newNavigationControllerWithoutRelease:(UIViewController*)vc
{
    MyNavigationController* vcNav = [[MyNavigationController alloc] initWithRootViewController:vc];
    [self setupNavigationAttribute:vcNav];
    
//    //  REMARK：统计navibar vc
//    [Flurry logAllPageViewsForTarget:vcNav];
    
    return vcNav;
}

/**
 *  App版本号和短版本号
 */
+ (NSString*)appVersion
{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
}

+ (NSString*)appShortVersion
{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

- (CGFloat)getRequestTimeout
{
    switch ((int)_currNetStatus) {
        case 1: //  wifi
        case 5: //  4g
            return 10.0f;
        case 3: //  2g
        case 4: //  3g
            return 20.0f;
        default:
            return 30.0f;
    }
}

/**
 *  !!! 各种控件颜色设置，初始化以及切换主题时调用。
 */
- (void)resetAppearanceColors
{
    assert(_mainTabController);
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  设置状态栏：不隐藏、黑白颜色
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    if ([[[[SettingManager sharedSettingManager] getThemeInfo] objectForKey:@"themeStatusBarWhite"] boolValue]){
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent]; //  白色
    }else{
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];      //  黑色
    }
    
    //  该方法 ios10 新增的
    UITabBar* tabbar = [UITabBar appearance];
    if ([_mainTabController.tabBar respondsToSelector:@selector(setUnselectedItemTintColor:)]){
        [tabbar setUnselectedItemTintColor:theme.textColorGray]; //  未选中时颜色
        [tabbar setTintColor:theme.textColorHighlight];          //  选中时颜色
    }else{
        //  TODO:fowallet 未选中的颜色不支持？只能设置 2种 image，选中的？和非选中的？
        [tabbar setTintColor:theme.textColorHighlight];          //  选中时颜色
    }
    [tabbar setBarTintColor:theme.tabBarColor];                  //  tabar背景颜色
    tabbar.translucent = NO;
    
    [[UITextField appearance] setTintColor:theme.tintColor];
    //    [[UIImageView appearance] setTintColor:theme.iconColor];
//    //  REMARK: 这个会影响 tableView 中的问号按钮等色调
//    [[UIImageView appearanceWhenContainedIn:[UITableView class], nil] setTintColor:theme.tintColor];
    [[UIImageView appearanceWhenContainedIn:[UISegmentedControl class], nil] setTintColor:theme.tintColor];
//    //  REMARK: 这个会影响关注、收藏按钮等色调
//    [[UIImageView appearanceWhenContainedIn:[UINavigationBar class], nil] setTintColor:theme.navigationBarTextColor];
}

- (void)switchTheme
{
    if (!_mainTabController){
        return;
    }
    
    [self resetAppearanceColors];
   
    if ([_mainTabController.view respondsToSelector:@selector(setTintColor:)])
    {
        _mainTabController.view.tintColor = [ThemeManager sharedThemeManager].tabBarColor;
    }
    _mainTabController.view.backgroundColor = [UIColor whiteColor];
    
    for (MyNavigationController* navi in _mainTabController.viewControllers) {
        [self setupNavigationAttribute:navi];
        [navi switchTheme];
    }
}

- (void)switchLanguage
{
    if (!_mainTabController){
        return;
    }
    for (MyNavigationController* navi in _mainTabController.viewControllers) {
        [navi switchLanguage];
    }
}

///<    设置导航条属性
-(void)setupNavigationAttribute:(UINavigationController*)nav
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  navibar 背景
    nav.navigationBar.barTintColor = theme.navigationBarBackColor;
    
    //  navibar 左右按钮颜色（REMARK：关注、收藏等右边按钮需要改色调必须采用自定义UIButton处理。）
    [nav.navigationBar setTintColor:theme.navigationBarTextColor];
    [nav.navigationBar setTranslucent:NO];  //  REMARK：这个调整了所有布局都会乱，别瞎改。
    
    //  navibar 中间 title 文字颜色和字号
    NSDictionary *textAttributes = @{
                                     NSForegroundColorAttributeName : theme.navigationBarTextColor,
                                     NSFontAttributeName            : [UIFont boldSystemFontOfSize:17]
                                     };
    nav.navigationBar.titleTextAttributes = textAttributes;
    
    //    //  UIBarButtonItem 的文字颜色，不包含 返回的左边按钮颜色。左边按钮颜色用 navigationBar 的 tintColor 设置。
    //    [[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil]
    //     setTitleTextAttributes:
    //     @{NSForegroundColorAttributeName:[UIColor greenColor],
    //       NSFontAttributeName:[UIFont systemFontOfSize:17.0]
    //       }
    //     forState:UIControlStateNormal];

    //  REMARK：这条横线可以考虑隐藏
    [nav.navigationBar setBackgroundImage:[[UIImage alloc] init]
                           forBarPosition:UIBarPositionAny
                               barMetrics:UIBarMetricsDefault];
    [nav.navigationBar setShadowImage:[[UIImage alloc] init]];
}

- (UIImage*)imageWithColor:(UIColor*)color
{
    //  一个像素
    CGRect rect = CGRectMake(0, 0, 1, 1);
    //  开启上下文
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    [color setFill];
    UIRectFill(rect);
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

-(UIWindow*)createMainWindow
{
    if (self.window)
        return self.window;
    
    ///<    初始化窗口
    if (!self.window){
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    }
    
    ///<    初始化tabBar和各子视图
    _mainTabController = [[MyTabBarController alloc] init];
    
    VCMarketContainer* vcMarketContainer = [[VCMarketContainer alloc] init];
    vcMarketContainer.title = NSLocalizedString(@"kTabBarNameMarkets", @"行情");
    GRCustomUITabBarItem *tabarItem = [[GRCustomUITabBarItem alloc]initWithTitle:NSLocalizedString(@"kTabBarNameMarkets", @"行情") tag:0];
    tabarItem.imageString = @"tabMarket";
    vcMarketContainer.tabBarItem = tabarItem;
 
    VCDebt* vcDebt = [[VCDebt alloc] init];
    vcDebt.title = NSLocalizedString(@"kVcTitleMarginPosition", @"抵押借贷");
    tabarItem = [[GRCustomUITabBarItem alloc]initWithTitle:NSLocalizedString(@"kTabBarNameCollateral", @"抵押") tag:0];
    tabarItem.imageString = @"tabDebt";
    vcDebt.tabBarItem = tabarItem;
    
    VCServices* vcServices = [[VCServices alloc] init];
    vcServices.title = NSLocalizedString(@"kTabBarNameServices", @"服务");
    tabarItem = [[GRCustomUITabBarItem alloc]initWithTitle:NSLocalizedString(@"kTabBarNameServices", @"服务") tag:0];
    tabarItem.imageString = @"tabService";
    vcServices.tabBarItem = tabarItem;
    
//    //  占位VC（空）
//    VCBase* tmpVC = [[[VCBase alloc] init] autorelease];
//    UITabBarItem* tmpTabBarItem = [[[UITabBarItem alloc] initWithTitle:nil image:nil tag:0] autorelease];
//    tmpTabBarItem.enabled = NO;
//    tmpVC.tabBarItem = tmpTabBarItem;
    
    VCMyself *vcMyself = [[VCMyself alloc] init];
    vcMyself.title = NSLocalizedString(@"kTabBarNameMy", @"我的");
    tabarItem = [[GRCustomUITabBarItem alloc]initWithTitle:NSLocalizedString(@"kTabBarNameMy", @"我的") tag:0];
    tabarItem.imageString = @"tabMyself";
    vcMyself.tabBarItem = tabarItem;
    
    //  初始化tabvc对应的navibar
    NSArray* controllers = [NSArray arrayWithObjects:vcMarketContainer, vcDebt, vcServices, vcMyself, nil];
    NSMutableArray *navControllers = [[NSMutableArray alloc] init];
    for (int i=0; i<[controllers count]; i++)
    {
        UIViewController* vc = [controllers objectAtIndex:i];
        MyNavigationController* vcNav = [[MyNavigationController alloc]initWithRootViewController:vc];
        [self setupNavigationAttribute:vcNav];
        [navControllers addObject:vcNav];
    }
    
    [self resetAppearanceColors];
    
    _mainTabController.viewControllers = navControllers;
    _mainTabController.view.autoresizesSubviews = NO;
    
    [self.window setRootViewController:_mainTabController];
    
    return self.window;
}

- (UIViewController*)getAlertViewWindowViewController
{
    if (!self.alertViewWindow)
    {
        self.alertViewWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.alertViewWindow.backgroundColor = [UIColor clearColor];
        VCBase* rootVC = [[VCBase alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        [self.alertViewWindow setRootViewController:rootVC];
    }
    self.alertViewWindow.hidden = NO;
    self.alertViewWindow.windowLevel = UIWindowLevelNormal + 20;
    [self.alertViewWindow makeKeyAndVisible];
    return self.alertViewWindow.rootViewController;
}

void uncaughtExceptionHandler(NSException *exception)
{
    //  [统计]
    [OrgUtils logEvents:@"crash" params:@{@"name":exception.name, @"reason":exception.reason}];
}

- (void)initLanguageInfo
{
    self.currLanguage = [[self class] getSystemLanguage];
    self.isLanguageCN = [self.currLanguage hasPrefix:@"zh"];
    self.isLanguageSimpleChinese = [self.currLanguage hasPrefix:@"zh-Hans"] || [self.currLanguage hasPrefix:@"zh-CN"];
}

#pragma mark- application delegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@":Device Unique Identifier: %@ | %@\nSystem Version: %ld", [[self class] deviceUniqueID], [[self class] deviceDetailDescription], (long)[[self class] systemVersion]);
    
    ///<    初始化状态栏：渐变
    [application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [application setStatusBarStyle:UIStatusBarStyleLightContent];
    
    //  Crashlytics
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);   //  REMARK：must before init crashlytics
    [Fabric with:@[[Crashlytics class]]];
    
    NSString* uuid = [NativeAppDelegate deviceUniqueID];
    id device_info = [NativeAppDelegate deviceInfo];
    CLS_LOG(@"%@",uuid);
    CLS_LOG(@"UserDeviceInfo: %@", device_info);
    
    [CrashlyticsKit setUserIdentifier:uuid];
    
    [Flurry startSession:@"WY5BMPMSZTXNCC2X986X" withSessionBuilder:[[[[[FlurrySessionBuilder new]
                                                                        withLogLevel:FlurryLogLevelAll]
                                                                       withCrashReporting:YES]
                                                                      withSessionContinueSeconds:20]
                                                                     withAppVersion:[[self class] appVersion]]];
    
    //  初始化石墨烯对象序列化类
    [T_Base registerAllType];
    
    //  初始化部分临时数据
    [[TempManager sharedTempManager] InitData];
    
    //  初始化缓存列表（REMARK：放在tempmgr之后初始化，因为缓存文件用到的key在tempmgr中。）
    [[AppCacheManager sharedAppCacheManager] initload];
    
    //  初始化语言信息
    [[LangManager sharedLangManager] initCurrentLanguage];
    [self initLanguageInfo];
    
    //  初始化帐号、资产、市场等数据（放在cacheMgr之后，可能用到cacheMgr中用户收藏的信息。）
    [[ChainObjectManager sharedChainObjectManager] initAll];
    
    //  记录首次启动时间
    [[AppCacheManager sharedAppCacheManager] recordFirstRunTime:^{
        //  REMARK：设置首次启动、首次运行标记
        [TempManager sharedTempManager].appFirstLaunch = YES;
        //  移除所有可能存在的本地通知
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }];
    
    //  [统计]
    id login_account_id = [[WalletManager sharedWalletManager] getWalletAccountName];
    if (login_account_id && ![login_account_id isEqualToString:@""]){
        [Flurry setUserID:login_account_id];
    }
    [OrgUtils logEvents:@"startSession" params:@{@"uuid":uuid, @"lang":self.currLanguage ? : @"", @"device_info":device_info}];
    
    //  LOG
#ifndef DEBUG
    if ([TempManager sharedTempManager].appFirstLaunch){
        CLS_LOG(@"AppFirstLaunch YES");
    }else{
        CLS_LOG(@"AppFirstLaunch NO, first launch time: %@", @((uint32_t)[[AppCacheManager sharedAppCacheManager] getFirstRunTime]));
    }
#endif
    
    //  初始化网络状态以及监听器
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onReachabilityChanged:)
                                                 name: kReachabilityChangedNotification
                                               object: nil];
    self.networkreach = [Reachability reachabilityForInternetConnection];
    [_reach startNotifier];
    _currNetStatus = [_reach currentReachabilityStatus];
    
    //  初始化窗口
    [[self createMainWindow] makeKeyAndVisible];
    
    return YES;
}

///<    一对：暂停和继续
- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
    NSLog(@"applicationWillResignActive");
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    NSLog(@"applicationDidBecomeActive");
}

///<    一对：后台和前台o.o
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
    NSLog(@"applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
    [application setApplicationIconBadgeNumber:0];
    NSLog(@"applicationWillEnterForeground");
}

///<    不搭理你o.o
- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
}

#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}


-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    _mainTabController = nil;
    if (_reach)
    {
        [_reach stopNotifier];
        self.networkreach = nil;
    }
    _window = nil;
}

@end
