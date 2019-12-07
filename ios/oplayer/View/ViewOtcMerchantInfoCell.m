//
//  ViewOtcMerchantInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "VCBase.h"
#import "ViewOtcMerchantInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewOtcMerchantInfoCell()
{
    __weak VCBase*  _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    NSDictionary*   _item;
    
    UILabel*        _imageHeader;
    
    UILabel*        _lbUsername;
    UILabel*        _lbCompleteNumber;  //  成交笔数
    
    UILabel*        _lbAmount;          //  数量
    UILabel*        _lbLimit;           //  限额
    
    UILabel*        _lbPriceTitle;      //  单价
    UILabel*        _lbPriceValue;      //  价格
    
    NSMutableArray* _paymentIconList;
    UIButton*       _lbSubmit;
}

@end

@implementation ViewOtcMerchantInfoCell

@synthesize adType;
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
    
    _lbSubmit = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(VCBase*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        //  保存引用
        _owner = vc;
        self.adType = eoadt_user_buy;
        
        _item = nil;
        
        _imageHeader = [self auxGenLabel:[UIFont systemFontOfSize:14]];
        _imageHeader.textAlignment = NSTextAlignmentCenter;
        
        _lbUsername = [self auxGenLabel:[UIFont boldSystemFontOfSize:15]];
        
        _lbCompleteNumber = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbCompleteNumber.textAlignment = NSTextAlignmentRight;
        
        _lbAmount = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbLimit = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        
        _lbPriceTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbPriceTitle.textAlignment = NSTextAlignmentRight;
        
        _lbPriceValue = [self auxGenLabel:[UIFont boldSystemFontOfSize:19]];
        _lbPriceValue.textAlignment = NSTextAlignmentRight;
        
        //  最后一行：支付方法 和 按钮  支付图标顺序：银行卡、支付宝、微信
        _paymentIconList = [NSMutableArray array];
        for (id icon in @[@"iconPmBankCard", @"iconPmAlipay", @"iconPmWechat"]) {
            UIImage* image = [UIImage imageNamed:icon];
            UIImageView* iconView = [[UIImageView alloc] initWithImage:image];
            iconView.hidden = YES;
            [self addSubview:iconView];
            [_paymentIconList addObject:iconView];
        }
        _lbSubmit = [UIButton buttonWithType:UIButtonTypeCustom];
        _lbSubmit.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [_lbSubmit setTitleColor:[ThemeManager sharedThemeManager].textColorMain forState:UIControlStateNormal];
        [_lbSubmit addTarget:self action:@selector(onButtonBuyOrSellClicked:) forControlEvents:UIControlEventTouchUpInside];
        _lbSubmit.layer.borderWidth = 1;
        _lbSubmit.layer.cornerRadius = 0;
        _lbSubmit.layer.masksToBounds = YES;
        [self addSubview:_lbSubmit];
    }
    return self;
}

- (void)onButtonBuyOrSellClicked:(UIButton*)sender
{
    if (_owner && [_owner respondsToSelector:@selector(onButtonBuyOrSellClicked:)]){
        [_owner performSelector:@selector(onButtonBuyOrSellClicked:) withObject:sender];
    }
}

