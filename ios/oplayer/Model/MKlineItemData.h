//
//  MKlineItemData.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <Foundation/Foundation.h>

@interface MKlineItemData : NSObject

@property (nonatomic, assign) NSInteger dataIndex;
@property (nonatomic, assign) NSInteger showIndex;

@property (nonatomic, assign) BOOL isRise;
@property (nonatomic, assign) BOOL isMaxPrice;
@property (nonatomic, assign) BOOL isMinPrice;
@property (nonatomic, assign) BOOL isMax24Vol;

@property (nonatomic, strong) NSDecimalNumber* nPriceOpen;
@property (nonatomic, strong) NSDecimalNumber* nPriceClose;
@property (nonatomic, strong) NSDecimalNumber* nPriceHigh;
@property (nonatomic, strong) NSDecimalNumber* nPriceLow;
@property (nonatomic, strong) NSDecimalNumber* n24Vol;          //  成交量
@property (nonatomic, strong) NSDecimalNumber* n24TotalAmount;  //  成交额
@property (nonatomic, strong) NSDecimalNumber* nAvgPrice;       //  成交均价

@property (nonatomic, strong) NSDecimalNumber* ma60;            //  分时图需要显示

@property (nonatomic, strong) NSDecimalNumber* main_index01;    //  主图指标01-03（根据设置对应不同指标，比如ma1-ma3，或者ema1-ema3，或者boll、ub、lb等）
@property (nonatomic, strong) NSDecimalNumber* main_index02;
@property (nonatomic, strong) NSDecimalNumber* main_index03;
@property (nonatomic, assign) CGFloat   fOffsetMainIndex01;
@property (nonatomic, assign) CGFloat   fOffsetMainIndex02;
@property (nonatomic, assign) CGFloat   fOffsetMainIndex03;

@property (nonatomic, strong) NSDecimalNumber* adv_index01;     //  高级指标（MACD等）
@property (nonatomic, strong) NSDecimalNumber* adv_index02;
@property (nonatomic, strong) NSDecimalNumber* adv_index03;
@property (nonatomic, assign) CGFloat   fOffsetAdvIndex01;
@property (nonatomic, assign) CGFloat   fOffsetAdvIndex02;
@property (nonatomic, assign) CGFloat   fOffsetAdvIndex03;

@property (nonatomic, strong) NSDecimalNumber* change;          //  涨跌额
@property (nonatomic, strong) NSDecimalNumber* change_percent;  //  涨跌幅

@property (nonatomic, strong) NSDecimalNumber* vol_ma5;
@property (nonatomic, strong) NSDecimalNumber* vol_ma10;

@property (nonatomic, assign) CGFloat   fOffsetOpen;
@property (nonatomic, assign) CGFloat   fOffsetClose;
@property (nonatomic, assign) CGFloat   fOffsetHigh;
@property (nonatomic, assign) CGFloat   fOffsetLow;
@property (nonatomic, assign) CGFloat   fOffset24Vol;

@property (nonatomic, assign) CGFloat   fOffsetMA60;            //  分时图需要显示

@property (nonatomic, assign) CGFloat   fOffsetVolMA5;
@property (nonatomic, assign) CGFloat   fOffsetVolMA10;

@property (nonatomic, assign) NSTimeInterval date;

- (void)reset;

/**
 *  (public) 解析服务器的K线数据，生成对应的Model。
 *
 *  fillto          - 可为nil。
 *  ceilHandler     - 可为nil。
 */
+ (MKlineItemData*)parseData:(id)data
                      fillto:(MKlineItemData*)fillto
                     base_id:(NSString*)base_id
              base_precision:(NSInteger)base_precision
             quote_precision:(NSInteger)quote_precision
                 ceilHandler:(NSDecimalNumberHandler*)ceilHandler
              percentHandler:(NSDecimalNumberHandler*)percentHandler;

@end
