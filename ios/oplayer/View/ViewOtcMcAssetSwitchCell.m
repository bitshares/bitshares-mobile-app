//
//  ViewOtcMcAssetSwitchCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "VCBase.h"
#import "ViewOtcMcAssetSwitchCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewOtcMcAssetSwitchCell()
{
    __weak VCBase*  _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    NSDictionary*   _item;
    
    UILabel*        _lbFromTitle;
    UILabel*        _lbFromValue;
    
    UIButton*       _btnSwitch;
    
    UILabel*        _lbToTitle;
    UILabel*        _lbToValue;
}

@end

@implementation ViewOtcMcAssetSwitchCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbFromTitle = nil;
    _lbFromValue = nil;
    
    _btnSwitch = nil;
    
    _lbToTitle = nil;
    _lbToValue = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _item = nil;
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        _lbFromTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbFromValue = [self auxGenLabel:[UIFont systemFontOfSize:16.0f]];
        
        _lbToTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbToValue = [self auxGenLabel:[UIFont systemFontOfSize:16.0f]];
        _lbToTitle.textAlignment = NSTextAlignmentRight;
        _lbToValue.textAlignment = NSTextAlignmentRight;
        
        if (vc)
        {
            _btnSwitch = [UIButton buttonWithType:UIButtonTypeSystem];
            _btnSwitch.backgroundColor = [UIColor clearColor];
            _btnSwitch.titleLabel.font = [UIFont systemFontOfSize:13.0f];
            _btnSwitch.userInteractionEnabled = YES;
            _btnSwitch.tintColor = theme.textColorMain;
            [_btnSwitch setImage:[UIImage templateImageNamed:@"iconSwitch"] forState:UIControlStateNormal];
            [_btnSwitch addTarget:vc action:@selector(onButtonClicked_Switched:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_btnSwitch];
        }
        else
        {
            _btnSwitch = nil;
        }
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

    //  header
    CGFloat fOffsetY = 8.0f;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fWidth = self.bounds.size.width - 2 * fOffsetX;
    CGFloat fLineHeight = 28.0f;
    
    NSString* from;
    NSString* to;
    if ([[_item objectForKey:@"bFromIsMerchant"] boolValue]) {
        from = NSLocalizedString(@"kOtcMcAssetTransferFromToMerchantAccount", @"(商家账号)");
        to = NSLocalizedString(@"kOtcMcAssetTransferFromToUserAccount", @"(个人账号)");
    } else {
        to = NSLocalizedString(@"kOtcMcAssetTransferFromToMerchantAccount", @"(商家账号)");
        from = NSLocalizedString(@"kOtcMcAssetTransferFromToUserAccount", @"(个人账号)");
    }
    _lbFromTitle.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kOtcMcAssetTransferFromTitle", @"从 ")
                                                            value:from
                                                       titleColor:theme.textColorMain
                                                       valueColor:theme.textColorGray];
    _lbToTitle.attributedText = [self genAndColorAttributedText:NSLocalizedString(@"kOtcMcAssetTransferToTitle", @"到 ")
                                                          value:to
                                                     titleColor:theme.textColorMain
                                                     valueColor:theme.textColorGray];
    
    _lbFromValue.text = [_item objectForKey:@"from"];
    _lbToValue.text = [_item objectForKey:@"to"];;
    
    _lbFromTitle.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    _lbToTitle.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    if (_btnSwitch) {
        _btnSwitch.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight * 2);
    }
    
    fOffsetY += fLineHeight;
    
    _lbFromValue.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    _lbToValue.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
}

@end
