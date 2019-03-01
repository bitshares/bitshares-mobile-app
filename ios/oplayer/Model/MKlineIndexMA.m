//
//  MKlineIndexMA.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "MKlineIndexMA.h"
#import "OrgUtils.h"

@interface MKlineIndexMA()
{
    NSDecimalNumber*        _sum;
    NSInteger               _cnt;
}

@end

@implementation MKlineIndexMA

- (void)dealloc
{
}

- (id)initWithN:(NSInteger)n data_array:(NSArray*)data_array ceil_handler:(NSDecimalNumberHandler*)ceil_handler getter:(FunMAValueGetter)getter
{
    self = [super init];
    if (self)
    {
        assert(n >= 2);
        _n = n;
        _n_n = [NSDecimalNumber decimalNumberWithMantissa:n exponent:0 isNegative:NO];
        
        _sum = [NSDecimalNumber zero];
        
        _getter = getter;
        _data_array = data_array;
        _ceil_handler = ceil_handler;
        
        _cnt = 0;
    }
    return self;
}

/**
 *  计算移动平均数MA(n)，如果当前蜡烛图数量不足 n，则返回 nil，否则返回 n 项的移动平均数。
 */
- (NSDecimalNumber*)calc_ma:(MKlineItemData*)model
{
    //  累加
    _sum = [_sum decimalNumberByAdding:_getter(model)];
    //  计数
    ++_cnt;
    if (_cnt >= _n){
        //  多余项数值需要减去。
        if (_cnt >= _n + 1){
            MKlineItemData* m = [_data_array objectAtIndex:_cnt - (_n + 1)];
            _sum = [_sum decimalNumberBySubtracting:_getter(m)];
        }
        //  计算平均数
        return [_sum decimalNumberByDividingBy:_n_n withBehavior:_ceil_handler];
    }else{
        //  没达到 n 项，没有 ma 值。
        return nil;
    }
}

@end


