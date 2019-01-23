//
//  GrapheneConnection.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "GrapheneConnection.h"
#import "GrapheneApi.h"
#import "GrapheneWebSocket.h"

#include "bts_chain_config.h"

@interface GrapheneConnection()
{
    NSString*           _url;               //  ws node url
    
    NSInteger           _max_retry_num;     //  最大重连次数。
    NSInteger           _cur_retry_num;     //  当前重连次数。
    
    NSInteger           _connect_timeout;   //  连接超时限制（单位：秒）
    
    CFAbsoluteTime      _ts_start;          //  创建连接时间戳
    CFAbsoluteTime      _ts_logined;        //  登录后时间戳
    CFAbsoluteTime      _ts_api_inited;     //  API初始化完成时间戳
    
    CFAbsoluteTime      _time_cost_init;    //  初始化耗时（从连接到login请求完毕）
    
    GrapheneWebSocket*  _wsrpc;;
    
    GrapheneApi*        _api_db;
    GrapheneApi*        _api_net;
    GrapheneApi*        _api_history;
    
    BOOL                _init_done;         //  是否初始化完毕
}
@end

@implementation GrapheneConnection

@synthesize api_db = _api_db;
@synthesize api_net = _api_net;
@synthesize api_history = _api_history;

@synthesize time_cost_init = _time_cost_init;

- (id)initWithNode:(NSString*)url max_retry_num:(NSInteger)max_retry_num connect_timeout:(NSInteger)connect_timeout
{
    self = [super init];
    if (self)
    {
        _url = url;
        _max_retry_num = max_retry_num;
        _cur_retry_num = 0;
        _connect_timeout = connect_timeout;
        
        _ts_start = 0;
        _ts_logined = 0;
        _ts_api_inited = 0;
        _time_cost_init = 0;
        
        _wsrpc = nil;
        
        //  直接初始化 api 对象，任何情况 api 都不应该为 nil。
        _api_db = [[GrapheneApi alloc] initWithConnection:self andApi:@"database"];
        _api_net= [[GrapheneApi alloc] initWithConnection:self andApi:@"network_broadcast"];
        _api_history = [[GrapheneApi alloc] initWithConnection:self andApi:@"history"];
        
        _init_done = NO;
    }
    return self;
}

- (void)dealloc
{
    [self close_connection];
    self.api_db = nil;
    self.api_net = nil;
    self.api_history = nil;
}

/**
 *  关闭连接
 */
- (void)close_connection
{
    if (_wsrpc){
        [_wsrpc close];
        _wsrpc = nil;
    }
    [_api_db close];
    [_api_net close];
    [_api_history close];
    _init_done = NO;
}

/**
 *  (private) 心跳
 */
- (void)onKeepAliveCallback:(BOOL)closed
{
    if ([_api_db isInited] && !closed){
        [[[_api_db exec:@"get_objects" params:@[@[BTS_DYNAMIC_GLOBAL_PROPERTIES_ID]] auto_reconnect:NO] then:(^id(id data) {
            NSLog(@"onKeepAliveCallback done: %@", data);
            return nil;
        })] catch:(^id(id error) {
            NSLog(@"onKeepAliveCallback error: %@", error);
            return nil;
        })];
    }
}

/**
 *  (private) 连接到API结点服务器。
 */
