//
//  VCUserOrders.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  订单管理

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"
#import "TradingPair.h"

@interface VCUserOrdersPages : VCSlideControllerBase

- (id)initWithUserFullInfo:(NSDictionary*)userFullInfo tradeHistory:(NSArray*)tradeHistory tradingPair:(TradingPair*)tradingPair;

@end

@interface VCUserOrders : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner data:(id)data history:(BOOL)history tradingPair:(TradingPair*)tradingPair filter:(BOOL)filterWithTradingPair;

@end
