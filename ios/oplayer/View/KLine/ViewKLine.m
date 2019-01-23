
//
//  ViewKLine.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "ViewKLine.h"
#import "MKlineItemData.h"
#import "MKlineIndexMA.h"
#import "WalletManager.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "UIImage+Template.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "DirectionPanGestureRecognizer.h"
#import "Extension.h"

/**
 *  (ROW高度等于屏幕宽度 / 5）
 *  MA MA MA LINE ......                                :0.25 ROW
 *    主  ROW 1
 *    图  ROW 2
 *    区  ROW 3
 *    域  ROW 4
 *  (副图区域总共 0.75ROW 高)
 *  VOLUME MA MA MA MA LINE                             :0.75ROW * 0.25
 *      SECOND MAIN ARRAY                               :0.75ROW * 0.75
 *  时间轴区域 时间轴区域 时间轴区域 时间轴区域 时间轴区域        20高
 */
@interface ViewKLine()
{
    NSDictionary*       _baseAsset;
    NSDictionary*       _quoteAsset;
    NSInteger           _base_precision;
    NSInteger           _quote_precision;
    NSString*           _base_id;
    
    NSMutableArray*     _kdataModelPool;
    NSUInteger          _kdataModelCurrentIndex;
    
    NSMutableArray*     _kdataArrayAll;             //  所有K线数据Model
    NSMutableArray*     _kdataArrayShowing;         //  当前屏幕显示中的数据Model
    NSDecimalNumber*    _currMaxPrice;              //  Y轴价格区间最高价格
    NSDecimalNumber*    _currMinPrice;              //  Y轴价格区间最低价格
    NSDecimalNumber*    _currRowPriceStep;          //  每行价格阶梯
    NSDecimalNumber*    _currMaxVolume;             //  Vol区间当前最大交易量
    
    CAShapeLayer*       _layerBackFrame;
    CAShapeLayer*       _layerCross;
    
    NSMutableArray*     _caTextLayerArray;
    NSMutableArray*     _maLayerArray;              //  MA指标图层列表
    CGSize              _f10NumberSize;             //  测量字体高度
    UIFont*             _font;                      //  K线图各种数据字体
    
    //  手势拖拽
    DirectionPanGestureRecognizer* _recognizer;
    BOOL                    _isMoving;
    CGPoint                 _startTouch;
    NSInteger               _currCandleOffset;
    CGFloat                 _panOffsetX;
    
    //  缩放手势
    UIPinchGestureRecognizer*   _scaleGesture;
    NSInteger               _currCandleWidth;       //  当前蜡烛图宽度（0-9）
    NSInteger               _currCandleTotalWidth;  //  当前缩放蜡烛图总宽度（1-10）
    
    NSInteger               _maxShowNumber;         //  当前屏幕最大显示蜡烛数量（根据蜡烛宽度动态计算）
    
    //  长按手势（十字叉）
    UILongPressGestureRecognizer*   gestureLongPress;
}

@end

@implementation ViewKLine

@synthesize ekdptType;
@synthesize fOneCellHeight;
@synthesize fMainGraphHeight, fSecondGraphHeight;
@synthesize fMainMAHeight, fSecondMAHeight;
@synthesize fSquareHeight;
@synthesize fTimeAxisHeight;

- (void)dealloc
{
    _kdataModelPool = nil;
    _layerBackFrame = nil;
    _layerCross = nil;
}

/**
 *  描绘文字
 */
-(CATextLayer*)getTextLayerWithString:(NSString *)text
                            textColor:(UIColor *)textColor
                                 font:(UIFont*)font
                      backgroundColor:(UIColor *)bgColor
                                frame:(CGRect)frame
{
    CATextLayer* textLayer = [CATextLayer layer];
    //  设置文字frame
    textLayer.frame = frame;
    //  设置文字
    textLayer.string = text;
    textLayer.fontSize = font.pointSize;
    textLayer.font = (__bridge CFTypeRef)font.fontName;
    //  设置文字颜色
    textLayer.foregroundColor = textColor.CGColor;
    //  设置背景颜色
    if (bgColor){
        textLayer.backgroundColor = bgColor.CGColor;
    }
    textLayer.alignmentMode = kCAAlignmentCenter;
    //  设置缩放率
    textLayer.contentsScale = [UIScreen mainScreen].scale;
    return textLayer;
}

/**
 *  描绘蜡烛图和影线
 */
- (CAShapeLayer*)genCandleLayer:(MKlineItemData*)model index:(NSInteger)index candle_width:(CGFloat)candle_width
{
    //  蜡烛宽度（包括中间间隔像素）
    CGFloat spaceW = candle_width * 2 + kBTS_KLINE_SHADOW_WIDTH + kBTS_KLINE_INTERVAL;
    
    //  绘制蜡烛和上下影线（如果candle_width为0了则只描绘影线，不描绘蜡烛。）
    UIBezierPath* path;
    if (candle_width > 0){
        //  生成柱子的rect
        CGFloat fHeight;
        CGFloat yOffset;
        if (model.isRise){
            yOffset = floor(model.fOffsetClose);
            fHeight = fmaxf(ceil(model.fOffsetOpen - model.fOffsetClose), 1);
        }else{
            yOffset = floor(model.fOffsetOpen);
            fHeight = fmaxf(ceil(model.fOffsetClose - model.fOffsetOpen), 1);
        }
        CGRect candleFrame = CGRectMake(index * spaceW, self.fMainMAHeight + yOffset, candle_width * 2 + kBTS_KLINE_SHADOW_WIDTH, fHeight);
        path = [UIBezierPath bezierPathWithRect:candleFrame];
    }else{
        path = [[UIBezierPath alloc] init];
    }
    [path moveToPoint:CGPointMake(index * spaceW+candle_width, self.fMainMAHeight + floor(model.fOffsetHigh))];
    [path addLineToPoint:CGPointMake(index * spaceW+candle_width, self.fMainMAHeight + ceil(model.fOffsetLow))];
    
    CAShapeLayer* layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    
    //  判断涨跌来设置颜色
    if (model.isRise)
    {
        UIColor* color = [ThemeManager sharedThemeManager].buyColor;
        
        layer.strokeColor = color.CGColor;
        layer.fillColor = color.CGColor;
        
    }
    else
    {
        UIColor* color = [ThemeManager sharedThemeManager].sellColor;
        layer.strokeColor = color.CGColor;
        layer.fillColor = color.CGColor;
    }
    
    return layer;
}

/**
 *  绘制成交量柱子
 */
- (CAShapeLayer*)genVolumeLayer:(MKlineItemData*)model index:(NSInteger)index candle_width:(CGFloat)candle_width
{
    CGFloat spaceW = candle_width * 2 + kBTS_KLINE_SHADOW_WIDTH + kBTS_KLINE_INTERVAL;
    
    //  REMARK：从最底部倒着往上绘制，高度设置为负数。
    UIBezierPath* path;
    if (candle_width > 0){
        CGRect candleFrame = CGRectMake(index * spaceW, self.fSquareHeight, candle_width * 2 + kBTS_KLINE_SHADOW_WIDTH, floor(-model.fOffset24Vol));
        path = [UIBezierPath bezierPathWithRect:candleFrame];
    }else{
        path = [[UIBezierPath alloc] init];
        [path moveToPoint:CGPointMake(index * spaceW, self.fSquareHeight)];
        [path addLineToPoint:CGPointMake(index * spaceW, floor(self.fSquareHeight - model.fOffset24Vol))];
    }
    CAShapeLayer* layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    
    //  判断涨跌来设置颜色
    if (model.isRise)
    {
        UIColor* color = [ThemeManager sharedThemeManager].buyColor;
        layer.strokeColor = color.CGColor;
        layer.fillColor = color.CGColor;
    }
    else
    {
        UIColor* color = [ThemeManager sharedThemeManager].sellColor;
        layer.strokeColor = color.CGColor;
        layer.fillColor = color.CGColor;
    }
    
    return layer;
}

/**
 *  (private) 初始化背景边框图层
 */
