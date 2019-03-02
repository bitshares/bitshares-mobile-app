//
//  MKlineIndexBoll.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "MKlineIndexBoll.h"
#import "OrgUtils.h"

@interface MKlineIndexBoll()
{
    NSInteger           _p;
}

@end

@implementation MKlineIndexBoll

- (void)dealloc
{
}

- (id)initWithN:(NSInteger)n p:(NSInteger)p
     data_array:(NSArray*)data_array
   ceil_handler:(NSDecimalNumberHandler*)ceil_handler
         getter:(FunMAValueGetter)getter
{
    self = [super initWithN:n data_array:data_array ceil_handler:ceil_handler getter:getter];
    if (self)
    {
        _p = p;
    }
    return self;
}

/**
 *  计算中轨线boll(n)，即ma(n)。如果当前蜡烛图数量不足 n，则返回 nil，否则返回 n 项的移动平均数。
 */
- (NSDecimalNumber*)calc_boll:(MKlineItemData*)model
{
    return [super calc_ma:model];
}

- (void)fill_ub_and_lb:(MKlineItemData*)model
{
    if (!model.main_index01){
        return;
    }

    //  data = close(n)
    //  ma = data.sum / data.size
    //  md = sqrt(data.map{|v| (v-ma)**2}.sum/data.size)
    //  ub = ma + p*md
    //  lb = ma - p*md
    assert(model.dataIndex >= _n - 1);
    NSDecimalNumber* sum_of_variance = [NSDecimalNumber zero];
    for (NSInteger i = model.dataIndex + 1 - _n; i <= model.dataIndex; ++i) {
        id variance = [[model.main_index01 decimalNumberBySubtracting:_getter([_data_array objectAtIndex:i])] decimalNumberByRaisingToPower:2];
        sum_of_variance = [sum_of_variance decimalNumberByAdding:variance];
    }
    
    //  计算平均方差
    NSDecimalNumber* average_variance = [sum_of_variance decimalNumberByDividingBy:_n_n];

    //  标准差
    double p_standard_deviation = _p * sqrt([average_variance doubleValue]);
    
    //  N倍标准差
    NSDecimalNumber* n_standard_deviation = (NSDecimalNumber*)[NSDecimalNumber numberWithDouble:p_standard_deviation];
    
    //  REMARK：下轨可能为负数
    model.main_index02 = [model.main_index01 decimalNumberByAdding:n_standard_deviation withBehavior:_ceil_handler];
    model.main_index03 = [model.main_index01 decimalNumberBySubtracting:n_standard_deviation withBehavior:_ceil_handler];
}

@end


