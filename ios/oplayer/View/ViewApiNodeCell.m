//
//  ViewApiNodeCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewApiNodeCell.h"

#import "ThemeManager.h"
#import "NativeAppDelegate.h"

@interface ViewApiNodeCell()
{
    UILabel*    _lbName;
    UILabel*    _lbCustomLabel;
    
    UILabel*    _lbUrl;
}

@end

@implementation ViewApiNodeCell

- (void)dealloc
{
    _lbName = nil;
    _lbCustomLabel = nil;
    _lbUrl = nil;
    
    _item = nil;
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
        
        _lbName = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:16] superview:self];
        _lbName.textAlignment = NSTextAlignmentLeft;
        _lbName.textColor = theme.textColorMain;
        
        UIColor* backColor = theme.textColorHighlight;
        _lbCustomLabel = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:12] superview:self];
        _lbCustomLabel.backgroundColor = [UIColor clearColor];
        _lbCustomLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbCustomLabel.layer.borderWidth = 1;
        _lbCustomLabel.layer.cornerRadius = 2;
        _lbCustomLabel.layer.masksToBounds = YES;
        _lbCustomLabel.layer.borderColor = backColor.CGColor;
        _lbCustomLabel.layer.backgroundColor = backColor.CGColor;
        _lbCustomLabel.text = NSLocalizedString(@"kSettingApiCellCustomFlag", @"自定义");
        
        _lbUrl = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _lbUrl.textAlignment = NSTextAlignmentLeft;
        _lbUrl.textColor = theme.textColorNormal;
    }
    return self;
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
    
    CGSize size = self.bounds.size;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fWidth = size.width - fOffsetX * 2;
    CGFloat fHeight = 28.0f;
    
    NSString* namekey = [_item objectForKey:@"namekey"];
    if (namekey && ![namekey isEqualToString:@""]) {
        _lbName.text = NSLocalizedString(namekey, @"node location");
    } else {
        _lbName.text = [_item objectForKey:@"location"] ?: [_item objectForKey:@"name"];
    }
    _lbUrl.text = [_item objectForKey:@"url"];
    
    if ([[_item objectForKey:@"_is_custom"] boolValue]) {
        _lbCustomLabel.hidden = NO;
        CGSize size1 = [ViewUtils auxSizeWithLabel:_lbName];
        CGSize size2 = [ViewUtils auxSizeWithLabel:_lbCustomLabel];
        _lbCustomLabel.frame = CGRectMake(fOffsetX + size1.width + 4,
                                          (fHeight - size2.height - 2)/2,
                                          size2.width + 8,
                                          size2.height + 2);
    } else {
        _lbCustomLabel.hidden = YES;
    }
    
    _lbName.frame = CGRectMake(fOffsetX, 0, fWidth, fHeight);
    _lbUrl.frame = CGRectMake(fOffsetX, fHeight, fWidth, 24);
}

@end
