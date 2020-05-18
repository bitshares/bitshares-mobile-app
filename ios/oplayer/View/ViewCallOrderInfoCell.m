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
    UILabel*        _lbWillSettlementFlag;
    
    UILabel*        _lbRate;
    
    UILabel*        _lbAssetDebtTitle;
    UILabel*        _lbAssetDebtValue;
    
    UILabel*        _lbAssetCollateralTitle;
    UILabel*        _lbAssetCollateralValue;
    
    UILabel*        _lbTriggerPriceTitle;
    UILabel*        _lbTriggerPriceValue;
}

@end

@implementation ViewCallOrderInfoCell

@synthesize feedPriceInfo;
@synthesize mcr;
@synthesize item=_item;
@synthesize debt_precision;
@synthesize collateral_precision;

- (void)dealloc
{
    self.feedPriceInfo = nil;
    self.mcr = nil;
    _item = nil;
    
    _lbUsername = nil;
    _lbWillSettlementFlag = nil;
    _lbRate = nil;
    
    _lbAssetDebtTitle = nil;
    _lbAssetDebtValue = nil;
    
    _lbAssetCollateralTitle = nil;
    _lbAssetCollateralValue = nil;
    
    _lbTriggerPriceTitle = nil;
    _lbTriggerPriceValue = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        self.feedPriceInfo = [NSDecimalNumber zero];
        self.mcr = nil;
        _item = nil;
        
        _lbUsername = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbUsername.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbUsername.textAlignment = NSTextAlignmentLeft;
        _lbUsername.numberOfLines = 1;
        _lbUsername.backgroundColor = [UIColor clearColor];
        _lbUsername.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbUsername.font = [UIFont systemFontOfSize:16];
        [self addSubview:_lbUsername];
        
        _lbWillSettlementFlag = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:12.0f] superview:self];
        UIColor* backColor = [ThemeManager sharedThemeManager].sellColor;
        _lbWillSettlementFlag.textAlignment = NSTextAlignmentCenter;
        _lbWillSettlementFlag.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbWillSettlementFlag.layer.borderWidth = 1;
        _lbWillSettlementFlag.layer.cornerRadius = 2;
        _lbWillSettlementFlag.layer.masksToBounds = YES;
        _lbWillSettlementFlag.layer.borderColor = backColor.CGColor;
        _lbWillSettlementFlag.layer.backgroundColor = backColor.CGColor;
        _lbWillSettlementFlag.hidden = YES;
        
        _lbRate = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbRate.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbRate.textAlignment = NSTextAlignmentRight;
        _lbRate.numberOfLines = 1;
        _lbRate.backgroundColor = [UIColor clearColor];
        _lbRate.textColor = [ThemeManager sharedThemeManager].tintColor;
        _lbRate.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbRate];
        
        _lbAssetDebtTitle = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _lbAssetDebtValue = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _lbAssetDebtTitle.textAlignment = NSTextAlignmentLeft;
        _lbAssetDebtValue.textAlignment = NSTextAlignmentLeft;
        
        _lbAssetCollateralTitle = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _lbAssetCollateralValue = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _lbAssetCollateralTitle.textAlignment = NSTextAlignmentCenter;
        _lbAssetCollateralValue.textAlignment = NSTextAlignmentCenter;
        
        _lbTriggerPriceTitle = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _lbTriggerPriceValue = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _lbTriggerPriceTitle.textAlignment = NSTextAlignmentRight;
        _lbTriggerPriceValue.textAlignment = NSTextAlignmentRight;
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
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat fWidth = self.bounds.size.width;
    
    //  header
    CGFloat fOffsetY = 0.0f;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fOffsetX_2x = fOffsetX * 2;
    CGFloat fLineHeight = 28.0f;
    CGFloat fContentWidth = fWidth - fOffsetX_2x;
    
    //  准备数据
    id callorder = [_item objectForKey:@"callorder"];
    assert(callorder);
    BOOL will_be_settlement = [[_item objectForKey:@"will_be_settlement"] boolValue];
    id n_collateral = [_item objectForKey:@"n_collateral"];
    id n_debt = [_item objectForKey:@"n_debt"];
    
    id call_price = [callorder objectForKey:@"call_price"];
    assert(call_price);
    id coll_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[call_price objectForKey:@"base"][@"asset_id"]];
    id debt_asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[call_price objectForKey:@"quote"][@"asset_id"]];
    assert(coll_asset);
    assert(debt_asset);
    
    //  第一行
    NSString* borrower_str = nil;
    id borrower_id = [callorder objectForKey:@"borrower"];
    id borrower_account = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:borrower_id];
    if (borrower_account){
        borrower_str = [borrower_account objectForKey:@"name"];
    }else{
        borrower_str = borrower_id;
    }
    _lbUsername.text = borrower_str;
    _lbUsername.frame = CGRectMake(fOffsetX, fOffsetY, fWidth - fOffsetX_2x, fLineHeight);
    
    //  标签：将被清算 TODO: 其他各种标签：强平中、接近平仓、安全
    if (will_be_settlement) {
        _lbWillSettlementFlag.text = NSLocalizedString(@"kVcRankFlagWillSettlement", @"将被清算");
        _lbWillSettlementFlag.hidden = NO;
    } else {
        _lbWillSettlementFlag.hidden = YES;
    }
    if (!_lbWillSettlementFlag.hidden){
        CGSize size1 = [self auxSizeWithText:_lbUsername.text font:_lbUsername.font maxsize:CGSizeMake(fWidth, 9999)];
        CGSize size2 = [self auxSizeWithText:_lbWillSettlementFlag.text font:_lbWillSettlementFlag.font maxsize:CGSizeMake(fWidth, 9999)];
        _lbWillSettlementFlag.frame = CGRectMake(fOffsetX + size1.width + 4, fOffsetY + (fLineHeight - size2.height - 2)/2, size2.width + 8, size2.height + 2);
    }
    
    //  第一行 右边
    NSString* rate_string;
    if (self.feedPriceInfo) {
        NSDecimalNumberHandler* handler = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp
                                                                                                 scale:2
                                                                                      raiseOnExactness:NO
                                                                                       raiseOnOverflow:NO
                                                                                      raiseOnUnderflow:NO
                                                                                   raiseOnDivideByZero:NO];
        id n_percent = [[[[NSDecimalNumber decimalNumberWithMantissa:100 exponent:0 isNegative:NO] decimalNumberByMultiplyingBy:self.feedPriceInfo] decimalNumberByMultiplyingBy:n_collateral] decimalNumberByDividingBy:n_debt withBehavior:handler];
        
        rate_string = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:n_percent usesGroupingSeparator:NO]];
    } else {
        rate_string = @"--%";
    }
    
    _lbRate.text = rate_string;
    _lbRate.textColor = theme.tintColor;
    _lbRate.frame = CGRectMake(fOffsetX, fOffsetY, fWidth - fOffsetX_2x, fLineHeight);
    fOffsetY += fLineHeight;
    
    //  第二行 标题
    _lbAssetCollateralTitle.text = [NSString stringWithFormat:@"%@(%@) ",
                                    NSLocalizedString(@"kVcRankColl", @"抵押物"), coll_asset[@"symbol"]];
    _lbAssetDebtTitle.text = [NSString stringWithFormat:@"%@(%@) ",
                              NSLocalizedString(@"kVcRankDebt", @"借款金额"), debt_asset[@"symbol"]];
    _lbTriggerPriceTitle.text = NSLocalizedString(@"kVcRankCallPrice", @"强平触发价");
    
    _lbAssetCollateralTitle.textColor = theme.textColorGray;
    _lbAssetDebtTitle.textColor = theme.textColorGray;
    _lbTriggerPriceTitle.textColor = theme.textColorGray;
    
    _lbAssetCollateralTitle.frame = CGRectMake(fOffsetX, fOffsetY, fContentWidth, fLineHeight);
    _lbAssetDebtTitle.frame = CGRectMake(fOffsetX, fOffsetY, fContentWidth, fLineHeight);
    _lbTriggerPriceTitle.frame = CGRectMake(fOffsetX, fOffsetY, fContentWidth, fLineHeight);
    fOffsetY += fLineHeight;
    
    //  第三行 值
    _lbAssetCollateralValue.text = [OrgUtils formatFloatValue:n_collateral];
    _lbAssetCollateralValue.textColor = theme.textColorNormal;
    
    _lbAssetDebtValue.text = [OrgUtils formatFloatValue:n_debt];
    _lbAssetDebtValue.textColor = theme.textColorNormal;
    
    NSDecimalNumber* n_settlement_trigger_price = [OrgUtils calcSettlementTriggerPrice:callorder[@"debt"]
                                                                            collateral:callorder[@"collateral"]
                                                                        debt_precision:self.debt_precision
                                                                  collateral_precision:self.collateral_precision
                                                                                 n_mcr:self.mcr
                                                                               reverse:NO
                                                                          ceil_handler:nil
                                                                  set_divide_precision:YES];
    
    _lbTriggerPriceValue.text = [OrgUtils formatFloatValue:n_settlement_trigger_price
                                     usesGroupingSeparator:NO
                                     minimumFractionDigits:self.debt_precision];
    _lbTriggerPriceValue.textColor = theme.textColorNormal;
    
    _lbAssetCollateralValue.frame = CGRectMake(fOffsetX, fOffsetY, fContentWidth, fLineHeight);
    _lbAssetDebtValue.frame = CGRectMake(fOffsetX, fOffsetY, fContentWidth, fLineHeight);
    _lbTriggerPriceValue.frame = CGRectMake(fOffsetX, fOffsetY, fContentWidth, fLineHeight);
    fOffsetY += fLineHeight;
}

@end
