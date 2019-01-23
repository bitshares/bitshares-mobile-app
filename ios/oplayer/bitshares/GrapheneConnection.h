//
//  GrapheneConnection.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//  管理一个石墨烯网络连接，包括各种api封装。

#import <Foundation/Foundation.h>
#import "GrapheneApi.h"
#import "Extension.h"

@class GrapheneApi;
@interface GrapheneConnection : NSObject

@property (nonatomic, strong) GrapheneApi* api_db;
@property (nonatomic, strong) GrapheneApi* api_net;
@property (nonatomic, strong) GrapheneApi* api_history;

@property (nonatomic, assign) CFAbsoluteTime time_cost_init;

- (id)initWithNode:(NSDictionary*)ws_node_config max_retry_num:(NSInteger)max_retry_num connect_timeout:(NSInteger)connect_timeout;

- (WsPromise*)run_connection;
- (BOOL)isClosed;

/**
 *  (public) 执行请求，可指定是否重连。
 */
- (WsPromise*)call:(NSArray*)params auto_reconnect:(BOOL)auto_reconnect;
- (WsPromise*)call:(NSArray*)params;

@end
