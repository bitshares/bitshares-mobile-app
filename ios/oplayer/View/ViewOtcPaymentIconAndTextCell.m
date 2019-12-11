//
//  ViewOtcPaymentIconAndTextCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewOtcPaymentIconAndTextCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "OtcManager.h"

@interface ViewOtcPaymentIconAndTextCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbTitle;
    UIImageView*    _iconType;          //  类型图标
    UILabel*        _lbNameAndAccount;  //  收款方式+账号信息
}

@end

@implementation ViewOtcPaymentIconAndTextCell

@synthesize userType;
@synthesize bUserSell;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _iconType = nil;
    _lbTitle = nil;
    _lbNameAndAccount = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        self.userType = eout_normal_user;
        self.bUserSell = NO;
        _iconType = nil;
        _lbTitle = [self auxGenLabel:[UIFont boldSystemFontOfSize:13]];
        _lbNameAndAccount = [self auxGenLabel:[UIFont systemFontOfSize:13]];
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
    
    id pminfos = [OtcManager auxGenPaymentMethodInfos:_item[@"payAccount"]
                                                 type:_item[@"payChannel"]
                                             bankname:nil];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fHeight = self.bounds.size.height;
    
    if (!_iconType) {
        _iconType = [[UIImageView alloc] initWithImage:[UIImage imageNamed:pminfos[@"icon"]]];
        [self addSubview:_iconType];
    }
    
    if (self.userType == eout_normal_user) {
        _lbTitle.text = self.bUserSell ? NSLocalizedString(@"kOtcAdCellLabelTitleReceiveMethod", @"收款方式") : NSLocalizedString(@"kOtcAdCellLabelTitlePaymentMethod", @"付款方式");
    } else {
        _lbTitle.text = self.bUserSell ? NSLocalizedString(@"kOtcAdCellLabelTitlePaymentMethod", @"付款方式") : NSLocalizedString(@"kOtcAdCellLabelTitleReceiveMethod", @"收款方式");
    }
    
    _lbTitle.textColor = theme.textColorNormal;
    _lbTitle.frame = CGRectMake(xOffset, 0, fWidth, fHeight);

  
    _lbNameAndAccount.text = pminfos[@"name_with_short_account"];
    _lbNameAndAccount.textColor = theme.textColorMain;
    
    CGSize size = [self auxSizeWithText:_lbNameAndAccount.text font:_lbNameAndAccount.font maxsize:CGSizeMake(fWidth, 9999)];
    _lbNameAndAccount.frame = CGRectMake(self.bounds.size.width - xOffset - size.width, 0, size.width, fHeight);
    
    _iconType.frame = CGRectMake(_lbNameAndAccount.frame.origin.x - 24.0f, (fHeight - 16) / 2.0f, 16, 16);
}

@end
