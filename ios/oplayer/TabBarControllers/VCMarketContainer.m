//
//  VCMarketContainer.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCMarketContainer.h"
#import "BitsharesClientManager.h"
#import "GrapheneConnectionManager.h"
#import "ScheduleManager.h"
#import "GrapheneApi.h"

#import "VCMarketInfo.h"

#import <SocketRocket/SocketRocket.h>

#import "secp256k1.h"
#import "secp256k1_recovery.h"

#import "VCTest.h"

#import "VCSearchNetwork.h"

#import "AppCacheManager.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "OrgUtils.h"
#import "MBProgressHUDSingleton.h"

#import "MySecurityFileMgr.h"

#import "OrgUtils.h"

@interface VCMarketContainer ()
{
    BOOL                        _selfShowing;                       //  首页自身是否显示中
//    BOOL                        _jsbFirstTimeInitDone;              //  jsb首次初始化是否已经初始化完毕。
//    BOOL                        _jsBridgeInited;
    BOOL                        _isJailbroken;
    BOOL                        _grapheneInitDone;                  //  石墨烯网络是否初始化完毕
    NSTimer*                    _tickerRefreshTimer;                //  ticker 数据定时刷新计时器

    UIAlertView*                _upgradeAppTips;
    NSMutableDictionary*        _waitShowResdataUpdateWindowArgs;   //  等待显示资源更新窗口，并保存部分参数等。
}

@end

@implementation VCMarketContainer

-(void)dealloc
{
    //  移除前后台事件
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [self disposeWaitShowResdataUpdateWindowArgs];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)disposeWaitShowResdataUpdateWindowArgs
{
    if (_waitShowResdataUpdateWindowArgs){
        [_waitShowResdataUpdateWindowArgs removeAllObjects];
        _waitShowResdataUpdateWindowArgs = nil;
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _selfShowing = YES;
//        _jsbFirstTimeInitDone = NO;
        _grapheneInitDone = NO;
        _tickerRefreshTimer = nil;
        _waitShowResdataUpdateWindowArgs = nil;
    }
    return self;
}

#pragma mark- ticker ui refresh timer

- (void)startTimerTickerRefresh
{
    if (!_grapheneInitDone){
        return;
    }
    if (!_tickerRefreshTimer){
        _tickerRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(onTimerTickerRefresh:) userInfo:nil repeats:YES];
        [_tickerRefreshTimer fire];
    }
}

- (void)onTimerTickerRefresh:(NSTimer*)timer
{
    if ([TempManager sharedTempManager].tickerDataDirty){
        //  清除标记
        [TempManager sharedTempManager].tickerDataDirty = NO;
        //  刷新
        if (_subvcArrays){
            for (VCMarketInfo* vc in _subvcArrays) {
                [vc onRefreshTickerData];
            }
        }
    }
}

- (void)stopTimerTickerRefresh
{
    if (_tickerRefreshTimer){
        [_tickerRefreshTimer invalidate];
        _tickerRefreshTimer = nil;
    }
}

#pragma mark- foreground & background event notification

//  事件：已经进入前台
- (void)onUIApplicationDidBecomeActiveNotification
{    
    //  检测语言是否发生变化，变化后重新初始化jsb。并删除之前多config缓存。
    BOOL langChanged = NO;
    NSString* lang = [NativeAppDelegate getSystemLanguage];
    if (![lang isEqualToString:[NativeAppDelegate sharedAppDelegate].currLanguage]){
        langChanged = YES;
        //  重新初始化语言
        [[NativeAppDelegate sharedAppDelegate] initLanguageInfo];
        NSLog(@"system language changed...");
    }
    
    //  TODO:fowallet
    
//    //  从后台返回前台，时间间隔超过固定时间并且首页显示中则检测更新。
//    NSTimeInterval diff = [[NSDate date] timeIntervalSince1970] - [TempManager sharedTempManager].lastEnterBackgroundTs;
//    if (langChanged || diff >= kBackToForegroundCheckupdateTimespace){
//        [self checkUpdate:YES];
//    }else{
//        //  不检测更新的时候判断代理：如果代理变化了则强制调用 Init。
//        BOOL useHttpProxy = [[SettingManager sharedSettingManager] useHttpProxy];
//        if (useHttpProxy != [TempManager sharedTempManager].lastUseHttpProxy){
//            CLS_LOG(@"back to foreground: call init when httpproxy flag changed. new value: %d", (int)useHttpProxy);
//            //  TODO:fowallet proxy changed...
//        }
//    }
    
    //  回到前台检测是否需要重新连接。
    if (_grapheneInitDone){        
        [[GrapheneConnectionManager sharedGrapheneConnectionManager] reconnect_all];
    }
}

