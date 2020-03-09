//
//  GrapheneConnectionManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//  负责网络连接的测速、管理、有效性检测等。

#import <Foundation/Foundation.h>
#import "GrapheneConnection.h"
#import "WsPromise.h"
#import "Extension.h"

@interface GrapheneConnectionManager : NSObject

+ (GrapheneConnectionManager*)sharedGrapheneConnectionManager;
+ (void)replaceWithNewGrapheneConnectionManager:(GrapheneConnectionManager*)newMgr;

- (WsPromise*)Start:(BOOL)force_use_random_node;

/**
 *  (public) 获取任意可用的连接。
 */
- (GrapheneConnection*)any_connection;

/**
 *  (public) 获取上次执行请求的连接，如果该连接异常了则自动获取另外的连接。
 */
- (GrapheneConnection*)last_connection;

/**
 *  (public) 重连所有已断开的连接，后台回到前台考虑执行。
 */
- (void)reconnect_all;

/*
 *  (public) 切换到自定义连接
 */
- (void)switchTo:(GrapheneConnection*)new_conn;

@end
