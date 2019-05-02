//
//  ViewProposalOpInfoCell_AccountUpdate.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewProposalOpInfoCell_AccountUpdate.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

#import "ViewPermissionCell.h"
#import "ViewMemoKeyCell.h"
#import "ViewVotingCell.h"

@interface ViewProposalOpInfoCell_AccountUpdate()
{
    NSDictionary*           _item;
    
    UILabel*                _lbTransferName;    //  交易类型描述 转账、限价单等
    UILabel*                _lbMainDesc;        //  描述
    
    UILabel*                _lbDangerous;       //  标签：危险操作
    
    ViewPermissionCell*     _viewPermissionOwner;
    ViewPermissionCell*     _viewPermissionActive;
    ViewMemoKeyCell*        _viewPermissionMemoKey;
    ViewVotingCell*         _viewVotingInfos;
    UIView*                 _pBottomLine;
}

@end

@implementation ViewProposalOpInfoCell_AccountUpdate

@synthesize item=_item;
@synthesize useLabelFont;
@synthesize useBuyColorForTitle;

- (void)dealloc
{
    _item = nil;
    
    _lbTransferName = nil;
    _lbMainDesc = nil;
    _lbDangerous = nil;
    
    _viewPermissionOwner = nil;
    _viewPermissionActive = nil;
    _viewPermissionMemoKey = nil;
    _viewVotingInfos = nil;
    
    _pBottomLine = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        self.useLabelFont = NO;
        
        _lbTransferName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTransferName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTransferName.textAlignment = NSTextAlignmentLeft;
        _lbTransferName.numberOfLines = 1;
        _lbTransferName.backgroundColor = [UIColor clearColor];
        _lbTransferName.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbTransferName];
        
        _lbDangerous = [[UILabel alloc] initWithFrame:CGRectZero];
        UIColor* backColor = [ThemeManager sharedThemeManager].sellColor;
        _lbDangerous.textAlignment = NSTextAlignmentCenter;
        _lbDangerous.backgroundColor = [UIColor clearColor];
        _lbDangerous.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbDangerous.font = [UIFont boldSystemFontOfSize:12];
        _lbDangerous.layer.borderWidth = 1;
        _lbDangerous.layer.cornerRadius = 2;
        _lbDangerous.layer.masksToBounds = YES;
        _lbDangerous.layer.borderColor = backColor.CGColor;
        _lbDangerous.layer.backgroundColor = backColor.CGColor;
        _lbDangerous.hidden = YES;
        [self addSubview:_lbDangerous];
        
        _lbMainDesc = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbMainDesc.lineBreakMode = NSLineBreakByWordWrapping;
        _lbMainDesc.textAlignment = NSTextAlignmentLeft;
        _lbMainDesc.numberOfLines = 0;
        _lbMainDesc.backgroundColor = [UIColor clearColor];
        _lbMainDesc.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbMainDesc];
        
        _viewPermissionOwner = nil;
        _viewPermissionActive = nil;
        _viewPermissionMemoKey = nil;
        _viewVotingInfos = nil;
        
        _pBottomLine = [[UIView alloc] init];
        _pBottomLine.backgroundColor = [ThemeManager sharedThemeManager].bottomLineColor;
        [self addSubview:_pBottomLine];
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

