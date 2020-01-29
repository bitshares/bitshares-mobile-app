//
//  VCTradeHor.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

@interface VCTradeHor : VCSlideControllerBase

- (id)initWithTradingPair:(TradingPair*)tradingPair selectBuy:(BOOL)selectBuy;

/**
 *  (public) 帐号信息更新，刷新界面。
 */
- (void)onFullAccountInfoResponsed:(NSDictionary*)full_account_info;

@end
