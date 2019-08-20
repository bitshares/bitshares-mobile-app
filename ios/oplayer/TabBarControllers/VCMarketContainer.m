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

#import "OrgUtils.h"

@interface VCMarketContainer ()
{
    BOOL                        _selfShowing;                       //  首页自身是否显示中
    BOOL                        _grapheneInitDone;                  //  石墨烯网络是否初始化完毕
    NSTimer*                    _tickerRefreshTimer;                //  ticker 数据定时刷新计时器
}

@end

@implementation VCMarketContainer

-(void)dealloc
{
    //  移除初始化完成事件监听
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kBtsAppEventInitDone object:nil];
    
    //  移除前后台事件
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _selfShowing = YES;
        _grapheneInitDone = NO;
        _tickerRefreshTimer = nil;
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
        _tickerRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               target:self
                                                             selector:@selector(onTimerTickerRefresh:)
                                                             userInfo:nil
                                                              repeats:YES];
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

- (void)_onAppInitDone:(NSNotification*)notification
{
    //  初始化完毕
    _grapheneInitDone = YES;
    
    //  初始化完成：刷新各市场ticker数据
    if (_subvcArrays) {
        for (VCMarketInfo* vc in _subvcArrays) {
            [vc marketTickerDataInitDone];
        }
    }
}

/**
 *  事件 - 添加交易对
 */
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_onAppInitDone:)
                                                 name:kBtsAppEventInitDone object:nil];
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
