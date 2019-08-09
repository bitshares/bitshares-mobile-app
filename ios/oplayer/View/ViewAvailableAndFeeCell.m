//
//  ViewAvailableAndFeeCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewAvailableAndFeeCell.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "UIImage+Template.h"

@interface ViewAvailableAndFeeCell()
{
    UILabel*        _lbAvailable;       //  可用金额/可用数量
    UILabel*        _lbMarketFee;       //  市场手续费
    UIButton*       _btnTips;
//    CGSize          _sizeBtnImage;
}

@end

@implementation ViewAvailableAndFeeCell

- (void)dealloc
{
    _lbAvailable = nil;
    _lbMarketFee = nil;
    _btnTips = nil;
}

- (void)onTipButtonClicked:(UIButton*)sender
{
//    switch (sender.tag) {
//
//    }
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        _lbAvailable = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAvailable.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAvailable.textAlignment = NSTextAlignmentLeft;
        _lbAvailable.numberOfLines = 1;
        _lbAvailable.backgroundColor = [UIColor clearColor];
        _lbAvailable.font = [UIFont systemFontOfSize:13.0f];
        [self addSubview:_lbAvailable];

        _lbMarketFee = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbMarketFee.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbMarketFee.textAlignment = NSTextAlignmentRight;
        _lbMarketFee.numberOfLines = 1;
        _lbMarketFee.backgroundColor = [UIColor clearColor];
        _lbMarketFee.font = [UIFont systemFontOfSize:13.0f];
        _lbMarketFee.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbMarketFee];
        
//        //  是否有帮助按钮
//        _btnTips = [UIButton buttonWithType:UIButtonTypeCustom];
//        UIImage* btn_image = [UIImage templateImageNamed:@"Help-50"];
//        _sizeBtnImage = btn_image.size;
//        [_btnTips setBackgroundImage:btn_image forState:UIControlStateNormal];
//        _btnTips.userInteractionEnabled = YES;
//        [_btnTips addTarget:self action:@selector(onTipButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
//        _btnTips.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
//        [self addSubview:_btnTips];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)draw_available:(NSString*)value enough:(BOOL)enough isbuy:(BOOL)isbuy tradingPair:(TradingPair*)tradingPair
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    NSString* symbol;
    NSString* not_enough_str;
    if (isbuy) {
        symbol = [tradingPair.baseAsset objectForKey:@"symbol"];
        not_enough_str = NSLocalizedString(@"kVcTradeTipAvailableNotEnough", @"金额不足");
    } else {
        symbol = [tradingPair.quoteAsset objectForKey:@"symbol"];
        not_enough_str = NSLocalizedString(@"kVcTradeTipAmountNotEnough", @"数量不足");
    }
    
    NSString* value_str;
    UIColor* value_color;
    if (enough){
        value_str = [NSString stringWithFormat:@"%@%@", value ?: @"--", symbol];
        value_color = theme.textColorNormal;
    }else{
        value_str = [NSString stringWithFormat:@"%@%@(%@)", value ?: @"--", symbol, not_enough_str];
        value_color = theme.tintColor;
    }
    
    _lbAvailable.attributedText = [UITableViewCellBase genAndColorAttributedText:[NSString stringWithFormat:@"%@ ", NSLocalizedString(@"kLableAvailable", @"可用")]
                                                                           value:value_str
                                                                      titleColor:value_color
                                                                      valueColor:value_color];
}

- (void)draw_market_fee:(NSDictionary*)asset account:(NSDictionary*)account
{
    id market_fee_percent = [[asset objectForKey:@"options"] objectForKey:@"market_fee_percent"];
    if (market_fee_percent){
        id n_market_fee_percent = [NSDecimalNumber decimalNumberWithMantissa:[market_fee_percent unsignedLongLongValue]
                                                                    exponent:-2 isNegative:NO];
//        if ([OrgUtils isBitsharesVIP:[account objectForKey:@"membership_expiration_date"]]){
//            _lbMarketFee.text = [NSString stringWithFormat:@"手续费 %@%%(2折)", n_market_fee_percent];
//        }else{
            _lbMarketFee.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelMarketFee", @"手续费 %@"), [NSString stringWithFormat:@"%@%%", n_market_fee_percent]];
//        }
    }else{
        _lbMarketFee.text = [NSString stringWithFormat:NSLocalizedString(@"kLabelMarketFee", @"手续费 %@"), @"0%"];
    }
    _lbMarketFee.textColor = [ThemeManager sharedThemeManager].textColorNormal;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    
    _lbAvailable.frame = CGRectMake(xOffset, 0, fWidth, fCellHeight - 16);
    
//    _btnTips.frame = CGRectMake(self.bounds.size.width - _sizeBtnImage.width - xOffset,
//                                (fCellHeight - 16 - _sizeBtnImage.height) / 2,
//                                _sizeBtnImage.width - 4, _sizeBtnImage.height - 4);
    
    _lbMarketFee.frame = CGRectMake(xOffset, 0, fWidth, fCellHeight - 16);
}

@end
