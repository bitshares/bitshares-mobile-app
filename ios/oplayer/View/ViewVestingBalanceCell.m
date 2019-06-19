//
//  ViewVestingBalanceCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewVestingBalanceCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"
#import "VCVestingBalance.h"

@interface ViewVestingBalanceCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbObjectID;            //  ID
    
    UILabel*        _lbTotalTitle;          //  总金额
    UILabel*        _lbTotalValue;          //  总金额
    
    UILabel*        _lbAmountTitle;         //  已解冻数量
    UILabel*        _lbAmountValue;         //  已解冻数量
    
    UILabel*        _lbVestingPeriodTitle;  //  解冻周期
    UILabel*        _lbVestingPeriodValue;  //  解冻周期
    
    UIButton*       _btnWithdraw;           //  提取按钮
}

@end

@implementation ViewVestingBalanceCell

@synthesize item=_item;
@synthesize row;

- (void)dealloc
{
    _item = nil;
    
    _lbObjectID = nil;
    _lbTotalTitle = nil;
    _lbTotalValue = nil;
    _lbAmountTitle = nil;
    _lbAmountValue = nil;
    _lbVestingPeriodTitle = nil;
    _lbVestingPeriodValue = nil;
    
    _btnWithdraw = nil;
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
        _lbObjectID = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbObjectID.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbObjectID.textAlignment = NSTextAlignmentLeft;
        _lbObjectID.numberOfLines = 1;
        _lbObjectID.backgroundColor = [UIColor clearColor];
        _lbObjectID.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_lbObjectID];
     
        if (vc){
            _btnWithdraw = [UIButton buttonWithType:UIButtonTypeCustom];
            _btnWithdraw.backgroundColor = [UIColor clearColor];
            [_btnWithdraw setTitle:NSLocalizedString(@"kVestingCellBtnWithdrawal", @"提取") forState:UIControlStateNormal];
            [_btnWithdraw setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
            _btnWithdraw.titleLabel.font = [UIFont systemFontOfSize:16.0];
            _btnWithdraw.userInteractionEnabled = YES;
            _btnWithdraw.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
            [_btnWithdraw addTarget:vc action:@selector(onButtonClicked_Withdraw:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_btnWithdraw];
        }else{
            _btnWithdraw = nil;
        }
        
        //  第二行
        _lbTotalTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTotalTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTotalTitle.textAlignment = NSTextAlignmentLeft;
        _lbTotalTitle.numberOfLines = 1;
        _lbTotalTitle.backgroundColor = [UIColor clearColor];
        _lbTotalTitle.font = [UIFont systemFontOfSize:13];
        _lbTotalTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbTotalTitle];
        
        _lbAmountTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAmountTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAmountTitle.textAlignment = NSTextAlignmentCenter;
        _lbAmountTitle.numberOfLines = 1;
        _lbAmountTitle.backgroundColor = [UIColor clearColor];
        _lbAmountTitle.font = [UIFont systemFontOfSize:13];
        _lbAmountTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbAmountTitle];
        
        _lbVestingPeriodTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbVestingPeriodTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbVestingPeriodTitle.textAlignment = NSTextAlignmentRight;
        _lbVestingPeriodTitle.numberOfLines = 1;
        _lbVestingPeriodTitle.backgroundColor = [UIColor clearColor];
        _lbVestingPeriodTitle.font = [UIFont systemFontOfSize:13];
        _lbVestingPeriodTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbVestingPeriodTitle];
        
        //  第三行
        _lbTotalValue = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTotalValue.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTotalValue.textAlignment = NSTextAlignmentLeft;
        _lbTotalValue.numberOfLines = 1;
        _lbTotalValue.backgroundColor = [UIColor clearColor];
        _lbTotalValue.font = [UIFont systemFontOfSize:14];
        _lbTotalValue.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbTotalValue];
        
        _lbAmountValue = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAmountValue.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAmountValue.textAlignment = NSTextAlignmentCenter;
        _lbAmountValue.numberOfLines = 1;
        _lbAmountValue.backgroundColor = [UIColor clearColor];
        _lbAmountValue.font = [UIFont systemFontOfSize:14];
        _lbAmountValue.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbAmountValue];
        
        _lbVestingPeriodValue = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbVestingPeriodValue.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbVestingPeriodValue.textAlignment = NSTextAlignmentRight;
        _lbVestingPeriodValue.numberOfLines = 1;
        _lbVestingPeriodValue.backgroundColor = [UIColor clearColor];
        _lbVestingPeriodValue.font = [UIFont systemFontOfSize:14];
        _lbVestingPeriodValue.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbVestingPeriodValue];
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
    if (_btnWithdraw){
        _btnWithdraw.tag = tag;
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
    
    //  第一行 ID
    _lbObjectID.text = [NSString stringWithFormat:@"%@. %@", @(self.row + 1), _item[@"kName"]];
    _lbObjectID.textColor = theme.textColorMain;
    
    if (_btnWithdraw){
        _lbObjectID.frame = CGRectMake(xOffset, yOffset, fWidth - 84, 28);
        _btnWithdraw.frame = CGRectMake(self.bounds.size.width - xOffset - 120, yOffset, 120, 28);
    }else{
        _lbObjectID.frame = CGRectMake(xOffset, yOffset, fWidth, 28);
    }
    
    yOffset += 28;
    
    //  第二行
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id balance = [_item objectForKey:@"balance"];
    id balance_asset = [chainMgr getChainObjectByID:balance[@"asset_id"]];
    _lbTotalTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kVestingCellTotal", @"总数量"), balance_asset[@"symbol"]];
    _lbAmountTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kVestingCellVesting", @"已解冻数量"), balance_asset[@"symbol"]];
    _lbVestingPeriodTitle.text = NSLocalizedString(@"kVestingCellPeriod", @"解冻周期");
    _lbTotalTitle.textColor = theme.textColorGray;
    _lbAmountTitle.textColor = theme.textColorGray;
    _lbVestingPeriodTitle.textColor = theme.textColorGray;
    
    _lbTotalTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbAmountTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbVestingPeriodTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    
    yOffset += 24;
    
    //  第三行 数量和价格
    unsigned long long withdraw_available = [VCVestingBalance calcVestingBalanceAmount:_item];
    
    NSString* vestingPeriodValue = @"--";
    switch ([[[_item objectForKey:@"policy"] objectAtIndex:0] integerValue]) {
        case ebvp_cdd_vesting_policy:
        {
            //  REMARK：解冻周期最低1秒
            id policy_data = [[_item objectForKey:@"policy"] objectAtIndex:1];
            assert(policy_data);
            NSUInteger vesting_seconds = MAX([[policy_data objectForKey:@"vesting_seconds"] unsignedIntegerValue], 1L);
            vestingPeriodValue = [OrgUtils fmtVestingPeriodDateString:vesting_seconds];
        }
            break;
        case ebvp_instant_vesting_policy:
        {
            vestingPeriodValue = NSLocalizedString(@"kVestingCellPeriodInstant", @"立即解冻");
        }
            break;
        default:
            //  TODO:ebvp_linear_vesting_policy
            assert(false);
            break;
    }
    
    _lbTotalValue.text = [NSString stringWithFormat:@"%@", [OrgUtils formatAssetString:balance[@"amount"] asset:balance_asset]];
    _lbTotalValue.textColor = theme.textColorNormal;
    
    _lbAmountValue.text = [NSString stringWithFormat:@"%@", [OrgUtils formatAssetString:@(withdraw_available) asset:balance_asset]];
    _lbAmountValue.textColor = theme.textColorNormal;
    
    _lbVestingPeriodValue.text = vestingPeriodValue;
    _lbVestingPeriodValue.textColor = theme.textColorNormal;
    
    _lbTotalValue.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbAmountValue.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbVestingPeriodValue.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
}

@end
