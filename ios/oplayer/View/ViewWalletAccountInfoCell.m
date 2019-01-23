//
//  ViewWalletAccountInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewWalletAccountInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "WalletManager.h"

@interface ViewWalletAccountInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbAccountName;
    UILabel*        _lbCurrentFlag;
    
    UILabel*        _lbFlagOwner;
    UILabel*        _lbFlagActive;
    UILabel*        _lbFlagMemo;
}

@end

@implementation ViewWalletAccountInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbAccountName = nil;
    _lbCurrentFlag = nil;
    
    _lbFlagOwner = nil;
    _lbFlagActive = nil;
    _lbFlagMemo = nil;
}

- (UILabel*)genFlagLabel
{
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
    UIColor* backColor = [ThemeManager sharedThemeManager].textColorHighlight;
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [ThemeManager sharedThemeManager].textColorMain;
    label.font = [UIFont boldSystemFontOfSize:12];
    label.layer.borderWidth = 1;
    label.layer.cornerRadius = 2;
    label.layer.masksToBounds = YES;
    label.layer.borderColor = backColor.CGColor;
    label.layer.backgroundColor = backColor.CGColor;
    [self addSubview:label];
    return label;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _lbAccountName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAccountName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAccountName.textAlignment = NSTextAlignmentLeft;
        _lbAccountName.numberOfLines = 1;
        _lbAccountName.backgroundColor = [UIColor clearColor];
        _lbAccountName.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbAccountName.font = [UIFont boldSystemFontOfSize:18];
        [self addSubview:_lbAccountName];
        
        _lbCurrentFlag = [[UILabel alloc] initWithFrame:CGRectZero];
        UIColor* backColor = [ThemeManager sharedThemeManager].textColorHighlight;
        _lbCurrentFlag.textAlignment = NSTextAlignmentCenter;
        _lbCurrentFlag.backgroundColor = [UIColor clearColor];
        _lbCurrentFlag.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbCurrentFlag.font = [UIFont boldSystemFontOfSize:12];
        _lbCurrentFlag.layer.borderWidth = 1;
        _lbCurrentFlag.layer.cornerRadius = 2;
        _lbCurrentFlag.layer.masksToBounds = YES;
        _lbCurrentFlag.layer.borderColor = backColor.CGColor;
        _lbCurrentFlag.layer.backgroundColor = backColor.CGColor;
        [self addSubview:_lbCurrentFlag];
        
        _lbFlagOwner = [self genFlagLabel];
        _lbFlagActive = [self genFlagLabel];
        _lbFlagMemo = [self genFlagLabel];
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
    
    BOOL bLocked = [[_item objectForKey:@"locked"] boolValue];
    CGFloat xOffset = self.layoutMargins.left;
    CGFloat fWidth = self.bounds.size.width;
    CGFloat fCellWidth = fWidth - xOffset * 2;
    
    //  header
    CGFloat fOffsetY = 0.0f;
    CGFloat fLineHeight = bLocked ? self.bounds.size.height : 28;
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
  
    //  第一行
    BOOL isCurrent = [[_item objectForKey:@"current"] boolValue];
    _lbAccountName.text = [_item objectForKey:@"name"];
    _lbAccountName.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    if (isCurrent){
        _lbAccountName.textColor = theme.textColorMain;
        _lbAccountName.font = [UIFont boldSystemFontOfSize:19];
        _lbCurrentFlag.hidden = NO;
        _lbCurrentFlag.text = NSLocalizedString(@"kWalletCellCurrentAccount", @"当前账号");
        CGSize size1 = [self auxSizeWithText:_lbAccountName.text font:_lbAccountName.font maxsize:CGSizeMake(fWidth, 9999)];
//        CGFloat width = fmin(size1.width, fCellWidth - 100);
        CGSize size2 = [self auxSizeWithText:_lbCurrentFlag.text font:_lbCurrentFlag.font maxsize:CGSizeMake(fWidth, 9999)];
        _lbCurrentFlag.frame = CGRectMake(xOffset + size1.width + 4,
                                          fOffsetY + (fLineHeight - size2.height - 2)/2,
                                          size2.width + 8, size2.height + 2);
    }else{
        _lbAccountName.textColor = theme.textColorNormal;
        _lbAccountName.font = [UIFont boldSystemFontOfSize:15];
        _lbCurrentFlag.hidden = YES;
    }
    fOffsetY += fLineHeight;
    
    //  第二行 - 权限
    if (bLocked){
        _lbFlagOwner.hidden = YES;
        _lbFlagActive.hidden = YES;
        _lbFlagMemo.hidden = YES;
    }else{
        _lbFlagOwner.hidden = NO;
        _lbFlagActive.hidden = NO;
        _lbFlagMemo.hidden = NO;
        _lbFlagOwner.text = NSLocalizedString(@"kWalletCellPermissionOwner", @"账号权限");
        _lbFlagActive.text = NSLocalizedString(@"kWalletCellPermissionActive", @"资金权限");
        _lbFlagMemo.text = NSLocalizedString(@"kWalletCellPermissionMemo", @"备注权限");
        //  账号权限 着色
        UIColor* borderColor = nil;
        UIColor* backColor = nil;
        UIColor* textColor = nil;
        EAccountPermissionStatus owner_status = (EAccountPermissionStatus)[[_item objectForKey:@"owner_status"] integerValue];
        EAccountPermissionStatus active_status = (EAccountPermissionStatus)[[_item objectForKey:@"active_status"] integerValue];
        if (owner_status == EAPS_ENOUGH_PERMISSION || owner_status == EAPS_FULL_PERMISSION){
            borderColor = theme.textColorHighlight;
            backColor = theme.textColorHighlight;
            textColor = theme.textColorMain;
        }else if (owner_status == EAPS_PARTIAL_PERMISSION){
            borderColor = theme.textColorHighlight;
            backColor = [UIColor clearColor];
            textColor = theme.textColorMain;
        }else{
            borderColor = theme.textColorGray;
            backColor = [UIColor clearColor];
            textColor = theme.textColorGray;
        }
        _lbFlagOwner.textColor = textColor;
        _lbFlagOwner.layer.borderColor = borderColor.CGColor;
        _lbFlagOwner.layer.backgroundColor = backColor.CGColor;
        //  资金权限-着色
        if (active_status == EAPS_ENOUGH_PERMISSION || active_status == EAPS_FULL_PERMISSION){
            borderColor = theme.textColorHighlight;
            backColor = theme.textColorHighlight;
            textColor = theme.textColorMain;
        }else if (active_status == EAPS_PARTIAL_PERMISSION){
            borderColor = theme.textColorHighlight;
            backColor = [UIColor clearColor];
            textColor = theme.textColorMain;
        }else{
            borderColor = theme.textColorGray;
            backColor = [UIColor clearColor];
            textColor = theme.textColorGray;
        }
        _lbFlagActive.textColor = textColor;
        _lbFlagActive.layer.borderColor = borderColor.CGColor;
        _lbFlagActive.layer.backgroundColor = backColor.CGColor;
        //  备注权限-着色
        if ([[_item objectForKey:@"haveMemoPermission"] boolValue]){
            borderColor = theme.textColorHighlight;
            backColor = theme.textColorHighlight;
            textColor = theme.textColorMain;
        }else{
            borderColor = theme.textColorGray;
            backColor = [UIColor clearColor];
            textColor = theme.textColorGray;
        }
        _lbFlagMemo.textColor = textColor;
        _lbFlagMemo.layer.borderColor = borderColor.CGColor;
        _lbFlagMemo.layer.backgroundColor = backColor.CGColor;
        
        //  布局
        CGSize size1 = [self auxSizeWithText:_lbFlagOwner.text font:_lbFlagOwner.font maxsize:CGSizeMake(fWidth, 9999)];
        CGSize size2 = [self auxSizeWithText:_lbFlagActive.text font:_lbFlagActive.font maxsize:CGSizeMake(fWidth, 9999)];
        CGSize size3 = [self auxSizeWithText:_lbFlagMemo.text font:_lbFlagMemo.font maxsize:CGSizeMake(fWidth, 9999)];
        _lbFlagOwner.frame = CGRectMake(xOffset,
                                        fOffsetY + (fLineHeight - size1.height - 2)/2, size1.width + 8, size1.height + 2);
        _lbFlagActive.frame = CGRectMake(_lbFlagOwner.frame.origin.x + _lbFlagOwner.frame.size.width + 8,
                                         fOffsetY + (fLineHeight - size2.height - 2)/2, size2.width + 8, size2.height + 2);
        _lbFlagMemo.frame = CGRectMake(_lbFlagActive.frame.origin.x + _lbFlagActive.frame.size.width + 8,
                                       fOffsetY + (fLineHeight - size3.height - 2)/2, size3.width + 8, size3.height + 2);
    }
}

@end
