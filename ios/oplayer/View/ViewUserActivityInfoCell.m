//
//  ViewUserActivityInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewUserActivityInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"

@interface ViewUserActivityInfoCell()
{
    NSDictionary*   _item;
    
    //  ---                 ----
    //  ------------------------
    //  -------
    UILabel*        _lbTransferName;    //  交易类型描述 转账、限价单等
    UILabel*        _lbDate;            //  日期
    
    UILabel*        _lbMainDesc;        //  描述
}

@end

@implementation ViewUserActivityInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbTransferName = nil;
    _lbMainDesc = nil;
    _lbDate = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _lbTransferName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTransferName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTransferName.textAlignment = NSTextAlignmentLeft;
        _lbTransferName.numberOfLines = 1;
        _lbTransferName.backgroundColor = [UIColor clearColor];
        _lbTransferName.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_lbTransferName];
        
        _lbDate = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbDate.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbDate.textAlignment = NSTextAlignmentRight;
        _lbDate.numberOfLines = 1;
        _lbDate.backgroundColor = [UIColor clearColor];
        _lbDate.font = [UIFont systemFontOfSize:13];
        [self addSubview:_lbDate];
        
        _lbMainDesc = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbMainDesc.lineBreakMode = NSLineBreakByWordWrapping;
        _lbMainDesc.textAlignment = NSTextAlignmentLeft;
        _lbMainDesc.numberOfLines = 0;
        _lbMainDesc.backgroundColor = [UIColor clearColor];
        _lbMainDesc.font = [UIFont systemFontOfSize:14];
//        _lbMainDesc.adjustsFontSizeToFitWidth = YES;
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

+ (CGFloat)getCellHeight:(NSDictionary*)item
{
    assert(item);
    
    //  这里 12 和 layoutSubviews 里的 xOffset 一致。
    CGFloat fWidth = [[UIScreen mainScreen] bounds].size.width - 16 * 2;
    UIFont* font = [UIFont systemFontOfSize:14];
    CGSize size = [[item objectForKey:@"desc"] boundingRectWithSize:CGSizeMake(fWidth, 9999)
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
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = 16;//self.textLabel.frame.origin.x;
    CGFloat yOffset = 4;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fHeight = self.bounds.size.height;
    CGFloat fLineHeight = 28;
    
    _lbTransferName.text = [_item objectForKey:@"typename"];
    id typecolor = [_item objectForKey:@"typecolor"];
    if (typecolor){
        _lbTransferName.textColor = typecolor;
    }else{
        _lbTransferName.textColor = theme.textColorMain;
    }
    _lbTransferName.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    
    //  TODO:fowallet 手续费是否显示在日期后面？？？待确认
    id block_time_str = [OrgUtils fmtAccountHistoryTimeShowString:[_item objectForKey:@"block_time"]];
//    id fee = [opdata objectForKey:@"fee"];
//    if (fee){
//        id asset = [chainMgr getChainObjectByID:fee[@"asset_id"]];
//        id num = [OrgUtils genAssetAmountDecimalNumber:fee[@"amount"] asset:asset];
//        _lbDate.text = [NSString stringWithFormat:@"%@ %@%@", block_time_str, num, asset[@"symbol"]];
//    }else{
        _lbDate.text = block_time_str;
//    }
    _lbDate.textColor = theme.textColorGray;
    _lbDate.frame = CGRectMake(xOffset, yOffset+1, fWidth, fLineHeight);
    
    yOffset += fLineHeight;
    
    //  第二行 动态计算高度 TODO:fowallet 是否有需要
    _lbMainDesc.text = [_item objectForKey:@"desc"];
    _lbMainDesc.textColor = theme.textColorNormal;
    _lbMainDesc.frame = CGRectMake(xOffset, yOffset, fWidth, fHeight - fLineHeight - 12);
}

@end