//  事件：将要进入后台
- (void)onUIApplicationWillResignActiveNotification
{
    CLS_LOG(@"will enter background");
    //  [统计]
    [OrgUtils logEvents:@"enterBackground" params:@{}];
    //  处理逻辑
    [[AppCacheManager sharedAppCacheManager] saveToFile];
    //  记录即将进入后台的时间
    [TempManager sharedTempManager].lastEnterBackgroundTs = [[NSDate date] timeIntervalSince1970];
    //  记录当前http代理标记
    [TempManager sharedTempManager].lastUseHttpProxy = [[SettingManager sharedSettingManager] useHttpProxy];
}

//  事件：已经进入后台
- (void)onUIApplicationDidEnterBackgroundNotification
{
    CLS_LOG(@"did enter background");
}

//  事件：将要进入前台
- (void)onUIApplicationWillEnterForegroundNotification
{
    CLS_LOG(@"will enter foreground");
    //  [统计]
    [OrgUtils logEvents:@"enterForeground" params:@{}];
}

- (void)onAddMarketInfos
{
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAsset callback:nil];
    vc.title = NSLocalizedString(@"kVcTitleCustomPairs", @"添加交易对");
    [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
}

- (NSInteger)getTitleDefaultSelectedIndex
{
    //  REMARK：默认选中第二个市场（第一个是自选市场）
    return 2;
}

- (NSArray*)getTitleStringArray
{
    NSMutableArray* ary = [NSMutableArray arrayWithObject:NSLocalizedString(@"kLabelMarketFavorites", @"自选")];
    [ary addObjectsFromArray:[[[ChainObjectManager sharedChainObjectManager] getMergedMarketInfos] ruby_map:(^id(id market) {
        return [[market objectForKey:@"base"] objectForKey:@"name"];
    })]];
    return [ary copy];
}

- (NSArray*)getSubPageVCArray
{
    //  REMARK：marketInfo 参数为 nil，说明为自选市场。
    NSMutableArray* ary = [NSMutableArray arrayWithObject:[[VCMarketInfo alloc] initWithOwner:self marketInfo:nil]];
    NSArray* base = [[[ChainObjectManager sharedChainObjectManager] getMergedMarketInfos] ruby_map:(^id(id market) {
        return [[VCMarketInfo alloc] initWithOwner:self marketInfo:market];
    })];
    [ary addObjectsFromArray:base];
    return [ary copy];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  右边➕按钮
    UIBarButtonItem* addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                            target:self
                                                                            action:@selector(onAddMarketInfos)];
    addBtn.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
    self.navigationItem.rightBarButtonItem = addBtn;
    
	// Do any additional setup after loading the view.
    
    //  注册前后台事件
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUIApplicationDidBecomeActiveNotification)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUIApplicationWillResignActiveNotification)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUIApplicationDidEnterBackgroundNotification)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onUIApplicationWillEnterForegroundNotification)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    _isJailbroken = [NativeAppDelegate isJailbroken];
    
    //  检测更新
    [self checkUpdate:NO];
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
         [self startInitGrapheneNetwork];
     }];
}

/**
 *  (private) 初始化 Bitshares 网络
 */
- (void)startInitGrapheneNetwork
{
    _grapheneInitDone = NO;
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsInitialize", @"初始化中…")];
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
                //  更新各市场ticker数据
                for (VCMarketInfo* vc in _subvcArrays) {
                    [vc marketTickerDataInitDone];
                }
                //  设置初始化完毕标记
                _grapheneInitDone = YES;
                //  添加ticker更新任务
                [[ScheduleManager sharedScheduleManager] autoRefreshTickerScheduleByMergedMarketInfos];
                //  初始化网络成功
                [OrgUtils logEvents:@"appInitNetworkDone" params:@{}];
                return nil;
            })];
        })] catch:(^id(id error) {
            [self hideBlockView];
            CLS_LOG(@"InitNetworkError02: %@", error);
            [self onFirstInitFailed];
            return nil;
        })];
        return nil;
    })] catch:(^id(id error) {
        [self hideBlockView];
        CLS_LOG(@"InitNetworkError01: %@", error);
        [self onFirstInitFailed];
        return nil;
    })];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //  自选市场可能发生变化，重新加载。
    [self onRefreshFavoritesMarket];
    //  自定义交易对发生变化，重新加载。
    [self onRefreshCustomMarket];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _selfShowing = YES;
    
    //  启动UI刷新定时器
    [self startTimerTickerRefresh];
}

