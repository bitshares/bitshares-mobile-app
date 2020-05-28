//
//  VCSettlementOrders.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  清算单

#import "VCBase.h"

@interface VCSettlementOrders : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner tradingPair:(TradingPair*)tradingPair fullAccountInfo:(NSDictionary*)fullAccountInfo;

- (void)querySettlementOrders;

@property (nonatomic, strong) TradingPair* tradingPair;

@end
