//
//  VCLaunch.h
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCBase.h"

@interface VCLaunch : VCBase

/*
 *  (public) 检测APP更新数据。
 */
+ (WsPromise*)checkAppUpdate;

@end
