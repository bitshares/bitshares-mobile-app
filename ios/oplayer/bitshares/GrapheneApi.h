//
//  GrapheneApi.h
//  UIDemo
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"

@class GrapheneConnection;
@interface GrapheneApi : NSObject

- (id)initWithConnection:(GrapheneConnection*)conn andApi:(NSString*)apiname;
- (void)close;
- (BOOL)isInited;

- (WsPromise*)api_init;
- (WsPromise*)safe_api_init;
- (WsPromise*)exec:(NSString*)method;
- (WsPromise*)exec:(NSString*)method params:(NSArray*)params;
- (WsPromise*)exec:(NSString*)method params:(NSArray*)params auto_reconnect:(BOOL)auto_reconnect;

@end
