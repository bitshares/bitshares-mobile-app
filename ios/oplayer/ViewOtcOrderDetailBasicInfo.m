//
//  ViewOtcOrderDetailBasicInfo.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewOtcOrderDetailBasicInfo.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "OtcManager.h"

@interface ViewOtcOrderDetailBasicInfo()
{
    NSDictionary*   _item;
    
    UILabel*        _lbTotal;
    UILabel*        _lbPrice;
    UILabel*        _lbAmount;
}

@end

@implementation ViewOtcOrderDetailBasicInfo

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbTotal = nil;
    _lbPrice = nil;
    _lbAmount = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];

        _lbTotal = [self auxGenLabel:[UIFont boldSystemFontOfSize:28.0f]];
        _lbPrice = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbAmount = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbAmount.textAlignment = NSTextAlignmentRight;
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
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fWidth = self.bounds.size.width - fOffsetX *  2;
    
    //  TODO:2.9 订单返回的是全角符号...
    NSString* fiat_symbol = [[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"legalCurrencySymbol"];
//    NSString* fiat_symbol = [_item objectForKey:@"legalCurrencySymbol"];
    NSString* asset_symbol = [_item objectForKey:@"assetSymbol"];
    
    //  TODO:2.9 3E+2 格式
    id n_amount = [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", _item[@"amount"]]];
    _lbTotal.text = [NSString stringWithFormat:@"%@ %@", fiat_symbol, n_amount];
    _lbTotal.textColor = theme.textColorHighlight;
    
    _lbPrice.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kOtcOdCellUnitPrice", @"单价 ")
                                                        value:[NSString stringWithFormat:@"%@%@", fiat_symbol, _item[@"unitPrice"]]
                                                   titleColor:theme.textColorNormal
                                                   valueColor:theme.textColorMain];
    
    _lbAmount.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kOtcOdCellAmount", @"数量 ")
                                                         value:[NSString stringWithFormat:@"%@ %@", [NSDecimalNumber decimalNumberWithString:[NSString stringWithFormat:@"%@", _item[@"quantity"]]],
                                                                asset_symbol]
                                                    titleColor:theme.textColorNormal
                                                    valueColor:theme.textColorMain];
    
    _lbTotal.frame = CGRectMake(fOffsetX, 0, fWidth, 48);
    _lbPrice.frame = CGRectMake(fOffsetX, 48, fWidth, 20.0f);
    _lbAmount.frame = CGRectMake(fOffsetX, 48, fWidth, 20.0f);
}

@end
