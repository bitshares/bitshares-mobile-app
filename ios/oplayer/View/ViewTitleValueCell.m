//
//  ViewTitleValueCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewTitleValueCell.h"

#import "ThemeManager.h"

@interface ViewTitleValueCell()
{
    UILabel*        _titleLabel;
    UILabel*        _valueLabel;
}

@end

@implementation ViewTitleValueCell

@synthesize titleLabel=_titleLabel;
@synthesize valueLabel=_valueLabel;

- (void)dealloc
{
    _titleLabel = nil;
    _valueLabel = nil;
}

- (id)init
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _titleLabel.textAlignment = NSTextAlignmentLeft;
        _titleLabel.numberOfLines = 1;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont fontWithName:@"Helvetica" size:12.0f];
        _titleLabel.textColor = theme.textColorNormal;
        [self addSubview:_titleLabel];
        
        _valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _valueLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _valueLabel.textAlignment = NSTextAlignmentRight;
        _valueLabel.numberOfLines = 1;
        _valueLabel.backgroundColor = [UIColor clearColor];
        _valueLabel.font = [UIFont fontWithName:@"Helvetica" size:12.0f];
        _valueLabel.textColor = theme.textColorMain;
        [self addSubview:_valueLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize size = self.bounds.size;
    CGFloat fOffsetX = self.layoutMargins.left;
    
    _titleLabel.frame = CGRectMake(fOffsetX, 0, size.width - fOffsetX * 2, size.height);
    _valueLabel.frame = CGRectMake(fOffsetX, 0, size.width - fOffsetX * 2, size.height);
}

@end
