//
//  ViewTickerHeader.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "ViewTickerHeader.h"
#import "WalletManager.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "UIImage+Template.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

#import "Extension.h"
#import "VerticalAlignmentLabel.h"
#import "ChainObjectManager.h"
#import "TradingPair.h"

@interface ViewTickerHeader()
{
    TradingPair*                _tradingPair;
    
    VerticalAlignmentLabel*     _lbCurrPrice;
    VerticalAlignmentLabel*     _lbPricePercent;
    
    UILabel*                    _lbFeedPriceTitle;
    UILabel*                    _lbFeedPrice;
    
    UILabel*                    _lbHighTitle;
    UILabel*                    _lbLowTitle;
    UILabel*                    _lb24VolTitle;
    
    UILabel*                    _lbHigh;
    UILabel*                    _lbLow;
    UILabel*                    _lb24Vol;
}

@end

@implementation ViewTickerHeader

- (void)dealloc
{
    _lbCurrPrice = nil;
    _lbPricePercent = nil;
    
    _lbFeedPriceTitle = nil;
    _lbFeedPrice = nil;
    
    _lbHighTitle = nil;
    _lbLowTitle = nil;
    _lb24VolTitle = nil;
    _lbHigh = nil;
    _lbLow = nil;
    _lb24Vol = nil;
}

