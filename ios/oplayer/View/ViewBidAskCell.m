//
//  ViewBidAskCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewBidAskCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewBidAskCell()
{
    BOOL            _isbuy;
    NSInteger       _row_id;
    double          _max_sum;
    NSDictionary*   _item;
    
    UIView*         _bgDeepBar; //  背景深度条
    
    UILabel*        _lbID;      //  编号
    UILabel*        _lbNum;     //  挂单数量
    UILabel*        _lbPrice;   //  挂单价格
}

@end

@implementation ViewBidAskCell

@synthesize displayPrecision;
@synthesize numPrecision;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _bgDeepBar = nil;
    _lbID = nil;
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
        
        CGFloat red, green, blue, alpha;
        if (_isbuy){
            [[ThemeManager sharedThemeManager].buyColor getRed:&red green:&green blue:&blue alpha:&alpha];
        }else{
            [[ThemeManager sharedThemeManager].sellColor getRed:&red green:&green blue:&blue alpha:&alpha];
        }
        _bgDeepBar = [[UIView alloc] init];
        _bgDeepBar.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:0.1f];   //  REMARK: 透明度
        [self addSubview:_bgDeepBar];
        
        //  TODO:fowallet 这个是等宽字体，数字看着舒服点。。新版ios字体太难看。
        _lbID = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbID.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbID.textAlignment = NSTextAlignmentLeft;
        _lbID.numberOfLines = 1;
        _lbID.backgroundColor = [UIColor clearColor];
        _lbID.font = [UIFont fontWithName:@"Helvetica" size:12.0f];
        [self addSubview:_lbID];
        
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

- (BOOL)isTitleCell
{
    return _row_id == 0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL _titleCell = [self isTitleCell];
    
    CGFloat fWidth = self.bounds.size.width;
    
    //  深度信息
    //  REMARK: _max_sum <= 0，精度问题。
    if (_max_sum <= 0.000001f || !_item || _titleCell){
        _bgDeepBar.hidden = YES;
    }else{
        _bgDeepBar.hidden = NO;
    }
    if (!_bgDeepBar.hidden){
        double sum = [[_item objectForKey:@"sum"] doubleValue];
        //  REMARK：最小值1、最大值fWidth。
        int w = (int)fmax(fmin(sum * fWidth / _max_sum, fWidth), 1.0f);
        //  REMARK：买盘靠右显示、卖盘靠左显示
        if (_isbuy){
            _bgDeepBar.frame = CGRectMake(fWidth - w, 0, w, self.bounds.size.height);
        }else{
            _bgDeepBar.frame = CGRectMake(0, 0, w, self.bounds.size.height);
        }
    }
    
    //  REMARK：第一行为标题栏
    if (_titleCell)
    {
        _lbID.text = _isbuy ? NSLocalizedString(@"kLableBidBuy", @"买") : NSLocalizedString(@"kLableAskSell", @"卖");
        _lbNum.text = NSLocalizedString(@"kLableBidAmount", @"数量");
        _lbPrice.text = NSLocalizedString(@"kLableBidPrice", @"价格");
    }
    else
    {
        if (!_item)
        {
            _lbID.text = [NSString stringWithFormat:@"%@", @(_row_id)];
            _lbNum.text = @"--";
            _lbPrice.text = @"--";
        }
        else
        {
            _lbID.text = [NSString stringWithFormat:@"%@", @(_row_id)];
            _lbNum.text = [OrgUtils formatFloatValue:[[_item objectForKey:@"quote"] doubleValue] precision:self.numPrecision];
            _lbPrice.text = [OrgUtils formatFloatValue:[[_item objectForKey:@"price"] doubleValue] precision:self.displayPrecision];
        }
    }
    //  _item:
    //  base = "4473.9868";
    //  price = "45503.003420668371322";
    //  quote = "0.09832289";
    CGFloat xOffset = self.textLabel.frame.origin.x;
    
    //  设置 frame 位置
    CGFloat spaceID2Num = 26.0f;    //  REMARK：ID编号和挂单数量的间距
    
    if (_isbuy)
    {
        _lbID.frame = CGRectMake(xOffset, 0, fWidth - xOffset * 2, self.bounds.size.height);
        _lbID.textAlignment = NSTextAlignmentLeft;
        
        _lbNum.frame = CGRectMake(xOffset + spaceID2Num, 0, fWidth - xOffset * 2, self.bounds.size.height);
        _lbNum.textAlignment = NSTextAlignmentLeft;
        
        _lbPrice.frame = CGRectMake(xOffset, 0, fWidth - xOffset * 2, self.bounds.size.height);
        _lbPrice.textAlignment = NSTextAlignmentRight;
    }
    else
    {
        _lbID.frame = CGRectMake(xOffset, 0, fWidth - xOffset * 2, self.bounds.size.height);
        _lbID.textAlignment = NSTextAlignmentRight;
        
        _lbNum.frame = CGRectMake(xOffset, 0, fWidth - xOffset * 2 - spaceID2Num, self.bounds.size.height);
        _lbNum.textAlignment = NSTextAlignmentRight;
        
        _lbPrice.frame = CGRectMake(xOffset, 0, fWidth - xOffset * 2, self.bounds.size.height);
        _lbPrice.textAlignment = NSTextAlignmentLeft;
    }
    
    //  设置颜色
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    if (_titleCell){
        _lbID.textColor = theme.textColorGray;
        _lbNum.textColor = theme.textColorGray;
        _lbPrice.textColor = theme.textColorGray;
    }else{
        if ([[_item objectForKey:@"iscall"] boolValue]){
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
    }
}

@end