+ (CGFloat)getCellHeight:(NSDictionary*)item leftOffset:(CGFloat)leftOffset
{
    assert(item);
    
    id opdata = [item objectForKey:@"opdata"];
    assert(opdata);
    
    //  更新账号权限部分
    NSInteger base_height = 4 + 28;
    
    BOOL bHaveSpecView = NO;
    
    id opaccount = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[opdata objectForKey:@"account"]];
    
    id new_owner = [opdata objectForKey:@"owner"];
    if (new_owner){
        //  1、特殊View：更新所有者权限
        base_height += [ViewPermissionCell calcViewHeight:[opaccount objectForKey:@"owner"] new:new_owner];
        bHaveSpecView = YES;
    }
    
    id new_active = [opdata objectForKey:@"active"];
    if (new_active){
        //  2、特殊View：更新资金权限
        base_height += [ViewPermissionCell calcViewHeight:[opaccount objectForKey:@"active"] new:new_active];
        bHaveSpecView = YES;
    }
    
    id new_options = [opdata objectForKey:@"new_options"];
    if (new_options){
        id old_options = [opaccount objectForKey:@"options"];
        
        //  3、特殊View：更新备注权限
        id old_memo_key = [old_options objectForKey:@"memo_key"];
        id new_memo_key = [new_options objectForKey:@"memo_key"];
        if (![old_memo_key isEqualToString:new_memo_key]){
            base_height += [ViewMemoKeyCell calcViewHeight:old_memo_key new:new_memo_key];
            bHaveSpecView = YES;
        }
        
        //  4、特殊View：更新投票信息（包括代理）
        CGFloat voteViewHeight = [ViewVotingCell calcViewHeight:old_options new:new_options];
        if (voteViewHeight > 0){
            base_height += voteViewHeight;
            bHaveSpecView = YES;
        }
    }
    
    if (bHaveSpecView){
        //  有特殊View显示的情况
        return base_height;
    }else{
        //  没有任何信息更新（比如同时发起2个提案，第一个批准了，第二个提案和第一个的内容没任何变化等特殊情况。）
        id uidata = [item objectForKey:@"uidata"];
        assert(uidata);
        
        id desc = [uidata objectForKey:@"desc"];
        assert(desc);
        
        //  限制最低值
        leftOffset = MAX(leftOffset, 12);
        
        //  这里 12 和 layoutSubviews 里的 xOffset 一致。
        CGFloat fWidth = [[UIScreen mainScreen] bounds].size.width - leftOffset * 2;
        UIFont* font = [UIFont systemFontOfSize:13];
        CGSize size = [desc boundingRectWithSize:CGSizeMake(fWidth, 9999)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName:font} context:nil].size;
        
        CGFloat dynamic_height = size.height;
        
        return base_height + dynamic_height + 12;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!_item){
        return;
    }
    
    id opdata = [_item objectForKey:@"opdata"];
    id opaccount = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[opdata objectForKey:@"account"]];
    
    id new_owner = [opdata objectForKey:@"owner"];
    id new_active = [opdata objectForKey:@"active"];
    id new_options = [opdata objectForKey:@"new_options"];
    
    id uidata = [_item objectForKey:@"uidata"];
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.layoutMargins.left;
    CGFloat yOffset = 4;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fHeight = self.bounds.size.height;
    CGFloat fLineHeight = 28;
    
    _lbTransferName.text = [uidata objectForKey:@"name"];
    if (self.useBuyColorForTitle){
        _lbTransferName.textColor = theme.buyColor;
    }else{
        _lbTransferName.textColor = [uidata objectForKey:@"color"];
    }
    _lbTransferName.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    if (self.useLabelFont){
        _lbTransferName.font = self.textLabel.font;
    }
    
    //  特殊标签【危险操作】
    if (new_owner || new_active){
        _lbDangerous.text = NSLocalizedString(@"kOpDetailFlagDangerous", @"危险操作");
        _lbDangerous.hidden = NO;
        if (!_lbDangerous.hidden){
            CGSize size1 = [self auxSizeWithText:_lbTransferName.text font:_lbTransferName.font maxsize:CGSizeMake(fWidth, 9999)];
            CGSize size2 = [self auxSizeWithText:_lbDangerous.text font:_lbDangerous.font maxsize:CGSizeMake(fWidth, 9999)];
            _lbDangerous.frame = CGRectMake(xOffset + size1.width + 4, yOffset + (fLineHeight - size2.height - 2)/2,
                                            size2.width + 8, size2.height + 2);
        }
    }else{
        _lbDangerous.hidden = YES;
    }
    
    yOffset += fLineHeight;

    //  第二行 特殊View or 没有任何更新。
    if (_viewPermissionOwner){
        [_viewPermissionOwner removeFromSuperview];
        _viewPermissionOwner = nil;
    }
    if (_viewPermissionActive){
        [_viewPermissionActive removeFromSuperview];
        _viewPermissionActive = nil;
    }
    if (_viewPermissionMemoKey){
        [_viewPermissionMemoKey removeFromSuperview];
        _viewPermissionMemoKey = nil;
    }
    if (_viewVotingInfos){
        [_viewVotingInfos removeFromSuperview];
        _viewVotingInfos = nil;
    }
    
    //  1、所有者权限
    if (new_owner){
        _viewPermissionOwner = [[ViewPermissionCell alloc] initWithPermission:opaccount[@"owner"]
                                                                            new:new_owner
                                                                          title:NSLocalizedString(@"kOpDetailPermissionOwner", @"所有者权限")];
        _viewPermissionOwner.xOffset = xOffset;
        [self addSubview:_viewPermissionOwner];
        CGFloat height = [_viewPermissionOwner getViewHeight];
        _viewPermissionOwner.frame = CGRectMake(0, yOffset, self.bounds.size.width, height);
        yOffset += height;
    }
    
    //  2、资金权限
    if (new_active){
        _viewPermissionActive = [[ViewPermissionCell alloc] initWithPermission:opaccount[@"active"]
                                                                             new:new_active
                                                                           title:NSLocalizedString(@"kOpDetailPermissionActive", @"资金权限")];
        _viewPermissionActive.xOffset = xOffset;
        [self addSubview:_viewPermissionActive];
        CGFloat height = [_viewPermissionActive getViewHeight];
        _viewPermissionActive.frame = CGRectMake(0, yOffset, self.bounds.size.width, height);
        yOffset += height;
    }
    
    if (new_options){
        id old_options = [opaccount objectForKey:@"options"];
        
        //  3、备注权限
        id old_memo_key = [old_options objectForKey:@"memo_key"];
        id new_memo_key = [new_options objectForKey:@"memo_key"];
        if (![old_memo_key isEqualToString:new_memo_key]){
            _viewPermissionMemoKey = [[ViewMemoKeyCell alloc] initWithOldMemo:old_memo_key
                                                                         new:new_memo_key
                                                                       title:NSLocalizedString(@"kOpDetailPermissionMemo", @"备注权限")];
            _viewPermissionMemoKey.xOffset = xOffset;
            [self addSubview:_viewPermissionMemoKey];
            CGFloat height = [_viewPermissionMemoKey getViewHeight];
            _viewPermissionMemoKey.frame = CGRectMake(0, yOffset, self.bounds.size.width, height);
            yOffset += height;
        }
        
        //  4、投票信息（包括代理）
        CGFloat voteViewHeight = [ViewVotingCell calcViewHeight:old_options new:new_options];
        if (voteViewHeight > 0){
            _viewVotingInfos = [[ViewVotingCell alloc] initWithOptions:old_options new:new_options];
            _viewVotingInfos.xOffset = xOffset;
            [self addSubview:_viewVotingInfos];
            CGFloat height = [_viewVotingInfos getViewHeight];
            _viewVotingInfos.frame = CGRectMake(0, yOffset, self.bounds.size.width, height);
            yOffset += height;
        }
    }
    
    if (_viewPermissionOwner || _viewPermissionActive || _viewPermissionMemoKey || _viewVotingInfos){
        _lbMainDesc.hidden = YES;
        _pBottomLine.hidden = YES;
    }else{
        _lbMainDesc.hidden = NO;
        _pBottomLine.hidden = NO;
        
        _lbMainDesc.text = [uidata objectForKey:@"desc"];
        _lbMainDesc.textColor = theme.textColorNormal;
        _lbMainDesc.frame = CGRectMake(xOffset, yOffset, fWidth, fHeight - fLineHeight - 12);
        
        _pBottomLine.frame = CGRectMake(xOffset, fHeight - 1.0f, self.bounds.size.width - xOffset, 0.5f);
    }
}

@end
