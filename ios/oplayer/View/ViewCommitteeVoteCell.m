//
//  ViewCommitteeVoteCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewCommitteeVoteCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "VCVote.h"
#import "ChainObjectManager.h"

@interface ViewCommitteeVoteCell()
{
    NSInteger       _row;
    NSDictionary*   _item;
    NSDictionary*   _votingInfo;
    
    UILabel*        _lbAccountName;
//    UILabel*        _lbVoteFlag;
    UILabel*        _lbVoteNumber;
    UILabel*        _lbMissNumber;
    
    UIButton*       _btnIntro;
}

@end

@implementation ViewCommitteeVoteCell

@synthesize voteType;
@synthesize bts_precision_pow;
@synthesize dirty;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    _votingInfo = nil;
    
    _lbAccountName = nil;
//    _lbVoteFlag = nil;
    _lbVoteNumber = nil;
    _lbMissNumber = nil;
    _btnIntro = nil;
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
        self.voteType = evt_committee;
        self.bts_precision_pow = 100000;
        self.dirty = NO;
        _votingInfo = nil;
        
        //  多选时不显示蓝色背景
        self.multipleSelectionBackgroundView = [[UIView alloc] init];
        self.multipleSelectionBackgroundView.hidden = YES;
        self.tintColor = [ThemeManager sharedThemeManager].textColorHighlight;
        
        //  第一行
        _lbAccountName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAccountName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAccountName.textAlignment = NSTextAlignmentLeft;
        _lbAccountName.numberOfLines = 1;
        _lbAccountName.backgroundColor = [UIColor clearColor];
        _lbAccountName.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_lbAccountName];
        _lbAccountName.adjustsFontSizeToFitWidth = YES;

//        _lbVoteFlag = [[UILabel alloc] initWithFrame:CGRectZero];
//        UIColor* backColor = [ThemeManager sharedThemeManager].textColorHighlight;
//        _lbVoteFlag.textAlignment = NSTextAlignmentCenter;
//        _lbVoteFlag.backgroundColor = [UIColor clearColor];
//        _lbVoteFlag.textColor = [ThemeManager sharedThemeManager].textColorMain;
//        _lbVoteFlag.font = [UIFont boldSystemFontOfSize:12];
//        _lbVoteFlag.layer.borderWidth = 1;
//        _lbVoteFlag.layer.cornerRadius = 2;
//        _lbVoteFlag.layer.masksToBounds = YES;
//        _lbVoteFlag.layer.borderColor = backColor.CGColor;
//        _lbVoteFlag.layer.backgroundColor = backColor.CGColor;
//        _lbVoteFlag.hidden = YES;
//        [self addSubview:_lbVoteFlag];
        
        _lbVoteNumber = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbVoteNumber.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbVoteNumber.textAlignment = NSTextAlignmentLeft;
        _lbVoteNumber.numberOfLines = 1;
        _lbVoteNumber.backgroundColor = [UIColor clearColor];
        _lbVoteNumber.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbVoteNumber];
        _lbVoteNumber.adjustsFontSizeToFitWidth = YES;
        
        _lbMissNumber = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbMissNumber.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbMissNumber.textAlignment = NSTextAlignmentRight;
        _lbMissNumber.numberOfLines = 1;
        _lbMissNumber.backgroundColor = [UIColor clearColor];
        _lbMissNumber.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbMissNumber];
        _lbMissNumber.adjustsFontSizeToFitWidth = YES;
        
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
    
//    CGFloat fHalfWidth = self.bounds.size.width / 2;
    
    NSString* name = nil;
    NSString* account_id = nil;
    switch (self.voteType) {
        case evt_committee:
        {
            account_id = [_item objectForKey:@"committee_member_account"];
        }
            break;
        case evt_witness:
        {
            account_id = [_item objectForKey:@"witness_account"];
        }
            break;
        case evt_work:
        {
            account_id = [_item objectForKey:@"worker_account"];
        }
            break;
        default:
            assert(false);
            break;
    }
    id account_info = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:account_id];
    if (account_info){
        name = [account_info objectForKey:@"name"];
    }else{
        name = account_id;
    }
    
    _lbAccountName.text = [NSString stringWithFormat:@"%@. %@", @(_row+1), name];
    _lbAccountName.textColor = mainColor;
    //  TODO:fowallet 宽度？？覆盖 个人介绍按钮了
    _lbAccountName.frame = CGRectMake(xOffset, yOffset, fWidth - 60, fLineHeight);
    
    //  TODO:fowallet 未完成...
