//
//  GrapheneConnectionManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "GrapheneConnectionManager.h"
#import "ChainObjectManager.h"

#import "NativeAppDelegate.h"
#import "MBProgressHUDSingleton.h"
#import "OrgUtils.h"
#import "SettingManager.h"

#import <Crashlytics/Crashlytics.h>

static GrapheneConnectionManager *_sharedGrapheneConnectionManager = nil;

@interface GrapheneConnectionManager()
{
    NSMutableArray*     _connection_list;       //  所有连接列表
    NSMutableArray*     _available_connlist;    //  可用连接列表
    GrapheneConnection* _last_connection;       //  上次执行请求的连接
}
@end

@implementation GrapheneConnectionManager

+(GrapheneConnectionManager *)sharedGrapheneConnectionManager
{
    @synchronized(self)
    {
        if(!_sharedGrapheneConnectionManager)
        {
            _sharedGrapheneConnectionManager = [[GrapheneConnectionManager alloc] init];
        }
        return _sharedGrapheneConnectionManager;
    }
}

+ (void)replaceWithNewGrapheneConnectionManager:(GrapheneConnectionManager*)newMgr
{
    @synchronized(self) {
        if (_sharedGrapheneConnectionManager != newMgr) {
            if (_sharedGrapheneConnectionManager) {
                [_sharedGrapheneConnectionManager close_all_connections];
            }
            _sharedGrapheneConnectionManager = newMgr;
        }
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _connection_list = nil;
        _available_connlist = nil;
        _last_connection = nil;
    }
    return self;
}

- (void)dealloc
{
    [self close_all_connections];
}

- (void)close_all_connections
{
    if (_connection_list){
        for (id conn in _connection_list) {
            [conn close_connection];
        }
        [_connection_list removeAllObjects];
        _connection_list = nil;
    }
    if (_available_connlist){
        [_available_connlist removeAllObjects];
        _available_connlist = nil;
    }
    _last_connection = nil;
}

/**
 *  (public) 初始化网络连接。
 */
- (WsPromise*)Start:(BOOL)force_use_random_node
{
    //  先关闭之前的连接
    [self close_all_connections];
    _connection_list = [NSMutableArray array];
    _available_connlist = [NSMutableArray array];
    
    //  初始化所有连接
    id network_infos = [[ChainObjectManager sharedChainObjectManager] getCfgNetWorkInfos];
    assert(network_infos);
    NSInteger max_retry_num = [network_infos[@"max_retry_num"] integerValue];
    NSInteger connect_timeout = [network_infos[@"connect_timeout"] integerValue];
    
    SettingManager* settingMgr = [SettingManager sharedSettingManager];
    //  1、获取服务器动态配置的api结点信息
    NSMutableDictionary* wssUrlHash = [NSMutableDictionary dictionary];
    NSDictionary* current_api_node = [settingMgr getApiNodeCurrentSelect];
    
    if (!force_use_random_node && current_api_node && [current_api_node objectForKey:@"url"]) {
        //  - 用户配置
        [wssUrlHash setObject:@YES forKey:[current_api_node objectForKey:@"url"]];
    } else {
        //  - 随机选择
#if GRAPHENE_BITSHARES_MAINNET
        id serverConfig = settingMgr.serverConfig;
        if (serverConfig){
            id serverWssNodes = [serverConfig objectForKey:@"wssNodes"];
            if (serverWssNodes){
                id langKey = NSLocalizedString(@"serverWssLangKey", @"langKey");
                id defaultList = [serverWssNodes objectForKey:@"default"];
                id langList = [serverWssNodes objectForKey:langKey];
                if (defaultList && [defaultList count] > 0){
                    for (id url in defaultList) {
                        [wssUrlHash setObject:@YES forKey:url];
                    }
                }
                if (langList && [langList count] > 0){
                    for (id url in langList) {
                        [wssUrlHash setObject:@YES forKey:url];
                    }
                }
            }
        }
#endif  //  GRAPHENE_BITSHARES_MAINNET
        
        //  2、获取app内配置的api结点信息
        id wslist = [network_infos objectForKey:@"ws_node_list"];
        if (wslist && [wslist count] > 0){
            for (id node in wslist) {
                [wssUrlHash setObject:@YES forKey:[node objectForKey:@"url"]];
            }
        }
        
#ifdef DEBUG
#if GRAPHENE_BITSHARES_MAINNET
        //  REMARK：DEBUG调试阶段仅连接一个节点，否则其他节点连接不上会抛出异常。（Promise中）
        [wssUrlHash removeAllObjects];
        [wssUrlHash setObject:@YES forKey:@"wss://api.weaccount.cn"];
#endif
#endif
    }
    
    //  初始化所有结点
    for (id url in [wssUrlHash allKeys]) {
        [_connection_list addObject:[[GrapheneConnection alloc] initWithNode:url
                                                               max_retry_num:max_retry_num
                                                             connect_timeout:connect_timeout]];
    }
    
    //  没有结点，直接初始化失败。
    if ([_connection_list count] <= 0){
        return [WsPromise reject:@NO];
    }
    
    //  执行连接请求，任意一个结点连接成功则返回。
    NSInteger total_conn_number = [_connection_list count];
    WsPromise* any_promise = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        __block NSInteger err_number = 0;
        for (GrapheneConnection* conn in _connection_list) {
            //  连接结点服务器，该promise不用catch，通过then的返回值判断成功与否。
            [[conn run_connection] then:(^id(id success) {
                if ([success boolValue]){
                    [_available_connlist addObject:conn];
                    resolve(@YES);
                }else{
                    //  所有结点都连接失败，则初始化失败。
                    if (++err_number >= total_conn_number){
                        reject(@NO);
                    }
                }
                return nil;
            })];
        }
    }];
    return any_promise;
}