- (id)initWithTradingPair:(TradingPair*)tradingPair
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        _tradingPair = tradingPair;
        
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.hideTopLine = YES;
        self.hideBottomLine = YES;
        
        self.backgroundColor = [UIColor clearColor];
        
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _lbCurrPrice = [[VerticalAlignmentLabel alloc] initWithFrame:CGRectZero];
        _lbCurrPrice.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbCurrPrice.textAlignment = NSTextAlignmentLeft;
        _lbCurrPrice.numberOfLines = 1;
        _lbCurrPrice.backgroundColor = [UIColor clearColor];
        _lbCurrPrice.font = [UIFont boldSystemFontOfSize:24];
        _lbCurrPrice.adjustsFontSizeToFitWidth = YES;
        _lbCurrPrice.verticalAlignment = VerticalAlignmentBottom;
        [self addSubview:_lbCurrPrice];
        
        _lbPricePercent = [[VerticalAlignmentLabel alloc] initWithFrame:CGRectZero];
        _lbPricePercent.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbPricePercent.textAlignment = NSTextAlignmentLeft;
        _lbPricePercent.numberOfLines = 1;
        _lbPricePercent.backgroundColor = [UIColor clearColor];
        _lbPricePercent.font = [UIFont boldSystemFontOfSize:14];
        _lbPricePercent.adjustsFontSizeToFitWidth = YES;
        _lbPricePercent.verticalAlignment = VerticalAlignmentBottom;
        [self addSubview:_lbPricePercent];
        
        //  喂价
        _lbFeedPriceTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbFeedPriceTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbFeedPriceTitle.textAlignment = NSTextAlignmentLeft;
        _lbFeedPriceTitle.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbFeedPriceTitle.numberOfLines = 1;
        _lbFeedPriceTitle.backgroundColor = [UIColor clearColor];
        _lbFeedPriceTitle.font = [UIFont systemFontOfSize:12];
        _lbFeedPriceTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbFeedPriceTitle];
        
        _lbFeedPrice = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbFeedPrice.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbFeedPrice.textAlignment = NSTextAlignmentLeft;
        _lbFeedPrice.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbFeedPrice.numberOfLines = 1;
        _lbFeedPrice.backgroundColor = [UIColor clearColor];
        _lbFeedPrice.font = [UIFont systemFontOfSize:12];
        _lbFeedPrice.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbFeedPrice];
        
        _lbHighTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbHighTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbHighTitle.textAlignment = NSTextAlignmentLeft;
        _lbHighTitle.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbHighTitle.numberOfLines = 1;
        _lbHighTitle.backgroundColor = [UIColor clearColor];
        _lbHighTitle.font = [UIFont systemFontOfSize:12];
        _lbHighTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbHighTitle];
        
        _lbHigh = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbHigh.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbHigh.textAlignment = NSTextAlignmentRight;
        _lbHigh.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbHigh.numberOfLines = 1;
        _lbHigh.backgroundColor = [UIColor clearColor];
        _lbHigh.font = [UIFont systemFontOfSize:12];
        _lbHigh.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbHigh];
        
        _lbLowTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbLowTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbLowTitle.textAlignment = NSTextAlignmentLeft;
        _lbLowTitle.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbLowTitle.numberOfLines = 1;
        _lbLowTitle.backgroundColor = [UIColor clearColor];
        _lbLowTitle.font = [UIFont systemFontOfSize:12];
        _lbLowTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbLowTitle];
        
        _lbLow = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbLow.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbLow.textAlignment = NSTextAlignmentRight;
        _lbLow.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbLow.numberOfLines = 1;
        _lbLow.backgroundColor = [UIColor clearColor];
        _lbLow.font = [UIFont systemFontOfSize:12];
        _lbLow.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbLow];
        
        _lb24VolTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lb24VolTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lb24VolTitle.textAlignment = NSTextAlignmentLeft;
        _lb24VolTitle.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lb24VolTitle.numberOfLines = 1;
        _lb24VolTitle.backgroundColor = [UIColor clearColor];
        _lb24VolTitle.font = [UIFont systemFontOfSize:12];
        _lb24VolTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lb24VolTitle];
        
        _lb24Vol = [[UILabel alloc] initWithFrame:CGRectZero];
        _lb24Vol.lineBreakMode = NSLineBreakByTruncatingTail;
        _lb24Vol.textAlignment = NSTextAlignmentRight;
        _lb24Vol.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lb24Vol.numberOfLines = 1;
        _lb24Vol.backgroundColor = [UIColor clearColor];
        _lb24Vol.font = [UIFont systemFontOfSize:12];
        _lb24Vol.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lb24Vol];
        
        _lbFeedPriceTitle.text = NSLocalizedString(@"kLabelHeaderFeedPrice", @"喂价");
        _lbFeedPrice.text = @"--";
        _lbFeedPriceTitle.hidden = YES;
        _lbFeedPrice.hidden = YES;
        
        _lbHighTitle.text = NSLocalizedString(@"kLabelHeaderHigh", @"高");
        _lbLowTitle.text = NSLocalizedString(@"kLabelHeaderLow", @"低");
        _lb24VolTitle.text = NSLocalizedString(@"kLabelHeader24HVol", @"24H量");
        _lbHigh.text = @"--";
        _lbLow.text = @"--";
        _lb24Vol.text = @"--";
    }
    return self;
}

- (void)refreshFeedPrice:(NSDecimalNumber*)feedPrice
{
    if (feedPrice){
        _lbFeedPriceTitle.hidden = NO;
        _lbFeedPrice.hidden = NO;
        _lbFeedPrice.text = [OrgUtils formatFloatValue:feedPrice];
    }else{
        _lbFeedPriceTitle.hidden = YES;
        _lbFeedPrice.hidden = YES;
    }
}

- (void)refreshInfos:(MKlineItemData*)model feedPrice:(NSDecimalNumber*)feedPrice
{
    [self refreshFeedPrice:feedPrice];
    if (model){
        _lbLow.text = [OrgUtils formatFloatValue:model.nPriceLow];
        _lbHigh.text = [OrgUtils formatFloatValue:model.nPriceHigh];
        _lb24Vol.text = [OrgUtils formatFloatValue:model.n24Vol];
    }else{
        _lb24Vol.text = @"0";
    }
    [self refreshTickerData];
}