- (CAShapeLayer*)genBackFrameLayer:(CGRect)frame
{
    //  初始化一个图层
    CAShapeLayer* frameLayer = [CAShapeLayer layer];
    
    CGFloat frameX = 0;
    CGFloat frameY = 0;
    CGFloat frameW = frame.size.width;
    CGFloat frameH = frame.size.height;
    
    //  初始化一个路径
    UIBezierPath *framePath = [UIBezierPath bezierPathWithRect:frame];
    
    CGFloat cellW = frameW / kBTS_KLINE_COL_NUM;
    CGFloat cellH = frameH / kBTS_KLINE_ROW_NUM;
    
    //  绘制竖线（kBTS_KLINE_COL_NUM - 1）条
    for (int i = 0; i < kBTS_KLINE_COL_NUM - 1; ++i) {
        CGPoint startPoint = CGPointMake(frameX + cellW * (i + 1), frameY);
        CGPoint endPoint   = CGPointMake(frameX + cellW * (i + 1), frameY + frameH);
        [framePath moveToPoint:startPoint];
        [framePath addLineToPoint:endPoint];
    }
    
    //  绘制横线（kBTS_KLINE_ROW_NUM - 1）条。由于区域顶部显示MA指标，所以横线需要往下偏移。
    CGFloat fMAOffset = kBTS_KLINE_MA_HEIGHT * cellH;
    for (int i = 0; i < kBTS_KLINE_ROW_NUM - 1; ++i) {
        CGPoint startPoint = CGPointMake(frameX, frameY + cellH * (i + 1) + fMAOffset);
        CGPoint endPoint   = CGPointMake(frameX + frameW, frameY + cellH * (i + 1) + fMAOffset);
        [framePath moveToPoint:startPoint];
        [framePath addLineToPoint:endPoint];
    }
    
    //  设置路径和各种属性
    frameLayer.path = framePath.CGPath;
    frameLayer.lineWidth = 1;
    frameLayer.strokeColor = [ThemeManager sharedThemeManager].bottomLineColor.CGColor;
    frameLayer.fillColor = [UIColor clearColor].CGColor;
    frameLayer.zPosition = -2;
    
    return frameLayer;
}

- (id)initWithWidth:(CGFloat)width baseAsset:(id)baseAsset quoteAsset:(id)quoteAsset
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.hideTopLine = YES;
        self.hideBottomLine = YES;
        
        self.backgroundColor = [UIColor clearColor];
        
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        //  外部参数
        _baseAsset = baseAsset;
        _quoteAsset = quoteAsset;
        _base_precision = [[baseAsset objectForKey:@"precision"] integerValue];
        _quote_precision = [[quoteAsset objectForKey:@"precision"] integerValue];
        _base_id = [[baseAsset objectForKey:@"id"] copy];
        
        CGRect frame = CGRectMake(0, 0, width, width);
        
        //  初始化默认字体
        _font = [UIFont fontWithName:@"Helvetica" size:kBTS_KLINE_PRICE_VOL_FONTSIZE];
        //  REMARK：测量X轴、Y轴、MAX、MIN价格、VOL等字体高度用。
        _f10NumberSize = [self auxSizeWithText:@"0.123456789-:" font:_font maxsize:CGSizeMake(width, 9999)];
        
        //  初始化各种数据
        self.ekdptType = ekdpt_15m; //  默认值
        CGFloat fTotalHeight = frame.size.height;
        self.fOneCellHeight = fTotalHeight / kBTS_KLINE_ROW_NUM;
        self.fMainGraphHeight = self.fOneCellHeight * (kBTS_KLINE_ROW_NUM - 1);
        self.fMainMAHeight = self.fOneCellHeight * kBTS_KLINE_MA_HEIGHT;
        CGFloat fSecondGraphTotal = self.fOneCellHeight - self.fMainMAHeight;
        self.fSecondMAHeight = fSecondGraphTotal * kBTS_KLINE_MA_HEIGHT;
        self.fSecondGraphHeight = fSecondGraphTotal - self.fSecondMAHeight;
        self.fTimeAxisHeight = ceil(_f10NumberSize.height + 8);
        self.fSquareHeight = width;
        
        //  初始化model池
        _kdataModelPool = [NSMutableArray array];
        for (int i = 0; i <= kBTS_KLINE_MAX_SHOW_CANDLE_NUM; ++i) {
            [_kdataModelPool addObject:[[MKlineItemData alloc] init]];
        }
        _kdataModelCurrentIndex = 0;
        
        _kdataArrayShowing = [NSMutableArray array];
        _kdataArrayAll = [NSMutableArray array];
        _currMaxPrice = nil;
        _currMinPrice = nil;
        _currRowPriceStep = nil;
        _currMaxVolume = nil;
        
        _caTextLayerArray = [NSMutableArray array];
        _maLayerArray = [NSMutableArray array];
        
        //  初始化各种layer
        _layerBackFrame = [self genBackFrameLayer:frame];
        [self.layer addSublayer:_layerBackFrame];
        _layerCross = [CAShapeLayer layer];
        
        //  手势
        _recognizer = [[DirectionPanGestureRecognizer alloc] initWithTarget:self action:@selector(paningGestureReceive:)];
        _recognizer.direction = DirectionPanGestureRecognizerHorizontal;
        //        _recognizer.delaysTouchesBegan = NO;        //  不延迟处理（延迟处理会导致各种点击变的奇怪o.o
        _recognizer.cancelsTouchesInView = YES;     //  响应手势后吞掉事件（向其他view送cancel事件取消处理
        [self addGestureRecognizer:_recognizer];
        _recognizer.enabled = YES;                   //  默认不启用（只有vc大于1时才启用返回拖拽功能
        _panOffsetX = 0;
        
        //  缩放手势
        _currCandleTotalWidth = kBTS_KLINE_CANDLE_WIDTH + kBTS_KLINE_SHADOW_WIDTH;
        _currCandleWidth = _currCandleTotalWidth - kBTS_KLINE_SHADOW_WIDTH;
        _scaleGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onScaleGestureTrigger:)];
        [self addGestureRecognizer:_scaleGesture];
        _scaleGesture.enabled = YES;
        
        //  长按手势
        gestureLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressCross:)];
        [self addGestureRecognizer:gestureLongPress];
        gestureLongPress.enabled = YES;
    }
    return self;
}

/**
 *  (private) 计算屏幕宽度一次可以显示的蜡烛数量，蜡烛可缩放。
 *  candle_width - 3、2、1、0（最小宽度为0，则蜡烛和影线一样了、没实体）
 */
- (NSInteger)calcMaxShowCandleNumber:(CGFloat)candle_width
{
    CGFloat fMaxWidth = self.bounds.size.width;
    CGFloat fWidthCandle = candle_width * 2 + kBTS_KLINE_SHADOW_WIDTH;
    CGFloat fRealWidth = fWidthCandle + kBTS_KLINE_INTERVAL;
    
    NSInteger num = (NSInteger)floor(fMaxWidth / fRealWidth);
    
    //  余下的宽度虽然没有 9，但如果宽度有7，显示数量应该+1。最后一根蜡烛不包含间距。
    CGFloat mod = fMaxWidth - num * fRealWidth;
    if (mod >= fWidthCandle){
        num += 1;
    }
    
    return num;
}

- (MKlineItemData*)getOneKdataModel
{
    if (_kdataModelCurrentIndex >= [_kdataModelPool count]){
        [_kdataModelPool addObject:[[MKlineItemData alloc] init]];
    }
    id m = [_kdataModelPool objectAtIndex:_kdataModelCurrentIndex];
    ++_kdataModelCurrentIndex;
    //  TODO:fowallet 是否需要清0重制model之前的数据。
    [m reset];
    return m;
}


/**
 *  (private) 处理所有网络返回的K线数据为model，并计算移动均线数据。
 */