- (WsPromise*)connect_to_node_core
{
    //  TODO:fowallet websocket address
    //  wss://ws.hellobts.com
    //  wss://ws.gdex.top           - 巨蟹网关
    //  wss://btsapi.magicw.net/ws  - 鼓鼓钱包
    
    //  测试网络
    //  wss://node.testnet.bitshares.eu
    //  wss://testnet.nodes.bitshares.ws
    
    //  先释放连接。
    [self close_connection];
    
    _ts_start = CFAbsoluteTimeGetCurrent();
    
    //  初始化socket、建立连接
    _wsrpc = [[GrapheneWebSocket alloc] initWithServer:_url connect_timeout:_connect_timeout keepaliveCb:^(BOOL closed) {
        [self onKeepAliveCallback:closed];
    }];
    
    //  API结点登录的账号密码，公共结点大部分都为空，少数api需要登录授权。
    //  TODO:考虑配置username和password。
    NSString* rpc_username = @"";
    NSString* rpc_password = @"";
    
    //  参考：http://docs.bitshares.org/api/access.html
    //  全api文档：https://bitshares.org/doxygen/namespacegraphene_1_1app.html
    //  TODO:fowallet 其他的api：network_node、asset、crypto、debug、block需要重钱包节点开放才可以用（目前只能自己搭建节点。）
    
    //  登录连接成功，然后登录重钱包结点，大部分公共结点都不需要帐号密码授权，私有结点可以配置帐号密码访问不同权限api。
    return [[_wsrpc login:rpc_username password:rpc_password] then:(^id(id data) {
        NSLog(@"[wsnode]: %@ login responsed: %@", _url, data);
        _ts_logined = CFAbsoluteTimeGetCurrent();
        
        //  初始化api
        WsPromise* p1 = [_api_db api_init];
        WsPromise* p2 = [_api_net api_init];
        WsPromise* p3 = [_api_history api_init];
        
        return [[WsPromise all:@[p1, p2, p3]] then:(^id(id success_array) {
            NSLog(@"[wsnode]: %@ init all api done: %@", _url, success_array);
            _ts_api_inited = CFAbsoluteTimeGetCurrent();
            _time_cost_init = _ts_api_inited - _ts_start;
            //  设置标记：初始化完毕
            _init_done = YES;
            return @YES;
        })];
    })];
}

/**
 *  (private) 连接服务器，连接失败会继续重试，直到达到最大重试次数。
 */
- (void)connect_to_node:(WsResolveHandler)resolve reject:(WsRejectHandler)reject max_retry_num:(NSInteger)max_retry_num
{
    [[[self connect_to_node_core] then:(^id(id success) {
        NSLog(@"[wsnode]: %@ conn successful~", _url);
        resolve(@YES);
        return nil;
    })] catch:(^id(id error) {
        [self close_connection];
        if (++_cur_retry_num > max_retry_num){
            NSLog(@"[wsnode]: %@ reach max retry num, init failed", _url);
            resolve(@NO);
        }else{
            NSLog(@"[wsnode]: %@ conn failed, retry~(%@/%@)", _url, @(_cur_retry_num), @(_max_retry_num));
            [self connect_to_node:resolve reject:reject max_retry_num:max_retry_num];
        }
        return nil;
    })];
}

- (WsPromise*)run_connection_with_max_retry_num:(NSInteger)max_retry_num
{
    _cur_retry_num = 0;
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [self connect_to_node:resolve reject:reject max_retry_num:_max_retry_num];
    }];
}

/**
 *  (public) 请求连接服务器，该promise不用catch。
 */
- (WsPromise*)run_connection
{
    return [self run_connection_with_max_retry_num:_max_retry_num];
}

- (BOOL)isClosed
{
    //  尚未初始化完毕
    if (!_init_done){
        return YES;
    }
    if (!_wsrpc){
        return YES;
    }
    return [_wsrpc isClosed];
}

/**
 *  (public) 执行请求，可指定是否重连。
 */
- (WsPromise*)call:(NSArray*)params auto_reconnect:(BOOL)auto_reconnect
{
    assert(_wsrpc);
    if (auto_reconnect && [_wsrpc isClosed]){
        //  连接断开，先重连，然后再执行请求。
        return [[self run_connection_with_max_retry_num:0] then:(^id(id success) {
            if ([success boolValue]){
                return [_wsrpc call:params];
            }else{
                return [WsPromise reject:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
            }
        })];
    }else{
        //  执行请求
        return [_wsrpc call:params];
    }
}

- (WsPromise*)call:(NSArray*)params
{
    return [self call:params auto_reconnect:YES];
}

@end
