//
//  ViewOtcOrderDetailStatus.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//
#import "VCBase.h"
#import "ViewOtcOrderDetailStatus.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "UIImage+Template.h"
#import "OtcManager.h"

@interface ViewOtcOrderDetailStatus()
{
    __weak VCBase*  _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    NSDictionary*   _item;
    
    UILabel*        _lbStatusName;
    UILabel*        _lbStatusDesc;
    UIButton*       _imgPhone;
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
    
    _owner = nil;
}

- (void)onPhoneButtonClicked:(UIButton*)sender
{
    if (_owner && [_owner respondsToSelector:@selector(onPhoneButtonClicked:)]){
        [_owner performSelector:@selector(onPhoneButtonClicked:) withObject:sender];
    }
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(VCBase*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _owner = vc;
        
        _lbStatusName = [self auxGenLabel:[UIFont boldSystemFontOfSize:30]];
        _lbStatusDesc = [self auxGenLabel:[UIFont systemFontOfSize:13]];

        _imgPhone = [UIButton buttonWithType:UIButtonTypeCustom];
        [_imgPhone setBackgroundImage:[UIImage templateImageNamed:@"iconPhone"] forState:UIControlStateNormal];
        _imgPhone.userInteractionEnabled = YES;
        [_imgPhone addTarget:self action:@selector(onPhoneButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
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

- (void)refreshText
{
    assert(_item);
    _lbStatusName.text = _item[@"main"];
    _lbStatusDesc.text = _item[@"desc"];
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
    
    CGFloat fPhoneSize = 40.0f;
    _lbPhone.text = NSLocalizedString(@"kOtcOdCellContactOthers", @"联系对方");
    _lbPhone.frame = CGRectMake(fOffsetX, 48, fWidth, 20);
    CGSize size = [self auxSizeWithText:_lbPhone.text font:_lbPhone.font maxsize:CGSizeMake(fWidth, 9999)];
    _imgPhone.tintColor = theme.textColorMain;
    _imgPhone.frame = CGRectMake(self.bounds.size.width - fPhoneSize - fOffsetX - fmaxf(size.width - fPhoneSize, 0) / 2.0f,
                                 (48 - fPhoneSize) / 2.0f, fPhoneSize, fPhoneSize);
}

@end
