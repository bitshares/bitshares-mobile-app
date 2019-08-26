//
//  VCLaunch.m
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCLaunch.h"
#import "OrgUtils.h"
#import "MySecurityFileMgr.h"
#import "ScheduleManager.h"

@interface VCLaunch ()
{
}

@end

@implementation VCLaunch

- (void)dealloc
{
}

- (id)init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

/**
 *  (private) 获取启动界面的图片名
 */
- (NSString*)getLaunchImageName
{
    NSString* viewOrientation = @"Portrait";
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
    {
        viewOrientation = @"Landscape";
    }
    
    CGSize viewSize = [[UIScreen mainScreen] bounds].size;
    for (NSDictionary* dict in [[[NSBundle mainBundle] infoDictionary] valueForKey:@"UILaunchImages"])
    {
        CGSize imageSize = CGSizeFromString(dict[@"UILaunchImageSize"]);
        
        if (CGSizeEqualToSize(imageSize, viewSize) && [viewOrientation isEqualToString:dict[@"UILaunchImageOrientation"]])
        {
            return dict[@"UILaunchImageName"];
        }
    }
    
    return nil;
}

/**
 *  (private) 获取启动界面的图片
 */
- (UIImage*)getLaunchImage
{
    NSString* name = [self getLaunchImageName];
    if (!name){
        return nil;
    }
    return [UIImage imageNamed:name];
}

/**
 *  (private) 裁剪图像
 */
- (UIImage*)clipImage:(CGImageRef)src rect:(CGRect)rect scale:(CGFloat)scale
{
    CGImageRef imageRef = CGImageCreateWithImageInRect(src, rect);
    UIImage* newImage = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(imageRef);
    return newImage;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    //  启动界面背景图
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    UIImage* launchImage = [self getLaunchImage] ?: [UIImage imageNamed:@"LaunchImage"];
    UIImageView* launchFullScreenView = [[UIImageView alloc] initWithImage:launchImage];
    launchFullScreenView.frame = screenRect;
    [self.view addSubview:launchFullScreenView];
    
    //  启动初始化
    [self startInit:YES];
}

/**
 *  启动初始化
 */
- (void)startInit:(BOOL)first_init
{
    [[[self checkUpdate] then:(^id(id pVersionConfig) {
        [SettingManager sharedSettingManager].serverConfig = [NSDictionary dictionaryWithDictionary:pVersionConfig];
        return [[self asyncInitBitshares] then:(^id(id data) {
            [self _onLoadVersionJsonFinish:pVersionConfig];
            return nil;
        })];
    })] catch:(^id(id error) {
        [self onFirstInitFailed];
        return nil;
    })];
}

- (void)onFirstInitFailed
{
    [[UIAlertViewManager sharedUIAlertViewManager] showMessageEx:NSLocalizedString(@"kAppFirstInitNetworkFailed", @"APP网络初始化异常了，请按照以下步骤处理：\n1、如果是首次启动，请允许应用使用无线数据。\n2、其他情况请检查您的设备网络是否正常。")
                                                       withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                    cancelButton:nil
                                                    otherButtons:@[NSLocalizedString(@"kAppBtnReInit", @"重试")]
                                                      completion:^(NSInteger buttonIndex)
     {
         [OrgUtils logEvents:@"appReInitNetwork" params:@{}];
         [self startInit:NO];
     }];
}

- (WsPromise*)checkUpdate
{
    
    
#if kAppCheckUpdate
    
    //  检测更新
    return [WsPromise promise:(^(WsResolveHandler resolve, WsRejectHandler reject) {
#ifdef DEBUG
        //  调试模式：直接加载本地version.json
        NSDictionary* pVersionJson = [self loadBundleVersionJson];
        resolve(pVersionJson);
#else
        //  正式环境 or 测试更新模式下 从服务器加载。
        NSString* pNativeVersion = [NativeAppDelegate appShortVersion];
        NSString* flags = @"0";
        id version_url = [NSString stringWithFormat:@"https://btspp.io/app/ios/%@_%@/version.json?f=%@", @(kAppChannelID), pNativeVersion, flags];
        [OrgUtils asyncFetchJson:version_url
                         timeout:[[NativeAppDelegate sharedAppDelegate] getRequestTimeout]
                 completionBlock:^(id pVersionJson)
         {
             if (!pVersionJson)
             {
                 pVersionJson = [self loadNativeVersionJson];
             }
             resolve(pVersionJson);
         }];
#endif
    })];
#else
    
    //  不检测更新
    return [WsPromise resolve:@{}];
#endif  //  kAppCheckUpdate

}

//  从bundle加载version.json
- (NSDictionary*)loadBundleVersionJson
{
    NSString* bundlePath = [NSBundle mainBundle].resourcePath;
    NSString* fullPathInApp = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, kAppStaticDir, kAppCacheNameVersionJsonByVer];
    NSData* data = [NSData dataWithContentsOfFile:fullPathInApp];
    if (!data){
        return nil;
    }
    NSString* rawdatajson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!rawdatajson){
        return nil;
    }
    NSDictionary* pCacheVersionJson = [NSJSONSerialization JSONObjectWithData:[rawdatajson dataUsingEncoding:NSUTF8StringEncoding]
                                                                      options:NSJSONReadingAllowFragments error:nil];
    return pCacheVersionJson;
}

