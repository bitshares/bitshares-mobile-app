//
//  ViewKLine.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

typedef enum EKLineMainIndexType
{
    ekmit_show_ma = 0,      //  显示MA指标
    ekmit_show_ema,         //  显示EMA指标
    ekmit_show_boll,        //  显示BOLL指标
    ekmit_show_none,        //  不显示
    
    ekmit_max
} EKLineMainIndexType;

typedef enum EKLineSubIndexType
{
    eksit_show_none = 0,    //  高级指标：不显示
    eksit_show_macd,        //  高级指标：MACD
    
    eksit_max
} EKLineSubIndexType;

typedef enum EKlineDatePeriodType
{
    ekdpt_timeline = 1,     //  分时图
    ekdpt_1m = 10,          //  1分
    ekdpt_5m = 20,          //  5分
    ekdpt_15m = 30,         //  15分
    ekdpt_30m = 40,         //  30分
    ekdpt_1h = 50,          //  1小时
    ekdpt_4h = 60,          //  4小时
    ekdpt_1d = 70,          //  日线
    ekdpt_1w = 80,          //  周线
} EKlineDatePeriodType;

//  K线周期菜单末尾 指标按钮
#define kBTS_KLINE_INDEX_BUTTON_VALUE   1000

//  K线周期菜单末尾 更多按钮
#define kBTS_KLINE_MORE_BUTTON_VALUE    1010

//  K线图中价格区间、日期区间、最低最高价格、成交量、MA信息等小主要文字字号
#define kBTS_KLINE_PRICE_VOL_FONTSIZE   10

//  K线背景边框行列数
#define kBTS_KLINE_COL_NUM              4
#define kBTS_KLINE_ROW_NUM              5

//  K线MA等指标区域高度（相对于ROW的比例，比如行高80，则MA高度20。）
#define kBTS_KLINE_MA_HEIGHT            0.25

//  K线蜡烛图实体默认宽度、最小宽度、最大宽度（影响缩放）
#define kBTS_KLINE_CANDLE_WIDTH         3
#define kBTS_KLINE_CANDLE_WIDTH_MIN     0
#define kBTS_KLINE_CANDLE_WIDTH_MAX     9

//  K线蜡烛图影线宽度
#define kBTS_KLINE_SHADOW_WIDTH         1

//  K线蜡烛图之间的间隔宽度
#define kBTS_KLINE_INTERVAL             2

//  K线最多显示的蜡烛图数量（一直往回滑动）    TODO:fowallet huobi是300，bts一次最多返回200，300需要多次请求。
#define kBTS_KLINE_MAX_SHOW_CANDLE_NUM  200

//  K线中指向最低价格、最高价格的短横线长度
#define kBTS_KLINE_HL_PRICE_SHORT_LINE_LENGTH   12

@interface ViewKLine : UITableViewCellBase

@property (nonatomic, assign) EKlineDatePeriodType ekdptType;   //  K线周期类型
@property (nonatomic, assign) CGFloat fOneCellHeight;           //  主图（K线）区域一个CELL格高度
@property (nonatomic, assign) CGFloat fMainGraphHeight;         //  主图（K线）区域总高度     该高度不包含 fMainMAHeight
@property (nonatomic, assign) CGFloat fSecondGraphHeight;       //  副图（量）区域总高度      该高度不包含 fSecondMAHeight
@property (nonatomic, assign) CGFloat fMainMAHeight;            //  主图（K线）MA区域总高度
@property (nonatomic, assign) CGFloat fSecondMAHeight;          //  副图（量）MA区域总高度
@property (nonatomic, assign) CGFloat fSquareHeight;            //  整个正方形区域高度
@property (nonatomic, assign) CGFloat fTimeAxisHeight;          //  最底部（X轴、时间轴总高度）

- (id)initWithWidth:(CGFloat)width baseAsset:(id)baseAsset quoteAsset:(id)quoteAsset;

- (void)refreshCandleLayer:(NSArray*)kdata;

- (void)refreshUI;

@end
