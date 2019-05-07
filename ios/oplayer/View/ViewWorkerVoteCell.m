//
//  ViewWorkerVoteCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewWorkerVoteCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "VCVote.h"

@interface ViewWorkerVoteCell()
{
    NSInteger       _row;
    NSDictionary*   _item;
    NSDictionary*   _votingInfo;
    
    UILabel*        _lbWorkerName;
    UIButton*       _btnIntro;
    
    UILabel*        _lbWorkerID;
    UILabel*        _lbAccountName;
    UILabel*        _lbVoteNumber;
    UILabel*        _lbDailyPay;
    UILabel*        _lbDate;
    UILabel*        _lbTypeFlag;
}

@end

@implementation ViewWorkerVoteCell

@synthesize bts_precision_pow;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    _votingInfo = nil;
    
    _lbWorkerName = nil;
    _btnIntro = nil;
    
    _lbWorkerID = nil;
    _lbAccountName = nil;
    _lbVoteNumber = nil;
    _lbDailyPay = nil;
    _lbDate = nil;
    _lbTypeFlag = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        _row = 0;
        self.bts_precision_pow = 100000;
        _votingInfo = nil;
        
        //  多选时不显示蓝色背景
        self.multipleSelectionBackgroundView = [[UIView alloc] init];
        self.multipleSelectionBackgroundView.hidden = YES;
        self.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
        
        //  第一行
        _lbWorkerName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbWorkerName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbWorkerName.textAlignment = NSTextAlignmentLeft;
        _lbWorkerName.numberOfLines = 1;
        _lbWorkerName.backgroundColor = [UIColor clearColor];
        _lbWorkerName.font = [UIFont boldSystemFontOfSize:16];
//        _lbWorkerName.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbWorkerName];
        
        if (vc){
            _btnIntro = [UIButton buttonWithType:UIButtonTypeCustom];
            _btnIntro.backgroundColor = [UIColor clearColor];
            [_btnIntro setTitle:NSLocalizedString(@"kLabelVotingIntroduction", @"介绍 >") forState:UIControlStateNormal];
            [_btnIntro setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
            _btnIntro.titleLabel.font = [UIFont systemFontOfSize:13.0];
            _btnIntro.userInteractionEnabled = YES;
            _btnIntro.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
            [_btnIntro addTarget:vc action:@selector(onButtonClicked_Url:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_btnIntro];
        }else{
            _btnIntro = nil;
        }
        
        _lbWorkerID = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbWorkerID.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbWorkerID.textAlignment = NSTextAlignmentLeft;
        _lbWorkerID.numberOfLines = 1;
        _lbWorkerID.backgroundColor = [UIColor clearColor];
        _lbWorkerID.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbWorkerID];
        
        _lbAccountName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAccountName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAccountName.textAlignment = NSTextAlignmentRight;
        _lbAccountName.numberOfLines = 1;
        _lbAccountName.backgroundColor = [UIColor clearColor];
        _lbAccountName.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbAccountName];

        _lbVoteNumber = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbVoteNumber.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbVoteNumber.textAlignment = NSTextAlignmentLeft;
        _lbVoteNumber.numberOfLines = 1;
        _lbVoteNumber.backgroundColor = [UIColor clearColor];
        _lbVoteNumber.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbVoteNumber];
        _lbVoteNumber.adjustsFontSizeToFitWidth = YES;
        
        _lbDailyPay = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbDailyPay.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbDailyPay.textAlignment = NSTextAlignmentRight;
        _lbDailyPay.numberOfLines = 1;
        _lbDailyPay.backgroundColor = [UIColor clearColor];
        _lbDailyPay.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbDailyPay];
        _lbDailyPay.adjustsFontSizeToFitWidth = YES;
        
        _lbDate = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbDate.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbDate.textAlignment = NSTextAlignmentLeft;
        _lbDate.numberOfLines = 1;
        _lbDate.backgroundColor = [UIColor clearColor];
        _lbDate.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbDate];
        _lbDate.adjustsFontSizeToFitWidth = YES;
        
        _lbTypeFlag = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTypeFlag.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTypeFlag.textAlignment = NSTextAlignmentRight;
        _lbTypeFlag.numberOfLines = 1;
        _lbTypeFlag.backgroundColor = [UIColor clearColor];
        _lbTypeFlag.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbTypeFlag];
        _lbTypeFlag.adjustsFontSizeToFitWidth = YES;
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
    _row = tag;
    if (_btnIntro){
        _btnIntro.tag = tag;
    }
}

