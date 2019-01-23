//
//  ViewAssetInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewAssetInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "SettingManager.h"

@interface ViewAssetInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbTitle;
    UILabel*        _lbAssetType;
    UILabel*        _lbTitleValue;
    
    UILabel*        _lbAssetFree;
    UILabel*        _lbAssetFreeFrozen;
    
    NSMutableArray* _lbAssetOptional;       //  可选的资产信息（抵押、负债、强平 三个）

    UIButton*       _btnTransfer;
    UIButton*       _btnTrade;
}

@end

@implementation ViewAssetInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbTitle = nil;
    _lbAssetType = nil;
    _lbTitleValue = nil;
    
    _lbAssetFree = nil;
    _lbAssetFreeFrozen = nil;
    
    if (_lbAssetOptional){
        [_lbAssetOptional removeAllObjects];
        _lbAssetOptional = nil;
    }
    
    _btnTransfer = nil;
    _btnTrade = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _lbTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTitle.textAlignment = NSTextAlignmentLeft;
        _lbTitle.numberOfLines = 1;
        _lbTitle.backgroundColor = [UIColor clearColor];
        _lbTitle.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbTitle.font = [UIFont systemFontOfSize:16];
        [self addSubview:_lbTitle];
        
        _lbAssetType = [[UILabel alloc] initWithFrame:CGRectZero];
        UIColor* backColor = [ThemeManager sharedThemeManager].textColorHighlight;
        _lbAssetType.textAlignment = NSTextAlignmentCenter;
        _lbAssetType.backgroundColor = [UIColor clearColor];
        _lbAssetType.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbAssetType.font = [UIFont boldSystemFontOfSize:12];
        _lbAssetType.layer.borderWidth = 1;
        _lbAssetType.layer.cornerRadius = 2;
        _lbAssetType.layer.masksToBounds = YES;
        _lbAssetType.layer.borderColor = backColor.CGColor;
        _lbAssetType.layer.backgroundColor = backColor.CGColor;
        _lbAssetType.hidden = YES;
        [self addSubview:_lbAssetType];
        
        _lbTitleValue = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTitleValue.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTitleValue.textAlignment = NSTextAlignmentRight;
        _lbTitleValue.numberOfLines = 1;
        _lbTitleValue.backgroundColor = [UIColor clearColor];
        _lbTitleValue.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbTitleValue.font = [UIFont systemFontOfSize:16];
        [self addSubview:_lbTitleValue];
        
        _lbAssetFree = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAssetFree.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAssetFree.numberOfLines = 1;
        _lbAssetFree.backgroundColor = [UIColor clearColor];
        _lbAssetFree.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbAssetFree.font = [UIFont systemFontOfSize:14];
        _lbAssetFree.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbAssetFree];
        
        _lbAssetFreeFrozen = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAssetFreeFrozen.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAssetFreeFrozen.numberOfLines = 1;
        _lbAssetFreeFrozen.backgroundColor = [UIColor clearColor];
        _lbAssetFreeFrozen.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbAssetFreeFrozen.font = [UIFont systemFontOfSize:14];
        _lbAssetFreeFrozen.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbAssetFreeFrozen];
        
        //  REMARK: 数量3有需要可调整
        _lbAssetOptional = [NSMutableArray array];
        for (int i = 0; i < 3; ++i) {
            UILabel* lbOptional = [[UILabel alloc] initWithFrame:CGRectZero];
            lbOptional.lineBreakMode = NSLineBreakByTruncatingTail;
            lbOptional.numberOfLines = 1;
            lbOptional.backgroundColor = [UIColor clearColor];
            lbOptional.textColor = [ThemeManager sharedThemeManager].textColorNormal;
            lbOptional.font = [UIFont systemFontOfSize:14];
            lbOptional.adjustsFontSizeToFitWidth = YES;
            lbOptional.hidden = YES;
            [self addSubview:lbOptional];
            [_lbAssetOptional addObject:lbOptional];
        }
        
        if (vc)
        {
            _btnTransfer = [UIButton buttonWithType:UIButtonTypeCustom];
            _btnTransfer.backgroundColor = [UIColor clearColor];
            
            [_btnTransfer setTitle:NSLocalizedString(@"kVcAssetBtnTransfer", @"转账") forState:UIControlStateNormal];
            [_btnTransfer setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
            _btnTransfer.titleLabel.font = [UIFont systemFontOfSize:16.0];
            _btnTransfer.userInteractionEnabled = YES;
            [_btnTransfer addTarget:vc action:@selector(onButtonClicked_Transfer:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_btnTransfer];
            
            _btnTrade = [UIButton buttonWithType:UIButtonTypeCustom];
            _btnTrade.backgroundColor = [UIColor clearColor];
            [_btnTrade setTitle:NSLocalizedString(@"kVcAssetBtnTrade", @"交易") forState:UIControlStateNormal];
            [_btnTrade setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
            _btnTrade.titleLabel.font = [UIFont systemFontOfSize:16.0];
            _btnTrade.userInteractionEnabled = YES;
            [_btnTrade addTarget:vc action:@selector(onButtonClicked_Trade:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_btnTrade];
        }
        else
        {
            _btnTransfer = nil;
            _btnTrade = nil;
        }
    }
    return self;
}

- (void)setTagData:(NSInteger)tag
{
    if (_btnTrade && _btnTransfer){
        _btnTrade.tag = tag;
        _btnTransfer.tag = tag;
    }
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
    
    //{
    //    balance = 0;
    //    "limit_order_value" = 25998000;
    //    "call_order_value" = 10020;       - 可选
    //    "debt_value" = 114388393621;      - 可选
    //    id = "1.3.113";
    //    "is_smart" = 1;
    //    kPriority = 100;
    //    name = CNY;
    //    precision = 4;
    //}
    
    CGFloat xOffset = self.layoutMargins.left;
    CGFloat fWidth = self.bounds.size.width;
    CGFloat fCellWidth = fWidth - xOffset * 2;
    
    //  header
    CGFloat fOffsetY = 0.0f;
    CGFloat fLineHeight = 28;
    
//    [asset setObject:@(estimate_value) forKey:@"estimate_value_real"];
//    [asset setObject:[OrgUtils formatFloatValue:estimate_value precision:display_precision] forKey:@"estimate_value"];
//    
    //  第一行
    _lbTitle.text = [_item objectForKey:@"name"];
    _lbTitle.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    id estimate_value = [_item objectForKey:@"estimate_value"];
    if (estimate_value){
        _lbTitleValue.text = [NSString stringWithFormat:@"≈ %@%@", estimate_value, [[SettingManager sharedSettingManager] getEstimateAssetSymbol]];
        if ([[_item objectForKey:@"estimate_value_real"] doubleValue] >= 0){
            _lbTitleValue.textColor = [ThemeManager sharedThemeManager].textColorMain;
        }else{
            _lbTitleValue.textColor = [ThemeManager sharedThemeManager].tintColor;
        }
    }else{
        _lbTitleValue.text = NSLocalizedString(@"kVcAssetTipsEstimating", @"估算中...");
        _lbTitleValue.textColor = [ThemeManager sharedThemeManager].textColorMain;
    }
    _lbTitleValue.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    
    //  Core、Smart资产标签
    if ([[_item objectForKey:@"is_core"] boolValue]){
        _lbAssetType.text = @"Core";    //  TODO:fowallet 是否需要多语言 核心、智能资产
        _lbAssetType.hidden = NO;
    }else if ([[_item objectForKey:@"is_smart"] boolValue]){
        _lbAssetType.text = @"Smart";   //  TODO:fowallet 是否需要多语言 核心、智能资产
        _lbAssetType.hidden = NO;
    }else{
        _lbAssetType.hidden = YES;
    }
    if (!_lbAssetType.hidden){
        CGSize size1 = [self auxSizeWithText:_lbTitle.text font:_lbTitle.font maxsize:CGSizeMake(fWidth, 9999)];
        CGSize size2 = [self auxSizeWithText:_lbAssetType.text font:_lbAssetType.font maxsize:CGSizeMake(fWidth, 9999)];
        _lbAssetType.frame = CGRectMake(xOffset + size1.width + 4, fOffsetY + (fLineHeight - size2.height - 2)/2, size2.width + 8, size2.height + 2);
    }
    
    fOffsetY += fLineHeight;
    NSInteger precision = [[_item objectForKey:@"precision"] integerValue];
    
    //  第二行     可用资产    冻结资产
    _lbAssetFree.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcAssetAvailable", @"可用"), [OrgUtils formatAssetString:[_item objectForKey:@"balance"] precision:precision]];
    _lbAssetFree.frame = CGRectMake(xOffset, fOffsetY, fCellWidth / 2, fLineHeight);
    
    _lbAssetFreeFrozen.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcAssetOnOrder", @"挂单"),
                               [OrgUtils formatAssetString:[_item objectForKey:@"limit_order_value"] precision:precision]];
    _lbAssetFreeFrozen.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    _lbAssetFreeFrozen.textAlignment = NSTextAlignmentRight;
//
    fOffsetY += fLineHeight;
    
    //  第三行     抵押资产    负债资产
    for (UILabel* label in _lbAssetOptional) {
        label.hidden = YES;
    }
    NSInteger showIndex = 0;
    for (NSString* key in @[@"call_order_value", @"debt_value", @"trigger_price"]) {
        id value = [_item objectForKey:key];
        if (value){
            UILabel* label = [_lbAssetOptional objectAtIndex:showIndex];
            label.hidden = NO;
            if ([key isEqualToString:@"call_order_value"]){
                label.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcAssetColl", @"抵押"), [OrgUtils formatAssetString:value precision:precision]];
            }else if ([key isEqualToString:@"debt_value"]){
                label.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcAssetDebt", @"负债"), [OrgUtils formatAssetString:value precision:precision]];
            }else{
                label.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcAssetCallPrice", @"强制平仓价"), value];
            }
            if ((showIndex % 2) == 1){
                label.textAlignment = NSTextAlignmentRight;
                label.frame = CGRectMake(xOffset , fOffsetY + fLineHeight * (showIndex / 2), fCellWidth, fLineHeight);
            }else{
                label.textAlignment = NSTextAlignmentLeft;
                label.frame = CGRectMake(xOffset , fOffsetY + fLineHeight * (showIndex / 2), fCellWidth, fLineHeight);
            }
            ++showIndex;
        }
    }
    fOffsetY += ((showIndex + 1) / 2) * fLineHeight;
    
    //  第四行 action
    if (_btnTrade && _btnTransfer){
        _btnTransfer.frame = CGRectMake(xOffset, fOffsetY, fCellWidth / 2, fLineHeight);
        _btnTrade.frame = CGRectMake(xOffset + fCellWidth / 2, fOffsetY, fCellWidth / 2, fLineHeight);
    }
}

@end
