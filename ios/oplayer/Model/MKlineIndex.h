//
//  MKlineIndex.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//	K线图各种指标

#import <Foundation/Foundation.h>

typedef NSDecimalNumber* (^FunKlineIndexGetter)(id model);
typedef void (^FunKlineIndexSetter)(id model, NSDecimalNumber* new_index_value);

@interface MKlineIndex : NSObject

/**
 *  (public) calc MA index
 */
+ (void)calc_ma_index:(NSArray*)data_array
                    n:(NSInteger)n
         ceil_handler:(NSDecimalNumberHandler*)ceil_handler
               getter:(FunKlineIndexGetter)getter
               setter:(FunKlineIndexSetter)setter;

/**
 *  (public) calc EMA index
 */
+ (void)calc_ema_index:(NSArray*)data_array
                     n:(NSInteger)n
          ceil_handler:(NSDecimalNumberHandler*)ceil_handler
                getter:(FunKlineIndexGetter)getter
                setter:(FunKlineIndexSetter)setter;

@end
