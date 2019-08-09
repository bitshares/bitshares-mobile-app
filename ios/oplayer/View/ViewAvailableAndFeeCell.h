//
//  ViewAvailableAndFeeCell.h
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "TradingPair.h"

@interface ViewAvailableAndFeeCell : UITableViewCellBase

- (void)draw_available:(NSString*)value enough:(BOOL)enough isbuy:(BOOL)isbuy tradingPair:(TradingPair*)tradingPair;
- (void)draw_market_fee:(NSDictionary*)asset account:(NSDictionary*)account;

@end
