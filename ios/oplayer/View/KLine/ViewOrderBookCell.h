//
//  ViewOrderBookCell.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "TradingPair.h"

@interface ViewOrderBookCell : UITableViewCellBase<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, assign) CGFloat cellTotalHeight;

- (id)initWithTradingPair:(TradingPair*)tradingPair;

- (void)onQueryLimitOrderResponsed:(id)limit_order_infos;

@end
