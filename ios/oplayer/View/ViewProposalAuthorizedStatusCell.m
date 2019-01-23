//
//  ViewProposalAuthorizedStatusCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewProposalAuthorizedStatusCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewProposalAuthorizedStatusCell()
{
    NSDictionary*   _item;
    
    NSMutableArray* _lbAuthorizeTitleList;
    NSMutableArray* _lbAuthorizeStatusList;
}

@end

@implementation ViewProposalAuthorizedStatusCell

@synthesize dynamicInfos;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbAuthorizeTitleList = nil;
    _lbAuthorizeStatusList = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _lbAuthorizeTitleList = [NSMutableArray array];
        _lbAuthorizeStatusList = [NSMutableArray array];
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
    
    CGFloat xOffset = self.layoutMargins.left;
    CGFloat yOffset = 2;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fLineHeight = 22;
    
    //  获取数据
    id kProcessedData = [_item objectForKey:@"kProcessedData"];
    assert(kProcessedData);
    id needAuthorizeHash = [kProcessedData objectForKey:@"needAuthorizeHash"];
    id availableHash = [kProcessedData objectForKey:@"availableHash"];
    assert(needAuthorizeHash && availableHash);
    NSInteger passThreshold = [[kProcessedData objectForKey:@"passThreshold"] integerValue];
    assert(passThreshold > 0);
    
    NSInteger diff = (NSInteger)[needAuthorizeHash count] - (NSInteger)[_lbAuthorizeTitleList count];
    for (NSInteger i = 0; i < diff; ++i) {
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.numberOfLines = 1;
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:label];
        [_lbAuthorizeTitleList addObject:label];
        
        UILabel* status = [[UILabel alloc] initWithFrame:CGRectZero];
        status.lineBreakMode = NSLineBreakByTruncatingTail;
        status.numberOfLines = 1;
        status.textAlignment = NSTextAlignmentRight;
        status.backgroundColor = [UIColor clearColor];
        status.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:status];
        [_lbAuthorizeStatusList addObject:status];
    }
    for (UILabel* label in _lbAuthorizeTitleList) {
        label.hidden = YES;
    }
    for (UILabel* label in _lbAuthorizeStatusList) {
        label.hidden = YES;
    }
    
    //  动态信息：添加or移除授权时动态显示
    NSString* dynamicKey = nil;
    if (self.dynamicInfos){
        dynamicKey = [self.dynamicInfos objectForKey:@"key"];
    }
    
    NSInteger labelIndex = 0;
    for (id key in needAuthorizeHash) {
        id item = [needAuthorizeHash objectForKey:key];
        assert([[item objectForKey:@"key"] isEqualToString:key]);
        
        //  计算该授权实体占比权重。
        NSInteger threshold = [[item objectForKey:@"threshold"] integerValue];
        CGFloat weight_percent = threshold * 100.0f / (CGFloat)passThreshold;
        if (threshold < passThreshold){
            weight_percent = fminf(weight_percent, 99.0f);
        }
        if (threshold > 0){
            weight_percent = fmaxf(weight_percent, 1.0f);
        }
        
        //  entity
        UILabel* label = [_lbAuthorizeTitleList objectAtIndex:labelIndex];
        if (dynamicKey && [dynamicKey isEqualToString:key]){
            if ([[self.dynamicInfos objectForKey:@"remove"] boolValue]){
                label.text = [NSString stringWithFormat:@"* %2d%% %@", (int)weight_percent, [item objectForKey:@"name"]];
                label.textColor = theme.sellColor;
            }else{
                label.text = [NSString stringWithFormat:@"* %2d%% %@", (int)weight_percent, [item objectForKey:@"name"]];
                label.textColor = theme.buyColor;
            }
        }else{
            if ([availableHash objectForKey:key]){
                label.text = [NSString stringWithFormat:@"* %2d%% %@", (int)weight_percent, [item objectForKey:@"name"]];
                label.textColor = theme.buyColor;
            }else{
                label.text = [NSString stringWithFormat:@"* %2d%% %@", (int)weight_percent, [item objectForKey:@"name"]];
                label.textColor = theme.textColorNormal;
            }
        }
        label.frame = CGRectMake(xOffset, yOffset, fWidth * 0.75f, fLineHeight);
        label.hidden = NO;
        
        //  status
        UILabel* status = [_lbAuthorizeStatusList objectAtIndex:labelIndex++];
        if (dynamicKey && [dynamicKey isEqualToString:key]){
            if ([[self.dynamicInfos objectForKey:@"remove"] boolValue]){
                status.text = NSLocalizedString(@"kProposalCellRemoveApproval", @"移除授权");
                status.textColor = theme.sellColor;
            }else{
                status.text = NSLocalizedString(@"kProposalCellAddApproval", @"添加授权");
                status.textColor = theme.buyColor;
            }
        }else{
            if ([availableHash objectForKey:key]){
                status.text = NSLocalizedString(@"kProposalCellApproved", @"已批准");
                status.textColor = theme.buyColor;
            }else{
                status.text = NSLocalizedString(@"kProposalCellNotApproved", @"未批准");
                status.textColor = theme.textColorNormal;
            }
        }
        status.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
        status.hidden = NO;
        yOffset += fLineHeight;
    }
}

@end
