//
//  ViewOtcPaymentMethodInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewOtcPaymentMethodInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "OtcManager.h"

@interface ViewOtcPaymentMethodInfoCell()
{
    NSDictionary*   _item;
    
    UIImageView*    _iconType;      //  类型图标
    UILabel*        _lbName;        //  收款方式名 or 银行卡名
    UILabel*        _lbStatus;      //  是否已开启状态
    UILabel*        _lbUserName;    //  用户姓名
    UILabel*        _lbAccount;     //  收款方式账号 or 银行卡号
}

@end

@implementation ViewOtcPaymentMethodInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _iconType = nil;
    _lbName = nil;
    _lbUserName = nil;
    _lbAccount = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _iconType = nil;
        _lbName = [self auxGenLabel:[UIFont boldSystemFontOfSize:16]];
        _lbStatus = [self auxGenLabel:[UIFont systemFontOfSize:15]];
        _lbStatus.textAlignment = NSTextAlignmentRight;
        _lbUserName = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbAccount = [self auxGenLabel:[UIFont systemFontOfSize:16]];
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
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 4;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fLineHeight = 28.0f;
    
    id pminfos = [OtcManager auxGenPaymentMethodInfos:_item[@"account"] type:_item[@"type"] bankname:_item[@"bankName"]];
    
    if (!_iconType) {
        _iconType = [[UIImageView alloc] initWithImage:[UIImage imageNamed:pminfos[@"icon"]]];
        [self addSubview:_iconType];
    }
    
    CGFloat iconOffset = 0.0f;
    if (_iconType) {
        _iconType.frame = CGRectMake(xOffset, yOffset + (fLineHeight - 16) / 2.0f, 16, 16);
        iconOffset = 16.0f + 6.0f;
    }
    _lbName.text = pminfos[@"name"];
    _lbName.frame = CGRectMake(xOffset + iconOffset, yOffset, fWidth, fLineHeight);
    _lbName.textColor = theme.textColorMain;
    
    if ([[_item objectForKey:@"status"] integerValue] == eopms_enable) {
        _lbStatus.text = NSLocalizedString(@"kOtcPmCellStatusEnabled", @"已开启");
        _lbStatus.textColor = theme.textColorHighlight;
    } else {
        _lbStatus.text = NSLocalizedString(@"kOtcPmCellStatusDisabled", @"未开启");
        _lbStatus.textColor = theme.textColorGray;
    }

    _lbStatus.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    _lbUserName.text = [_item objectForKey:@"realName"] ?: @"";
    _lbUserName.frame = CGRectMake(xOffset, yOffset + 1, fWidth, fLineHeight);
    _lbUserName.textColor = theme.textColorNormal;
    yOffset += fLineHeight;
    
    _lbAccount.text = [_item objectForKey:@"account"];
    _lbAccount.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbAccount.textColor = theme.textColorMain;
}

@end
