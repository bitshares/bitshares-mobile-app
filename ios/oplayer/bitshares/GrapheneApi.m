//
//  GrapheneApi.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "GrapheneApi.h"
#import "GrapheneConnection.h"

@interface GrapheneApi()
{
    __weak GrapheneConnection*  _conn;                 //  REMARK：声明为 weak，否则会导致循环引用。
    NSString*                   _apiname;
    NSNumber*                   _api_id;
}
@end

@implementation GrapheneApi

- (id)initWithConnection:(GrapheneConnection*)conn andApi:(NSString*)apiname
{
    self = [super init];
    if (self)
    {
        _conn = conn;
        _apiname = apiname;
        _api_id = nil;
    }
    return self;
}

- (void)close
{
    //  only clear api id
    _api_id = nil;
}

- (BOOL)isInited
{
    return _api_id != nil;
}

-(void)dealloc
{
    _conn = nil;
    _apiname = nil;
    _api_id = nil;
}

/*
 *  初始化API，失败会触发reject。
 */
- (WsPromise*)api_init
{
    //  初始化api标示符
    assert(_conn);
    return [[_conn call:@[@(1), _apiname, @[]] auto_reconnect:NO] then:(^id(id data) {
        _api_id = (NSNumber*)data;
        return @YES;
    })];
}

/*
 *  安全的初始化API，失败不会reject，仅返回false。
 */
- (WsPromise*)safe_api_init
{
    return [[[self api_init] then:^id(id data) {
        return data;
    }] catch:^id(id error) {
        _api_id = nil;
        return @NO;
    }];
}

- (WsPromise*)exec:(NSString*)method
{
    return [self exec:method params:@[]];
}

- (WsPromise*)exec:(NSString*)method params:(NSArray*)params
{
    return [self exec:method params:params auto_reconnect:YES];
}

- (WsPromise*)exec:(NSString*)method params:(NSArray*)params auto_reconnect:(BOOL)auto_reconnect
{
    //  TODO:fowallet error
    assert(_conn);
    if (!_api_id){
        return [WsPromise reject:@"not initialized..."];
    }
    return [[_conn call:@[_api_id, method, params] auto_reconnect:auto_reconnect] catch:^id (id error) {
        NSLog(@"error ---- %@", error);
        [WsPromiseException throwException:error];
        return nil;
    }];
}

@end