//    //  投票标记（代投票、投票、扯票）
//    //  TODO:fowallet
//    if ([[_votingInfo objectForKey:@"have_proxy"] boolValue]){
//        UIColor* backColor = nil;
//        if ([[_item objectForKey:@"_kOldSelected"] boolValue]){
//            if (self.selected){
//                if (!self.dirty){
//                    _lbVoteFlag.text = @"代投票";
//                    _lbVoteFlag.hidden = NO;
//                    backColor = [ThemeManager sharedThemeManager].textColorHighlight;
//                }else{
//                    _lbVoteFlag.hidden = YES;
//                }
//            }else{
//                _lbVoteFlag.text = @"撤票";
//                _lbVoteFlag.hidden = NO;
//                backColor = [ThemeManager sharedThemeManager].sellColor;
//            }
//        }else{
//            if (self.selected){
//                _lbVoteFlag.text = @"新增";
//                _lbVoteFlag.hidden = NO;
//                backColor = [ThemeManager sharedThemeManager].buyColor;
//            }else{
//                _lbVoteFlag.hidden = YES;
//            }
//        }
//        if (backColor){
//            _lbVoteFlag.layer.borderColor = backColor.CGColor;
//            _lbVoteFlag.layer.backgroundColor = backColor.CGColor;
//        }
//        if (!_lbVoteFlag.hidden){
//            CGSize size1 = [self auxSizeWithText:_lbAccountName.text font:_lbAccountName.font maxsize:CGSizeMake(fWidth, 9999)];
//            CGSize size2 = [self auxSizeWithText:_lbVoteFlag.text font:_lbVoteFlag.font maxsize:CGSizeMake(fWidth, 9999)];
//            _lbVoteFlag.frame = CGRectMake(xOffset + size1.width + 4, yOffset + (fLineHeight - size2.height - 2)/2, size2.width + 8, size2.height + 2);
//        }
//    }else{
//        _lbVoteFlag.hidden = YES;
//    }

    //  TODO:fowallet cancel
    if (_btnIntro){
        id url = [_item objectForKey:@"url"];
        if (url && ![url isEqualToString:@""]){
            _btnIntro.hidden = NO;
            _btnIntro.frame = CGRectMake(self.bounds.size.width - fRightOffset - 120, yOffset, 120, fLineHeight);
        }else{
            _btnIntro.hidden = YES;
        }
    }
    
    yOffset += fLineHeight;
    
    id n_vote = [_item objectForKey:@"total_votes"];
    assert(n_vote);
    unsigned long long d_vote = [n_vote unsignedLongLongValue];
    _lbVoteNumber.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcVoteCellTotalVotes", @"总票数 ")
                                                               value:[OrgUtils formatFloatValue:round(d_vote/bts_precision_pow) precision:0]
                                                          titleColor:theme.textColorNormal
                                                          valueColor:mainColor];
    _lbVoteNumber.frame = CGRectMake(xOffset + fCellWidth * 0, yOffset, fCellWidth * 3, fLineHeight);
    
    id n_total_missed = [_item objectForKey:@"total_missed"];
    if (n_total_missed){
        _lbMissNumber.hidden = NO;
        _lbMissNumber.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kVcVoteCellMissed", @"丢块数 ")
                                                                 value:[NSString stringWithFormat:@"%@", n_total_missed]
                                                            titleColor:theme.textColorNormal
                                                            valueColor:mainColor];
        _lbMissNumber.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    }else{
        _lbMissNumber.hidden = YES;
    }
    
    yOffset += fLineHeight;
}

@end
