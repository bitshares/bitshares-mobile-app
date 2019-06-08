//
//  TradingPair.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <Foundation/Foundation.h>

@interface TradingPair : NSObject

@property (nonatomic, strong) NSString* pair;

@property (nonatomic, strong) NSDictionary* baseAsset;
@property (nonatomic, strong) NSDictionary* quoteAsset;
@property (nonatomic, assign) BOOL baseIsSmart;
@property (nonatomic, assign) BOOL quoteIsSmart;

@property (nonatomic, assign) BOOL isCoreMarket;
@property (nonatomic, strong) NSString* smartAssetId;
@property (nonatomic, strong) NSString* sbaAssetId;

@property (nonatomic, strong) NSString* baseId;
@property (nonatomic, strong) NSString* quoteId;

@property (nonatomic, assign) NSInteger basePrecision;
@property (nonatomic, assign) NSInteger quotePrecision;

@property (nonatomic, assign) double basePrecisionPow;
@property (nonatomic, assign) double quotePrecisionPow;

@property (nonatomic, assign) NSInteger displayPrecision;
@property (nonatomic, assign) NSInteger numPrecision;

- (id)initWithBaseID:(NSString*)baseId quoteId:(NSString*)quoteId;
- (id)initWithBaseSymbol:(NSString*)baseSymbol quoteSymbol:(NSString*)quoteSymbol;
- (id)initWithBaseAsset:(NSDictionary*)baseAsset quoteAsset:(NSDictionary*)quoteAsset;

/**
 *  (public) 刷新智能资产交易对（市场）标记。即：quote是base的背书资产，或者base是quote的背书资产。
 */
- (void)RefreshCoreMarketFlag:(NSDictionary*)sba_hash;

/**
 *  (public) 计算需要显示的喂价信息，不需要显示喂价则返回 nil。
 */
- (NSDecimalNumber*)calcShowFeedInfo:(id)bitasset_data_id_data_array;

/**
 *  (public) 设置显示精度和数量精度信息
 *  display_precision   - 如果该值为 -1，则使用默认值初始化。
 */
- (void)setDisplayPrecision:(NSInteger)display_precision;

/**
 *  (public) 根据限价单信息动态更新显示精度和数量精度字段
 */
- (void)dynamicUpdateDisplayPrecision:(id)limit_data_infos;

@end
