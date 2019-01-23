//
//  ViewProposalOpInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewProposalOpInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewProposalOpInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbTransferName;    //  交易类型描述 转账、限价单等
    UILabel*        _lbMainDesc;        //  描述
}

@end

@implementation ViewProposalOpInfoCell

@synthesize item=_item;
@synthesize useLabelFont;
@synthesize useBuyColorForTitle;

- (void)dealloc
{
    _item = nil;
    
    _lbTransferName = nil;
    _lbMainDesc = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        self.useLabelFont = NO;
        
        _lbTransferName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTransferName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTransferName.textAlignment = NSTextAlignmentLeft;
        _lbTransferName.numberOfLines = 1;
        _lbTransferName.backgroundColor = [UIColor clearColor];
        _lbTransferName.font = [UIFont boldSystemFontOfSize:13];
        [self addSubview:_lbTransferName];
        
        _lbMainDesc = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbMainDesc.lineBreakMode = NSLineBreakByWordWrapping;
        _lbMainDesc.textAlignment = NSTextAlignmentLeft;
        _lbMainDesc.numberOfLines = 0;
        _lbMainDesc.backgroundColor = [UIColor clearColor];
        _lbMainDesc.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbMainDesc];
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

+ (CGFloat)getCellHeight:(NSDictionary*)item leftOffset:(CGFloat)leftOffset
{
    assert(item);
    
    id uidata = [item objectForKey:@"uidata"];
    assert(uidata);
    
    id desc = [uidata objectForKey:@"desc"];
    assert(desc);
    
    //  限制最低值
    leftOffset = MAX(leftOffset, 12);
    
    //  这里 12 和 layoutSubviews 里的 xOffset 一致。
    CGFloat fWidth = [[UIScreen mainScreen] bounds].size.width - leftOffset * 2;
    UIFont* font = [UIFont systemFontOfSize:13];
    CGSize size = [desc boundingRectWithSize:CGSizeMake(fWidth, 9999)
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:@{NSFontAttributeName:font} context:nil].size;
    
    CGFloat dynamic_height = size.height;

    return 4 + 28 + dynamic_height + 12;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!_item){
        return;
    }
    
    id uidata = [_item objectForKey:@"uidata"];
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.layoutMargins.left;
    CGFloat yOffset = 4;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fHeight = self.bounds.size.height;
    CGFloat fLineHeight = 28;
    
    _lbTransferName.text = [uidata objectForKey:@"name"];
    if (self.useBuyColorForTitle){
        _lbTransferName.textColor = theme.buyColor;
    }else{
        _lbTransferName.textColor = [uidata objectForKey:@"color"];
    }
    _lbTransferName.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    if (self.useLabelFont){
        _lbTransferName.font = self.textLabel.font;
    }
    yOffset += fLineHeight;

    //  第二行 动态计算高度
    _lbMainDesc.text = [uidata objectForKey:@"desc"];
    _lbMainDesc.textColor = theme.textColorNormal;
    _lbMainDesc.frame = CGRectMake(xOffset, yOffset, fWidth, fHeight - fLineHeight - 12);
}

@end
