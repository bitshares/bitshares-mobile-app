//
//  VCTradeVertical.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

@interface VCTradeVertical : VCSlideControllerBase

- (id)initWithTradingPair:(TradingPair*)tradingPair selectBuy:(BOOL)selectBuy;

@end

@interface VCTradeVerticalBuyOrSell : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCTradeVertical*)owner tradingPair:(TradingPair*)tradingPair isbuy:(BOOL)isbuy;

/*
 *  事件 - 数据响应 - 用户账号数据返回
 */
- (void)onFullAccountDataResponsed:(id)full_account_data;

/*
 *  事件 - 数据响应 - 盘口
 */
- (void)onQueryOrderBookResponse:(id)merged_order_book;

/*
 *  事件 - 数据响应 - Ticker数据
 */
- (void)onQueryTickerDataResponse:(id)data;

/*
 *  事件 - 数据响应 - 历史成交记录
 */
- (void)onQueryFillOrderHistoryResponsed:(id)data_array;

/*
 *  事件 - 处理登录成功事件
 *  更改 登录按钮为 买卖按钮
 *  获取 个人信息
 */
- (void)onRefreshLoginStatus;

/*
 *  事件 - UI取消关闭键盘
 */
- (void)endInput;

@end
