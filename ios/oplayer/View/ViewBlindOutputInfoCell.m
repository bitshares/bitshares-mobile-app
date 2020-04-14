//
//  ViewBlindOutputInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewBlindOutputInfoCell.h"
#import "ChainObjectManager.h"
#import "ThemeManager.h"
#import "NativeAppDelegate.h"
#import "OrgUtils.h"

@interface ViewBlindOutputInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbAuthority;           //  隐私输出地址
    UILabel*        _lbAmount;              //  隐私输出数量
    UIButton*       _btnEdit;               //  编辑按钮
}

@end

@implementation ViewBlindOutputInfoCell

@synthesize item=_item;
@synthesize passThreshold;

- (void)dealloc
{
    _item = nil;
    
    _lbAmount = nil;
    _lbAuthority = nil;
    _btnEdit = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        //  第一行
        _lbAuthority = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAuthority.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAuthority.textAlignment = NSTextAlignmentLeft;
        _lbAuthority.numberOfLines = 1;
        _lbAuthority.backgroundColor = [UIColor clearColor];
        _lbAuthority.font = [UIFont systemFontOfSize:14];
        [self addSubview:_lbAuthority];
        
        _lbAmount = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAmount.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAmount.textAlignment = NSTextAlignmentLeft;
        _lbAmount.numberOfLines = 1;
        _lbAmount.backgroundColor = [UIColor clearColor];
        _lbAmount.font = [UIFont systemFontOfSize:14];
        [self addSubview:_lbAmount];
        
        _btnEdit = [UIButton buttonWithType:UIButtonTypeCustom];
        _btnEdit.titleLabel.font = [UIFont systemFontOfSize:14];
        [_btnEdit setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
        [_btnEdit addTarget:vc action:@selector(onButtonClicked_Edit:) forControlEvents:UIControlEventTouchUpInside];
        _btnEdit.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [_btnEdit setTitle:@" " forState:UIControlStateNormal];
        [self addSubview:_btnEdit];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)setTagData:(NSInteger)tag
{
    if (_btnEdit){
        _btnEdit.tag = tag;
    }
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
    CGFloat yOffset = 0;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    CGFloat fLineHeight = 28.0f;
    
    if ([[_item objectForKey:@"title"] boolValue]) {
        //  TODO:6.0 lang
        _lbAuthority.text = @"隐私地址";
        _lbAmount.text = @"数量";
        [_btnEdit setTitle:@"操作" forState:UIControlStateNormal];
        
        _lbAuthority.textColor = theme.textColorGray;
        _lbAmount.textColor = theme.textColorGray;
        [_btnEdit setTitleColor:theme.textColorGray forState:UIControlStateNormal];
        _btnEdit.userInteractionEnabled = NO;
    } else {
        _lbAuthority.text = [_item objectForKey:@"public_key"];
        _lbAmount.text = [OrgUtils formatFloatValue:[_item objectForKey:@"n_amount"] usesGroupingSeparator:NO];
        [_btnEdit setTitle:@"编辑" forState:UIControlStateNormal];
        
        _lbAuthority.textColor = theme.textColorMain;
        _lbAmount.textColor = theme.textColorMain;
        [_btnEdit setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
        _btnEdit.userInteractionEnabled = YES;
    }
    
    _lbAuthority.frame = CGRectMake(xOffset, yOffset, fWidth * 0.6, fCellHeight);
    _lbAmount.frame = CGRectMake(xOffset + fWidth * 0.6 + 12, yOffset, fWidth, fCellHeight);
    CGFloat fButtonWidth = 72.0f;
    _btnEdit.frame = CGRectMake(self.bounds.size.width - xOffset - fButtonWidth,
                                (fCellHeight - fLineHeight) / 2.0f, fButtonWidth, fLineHeight);
}

@end