- (void)prepareAllDatas:(NSArray*)data_array
{
    [_kdataArrayAll removeAllObjects];
    //  重制！！！重要。
    _kdataModelCurrentIndex = 0;
    
    //  无数据
    if ([data_array count] <= 0){
        return;
    }
    
    //  保留小数位数 向上取整
    NSDecimalNumberHandler* ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                 scale:_base_precision
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
    
    NSDecimalNumberHandler* percentHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                    scale:4
                                                                                         raiseOnExactness:NO
                                                                                          raiseOnOverflow:NO
                                                                                         raiseOnUnderflow:NO
                                                                                      raiseOnDivideByZero:NO];
    
    //  MA(n)辅助计算类
    MKlineIndexMA* ma5 = [[MKlineIndexMA alloc] initWithN:5
                                               data_array:_kdataArrayAll ceil_handler:ceilHandler getter:(^NSDecimalNumber *(MKlineItemData *model) {
        return model.nPriceClose;
    })];
    MKlineIndexMA* ma10 = [[MKlineIndexMA alloc] initWithN:10
                                                data_array:_kdataArrayAll ceil_handler:ceilHandler getter:(^NSDecimalNumber *(MKlineItemData *model) {
        return model.nPriceClose;
    })];
    MKlineIndexMA* ma30 = [[MKlineIndexMA alloc] initWithN:30
                                                data_array:_kdataArrayAll ceil_handler:ceilHandler getter:(^NSDecimalNumber *(MKlineItemData *model) {
        return model.nPriceClose;
    })];
    //  REMARK：目前仅分时图才显示MA60
    MKlineIndexMA* ma60 = nil;
    if ([self isDrawTimeLine]){
        ma60 = [[MKlineIndexMA alloc] initWithN:60
                                     data_array:_kdataArrayAll ceil_handler:ceilHandler getter:(^NSDecimalNumber *(MKlineItemData *model) {
            return model.nPriceClose;
        })];
    }
    MKlineIndexMA* vol_ma5 = [[MKlineIndexMA alloc] initWithN:5
                                                   data_array:_kdataArrayAll ceil_handler:ceilHandler getter:(^NSDecimalNumber *(MKlineItemData *model) {
        return model.n24Vol;
    })];
    MKlineIndexMA* vol_ma10 = [[MKlineIndexMA alloc] initWithN:10
                                                    data_array:_kdataArrayAll ceil_handler:ceilHandler getter:(^NSDecimalNumber *(MKlineItemData *model) {
        return model.n24Vol;
    })];
    for (id data in data_array) {
        //  创建Model
        MKlineItemData* model = [self getOneKdataModel];
        
        //  解析Model
        model = [MKlineItemData parseData:data
                                   fillto:model
                                  base_id:_base_id
                           base_precision:_base_precision
                          quote_precision:_quote_precision
                              ceilHandler:ceilHandler
                           percentHandler:percentHandler];
        [_kdataArrayAll addObject:model];
        
        //  计算MA（n）
        model.ma5 = [ma5 calc_ma:model];
        model.ma10 = [ma10 calc_ma:model];
        model.ma30 = [ma30 calc_ma:model];
        if (ma60){
            model.ma60 = [ma60 calc_ma:model];
        }
        model.vol_ma5 = [vol_ma5 calc_ma:model];
        model.vol_ma10 = [vol_ma10 calc_ma:model];
    }
}

/**
 *  (private) 准备所有显示用model（每次刷新都需要重新计算最高点、最低点、蜡烛图坐标等数据）
 *  candle_offset   - 右边跳过数据数量
 */
- (void)prepareShowData:(NSInteger)maxShowNum candle_offset:(NSInteger)candle_offset
{
    //  根据屏幕宽度指定的显示数据获取需要显示的数据  REMARK：data_array[最旧....最新]
    [_kdataArrayShowing removeAllObjects];
    NSInteger n_data_array = [_kdataArrayAll count];
    
    //  无数据
    if (n_data_array <= 0){
        return;
    }
    
    NSInteger enumIndexOffset = n_data_array - maxShowNum - candle_offset;
    if (enumIndexOffset < 0){
        enumIndexOffset = 0;
    }
    for (NSInteger enumIndex = enumIndexOffset; enumIndex < n_data_array; ++enumIndex) {
        //  先清除标记，因为如果有滑动过，那么有可能设置过了最大、最小等标记。
        MKlineItemData* m = [_kdataArrayAll objectAtIndex:enumIndex];
        m.isMax24Vol = NO;
        m.isMaxPrice = NO;
        m.isMinPrice = NO;
        [_kdataArrayShowing addObject:m];
        if ([_kdataArrayShowing count] >= maxShowNum){
            break;
        }
    }
    
    //  分时图
    BOOL onlyTimeLine = [self isDrawTimeLine];
    
    //  寻找最大价格、最小价格、最大成交量（REMARK：最大最小价格区域包含MA的价格）
    MKlineItemData* first_data = [_kdataArrayShowing firstObject];
    MKlineItemData* price_max_item = first_data;
    MKlineItemData* price_min_item = first_data;
    MKlineItemData* volume_max_item = first_data;
    
    //  全部数据的最大价格：包括蜡烛、影线和移动均线（整个绘制区域包含均线，所以需要考虑均线价格因素。）
    id max_price = onlyTimeLine ? first_data.nPriceClose : first_data.nPriceHigh;
    id min_price = onlyTimeLine ? first_data.nPriceClose : first_data.nPriceLow;
    
    //  所有蜡烛（包括影线）的最大价格和最小价格
    MKlineItemData* candle_max_price_item = first_data;
    MKlineItemData* candle_min_price_item = first_data;
    id candle_max_price = first_data.nPriceHigh;
    id candle_min_price = first_data.nPriceLow;
    id max_24vol = first_data.n24Vol;
    
    NSDecimalNumber* h;
    NSDecimalNumber* l;
    NSDecimalNumber* c;
    NSDecimalNumber* vol;
    NSDecimalNumber* ma5;
    NSDecimalNumber* ma10;
    NSDecimalNumber* ma30;
    NSDecimalNumber* ma60;
    NSDecimalNumber* vol_ma5;
    NSDecimalNumber* vol_ma10;
    for (MKlineItemData* m in _kdataArrayShowing) {
        if (onlyTimeLine){
            //  统计分时Y轴最高最低价格用
            c = m.nPriceClose;
            ma60 = m.ma60;
        }else{
            //  统计K线Y轴最高最低价格、以及蜡烛图最高最低价格（由于MA存在两者可能不同）
            h = m.nPriceHigh;
            l = m.nPriceLow;
            ma5 = m.ma5;
            ma10 = m.ma10;
            ma30 = m.ma30;
        }
        //  统计副图Y轴最大交易量
        vol = m.n24Vol;
        vol_ma5 = m.vol_ma5;
        vol_ma10 = m.vol_ma10;
        if (onlyTimeLine){
            //  分时
            //  最高价格
            if ([c compare:max_price] == NSOrderedDescending){
                max_price = c;
                price_max_item = m;
            }
            if (ma60 && [ma60 compare:max_price] == NSOrderedDescending){
                max_price = ma60;
                price_max_item = m;
            }
            //  最低价格
            if ([c compare:min_price] == NSOrderedAscending){
                min_price = c;
                price_min_item = m;
            }
            if (ma60 && [ma60 compare:min_price] == NSOrderedAscending){
                min_price = ma60;
                price_min_item = m;
            }
        }else{
            //  K线
            //  h > candle_max_price
            if ([h compare:candle_max_price] == NSOrderedDescending){
                candle_max_price = h;
                candle_max_price_item = m;
            }
            //  h > max_price
            if ([h compare:max_price] == NSOrderedDescending){
                max_price = h;
                price_max_item = m;
            }
            if (ma5 && [ma5 compare:max_price] == NSOrderedDescending){
                max_price = ma5;
                price_max_item = m;
            }
            if (ma10 && [ma10 compare:max_price] == NSOrderedDescending){
                max_price = ma10;
                price_max_item = m;
            }
            if (ma30 && [ma30 compare:max_price] == NSOrderedDescending){
                max_price = ma30;
                price_max_item = m;
            }
            //  l < candle_min_price
            if ([l compare:candle_min_price] == NSOrderedAscending){
                candle_min_price = l;
                candle_min_price_item = m;
            }
            //  l < min_price
            if ([l compare:min_price] == NSOrderedAscending){
                min_price = l;
                price_min_item = m;
            }
            if (ma5 && [ma5 compare:min_price] == NSOrderedAscending){
                min_price = ma5;
                price_min_item = m;
            }
            if (ma10 && [ma10 compare:min_price] == NSOrderedAscending){
                min_price = ma10;
                price_min_item = m;
            }
            if (ma30 && [ma30 compare:min_price] == NSOrderedAscending){
                min_price = ma30;
                price_min_item = m;
            }
        }
        //  vol > max_24vol
        if ([vol compare:max_24vol] == NSOrderedDescending){
            max_24vol = vol;
            volume_max_item = m;
        }
        if (vol_ma5 && [vol_ma5 compare:max_24vol] == NSOrderedDescending){
            max_24vol = vol_ma5;
            volume_max_item = m;
        }
        if (vol_ma10 && [vol_ma10 compare:max_24vol] == NSOrderedDescending){
            max_24vol = vol_ma10;
            volume_max_item = m;
        }
    }
    candle_max_price_item.isMaxPrice = YES;
    candle_min_price_item.isMinPrice = YES;
    volume_max_item.isMax24Vol = YES;
    
    //  REMARK：特殊情况，如果最大最小值为0，那么在屏幕上就只有一个点，不存在区间，那么Y轴价格区间就没法显示，这种情况价格区间上下浮动 10%。
    if ([max_price compare:min_price] == NSOrderedSame){
        //  max_price *= 1.1;
        //  min_price *= 0.9;
        NSDecimalNumberHandler* ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                     scale:_base_precision
                                                                                          raiseOnExactness:NO
                                                                                           raiseOnOverflow:NO
                                                                                          raiseOnUnderflow:NO
                                                                                       raiseOnDivideByZero:NO];
        NSDecimalNumber* n_percent_90 = [NSDecimalNumber decimalNumberWithString:@"0.9"];
        NSDecimalNumber* n_percent_110 = [NSDecimalNumber decimalNumberWithString:@"1.1"];
        max_price = [max_price decimalNumberByMultiplyingBy:n_percent_110 withBehavior:ceilHandler];
        min_price = [min_price decimalNumberByMultiplyingBy:n_percent_90 withBehavior:ceilHandler];
    }
    
    //  记住Y轴价格区间最高、最低价格、并计算差价等。
    _currMaxPrice = max_price;
    _currMinPrice = min_price;
    _currMaxVolume = max_24vol;
    id currDiffPrice = [max_price decimalNumberBySubtracting:min_price];
    double f_diff_price = [currDiffPrice doubleValue];
    assert(kBTS_KLINE_ROW_NUM >= 2);
    id n_rows = [NSDecimalNumber decimalNumberWithMantissa:kBTS_KLINE_ROW_NUM - 1 exponent:0 isNegative:NO];
    _currRowPriceStep = [currDiffPrice decimalNumberByDividingBy:n_rows];
    
    NSLog(@"%@", [NSString stringWithFormat:@"max_price:%@ min_price:%@ diff_price:%@", max_price, min_price, currDiffPrice]);
    
    //  计算开收高低屏幕位置 REMARK：K线可描绘区域底部留出半个行高，用于显示MIN价格，不然MIN价格会超出底线。
    CGFloat fViewMaxHeight = self.fMainGraphHeight - ceil(_f10NumberSize.height / 2.0);
    CGFloat fSecondViewHeight = self.fSecondGraphHeight;
    for (MKlineItemData* m in _kdataArrayShowing) {
        m.fOffsetOpen = [[max_price decimalNumberBySubtracting:m.nPriceOpen] doubleValue] * fViewMaxHeight / f_diff_price;
        m.fOffsetClose = [[max_price decimalNumberBySubtracting:m.nPriceClose] doubleValue] * fViewMaxHeight / f_diff_price;
        m.fOffsetHigh = [[max_price decimalNumberBySubtracting:m.nPriceHigh] doubleValue] * fViewMaxHeight / f_diff_price;
        m.fOffsetLow = [[max_price decimalNumberBySubtracting:m.nPriceLow] doubleValue] * fViewMaxHeight / f_diff_price;
        m.fOffset24Vol = [[m.n24Vol decimalNumberByDividingBy:max_24vol] doubleValue] * fSecondViewHeight;
        if (m.ma5){
            m.fOffsetMA5 = [[max_price decimalNumberBySubtracting:m.ma5] doubleValue] * fViewMaxHeight / f_diff_price;
        }
        if (m.ma10){
            m.fOffsetMA10 = [[max_price decimalNumberBySubtracting:m.ma10] doubleValue] * fViewMaxHeight / f_diff_price;
        }
        if (m.ma30){
            m.fOffsetMA30 = [[max_price decimalNumberBySubtracting:m.ma30] doubleValue] * fViewMaxHeight / f_diff_price;
        }
        if (m.ma60){
            m.fOffsetMA60 = [[max_price decimalNumberBySubtracting:m.ma60] doubleValue] * fViewMaxHeight / f_diff_price;
        }
        if (m.vol_ma5){
            m.fOffsetVolMA5 = [[m.vol_ma5 decimalNumberByDividingBy:max_24vol] doubleValue] * fSecondViewHeight;
        }
        if (m.vol_ma10){
            m.fOffsetVolMA10 = [[m.vol_ma10 decimalNumberByDividingBy:max_24vol] doubleValue] * fSecondViewHeight;
        }
    }
}

