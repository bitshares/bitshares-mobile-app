//
//  ViewCallOrderInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewCallOrderInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewCallOrderInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbUsername;
    UILabel*        _lbRate;
    
    UILabel*        _lbTriggerPrice;
    
    UILabel*        _lbAssetCollateral;
    UILabel*        _lbAssetDebt;
}

@end

@implementation ViewCallOrderInfoCell

@synthesize feedPriceInfo;
@synthesize item=_item;

- (void)dealloc
{
    self.feedPriceInfo = nil;
    _item = nil;
    
    _lbUsername = nil;
    _lbRate = nil;
    _lbTriggerPrice = nil;
    _lbAssetCollateral = nil;
    _lbAssetDebt = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        self.feedPriceInfo = [NSDecimalNumber zero];
        _item = nil;
        
        _lbUsername = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbUsername.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbUsername.textAlignment = NSTextAlignmentLeft;
        _lbUsername.numberOfLines = 1;
        _lbUsername.backgroundColor = [UIColor clearColor];
        _lbUsername.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbUsername.font = [UIFont systemFontOfSize:16];
        [self addSubview:_lbUsername];
        
        _lbRate = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbRate.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbRate.textAlignment = NSTextAlignmentRight;
        _lbRate.numberOfLines = 1;
        _lbRate.backgroundColor = [UIColor clearColor];
        _lbRate.textColor = [ThemeManager sharedThemeManager].tintColor;
        _lbRate.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbRate];
        
        _lbTriggerPrice = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTriggerPrice.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTriggerPrice.textAlignment = NSTextAlignmentLeft;
        _lbTriggerPrice.numberOfLines = 1;
        _lbTriggerPrice.backgroundColor = [UIColor clearColor];
        _lbTriggerPrice.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbTriggerPrice.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbTriggerPrice];
        
        _lbAssetCollateral = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAssetCollateral.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAssetCollateral.textAlignment = NSTextAlignmentLeft;
        _lbAssetCollateral.numberOfLines = 1;
        _lbAssetCollateral.backgroundColor = [UIColor clearColor];
        _lbAssetCollateral.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbAssetCollateral.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbAssetCollateral];
        
        _lbAssetDebt = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAssetDebt.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAssetDebt.textAlignment = NSTextAlignmentRight;
        _lbAssetDebt.numberOfLines = 1;
        _lbAssetDebt.backgroundColor = [UIColor clearColor];
        _lbAssetDebt.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbAssetDebt.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbAssetDebt];
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
    
    if (!_item)
        return;
    
    //  TODO:fowallet 719新版本爆仓调整，强平价格根据 call_price 计算还是  debt和diya计算。
    //  The call price is DEBT * MCR / COLLATERAL
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat fWidth = self.bounds.size.width;
    
    //  header
    CGFloat fOffsetY = 0.0f;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fOffsetX_2x = fOffsetX * 2;
    
    id call_price = [_item objectForKey:@"call_price"];
    assert(call_price);
    id coll_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[call_price objectForKey:@"base"][@"asset_id"]];
    id debt_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[call_price objectForKey:@"quote"][@"asset_id"]];
    assert(coll_asset);
    assert(debt_asset);
    
    NSInteger coll_precision = [[coll_asset objectForKey:@"precision"] integerValue];
    NSInteger debt_precision = [[debt_asset objectForKey:@"precision"] integerValue];
    double f_collateral = [OrgUtils calcAssetRealPrice:[_item objectForKey:@"collateral"] precision:coll_precision];
    double f_debt = [OrgUtils calcAssetRealPrice:[_item objectForKey:@"debt"] precision:debt_precision];
    
    double rate_percent100 = 100 * [self.feedPriceInfo doubleValue] * f_collateral / f_debt;
    
    //  第一行
    NSString* borrower_str = nil;
    id borrower_id = [_item objectForKey:@"borrower"];
    id borrower_account = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:borrower_id];
    if (borrower_account){
        borrower_str = [borrower_account objectForKey:@"name"];
    }else{
        borrower_str = borrower_id;
    }
    _lbUsername.text = borrower_str;
    _lbUsername.frame = CGRectMake(fOffsetX, fOffsetY, fWidth - fOffsetX_2x, 28);
    
    //  TODO:fowallet 各种标签：强平中、即将清算、接近平仓、安全
    
    fOffsetY += 28;
    
    //  第二行
    
    //  强平触发价 高精度计算
    NSDecimalNumber* n_settlement_trigger_price = [OrgUtils calcSettlementTriggerPrice:call_price
                                                                  collateral_precision:coll_precision
                                                                        debt_precision:debt_precision];
    //  非高精度计算
//    double f_callprice_base = [OrgUtils calcAssetRealPrice:[[call_price objectForKey:@"base"] objectForKey:@"amount"]
//                                                 precision:coll_precision];
//    double f_callprice_quote = [OrgUtils calcAssetRealPrice:[[call_price objectForKey:@"quote"] objectForKey:@"amount"]
//                                                  precision:debt_precision];
//    double f_settlemet_trigger_price = f_callprice_quote/f_callprice_base;
//    NSString* str_settlemet_trigger_price = [OrgUtils formatFloatValue:f_settlemet_trigger_price precision:debt_precision];
    _lbTriggerPrice.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcRankCallPrice", @"强平触发价 ")
                                                                  value:[NSString stringWithFormat:@"%@", n_settlement_trigger_price]
                                                             titleColor:theme.textColorNormal
                                                             valueColor:theme.textColorMain];
    _lbTriggerPrice.frame = CGRectMake(fOffsetX, fOffsetY, fWidth - fOffsetX_2x, 28);
    
    _lbRate.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcRankRatio", @"抵押率 ")
                                                       value:[NSString stringWithFormat:@"%0.2f%%", rate_percent100]
                                                  titleColor:theme.textColorNormal
                                                  valueColor:theme.tintColor];
    _lbRate.frame = CGRectMake(fOffsetX, fOffsetY, fWidth - fOffsetX_2x, 28);
    
    fOffsetY += 28;
    
    _lbAssetCollateral.attributedText = [self genAndColorAttributedText:[NSString stringWithFormat:@"%@(%@) ", NSLocalizedString(@"kVcRankColl", @"抵押"), coll_asset[@"symbol"]]
                                                                  value:[OrgUtils formatAssetString:_item[@"collateral"]
                                                                                          precision:coll_precision]
                                                             titleColor:theme.textColorNormal
                                                             valueColor:theme.textColorMain];
    _lbAssetCollateral.frame = CGRectMake(fOffsetX, fOffsetY, fWidth - fOffsetX_2x, 28);
    
    _lbAssetDebt.attributedText = [self genAndColorAttributedText:[NSString stringWithFormat:@"%@(%@) ", NSLocalizedString(@"kVcRankDebt", @"借入"), debt_asset[@"symbol"]]
                                                            value:[OrgUtils formatAssetString:_item[@"debt"] precision:debt_precision]
                                                       titleColor:theme.textColorNormal
                                                       valueColor:theme.textColorMain];
    _lbAssetDebt.frame = CGRectMake(fOffsetX, fOffsetY, fWidth - fOffsetX_2x, 28);
}

@end