- (void)viewDidDisappear:(BOOL)animated
{
    //  停止UI刷新计时器
    [self stopTimerTickerRefresh];
    
    _selfShowing = NO;
    [super viewDidDisappear:animated];
}

/**
 *  (private) 事件 - 刷新自选(关注、收藏)市场
 */
- (void)onRefreshFavoritesMarket
{
    if ([TempManager sharedTempManager].favoritesMarketDirty){
        //  清除标记
        [TempManager sharedTempManager].favoritesMarketDirty = NO;
        //  刷新
        if (_subvcArrays){
            for (VCMarketInfo* vc in _subvcArrays) {
                [vc onRefreshFavoritesMarket];
            }
        }
    }
}
/**
 *  (private) 事件 - 刷新自定义交易对市场 同时刷新收藏列表（因为变更自定义交易对，可能导致收藏失效。）
 */
- (void)onRefreshCustomMarket
{
    if ([TempManager sharedTempManager].customMarketDirty){
        //  重新构建各市场分组信息
        [[ChainObjectManager sharedChainObjectManager] buildAllMarketsInfos];
        //  清除标记
        [TempManager sharedTempManager].customMarketDirty = NO;
        //  刷新
        if (_subvcArrays){
            for (VCMarketInfo* vc in _subvcArrays) {
                [vc onRefreshCustomMarket];
                [vc onRefreshFavoritesMarket];
            }
        }
        //  自定义交易对发生变化，重新刷新ticker更新任务。
        [[ScheduleManager sharedScheduleManager] autoRefreshTickerScheduleByMergedMarketInfos];
    }
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

/**
 *  (private) 检测更新：back_to_foreground 为 true 则为从后台回到前台时检测，为 false 则为初始化时检测。
 */
- (void)checkUpdate:(BOOL)back_to_foreground
{
    if (back_to_foreground){
        CLS_LOG(@"back to foreground checkUpdate");
        //  从后台回到前台检测更新在首次初始化尚未初始化完毕的情况下则直接返回。
        if (!_grapheneInitDone){
            CLS_LOG(@"checkUpdate cancel, first time initing...");
            return;
        }
    }
    
    //  1、首次启动添加blockview初始化。
    //  2、如果是从后台进入前台，则在获取version和调用Init都不用等待。
    if (!back_to_foreground){
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsInitialize", @"初始化中…")];
    }

#if DEBUG && !TEST_UPDATE
    //  调试模式：直接加载本地version.json
    NSDictionary* pVersionJson = [self loadBundleVersionJson];
    [self onLoadVersionJsonFinish:pVersionJson back_to_foreground:back_to_foreground updateversion:NO];
#else
    //  正式环境 or 测试更新模式下 从服务器加载。
    NSString* pNativeVersion = [NativeAppDelegate appShortVersion];
    NSString* flags = @"0";
#if APPSTORE_CHANNEL
    id version_url = [NSString stringWithFormat:@"https://btspp.io/app/a_%@/version.json?f=%@", pNativeVersion, flags];
#else
    id version_url = [NSString stringWithFormat:@"https://btspp.io/app/e_%@/version.json?f=%@", pNativeVersion, flags];
#endif  //  APPSTORE_CHANNEL
    [OrgUtils asyncFetchJson:version_url
                     timeout:[[NativeAppDelegate sharedAppDelegate] getRequestTimeout]
             completionBlock:^(id pVersionJson)
     {
         BOOL updateversionjson;

         if (!pVersionJson)
         {
             //  网络或服务器异常加载version.json失败，则使用本地文件。
             NSLog(@"error>fetch version.json failed, use native...");
             pVersionJson = [self loadNativeVersionJson];
             //  REMARK：本来就是本地读取出来的则不用重新写入了
             updateversionjson = NO;
         }
         else
         {
             // 加载成功默认更新本地的version.json
             updateversionjson = YES;
         }

         //  处理version.json加载后逻辑。
         [self onLoadVersionJsonFinish:pVersionJson back_to_foreground:back_to_foreground updateversion:updateversionjson];
     }];
#endif
}

/**
 *  (private) 处理 version.json 加载完毕事件。
 */
- (void)onLoadVersionJsonFinish:(NSDictionary*)pConfig back_to_foreground:(BOOL)back_to_foreground updateversion:(BOOL)updateversionjson
{
    //  服务器 or 本地加载都异常了 REMARK：这种情况记录一个CLS_LOG后直接初始化（应该是被人debug修改错乱了。）
    if (!pConfig)
    {
        CLS_LOG(@"onLoadVersionJsonFinish: load version.json error");
        [self startInitGrapheneNetwork];
        return;
    }

    CLS_LOG(@"onLoadVersionJsonFinish: asyncFetchJson done, blockview: %@", @([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]));

    //  需要更新时 version.json 写入文件，如果直接从本地读取出来的情况则不用重新写入。
    if (updateversionjson){
        NSString* pCacheVersionFilename = [OrgUtils makeFullPathByVerStorage:kAppCacheNameVersionJsonByVer];
        [MySecurityFileMgr saveSecFile:pConfig path:pCacheVersionFilename];
    }

    //  更新广告数据
    //  ... TODO:fowallet 待添加

    //  保存所有配置
    [SettingManager sharedSettingManager].serverConfig = [NSDictionary dictionaryWithDictionary:pConfig];

    //  启用功能
    //  flagxxx标记
    //  ...TODO:fowallet 以后添加

    //  检测app是否可以更新
    NSString* pNativeVersion = [NativeAppDelegate appShortVersion];
    BOOL appVersionEqual = NO; //  默认设置为不能，不更新js。
    NSString* pNewestVersion = [pConfig objectForKey:@"version"];
    if (pNewestVersion)
    {
        NSInteger ret = [OrgUtils compareVersion:pNewestVersion other:pNativeVersion];
        appVersionEqual = ret == 0;
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
        }
    }
    
    //  初始化石墨烯（不论是否弹框升级都初始化网络）
    [self startInitGrapheneNetwork];
}

