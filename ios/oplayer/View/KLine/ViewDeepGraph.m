
//
//  ViewDeepGraph.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "ViewDeepGraph.h"
#import "ThemeManager.h"
#import "ViewKLine.h"
#import "OrgUtils.h"

@interface ViewDeepGraph()
{
    TradingPair*            _tradingPair;
    
    CGSize                  _f10NumberSize;             //  测量字体高度
    UIFont*                 _font;                      //  K线图各种数据字体
    
    NSMutableArray*         _allLayers;
    
//    //  手势拖拽
//    DirectionPanGestureRecognizer* _recognizer;
//    BOOL                    _isMoving;
//    CGPoint                 _startTouch;
//    NSInteger               _currCandleOffset;
//    CGFloat                 _panOffsetX;
//
//    //  缩放手势
//    UIPinchGestureRecognizer*   _scaleGesture;
//    NSInteger               _currCandleWidth;       //  当前蜡烛图宽度（0-9）
//    NSInteger               _currCandleTotalWidth;  //  当前缩放蜡烛图总宽度（1-10）
//
//    NSInteger               _maxShowNumber;         //  当前屏幕最大显示蜡烛数量（根据蜡烛宽度动态计算）
//
//    //  长按手势（十字叉）
//    UILongPressGestureRecognizer*   gestureLongPress;
}

@end

@implementation ViewDeepGraph

@synthesize fCellTotalHeight;
@synthesize fMainGraphOffset;
@synthesize fMainGraphRowH;
@synthesize fMainGraphHeight;

- (void)dealloc
{

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

- (void)drawBidAskInfo:(CGFloat)width
{
    NSString* bid_str = NSLocalizedString(@"kLabelDepthSideBuy", @"买盘");
    NSString* ask_str = NSLocalizedString(@"kLabelDepthSideSell", @"卖盘");
    
    CGFloat fHalf = width / 2.0f;
    CGFloat fGridW = 4.0f;
    
    //  买盘
    CGSize str_size = [self auxSizeWithText:bid_str font:_font
                                    maxsize:CGSizeMake(self.bounds.size.width, 9999)];
    CATextLayer* txt = [self getTextLayerWithString:bid_str
                                          textColor:[ThemeManager sharedThemeManager].textColorNormal
                                               font:_font backgroundColor:nil
                                              frame:CGRectMake(0, 0, fHalf - 8, str_size.height)];
    txt.alignmentMode = kCAAlignmentRight;
    [self.layer addSublayer:txt];
    
    UIBezierPath* path = [UIBezierPath bezierPathWithRect:CGRectMake(fHalf - 8 - str_size.width - 8, (str_size.height - fGridW) / 2 + 1, fGridW, fGridW)];
    CAShapeLayer* layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    UIColor* color = [ThemeManager sharedThemeManager].buyColor;
    layer.strokeColor = color.CGColor;
    layer.fillColor = color.CGColor;
    [self.layer addSublayer:layer];
    
    //  卖盘
    CGSize str_size1 = [self auxSizeWithText:ask_str font:_font
                                    maxsize:CGSizeMake(self.bounds.size.width, 9999)];
    CATextLayer* txt1 = [self getTextLayerWithString:ask_str
                                          textColor:[ThemeManager sharedThemeManager].textColorNormal
                                               font:_font backgroundColor:nil
                                              frame:CGRectMake(fHalf + 8 + 8, 0, fHalf - 16, str_size1.height)];
    txt1.alignmentMode = kCAAlignmentLeft;
    [self.layer addSublayer:txt1];
    
    UIBezierPath* path1 = [UIBezierPath bezierPathWithRect:CGRectMake(fHalf + 8, (str_size1.height - fGridW) / 2 + 1, fGridW, fGridW)];
    CAShapeLayer* layer1 = [CAShapeLayer layer];
    layer1.path = path1.CGPath;
    UIColor* color1 = [ThemeManager sharedThemeManager].sellColor;
    layer1.strokeColor = color1.CGColor;
    layer1.fillColor = color1.CGColor;
    [self.layer addSublayer:layer1];
}

/**
 *  (private) 描绘深度图边框和背景
 */
- (void)drawDeepGraph:(NSArray*)points color:(UIColor*)color firstClose:(BOOL)firstClose
{
    //  1、描绘边框
    UIBezierPath* path = [UIBezierPath bezierPath];
    
    //  起始点封闭
    if (firstClose){
        CGPoint firstPoint = [[points firstObject] CGPointValue];
        [path moveToPoint:CGPointMake(firstPoint.x, self.fMainGraphOffset + self.fMainGraphHeight)];
        [path addLineToPoint:firstPoint];
    }else{
        [path moveToPoint:[[points firstObject] CGPointValue]];
    }
    for (int idxY=1; idxY < points.count; idxY++)
    {
        [path addLineToPoint:[points[idxY] CGPointValue]];
    }
    
    //  结尾点封闭
    if (!firstClose){
        CGPoint lastPoint = [[points lastObject] CGPointValue];
        [path addLineToPoint:CGPointMake(lastPoint.x, self.fMainGraphOffset + self.fMainGraphHeight)];
    }
    
    CAShapeLayer* layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    layer.lineWidth = 2.f;
    layer.strokeColor = color.CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:layer];
    [_allLayers addObject:layer];
    
    //  2、填充封闭区域背景
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    UIColor* fillColor = [UIColor colorWithRed:red green:green blue:blue alpha:0.1f];
    CGPoint firstPoint = [[points firstObject] CGPointValue];
    CGPoint lastPoint = [[points lastObject] CGPointValue];
    CGFloat maxOffsetY = self.fMainGraphOffset + self.fMainGraphHeight;
    //  连接成封闭图形，才可以填充颜色。（连线顺序顺时针）
    UIBezierPath* fillPath = [path copy];
    [fillPath addLineToPoint:CGPointMake(lastPoint.x, maxOffsetY)];
    [fillPath addLineToPoint:CGPointMake(firstPoint.x, maxOffsetY)];
    [fillPath addLineToPoint:CGPointMake(firstPoint.x, firstPoint.y)];
//    [fillPath stroke];
    [fillPath closePath];
    CAShapeLayer* fillLayer = [CAShapeLayer layer];
    fillLayer.path = fillPath.CGPath;
    fillLayer.lineWidth = 0.f;
    fillLayer.strokeColor = fillColor.CGColor;
    fillLayer.fillColor = fillColor.CGColor;     //  REMARK：这个填充颜色不能是透明色。
    [self.layer addSublayer:fillLayer];
    [_allLayers addObject:fillLayer];
}

