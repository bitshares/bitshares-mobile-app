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
    BOOL bUserSell = [[_item objectForKey:@"type"] integerValue] == eoot_data_sell;
    if (bUserSell){
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
    
    id status_infos = [OtcManager genUserOrderStatusAndActions:_item];
    _lbStatus.attributedText = [self genAndColorAttributedText:[NSString stringWithFormat:@"%@ ", status_infos[@"main"]]
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