/**
 *  (private) 生成单条线
 */
- (CAShapeLayer*)getSingleLineLayerWithPointArray:(NSArray*)pointArr lineColor:(UIColor*)lineColor
{
    UIBezierPath* path = [UIBezierPath bezierPath];
    
    [path moveToPoint:[[pointArr firstObject] CGPointValue]];
    for (int idxY=1; idxY<pointArr.count; idxY++)
    {
        [path addLineToPoint:[pointArr[idxY] CGPointValue]];
    }
    
    //  TODO:fowallet 多条线（比如中间有一天的vol为0的情况，线条不连续？）
    //    UIBezierPath *path = [UIBezierPath bezierPath];
    //
    //    for (int idxX=0; idxX<pointArr.count; idxX++)
    //    {
    //        NSArray *idxXArr = pointArr[idxX];
    //
    //        [path moveToPoint:[[idxXArr firstObject] CGPointValue]];
    //        for (int idxY=1; idxY<idxXArr.count; idxY++)
    //        {
    //            [path addLineToPoint:[idxXArr[idxY] CGPointValue]];
    //        }
    //    }
    //
    CAShapeLayer* layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    layer.lineWidth = 1.f;
    layer.strokeColor = lineColor.CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    
    return layer;
}

- (NSString*)formatDateString:(NSTimeInterval)date_ts
{
    //  REMARK：BTS默认时间是UTC时间，这里按照本地时区格式化。
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:date_ts];
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    switch (self.ekdptType) {
        case ekdpt_timeline:    //  分时
        case ekdpt_1m:          //  1分
            [dateFormat setDateFormat:@"HH:mm"];
            break;
        case ekdpt_5m:          //  5分
        case ekdpt_15m:         //  15分
        case ekdpt_30m:         //  30分
        case ekdpt_1h:          //  1小时
        case ekdpt_4h:          //  4小时
            [dateFormat setDateFormat:@"MM-dd HH:mm"];
            break;
        case ekdpt_1d:          //  日线
        case ekdpt_1w:          //  周线
            [dateFormat setDateFormat:@"yy-MM-dd"];
            break;
        default:
            return @"--";
    }
    return [dateFormat stringFromDate:date];
}

/**
 *  (private) 描绘十字叉
 */
