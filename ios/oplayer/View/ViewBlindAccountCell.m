//
//  ViewBlindAccountCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewBlindAccountCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"
#import "Extension.h"

@interface ViewBlindAccountCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbObjectID;            //  ID
    UILabel*        _to_value;
}

@end

@implementation ViewBlindAccountCell

@synthesize item=_item;
@synthesize row;

- (void)dealloc
{
    _item = nil;
    
    _lbObjectID = nil;
    _to_value = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _lbObjectID = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:16] superview:self];
        _lbObjectID.textAlignment = NSTextAlignmentLeft;
        
        _to_value = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _to_value.textAlignment = NSTextAlignmentLeft;
        _to_value.lineBreakMode = NSLineBreakByTruncatingMiddle;
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

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!_item){
        return;
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.layoutMargins.left;
    CGFloat yOffset = 4.0f;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    
    //  获取显示数据
    NSString* parent_key = [_item objectForKey:@"parent_key"];
    BOOL bChildAccount = parent_key && ![parent_key isEqualToString:@""];
    
    //  第一行 ID
    if (bChildAccount) {
        //  子账号
        NSString* alias_name = [ViewUtils genBlindAccountDisplayName:[_item objectForKey:@"public_key"]];
        _lbObjectID.text = alias_name ?: @"";
        _lbObjectID.font = [UIFont systemFontOfSize:13];
        _lbObjectID.textColor = theme.textColorNormal;
    } else {
        //  主账号
        _lbObjectID.text = _item[@"alias_name"] ?: @"";
        _lbObjectID.font = [UIFont boldSystemFontOfSize:16];
        _lbObjectID.textColor = theme.textColorMain;
    }
    
    _lbObjectID.frame = CGRectMake(xOffset, yOffset, fWidth, 28.0f);
    
    yOffset += 28.0f;
    
    _to_value.text = [_item objectForKey:@"public_key"];
    _to_value.textColor = theme.textColorNormal;
    _to_value.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
}

@end
