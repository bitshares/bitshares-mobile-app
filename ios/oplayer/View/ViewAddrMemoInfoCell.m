//
//  ViewAddrMemoInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-19.
//
//

#import "ViewAddrMemoInfoCell.h"
#import "ThemeManager.h"
#import "UIImage+Template.h"

@interface ViewAddrMemoInfoCell ()
{
    UILabel*            _lbTitleText;
    UILabel*            _lbValueText;
}

@end

@implementation ViewAddrMemoInfoCell


- (void)dealloc
{
    _lbValueText = nil;
    _lbTitleText = nil;
}

- (id)initWithTitleText:(NSString*)titleText valueText:(NSString*)valueText
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        // Initialization code
        
        _lbValueText = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbValueText.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbValueText.font = [UIFont systemFontOfSize:16];
        _lbValueText.text = valueText;
        _lbValueText.textAlignment = NSTextAlignmentCenter;
        _lbValueText.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self addSubview:_lbValueText];
        
        _lbTitleText = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTitleText.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
        _lbTitleText.font = [UIFont boldSystemFontOfSize:16];
        _lbTitleText.text = titleText;
        _lbTitleText.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_lbTitleText];
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
    
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fCellWidth = self.bounds.size.width - fOffsetX * 2;
    
    CGFloat fTopOffset = 10.0f;
    CGFloat fLineHeight = 24.0f;
    
    _lbValueText.frame = CGRectMake(fOffsetX, fTopOffset, fCellWidth, fLineHeight);
    _lbTitleText.frame = CGRectMake(fOffsetX, fTopOffset + fLineHeight, fCellWidth, fLineHeight);
}

@end
