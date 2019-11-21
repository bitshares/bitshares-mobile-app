//
//  ViewOtcOrderInfCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewOtcOrderInfCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "OtcManager.h"

@interface ViewOtcOrderInfCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbType;            //  买/卖
    UILabel*        _lbStatus;          //  订单状态
    
    UILabel*        _lbDateTitle;
    UILabel*        _lbDate;            //  日期
    
    UILabel*        _lbNumTitle;
    UILabel*        _lbNum;             //  数量
    
    UILabel*        _lbTotalTitle;
    UILabel*        _lbTotal;           //  总金额
    
    UILabel*        _lbMerchantName;    //  商家名字
}

@end

@implementation ViewOtcOrderInfCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbType = nil;
    _lbStatus = nil;
    
    _lbDateTitle = nil;
    _lbDate = nil;
    
    _lbNumTitle = nil;
    _lbNum = nil;
    
    _lbTotalTitle = nil;
    _lbTotal = nil;
    
    _lbMerchantName = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _lbType = [self auxGenLabel:[UIFont boldSystemFontOfSize:16]];
        _lbStatus = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbStatus.textAlignment = NSTextAlignmentRight;
     
        //  左
        _lbDateTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbDate = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        
        //  中
        _lbNumTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbNum = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbNumTitle.textAlignment = NSTextAlignmentCenter;
        _lbNum.textAlignment = NSTextAlignmentCenter;
        
        //  右
        _lbTotalTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbTotal = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbTotalTitle.textAlignment = NSTextAlignmentRight;
        _lbTotal.textAlignment = NSTextAlignmentRight;
        
        //  商家名
        _lbMerchantName = [self auxGenLabel:[UIFont systemFontOfSize:13]];
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
    //  TODO:2.9
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
    CGFloat firstLineHeight = 28.0f;
    CGFloat fLineHeight = 24.0f;
    
    //  第一行 买卖 SYMBOL
    id asset_symbol = _item[@"assetSymbol"];
    if ([[_item objectForKey:@"type"] integerValue] == eoot_data_sell){
        _lbType.attributedText = [self genAndColorAttributedText:[NSString stringWithFormat:@"%@ ", @"出售"]
                                                           value:asset_symbol
                                                      titleColor:theme.sellColor
                                                      valueColor:theme.textColorMain];
    }else{
        _lbType.attributedText = [self genAndColorAttributedText:[NSString stringWithFormat:@"%@ ", @"购买"]
                                                           value:asset_symbol
                                                      titleColor:theme.buyColor
                                                      valueColor:theme.textColorMain];
    }
    _lbType.frame = CGRectMake(xOffset, yOffset, fWidth, firstLineHeight);
    //  TODO:2.9
//    `status` tinyint(4) unsigned NOT NULL DEFAULT '0' COMMENT '状态，1 订单已创建，2、已付款，3、已转币，4、系统处理中 5、 区块确认中 6、已完成，5、已退款，6、退款失败，7、退款已确认 8、订单已取消',
    NSString* status_desc = @"未知状态";
    switch ([[_item objectForKey:@"status"] integerValue]) {
        case 1:
            status_desc = @"已下单";
            break;
        case 2:
            status_desc = @"已付款";
            break;
        case 3:
            status_desc = @"已转币";
            break;
        case 4:
            status_desc = @"系统处理中";
            break;
        case 5:
            status_desc = @"区块确认中";
            break;
        case 6:
            status_desc = @"已完成";
            break;
        case 7:
            status_desc = @"退款已确认";
            break;
        case 8:
            status_desc = @"已取消";
            break;
        default:
            break;
    }
    _lbStatus.attributedText = [self genAndColorAttributedText:[NSString stringWithFormat:@"%@ ", status_desc]
                                                         value:@">"
                                                    titleColor:theme.textColorNormal
                                                    valueColor:theme.textColorGray];
    _lbStatus.frame = CGRectMake(xOffset, yOffset + 1, fWidth, firstLineHeight);
    yOffset += firstLineHeight;
    
    //  第二行 数量和价格标题
    _lbDateTitle.text = @"时间";
    _lbNumTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kLabelTradeHisTitleAmount", @"数量"), asset_symbol];
    _lbTotalTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kVcOrderTotal", @"总金额"), _item[@"legalCurrencySymbol"]];
    _lbDateTitle.textColor = theme.textColorGray;
    _lbNumTitle.textColor = theme.textColorGray;
    _lbTotalTitle.textColor = theme.textColorGray;
    
    _lbDateTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbNumTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbTotalTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  第三行 数量和价格
    _lbDate.text = @"xxx";// [_item objectForKey:@"price"];
    _lbDate.textColor = theme.textColorNormal;
    
    _lbNum.text = [NSString stringWithFormat:@"%@", [_item objectForKey:@"quantity"]];
    _lbNum.textColor = theme.textColorNormal;
    
    _lbTotal.text = [NSString stringWithFormat:@"%@", [_item objectForKey:@"amount"]];
    _lbTotal.textColor = theme.textColorNormal;
    
    _lbDate.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbNum.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbTotal.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    _lbMerchantName.text = [_item objectForKey:@"merchantNickname"] ?: @"";
    _lbMerchantName.textColor = theme.textColorMain;
    _lbMerchantName.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
}

@end
