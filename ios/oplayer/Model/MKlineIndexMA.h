//
//  MKlineIndexMA.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//	K线图指标 - MA数据

#import <Foundation/Foundation.h>
#import "MKlineItemData.h"

typedef NSDecimalNumber* (^FunMAValueGetter)(MKlineItemData* model);

@interface MKlineIndexMA : NSObject
{
    NSInteger               _n;
    NSDecimalNumber*        _n_n;
    
    FunMAValueGetter        _getter;
    NSArray*                _data_array;
    NSDecimalNumberHandler* _ceil_handler;
}

- (id)initWithN:(NSInteger)n data_array:(NSArray*)data_array ceil_handler:(NSDecimalNumberHandler*)ceil_handler getter:(FunMAValueGetter)getter;

/**
 *  计算移动平均数MA(n)，如果当前蜡烛图数量不足 n，则返回 nil，否则返回 n 项的移动平均数。
 */
- (NSDecimalNumber*)calc_ma:(MKlineItemData*)model;

@end