- (void)setTagData:(NSInteger)tag
{
    _lbSubmit.tag = tag;
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

    CGFloat fWidth = self.bounds.size.width;

    //  header
    CGFloat fOffsetY = 8.0f;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fLineHeight = 20.0f;
    CGFloat fDiameter = 24.0f;
    
    //  UI - 第一行 头像
    NSString* merchantName = [_item objectForKey:@"merchantNickname"];
    _imageHeader.layer.cornerRadius = fDiameter / 2.0f;
    _imageHeader.layer.backgroundColor = theme.textColorHighlight.CGColor;
    _imageHeader.text = [merchantName substringToIndex:1];
    _imageHeader.frame = CGRectMake(fOffsetX, fOffsetY, fDiameter, fDiameter);
    
    //  UI - 第一行 商家名字
    _lbUsername.text = merchantName;
    _lbUsername.frame = CGRectMake(fOffsetX + fDiameter + 8, fOffsetY, fWidth, fDiameter);
    
    //  UI - 第一行 商家订单统计信息
    _lbCompleteNumber.text = @"3332笔 | 94%";//TODO:2.9 field?
    CGSize size1 = [self auxSizeWithText:_lbCompleteNumber.text font:_lbCompleteNumber.font maxsize:CGSizeMake(fWidth, 9999)];
    _lbCompleteNumber.frame = CGRectMake(0, fOffsetY + (fDiameter - size1.height) / 2.0f, fWidth - fOffsetX, size1.height);
    _lbCompleteNumber.textColor = theme.textColorGray;
    fOffsetY += fDiameter + 4;
    
    //  UI - 第二行 数量限额
    NSString* fiat_sym = [[[OtcManager sharedOtcManager] getFiatCnyInfo] objectForKey:@"short_symbol"];
    
    //  TODO:2.9 lang
    _lbAmount.attributedText = [self genAndColorAttributedText:@"数量 "
                                                         value:[NSString stringWithFormat:@"%@ %@", _item[@"stock"], _item[@"assetSymbol"]]
                                                    titleColor:theme.textColorGray
                                                    valueColor:theme.textColorNormal];
    
    //  UI - 第三行 交易额限额
    _lbLimit.attributedText = [self genAndColorAttributedText:@"限额 "
                                                        value:[NSString stringWithFormat:@"%@%@ - %@%@", fiat_sym, _item[@"lowestLimit"],
                                                               fiat_sym, _item[@"maxLimit"]]
                                                   titleColor:theme.textColorGray
                                                   valueColor:theme.textColorNormal];
    
    _lbPriceTitle.text = @"单价";
    _lbPriceValue.text = [NSString stringWithFormat:@"%@%@", fiat_sym, _item[@"price"]];
    
    _lbAmount.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    _lbPriceTitle.frame = CGRectMake(0, fOffsetY, fWidth - fOffsetX, fLineHeight);
    _lbPriceTitle.textColor = theme.textColorGray;
    
    fOffsetY += fLineHeight;
    _lbLimit.frame = CGRectMake(fOffsetX, fOffsetY, fWidth, fLineHeight);
    _lbPriceValue.frame = CGRectMake(0, fOffsetY, fWidth - fOffsetX, fLineHeight);
    _lbPriceValue.textColor = theme.textColorHighlight;
    
    //  UI - 第四行 支付方式图标 和 买卖按钮
    fOffsetY += fLineHeight;
    CGFloat fIconOffset = fOffsetX;
    
    //  全部隐藏
    for (UIImageView* icon in _paymentIconList) {
        icon.hidden = YES;
    }
    if ([[_item objectForKey:@"bankcardPaySwitch"] boolValue]) {
        UIImageView* icon = [_paymentIconList objectAtIndex:0]; //  0: 银行卡icon
        icon.hidden = NO;
        icon.frame = CGRectMake(fIconOffset, fOffsetY + 12 + 2, 16, 16);
        fIconOffset += 16 + 6.0f;
    }
    if ([[_item objectForKey:@"aliPaySwitch"] boolValue]) {
        UIImageView* icon = [_paymentIconList objectAtIndex:1]; //  1: 支付宝icon
        icon.hidden = NO;
        icon.frame = CGRectMake(fIconOffset, fOffsetY + 12 + 2, 16, 16);
        fIconOffset += 16 + 6.0f;
    }
    
    //  买卖按钮 TODO:2.9 lang
    UIColor* backColor;
    if (self.adType == eoadt_user_buy) {
        backColor = theme.buyColor;
        [_lbSubmit setTitle:@"购买" forState:UIControlStateNormal];
    } else {
        backColor = theme.sellColor;
        [_lbSubmit setTitle:@"出售" forState:UIControlStateNormal];
    }
    _lbSubmit.layer.borderColor = backColor.CGColor;
    _lbSubmit.layer.backgroundColor = backColor.CGColor;
    CGFloat fButtonWidth = 80.0f;
    _lbSubmit.frame = CGRectMake(fWidth - fOffsetX - fButtonWidth, fOffsetY + 6, fButtonWidth, 28);
}

@end
