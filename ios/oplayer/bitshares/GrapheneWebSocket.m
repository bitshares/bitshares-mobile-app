//
//  GrapheneWebSocket.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "GrapheneWebSocket.h"
#import "OrgUtils.h"

#import <Crashlytics/Crashlytics.h>
#import <Flurry/Flurry.h>

#define kGwsKeepAliveINterval   5000
#define kGwsMaxSendLife         4
#define kGwsMaxRecvLife         10
#define kGwsConnectPromiseKey   @"__connectPromiseCallback"

@interface GrapheneWebSocket()
{
    SRWebSocket*                _webSocket;
    NSString*                   _url;
    KeepAliveCallback           _keepAliveCb;
    
    __weak WsPromise*           __weak_connect_promise;
    BOOL                        _closed;
    
    NSUInteger                  _cbId;
    NSMutableDictionary*        _cbs;       //  普通请求的回调函数列表
    NSMutableDictionary*        _subs;      //  订阅推送回调列表
    NSMutableDictionary*        _unsub;     //  取消订阅
    
    NSTimer*                    _keepAliveTimer;
    NSInteger                   _send_life;
    NSInteger                   _recv_life;
}
@end

@implementation GrapheneWebSocket

/**
 *  (private) 处理连接超时
 */
- (void)onConnectTimeoutTrigger:(NSInteger)connectTimeoutSec
{
    //  连接成功，则连接的promise回调已经被移除了。
    id promise_callbacks = [_cbs objectForKey:kGwsConnectPromiseKey];
    if (!promise_callbacks){
        return;
    }
    
    //  连接失败
    WsRejectHandler reject = [promise_callbacks objectForKey:@"reject"];
    [_cbs removeObjectForKey:kGwsConnectPromiseKey];
    [self close_websocket];
    reject([WsPromiseException makeException:[NSString stringWithFormat:@"Connection attempt timed out after %@s", @(connectTimeoutSec)]]);
}

- (void)dealloc
{
    _url = nil;
    _keepAliveCb = nil;
    __weak_connect_promise = nil;
    
    _cbs = nil;
    _subs = nil;
    [self close_websocket];
}

- (id)initWithServer:(NSString*)url connect_timeout:(NSInteger)connect_timeout keepaliveCb:(KeepAliveCallback)keepaliveCb
{
    self = [super init];
    if (self)
    {
        _webSocket = nil;
        _url = url;
        _keepAliveCb = keepaliveCb;
        _closed = NO;
        
        _cbId = 0;
        _cbs = [NSMutableDictionary dictionary];
        _subs = [NSMutableDictionary dictionary];
        _unsub = [NSMutableDictionary dictionary];
        
        _keepAliveTimer = nil;
        _send_life = kGwsMaxSendLife;
        _recv_life = kGwsMaxRecvLife;
        
        //  --- 开始初始化 ---
        __weak_connect_promise = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
            //  保存 resolve 和 reject（这里cbs等会对promise保留引用，因此self里用weak即可，不然会循环引用。
            [_cbs setObject:@{@"resolve":resolve, @"reject":reject} forKey:kGwsConnectPromiseKey];
            //  连接socket
            _webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
            _webSocket.delegate = self;
            [_webSocket open];
        }];
        
        //  连接超时定时器
        __weak id this = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(connect_timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (this){
                [this onConnectTimeoutTrigger:connect_timeout];
            }
        });
    }
    return self;

}

- (WsPromise*)login:(NSString*)username password:(NSString*)password
{
    assert(__weak_connect_promise);
    return [__weak_connect_promise then:(^id(id data) {
        return [self call:@[@(1), @"login", @[username, password]]];
    })];
}

