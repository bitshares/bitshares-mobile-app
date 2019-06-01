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
    
    id base_name = [_item objectForKey:@"base_market_name"];
    
    if (_group_info){
        //  普通市场（基本资产小写、不突出）
        _lbName.text = quote_name;
        _lbName.frame = CGRectMake(12, 0, fWidth - 24, 32);
        CGSize size1 = CGSizeMake(fWidth, 9999);
        
        //  TODO:fowallet auxSizeWithText兼容性待测试
        size1 = [self auxSizeWithText:quote_name font:_lbName.font maxsize:size1];
//        size1 = [quote_name sizeWithFont:_lbName.font constrainedToSize:size1 lineBreakMode:UILineBreakModeWordWrap];
        
        _lbBaseName.text = [NSString stringWithFormat:@" / %@", base_name];
        _lbBaseName.frame = CGRectMake(12 + size1.width, 3, 120, 30);
        _lbBaseName.hidden = NO;
    }else{
        //  自选市场（基本资产不用小写）
        _lbName.text = [NSString stringWithFormat:@"%@/%@", quote_name, base_name];
        _lbName.frame = CGRectMake(12, 0, fWidth - 24, 32);
        _lbBaseName.hidden = YES;
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
    _lbCurrPrice.frame = CGRectMake(fWidth - 12 - percent_label_width - price_label_width - 8, 9, price_label_width, 32);
    
    //  第二行
    _lbVolume24.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kLable24HVol", @"24h量"), quote_volume];
    _lbVolume24.frame = CGRectMake(12, 20, fWidth - 24, 32);
    
    //  尾巴
    double percent = [percent_change doubleValue];
    if (percent > 0.0f){
        UIColor* backColor = [ThemeManager sharedThemeManager].buyColor;
        _lbPercent.layer.borderColor = backColor.CGColor;
        _lbPercent.layer.backgroundColor = backColor.CGColor;
        _lbPercent.text = [NSString stringWithFormat:@"+%@%%", [OrgUtils formatFloatValue:percent precision:2]];
    }else if (percent < 0){
        UIColor* backColor = [ThemeManager sharedThemeManager].sellColor;
        _lbPercent.layer.borderColor = backColor.CGColor;
        _lbPercent.layer.backgroundColor = backColor.CGColor;
        _lbPercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2]];
    } else {
        UIColor* backColor = [ThemeManager sharedThemeManager].zeroColor;
        _lbPercent.layer.borderColor = backColor.CGColor;
        _lbPercent.layer.backgroundColor = backColor.CGColor;
        _lbPercent.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:percent precision:2]];
    }
    _lbPercent.frame = CGRectMake(fWidth - 12 - percent_label_width, 9, percent_label_width, 32);
}

@end
