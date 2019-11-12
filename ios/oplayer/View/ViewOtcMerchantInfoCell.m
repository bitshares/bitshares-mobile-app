//
//  ViewOtcMerchantInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewOtcMerchantInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewOtcMerchantInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _imageHeader;
    
    UILabel*        _lbUsername;
    NSMutableArray* _paymentIconList;
    
    UILabel*        _lbCompleteNumber;  //  成交笔数
    
    UILabel*        _lbAmount;          //  数量
    UILabel*        _lbLimit;           //  限额
    
    UILabel*        _lbPriceTitle;      //  单价
    UILabel*        _lbPriceValue;      //  价格
}

@end

@implementation ViewOtcMerchantInfoCell

@synthesize isBuy;
@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _imageHeader = nil;
    
    _lbUsername = nil;
    _paymentIconList = nil;
    
    _lbCompleteNumber = nil;
    
    _lbAmount = nil;
    _lbLimit = nil;
    
    _lbPriceTitle = nil;
    _lbPriceValue = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        self.isBuy = NO;
        _item = nil;
        
        _imageHeader = [self auxGenLabel:[UIFont systemFontOfSize:14]];
        _imageHeader.textAlignment = NSTextAlignmentCenter;
        
        _lbUsername = [self auxGenLabel:[UIFont boldSystemFontOfSize:15]];
        
        //  TODO:2.9
        _paymentIconList = [NSMutableArray array];
        for (id icon in @[@"iconPmAlipay", @"iconPmBankCard", @"iconPmWechat"]) {
            UIImage* image = [UIImage imageNamed:icon];
            UIImageView* iconView = [[UIImageView alloc] initWithImage:image];
            iconView.hidden = YES;
            [self addSubview:iconView];
            [_paymentIconList addObject:iconView];
        }

        _lbCompleteNumber = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbCompleteNumber.textAlignment = NSTextAlignmentRight;
        
        _lbAmount = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbLimit = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        
        _lbPriceTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbPriceTitle.textAlignment = NSTextAlignmentRight;
        
        _lbPriceValue = [self auxGenLabel:[UIFont boldSystemFontOfSize:19]];
        _lbPriceValue.textAlignment = NSTextAlignmentRight;
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
    
    //  REMARK: 行高 8 + 24 + 4 + 20 + 20 + 8
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];

    CGFloat fWidth = self.bounds.size.width;

    //  header
    CGFloat fOffsetY = 8.0f;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fLineHeight = 20.0f;
    CGFloat fDiameter = 24.0f;
    
    _imageHeader.layer.cornerRadius = fDiameter / 2.0f;
    if (self.isBuy) {
        _imageHeader.layer.backgroundColor = theme.buyColor.CGColor;
    } else {
        _imageHeader.layer.backgroundColor = theme.sellColor.CGColor;
    }
    
    _imageHeader.text = @"杭";//TODO:
    _imageHeader.frame = CGRectMake(fOffsetX, fOffsetY, fDiameter, fDiameter);
    
    _lbUsername.text = self.isBuy ? @"快来买哦吧啦啦啦" : @"提现走这里哦吧啦吧啦啦";
    _lbUsername.frame = CGRectMake(fOffsetX + fDiameter + 8, fOffsetY, fWidth, fDiameter);
    
    CGSize size0 = [self auxSizeWithText:_lbUsername.text font:_lbUsername.font maxsize:CGSizeMake(fWidth, 9999)];
    //  TODO:2.9
    CGFloat fIconOffset = fOffsetX + fDiameter + 8 + size0.width + 8;
    for (UIImageView* icon in _paymentIconList) {
        icon.hidden = NO;
        icon.frame = CGRectMake(fIconOffset, fOffsetY + 4, 16, 16);
        fIconOffset += 16 + 6.0f;
    }
    
    _lbCompleteNumber.text = @"3332笔 | 94%";
    CGSize size1 = [self auxSizeWithText:_lbCompleteNumber.text font:_lbCompleteNumber.font maxsize:CGSizeMake(fWidth, 9999)];
    _lbCompleteNumber.frame = CGRectMake(0, fOffsetY + (fDiameter - size1.height) / 2.0f, fWidth - fOffsetX, size1.height);
    _lbCompleteNumber.textColor = theme.textColorGray;
    
    fOffsetY += fDiameter + 4;
    
    _lbAmount.attributedText = [self genAndColorAttributedText:@"数量 "
                                                         value:@"33323 bitCNY"
                                                    titleColor:theme.textColorGray
                                                    valueColor:theme.textColorNormal];
    
    _lbLimit.attributedText = [self genAndColorAttributedText:@"限额 "
                                                        value:@"¥233 - ¥43555"
                                                   titleColor:theme.textColorGray
                                                   valueColor:theme.textColorNormal];
    
    _lbPriceTitle.text = @"单价";
    _lbPriceValue.text = @"¥0.91";
    
    _lbAmount.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    _lbPriceTitle.frame = CGRectMake(0, fOffsetY, fWidth - fOffsetX, fLineHeight);
    _lbPriceTitle.textColor = theme.textColorGray;
    
    fOffsetY += fLineHeight;
    _lbLimit.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    _lbPriceValue.frame = CGRectMake(0, fOffsetY, fWidth - fOffsetX, fLineHeight);
    _lbPriceValue.textColor = theme.textColorHighlight;
}

@end
