//
//  ViewCheckBox.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewCheckBox.h"
#import "ViewUtils.h"
#import "UIImage+Template.h"
#import "ThemeManager.h"

@interface ViewCheckBox()
{
    UIImageView*    _iconUnchecked;
    UIImageView*    _iconChecked;
}

@end

@implementation ViewCheckBox

- (void)dealloc
{
    _iconUnchecked = nil;
    _iconChecked = nil;
    _labelTitle = nil;
}

- (id)initWithFrame:(CGRect)rect
{
    self = [super initWithFrame:rect];
    if (self) {
        _labelTitle = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _labelTitle.textAlignment = NSTextAlignmentLeft;
        _iconUnchecked = [[UIImageView alloc] initWithImage:[UIImage templateImageNamed:@"iconUnchecked"]];
        _iconChecked = [[UIImageView alloc] initWithImage:[UIImage templateImageNamed:@"iconChecked"]];
        [self addSubview:_iconUnchecked];
        [self addSubview:_iconChecked];
        self.isChecked = NO;
    }
    return self;
}

- (void)setIsChecked:(BOOL)isChecked
{
    _isChecked = isChecked;
    _iconChecked.hidden = !isChecked;
    _iconUnchecked.hidden = isChecked;
}

- (void)setColorForChecked:(UIColor *)colorForChecked
{
    _colorForChecked = colorForChecked;
    _iconChecked.tintColor = colorForChecked;
}

- (void)setColorForUnchecked:(UIColor *)colorForUnchecked
{
    _colorForUnchecked = colorForUnchecked;
    _iconUnchecked.tintColor = colorForUnchecked;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    if (_iconChecked && _iconUnchecked && _labelTitle) {
        CGFloat h = frame.size.height;
        CGSize icon_size = CGSizeMake(14, 14);// _iconUnchecked.image.size;
        CGRect icon_rect = CGRectMake(0, (h - icon_size.height) / 2.0f, icon_size.width, icon_size.height);
        _iconUnchecked.frame = icon_rect;
        _iconChecked.frame = icon_rect;
        _labelTitle.frame = CGRectMake(icon_size.width + 4, 0, frame.size.width - (icon_size.width + 4), h);
    }
}

@end