///**
// *  免费声明提示
// */
//- (void)freeTips:(void (^)())continue_callback
//{
//    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
//    NSString* firstFreeTipsReviewd = (NSString*)[pAppCache getPref:@"firstFreeTipsReviewd" defaultValue:nil];
//    if (firstFreeTipsReviewd && [firstFreeTipsReviewd boolValue]){
//        continue_callback();
//        return;
//    }
//    
//    [[UIAlertViewManager sharedUIAlertViewManager] showMessage:@"BTS++官方版本完全免费，无代理费，无手续费，无加速包。任何收费版本皆为山寨版本，遇到山寨版本请与我们联系。"
//                                                     withTitle:NSLocalizedString(@"kWarmTips", @"温馨提示")
//                                                    completion:^(NSInteger buttonIndex)
//    {
//        //  不在提示
//        [pAppCache setPref:@"firstFreeTipsReviewd" value:@"1"];
//        [pAppCache saveCacheToFile];
//        //  回调
//        continue_callback();
//    }];
//}
//

/**
 *  提示app更新
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

#pragma mark- switch theme
- (void)switchTheme
{
    [super switchTheme];
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    self.navigationItem.rightBarButtonItem.tintColor = [ThemeManager sharedThemeManager].navigationBarTextColor;
}

#pragma mark- switch language
- (void)switchLanguage
{
    [[self buttonWithTag:1] setTitle:NSLocalizedString(@"kLabelMarketFavorites", @"自选") forState:UIControlStateNormal];
    self.title = NSLocalizedString(@"kTabBarNameMarkets", @"行情");
    self.tabBarItem.title = NSLocalizedString(@"kTabBarNameMarkets", @"行情");
    if (_subvcArrays){
        for (VCMarketInfo* vc in _subvcArrays) {
            [vc switchLanguage];
        }
    }
}

@end
