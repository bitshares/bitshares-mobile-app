//
//  GrapheneWebSocket.h
//  UIDemo
//
//  Created by SYALON on 13-9-3.
//
//

#import <Foundation/Foundation.h>
#import <SocketRocket/SocketRocket.h>
#import "WsPromise.h"

typedef void (^WsCallback)(NSString* err, id data);
typedef BOOL (^WsNotifyCallback)(BOOL success, id data);

typedef void (^KeepAliveCallback)(BOOL closed);

@interface GrapheneWebSocket : NSObject<SRWebSocketDelegate>

- (id)initWithServer:(NSString*)url connect_timeout:(NSInteger)connect_timeout keepaliveCb:(KeepAliveCallback)keepaliveCb;

- (WsPromise*)login:(NSString*)username password:(NSString*)password;
- (WsPromise*)call:(NSArray*)params;
- (void)close;
- (BOOL)isClosed;

@end
