//
//  ViewFillOrderCellVer.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewFillOrderCellVer.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewFillOrderCellVer()
{
    NSDictionary*   _item;
    
    UILabel*        _lbNum;     //  挂单数量
    UILabel*        _lbPrice;   //  挂单价格
}

@end

@implementation ViewFillOrderCellVer

@synthesize displayPrecision;
@synthesize numPrecision;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbNum = nil;
    _lbPrice = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _item = nil;
        //  仅设置个默认值防止出错，启动会从配置文件加载信息动态计算的。
        self.displayPrecision = 8;
        self.numPrecision = 4;
        
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

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!_item) {
        return;
    }
    
    CGFloat fWidth = self.bounds.size.width;
    CGFloat fOffsetX = self.layoutMargins.left;
    
    _lbNum.text = [OrgUtils formatOrderBookValue:[[_item objectForKey:@"amount"] doubleValue]
                                       precision:self.numPrecision usesGroupingSeparator:NO];
    _lbPrice.text = [OrgUtils formatOrderBookValue:[[_item objectForKey:@"price"] doubleValue]
                                         precision:self.displayPrecision usesGroupingSeparator:NO];
    
    //  _item:
    //  base = "4473.9868";
    //  price = "45503.003420668371322";
    //  quote = "0.09832289";
    //    CGFloat xOffset = self.textLabel.frame.origin.x;
    
    _lbNum.frame = CGRectMake(fOffsetX, 0, fWidth - fOffsetX * 2, self.bounds.size.height);
    _lbNum.textAlignment = NSTextAlignmentRight;
    
    _lbPrice.frame = CGRectMake(fOffsetX, 0, fWidth - fOffsetX * 2, self.bounds.size.height);
    _lbPrice.textAlignment = NSTextAlignmentLeft;
    
    //  设置颜色
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    if ([[_item objectForKey:@"iscall"] boolValue]){
        _lbNum.textColor = theme.callOrderColor;
        _lbPrice.textColor = theme.callOrderColor;
    }else{
        _lbNum.textColor = theme.textColorNormal;
        if ([[_item objectForKey:@"issell"] boolValue]){
            _lbPrice.textColor = theme.sellColor;
        }else{
            _lbPrice.textColor = theme.buyColor;
        }
    }
}

@end
