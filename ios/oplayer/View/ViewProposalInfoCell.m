//
//  ViewProposalInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewProposalInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewProposalInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbCreator;
    UILabel*        _lbApproval;
    
    UILabel*        _lbStatus;
    UILabel*        _lbAuthorizeProgress;
}

@end

@implementation ViewProposalInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbCreator = nil;
    _lbApproval = nil;
    _lbStatus = nil;
    _lbAuthorizeProgress = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];

        _lbApproval = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbApproval.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbApproval.numberOfLines = 1;
        _lbApproval.backgroundColor = [UIColor clearColor];
        _lbApproval.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbApproval];
        
        _lbCreator = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbCreator.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbCreator.numberOfLines = 1;
        _lbCreator.textAlignment = NSTextAlignmentRight;
        _lbCreator.backgroundColor = [UIColor clearColor];
        _lbCreator.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbCreator];
        
        _lbStatus = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbStatus.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbStatus.numberOfLines = 1;
        _lbStatus.textAlignment = NSTextAlignmentRight;
        _lbStatus.backgroundColor = [UIColor clearColor];
        _lbStatus.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbStatus];
        
        _lbAuthorizeProgress = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAuthorizeProgress.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAuthorizeProgress.numberOfLines = 1;
        _lbAuthorizeProgress.backgroundColor = [UIColor clearColor];
        _lbAuthorizeProgress.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbAuthorizeProgress];
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
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    //  获取数据
    id kProcessedData = [_item objectForKey:@"kProcessedData"];
    assert(kProcessedData);
    NSInteger passThreshold = [[kProcessedData objectForKey:@"passThreshold"] integerValue];
    NSInteger currThreshold = [[kProcessedData objectForKey:@"currThreshold"] integerValue];
    CGFloat thresholdPercent = [[kProcessedData objectForKey:@"thresholdPercent"] floatValue];
    
    CGFloat xOffset = self.layoutMargins.left;
    CGFloat yOffset = 2;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
//    CGFloat fHeight = self.bounds.size.height;
    CGFloat fLineHeight = 28;
    
    NSMutableDictionary* require_ids = [NSMutableDictionary dictionary];
    NSMutableArray* require_names = [NSMutableArray array];
    for (id oid in [_item objectForKey:@"required_active_approvals"]) {
        [require_ids setObject:@YES forKey:oid];
    }
    for (id oid in [_item objectForKey:@"required_owner_approvals"]) {
        [require_ids setObject:@YES forKey:oid];
    }
    for (id oid in [require_ids allKeys]) {
        [require_names addObject:[[chainMgr getChainObjectByID:oid] objectForKey:@"name"]];
    }
    _lbApproval.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kProposalCellApprover", @"目标账号 ")
                                                           value:[require_names componentsJoinedByString:@" "]
                                                      titleColor:theme.textColorNormal
                                                      valueColor:theme.textColorMain];
    
    _lbCreator.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kProposalCellCreator", @"发起账号 ")
                                                          value:[[chainMgr getChainObjectByID:_item[@"proposer"]] objectForKey:@"name"]
                                                     titleColor:theme.textColorNormal
                                                     valueColor:theme.textColorMain];
    
    _lbCreator.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbApproval.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    
    yOffset += fLineHeight;
    
    //  （白色）进行中：没有或者未进入审核期授权未通过
    //  （红色）未通过：进入审核期并且授权未通过
    //  （红色）失败：无审核期并且授权已通过，则执行失败。
    //  （绿色）待审核：有审核期但尚未开始审核并且授权已通过
    //  （绿色）审核中：进入审核期并且授权已通过
    BOOL bApprovalPassed = currThreshold >= passThreshold;
    BOOL bInReview = [[kProcessedData objectForKey:@"inReview"] boolValue];
    
    NSString* status = nil;
    UIColor* statusColor = nil;
    if (bApprovalPassed){
        if ([_item objectForKey:@"review_period_time"]){
            if (bInReview){
                //  审核中：进入审核期并且授权已通过
                status = NSLocalizedString(@"kProposalCellStatusReview", @"审核中");
                statusColor = theme.buyColor;
            }else{
                //  待审核：有审核期但尚未开始审核并且授权已通过
                status = NSLocalizedString(@"kProposalCellStatusWaitReview", @"待审核");
                statusColor = theme.buyColor;
            }
        }else{
            //  失败：无审核期并且授权已通过，则执行失败。
            status = NSLocalizedString(@"kProposalCellStatusFailed", @"失败");
            statusColor = theme.sellColor;
        }
    }else{
        if ([_item objectForKey:@"review_period_time"] && bInReview){
            //  未通过：进入审核期并且授权未通过
            status = NSLocalizedString(@"kProposalCellStatusNotPassed", @"未通过");
            statusColor = theme.sellColor;
        }else{
            //  进行中：没有或者未进入审核期并且授权未通过
            status = NSLocalizedString(@"kProposalCellStatusPending", @"进行中");
            statusColor = theme.textColorMain;
        }
    }
    assert(status && statusColor);
    _lbStatus.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kProposalCellStatusTitle", @"状态 ")
                                                         value:status
                                                    titleColor:theme.textColorNormal
                                                    valueColor:statusColor];
    _lbStatus.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    
    _lbAuthorizeProgress.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kProposalCellProgress", @"授权进度 ")
                                                                    value:[NSString stringWithFormat:@"%2d%% (%d/%d)", (int)thresholdPercent, (int)currThreshold, (int)passThreshold]
                                                               titleColor:theme.textColorNormal
                                                               valueColor:theme.textColorMain];
    _lbAuthorizeProgress.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
}

@end
