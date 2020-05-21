//
//  ViewMarketTickerInfoCell.m
//  oplayer
//
//  Created by SYALON on 14-1-12.
//
//
#import "NativeAppDelegate.h"
#import "ViewMarketTickerInfoCell.h"
#import "OrgUtils.h"
#import "ThemeManager.h"
#import "ChainObjectManager.h"

@interface ViewMarketTickerInfoCell()
{
    NSDictionary*   _item;
    NSDictionary*   _group_info;
    
    UILabel*        _lbName;
    UILabel*        _lbBaseName;
    UILabel*        _lbCustomLabel;
    
    UILabel*        _lbVolume24;
    UILabel*        _lbCurrPrice;
    
    UILabel*        _lbPercent;
}

@end

@implementation ViewMarketTickerInfoCell

@synthesize item=_item;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _item = nil;
        _group_info = nil;
        
        // Initialization code
        _lbName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbName.numberOfLines = 1;
        _lbName.backgroundColor = [UIColor clearColor];
        _lbName.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbName.font = [UIFont boldSystemFontOfSize:18];
        [self addSubview:_lbName];
        
        _lbBaseName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbBaseName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbBaseName.numberOfLines = 1;
        _lbBaseName.backgroundColor = [UIColor clearColor];
        _lbBaseName.textColor = [ThemeManager sharedThemeManager].textColorGray;
        _lbBaseName.font = [UIFont systemFontOfSize:12];
        [self addSubview:_lbBaseName];
        
        UIColor* customBackColor = [ThemeManager sharedThemeManager].textColorHighlight;
        _lbCustomLabel = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:12] superview:self];
        _lbCustomLabel.backgroundColor = [UIColor clearColor];
        _lbCustomLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbCustomLabel.layer.borderWidth = 1;
        _lbCustomLabel.layer.cornerRadius = 2;
        _lbCustomLabel.layer.masksToBounds = YES;
        _lbCustomLabel.layer.borderColor = customBackColor.CGColor;
        _lbCustomLabel.layer.backgroundColor = customBackColor.CGColor;
        _lbCustomLabel.text = NSLocalizedString(@"kSettingApiCellCustomFlag", @"自定义");
        
        _lbVolume24 = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbVolume24.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbVolume24.numberOfLines = 1;
        _lbVolume24.backgroundColor = [UIColor clearColor];
        _lbVolume24.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbVolume24.font = [UIFont systemFontOfSize:12];
        [self addSubview:_lbVolume24];
        
        _lbCurrPrice = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbCurrPrice.textAlignment = NSTextAlignmentRight;
        _lbCurrPrice.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbCurrPrice.numberOfLines = 1;
        _lbCurrPrice.backgroundColor = [UIColor clearColor];
        _lbCurrPrice.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbCurrPrice.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_lbCurrPrice];
        
        //  涨跌幅
        _lbPercent = [[UILabel alloc] initWithFrame:CGRectZero];
        UIColor* backColor = [ThemeManager sharedThemeManager].zeroColor;
        _lbPercent.textAlignment = NSTextAlignmentCenter;
        _lbPercent.font = [UIFont systemFontOfSize:17];
        _lbPercent.text = @"0%";
        _lbPercent.backgroundColor = [UIColor clearColor];
        _lbPercent.textColor = [ThemeManager sharedThemeManager].textColorPercent;
        _lbPercent.font = [UIFont boldSystemFontOfSize:16];
        _lbPercent.adjustsFontSizeToFitWidth = YES; //  自适应
        
        _lbPercent.layer.borderWidth = 1;
        _lbPercent.layer.cornerRadius = 0;
        _lbPercent.layer.masksToBounds = YES;
        _lbPercent.layer.borderColor = backColor.CGColor;
        _lbPercent.layer.backgroundColor = backColor.CGColor;
        
        [self addSubview:_lbPercent];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)setGroupInfo:(NSDictionary*)group_info
{
    _group_info = group_info;
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
    
    if (!_item)
        return;
    
    CGFloat fWidth = self.bounds.size.width;
    CGFloat fOffsetX = 12.0f;
    
    //    item = @{@"base_asset":_base_asset, @"quote":[quote objectForKey:@"name"], @"ticker_data":ticker_data};
    //    //  ticker_data:
    //    {"id"=>5,
    //        "jsonrpc"=>"2.0",
    //        "result"=>
    //        {"time"=>"2018-05-21T10:49:18",
    //            "base"=>"CNY",
    //            "quote"=>"BTS",
    //            "latest"=>"1.610009998886597585",
    //            "lowest_ask"=>"1.610019305911588168",
    //            "highest_bid"=>"1.610009998886597585",
    //            "percent_change"=>"-2.41",
    //            "base_volume"=>"16413477.773",
    //            "quote_volume"=>"9977701.34304"}}
    
    id base_asset = [_item objectForKey:@"base"];
    assert(base_asset);
    id quote_asset = [_item objectForKey:@"quote"];
    assert(quote_asset);
    
    NSInteger base_precision = [[base_asset objectForKey:@"precision"] integerValue];
    
    //  第一行
    id quote_name = [quote_asset objectForKey:@"symbol"];
    NSInteger quote_precision = [[quote_asset objectForKey:@"precision"] integerValue];
    
    //  REMARK：如果是网关资产、则移除网关前缀。自选市场没有分组信息，网关资产也显示全称。
    if (_group_info && [[_group_info objectForKey:@"gateway"] boolValue]){
        id prefix = [_group_info objectForKey:@"prefix"];
        if ([quote_name rangeOfString:prefix].location == 0){
            id ary = [[quote_name componentsSeparatedByString:@"."] mutableCopy];
            if ([[ary firstObject] isEqualToString:prefix]){
                [ary removeObjectAtIndex:0];
                quote_name = [ary componentsJoinedByString:@"."];
            }
        }
    }
    
    NSString* base_name = [_item objectForKey:@"base_market_name"];
    //  REMARK：如果 base 的别名刚好和交易资产名字相同，则显示 base 的原始资产名字。
    if ([base_name isEqualToString:quote_name]) {
        base_name = [base_asset objectForKey:@"symbol"];
    }
    
    //  UI - 交易资产名
    _lbName.text = quote_name;
    _lbName.frame = CGRectMake(fOffsetX, 0, fWidth - 24, 32);
    
    //  UI - 报价资产名称
    CGSize size_quote_name = [ViewUtils auxSizeWithLabel:_lbName];
    _lbBaseName.text = [NSString stringWithFormat:@" / %@", base_name];
    _lbBaseName.frame = CGRectMake(fOffsetX + size_quote_name.width, 3, 120, 30);
    _lbBaseName.hidden = NO;
    
    //  UI - 默认交易对中【非内置】交易对，添加【自定义】标签。【自选市场】不用显示。
    if (_group_info && ![[ChainObjectManager sharedChainObjectManager] isDefaultPair:quote_asset base:base_asset]) {
        _lbCustomLabel.hidden = NO;
        CGSize size1 = [ViewUtils auxSizeWithLabel:_lbBaseName];
        CGSize size2 = [ViewUtils auxSizeWithLabel:_lbCustomLabel];
        _lbCustomLabel.frame = CGRectMake(_lbBaseName.frame.origin.x + size1.width + 4,
                                          (32 - size2.height - 2)/2,
                                          size2.width + 8,
                                          size2.height + 2);
    } else {
        _lbCustomLabel.hidden = YES;
    }
    
    //  获取数据
    id ticker_data = [_item objectForKey:@"ticker_data"];
    NSString* latest;
    NSString* quote_volume;
    NSString* percent_change;
    if (ticker_data){
        //  TODO:货币符号(还分半角全角) ¥＄€£ ￥
        NSString* sym = @"";
        id base_asset_symbol = [base_asset objectForKey:@"symbol"];
        if ([base_asset_symbol isEqualToString:@"CNY"]){
            sym = @"¥"; //  REMARK：半角形式，如果需要全角用这个￥。
        }else if ([base_asset_symbol isEqualToString:@"USD"]){
            sym = @"$"; //  REMARK：半角形式，如果需要全角用这个＄。
        }
        latest = [NSString stringWithFormat:@"%@%@", sym, [OrgUtils formatFloatValue:[[ticker_data objectForKey:@"latest"] doubleValue]
                                                                           precision:base_precision]];
        quote_volume = [OrgUtils formatFloatValue:[[ticker_data objectForKey:@"quote_volume"] doubleValue]
                                        precision:quote_precision];
        percent_change = [ticker_data objectForKey:@"percent_change"];
    }else{
        latest = @"--";
        quote_volume = @"--";
        percent_change = @"0";
    }
    
    //  处理显示
    CGFloat percent_label_width = 80.0f;
    CGFloat price_label_width = 120.0f;
    
    _lbCurrPrice.text = latest;
    _lbCurrPrice.frame = CGRectMake(fWidth - fOffsetX - percent_label_width - price_label_width - 8, 9, price_label_width, 32);
    
    //  第二行
    _lbVolume24.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kLable24HVol", @"24h量"), quote_volume];
    _lbVolume24.frame = CGRectMake(fOffsetX, 20, fWidth - 24, 32);
    
    //  尾巴
    double percent = [percent_change doubleValue];
    if (percent > 0.0f){
        UIColor* backColor = [ThemeManager sharedThemeManager].buyColor;
        _lbPercent.layer.borderColor = backColor.CGColor;
        _lbPercent.layer.backgroundColor = backColor.CGColor;
        _lbPercent.text = [NSString stringWithFormat:@"+%@%%", [OrgUtils formatFloatValue:percent precision:2 usesGroupingSeparator:NO]];
    }else if (percent < 0){
        UIColor* backColor = [ThemeManager sharedThemeManager].sellColor;
        _lbPercent.layer.borderColor = backColor.CGColor;
        _lbPercent.layer.backgroundColor = backColor.CGColor;
        _lbPercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2 usesGroupingSeparator:NO]];
    } else {
        UIColor* backColor = [ThemeManager sharedThemeManager].zeroColor;
        _lbPercent.layer.borderColor = backColor.CGColor;
        _lbPercent.layer.backgroundColor = backColor.CGColor;
        _lbPercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2 usesGroupingSeparator:NO]];
    }
    _lbPercent.frame = CGRectMake(fWidth - fOffsetX - percent_label_width, 9, percent_label_width, 32);
}

@end
