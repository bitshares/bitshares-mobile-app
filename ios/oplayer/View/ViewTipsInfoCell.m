//
//  ViewTipsInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewTipsInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "MyLabel.h"
#import "OrgUtils.h"

@interface ViewTipsInfoCell()
{
    MyLabel*        _label;
}

@end

@implementation ViewTipsInfoCell

- (void)dealloc
{
    _label = nil;
}

- (CGFloat)calcCellDynamicHeight:(CGFloat)leftOffset
{
    assert(_label);
    
    //  限制最低值
    leftOffset = MAX(leftOffset, 12);
    
    CGSize size = [self auxSizeWithText:_label.text font:_label.font
                                maxsize:CGSizeMake(self.bounds.size.width - leftOffset * 2 - 8, 9999)];
    
    return size.height + 16;
}

- (id)initWithText:(NSString*)pText
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        _label = [[MyLabel alloc] initWithFrame:CGRectZero];
        _label.textInsets = UIEdgeInsetsMake(4, 4, 4, 4);       //  可调整
        _label.lineBreakMode = NSLineBreakByWordWrapping;
        _label.textAlignment = NSTextAlignmentLeft;
        _label.numberOfLines = 0;
        _label.backgroundColor = [UIColor clearColor];
        _label.font = [UIFont systemFontOfSize:13];
        _label.text = pText;
        _label.textColor = [ThemeManager sharedThemeManager].textColorMain;
        
        [self addSubview:_label];
        
    }
    return self;
}

- (void)updateLabelText:(NSString*)text
{
    _label.text = text;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat fWidth = self.bounds.size.width;
    CGFloat xOffset = self.layoutMargins.left;
    
    _label.frame = CGRectMake(xOffset, 0, fWidth - xOffset * 2, self.bounds.size.height);
    
    //  TODO:fowallet 颜色
    UIColor* backColor = [ThemeManager sharedThemeManager].textColorGray;
    _label.layer.borderWidth = 1;
    _label.layer.cornerRadius = 0;
    _label.layer.masksToBounds = YES;
    _label.layer.borderColor = backColor.CGColor;
    _label.layer.backgroundColor = backColor.CGColor;
}

@end
