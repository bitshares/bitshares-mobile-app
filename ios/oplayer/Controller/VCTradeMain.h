//
//  VCTradeMain.h
//  oplayer
//
//  Created by SYALON on 14-1-12.
//
//

#import "VCBase.h"

@class VCTradeHor;
@interface VCTradeMain : VCBase<UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, UIAlertViewDelegate, UITextFieldDelegate>

- (id)initWithOwner:(VCTradeHor*)owner baseInfo:(NSDictionary*)base quoteInfo:(NSDictionary*)quote isbuy:(BOOL)isbuy;

- (void)resignAllFirstResponder;

- (void)onFullAccountDataResponsed:(id)full_account_data;
- (void)onQueryOrderBookResponse:(id)merged_order_book;
- (void)onQueryTickerDataResponse:(id)data;
- (void)onQueryFillOrderHistoryResponsed:(id)data;
- (void)onRefreshLoginStatus;

@end
