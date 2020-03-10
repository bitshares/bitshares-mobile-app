//
//  ViewDeepGraph.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//  K线界面中间部分 深度图

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"
#import "TradingPair.h"

//  深度图总共行数
#define kBTS_KLINE_DEEP_GRAPH_ROW_N         6

//  深度图X轴高度
#define kBTS_KLINE_DEEP_GRAPH_AXIS_X_HEIGHT 20

@interface ViewDeepGraph : UITableViewCellBase

@property (nonatomic, weak) TradingPair* tradingPair;
@property (nonatomic, assign) CGFloat fCellTotalHeight;
@property (nonatomic, assign) CGFloat fMainGraphOffset;
@property (nonatomic, assign) CGFloat fMainGraphRowH;
@property (nonatomic, assign) CGFloat fMainGraphHeight;

- (id)initWithWidth:(CGFloat)width tradingPair:(TradingPair*)tradingPair;

- (void)refreshDeepGraph:(NSDictionary*)limit_order_infos;

@end
