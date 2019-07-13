//
//  MKlineItemData.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "MKlineItemData.h"
#import "OrgUtils.h"

@interface MKlineItemData()
{
}

@end

@implementation MKlineItemData

@synthesize dataIndex;
@synthesize showIndex;
@synthesize isRise, isMaxPrice, isMinPrice, isMax24Vol;
@synthesize nPriceOpen, nPriceClose, nPriceHigh, nPriceLow;
@synthesize n24Vol, n24TotalAmount, nAvgPrice;
@synthesize ma60;
@synthesize main_index01, main_index02, main_index03, fOffsetMainIndex01, fOffsetMainIndex02, fOffsetMainIndex03;
@synthesize adv_index01, adv_index02, adv_index03, fOffsetAdvIndex01, fOffsetAdvIndex02, fOffsetAdvIndex03;
@synthesize vol_ma5, vol_ma10;
@synthesize change, change_percent;
@synthesize fOffsetOpen, fOffsetClose, fOffsetHigh, fOffsetLow;
@synthesize fOffset24Vol;
@synthesize fOffsetMA60;
@synthesize fOffsetVolMA5, fOffsetVolMA10;
@synthesize date;

- (void)dealloc
{
}

- (void)reset
{
    self.dataIndex = 0;
    self.showIndex = 0;
    
    self.isRise = NO;
    self.isMaxPrice = NO;
    self.isMinPrice = NO;
    self.isMax24Vol = NO;
    
    self.nPriceOpen = nil;
    self.nPriceClose = nil;
    self.nPriceHigh = nil;
    self.nPriceLow = nil;
    
    self.n24Vol = nil;
    self.n24TotalAmount = nil;
    self.nAvgPrice = nil;
    
    self.ma60 = nil;
    
    self.main_index01 = nil;
    self.main_index02 = nil;
    self.main_index03 = nil;
    self.fOffsetMainIndex01 = 0;
    self.fOffsetMainIndex02 = 0;
    self.fOffsetMainIndex03 = 0;
    
    self.adv_index01 = nil;
    self.adv_index02 = nil;
    self.adv_index03 = nil;
    self.fOffsetAdvIndex01 = 0;
    self.fOffsetAdvIndex02 = 0;
    self.fOffsetAdvIndex03 = 0;
    
    self.vol_ma5 = nil;
    self.vol_ma10 = nil;
    
    self.change = nil;
    self.change_percent = nil;
    
    self.fOffsetOpen = 0;
    self.fOffsetClose = 0;
    self.fOffsetHigh = 0;
    self.fOffsetLow = 0;
    
    self.fOffset24Vol = 0;
    
    self.fOffsetMA60 = 0;
    
    self.fOffsetVolMA5 = 0;
    self.fOffsetVolMA10 = 0;
    
    self.date = 0;
}

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
              percentHandler:(NSDecimalNumberHandler*)percentHandler
{
    if (!fillto){
        fillto = [[MKlineItemData alloc] init];
    }
    
    //  保留小数位数 向上取整
    if (!ceilHandler){
        ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                             scale:base_precision
                                                                  raiseOnExactness:NO
                                                                   raiseOnOverflow:NO
                                                                  raiseOnUnderflow:NO
                                                               raiseOnDivideByZero:NO];
    }
    
    //  涨跌幅的百分比 handler，有效数位4位。百分比加2位小数点。
    if (!percentHandler){
        percentHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                scale:4
                                                                     raiseOnExactness:NO
                                                                      raiseOnOverflow:NO
                                                                     raiseOnUnderflow:NO
                                                                  raiseOnDivideByZero:NO];
    }

    id open_base = [data objectForKey:@"open_base"];
    id open_quote = [data objectForKey:@"open_quote"];
    
    id high_base = [data objectForKey:@"high_base"];
    id high_quote = [data objectForKey:@"high_quote"];
    
    id low_base = [data objectForKey:@"low_base"];
    id low_quote = [data objectForKey:@"low_quote"];
    
    id close_base = [data objectForKey:@"close_base"];
    id close_quote = [data objectForKey:@"close_quote"];
    
    id key = [data objectForKey:@"key"];
    if ([[key objectForKey:@"base"] isEqualToString:base_id]){
        //  price = base/quote
        id n_open_base = [NSDecimalNumber decimalNumberWithMantissa:[open_base unsignedLongLongValue] exponent:-base_precision isNegative:NO];
        id n_open_quote = [NSDecimalNumber decimalNumberWithMantissa:[open_quote unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
        
        id n_high_base = [NSDecimalNumber decimalNumberWithMantissa:[high_base unsignedLongLongValue] exponent:-base_precision isNegative:NO];
        id n_high_quote = [NSDecimalNumber decimalNumberWithMantissa:[high_quote unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
        
        id n_low_base = [NSDecimalNumber decimalNumberWithMantissa:[low_base unsignedLongLongValue] exponent:-base_precision isNegative:NO];
        id n_low_quote = [NSDecimalNumber decimalNumberWithMantissa:[low_quote unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
        
        id n_close_base = [NSDecimalNumber decimalNumberWithMantissa:[close_base unsignedLongLongValue] exponent:-base_precision isNegative:NO];
        id n_close_quote = [NSDecimalNumber decimalNumberWithMantissa:[close_quote unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
        
        id n_open_price = [n_open_base decimalNumberByDividingBy:n_open_quote withBehavior:ceilHandler];
        id n_high_price = [n_high_base decimalNumberByDividingBy:n_high_quote withBehavior:ceilHandler];
        id n_low_price = [n_low_base decimalNumberByDividingBy:n_low_quote withBehavior:ceilHandler];
        id n_close_price = [n_close_base decimalNumberByDividingBy:n_close_quote withBehavior:ceilHandler];
        
        fillto.n24Vol = [NSDecimalNumber decimalNumberWithMantissa:[[data objectForKey:@"quote_volume"] unsignedLongLongValue]
                                                          exponent:-quote_precision isNegative:NO];
        fillto.n24TotalAmount = [NSDecimalNumber decimalNumberWithMantissa:[[data objectForKey:@"base_volume"] unsignedLongLongValue]
                                                                  exponent:-base_precision isNegative:NO];
        
        //  n_open_price <= n_close_price
        fillto.isRise = [n_open_price compare:n_close_price] != NSOrderedDescending;
        
        //  REMARK：完全一致、高低也相同
        fillto.nPriceOpen = n_open_price;
        fillto.nPriceClose = n_close_price;
        fillto.nPriceHigh = n_high_price;
        fillto.nPriceLow = n_low_price;
    }else{
        //  price = quote/base
        id n_open_base = [NSDecimalNumber decimalNumberWithMantissa:[open_base unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
        id n_open_quote = [NSDecimalNumber decimalNumberWithMantissa:[open_quote unsignedLongLongValue] exponent:-base_precision isNegative:NO];
        
        id n_high_base = [NSDecimalNumber decimalNumberWithMantissa:[high_base unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
        id n_high_quote = [NSDecimalNumber decimalNumberWithMantissa:[high_quote unsignedLongLongValue] exponent:-base_precision isNegative:NO];
        
        id n_low_base = [NSDecimalNumber decimalNumberWithMantissa:[low_base unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
        id n_low_quote = [NSDecimalNumber decimalNumberWithMantissa:[low_quote unsignedLongLongValue] exponent:-base_precision isNegative:NO];
        
        id n_close_base = [NSDecimalNumber decimalNumberWithMantissa:[close_base unsignedLongLongValue] exponent:-quote_precision isNegative:NO];
        id n_close_quote = [NSDecimalNumber decimalNumberWithMantissa:[close_quote unsignedLongLongValue] exponent:-base_precision isNegative:NO];
        
        id n_open_price = [n_open_quote decimalNumberByDividingBy:n_open_base withBehavior:ceilHandler];
        id n_high_price = [n_high_quote decimalNumberByDividingBy:n_high_base withBehavior:ceilHandler];
        id n_low_price = [n_low_quote decimalNumberByDividingBy:n_low_base withBehavior:ceilHandler];
        id n_close_price = [n_close_quote decimalNumberByDividingBy:n_close_base withBehavior:ceilHandler];
        
        fillto.n24Vol = [NSDecimalNumber decimalNumberWithMantissa:[[data objectForKey:@"base_volume"] unsignedLongLongValue]
                                                          exponent:-quote_precision isNegative:NO];
        fillto.n24TotalAmount = [NSDecimalNumber decimalNumberWithMantissa:[[data objectForKey:@"quote_volume"] unsignedLongLongValue]
                                                                  exponent:-base_precision isNegative:NO];
        
        //  n_open_price <= n_close_price
        fillto.isRise = [n_open_price compare:n_close_price] != NSOrderedDescending;
        
        //  REMARK：开收相同、高低反向
        fillto.nPriceOpen = n_open_price;
        fillto.nPriceClose = n_close_price;
        fillto.nPriceHigh = n_low_price;
        fillto.nPriceLow = n_high_price;
    }
    
    //  成交均价
    if ([fillto.n24Vol compare:[NSDecimalNumber zero]] > 0){
        fillto.nAvgPrice = [fillto.n24TotalAmount decimalNumberByDividingBy:fillto.n24Vol withBehavior:ceilHandler];
    }else{
        fillto.nAvgPrice = nil;
    }
    
    //  计算涨跌额和涨跌幅
    fillto.change = [fillto.nPriceClose decimalNumberBySubtracting:fillto.nPriceOpen withBehavior:ceilHandler];
    NSDecimalNumber* rate = [fillto.nPriceClose decimalNumberByDividingBy:fillto.nPriceOpen withBehavior:percentHandler];
    rate = [rate decimalNumberBySubtracting:[NSDecimalNumber one] withBehavior:percentHandler];
    fillto.change_percent = [rate decimalNumberByMultiplyingByPowerOf10:2 withBehavior:percentHandler];
    
    //  解析日期
    fillto.date = [OrgUtils parseBitsharesTimeString:[key objectForKey:@"open"]];
    
    return fillto;
}

@end
