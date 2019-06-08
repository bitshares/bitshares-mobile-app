//
//  TradingPair.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "TradingPair.h"
#import "ChainObjectManager.h"

@interface TradingPair()
{
    NSString*       _pair;
    
    NSDictionary*   _baseAsset;
    NSDictionary*   _quoteAsset;
    BOOL            _baseIsSmart;
    BOOL            _quoteIsSmart;
    
    BOOL            _isCoreMarket;              //  是否是智能资产市场（该标记需要后期更新）
    NSString*       _smartAssetId;              //  智能资产ID
    NSString*       _sbaAssetId;                //  背书资产ID
    
    NSString*       _baseId;
    NSString*       _quoteId;
    
    NSInteger       _basePrecision;
    NSInteger       _quotePrecision;
    
    double          _basePrecisionPow;
    double          _quotePrecisionPow;
    
    BOOL            _displayPrecisionDynamic;   //  动态参数是否动态计算完毕（每次进入交易界面计算一次，之后每次更新盘口数据不在重新计算。）
    NSInteger       _displayPrecision;          //  价格显示精度：资产买盘、卖盘显示精度、出价精度。默认值 -1，需要初始化。
    NSInteger       _numPrecision;              //  数量显示精度：num_price_total_max_precision - _displayPrecision
}

@end

@implementation TradingPair

@synthesize pair = _pair;
@synthesize baseAsset = _baseAsset;
@synthesize quoteAsset = _quoteAsset;
@synthesize baseIsSmart = _baseIsSmart;
@synthesize quoteIsSmart = _quoteIsSmart;
@synthesize isCoreMarket = _isCoreMarket;
@synthesize smartAssetId = _smartAssetId;
@synthesize sbaAssetId = _sbaAssetId;
@synthesize baseId = _baseId;
@synthesize quoteId = _quoteId;
@synthesize basePrecision = _basePrecision;
@synthesize quotePrecision = _quotePrecision;
@synthesize basePrecisionPow = _basePrecisionPow;
@synthesize quotePrecisionPow = _quotePrecisionPow;

@synthesize displayPrecision = _displayPrecision;
@synthesize numPrecision = _numPrecision;

- (void)dealloc
{
    self.baseAsset = nil;
    self.quoteAsset = nil;
    self.baseId = nil;
    self.quoteId = nil;
    
    self.smartAssetId = nil;
    self.sbaAssetId = nil;
}

- (id)initWithBaseID:(NSString*)baseId quoteId:(NSString*)quoteId
{
    assert(baseId);
    assert(quoteId);
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id base = [chainMgr getChainObjectByID:baseId];
    id quote = [chainMgr getChainObjectByID:quoteId];
    return [self initWithBaseAsset:base quoteAsset:quote];
}

- (id)initWithBaseSymbol:(NSString*)baseSymbol quoteSymbol:(NSString*)quoteSymbol
{
    assert(baseSymbol);
    assert(quoteSymbol);
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id base = [chainMgr getAssetBySymbol:baseSymbol];
    id quote = [chainMgr getAssetBySymbol:quoteSymbol];
    return [self initWithBaseAsset:base quoteAsset:quote];
}

- (id)initWithBaseAsset:(NSDictionary*)baseAsset quoteAsset:(NSDictionary*)quoteAsset
{
    assert(baseAsset);
    assert(quoteAsset);
    self = [super init];
    if (self)
    {
        _pair = [NSString stringWithFormat:@"%@_%@", baseAsset[@"symbol"], quoteAsset[@"symbol"]];
        
        _baseAsset = baseAsset;
        _quoteAsset = quoteAsset;
        _baseIsSmart = [self _is_smart:_baseAsset];
        _quoteIsSmart = [self _is_smart:_quoteAsset];
        
        _isCoreMarket = NO;
        _smartAssetId = nil;
        _sbaAssetId = nil;
        
        _baseId = [baseAsset objectForKey:@"id"];
        _quoteId = [quoteAsset objectForKey:@"id"];
        _basePrecision = [[_baseAsset objectForKey:@"precision"] integerValue];
        _quotePrecision = [[_quoteAsset objectForKey:@"precision"] integerValue];
        _basePrecisionPow = pow(10, _basePrecision);
        _quotePrecisionPow = pow(10, _quotePrecision);
        
        //  初始化默认值
        _displayPrecisionDynamic = NO;
        [self setDisplayPrecision:-1];
    }
    return self;
}

