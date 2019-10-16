//
//  ViewPermissionInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewPermissionInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewPermissionInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbTitle;               //  标题
    UILabel*        _lbThreshold;           //  阈值
    
    NSMutableArray* _lbAuthorizeTitleList;
    NSMutableArray* _lbAuthorizeStatusList;
}

@end

@implementation ViewPermissionInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbThreshold = nil;
    _lbTitle = nil;

    _lbAuthorizeTitleList = nil;
    _lbAuthorizeStatusList = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        //  第一行
        _lbTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTitle.textAlignment = NSTextAlignmentLeft;
        _lbTitle.numberOfLines = 1;
        _lbTitle.backgroundColor = [UIColor clearColor];
        _lbTitle.font = [UIFont systemFontOfSize:14];
        [self addSubview:_lbTitle];
     
        _lbThreshold = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbThreshold.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbThreshold.textAlignment = NSTextAlignmentRight;
        _lbThreshold.numberOfLines = 1;
        _lbThreshold.backgroundColor = [UIColor clearColor];
        _lbThreshold.font = [UIFont systemFontOfSize:14];
        [self addSubview:_lbThreshold];
        
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
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 0;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fLineHeight = 28;

    BOOL bHideThreshold = [[_item objectForKey:@"is_memo"] boolValue];
    id authorizeItems = [_item objectForKey:@"items"];
    NSInteger passThreshold = [_item[@"weight_threshold"] integerValue];
    
    //  第一行 标题
    if (bHideThreshold) {
        _lbTitle.hidden = YES;
        _lbThreshold.hidden = YES;
    } else {
        _lbTitle.hidden = NO;
        _lbThreshold.hidden = NO;
        _lbTitle.text = NSLocalizedString(@"kVcPermissionEditTitleName", @"账号/公钥");
        _lbTitle.textColor = theme.textColorGray;
        _lbTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
        
        _lbThreshold.text = NSLocalizedString(@"kVcPermissionEditTitleWeight", @"权重(百分比)");
        _lbThreshold.textColor = theme.textColorGray;
        _lbThreshold.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
        
        yOffset += fLineHeight;
    }

    //  各权限实体
    NSInteger diff = (NSInteger)[authorizeItems count] - (NSInteger)[_lbAuthorizeTitleList count];
    for (NSInteger i = 0; i < diff; ++i) {
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.numberOfLines = 1;
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont systemFontOfSize:14];
        [self addSubview:label];
        [_lbAuthorizeTitleList addObject:label];

        UILabel* status = [[UILabel alloc] initWithFrame:CGRectZero];
        status.lineBreakMode = NSLineBreakByTruncatingTail;
        status.numberOfLines = 1;
        status.textAlignment = NSTextAlignmentRight;
        status.backgroundColor = [UIColor clearColor];
        status.font = [UIFont systemFontOfSize:14];
        [self addSubview:status];
        [_lbAuthorizeStatusList addObject:status];
    }
    for (UILabel* label in _lbAuthorizeTitleList) {
        label.hidden = YES;
    }
    for (UILabel* label in _lbAuthorizeStatusList) {
        label.hidden = YES;
    }
    NSInteger labelIndex = 0;
    for (id item in authorizeItems) {
        //  计算该授权实体占比权重（最大值限制为100%）。
        NSInteger threshold = [[item objectForKey:@"threshold"] integerValue];
        CGFloat weight_percent = 0;
        if (!bHideThreshold) {
            weight_percent = threshold * 100.0f / (CGFloat)passThreshold;
            if (threshold < passThreshold){
                weight_percent = fminf(weight_percent, 99.0f);
            }
            if (threshold > 0){
                weight_percent = fmaxf(weight_percent, 1.0f);
            }
            weight_percent = fminf(weight_percent, 100.0f);
        }
        
        //  entity
        NSString* name = [item objectForKey:@"name"] ?: [item objectForKey:@"key"];
        UILabel* label = [_lbAuthorizeTitleList objectAtIndex:labelIndex];
        label.textColor = theme.textColorMain;
        label.text = name;
        if (bHideThreshold) {
            label.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
        } else {
            label.frame = CGRectMake(xOffset, yOffset, fWidth * 0.75f, fLineHeight);
        }
        label.hidden = NO;
        
        //  status
        UILabel* status = [_lbAuthorizeStatusList objectAtIndex:labelIndex++];
        status.text = [NSString stringWithFormat:@"%@ (%2d%%)", @(threshold), (int)weight_percent];
        status.textColor = theme.textColorMain;
        status.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
        status.hidden = bHideThreshold;
        yOffset += fLineHeight;
    }
}

@end