- (void)drawCore:(NSArray*)bid_array ask_array:(NSArray*)ask_array
{
    double bid_max_sum = 0;
    double ask_max_sum = 0;
    double bid_min_sum = 0;
    double ask_min_sum = 0;
    NSInteger bid_num = [bid_array count];
    NSInteger ask_num = [ask_array count];
    NSInteger total_num = bid_num + ask_num;
    
    //  数据不足
    if (bid_num <= 2 || ask_num <= 2){
        CGSize viewSize = self.bounds.size;
        id str = NSLocalizedString(@"kLabelNODATA", @"无数据");
        id font = [UIFont systemFontOfSize:30];
        CGSize str_size = [self auxSizeWithText:str font:font maxsize:CGSizeMake(viewSize.width, 9999)];
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:[ThemeManager sharedThemeManager].textColorGray
                                                   font:font backgroundColor:nil
                                                  frame:CGRectMake(0, (viewSize.height-str_size.height) / 2.0, viewSize.width, str_size.height)];
        txt.alignmentMode = kCAAlignmentCenter;
        [self.layer addSublayer:txt];
        [_allLayers addObject:txt];
        return;
    }
    
    //    {
    //        base = 17442;
    //        price = "0.8721012601863211";
    //        quote = "19999.9711";
    //        sum = "88659.12796999999";
    //    }
    double bid_min_price = 0;
    double bid_max_price = 0;
    if (bid_num > 0){
        bid_max_sum = [[[bid_array lastObject] objectForKey:@"sum"] doubleValue];
        bid_min_sum = [[[bid_array firstObject] objectForKey:@"sum"] doubleValue];
        bid_min_price = [[[bid_array lastObject] objectForKey:@"price"] doubleValue];
        bid_max_price = [[[bid_array firstObject] objectForKey:@"price"] doubleValue];
    }
    double ask_min_price = 0;
    double ask_max_price = 0;
    if (ask_num > 0){
        ask_max_sum = [[[ask_array lastObject] objectForKey:@"sum"] doubleValue];
        ask_min_sum = [[[ask_array firstObject] objectForKey:@"sum"] doubleValue];
        ask_min_price = [[[ask_array firstObject] objectForKey:@"price"] doubleValue];
        ask_max_price = [[[ask_array lastObject] objectForKey:@"price"] doubleValue];
    }
    double max_sum = fmax(bid_max_sum, ask_max_sum);
    double min_sum = fmin(bid_min_sum, ask_min_sum);
    double min_price = fmin(bid_min_price, ask_min_price);
    double max_price = fmax(bid_max_price, ask_max_price);
    
    CGFloat fWidth = self.bounds.size.width;
    
    NSMutableArray* buy_points = [NSMutableArray array];
    NSMutableArray* sell_points = [NSMutableArray array];
    
    //  买单
    for (NSInteger i = bid_num - 1; i >= 0; --i) {
        id order = [bid_array objectAtIndex:i];
        double x = fWidth * [buy_points count] / total_num;
        double y = self.fMainGraphOffset + self.fMainGraphHeight * (1.0f - [[order objectForKey:@"sum"] doubleValue] / max_sum);
        [buy_points addObject:@(CGPointMake(x, y))];
    }
    
    //  卖单
    for (id order in ask_array) {
        double x = fWidth * ([buy_points count] + [sell_points count]) / total_num;
        double y = self.fMainGraphOffset + self.fMainGraphHeight * (1.0f - [[order objectForKey:@"sum"] doubleValue] / max_sum);
        [sell_points addObject:@(CGPointMake(x, y))];
    }
    
    //  描绘Y轴（数量区间）
    double diff_sum = (max_sum - min_sum) / (kBTS_KLINE_DEEP_GRAPH_ROW_N - 1);
    for (int i = 1; i < kBTS_KLINE_DEEP_GRAPH_ROW_N; ++i) {
        double value = min_sum + diff_sum * i;
        CGFloat offsetY = self.fMainGraphOffset + self.fMainGraphHeight - self.fMainGraphRowH * i;
        
        id str = [OrgUtils formatFloatValue:value precision:_tradingPair.numPrecision];
        
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:[ThemeManager sharedThemeManager].textColorNormal
                                                   font:_font backgroundColor:nil
                                                  frame:CGRectMake(0, offsetY - _f10NumberSize.height, self.bounds.size.width - 4, _f10NumberSize.height)];
        txt.alignmentMode = kCAAlignmentRight;
        [self.layer addSublayer:txt];
        [_allLayers addObject:txt];
    }
    
    //  描绘X轴（价格区间）
    double diff_price = (max_price - min_price) / 2;
    for (int i = 0; i < 3; ++i) {
        double value = min_price + diff_price * i;
        
        id str = [OrgUtils formatFloatValue:value precision:_tradingPair.displayPrecision];
        
        CATextLayer* txt = [self getTextLayerWithString:str
                                              textColor:[ThemeManager sharedThemeManager].textColorNormal
                                                   font:_font backgroundColor:nil
                                                  frame:CGRectMake(4, self.fMainGraphOffset + self.fMainGraphHeight + 4, self.bounds.size.width - 8, _f10NumberSize.height)];
        if (i == 0){
            txt.alignmentMode = kCAAlignmentLeft;
        }else if (i == 1){
            txt.alignmentMode = kCAAlignmentCenter;
        }else{
            txt.alignmentMode = kCAAlignmentRight;
        }
        [self.layer addSublayer:txt];
        [_allLayers addObject:txt];
    }
    
    //  描绘图形
    [self drawDeepGraph:buy_points color:[ThemeManager sharedThemeManager].buyColor firstClose:NO];
    [self drawDeepGraph:sell_points color:[ThemeManager sharedThemeManager].sellColor firstClose:YES];
}

