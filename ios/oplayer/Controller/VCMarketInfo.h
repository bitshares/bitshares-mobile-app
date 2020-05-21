//
//  VCMarketInfo.h
//  oplayer
//
//  Created by SYALON on 14-1-12.
//
//

#import "VCBase.h"

@interface VCMarketInfo : VCBase<UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, UIAlertViewDelegate>

- (id)initWithOwner:(VCBase*)owner marketInfo:(NSDictionary*)market_config_info;

/**
 *  (public) 响应：初始化行情所有ticker数据更新完毕。
 */
- (void)marketTickerDataInitDone;

/**
 *  (public) 刷新自选市场
 */
- (void)onRefreshFavoritesMarket;

/**
 *  (public) 刷新UI（ticker数据变更）
 */
- (void)onRefreshTickerData;

@end
