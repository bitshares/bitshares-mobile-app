//
//  ViewOtcOrderDetailStatus.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewOtcOrderDetailStatus.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "UIImage+Template.h"
#import "OtcManager.h"

@interface ViewOtcOrderDetailStatus()
{
    NSDictionary*   _item;
    
    UILabel*        _lbStatusName;
    UILabel*        _lbStatusDesc;
    UIImageView*    _imgPhone;
    UILabel*        _lbPhone;
}

@end

@implementation ViewOtcOrderDetailStatus

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbStatusName = nil;
    _lbStatusDesc = nil;
    _imgPhone = nil;
    _lbPhone = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _lbStatusName = [self auxGenLabel:[UIFont boldSystemFontOfSize:30]];
        _lbStatusDesc = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        //  TODO:2.9 icon
        _imgPhone = [[UIImageView alloc] initWithImage:[UIImage templateImageNamed:@"paysuccess"]];
        [self addSubview:_imgPhone];
        _lbPhone = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbPhone.textAlignment = NSTextAlignmentRight;
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
    
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fWidth  = self.bounds.size.width - 2 * fOffsetX;
    
    _lbStatusName.text = _item[@"main"];
    _lbStatusDesc.text = _item[@"desc"];
    
    _lbStatusName.frame = CGRectMake(fOffsetX, 0, fWidth, 48);
    _lbStatusDesc.frame = CGRectMake(fOffsetX, 48, fWidth, 20);
        
    //  TODO:2.9
    CGFloat fPhoneSize = 40.0f;
    _lbPhone.text = @"联系对方";//_item[@"phone"] TODO:2.9
    _lbPhone.frame = CGRectMake(fOffsetX, 48, fWidth, 20);
    CGSize size = [self auxSizeWithText:_lbPhone.text font:_lbPhone.font maxsize:CGSizeMake(fWidth, 9999)];
    _imgPhone.tintColor = theme.textColorMain;
    _imgPhone.frame = CGRectMake(self.bounds.size.width - fPhoneSize - fOffsetX - fmaxf(size.width - fPhoneSize, 0) / 2.0f,
                                 (48 - fPhoneSize) / 2.0f, fPhoneSize, fPhoneSize);
}

@end
