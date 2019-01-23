//
//  ViewProposalActionsCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewProposalActionsCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewProposalActionsCell()
{
    NSDictionary*   _item;
    
    UIButton*       _btnApprove;
    UIButton*       _btnReject;
//    UIButton*       _btnDelete;
}

@end

@implementation ViewProposalActionsCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _btnApprove = nil;
    _btnReject = nil;
//    _btnDelete = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];

        _btnApprove = [UIButton buttonWithType:UIButtonTypeCustom];
        _btnApprove.backgroundColor = [UIColor clearColor];
        [_btnApprove setTitle:NSLocalizedString(@"kProposalCellBtnApprove", @"批准") forState:UIControlStateNormal];
        [_btnApprove setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
        _btnApprove.titleLabel.font = [UIFont systemFontOfSize:16.0];
        _btnApprove.userInteractionEnabled = YES;
        _btnApprove.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        [_btnApprove addTarget:vc action:@selector(onButtonClicked_Approve:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_btnApprove];
      
        _btnReject = [UIButton buttonWithType:UIButtonTypeCustom];
        _btnReject.backgroundColor = [UIColor clearColor];
        [_btnReject setTitle:NSLocalizedString(@"kProposalCellBtnNotApprove", @"否决") forState:UIControlStateNormal];
        [_btnReject setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
        _btnReject.titleLabel.font = [UIFont systemFontOfSize:16.0];
        _btnReject.userInteractionEnabled = YES;
        _btnReject.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        [_btnReject addTarget:vc action:@selector(onButtonClicked_Reject:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_btnReject];
        
//        _btnDelete = [UIButton buttonWithType:UIButtonTypeCustom];
//        _btnDelete.backgroundColor = [UIColor clearColor];
//        [_btnDelete setTitle:NSLocalizedString(@"kProposalCellBtnDelete", @"删除") forState:UIControlStateNormal];
//        [_btnDelete setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
//        _btnDelete.titleLabel.font = [UIFont systemFontOfSize:16.0];
//        _btnDelete.userInteractionEnabled = YES;
//        _btnDelete.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
//        [_btnDelete addTarget:vc action:@selector(onButtonClicked_Delete:) forControlEvents:UIControlEventTouchUpInside];
//        [self addSubview:_btnDelete];
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
    _btnApprove.tag = tag;
    _btnReject.tag = tag;
//    _btnDelete.tag = tag;
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
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fOffsetY = 0;
    CGFloat fCellWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    CGFloat fCellWidth30 = fCellWidth / 2.0f;
    
    _btnApprove.frame = CGRectMake(xOffset, fOffsetY, fCellWidth30, fCellHeight);
    _btnReject.frame = CGRectMake(xOffset + fCellWidth30, fOffsetY, fCellWidth30, fCellHeight);
//    _btnDelete.frame = CGRectMake(xOffset + fCellWidth30 * 2, fOffsetY, fCellWidth30, fCellHeight);
}

@end