- (void)drawCrossLayer:(MKlineItemData*)model
{
    [self cancelDrawCrossLayer];
    
    //  描绘MA指标
    [self drawAllMaValue:model];
    
    CGFloat spaceW = _currCandleWidth * 2 + kBTS_KLINE_SHADOW_WIDTH + kBTS_KLINE_INTERVAL;
    UIBezierPath* path = [UIBezierPath bezierPath];
    
    //  1、竖线
    [path moveToPoint:CGPointMake(model.showIndex * spaceW + _currCandleWidth, 0)];
    [path addLineToPoint:CGPointMake(model.showIndex * spaceW + _currCandleWidth, self.fSquareHeight)];
    
    //  2、横线
    CGFloat yOffsetHor;
    if (model.isRise){
        yOffsetHor = self.fMainMAHeight + floor(model.fOffsetClose);
    }else{
        yOffsetHor = self.fMainMAHeight + ceil(model.fOffsetClose);
    }
    [path moveToPoint:CGPointMake(0, yOffsetHor)];
    [path addLineToPoint:CGPointMake(self.bounds.size.width, yOffsetHor)];
    
    _layerCross.path = path.CGPath;
    _layerCross.lineWidth = 1.f;
    _layerCross.strokeColor = [ThemeManager sharedThemeManager].textColorMain.CGColor;
    _layerCross.fillColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:_layerCross];
    
    //  3、描绘详情
    CGFloat fDetailX;
    CGFloat fDetailY;
    CGFloat fDetailLineHeight = 18;
    CGFloat fDetailWidth = 130;
    CGFloat fDetailLineNumber = [self isDrawTimeLine] ? 3 : 8;
    CGFloat fDetailHeight = fDetailLineHeight * fDetailLineNumber + 4;
    if (model.showIndex >= _maxShowNumber/2){
        //  十字叉详情：靠左边显示
        fDetailX = 4;
        fDetailY = self.fMainMAHeight;
    }else{
        //  十字叉详情：靠右边显示
        fDetailX = self.bounds.size.width - 4 - fDetailWidth;
        fDetailY = self.fMainMAHeight;
    }
    
    //  3.1、背景框
    UIBezierPath* detailPath = [UIBezierPath bezierPathWithRect:CGRectMake(fDetailX, fDetailY, fDetailWidth, fDetailHeight)];
    CAShapeLayer* detailLayer = [CAShapeLayer layer];
    detailLayer.path = detailPath.CGPath;
    detailLayer.lineWidth = 1;
    detailLayer.strokeColor = [ThemeManager sharedThemeManager].textColorNormal.CGColor;
    detailLayer.fillColor = [ThemeManager sharedThemeManager].appBackColor.CGColor;
    [_layerCross addSublayer:detailLayer];
    
    //  分时图和蜡烛图十字叉详情显示不同数据。
    NSString* date_str = [self formatDateString:model.date];
    
    NSArray* value_ary = nil;
    NSArray* title_ary = nil;
    if ([self isDrawTimeLine]){
        value_ary = @[date_str, model.nPriceClose, model.n24Vol];
        title_ary = @[NSLocalizedString(@"kLabelKLineDate", @"时间"),
                      NSLocalizedString(@"kLabelKLinePrice", @"价格"),
                      NSLocalizedString(@"kLabelKLineVol", @"成交量")];
    }else{
        value_ary = @[date_str,
                      model.nPriceOpen, model.nPriceHigh, model.nPriceLow, model.nPriceClose,
                      model.change, model.change_percent,
                      model.n24Vol];
        title_ary = @[NSLocalizedString(@"kLabelKLineDate", @"时间"),
                      NSLocalizedString(@"kLabelKLineOpen", @"开"),
                      NSLocalizedString(@"kLabelKLineHigh", @"高"),
                      NSLocalizedString(@"kLabelKLineLow", @"低"),
                      NSLocalizedString(@"kLabelKLineClose", @"收"),
                      NSLocalizedString(@"kLabelKLineChange", @"涨跌额"),
                      NSLocalizedString(@"kLabelKLineChangePercent", @"涨跌幅"),
                      NSLocalizedString(@"kLabelKLineVol", @"成交量")];
    }
    //  3.2、详情 Value
    NSInteger lineIndex = 0;
    for (id value in value_ary) {
        UIColor* txtColor;
        NSString* str;
        if (lineIndex == 5 || lineIndex == 6){
            if (model.isRise){
                str = [NSString stringWithFormat:@"+%@", value];
                txtColor = [ThemeManager sharedThemeManager].buyColor;
            }else{
                str = [NSString stringWithFormat:@"%@", value];
                txtColor = [ThemeManager sharedThemeManager].sellColor;
            }
            //  涨跌幅增加百分号显示。
            if (lineIndex == 6){
                str = [NSString stringWithFormat:@"%@%%", str];
            }
        }else{
            str = [NSString stringWithFormat:@"%@", value];
            txtColor = [ThemeManager sharedThemeManager].textColorMain;
        }
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:txtColor
                                                   font:_font backgroundColor:nil
                                                  frame:CGRectMake(fDetailX + 4, fDetailY+fDetailLineHeight * lineIndex + 4, fDetailWidth - 8, fDetailLineHeight)];
        txt.alignmentMode = kCAAlignmentRight;
        [_layerCross addSublayer:txt];
        ++lineIndex;
    }
    
    //  3.3、详情 Title
    lineIndex = 0;
    for (id str in title_ary) {
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:[ThemeManager sharedThemeManager].textColorMain
                                                   font:_font backgroundColor:nil
                                                  frame:CGRectMake(fDetailX + 4, fDetailY+fDetailLineHeight * lineIndex + 4, fDetailWidth - 8, fDetailLineHeight)];
        txt.alignmentMode = kCAAlignmentLeft;
        [_layerCross addSublayer:txt];
        ++lineIndex;
    }
    
    //  4、底部时间
    CGSize date_str_size = [self auxSizeWithText:date_str font:[UIFont systemFontOfSize:kBTS_KLINE_PRICE_VOL_FONTSIZE]
                                         maxsize:CGSizeMake(self.bounds.size.width, 9999)];
    CGFloat bottomRectW = date_str_size.width + 8;
    CGFloat bottomRectX = fmin(fmax(model.showIndex * spaceW + _currCandleWidth - round(bottomRectW / 2.0f), 1), self.bounds.size.width - bottomRectW - 1);
    CGFloat bottomRectY = self.fSquareHeight + 1;
    CGFloat bottomRectH = date_str_size.height + 8;
    UIBezierPath* bottomPath = [UIBezierPath bezierPathWithRect:CGRectMake(bottomRectX, bottomRectY, bottomRectW, bottomRectH)];
    CAShapeLayer* bottomLayer = [CAShapeLayer layer];
    bottomLayer.path = bottomPath.CGPath;
    bottomLayer.lineWidth = 1;
    bottomLayer.strokeColor = [ThemeManager sharedThemeManager].textColorNormal.CGColor;
    bottomLayer.fillColor = [ThemeManager sharedThemeManager].appBackColor.CGColor;
    [_layerCross addSublayer:bottomLayer];
    
    CATextLayer* bottom_date_txt = [self getTextLayerWithString:date_str
                                                      textColor:[ThemeManager sharedThemeManager].textColorMain
                                                           font:_font backgroundColor:nil
                                                          frame:CGRectMake(bottomRectX + 4, bottomRectY + 4,
                                                                           bottomRectW - 8, bottomRectH - 8)];
    bottom_date_txt.alignmentMode = kCAAlignmentCenter;
    [_layerCross addSublayer:bottom_date_txt];
    
    //  5、横轴
    NSString* tailer_str = [NSString stringWithFormat:@"%@", model.nPriceClose];
    CGSize tailer_str_size = [self auxSizeWithText:tailer_str font:[UIFont systemFontOfSize:kBTS_KLINE_PRICE_VOL_FONTSIZE]
                                           maxsize:CGSizeMake(self.bounds.size.width, 9999)];
    CGFloat fHorTailerX;
    CGFloat fHorTailerW = tailer_str_size.width + 8;
    CGFloat fHorTailerH = tailer_str_size.height + 8;
    CGFloat fHorTailerY = yOffsetHor - round(fHorTailerH / 2.0);
    if (model.showIndex >= _maxShowNumber/2){
        //  横轴尾端：靠右显示
        fHorTailerX = self.bounds.size.width - fHorTailerW;
    }else{
        //  横轴尾端：靠左显示
        fHorTailerX = 0;
    }
    UIBezierPath* tailerPath = [UIBezierPath bezierPathWithRect:CGRectMake(fHorTailerX, fHorTailerY, fHorTailerW, fHorTailerH)];
    CAShapeLayer* tailerLayer = [CAShapeLayer layer];
    tailerLayer.path = tailerPath.CGPath;
    tailerLayer.lineWidth = 1;
    tailerLayer.strokeColor = [ThemeManager sharedThemeManager].textColorMain.CGColor;
    tailerLayer.fillColor = [ThemeManager sharedThemeManager].appBackColor.CGColor;
    [_layerCross addSublayer:tailerLayer];
    
    CATextLayer* tailer_txt_layer = [self getTextLayerWithString:tailer_str
                                                       textColor:[ThemeManager sharedThemeManager].textColorMain
                                                            font:_font backgroundColor:nil
                                                           frame:CGRectMake(fHorTailerX + 4, fHorTailerY + 4,
                                                                            fHorTailerW - 8, fHorTailerH - 8)];
    tailer_txt_layer.alignmentMode = kCAAlignmentCenter;
    [_layerCross addSublayer:tailer_txt_layer];
}

- (void)cancelDrawCrossLayer
{
    if (_layerCross){
        for (CALayer* sublayer in [_layerCross.sublayers copy]) {
            [sublayer removeFromSuperlayer];
        }
        if (_layerCross.superlayer){
            [_layerCross removeFromSuperlayer];
        }
        _layerCross.path = nil;
    }
}

/**
 *  描绘一条 MA(n) 指标，返回指标占据的宽度。
 */
- (CGFloat)drawOneMaValue:(NSString*)title ma:(id)ma offset_x:(CGFloat)offset_x offset_y:(CGFloat)offset_y color:(UIColor*)color
{
    id str = [NSString stringWithFormat:@"%@:%@", title, ma];
    CGSize str_size = [self auxSizeWithText:str font:[UIFont systemFontOfSize:kBTS_KLINE_PRICE_VOL_FONTSIZE]
                                    maxsize:CGSizeMake(self.bounds.size.width, 9999)];
    CATextLayer* txt = [self getTextLayerWithString:str
                                          textColor:color
                                               font:_font backgroundColor:nil
                                              frame:CGRectMake(offset_x, offset_y, str_size.width, str_size.height)];
    [self.layer addSublayer:txt];
    txt.alignmentMode = kCAAlignmentLeft;
    [_maLayerArray addObject:txt];
    return str_size.width;
}

/**
 *  在主图顶部和副图顶部描绘 MA(n) 和 VOL。如果参数为 nil，则描绘最新数据的指标。
 */