- (void)refreshTickerData
{
    [self setNeedsDisplay];
    //  REMARK fix ios7 detailTextLabel not show
    if ([NativeAppDelegate systemVersion] < 9)
    {
        [self layoutSubviews];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

/**
 *  更新顶部最新价格和今日涨跌幅
 */
- (void)updateLatestPrice:(NSString*)price percent:(NSString*)percent_change
{
    assert(price);
    _lbCurrPrice.text = price;
    
    CGSize size = [self auxSizeWithText:price font:_lbCurrPrice.font maxsize:CGSizeMake(self.bounds.size.width, 9999)];
    CGSize origin_size = _lbPricePercent.bounds.size;
    _lbPricePercent.frame = CGRectMake(_lbCurrPrice.frame.origin.x + size.width + 16, 0, origin_size.width, origin_size.height);
    
    assert(percent_change);
    double percent = [percent_change doubleValue];
    if (percent > 0.0f){
        _lbCurrPrice.textColor = [ThemeManager sharedThemeManager].buyColor;
        _lbPricePercent.textColor = [ThemeManager sharedThemeManager].buyColor;
        _lbPricePercent.text = [NSString stringWithFormat:@"+%@%%", [OrgUtils formatFloatValue:percent precision:2]];
    }else if (percent < 0){
        _lbCurrPrice.textColor = [ThemeManager sharedThemeManager].sellColor;
        _lbPricePercent.textColor = [ThemeManager sharedThemeManager].sellColor;
        _lbPricePercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2]];
    } else {
        _lbCurrPrice.textColor = [ThemeManager sharedThemeManager].zeroColor;
        _lbPricePercent.textColor = [ThemeManager sharedThemeManager].zeroColor;
        _lbPricePercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2]];
    }
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    NSString* latest;
    NSString* percent;
    
    NSDictionary* ticker_data = [[ChainObjectManager sharedChainObjectManager] getTickerData:[_tradingPair.baseAsset objectForKey:@"symbol"]
                                                                                       quote:[_tradingPair.quoteAsset objectForKey:@"symbol"]];
    if (ticker_data){
        latest = [OrgUtils formatFloatValue:[ticker_data[@"latest"] doubleValue]
                                  precision:_tradingPair.basePrecision];
        percent = [ticker_data objectForKey:@"percent_change"];
    }else{
        latest = @"--";
        percent = @"0";
    }

    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fLineHeight = 24;
    
    _lbCurrPrice.frame = CGRectMake(xOffset, 0, fWidth, fLineHeight * 1.5);
    _lbPricePercent.frame = CGRectMake(xOffset, 0, fWidth / 2, fLineHeight * 1.5 - 4);
    [self updateLatestPrice:latest percent:percent];
    
    //  TODO:fowallet ... width
    CGFloat fTitleOffsetX = self.bounds.size.width * 0.6;
    
    if (!_lbFeedPriceTitle.hidden){
        _lbFeedPriceTitle.frame = CGRectMake(xOffset, fLineHeight * 2, fWidth, fLineHeight);
        CGSize size = [self auxSizeWithText:_lbFeedPriceTitle.text font:_lbFeedPriceTitle.font maxsize:CGSizeMake(self.bounds.size.width, 9999)];
        _lbFeedPrice.frame = CGRectMake(xOffset + size.width + 4, fLineHeight * 2, fWidth, fLineHeight);
    }
    
    _lbHighTitle.frame = CGRectMake(fTitleOffsetX, fLineHeight * 0, fWidth, fLineHeight);
    _lbLowTitle.frame = CGRectMake(fTitleOffsetX, fLineHeight * 1, fWidth, fLineHeight);
    _lb24VolTitle.frame = CGRectMake(fTitleOffsetX, fLineHeight * 2, fWidth, fLineHeight);
    
    _lbHigh.frame = CGRectMake(xOffset, fLineHeight * 0, fWidth, fLineHeight);
    _lbLow.frame = CGRectMake(xOffset, fLineHeight * 1, fWidth, fLineHeight);
    _lb24Vol.frame = CGRectMake(xOffset, fLineHeight * 2, fWidth, fLineHeight);
}

@end