/**
 *  (public) 获取任意可用的连接。
 */
- (GrapheneConnection*)any_connection
{
    //  TODO:fowallet 根据连接速度选择
    for (GrapheneConnection* conn in _available_connlist) {
        if (![conn isClosed]){
            _last_connection = conn;
            return conn;
        }
    }
    //  全部都未连接，则返回第一个，会自动重连。
    _last_connection = [_connection_list firstObject];
    //    CLS_LOG(@"any_connection: closed: db_api: %@", @([_last_connection.api_db isInited]));
    return _last_connection;
}

/**
 *  (public) 获取上次执行请求的连接，如果该连接异常了则自动获取另外的连接。
 */
- (GrapheneConnection*)last_connection
{
    if (_last_connection){
        return _last_connection;
    }
    return [self any_connection];
}

/**
 *  (public) 重连所有已断开的连接，后台回到前台考虑执行。
 */
- (void)reconnect_all
{
    //  BlockView显示中的情况，暂时不考虑重连。后期处理 TODO:fowallet
    if ([[MBProgressHUDSingleton sharedMBProgressHUDSingleton] is_showing]){
        return;
    }
    
    //  统计断开的连接数
    NSMutableArray* closed_connections = [NSMutableArray array];
    for (GrapheneConnection* conn in _available_connlist) {
        if ([conn isClosed]){
            [closed_connections addObject:conn];
        }
    }
    
    //  全部连接正常，则返回。
    if ([closed_connections count] <= 0){
        return;
    }
    
    //  开始重连所有断开的连接。
    MBProgressHUDSingleton* blockView = [MBProgressHUDSingleton sharedMBProgressHUDSingleton];
    //  TODO:fowallet 文案
    [blockView showWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")
                     andView:[NativeAppDelegate sharedAppDelegate].window];
    NSInteger total_conn_number = [closed_connections count];
    WsPromise* any_promise = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        __block NSInteger err_number = 0;
        for (GrapheneConnection* conn in closed_connections) {
            [[conn run_connection] then:(^id(id success) {
                if ([success boolValue]){
                    resolve(@YES);
                }else{
                    //  所有结点都连接失败，则初始化失败。
                    if (++err_number >= total_conn_number){
                        reject(@NO);
                    }
                }
                return nil;
            })];
        }
    }];
    //  等待连接
    [[any_promise then:(^id(id data) {
        [blockView hide];
        //  通知 - 重连成功
        [[NSNotificationCenter defaultCenter] postNotificationName:kBtsWebsocketReconnectSuccess object:nil userInfo:nil];
        return nil;
    })] catch:(^id(id error) {
        [blockView hide];
        //  TODO:fowallet 连接断开...
        //  TODO:fowallet 连接所有结点都失败
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    })];
}

/*
 *  (public) 切换到自定义连接
 */
- (void)switchTo:(GrapheneConnection*)new_conn
{
    assert(new_conn);
    
    //  先关闭现有的连接
    [self close_all_connections];
    _connection_list = [NSMutableArray array];
    _available_connlist = [NSMutableArray array];
    
    //  切换到新的连接
    [_connection_list addObject:new_conn];
    [_available_connlist addObject:new_conn];
    _last_connection = new_conn;
}

@end