- (void)drawAllMaValue:(MKlineItemData*)model
{
    [self clearAllMaLayer];
    if (!model){
        //  无数据
        if ([_kdataArrayAll count] <= 0){
            return;
        }
        model = [_kdataArrayAll lastObject];
    }
    assert(model);
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    //  主图区域 分时图和K线分别描绘不同参数。
    CGFloat fMaOffsetX = 4;
    if ([self isDrawTimeLine]){
        if (model.ma60){
            fMaOffsetX += 2 + [self drawOneMaValue:@"MA60" ma:model.ma60 offset_x:fMaOffsetX offset_y:4 color:theme.ma5Color];  //  同MA5颜色
        }
    }else{
        if (model.ma5){
            fMaOffsetX += 2 + [self drawOneMaValue:@"MA5" ma:model.ma5 offset_x:fMaOffsetX offset_y:4 color:theme.ma5Color];
        }
        if (model.ma10){
            fMaOffsetX += 2 + [self drawOneMaValue:@"MA10" ma:model.ma10 offset_x:fMaOffsetX offset_y:4 color:theme.ma10Color];
        }
        if (model.ma30){
            fMaOffsetX += 2 + [self drawOneMaValue:@"MA30" ma:model.ma30 offset_x:fMaOffsetX offset_y:4 color:theme.ma30Color];
        }
    }
    //  副图区域 分时和K线一致。
    fMaOffsetX = 4;
    CGFloat fSecondOffsetY = self.fMainMAHeight + self.fMainGraphHeight;
    fMaOffsetX += [self drawOneMaValue:@"VOL" ma:model.n24Vol offset_x:fMaOffsetX offset_y:fSecondOffsetY color:theme.textColorMain];
    if (model.vol_ma5){
        fMaOffsetX += [self drawOneMaValue:@"MA5" ma:model.vol_ma5 offset_x:fMaOffsetX offset_y:fSecondOffsetY color:theme.ma5Color];
    }
    if (model.vol_ma10){
        fMaOffsetX += [self drawOneMaValue:@"MA10" ma:model.vol_ma10 offset_x:fMaOffsetX offset_y:fSecondOffsetY color:theme.ma10Color];
    }
}

/**
 *  当前是否显示分时图
 */
- (BOOL)isDrawTimeLine
{
    return self.ekdptType == ekdpt_timeline;
}

/**
 *  描绘分时图
 */
- (void)drawTimeLine:(CGFloat)candle_width
{
    CGFloat candleSpaceW = candle_width * 2 + kBTS_KLINE_SHADOW_WIDTH + kBTS_KLINE_INTERVAL;
    NSMutableArray* timeline_points = [NSMutableArray array];
    NSInteger idx = 0;
    for (MKlineItemData* m in _kdataArrayShowing) {
        CGFloat yOffset;
        if (m.isRise){
            yOffset = self.fMainMAHeight + floor(m.fOffsetClose);
        }else{
            yOffset = self.fMainMAHeight + ceil(m.fOffsetClose);
        }
        [timeline_points addObject:@(CGPointMake(idx * candleSpaceW + candle_width, yOffset))];
        ++idx;
    }
    if ([timeline_points count] >= 2){
        //  1、分时图线
        UIBezierPath* path = [UIBezierPath bezierPath];
        [path moveToPoint:[[timeline_points firstObject] CGPointValue]];
        for (int idxY=1; idxY < timeline_points.count; idxY++)
        {
            [path addLineToPoint:[timeline_points[idxY] CGPointValue]];
        }
        CAShapeLayer* layer = [CAShapeLayer layer];
        layer.path = path.CGPath;
        layer.lineWidth = 1.f;
        layer.strokeColor = [ThemeManager sharedThemeManager].textColorHighlight.CGColor;
        layer.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
        
        //  2、背景
        CGFloat red, green, blue, alpha;
        [[ThemeManager sharedThemeManager].textColorHighlight getRed:&red green:&green blue:&blue alpha:&alpha];
        UIColor* fillColor = [UIColor colorWithRed:red green:green blue:blue alpha:0.6f];
        //  2.1、分时下面封闭区域渐变背景mask
        CGPoint firstPoint = [[timeline_points firstObject] CGPointValue];
        CGPoint lastPoint = [[timeline_points lastObject] CGPointValue];
        CGFloat maxOffsetY = self.fMainMAHeight + self.fMainGraphHeight;
        //  连接成封闭图形，才可以填充颜色。（连线顺序顺时针）
        UIBezierPath* maskPath = [path copy];
        [maskPath addLineToPoint:CGPointMake(lastPoint.x, maxOffsetY)];
        [maskPath addLineToPoint:CGPointMake(firstPoint.x, maxOffsetY)];
        [maskPath addLineToPoint:CGPointMake(firstPoint.x, firstPoint.y)];
        [maskPath stroke];
        [maskPath closePath];
        CAShapeLayer* maskLayer = [CAShapeLayer layer];
        maskLayer.path = maskPath.CGPath;
        maskLayer.lineWidth = 1.f;
        maskLayer.strokeColor = fillColor.CGColor;
        maskLayer.fillColor = fillColor.CGColor;     //  REMARK：作为mask这个填充颜色不能是透明色。
        //  2.2、渐变图层
        CAGradientLayer* bgLayer = [CAGradientLayer layer];
        bgLayer.colors = @[(__bridge id)fillColor.CGColor, (__bridge id)[UIColor clearColor].CGColor];
        bgLayer.frame = CGRectMake(0, 0, self.bounds.size.width, self.fMainGraphHeight);
        bgLayer.startPoint = CGPointMake(0.5, 0);
        bgLayer.endPoint = CGPointMake(0.5, 1);
        bgLayer.mask = maskLayer;
        bgLayer.zPosition = -1;
        [self.layer addSublayer:bgLayer];
        [_caTextLayerArray addObject:bgLayer];
    }
}

