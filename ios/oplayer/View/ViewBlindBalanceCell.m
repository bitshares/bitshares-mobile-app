//
//  ViewBlindBalanceCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewBlindBalanceCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"
#import "Extension.h"

@interface ViewBlindBalanceCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbObjectID;            //  ID
    
    UILabel*        _to_title;
    UILabel*        _to_value;
    UILabel*        _amount_title;
    UILabel*        _amount_value;
}

@end

@implementation ViewBlindBalanceCell

@synthesize item=_item;
@synthesize row;

- (void)dealloc
{
    _item = nil;
    
    _lbObjectID = nil;
    
    _to_title = nil;
    _to_value = nil;
    _amount_title = nil;
    _amount_value = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        //  第一行
        _lbObjectID = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:16] superview:self];
        _lbObjectID.textAlignment = NSTextAlignmentLeft;
        
        _to_title = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _to_value = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _to_title.textAlignment = NSTextAlignmentLeft;
        _to_value.textAlignment = NSTextAlignmentLeft;
        _to_value.lineBreakMode = NSLineBreakByTruncatingMiddle;
        
        _amount_title = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _amount_value = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _amount_title.textAlignment = NSTextAlignmentRight;
        _amount_value.textAlignment = NSTextAlignmentRight;
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
    if (self.editing) {
        xOffset += 38;
    }
    CGFloat yOffset = 4.0f;
    CGFloat fWidth = self.bounds.size.width - self.layoutMargins.left - xOffset;
    
    //  获取显示数据
    id decrypted_memo = [_item objectForKey:@"decrypted_memo"];
    assert(decrypted_memo);
    id amount = [decrypted_memo objectForKey:@"amount"];
    uint32_t check = [[decrypted_memo objectForKey:@"check"] unsignedIntValue];
    
    //  第一行 ID
    _lbObjectID.text = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellTitleReceiptName", @"%@. 收据 #%@"), @(self.row + 1),
                        [[[NSData dataWithBytes:&check length:sizeof(check)] hex_encode] uppercaseString]];
    _lbObjectID.textColor = self.editing && !self.selected ? theme.textColorNormal : theme.textColorMain;
    _lbObjectID.frame = CGRectMake(xOffset, yOffset, fWidth, 28.0f);
    
    yOffset += 28.0f;
    
    id asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[amount objectForKey:@"asset_id"]];
    assert(asset);
    id n_amount = [NSDecimalNumber decimalNumberWithMantissa:[[amount objectForKey:@"amount"] unsignedLongLongValue]
                                                    exponent:-[[asset objectForKey:@"precision"] integerValue]
                                                  isNegative:NO];
    
    NSString* real_to_key = [_item objectForKey:@"real_to_key"];
    NSString* alias_name = [ViewUtils genBlindAccountDisplayName:real_to_key];
    if (alias_name && ![alias_name isEqualToString:@""]) {
        _to_title.text = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellTitleReceiptAddrWithAliasName", @"地址(%@)"), alias_name];
    } else {
        _to_title.text = NSLocalizedString(@"kVcStCellTitleReceiptAddr", @"地址");
    }
    _to_value.text = real_to_key;
    
    _amount_title.text = NSLocalizedString(@"kVcStCellTitleReceiptAmountValue", @"金额");
    _amount_value.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_amount usesGroupingSeparator:NO], asset[@"symbol"]];
    
    _to_title.textColor = theme.textColorGray;
    _to_value.textColor = theme.textColorNormal;
    _amount_title.textColor = theme.textColorGray;
    _amount_value.textColor = theme.textColorNormal;
    
    _to_title.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _amount_title.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    
    yOffset += 24.0f;
    
    _to_value.frame = CGRectMake(xOffset, yOffset, fWidth * 0.6, 24);
    _amount_value.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
}

@end