- (WsPromise*)call:(NSArray*)params
{
    //  已经断线
    if (_closed){
        return [WsPromise reject:[WsPromiseException makeException:@"连接已关闭..."]];
    }
    
    //  ID计数器
    _cbId++;
    
    //  部分方法特殊处理
    NSString* method = [params objectAtIndex:1];
    if ([method isEqualToString:@"set_subscribe_callback"] ||
        [method isEqualToString:@"subscribe_to_market"] ||
        [method isEqualToString:@"broadcast_transaction_with_callback"] ||
        [method isEqualToString:@"set_pending_transaction_callback"])
    {
        id old_sub_params = [params objectAtIndex:2];
        id sub_callback = [old_sub_params firstObject];
        
        //  订阅的callback替换为cbId传送到服务器。
        id sub_params_mutable = [old_sub_params mutableCopy];
        [sub_params_mutable replaceObjectAtIndex:0 withObject:@(_cbId)];
        id new_sub_params = [sub_params_mutable copy];
        
        //  保存订阅callback
        [_subs setObject:sub_callback forKey:@(_cbId)];
        
        //  更新订阅接口的参数信息
        id new_params = [params mutableCopy];
        [new_params replaceObjectAtIndex:2 withObject:new_sub_params];
        params = [new_params copy];
    }
    
    //  取消订阅
    if ([method isEqualToString:@"unsubscribe_from_market"] ||
        [method isEqualToString:@"unsubscribe_from_accounts"])
    {
        id old_sub_params = [params objectAtIndex:2];
        id unsub_callback = [old_sub_params firstObject];
        for (id key in _subs) {
            id cb = [_subs objectForKey:key];
            if ([cb isEqual:unsub_callback]){
                [_unsub setObject:key forKey:@(_cbId)];
                break;
            }
        }
        
        //  移除第一个 callback 参数
        id sub_params_mutable = [old_sub_params mutableCopy];
        [sub_params_mutable removeObjectAtIndex:0];
        id new_params = [params mutableCopy];
        [new_params replaceObjectAtIndex:2 withObject:[sub_params_mutable copy]];
        params = [new_params copy];
    }
    
    //  TODO:fowallet 取消订阅 unsubscribe_from_market unsubscribe_from_accounts
    NSLog(@"[ApiCall] %@", method);
    
    //  序列化
    NSError* err = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:@{@"id":@(_cbId), @"method":@"call", @"params":params}
                                                   options:NSJSONReadingAllowFragments
                                                     error:&err];
    if (err || !data){
        return [WsPromise reject:[WsPromiseException makeException:err]];
    }
    _send_life = kGwsMaxSendLife;

    //  构造promise对象并发送数据
    WsPromise* p = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        NSError* error = nil;
        BOOL ret = [_webSocket sendData:data error:&error];
        if (!ret || error){
            reject([WsPromiseException makeException:error]);
        }else{
            [_cbs setObject:@{@"resolve":resolve, @"reject":reject} forKey:@(_cbId)];
        }
    }];
    return p;
}

/**
 *  (private) 处理服务器响应
 */
- (void)listener:(id)response
{
    assert(response);
    
    id callback_id = [response objectForKey:@"id"];
    BOOL sub = NO;
    
    //  {"method":"notice","params":[notify_id,notify_data...]]}
    id method = [response objectForKey:@"method"];
    if (method && [method isEqualToString:@"notice"]){
        sub = YES;
        callback_id = [[response objectForKey:@"params"] firstObject];
    }
    
    id callback;
    if (sub){
        callback = [_subs objectForKey:callback_id];
    }else{
        callback = [_cbs objectForKey:callback_id];
    }
    
    if (callback && sub)
    {
        //  订阅方法 callback
        WsNotifyCallback cb = (WsNotifyCallback)callback;
        if (cb(YES, [[response objectForKey:@"params"] objectAtIndex:1])){
            //  移除 callback
            [_subs removeObjectForKey:callback_id];
        }
    }
    else if (callback && !sub)
    {
        //  普通请求 callback
        [_cbs removeObjectForKey:callback_id];   //  remove
        
        //  API调用是否异常判断
        id resp_error = [response objectForKey:@"error"];
        if (resp_error){
            //  TODO:fowallet 错误分类统计
            
            //  错误格式：
            //    @{"code":"1", @"data":@{@"code":@"code", @"message":@"base error message", @"name":@"xx", @"stack":@{}}, @"message":@"detail message"}
            //  [统计]
            if ([resp_error isKindOfClass:[NSDictionary class]]){
                id detail_error_message = [resp_error objectForKey:@"message"];
                id error_data = [resp_error objectForKey:@"data"];
                if (error_data){
                    id error_message = [error_data objectForKey:@"message"];
                    id error_stack = [error_data objectForKey:@"stack"];
                    id error_code = [error_data objectForKey:@"code"];
                    if (error_message && error_code && error_stack && [error_stack count] > 0){
                        
                        NSError* log_err = nil;
                        NSString* log_str = nil;
                        NSData* log_data = [NSJSONSerialization dataWithJSONObject:resp_error
                                                                           options:NSJSONReadingAllowFragments
                                                                             error:&log_err];
                        if (!log_err && log_data){
                            log_str = [[NSString alloc] initWithData:log_data encoding:NSUTF8StringEncoding];
                        }
                        [OrgUtils logEvents:[NSString stringWithFormat:@"api_error_%@", error_code]
                                     params:@{@"last_stack":[error_stack lastObject],
                                              @"message":error_message,
                                              @"detail_message":detail_error_message ? : @"",
                                              @"error":log_str ? : @""
                                              }];
                    }
                }
                if (detail_error_message){
                    CLS_LOG(@"graphene api error: %@", detail_error_message);
                }
            }
            //  resp_error 可能为 {message, data, code} 格式的 Hash。
            WsResolveHandler reject = [callback objectForKey:@"reject"];
            reject([WsPromiseException makeException:resp_error]);
        }else{
            WsResolveHandler resolve = [callback objectForKey:@"resolve"];
            resolve([response objectForKey:@"result"]);
        }
        //  取消订阅
        id unsub_id = [_unsub objectForKey:callback_id];
        if (unsub_id){
            [_subs removeObjectForKey:unsub_id];
            [_unsub removeObjectForKey:callback_id];
        }
    }
    else
    {
        NSLog(@"Warning: unknown websocket response: %@", response);
    }
}