/**
 *  (private) 是否是智能货币判断
 */
- (BOOL)_is_smart:(NSDictionary*)asset
{
    assert(asset);
    id bitasset_data_id = [asset objectForKey:@"bitasset_data_id"];
    return bitasset_data_id && ![bitasset_data_id isEqualToString:@""];
}

/**
 *  (public) 刷新智能资产交易对（市场）标记。即：quote是base的背书资产，或者base是quote的背书资产。
 */
- (void)RefreshCoreMarketFlag:(NSDictionary*)sba_hash
{
    assert(sba_hash);
    
    _isCoreMarket = NO;
    _smartAssetId = nil;
    _sbaAssetId = nil;
    
    id base_sba = [sba_hash objectForKey:_baseId];
    if (base_sba && [base_sba isEqualToString:_quoteId]){
        _isCoreMarket = YES;
        _smartAssetId = _baseId;
        _sbaAssetId = _quoteId;
        return;
    }
    
    id quote_sba = [sba_hash objectForKey:_quoteId];
    if (quote_sba && [quote_sba isEqualToString:_baseId]){
        _isCoreMarket = YES;
        _smartAssetId = _quoteId;
        _sbaAssetId = _baseId;
        return;
    }
}

/**
 *  (public) 计算需要显示的喂价信息，不需要显示喂价则返回 nil。
 *
 *  REMARK：返回的结果如果需要显示则需要用 NSString stringWithFormat: 进行格式化。
 */
- (NSDecimalNumber*)calcShowFeedInfo:(id)bitasset_data_id_data_array
{
    //  1、不需要显示喂价（都不是智能资产）
    if (!bitasset_data_id_data_array ||
        [bitasset_data_id_data_array isKindOfClass:[NSNull class]] ||
        [bitasset_data_id_data_array count] <= 0){
        return nil;
    }
    
    NSDictionary* current_feed = nil;
    if ([bitasset_data_id_data_array count] >= 2){
        assert([bitasset_data_id_data_array count] == 2);
        //  2、两种资产都是智能资产
        id first = bitasset_data_id_data_array[0];
        id last = bitasset_data_id_data_array[1];
        id first_sba = [first objectForKey:@"options"][@"short_backing_asset"];
        id last_sba = [last objectForKey:@"options"][@"short_backing_asset"];
        id first_id = [first objectForKey:@"asset_id"];
        id last_id = [last objectForKey:@"asset_id"];
        
        if ([first_sba isEqualToString:last_id]){
            //  last 给 first 背书，显示 first 资产的喂价。
            current_feed = [first objectForKey:@"current_feed"];
        }else if ([last_sba isEqualToString:first_id]){
            //  first 给 last 背书，显示 last 资产的喂价。
            current_feed = [last objectForKey:@"current_feed"];
        }else{
            //  例：USD 和 KITTY.CNY - 都是智能资产，但不互相背书
            return nil;
        }
    }else{
        //  3、base 或 quote 是智能资产
        id first = bitasset_data_id_data_array[0];
        id first_sba = [first objectForKey:@"options"][@"short_backing_asset"];
        id first_id = [first objectForKey:@"asset_id"];
        
        //  base 背书 或者 quote 背书。
        if (([first_id isEqualToString:_baseId] && [first_sba isEqualToString:_quoteId]) ||
            ([first_id isEqualToString:_quoteId] && [first_sba isEqualToString:_baseId])){
            current_feed = [first objectForKey:@"current_feed"];
        }else{
            return nil;
        }
    }
    
    //  根据喂价数据计算喂价
    assert(current_feed);
    id settlement_price = [current_feed objectForKey:@"settlement_price"];
    id asset01 = [settlement_price objectForKey:@"base"];
    id asset02 = [settlement_price objectForKey:@"quote"];
    unsigned long long amount01_amount = [asset01[@"amount"] unsignedLongLongValue];
    unsigned long long amount02_amount = [asset02[@"amount"] unsignedLongLongValue];
    
    //  喂价数据（过期or未设置）
    if (amount01_amount == 0 || amount02_amount == 0){
        return nil;
    }
    
    //  REMARK：喂价往下取（因为如果往上，那么抵押的时候评估抵押物价值可能略微偏高，在175贴现抵押的时候可能出现误差。）
    NSDecimalNumberHandler* downHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown
                                                                                                 scale:_basePrecision
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
    NSDecimalNumber* n_base;
    NSDecimalNumber* n_quote;
    
    //  price = base / quote
    if ([[asset01 objectForKey:@"asset_id"] isEqualToString:_quoteId]){
        n_base = [NSDecimalNumber decimalNumberWithMantissa:amount02_amount exponent:-_basePrecision isNegative:NO];
        n_quote = [NSDecimalNumber decimalNumberWithMantissa:amount01_amount exponent:-_quotePrecision isNegative:NO];
    }else{
        n_base = [NSDecimalNumber decimalNumberWithMantissa:amount01_amount exponent:-_basePrecision isNegative:NO];
        n_quote = [NSDecimalNumber decimalNumberWithMantissa:amount02_amount exponent:-_quotePrecision isNegative:NO];
    }
    
    return [n_base decimalNumberByDividingBy:n_quote withBehavior:downHandler];
}