- (id)initWithWidth:(CGFloat)width tradingPair:(TradingPair*)tradingPair
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
        _tradingPair = tradingPair;
        
        CGFloat height = ceil(width / 2.0f);
        self.fMainGraphRowH = height / kBTS_KLINE_DEEP_GRAPH_ROW_N;
        self.fMainGraphHeight = (kBTS_KLINE_DEEP_GRAPH_ROW_N - 1) * self.fMainGraphRowH;
        self.fMainGraphOffset = height - self.fMainGraphHeight;
        self.fCellTotalHeight = height + kBTS_KLINE_DEEP_GRAPH_AXIS_X_HEIGHT;
        
        _allLayers = [NSMutableArray array];
        
        //  初始化默认字体
        _font = [UIFont fontWithName:@"Helvetica" size:kBTS_KLINE_PRICE_VOL_FONTSIZE];
        //  REMARK：测量X轴、Y轴、MAX、MIN价格、VOL等字体高度用。
        _f10NumberSize = [self auxSizeWithText:@"0.123456789-:" font:_font maxsize:CGSizeMake(width, 9999)];

        [self drawBidAskInfo:width];
        
        //        [_maLayerArray addObject:txt];
        
//        //  手势
//        _recognizer = [[DirectionPanGestureRecognizer alloc] initWithTarget:self action:@selector(paningGestureReceive:)];
//        _recognizer.direction = DirectionPanGestureRecognizerHorizontal;
//        //        _recognizer.delaysTouchesBegan = NO;        //  不延迟处理（延迟处理会导致各种点击变的奇怪o.o
//        _recognizer.cancelsTouchesInView = YES;     //  响应手势后吞掉事件（向其他view送cancel事件取消处理
//        [self addGestureRecognizer:_recognizer];
//        _recognizer.enabled = YES;                   //  默认不启用（只有vc大于1时才启用返回拖拽功能
//        _panOffsetX = 0;
//
//        //  缩放手势
//        _currCandleTotalWidth = kBTS_KLINE_CANDLE_WIDTH + kBTS_KLINE_SHADOW_WIDTH;
//        _currCandleWidth = _currCandleTotalWidth - kBTS_KLINE_SHADOW_WIDTH;
//        _scaleGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onScaleGestureTrigger:)];
//        [self addGestureRecognizer:_scaleGesture];
//        _scaleGesture.enabled = YES;
//
//        //  长按手势
//        gestureLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressCross:)];
//        [self addGestureRecognizer:gestureLongPress];
//        gestureLongPress.enabled = YES;
    }
    return self;
}

