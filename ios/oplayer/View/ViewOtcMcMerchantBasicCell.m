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
    __weak VCBase*  _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
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
        
        _imageHeader = [self auxGenLabel:[UIFont systemFontOfSize:14]];
        _imageHeader.textAlignment = NSTextAlignmentCenter;
        
        _lbUsername = [self auxGenLabel:[UIFont boldSystemFontOfSize:15]];
        
        _lbStatus = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbStatus.textAlignment = NSTextAlignmentRight;
        
        _lbDate = [self auxGenLabel:[UIFont systemFontOfSize:13]];
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
    CGFloat fDiameter = 24.0f;
    
    //  UI - 第一行 头像
    NSString* merchantName = [_item objectForKey:@"merchantNickname"];
    _imageHeader.layer.cornerRadius = fDiameter / 2.0f;
    _imageHeader.layer.backgroundColor = theme.textColorHighlight.CGColor;
    _imageHeader.text = [merchantName substringToIndex:1];
    _imageHeader.frame = CGRectMake(fOffsetX, fOffsetY, fDiameter, fDiameter);
    
    //  UI - 第一行 商家名字
    _lbUsername.text = merchantName;
    _lbUsername.frame = CGRectMake(fOffsetX + fDiameter + 8, fOffsetY, fWidth, 28.0f);
    
    _lbStatus.text = @"已认证";
    _lbStatus.frame = CGRectMake(0, fOffsetY, fWidth - fOffsetX, 28.0f);
    _lbStatus.textColor = theme.buyColor;
    
    //  TODO:2.9
    _lbDate.attributedText = [self genAndColorAttributedText:@"申请日期 "
                                                       value:[_item objectForKey:@"ctime"]
                                                  titleColor:theme.textColorGray
                                                  valueColor:theme.textColorNormal];
    _lbDate.frame = CGRectMake(fOffsetX + fDiameter + 8, fOffsetY + 28.0f, fWidth, 20.8f);
    
}

@end