- (void)drawCore:(NSInteger)maxShowNum candle_width:(CGFloat)candle_width
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  无数据
    if ([_kdataArrayShowing count] <= 0){
        CGSize viewSize = self.bounds.size;
        id str = NSLocalizedString(@"kLabelNODATA", @"无数据");
        id font = [UIFont systemFontOfSize:30];
        CGSize str_size = [self auxSizeWithText:str font:font maxsize:CGSizeMake(viewSize.width, 9999)];
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:theme.textColorGray
                                                   font:font backgroundColor:nil
                                                  frame:CGRectMake(0, (viewSize.height-str_size.height) / 2.0, viewSize.width, str_size.height)];
        txt.alignmentMode = kCAAlignmentCenter;
        [self.layer addSublayer:txt];
        [_caTextLayerArray addObject:txt];
        return;
    }
    
    CGFloat candleSpaceW = candle_width * 2 + kBTS_KLINE_SHADOW_WIDTH + kBTS_KLINE_INTERVAL;
    //  保留小数位数 向上取整
    NSDecimalNumberHandler* ceilHandler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                 scale:_base_precision
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
    //  1、描绘背景右边(Y轴)价格区间
    id currStep = [_currMinPrice copy];
    for (int i = 0; i < kBTS_KLINE_ROW_NUM; ++i) {
        CGFloat txtOffsetY;
        id price;
        if (i == 0){
            price = _currMinPrice;
            txtOffsetY = self.fMainGraphHeight + self.fMainMAHeight - _f10NumberSize.height;
        }else if (i == kBTS_KLINE_ROW_NUM - 1){
            price = _currMaxPrice;
            txtOffsetY = 4;
        }else{
            price = [currStep decimalNumberByAdding:_currRowPriceStep withBehavior:ceilHandler];
            currStep = price;
            txtOffsetY = self.fMainGraphHeight + self.fMainMAHeight - _f10NumberSize.height - self.fOneCellHeight * i;
        }
        id str = [NSString stringWithFormat:@"%@", price];
        
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:theme.textColorNormal
                                                   font:_font backgroundColor:nil
                                                  frame:CGRectMake(0, txtOffsetY, self.bounds.size.width - 4, _f10NumberSize.height)];
        txt.alignmentMode = kCAAlignmentRight;
        [self.layer addSublayer:txt];
        [_caTextLayerArray addObject:txt];
    }
    
    //  2、描绘底部x轴时间
    for (int i = 0; i <= kBTS_KLINE_COL_NUM; ++i) {
        NSInteger dateCandleIndex;
        id align;
        CGFloat txtX;
        CGFloat txtWidth = 100;
        if (i == 0){
            dateCandleIndex = 0;
            align = kCAAlignmentLeft;
            txtX = 2;
        }else if (i == kBTS_KLINE_COL_NUM){
            dateCandleIndex = maxShowNum - 1;
            align = kCAAlignmentRight;
            txtX = self.bounds.size.width - 2 - txtWidth;
        }else{
            dateCandleIndex = round((double)(i * maxShowNum) / kBTS_KLINE_COL_NUM);
            align = kCAAlignmentCenter;
            txtX = i * self.bounds.size.width / kBTS_KLINE_COL_NUM - txtWidth / 2;
        }
        //  有可能时间轴区域对上去没有蜡烛信息（比如刚开盘或者成交量低等交易对）。所以需要用 safe 接口获取数据。
        MKlineItemData* m = [_kdataArrayShowing safeObjectAtIndex:dateCandleIndex];
        if (m){
            id str = [self formatDateString:m.date];
            CATextLayer* txt = [self getTextLayerWithString:str
                                                  textColor:theme.textColorNormal
                                                       font:_font backgroundColor:nil
                                                      frame:CGRectMake(txtX, self.fSquareHeight + 4, txtWidth, _f10NumberSize.height)];
            txt.alignmentMode = align;
            [self.layer addSublayer:txt];
            [_caTextLayerArray addObject:txt];
        }
    }
    
    //  3、描绘主图、副图MA等指标
    [self drawAllMaValue:nil];
    
    //  4、描绘中间主区域蜡烛图影线和成交量
    MKlineItemData* candle_max_price_model = nil;
    MKlineItemData* candle_min_price_model = nil;
    NSInteger idx = 0;
    for (MKlineItemData* m in _kdataArrayShowing) {
        m.showIndex = idx;
        //  非分时图的情况下描绘蜡烛图
        if (![self isDrawTimeLine]){
            id layer_candle = [self genCandleLayer:m index:idx candle_width:candle_width];
            [self.layer addSublayer:layer_candle];
            [_caTextLayerArray addObject:layer_candle];
        }
        //  描绘成交量
        id layer_volume = [self genVolumeLayer:m index:idx candle_width:candle_width];
        [self.layer addSublayer:layer_volume];
        [_caTextLayerArray addObject:layer_volume];
        //  分时图不显示最高、最低价格指标
        if (![self isDrawTimeLine]){
            if (m.isMaxPrice){
                candle_max_price_model = m;
            }
            if (m.isMinPrice){
                candle_min_price_model = m;
            }
        }
        ++idx;
    }
    //  描绘分时图
    if ([self isDrawTimeLine]){
        [self drawTimeLine:candle_width];
    }
    
    //  5、描绘MA均线（覆盖在蜡烛图上面）
    NSMutableArray* ma5_points = [NSMutableArray array];
    NSMutableArray* ma10_points = [NSMutableArray array];
    NSMutableArray* ma30_points = [NSMutableArray array];
    NSMutableArray* ma60_points = [NSMutableArray array];
    NSMutableArray* vol_ma5_points = [NSMutableArray array];
    NSMutableArray* vol_ma10_points = [NSMutableArray array];
    idx = 0;
    for (MKlineItemData* m in _kdataArrayShowing) {
        //  分时和蜡烛图分别描绘不同移动均线
        if ([self isDrawTimeLine]){
            if (m.ma60){
                [ma60_points addObject:@(CGPointMake(idx * candleSpaceW+candle_width, m.fOffsetMA60 + self.fMainMAHeight))];
            }
        }else{
            if (m.ma5){
                [ma5_points addObject:@(CGPointMake(idx * candleSpaceW+candle_width, m.fOffsetMA5 + self.fMainMAHeight))];
            }
            if (m.ma10){
                [ma10_points addObject:@(CGPointMake(idx * candleSpaceW+candle_width, m.fOffsetMA10 + self.fMainMAHeight))];
            }
            if (m.ma30){
                [ma30_points addObject:@(CGPointMake(idx * candleSpaceW+candle_width, m.fOffsetMA30 + self.fMainMAHeight))];
            }
        }
        //  成交量移动均线描绘
        if (m.vol_ma5){
            [vol_ma5_points addObject:@(CGPointMake(idx * candleSpaceW+candle_width, floor(self.fSquareHeight - m.fOffsetVolMA5)))];
        }
        if (m.vol_ma10){
            [vol_ma10_points addObject:@(CGPointMake(idx * candleSpaceW+candle_width, floor(self.fSquareHeight - m.fOffsetVolMA10)))];
        }
        ++idx;
    }
    if ([ma5_points count] >= 2){
        id layer = [self getSingleLineLayerWithPointArray:ma5_points lineColor:theme.ma5Color];
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
    }
    if ([ma10_points count] >= 2){
        id layer = [self getSingleLineLayerWithPointArray:ma10_points lineColor:theme.ma10Color];
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
    }
    if ([ma30_points count] >= 2){
        id layer = [self getSingleLineLayerWithPointArray:ma30_points lineColor:theme.ma30Color];
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
    }
    if ([ma60_points count] >= 2){
        id layer = [self getSingleLineLayerWithPointArray:ma60_points lineColor:theme.ma5Color];        //  同MA5颜色
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
    }
    if ([vol_ma5_points count] >= 2){
        id layer = [self getSingleLineLayerWithPointArray:vol_ma5_points lineColor:theme.ma5Color];
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
    }
    if ([vol_ma10_points count] >= 2){
        id layer = [self getSingleLineLayerWithPointArray:vol_ma10_points lineColor:theme.ma10Color];
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
    }
    //  6、描绘副图最大成交量、主图最大价格、最小价格
    if (_currMaxVolume){
        CATextLayer* txt = [self getTextLayerWithString:[NSString stringWithFormat:@"%@", _currMaxVolume]
                                              textColor:theme.textColorNormal
                                                   font:_font backgroundColor:nil
                                                  frame:CGRectMake(0, self.fMainGraphHeight + self.fMainMAHeight,
                                                                   self.bounds.size.width - 4, self.fSecondMAHeight)];
        txt.alignmentMode = kCAAlignmentRight;
        [self.layer addSublayer:txt];
        [_caTextLayerArray addObject:txt];
    }
    if (candle_max_price_model){
        id str = [NSString stringWithFormat:@"%@", candle_max_price_model.nPriceHigh];
        CGSize str_size = [self auxSizeWithText:str font:[UIFont systemFontOfSize:kBTS_KLINE_PRICE_VOL_FONTSIZE]
                                        maxsize:CGSizeMake(self.bounds.size.width, 9999)];
        
        CGFloat txtOffsetY = self.fMainMAHeight + floor(candle_max_price_model.fOffsetHigh) - str_size.height / 2;
        CGFloat txtOffsetX;
        
        CGFloat lineStartX;
        CGFloat lineEndX;
        CGFloat lineY = self.fMainMAHeight + floor(candle_max_price_model.fOffsetHigh);
        
        if (candle_max_price_model.showIndex >= maxShowNum/2){
            //  最高价格在右边区域：靠左边显示
            lineStartX = candle_max_price_model.showIndex * candleSpaceW + candle_width - kBTS_KLINE_HL_PRICE_SHORT_LINE_LENGTH;
            lineEndX = lineStartX + kBTS_KLINE_HL_PRICE_SHORT_LINE_LENGTH;
            txtOffsetX = lineStartX - 2 - str_size.width;
        }else{
            //  最高价格在右边区域：靠右边显示
            lineStartX = candle_max_price_model.showIndex * candleSpaceW + candle_width;
            lineEndX = lineStartX + kBTS_KLINE_HL_PRICE_SHORT_LINE_LENGTH;
            txtOffsetX = lineEndX + 2;
        }
        
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:theme.textColorMain
                                                   font:_font backgroundColor:nil
                                                  frame:CGRectMake(txtOffsetX, txtOffsetY, str_size.width, str_size.height)];
        [self.layer addSublayer:txt];
        [_caTextLayerArray addObject:txt];
        
        //  短横线-指向最高价格
        UIBezierPath *framePath = [[UIBezierPath alloc] init];
        CGPoint startPoint = CGPointMake(lineStartX, lineY);
        CGPoint endPoint   = CGPointMake(lineEndX, lineY);
        [framePath moveToPoint:startPoint];
        [framePath addLineToPoint:endPoint];
        CAShapeLayer* layer = [CAShapeLayer layer];
        layer.path = framePath.CGPath;
        layer.lineWidth = 1;
        layer.strokeColor = theme.textColorMain.CGColor;
        layer.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
    }
    if (candle_min_price_model){
        id str = [NSString stringWithFormat:@"%@", candle_min_price_model.nPriceLow];
        CGSize str_size = [self auxSizeWithText:str font:[UIFont systemFontOfSize:kBTS_KLINE_PRICE_VOL_FONTSIZE]
                                        maxsize:CGSizeMake(self.bounds.size.width, 9999)];
        
        CGFloat txtOffsetY = self.fMainMAHeight + ceil(candle_min_price_model.fOffsetLow) - ceil(str_size.height / 2.0);
        CGFloat txtOffsetX;
        
        CGFloat lineStartX;
        CGFloat lineEndX;
        CGFloat lineY = self.fMainMAHeight + ceil(candle_min_price_model.fOffsetLow);
        
        if (candle_min_price_model.showIndex >= maxShowNum/2){
            //  最低价格在右边区域：靠左边显示
            lineStartX = candle_min_price_model.showIndex * candleSpaceW + candle_width - kBTS_KLINE_HL_PRICE_SHORT_LINE_LENGTH;
            lineEndX = lineStartX + kBTS_KLINE_HL_PRICE_SHORT_LINE_LENGTH;
            txtOffsetX = lineStartX - 2 - str_size.width;
        }else{
            //  最低价格在右边区域：靠右边显示
            lineStartX = candle_min_price_model.showIndex * candleSpaceW + candle_width;
            lineEndX = lineStartX + kBTS_KLINE_HL_PRICE_SHORT_LINE_LENGTH;
            txtOffsetX = lineEndX + 2;
        }
        
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:theme.textColorMain
                                                   font:_font backgroundColor:nil
                                                  frame:CGRectMake(txtOffsetX, txtOffsetY, str_size.width, str_size.height)];
        [self.layer addSublayer:txt];
        [_caTextLayerArray addObject:txt];
        
        //  短横线-指向最低价格
        UIBezierPath *framePath = [[UIBezierPath alloc] init];
        CGPoint startPoint = CGPointMake(lineStartX, lineY);
        CGPoint endPoint   = CGPointMake(lineEndX, lineY);
        [framePath moveToPoint:startPoint];
        [framePath addLineToPoint:endPoint];
        CAShapeLayer* layer = [CAShapeLayer layer];
        layer.path = framePath.CGPath;
        layer.lineWidth = 1;
        layer.strokeColor = theme.textColorMain.CGColor;
        layer.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:layer];
        [_caTextLayerArray addObject:layer];
    }
}

