//
//  MKlineIndexBoll.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//	K线图指标 - 布林线(BOLL)

#import <Foundation/Foundation.h>
#import "MKlineItemData.h"
#import "MKlineIndexMA.h"

typedef NSDecimalNumber* (^FunBollValueGetter)(MKlineItemData* model);

@interface MKlineIndexBoll : MKlineIndexMA

- (id)initWithN:(NSInteger)n p:(NSInteger)p
     data_array:(NSArray*)data_array
   ceil_handler:(NSDecimalNumberHandler*)ceil_handler
         getter:(FunMAValueGetter)getter;

/**
 *  计算中轨线boll(n)，即ma(n)。如果当前蜡烛图数量不足 n，则返回 nil，否则返回 n 项的移动平均数。
 */
- (NSDecimalNumber*)calc_boll:(MKlineItemData*)model;

/**
 *  计算上轨和下轨线
 */
- (void)fill_ub_and_lb:(MKlineItemData*)model;

@end
