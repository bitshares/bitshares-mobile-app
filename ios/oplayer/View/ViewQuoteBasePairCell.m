//
//  ViewQuoteBasePairCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "VCBase.h"
#import "ViewQuoteBasePairCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewQuoteBasePairCell()
{
    __weak VCBase*  _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    NSDictionary*   _item;
    
    UIView*         _viewQuote;
    UIView*         _viewBase;
    
    UILabel*        _lbQuoteTitle;
    UILabel*        _lbQuoteValue;
    
    UIButton*       _btnSwitch;
    
    UILabel*        _lbBaseTitle;
    UILabel*        _lbBaseValue;
}

@end

@implementation ViewQuoteBasePairCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _viewQuote = nil;
    _viewBase = nil;
    
    _lbQuoteTitle = nil;
    _lbQuoteValue = nil;
    
    _btnSwitch = nil;
    
    _lbBaseTitle = nil;
    _lbBaseValue = nil;
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
        
        _viewQuote = [[UIView alloc] initWithFrame:CGRectZero];
        _viewBase = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:_viewQuote];
        [self addSubview:_viewBase];
        
        _lbQuoteTitle = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:_viewQuote];
        _lbQuoteValue = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:16.0f] superview:_viewQuote];
        _lbQuoteTitle.textAlignment = NSTextAlignmentLeft;
        _lbQuoteValue.textAlignment = NSTextAlignmentLeft;
        
        _lbBaseTitle = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:_viewBase];
        _lbBaseValue = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:16.0f] superview:_viewBase];
        _lbBaseTitle.textAlignment = NSTextAlignmentRight;
        _lbBaseValue.textAlignment = NSTextAlignmentRight;
        
        assert(vc);
        
        UITapGestureRecognizer* kQuoteTapped = [[UITapGestureRecognizer alloc] initWithTarget:vc action:@selector(onButtonClicked_Quote)];
        [_viewQuote addGestureRecognizer:kQuoteTapped];
        _viewQuote.userInteractionEnabled = YES;
        
        UITapGestureRecognizer* kBaseTapped = [[UITapGestureRecognizer alloc] initWithTarget:vc action:@selector(onButtonClicked_Base)];
        [_viewBase addGestureRecognizer:kBaseTapped];
        _viewBase.userInteractionEnabled = YES;
        
        _btnSwitch = [UIButton buttonWithType:UIButtonTypeSystem];
        _btnSwitch.backgroundColor = [UIColor clearColor];
        _btnSwitch.titleLabel.font = [UIFont systemFontOfSize:13.0f];
        _btnSwitch.userInteractionEnabled = YES;
        _btnSwitch.tintColor = theme.textColorMain;
        [_btnSwitch setImage:[UIImage templateImageNamed:@"iconSwitch"] forState:UIControlStateNormal];
        [_btnSwitch addTarget:vc action:@selector(onButtonClicked_Switched:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_btnSwitch];
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
    
    _lbQuoteTitle.text = NSLocalizedString(@"kLabelTitleAssetQuote", @"交易资产");
    _lbQuoteTitle.textColor = theme.textColorGray;
    
    _lbBaseTitle.text = NSLocalizedString(@"kLabelTitleAssetBase", @"报价资产");
    _lbBaseTitle.textColor = theme.textColorGray;
    
    //    _viewQuote.backgroundColor = [UIColor greenColor];
    //    _viewBase.backgroundColor = [UIColor greenColor];
    //    _btnSwitch.backgroundColor = [UIColor redColor];
    
    id quote = [_item objectForKey:@"quote"];
    id base = [_item objectForKey:@"base"];
    if (quote) {
        _lbQuoteValue.text = [quote objectForKey:@"symbol"];
        _lbQuoteValue.textColor = theme.textColorMain;
    } else {
        _lbQuoteValue.text = @"--";
        _lbQuoteValue.textColor = theme.textColorNormal;
    }
    
    if (base) {
        _lbBaseValue.text = [base objectForKey:@"symbol"];
        _lbBaseValue.textColor = theme.textColorMain;
    } else {
        _lbBaseValue.text = @"--";
        _lbBaseValue.textColor = theme.textColorNormal;
    }
    
    CGFloat width_quote = fWidth * 0.4f;
    CGFloat width_base = fWidth * 0.4f;
    CGFloat width_switch = fWidth * 0.2f;
    
    _viewQuote.frame = CGRectMake(fOffsetX, fOffsetY, width_quote, fLineHeight * 2);
    _viewBase.frame = CGRectMake(fOffsetX + width_quote + width_switch, fOffsetY, width_base, fLineHeight * 2);
    _btnSwitch.frame = CGRectMake(fOffsetX + width_quote, fOffsetY, width_switch, fLineHeight * 2);
    
    _lbQuoteTitle.frame = CGRectMake(0, 0, width_quote, fLineHeight);
    _lbBaseTitle.frame = CGRectMake(0, 0, width_base, fLineHeight);
    
    _lbQuoteValue.frame = CGRectMake(0, fLineHeight, width_quote, fLineHeight);
    _lbBaseValue.frame = CGRectMake(0, fLineHeight, width_base, fLineHeight);
}

@end
