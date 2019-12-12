//
//  ViewOtcMcMerchantBasicCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "VCBase.h"
#import "ViewOtcMcMerchantBasicCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewOtcMcMerchantBasicCell()
{
    NSDictionary*   _item;
    
    UILabel*        _imageHeader;
    
    UILabel*        _lbUsername;
    UILabel*        _lbStatus;
    UILabel*        _lbDate;
}

@end

@implementation ViewOtcMcMerchantBasicCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _imageHeader = nil;
    
    _lbUsername = nil;
    _lbStatus = nil;
    _lbDate = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _item = nil;
        
        _imageHeader = [self auxGenLabel:[UIFont systemFontOfSize:20]];
        _imageHeader.textAlignment = NSTextAlignmentCenter;
        
        _lbUsername = [self auxGenLabel:[UIFont boldSystemFontOfSize:15]];
        
        _lbStatus = [self auxGenLabel:[UIFont systemFontOfSize:12]];
        _lbStatus.layer.borderWidth = 1;
        _lbStatus.layer.cornerRadius = 2;
        _lbStatus.layer.masksToBounds = YES;
        _lbStatus.textAlignment = NSTextAlignmentCenter;
        
        _lbDate = [self auxGenLabel:[UIFont systemFontOfSize:13]];
//        _lbDate.textAlignment = NSTextAlignmentRight;
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
    
    if (!_item)
        return;
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];

    CGFloat fWidth = self.bounds.size.width;

    //  header
    CGFloat fOffsetY = 8.0f;
    CGFloat fOffsetX = self.layoutMargins.left;
//    CGFloat fLineHeight = 20.0f;
    CGFloat fDiameter = 40.0f;
    
    //  UI - 第一行 头像
    NSString* merchantName = [_item objectForKey:@"nickname"];
    _imageHeader.layer.cornerRadius = fDiameter / 2.0f;
    _imageHeader.layer.backgroundColor = theme.textColorHighlight.CGColor;
    _imageHeader.text = [merchantName substringToIndex:1];
    _imageHeader.frame = CGRectMake(fOffsetX, fOffsetY, fDiameter, fDiameter);
    
    //  UI - 第一行 商家名字
    _lbUsername.text = merchantName;
    _lbUsername.frame = CGRectMake(fOffsetX + fDiameter + 8, fOffsetY + 2, fWidth, 20.0f);
    
    _lbDate.text = [OtcManager fmtMerchantTime:[_item objectForKey:@"ctime"]];
    _lbDate.textColor = theme.textColorNormal;
    _lbDate.frame = CGRectMake(fOffsetX + fDiameter + 8, fOffsetY + 2 + 20.0f, fWidth, 20.0f);
    
    _lbStatus.text = @"已认证";
    _lbStatus.textColor = theme.textColorMain;
    UIColor* backColor = theme.textColorHighlight;
    _lbStatus.layer.borderColor = backColor.CGColor;
    _lbStatus.layer.backgroundColor = backColor.CGColor;
    CGSize size1 = [self auxSizeWithText:_lbUsername.text font:_lbUsername.font maxsize:CGSizeMake(fWidth, 9999)];
    CGSize size2 = [self auxSizeWithText:_lbStatus.text font:_lbStatus.font maxsize:CGSizeMake(fWidth, 9999)];
    CGFloat h = size2.height + 2;
    _lbStatus.frame = CGRectMake(fOffsetX + fDiameter + 8 + size1.width + 4, fOffsetY + 2 + (20 - h) / 2.0f, size2.width + 8, h);
}

@end