- (void)close_websocket
{
    if (_webSocket){
        _webSocket.delegate = nil;
        [_webSocket close];
        _webSocket = nil;
    }
}

- (void)close
{
    [self processWebsocketErrorOrClose:@"user close..."];
}

- (BOOL)isClosed
{
    return _closed;
}

#pragma mark- for keepAliveTimer
- (void)startKeepAliveTimer
{
    if (!_keepAliveTimer){
        _keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                           target:self
                                                         selector:@selector(onKeepAliveTimerTick)
                                                         userInfo:nil
                                                          repeats:YES];
        [_keepAliveTimer fire];
    }
}

- (void)stopKeepAliveTimer
{
    if (_keepAliveTimer){
        [_keepAliveTimer invalidate];
        _keepAliveTimer = nil;
    }
}

- (void)onKeepAliveTimerTick
{
    --_recv_life;
    if (_recv_life <= 0){
        NSLog(@"%@ connection is dead, terminating ws", _url);
        [self processWebsocketErrorOrClose:@"heartbeat..."];
        return;
    }
    
    --_send_life;
    if (_send_life <= 0){
        if (_keepAliveCb){
            _keepAliveCb(_closed);
        }
        _send_life = kGwsMaxSendLife;
    }
}

#pragma mark- for SRWebSocketDelegate

/**
 Called when any message was received from a web socket.
 This method is suboptimal and might be deprecated in a future release.
 
 @param webSocket An instance of `SRWebSocket` that received a message.
 @param message   Received message. Either a `String` or `NSData`.
 */
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    //  重置接受数据包的心跳计数
    _recv_life = kGwsMaxRecvLife;
    
    //  解析服务器响应为 json 格式
    NSData* data = nil;
    if ([message isKindOfClass:[NSString class]]){
        data = [message dataUsingEncoding:NSUTF8StringEncoding];
    }else{
        data = (NSData*)message;
    }
    NSError* err = nil;
    id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&err];
    if (err || !response){
        [self processWebsocketErrorOrClose:err];
        return;
    }
    
    //  处理响应
    [self listener:response];
}

/**
 Called when a given web socket was open and authenticated.
 
 @param webSocket An instance of `SRWebSocket` that was open.
 */
- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    //  REMARK：如果刚连接成功就已经超时了，则该callback可能为空。
    id promise_callbacks = [_cbs objectForKey:kGwsConnectPromiseKey];
    if (!promise_callbacks){
        return;
    }
    
    WsResolveHandler resolve = [promise_callbacks objectForKey:@"resolve"];
    [_cbs removeObjectForKey:kGwsConnectPromiseKey];
    
    //  REMARK：心跳定时器
    [self startKeepAliveTimer];
    
    //  连接成功
    resolve(@"websocket opened...");
}

/**
 *  (private) 处理网络异常 or 网络关闭。
 */
- (void)processWebsocketErrorOrClose:(id)error
{
    if (!_closed){
        //  关闭标记
        _closed = YES;
        
        //  promise_callbacks 存在则为连接异常，否则是通讯异常。
        id promise_callbacks = [_cbs objectForKey:kGwsConnectPromiseKey];
        if (promise_callbacks){
            WsRejectHandler reject = [promise_callbacks objectForKey:@"reject"];
            [_cbs removeObjectForKey:kGwsConnectPromiseKey];
            reject([WsPromiseException makeException:error]);
        }
        
        //  取消心跳计时器
        [self stopKeepAliveTimer];
        
        //  通讯中异常：则当前的所有待完成promise全部reject
        if ([_cbs count] > 0){
            for(id key in _cbs) {
                id cb = [_cbs objectForKey:key];
                WsResolveHandler reject = [cb objectForKey:@"reject"];
                reject([WsPromiseException makeException:@"websocket closed..."]);
            }
            [_cbs removeAllObjects];
        }
        //  当前订阅的callback也全部push false。
        if ([_subs count] > 0){
            for (id key in _subs) {
                WsNotifyCallback cb = (WsNotifyCallback)[_subs objectForKey:key];
                //  NOTIFY: NO，网络中断。
                cb(NO, nil);
            }
            [_subs removeAllObjects];
        }
        [_unsub removeAllObjects];
        
        //  关闭网络连接
        [self close_websocket];
    }
}

/**
 Called when a given web socket encountered an error.
 
 @param webSocket An instance of `SRWebSocket` that failed with an error.
 @param error     An instance of `NSError`.
 */
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    NSLog(@"websocket: didFailWithError: %@", error);
    [self processWebsocketErrorOrClose:error];
}

/**
 Called when a given web socket was closed.
 
 @param webSocket An instance of `SRWebSocket` that was closed.
 @param code      Code reported by the server.
 @param reason    Reason in a form of a String that was reported by the server or `nil`.
 @param wasClean  Boolean value indicating whether a socket was closed in a clean state.
 */
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(nullable NSString *)reason wasClean:(BOOL)wasClean
{
    NSLog(@"websocket: didCloseWithCode: code: %@ reason: %@", @(code), reason);
    [self processWebsocketErrorOrClose:@"websocket closed..."];
}

@end