/**
 *  (public) 服务器返回新数据（刷新）
 */
- (void)refreshCandleLayer:(NSArray*)kdata
{
    //  重置
    _currCandleOffset = 0;
    _panOffsetX = 0;
    //  处理数据
    [self prepareAllDatas:kdata];
    //  刷新（新数据不偏移，显示最新数据。）
    [self refreshCandleLayerCore:_currCandleOffset];
}

- (void)refreshCandleLayerCore:(NSInteger)offset_number
{
    //  1、清理
    [self clearAllLayer];
    //  2、根据当前缩放计算屏幕可显示数量
    _maxShowNumber = [self calcMaxShowCandleNumber:_currCandleWidth];
    //  3、准备显示用数据（所有蜡烛图坐标等各种数据）
    [self prepareShowData:_maxShowNumber candle_offset:offset_number];
    //  4、描绘
    [self drawCore:_maxShowNumber candle_width:_currCandleWidth];
}

/**
 *  (private) 重绘前清理所有图层
 */
- (void)clearAllLayer
{
    if ([_caTextLayerArray count] > 0){
        for (CALayer* layer in _caTextLayerArray) {
            if (layer.superlayer){
                [layer removeFromSuperlayer];
            }
        }
        [_caTextLayerArray removeAllObjects];
    }
    [self clearAllMaLayer];
}

- (void)clearAllMaLayer
{
    if ([_maLayerArray count] > 0){
        for (CALayer* layer in _maLayerArray) {
            if (layer.superlayer){
                [layer removeFromSuperlayer];
            }
        }
        [_maLayerArray removeAllObjects];
    }
}

#pragma mark- gesture
- (void)onLongPressCross:(UILongPressGestureRecognizer*)gesture
{
    //  无数据
    if ([_kdataArrayShowing count] <= 0){
        return;
    }
    
    //  长按or坐标变化
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged)
    {
        //  获取坐标
        CGPoint point = [gesture locationInView:self];
        CGFloat x = fmin(fmax(point.x, 0), self.bounds.size.width);
        
        //  计算选中索引
        CGFloat fWidthCandle = _currCandleWidth * 2 + kBTS_KLINE_SHADOW_WIDTH;
        CGFloat fRealWidth = fWidthCandle + kBTS_KLINE_INTERVAL;
        NSInteger index = fmin(fmax(round(x / fRealWidth), 0), [_kdataArrayShowing count] - 1);
        
        //  描绘
        [self drawCrossLayer:_kdataArrayShowing[index]];
    }
    else
    {
        [self cancelDrawCrossLayer];
        //  REMARK：重新描绘最新的MA指标。
        [self drawAllMaValue:nil];
    }
}

- (void)onScaleGestureTrigger:(UIPinchGestureRecognizer*)gesture
{
    //  无数据
    if ([_kdataArrayShowing count] <= 0){
        return;
    }
    
    CGFloat scale = gesture.scale;
    NSInteger total_width = (NSInteger)fmin(fmax(round(_currCandleTotalWidth * scale), kBTS_KLINE_CANDLE_WIDTH_MIN + kBTS_KLINE_SHADOW_WIDTH),
                                            kBTS_KLINE_CANDLE_WIDTH_MAX + kBTS_KLINE_SHADOW_WIDTH);
    if (total_width != _currCandleTotalWidth){
        _currCandleTotalWidth = total_width;
        _currCandleWidth = _currCandleTotalWidth - kBTS_KLINE_SHADOW_WIDTH;
        NSLog(@"candle scale: total: %@, curr: %@", @(_currCandleTotalWidth), @(_currCandleWidth));
        
        //  TODO:fowallet 缩放后 _currCandleOffset？？如何设置。
        [self refreshCandleLayerCore:_currCandleOffset];
    }
}

- (void)paningGestureReceive:(UIPanGestureRecognizer *)recoginzer
{
    //  无数据
    if ([_kdataArrayShowing count] <= 0){
        return;
    }
    
    //  获取坐标
    CGPoint touchPoint = [recoginzer locationInView:[[UIApplication sharedApplication] keyWindow]];
    
    ///<    开始拖拽
    if (recoginzer.state == UIGestureRecognizerStateBegan) {
        _isMoving = YES;
        _startTouch = touchPoint;
        ///<    拖拽结束（返回or复原）
    }else if (recoginzer.state == UIGestureRecognizerStateEnded){
        _panOffsetX += touchPoint.x - _startTouch.x;
        _panOffsetX = fmax(_panOffsetX, 0);
        CGFloat spaceW = _currCandleWidth * 2 + kBTS_KLINE_SHADOW_WIDTH + kBTS_KLINE_INTERVAL;
        _panOffsetX = fmin(_panOffsetX, fmax([_kdataArrayAll count] * spaceW - self.bounds.size.width, 0));
        NSLog(@"PanOffsetX: %@", @(_panOffsetX));
        _isMoving = NO;
        return;
        ///<    拖拽取消
    }else if (recoginzer.state == UIGestureRecognizerStateCancelled){
        _panOffsetX += touchPoint.x - _startTouch.x;
        _panOffsetX = fmax(_panOffsetX, 0);
        CGFloat spaceW = _currCandleWidth * 2 + kBTS_KLINE_SHADOW_WIDTH + kBTS_KLINE_INTERVAL;
        _panOffsetX = fmin(_panOffsetX, fmax([_kdataArrayAll count] * spaceW - self.bounds.size.width, 0));
        NSLog(@"PanOffsetX: %@", @(_panOffsetX));
        _isMoving = NO;
        return;
    }
    
    ///<    拖拽中
    if (_isMoving) {
        [self moveViewWithX:touchPoint.x - _startTouch.x];
    }
}

- (void)moveViewWithX:(float)x
{
    NSInteger offsetX = (NSInteger)x;
    NSLog(@"pan: %@", @(offsetX));
    
    CGFloat fWidthCandle = _currCandleWidth * 2 + kBTS_KLINE_SHADOW_WIDTH;
    CGFloat fRealWidth = fWidthCandle + kBTS_KLINE_INTERVAL;
    
    NSInteger offset_candle = round(fmax(_panOffsetX+offsetX, 0) / fRealWidth);
    if (offset_candle != _currCandleOffset){
        _currCandleOffset = offset_candle;
        [self refreshCandleLayerCore:_currCandleOffset];
    }
    
    //    _currCandleOffset
    //    x = x > _maxWidth ? _maxWidth : x;
    //    x = x < 0 ? 0 : x;
    //
    //    CGRect frame = self.view.frame;
    //    frame.origin.x = x;
    //    self.view.frame = frame;
    //
    //    float scale = (x * 0.05f / _maxWidth) + 0.95f;
    //    float alpha = 0.4f - (x * 0.4f / _maxWidth);
    //
    //    _lastScreenShotView.transform = CGAffineTransformMakeScale(scale, scale);
    //    _blackMask.alpha = alpha;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

-(void)layoutSubviews
{
    [super layoutSubviews];
}

@end