//  从服务器加载version.json失败后则加载本地等version.json（app内部或cache缓存内）
- (NSDictionary*)loadNativeVersionJson
{
    NSString* pCacheVersionFilename = [OrgUtils makeFullPathByVerStorage:kAppCacheNameVersionJsonByVer];
    NSDictionary* pCacheVersionJson = [MySecurityFileMgr loadDicSecFile:pCacheVersionFilename];
    if (pCacheVersionJson){
        return pCacheVersionJson;
    }
    return [self loadBundleVersionJson];
}

- (void)_onLoadVersionJsonFinish:(NSDictionary*)pConfig
{
    //  检测app是否可以更新
    if (pConfig && [pConfig count] > 0) {
        NSString* pNativeVersion = [NativeAppDelegate appShortVersion];
        NSString* pNewestVersion = [pConfig objectForKey:@"version"];
        if (pNewestVersion)
        {
            NSInteger ret = [OrgUtils compareVersion:pNewestVersion other:pNativeVersion];
            if (ret > 0)
            {
                //  提示更新
                NSString* infoKey;
                if ([NativeAppDelegate sharedAppDelegate].isLanguageCN){
                    infoKey = @"newVersionInfo";
                }else{
                    infoKey = @"newVersionInfoEn";
                }
                [self showAppUpdateWindow:[pConfig objectForKey:infoKey]
                                      url:[pConfig objectForKey:@"appURL"]
                              forceUpdate:[[pConfig objectForKey:@"force"] boolValue]];
                
                return;
            }
        }
    }
    
    //  没更新则直接启动
    [self _enterToMain];
}

/**
 *  (private) 进入主界面。
 */
- (void)_enterToMain
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kBtsAppEventInitDone object:nil userInfo:nil];
    [[NativeAppDelegate sharedAppDelegate] closeLaunchWindow];
}

/**
 *  (private) 提示app更新
 */
- (void)showAppUpdateWindow:(NSString*)message url:(NSString*)url forceUpdate:(BOOL)forceUpdate
{
    NSArray* otherButtons = nil;
    if (!forceUpdate){
        otherButtons = [NSArray arrayWithObject:NSLocalizedString(@"kRemindMeLatter", @"稍后提醒")];
    }
    [[UIAlertViewManager sharedUIAlertViewManager] showMessageEx:message
                                                       withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
                                                    cancelButton:NSLocalizedString(@"kUpgradeNow", @"立即升级")
                                                    otherButtons:otherButtons
                                                      completion:^(NSInteger buttonIndex)
     {
         if (buttonIndex == 0){
             [OrgUtils safariOpenURL:url];
         }
     }];
}

/**
 *  (private) 初始化APP核心逻辑
 */
- (WsPromise*)asyncInitBitshares
{
    return [WsPromise promise:(^(WsResolveHandler resolve, WsRejectHandler reject) {
        GrapheneConnectionManager* connMgr = [GrapheneConnectionManager sharedGrapheneConnectionManager];
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        WalletManager* walletMgr = [WalletManager sharedWalletManager];
        [[[connMgr Start] then:(^id(id success) {
            //  初始化石墨烯网络状态
            [[[chainMgr grapheneNetworkInit] then:(^id(id data) {
                //  初始化数据
                WsPromise* initTickerData = [chainMgr marketsInitAllTickerData];
                WsPromise* initGlobalProperties = [[connMgr last_connection].api_db exec:@"get_global_properties" params:@[]];
                WsPromise* initFeeAssetInfo = [chainMgr queryFeeAssetListDynamicInfo];   //  查询手续费兑换比例、手续费池等信息
                id initFullUserData = [NSNull null];
                if ([walletMgr isWalletExist] && [walletMgr isMissFullAccountData]){
                    initFullUserData = [chainMgr queryFullAccountInfo:[[walletMgr getWalletInfo] objectForKey:@"kAccountName"]];
                }
                return [[WsPromise all:@[initTickerData, initGlobalProperties, initFeeAssetInfo, initFullUserData]] then:(^id(id data_array) {
                    [self hideBlockView];
                    //  更新全局属性
                    [chainMgr updateObjectGlobalProperties:[data_array objectAtIndex:1]];
                    //  更新帐号完整数据
                    id full_account_data = [data_array objectAtIndex:3];
                    if (full_account_data && ![full_account_data isKindOfClass:[NSNull class]]){
                        [[AppCacheManager sharedAppCacheManager] updateWalletAccountInfo:full_account_data];
                    }
                    //  启动完毕备份钱包
                    [[AppCacheManager sharedAppCacheManager] autoBackupWalletToWebdir:NO];
                    //  添加ticker更新任务
                    [[ScheduleManager sharedScheduleManager] autoRefreshTickerScheduleByMergedMarketInfos];
                    //  初始化网络成功
                    [OrgUtils logEvents:@"appInitNetworkDone" params:@{}];
                    resolve(@YES);
                    return nil;
                })];
            })] catch:(^id(id error) {
                reject(NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。"));
                return nil;
            })];
            return nil;
        })] catch:(^id(id error) {
            reject(NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。"));
            return nil;
        })];
    })];
}

@end
