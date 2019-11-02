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

/*
 *  (public) 测试单个节点
 *  return_connect_obj - 是否返回连接对象，如果不返回则会自动释放。
 */
+ (WsPromise*)checkNodeStatus:(id)node
                max_retry_num:(NSInteger)max_retry_num
              connect_timeout:(NSInteger)connect_timeout
           return_connect_obj:(BOOL)return_connect_obj;

@property (nonatomic, strong) NSString* url;                    //  当前URL

@property (nonatomic, strong) GrapheneApi* api_db;
@property (nonatomic, strong) GrapheneApi* api_net;
@property (nonatomic, strong) GrapheneApi* api_history;
@property (nonatomic, strong) GrapheneApi* api_custom_operations;

@property (nonatomic, assign) CFAbsoluteTime time_cost_connect; //  建立连接耗时
@property (nonatomic, assign) CFAbsoluteTime time_cost_init;    //  初始化耗时（从连接到login请求完毕）

- (id)initWithNode:(NSString*)url max_retry_num:(NSInteger)max_retry_num connect_timeout:(NSInteger)connect_timeout;

- (WsPromise*)run_connection;
- (BOOL)isClosed;
/**
 *  关闭连接
 */
- (void)close_connection;

/**
 *  (public) 执行请求，可指定是否重连。
 */
- (WsPromise*)call:(NSArray*)params auto_reconnect:(BOOL)auto_reconnect;
- (WsPromise*)call:(NSArray*)params;

@end
