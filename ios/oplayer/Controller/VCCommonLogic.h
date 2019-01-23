//
//  VCCommonLogic.h
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//  复用部分 VC 中的代码片段

#import <Foundation/Foundation.h>
#import "MyPopviewManager.h"
#import "TradingPair.h"

@class VCBase;
@interface VCCommonLogic : NSObject

/**
 *  查询&显示用户委托(限价单)信息
 */
+ (void)viewUserLimitOrders:(VCBase*)this_ account:(NSString*)account_name_or_id tradingPair:(TradingPair*)tradingPair;

/**
 *  查询&显示用户资产信息
 */
+ (void)viewUserAssets:(VCBase*)this_ account:(NSString*)account_name_or_id;

/**
 *  弹框让用户选择要转账的资产类型
 */
+ (void)showPicker:(VCBase*)this_ selectAsset:(NSArray*)assets title:(NSString*)title callback:(void (^)(id selectItem))callback;

/**
 *  弹框让用户选择指定对象
 */
+ (void)showPicker:(VCBase*)this_ object_lists:(NSArray*)object_lists key:(NSString*)key title:(NSString*)title
          callback:(void (^)(id selectItem))callback;

@end
