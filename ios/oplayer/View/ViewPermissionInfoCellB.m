//
//  ViewPermissionInfoCellB.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewPermissionInfoCellB.h"
#import "ChainObjectManager.h"
#import "ThemeManager.h"
#import "NativeAppDelegate.h"
#import "OrgUtils.h"

@interface ViewPermissionInfoCellB()
{
    NSDictionary*   _item;
    
    UILabel*        _lbAuthority;           //  权利实体
    UILabel*        _lbThreshold;           //  阈值
    UIButton*       _btnRemove;             //  移除按钮
}

@end

@implementation ViewPermissionInfoCellB

@synthesize item=_item;
@synthesize passThreshold;

- (void)dealloc
{
    _item = nil;
    
    _lbThreshold = nil;
    _lbAuthority = nil;
    _btnRemove = nil;
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
        _lbAuthority = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAuthority.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAuthority.textAlignment = NSTextAlignmentLeft;
        _lbAuthority.numberOfLines = 1;
        _lbAuthority.backgroundColor = [UIColor clearColor];
        _lbAuthority.font = [UIFont systemFontOfSize:14];
        [self addSubview:_lbAuthority];
     
        _lbThreshold = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbThreshold.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbThreshold.textAlignment = NSTextAlignmentLeft;
        _lbThreshold.numberOfLines = 1;
        _lbThreshold.backgroundColor = [UIColor clearColor];
        _lbThreshold.font = [UIFont systemFontOfSize:14];
        [self addSubview:_lbThreshold];
        
        _btnRemove = [UIButton buttonWithType:UIButtonTypeCustom];
        _btnRemove.titleLabel.font = [UIFont systemFontOfSize:14];
        [_btnRemove setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
        [_btnRemove addTarget:vc action:@selector(onButtonClicked_Remove:) forControlEvents:UIControlEventTouchUpInside];
        _btnRemove.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [_btnRemove setTitle:NSLocalizedString(@"kVcPermissionEditBtnRemove", @"移除") forState:UIControlStateNormal];
        [self addSubview:_btnRemove];
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
    if (_btnRemove){
        _btnRemove.tag = tag;
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
    CGFloat fCellHeight = self.bounds.size.height;
    CGFloat fLineHeight = 28.0f;
    
    
    if ([[_item objectForKey:@"title"] boolValue]) {
        _lbAuthority.text = NSLocalizedString(@"kVcPermissionEditTitleName", @"账号/公钥");
        _lbThreshold.text = NSLocalizedString(@"kVcPermissionEditTitleWeight", @"权重(百分比)");
        [_btnRemove setTitle:NSLocalizedString(@"kVcPermissionEditTitleAction", @"操作") forState:UIControlStateNormal];
        
        _lbAuthority.textColor = theme.textColorGray;
        _lbThreshold.textColor = theme.textColorGray;
        [_btnRemove setTitleColor:theme.textColorGray forState:UIControlStateNormal];
        _btnRemove.userInteractionEnabled = NO;
    } else {
        //  获取名字
        NSString* name = [_item objectForKey:@"name"];
        if (!name) {
            name = [_item objectForKey:@"key"];
            if ([[_item objectForKey:@"isaccount"] boolValue]) {
                name = [[[ChainObjectManager sharedChainObjectManager] getChainObjectByID:name] objectForKey:@"name"];
            }
        }

        //  获取权重所占百分比（最大值限制为100%）
        NSInteger threshold = [[_item objectForKey:@"threshold"] integerValue];
        CGFloat weight_percent;
        weight_percent = threshold * 100.0f / (CGFloat)self.passThreshold;
        if (threshold < self.passThreshold){
            weight_percent = fminf(weight_percent, 99.0f);
        }
        if (threshold > 0){
            weight_percent = fmaxf(weight_percent, 1.0f);
        }
        weight_percent = fminf(weight_percent, 100.0f);
        
        _lbAuthority.text = name;
//        _lbThreshold.attributedText = [UITableViewCellBase genAndColorAttributedText:[NSString stringWithFormat:@"%@ ", @(threshold)]
//                                                                               value:[NSString stringWithFormat:@"(%2d%%)", (int)weight_percent]
//                                                                          titleColor:theme.textColorMain
//                                                                          valueColor:theme.textColorNormal];
        _lbThreshold.text = [NSString stringWithFormat:@"%@ (%2d%%)", @(threshold), (int)weight_percent];
        [_btnRemove setTitle:NSLocalizedString(@"kVcPermissionEditBtnRemove", @"移除") forState:UIControlStateNormal];
        
        _lbAuthority.textColor = theme.textColorMain;
        _lbThreshold.textColor = theme.textColorMain;
        [_btnRemove setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
        _btnRemove.userInteractionEnabled = YES;
    }
    
    _lbAuthority.frame = CGRectMake(xOffset, yOffset, fWidth * 0.6, fCellHeight);
    _lbThreshold.frame = CGRectMake(xOffset + fWidth * 0.6 + 12, yOffset, fWidth, fCellHeight);
    CGFloat fButtonWidth = 72.0f;
    _btnRemove.frame = CGRectMake(self.bounds.size.width - xOffset - fButtonWidth,
                                  (fCellHeight - fLineHeight) / 2.0f, fButtonWidth, fLineHeight);
}

@end
