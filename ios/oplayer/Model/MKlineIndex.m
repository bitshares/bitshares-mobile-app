//
//  MKlineIndex.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "MKlineIndex.h"

@implementation MKlineIndex

/**
 *  (public) calc MA index
 */
+ (void)calc_ma_index:(NSArray*)data_array
                    n:(NSInteger)n
         ceil_handler:(NSDecimalNumberHandler*)ceil_handler
               getter:(FunKlineIndexGetter)getter
               setter:(FunKlineIndexSetter)setter
{
    assert(data_array);
    assert(ceil_handler);
    assert(getter && setter);
    
    if (n <= 0){
        return;
    }
    
    NSDecimalNumber* n_n = [NSDecimalNumber decimalNumberWithMantissa:n exponent:0 isNegative:NO];
    NSDecimalNumber* sum = [NSDecimalNumber zero];
    NSDecimalNumber* ma = nil;
    
    NSInteger dataIndex = 0;
    
    for (id m in data_array) {
        //  get
        NSDecimalNumber* value = getter(m);
        
        sum = [sum decimalNumberByAdding:value];
        
        if (dataIndex >= n - 1){
            if (dataIndex >= n){
                NSDecimalNumber* last_value = getter([data_array objectAtIndex:dataIndex - n]);
                sum = [sum decimalNumberBySubtracting:last_value];
            }
            ma = [sum decimalNumberByDividingBy:n_n withBehavior:ceil_handler];
        }else{
            ma = nil;
        }
        
        //  set
        setter(m, ma);
        
        //  inc
        ++dataIndex;
    }
}

/**
 *  (public) calc EMA index
 *
 *  EMAtoday = α * (Pricetoday - EMAyesterday) + EMAyesterday
 */
+ (void)calc_ema_index:(NSArray*)data_array
                     n:(NSInteger)n
          ceil_handler:(NSDecimalNumberHandler*)ceil_handler
                getter:(FunKlineIndexGetter)getter
                setter:(FunKlineIndexSetter)setter
{
    assert(data_array);
    assert(ceil_handler);
    assert(getter && setter);
    
    if (n <= 0){
        return;
    }
    
    NSDecimalNumber* n_n = [NSDecimalNumber decimalNumberWithMantissa:n exponent:0 isNegative:NO];
    //  smoothing factor = 2 / (n + 1)
    NSDecimalNumber* alpha = [[NSDecimalNumber decimalNumberWithMantissa:2
                                                                exponent:0
                                                              isNegative:NO] decimalNumberByDividingBy:[n_n decimalNumberByAdding:[NSDecimalNumber one]]];
    
    NSDecimalNumber* sum = [NSDecimalNumber zero];
    NSDecimalNumber* ema_yesterday = nil;
    NSDecimalNumber* ema_today = nil;
    
    NSInteger dataIndex = 0;
    
    for (id m in data_array) {
        //  get
        NSDecimalNumber* value = getter(m);
        if (!value){
            continue;
        }
        
        //  calc
        if (ema_yesterday){
            ema_today = [[[value decimalNumberBySubtracting:ema_yesterday] decimalNumberByMultiplyingBy:alpha] decimalNumberByAdding:ema_yesterday withBehavior:ceil_handler];
        }else{
            sum = [sum decimalNumberByAdding:value];
            if (dataIndex < n - 1){
                ema_today = nil;
            }else{
                //  calc MA as ema
                ema_today = [sum decimalNumberByDividingBy:n_n withBehavior:ceil_handler];
            }
        }
        
        //  set
        setter(m, ema_today);
        ema_yesterday = ema_today;
        
        //  inc
        ++dataIndex;
    }
}

@end


