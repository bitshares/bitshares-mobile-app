//
//  ViewBlindBalanceCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewBlindBalanceCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"
#import "Extension.h"

@interface ViewBlindBalanceCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbObjectID;            //  ID
    
    UILabel*        _to_title;
    UILabel*        _to_value;
    UILabel*        _amount_title;
    UILabel*        _amount_value;
}

@end

@implementation ViewBlindBalanceCell

@synthesize item=_item;
@synthesize row;

- (void)dealloc
{
    _item = nil;
    
    _lbObjectID = nil;
    
    _to_title = nil;
    _to_value = nil;
    _amount_title = nil;
    _amount_value = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        //  第一行
        _lbObjectID = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:16] superview:self];
        _lbObjectID.textAlignment = NSTextAlignmentLeft;
        
        _to_title = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _to_value = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _to_title.textAlignment = NSTextAlignmentLeft;
        _to_value.textAlignment = NSTextAlignmentLeft;
        
        _amount_title = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _amount_value = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _amount_title.textAlignment = NSTextAlignmentRight;
        _amount_value.textAlignment = NSTextAlignmentRight;
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
    //    if (_btnWithdraw){
    //        _btnWithdraw.tag = tag;
    //    }
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
    
    CGFloat xOffset = self.layoutMargins.left;
    if (self.editing) {
        xOffset += 38;
    }
    CGFloat yOffset = 4.0f;
    CGFloat fWidth = self.bounds.size.width - self.layoutMargins.left - xOffset;

    //  获取显示数据
    id decrypted_memo = [_item objectForKey:@"decrypted_memo"];
    assert(decrypted_memo);
    id amount = [decrypted_memo objectForKey:@"amount"];
    uint32_t check = [[decrypted_memo objectForKey:@"check"] unsignedIntValue];
    
    //  第一行 ID
    _lbObjectID.text = [NSString stringWithFormat:@"%@. 收据 #%@", @(self.row + 1),
                        [[[NSData dataWithBytes:&check length:sizeof(check)] hex_encode] uppercaseString]];
    _lbObjectID.textColor = self.editing && !self.selected ? theme.textColorNormal : theme.textColorMain;
    _lbObjectID.frame = CGRectMake(xOffset, yOffset, fWidth, 28.0f);
    
    yOffset += 28.0f;
    
    id asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[amount objectForKey:@"asset_id"]];
    assert(asset);
    id n_amount = [NSDecimalNumber decimalNumberWithMantissa:[[amount objectForKey:@"amount"] unsignedLongLongValue]
                                                    exponent:-[[asset objectForKey:@"precision"] integerValue]
                                                  isNegative:NO];
    
    _to_title.text = @"地址";
    _to_value.text = [_item objectForKey:@"real_to_key"];
    _amount_title.text = @"金额";
    _amount_value.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_amount usesGroupingSeparator:NO], asset[@"symbol"]];
    
    _to_title.textColor = theme.textColorGray;
    _to_value.textColor = theme.textColorNormal;
    _amount_title.textColor = theme.textColorGray;
    _amount_value.textColor = theme.textColorNormal;
    
    //    yOffset += 28;
    //
    //    //  第二行
    //    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    //    id balance = [_item objectForKey:@"balance"];
    //    id balance_asset = [chainMgr getChainObjectByID:balance[@"asset_id"]];
    //    _lbTotalTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kVestingCellTotal", @"总数量"), balance_asset[@"symbol"]];
    //    _lbAmountTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kVestingCellVesting", @"已解冻数量"), balance_asset[@"symbol"]];
    //    _lbVestingPeriodTitle.text = NSLocalizedString(@"kVestingCellPeriod", @"解冻周期");
    //    _lbTotalTitle.textColor = theme.textColorGray;
    //    _lbAmountTitle.textColor = theme.textColorGray;
    //    _lbVestingPeriodTitle.textColor = theme.textColorGray;
    //
    //    _lbTotalTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    //    _lbAmountTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    //    _lbVestingPeriodTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    //
    //    yOffset += 24;
    //
    //    //  第三行 数量和价格
    //    unsigned long long withdraw_available = [VCVestingBalance calcVestingBalanceAmount:_item];
    //
    //    NSString* vestingPeriodValue = @"--";
    //    switch ([[[_item objectForKey:@"policy"] objectAtIndex:0] integerValue]) {
    //        case ebvp_cdd_vesting_policy:
    //        {
    //            //  REMARK：解冻周期最低1秒
    //            id policy_data = [[_item objectForKey:@"policy"] objectAtIndex:1];
    //            assert(policy_data);
    //            NSUInteger vesting_seconds = MAX([[policy_data objectForKey:@"vesting_seconds"] unsignedIntegerValue], 1L);
    //            vestingPeriodValue = [OrgUtils fmtVestingPeriodDateString:vesting_seconds];
    //        }
    //            break;
    //        case ebvp_instant_vesting_policy:
    //        {
    //            vestingPeriodValue = NSLocalizedString(@"kVestingCellPeriodInstant", @"立即解冻");
    //        }
    //            break;
    //        default:
    //            //  TODO:ebvp_linear_vesting_policy
    //            assert(false);
    //            break;
    //    }
    //
    //    _lbTotalValue.text = [NSString stringWithFormat:@"%@", [OrgUtils formatAssetString:balance[@"amount"] asset:balance_asset]];
    //    _lbTotalValue.textColor = theme.textColorNormal;
    //
    //    _lbAmountValue.text = [NSString stringWithFormat:@"%@", [OrgUtils formatAssetString:@(withdraw_available) asset:balance_asset]];
    //    _lbAmountValue.textColor = theme.textColorNormal;
    //
    //    _lbVestingPeriodValue.text = vestingPeriodValue;
    //    _lbVestingPeriodValue.textColor = theme.textColorNormal;
    //
    _to_title.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _amount_title.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    
    yOffset += 24.0f;
    
    _to_value.frame = CGRectMake(xOffset, yOffset, fWidth * 0.6, 24);
    _amount_value.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    //    _lbAmountValue.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    //    _lbVestingPeriodValue.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
}

@end