/**
 *  (public) 设置显示精度和数量精度信息
 *  display_precision   - 如果该值为 -1，则使用默认值初始化。
 */
- (void)setDisplayPrecision:(NSInteger)display_precision
{
    //  如果 display_precision 为负数，则从配置参数获取默认值。
    id parameters = [[ChainObjectManager sharedChainObjectManager] getDefaultParameters];
    if (display_precision < 0){
        display_precision = [[parameters objectForKey:@"display_precision"] integerValue];
    }
    
    //  更新价格精度
    _displayPrecision = display_precision;
    
    //  更新数量精度（最小0，最大不能超过quote资产本身的precision精度信息。）
    id max_precision = parameters[@"num_price_total_max_precision"];
    int n = (int)[max_precision integerValue] - (int)_displayPrecision;
    n = (int)fmin(fmax(n, 0), (int)_quotePrecision);
    
    _numPrecision = n;
}

/**
 *  (public) 根据限价单信息动态更新显示精度和数量精度字段
 */
- (void)dynamicUpdateDisplayPrecision:(id)limit_data_infos
{
    if (!_displayPrecisionDynamic){
        _displayPrecisionDynamic = YES;
        
        //  获取参考出价信息
        id bids_array = [limit_data_infos objectForKey:@"bids"];
        id asks_array = [limit_data_infos objectForKey:@"asks"];
        id ref_item = nil;
        if (bids_array && [bids_array count] > 0){
            ref_item = [bids_array firstObject];
        } else if (asks_array && [asks_array count] > 0){
            ref_item = [asks_array firstObject];
        }else{
            //  没有深度信息，不用计算了，直接返回。
            return;
        }
        //  计算有效精度
        //{
        //    base = "1233.8661";
        //    price = "1.100001101078906";
        //    quote = "1121.695331749937";
        //    sum = "1121.695331749937";
        //}
        NSInteger display_min_fraction = [[[[ChainObjectManager sharedChainObjectManager] getDefaultParameters] objectForKey:@"display_min_fraction"] integerValue];
        //  REMARK：这里用 %f 格式化代理 %@，否则对于部分小数会格式化出 1e-06 等不可期的数据。
        NSString* price = [NSString stringWithFormat:@"%f", [[ref_item objectForKey:@"price"] doubleValue]];
        NSRange range = [price rangeOfString:@"."];
        if (range.location != NSNotFound){
            id ary = [price componentsSeparatedByString:@"."];
            NSString* part1 = ary[0];       //  整数部分
            if ([part1 intValue] > 0){
                _displayPrecision = (NSInteger)fmax((int)_displayPrecision - (int)[part1 length], display_min_fraction);
            }else{
                NSString* part2 = ary[1];   //  小数部分
                NSString* temp;
                NSInteger precision = 0;
                for (NSUInteger i = 0; i < part2.length; ++i) {
                    temp = [part2 substringWithRange:NSMakeRange(i, 1)];
                    //  非0
                    if (![temp isEqualToString:@"0"]){
                        _displayPrecision = precision + _displayPrecision;
                        break;
                    }else{
                        precision += 1;
                    }
                }
                //  如果 part04 全位0，则 _displayPrecision 不会赋值，则为默认值。
            }
        }else{
            //  没有小数点，则默认取2位小数点即可。
            _displayPrecision = display_min_fraction;
        }
        //  更新 num 显示精度
        [self setDisplayPrecision:_displayPrecision];
        NSLog(@"%@ - displayPrecision: %@", price, @(_displayPrecision));
    }
}

@end
