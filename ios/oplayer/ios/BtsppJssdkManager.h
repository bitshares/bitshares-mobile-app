//
//  BtsppJssdkManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"

@class VCBase;

@interface BtsppJssdkManager : NSObject

+ (BtsppJssdkManager*)sharedBtsppJssdkManager;

- (BtsppJssdkManager*)binding_vc:(VCBase*)vc;
- (id)js_call:(NSString*)method args:(id)args;

@end
