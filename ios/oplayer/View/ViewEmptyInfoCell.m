//
//  ViewEmptyInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-19.
//
//

#import "ViewEmptyInfoCell.h"
#import "ThemeManager.h"
#import "UIImage+Template.h"

@interface ViewEmptyInfoCell ()
{
}

@end

@implementation ViewEmptyInfoCell


- (void)dealloc
{
    _imgIcon = nil;
    _lbText = nil;
}

- (id)initWithText:(NSString*)pText iconName:(NSString*)iconName
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.userInteractionEnabled = NO;
        // Initialization code
        
        //  图标
        if (iconName){
            _imgIcon = [[UIImageView alloc] initWithImage:[UIImage templateImageNamed:iconName]];
            _imgIcon.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
            [self addSubview:_imgIcon];
        }else{
            _imgIcon = nil;
        }
        
        //  文字
        _lbText = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbText.textAlignment = NSTextAlignmentLeft;
        _lbText.textColor = [ThemeManager sharedThemeManager].textColorGray;
        _lbText.font = [UIFont systemFontOfSize:14];
        _lbText.text = pText;
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
    
    CGFloat fCellWidth = self.bounds.size.width;
    CGFloat fCellHeight = self.bounds.size.height;
    
    if (_imgIcon){
        CGSize textSize = [self auxSizeWithText:_lbText.text font:_lbText.font maxsize:CGSizeMake(fCellWidth, 9999)];
        CGFloat fIconWidth = _imgIcon.image.size.width;
        CGFloat fIconHeight = _imgIcon.image.size.height;
        
        CGFloat xoffset = (fCellWidth - (textSize.width + fIconWidth + 4)) / 2.0f;
        
        _imgIcon.frame = CGRectMake(xoffset, (fCellHeight - fIconHeight) / 2.0f, fIconWidth, fIconHeight);
        _lbText.frame = CGRectMake(xoffset + fIconWidth + 4, (fCellHeight - textSize.height) / 2.0f, textSize.width, textSize.height);
    }else{
        _lbText.frame = CGRectMake(0, 0, fCellWidth, fCellHeight);
        _lbText.textAlignment = NSTextAlignmentCenter;
    }
}

@end
