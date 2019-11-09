//
//  BtsppJssdkManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"

@interface BtsppJssdkManager : NSObject

+ (BtsppJssdkManager*)sharedBtsppJssdkManager;

- (id)js_call:(NSString*)method args:(id)args;

@end
