//
//  ViewLimitOrderInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewLimitOrderInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewLimitOrderInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbType;        //  买/卖
    UILabel*        _lbDate;        //  日期
    
    UILabel*        _lbPriceTitle;
    UILabel*        _lbPrice;       //  价格
    
    UILabel*        _lbNumTitle;
    UILabel*        _lbNum;         //  数量
    
    UILabel*        _lbTotalTitle;
    UILabel*        _lbTotal;       //  总金额
    
    UIButton*       _btnCancel;     //  撤销订单按钮
}

@end

@implementation ViewLimitOrderInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbDate = nil;
    _lbType = nil;
    _lbPriceTitle = nil;
    _lbPrice = nil;
    _lbNumTitle = nil;
    _lbNum = nil;
    _lbTotalTitle = nil;
    _lbTotal = nil;
    
    _btnCancel = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        //  第一行
        _lbType = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbType.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbType.textAlignment = NSTextAlignmentLeft;
        _lbType.numberOfLines = 1;
        _lbType.backgroundColor = [UIColor clearColor];
        _lbType.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_lbType];
     
        _lbDate = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbDate.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbDate.textAlignment = NSTextAlignmentLeft;
        _lbDate.numberOfLines = 1;
        _lbDate.backgroundColor = [UIColor clearColor];
        _lbDate.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbDate];
        
        if (vc){
            _btnCancel = [UIButton buttonWithType:UIButtonTypeCustom];
            _btnCancel.backgroundColor = [UIColor clearColor];
            [_btnCancel setTitle:NSLocalizedString(@"kVcOrderBtnCancel", @"撤销") forState:UIControlStateNormal];
            [_btnCancel setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
            _btnCancel.titleLabel.font = [UIFont systemFontOfSize:16.0];
            _btnCancel.userInteractionEnabled = YES;
            _btnCancel.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
            [_btnCancel addTarget:vc action:@selector(onButtonClicked_CancelOrder:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_btnCancel];
        }else{
            _btnCancel = nil;
        }
        
        //  第二行
        _lbPriceTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbPriceTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbPriceTitle.textAlignment = NSTextAlignmentLeft;
        _lbPriceTitle.numberOfLines = 1;
        _lbPriceTitle.backgroundColor = [UIColor clearColor];
        _lbPriceTitle.font = [UIFont systemFontOfSize:13];
        _lbPriceTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbPriceTitle];
        
        _lbNumTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbNumTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbNumTitle.textAlignment = NSTextAlignmentCenter;
        _lbNumTitle.numberOfLines = 1;
        _lbNumTitle.backgroundColor = [UIColor clearColor];
        _lbNumTitle.font = [UIFont systemFontOfSize:13];
        _lbNumTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbNumTitle];
        
        _lbTotalTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTotalTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTotalTitle.textAlignment = NSTextAlignmentRight;
        _lbTotalTitle.numberOfLines = 1;
        _lbTotalTitle.backgroundColor = [UIColor clearColor];
        _lbTotalTitle.font = [UIFont systemFontOfSize:13];
        _lbTotalTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbTotalTitle];
        
        //  第三行
        _lbPrice = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbPrice.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbPrice.textAlignment = NSTextAlignmentLeft;
        _lbPrice.numberOfLines = 1;
        _lbPrice.backgroundColor = [UIColor clearColor];
        _lbPrice.font = [UIFont systemFontOfSize:14];
        _lbPrice.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbPrice];
        
        _lbNum = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbNum.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbNum.textAlignment = NSTextAlignmentCenter;
        _lbNum.numberOfLines = 1;
        _lbNum.backgroundColor = [UIColor clearColor];
        _lbNum.font = [UIFont systemFontOfSize:14];
        _lbNum.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbNum];
        
        _lbTotal = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTotal.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTotal.textAlignment = NSTextAlignmentRight;
        _lbTotal.numberOfLines = 1;
        _lbTotal.backgroundColor = [UIColor clearColor];
        _lbTotal.font = [UIFont systemFontOfSize:14];
        _lbTotal.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbTotal];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)setTagData:(NSInteger)tag
{
    if (_btnCancel){
        _btnCancel.tag = tag;
    }
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
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 0;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    
    //  第一行 买卖 PAIR
    BOOL iscall = [[_item objectForKey:@"iscall"] boolValue];
    id pair = [NSString stringWithFormat:@"%@/%@", _item[@"quote_symbol"], _item[@"base_symbol"]];
    if ([[_item objectForKey:@"issell"] boolValue]){
        _lbType.attributedText = [self genAndColorAttributedText:[NSString stringWithFormat:@"%@ ", NSLocalizedString(@"kLabelTradeTypeSell", @"卖出")]
                                                           value:pair
                                                      titleColor:iscall ? theme.callOrderColor : theme.sellColor
                                                      valueColor:theme.textColorMain];
    }else{
        _lbType.attributedText = [self genAndColorAttributedText:[NSString stringWithFormat:@"%@ ", NSLocalizedString(@"kLabelTradeTypeBuy", @"买入")]
                                                           value:pair
                                                      titleColor:iscall ? theme.callOrderColor : theme.buyColor
                                                      valueColor:theme.textColorMain];
    }
    _lbType.frame = CGRectMake(xOffset, yOffset, fWidth, 28);
    
    //  限价单过期时间 or 交易历史时间
    if ([[_item objectForKey:@"ishistory"] boolValue]){
        if (_btnCancel){
            _btnCancel.hidden = YES;
        }
        _lbDate.textAlignment = NSTextAlignmentRight;
        id block_time = [_item objectForKey:@"block_time"];
        if (block_time){
            _lbDate.hidden = NO;
            _lbDate.text = [OrgUtils fmtAccountHistoryTimeShowString:block_time];
            _lbDate.frame = CGRectMake(xOffset, yOffset + 1, fWidth, 28);
            _lbDate.textColor = theme.textColorGray;
        }else{
            //  TODO:fowallet 交易记录日期查询中，转圈动画？？？
            _lbDate.hidden = YES;
        }
    }else{
        _lbDate.textAlignment = NSTextAlignmentLeft;
        _lbDate.hidden = NO;
        if (_btnCancel){
            _btnCancel.hidden = NO;
        }
        CGSize size1 = CGSizeMake(fWidth, 9999);
        size1 = [_lbType.attributedText.string sizeWithFont:_lbType.font constrainedToSize:size1 lineBreakMode:UILineBreakModeWordWrap];
        _lbDate.text = [NSString stringWithFormat:NSLocalizedString(@"kVcOrderExpired", @"%@过期"), [OrgUtils fmtLimitOrderTimeShowString:[_item objectForKey:@"time"]]];
        _lbDate.frame = CGRectMake(xOffset + 8 + size1.width, yOffset + 1, fWidth, 28);
        _lbDate.textColor = theme.textColorGray;
    }
    
    //  TODO:fowallet cancel
    if (_btnCancel){
        _btnCancel.frame = CGRectMake(self.bounds.size.width - xOffset - 120, yOffset, 120, 28);
    }
    
    yOffset += 28;
    
    //  第二行 数量和价格标题
    
    _lbPriceTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kLabelTradeHisTitlePrice", @"价格"), _item[@"base_symbol"]];
    _lbNumTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kLabelTradeHisTitleAmount", @"数量"), _item[@"quote_symbol"]];
    _lbTotalTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kVcOrderTotal", @"总金额"), _item[@"base_symbol"]];
    _lbPriceTitle.textColor = theme.textColorGray;
    _lbNumTitle.textColor = theme.textColorGray;
    _lbTotalTitle.textColor = theme.textColorGray;
    
    _lbPriceTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbNumTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbTotalTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    
    yOffset += 24;
    
    //  第三行 数量和价格
    _lbPrice.text = [_item objectForKey:@"price"];
    _lbPrice.textColor = theme.textColorNormal;
    
    _lbNum.text = [_item objectForKey:@"amount"];
    _lbNum.textColor = theme.textColorNormal;
    
    _lbTotal.text = [_item objectForKey:@"total"];
    _lbTotal.textColor = theme.textColorNormal;
    
    _lbPrice.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbNum.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbTotal.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
}

@end