- (void)setVotingInfo:(NSDictionary*)voting_info
{
    _votingInfo = voting_info;
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
    if (!_votingInfo){
        return;
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    //  TODO:fowallet 编辑模式 左边距离。
    CGFloat fOffsetEditingMode = self.editing ? 38 : 0;
    
    CGFloat fRightOffset = self.textLabel.frame.origin.x;
    CGFloat xOffset = fRightOffset + fOffsetEditingMode;
    CGFloat yOffset = 0;
    CGFloat fWidth = self.bounds.size.width - xOffset - fRightOffset;
    CGFloat fCellWidth = fWidth / 5;
    CGFloat fLineHeight = 28.0f;
    
    //  根据是否选中设置颜色。
//    assert([[_item objectForKey:@"_kSelected"] boolValue] == self.selected);
    UIColor* mainColor = self.selected ? theme.textColorMain : theme.textColorNormal;
    
    _lbWorkerName.text = [NSString stringWithFormat:@"%@. %@", @(_row+1), [_item objectForKey:@"name"]];
    _lbWorkerName.textColor = mainColor;
    _lbWorkerName.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    
    if (_btnIntro){
        id url = [_item objectForKey:@"url"];
        if (url && ![url isEqualToString:@""]){
            _btnIntro.hidden = NO;
            CGSize sizeLimit = [self auxSizeWithText:NSLocalizedString(@"kLabelVotingIntroduction", @"介绍 >")
                                                font:_btnIntro.titleLabel.font maxsize:CGSizeMake(9999, fLineHeight)];
            _btnIntro.frame = CGRectMake(self.bounds.size.width - fRightOffset - (sizeLimit.width + 8), yOffset, sizeLimit.width + 8, fLineHeight);
            //  REMARK：为介绍按钮留出一定宽度
            _lbWorkerName.frame = CGRectMake(xOffset, yOffset, fWidth - (sizeLimit.width + 8), fLineHeight);
        }else{
            _btnIntro.hidden = YES;
        }
    }
    
    yOffset += fLineHeight;
    
    NSString* name = nil;
    NSString* account_id = [_item objectForKey:@"worker_account"];
    id account_info = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:account_id];
    if (account_info){
        name = [account_info objectForKey:@"name"];
    }else{
        name = account_id;
    }
    
    _lbWorkerID.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcVoteCellWorkerID", @"ID ")
                                                           value:_item[@"id"]
                                                      titleColor:theme.textColorNormal
                                                      valueColor:mainColor];
    _lbWorkerID.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    
    
    _lbAccountName.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcVoteCellCreator", @"创建者 ")
                                                             value:name
                                                        titleColor:theme.textColorNormal
                                                        valueColor:mainColor];
    _lbAccountName.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    id n_vote = [_item objectForKey:@"total_votes_for"];
    assert(n_vote);
    unsigned long long d_vote = [n_vote unsignedLongLongValue];
    _lbVoteNumber.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcVoteCellTotalVotes", @"总票数 ")
                                                             value:[OrgUtils formatFloatValue:round(d_vote/bts_precision_pow) precision:0]
                                                        titleColor:theme.textColorNormal
                                                        valueColor:mainColor];
    _lbVoteNumber.frame = CGRectMake(xOffset + fCellWidth * 0, yOffset, fCellWidth * 3, fLineHeight);
    
    id n_daily_pay = [_item objectForKey:@"daily_pay"];
    _lbDailyPay.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcVoteCellDailyPay", @"每日预算 ")
                                                           value:[OrgUtils formatFloatValue:round([n_daily_pay unsignedLongLongValue]/bts_precision_pow) precision:0]
                                                      titleColor:theme.textColorNormal
                                                      valueColor:mainColor];
    _lbDailyPay.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    
    yOffset += fLineHeight;
    
    //  TODO:fowallet 即将到期提醒
    NSTimeInterval work_begin_date = [OrgUtils parseBitsharesTimeString:[_item objectForKey:@"work_begin_date"]];
    NSTimeInterval work_end_date = [OrgUtils parseBitsharesTimeString:[_item objectForKey:@"work_end_date"]];
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yy/MM/dd"];
    id d1 = [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:work_begin_date]];
    id d2 = [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:work_end_date]];
    _lbDate.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcVoteCellWPDatePeriod", @"有效期 ")
                                                       value:[NSString stringWithFormat:@"%@ - %@", d1, d2]
                                                  titleColor:theme.textColorNormal
                                                  valueColor:mainColor];
    _lbDate.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    
    //  type flag
    NSString* flagTypeStr = @"";
    NSInteger workerType = [OrgUtils getWorkerType:_item];
    switch (workerType) {
        case ebwt_refund:
            flagTypeStr = NSLocalizedString(@"kVcVoteCellWPRefund", @"退款");
            break;
        case ebwt_vesting:
            flagTypeStr = NSLocalizedString(@"kVcVoteCellWPVesting", @"普通");
            break;
        case ebwt_burn:
            flagTypeStr = NSLocalizedString(@"kVcVoteCellWPBurn", @"销毁");
            break;
        default:
            break;
    }
    if (self.selected){
        //  vesting is normal color, others are call color.
        mainColor = workerType == 1 ? theme.textColorMain : theme.callOrderColor;
    }else{
        mainColor = theme.textColorNormal;
    }
    _lbTypeFlag.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcVoteCellWPType", @"类型 ")
                                                           value:flagTypeStr
                                                      titleColor:theme.textColorNormal
                                                      valueColor:mainColor];
    _lbTypeFlag.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
}

@end