- (void)refreshDeepGraph:(NSDictionary*)limit_order_infos
{
    //  test data
//    NSError* err = nil;
//    NSData* data = [NSJSONSerialization dataWithJSONObject:limit_order_infos
//                                                   options:NSJSONReadingAllowFragments
//                                                     error:&err];
//    id testjson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    assert(limit_order_infos);
    id bid_array = [limit_order_infos objectForKey:@"bids"];
    id ask_array = [limit_order_infos objectForKey:@"asks"];
    assert(bid_array);
    assert(ask_array);
    [self clearAllLayer];
    [self drawCore:bid_array ask_array:ask_array];
}

/**
 *  (private) 重绘前清理所有图层
 */
- (void)clearAllLayer
{
    if ([_allLayers count] > 0){
        for (CALayer* layer in _allLayers) {
            if (layer.superlayer){
                [layer removeFromSuperlayer];
            }
        }
        [_allLayers removeAllObjects];
    }
}

#pragma mark- gesture
- (void)onLongPressCross:(UILongPressGestureRecognizer*)gesture
{
//    //  无数据
//    if ([_kdataArrayShowing count] <= 0){
//        return;
//    }
//
//    //  长按or坐标变化
//    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged)
//    {
//        //  获取坐标
//        CGPoint point = [gesture locationInView:self];
//        CGFloat x = fmin(fmax(point.x, 0), self.bounds.size.width);
//
//        //  计算选中索引
//        CGFloat fWidthCandle = _currCandleWidth * 2 + kBTS_KLINE_SHADOW_WIDTH;
//        CGFloat fRealWidth = fWidthCandle + kBTS_KLINE_INTERVAL;
//        NSInteger index = fmin(fmax(round(x / fRealWidth), 0), [_kdataArrayShowing count] - 1);
//
//        //  描绘
//        [self drawCrossLayer:_kdataArrayShowing[index]];
//    }
//    else
//    {
//        [self cancelDrawCrossLayer];
//        //  REMARK：重新描绘最新的MA指标。
//        [self drawAllMaValue:nil];
//    }
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
