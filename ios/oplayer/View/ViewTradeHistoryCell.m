//
//  ViewTradeHistoryCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewTradeHistoryCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewTradeHistoryCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbDate;    //  日期
    UILabel*        _lbType;    //  买/卖
    UILabel*        _lbPrice;   //  价格
    UILabel*        _lbNum;     //  数量
}

@end

@implementation ViewTradeHistoryCell

@synthesize displayPrecision;
@synthesize numPrecision;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbDate = nil;
    _lbType = nil;
    _lbPrice = nil;
    _lbNum = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];

        //  仅设置个默认值防止出错，启动会从配置文件加载信息动态计算的。
        self.displayPrecision = 8;
        self.numPrecision = 4;
        
        //  TODO:fowallet font name
        _lbDate = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbDate.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbDate.textAlignment = NSTextAlignmentLeft;
        _lbDate.numberOfLines = 1;
        _lbDate.backgroundColor = [UIColor clearColor];
        _lbDate.font = [UIFont fontWithName:@"Helvetica" size:13.0f];
        [self addSubview:_lbDate];

        _lbType = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbType.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbType.textAlignment = NSTextAlignmentLeft;
        _lbType.numberOfLines = 1;
        _lbType.backgroundColor = [UIColor clearColor];
        _lbType.font = [UIFont fontWithName:@"Helvetica" size:13.0f];
        [self addSubview:_lbType];
        
        _lbPrice = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbPrice.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbPrice.textAlignment = NSTextAlignmentRight;
        _lbPrice.numberOfLines = 1;
        _lbPrice.backgroundColor = [UIColor clearColor];
        _lbPrice.font = [UIFont fontWithName:@"Helvetica" size:13.0f];  //  REMARK：自缩放适应
        _lbPrice.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbPrice];
        
        _lbNum = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbNum.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbNum.textAlignment = NSTextAlignmentRight;
        _lbNum.numberOfLines = 1;
        _lbNum.backgroundColor = [UIColor clearColor];
        _lbNum.font = [UIFont fontWithName:@"Helvetica" size:13.0f];    //  REMARK：自缩放适应
        _lbNum.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbNum];
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

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!_item){
        return;
    }
    
    //  @{@"title":@"1", @"price_asset":[_base objectForKey:@"asset"], @"amount_asset":[_quote objectForKey:@"asset"]}
    //  @{@"time":time, @"issell":@(isSell), @"price":@(price), @"amount":@(amount)}
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    
    if ([[_item objectForKey:@"title"] boolValue]){
        _lbDate.text = NSLocalizedString(@"kLabelTradeHisTitleTime", @"时间");
        _lbDate.textColor = theme.textColorGray;
        
        _lbType.text = NSLocalizedString(@"kLabelTradeHisTitleType", @"方向");
        _lbType.textColor = theme.textColorGray;

        _lbPrice.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kLabelTradeHisTitlePrice", @"价格"), [_item objectForKey:@"price_asset"]];
        _lbPrice.textColor = theme.textColorGray;
        
        _lbNum.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kLabelTradeHisTitleAmount", @"数量"), [_item objectForKey:@"amount_asset"]];
        _lbNum.textColor = theme.textColorGray;
    }else{
        _lbDate.text = [OrgUtils fmtTradeHistoryTimeShowString:[_item objectForKey:@"time"]];
        _lbDate.textColor = theme.textColorMain;
        
        if ([[_item objectForKey:@"issell"] boolValue]){
            _lbType.textColor = theme.sellColor;
            _lbType.text = NSLocalizedString(@"kLabelTradeTypeSell", @"卖出");
        }else{
            _lbType.textColor = theme.buyColor;
            _lbType.text = NSLocalizedString(@"kLabelTradeTypeBuy", @"买入");
        }
        
        //  是否是爆仓单
        if ([[_item objectForKey:@"iscall"] boolValue]){
            _lbType.textColor = theme.callOrderColor;
        }
        
        _lbPrice.text = [OrgUtils formatFloatValue:[[_item objectForKey:@"price"] doubleValue] precision:self.displayPrecision];
        _lbPrice.textColor = theme.textColorMain;
        
        _lbNum.text = [OrgUtils formatFloatValue:[[_item objectForKey:@"amount"] doubleValue] precision:self.numPrecision];
        _lbNum.textColor = theme.textColorMain;
    }
    
    _lbDate.frame = CGRectMake(xOffset, 0, fWidth * 0.25, fCellHeight);
    _lbType.frame = CGRectMake(xOffset + fWidth * 0.25, 0, fWidth * 0.15 - 4, fCellHeight); //  REMARK：向type偏移4像素
    _lbPrice.frame = CGRectMake(xOffset + fWidth * 0.4 - 4, 0, fWidth * 0.3, fCellHeight);
    _lbNum.frame = CGRectMake(xOffset + fWidth * 0.7, 0, fWidth * 0.3, fCellHeight);
}

@end
