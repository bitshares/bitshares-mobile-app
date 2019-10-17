//
//  ViewSecTipsLineCell.m
//  oplayer
//
//  Created by SYALON on 13-12-19.
//
//

#import "ViewSecTipsLineCell.h"
#import "ThemeManager.h"

@interface ViewSecTipsLineCell ()
{
    UILabel*    _lbText;
}

@end

@implementation ViewSecTipsLineCell


- (void)dealloc
{
    _lbText = nil;
}

- (id)init
{
    self = [self initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        // Initialization code
        
        _lbText = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbText.textColor = [ThemeManager sharedThemeManager].sellColor;
        _lbText.font = [UIFont boldSystemFontOfSize:13];
        _lbText.text = NSLocalizedString(@"kProposalTipsSecTipCannotApprove", @"风险提示：该提案由陌生账号创建，不可批准。");
        _lbText.textAlignment = NSTextAlignmentLeft;
        _lbText.numberOfLines = 2;
        _lbText.lineBreakMode = NSLineBreakByCharWrapping;
        [self addSubview:_lbText];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    
    CGSize size = [self auxSizeWithText:_lbText.text font:_lbText.font maxsize:CGSizeMake(fWidth, 9999)];
    _lbText.frame = CGRectMake(xOffset, 6, fWidth, size.height);
}

@end
