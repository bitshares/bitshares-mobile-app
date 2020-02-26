//
//  ViewBidAskCellVer.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewBidAskCellVer.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewBidAskCellVer()
{
    BOOL            _isbuy;
    NSInteger       _row_id;
    double          _max_sum;
    NSDictionary*   _item;
    
    UIView*         _bgDeepBar;     //  背景深度条
    
    UILabel*        _lbID;          //  编号
    UIView*         _myOrderDot;    //  我的挂单（小圆圈）
    UILabel*        _lbNum;         //  挂单数量
    UILabel*        _lbPrice;       //  挂单价格
}

@end

@implementation ViewBidAskCellVer

@synthesize displayPrecision;
@synthesize numPrecision;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _userLimitOrderHash = nil;
    _bgDeepBar = nil;
    _lbID = nil;
    _myOrderDot = nil;
    _lbNum = nil;
    _lbPrice = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier isbuy:(BOOL)isbuy
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _isbuy = isbuy;
        _row_id = 0;
        _item = nil;
        _max_sum = 0;
        //  仅设置个默认值防止出错，启动会从配置文件加载信息动态计算的。
        self.displayPrecision = 8;
        self.numPrecision = 4;
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        CGFloat red, green, blue, alpha;
        if (_isbuy){
            [theme.buyColor getRed:&red green:&green blue:&blue alpha:&alpha];
        }else{
            [theme.sellColor getRed:&red green:&green blue:&blue alpha:&alpha];
        }
        _bgDeepBar = [[UIView alloc] init];
        _bgDeepBar.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:0.15f];   //  REMARK: 透明度
        [self addSubview:_bgDeepBar];
        
        //  TODO:fowallet 这个是等宽字体，数字看着舒服点。。新版ios字体太难看。
        _lbID = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbID.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbID.textAlignment = NSTextAlignmentLeft;
        _lbID.numberOfLines = 1;
        _lbID.backgroundColor = [UIColor clearColor];
        _lbID.font = [UIFont fontWithName:@"Helvetica" size:12.0f];
        [self addSubview:_lbID];
        
        _myOrderDot = [[UIView alloc] init];
        [self addSubview:_myOrderDot];
        
        _lbNum = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbNum.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbNum.textAlignment = NSTextAlignmentLeft;
        _lbNum.numberOfLines = 1;
        _lbNum.backgroundColor = [UIColor clearColor];
        _lbNum.font = [UIFont fontWithName:@"Helvetica" size:12.0f];
        [self addSubview:_lbNum];
        
        _lbPrice = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbPrice.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbPrice.textAlignment = NSTextAlignmentLeft;
        _lbPrice.numberOfLines = 1;
        _lbPrice.backgroundColor = [UIColor clearColor];
        _lbPrice.font = [UIFont fontWithName:@"Helvetica" size:12.0f];
        [self addSubview:_lbPrice];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

-(void)setItem:(NSDictionary*)item
{
    if (_item != item)
    {
        _item = item;
        [self setNeedsDisplay];
        //  REMARK fix ios7 detailTextLabel not show
        if ([NativeAppDelegate systemVersion] < 9)
        {
            [self layoutSubviews];
        }
    }
}

- (void)setRowID:(NSInteger)_id maxSum:(double)maxSum
{
    _row_id = _id;
    _max_sum = maxSum;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat fWidth = self.bounds.size.width;
    CGFloat fHeight = self.bounds.size.height;
    CGFloat fOffsetX = self.layoutMargins.left;
    
    
    //  TODO:5.0 去掉 id，背景不用累计的，显示当个订单的。
    
    //  深度信息
    //  REMARK: _max_sum <= 0，精度问题。
    if (_max_sum <= 0.000001f || !_item){
        _bgDeepBar.hidden = YES;
    }else{
        _bgDeepBar.hidden = NO;
    }
    if (!_bgDeepBar.hidden){
        double sum = [[_item objectForKey:@"quote"] doubleValue];
        //  REMARK：最小值1、最大值fWidth。
        int w = (int)fmax(fmin(sum * fWidth / _max_sum, fWidth), 1.0f);
        //  REMARK：买盘靠右显示、卖盘靠左显示
        _bgDeepBar.frame = CGRectMake(fWidth - w, 0, w, fHeight);
    }
    
    NSInteger lineId = _row_id + 1;
    if (!_item)
    {
        _lbID.text = [NSString stringWithFormat:@"%@", @(lineId)];
        _lbNum.text = @"--";
        _lbPrice.text = @"--";
    }
    else
    {
        _lbID.text = [NSString stringWithFormat:@"%@", @(lineId)];
        _lbNum.text = [OrgUtils formatOrderBookValue:[[_item objectForKey:@"quote"] doubleValue]
                                           precision:self.numPrecision usesGroupingSeparator:NO];
        _lbPrice.text = [OrgUtils formatOrderBookValue:[[_item objectForKey:@"price"] doubleValue]
                                             precision:self.displayPrecision usesGroupingSeparator:NO];
    }
    
    //  设置 frame 位置
    CGFloat spaceID2Num = 26.0f;    //  REMARK：ID编号和价格的间距
    
    //  竖版界面
    _lbID.frame = CGRectMake(fOffsetX, 0, fWidth - fOffsetX * 2, fHeight);
    _lbID.textAlignment = NSTextAlignmentLeft;
    
    _lbPrice.frame = CGRectMake(fOffsetX + spaceID2Num, 0, fWidth - fOffsetX * 2, fHeight);
    _lbPrice.textAlignment = NSTextAlignmentLeft;
    
    _lbNum.frame = CGRectMake(fOffsetX, 0, fWidth - fOffsetX * 2, fHeight);
    _lbNum.textAlignment = NSTextAlignmentRight;
    
    //  设置颜色
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    BOOL bIsCall = [[_item objectForKey:@"iscall"] boolValue];
    if (bIsCall){
        _lbID.textColor = theme.callOrderColor;
        _lbNum.textColor = theme.callOrderColor;
        _lbPrice.textColor = theme.callOrderColor;
    }else{
        _lbID.textColor = theme.textColorNormal;
        _lbNum.textColor = theme.textColorNormal;
        if (_isbuy){
            _lbPrice.textColor = theme.buyColor;
        }else{
            _lbPrice.textColor = theme.sellColor;
        }
    }
    
    //  UI - 小圆点 无数据 or 爆仓单 or 不在我的委托hash中 都不显示。
    if (!_item || bIsCall || !_userLimitOrderHash || ![_userLimitOrderHash objectForKey:[_item objectForKey:@"oid"]]) {
        _myOrderDot.hidden = YES;
    } else {
        _myOrderDot.hidden = NO;
        CGFloat fDotWidth = 6.0f;
        _myOrderDot.layer.cornerRadius = fDotWidth / 2.0f;
        _myOrderDot.frame = CGRectMake((fOffsetX - fDotWidth) / 2.0f, (fHeight - fDotWidth) / 2.0f, fDotWidth, fDotWidth);
        if (_isbuy){
            _myOrderDot.layer.backgroundColor = theme.buyColor.CGColor;
        }else{
            _myOrderDot.layer.backgroundColor = theme.sellColor.CGColor;
        }
    }
}

@end
