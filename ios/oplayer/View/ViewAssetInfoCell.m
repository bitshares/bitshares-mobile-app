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
#import "bts_chain_config.h"
#import "Extension.h"

@interface ViewAssetInfoCell()
{
    __weak UIViewController*  _owner;
    NSDictionary*   _item;
    
    UILabel*        _lbTitle;
    UILabel*        _lbAssetType;
    UILabel*        _lbTitleValue;
    
    UILabel*        _lbAssetFree;
    UILabel*        _lbAssetFreeFrozen;
    
    NSMutableArray* _lbAssetOptional;       //  可选的资产信息（抵押、负债、强平 三个）
    
    NSMutableArray* _btnArray;
}

@end

@implementation ViewAssetInfoCell

@synthesize item=_item;
@synthesize row;

- (void)dealloc
{
    _owner = nil;
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
    
    if (_btnArray) {
        [_btnArray removeAllObjects];
        _btnArray = nil;
    }
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
        
        //  保存引用
        _owner = vc;
        
        if (vc)
        {
            _btnArray = [NSMutableArray array];
            for (NSInteger i = 0; i < 4; ++i) {
                UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
                btn.backgroundColor = [UIColor clearColor];
                [btn setTitle:@"placeholder" forState:UIControlStateNormal];
                [btn setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
                btn.titleLabel.font = [UIFont systemFontOfSize:16.0];
                btn.userInteractionEnabled = YES;
                [btn addTarget:self action:@selector(onActionButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
                [self addSubview:btn];
                [_btnArray addObject:btn];
            }
        }
        else
        {
            _btnArray = nil;
        }
    }
    return self;
}

- (void)onActionButtonClicked:(UIButton*)button
{
    if (_owner && [_owner respondsToSelector:@selector(onActionButtonClicked:row:)]){
        [_owner performSelector:@selector(onActionButtonClicked:row:) withObject:button withObject:@(self.row)];
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
    BOOL bIsCore = [[_item objectForKey:@"is_core"] boolValue];
    BOOL bIsPredictionMarket = [[_item objectForKey:@"is_prediction_market"] boolValue];
    BOOL bIsSmart = [[_item objectForKey:@"is_smart"] boolValue];
    if (bIsCore){
        _lbAssetType.text = @"Core";    //  TODO:fowallet 是否需要多语言 核心、智能资产
        _lbAssetType.hidden = NO;
    } else if (bIsPredictionMarket) {
        _lbAssetType.text = @"Prediction";   //  TODO:fowallet 是否需要多语言 核心、智能资产
        _lbAssetType.hidden = NO;
    }else if (bIsSmart){
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
    if (_btnArray) {
        //  TODO:4.0 后续可扩展【更多】按钮
        NSMutableArray* all_actions = [NSMutableArray arrayWithObjects:@(ebaok_transfer), @(ebaok_trade), nil];
        if (bIsSmart || bIsPredictionMarket) {
            [all_actions addObject:@(ebaok_settle)];
        } else {
            [all_actions addObject:@(ebaok_reserve)];
        }
        //  锁仓投票（仅针对BTS）
        if (bIsCore) {
            [all_actions addObject:@(ebaok_stake_vote)];
        }
        NSArray* final_actions;
//        //  按钮太多，添加【更多】按钮。
//        if ([all_actions count] > [_btnArray count]) {
//            //  TODO:6.2 暂时不支持更多按钮，目前最多4个。
//            NSMutableArray* tmp = [NSMutableArray array];
//            [tmp addObjectsFromArray:[all_actions subarrayWithRange:NSMakeRange(0, [_btnArray count] - 1)]];
//            [tmp addObject:@(ebaok_more)];
//            final_actions = [tmp copy];
//        } else {
            final_actions = [all_actions copy];
//        }
        //  默认全部不可见
        for (UIButton* btn in _btnArray) {
            btn.hidden = YES;
        }
        NSInteger nTotal = [final_actions count];
        CGFloat fButtonWidth = fCellWidth / nTotal;
        [final_actions ruby_each_with_index:^(id src, NSInteger idx) {
            NSInteger kActionType = [src integerValue];
            UIButton* btn = [_btnArray objectAtIndex:idx];
            switch (kActionType) {
                case ebaok_transfer:
                    [btn updateTitleWithoutAnimation:NSLocalizedString(@"kVcAssetBtnTransfer", @"转账")];
                    break;
                case ebaok_trade:
                    [btn updateTitleWithoutAnimation:NSLocalizedString(@"kVcAssetBtnTrade", @"交易")];
                    break;
                case ebaok_settle:
                    [btn updateTitleWithoutAnimation:NSLocalizedString(@"kVcAssetBtnSettle", @"清算")];
                    break;
                case ebaok_reserve:
                    [btn updateTitleWithoutAnimation:NSLocalizedString(@"kVcAssetBtnReserve", @"销毁")];
                    break;
                case ebaok_stake_vote:
                    [btn updateTitleWithoutAnimation:NSLocalizedString(@"kVcAssetBtnStakeVote", @"锁仓")];
                    break;
                case ebaok_more:
                    [btn updateTitleWithoutAnimation:NSLocalizedString(@"kVcAssetBtnMore", @"更多")];
                    break;
                default:
                    assert(false);
                    break;
            }
            btn.tag = kActionType;
            btn.frame = CGRectMake(xOffset + fButtonWidth * idx, fOffsetY, fButtonWidth, fLineHeight);
            btn.hidden = NO;
        }];
    }
}

@end
