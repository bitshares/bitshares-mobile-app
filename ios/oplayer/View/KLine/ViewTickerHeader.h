//
//  ViewTickerHeader.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "MKlineItemData.h"
#import "TradingPair.h"

@interface ViewTickerHeader : UITableViewCellBase

- (id)initWithTradingPair:(TradingPair*)tradingPair;
- (void)refreshFeedPrice:(NSDecimalNumber*)feedPrice;
- (void)refreshInfos:(MKlineItemData*)model feedPrice:(NSDecimalNumber*)feedPrice;
- (void)refreshTickerData;

@end
