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
    
    UILabel*        _lbTransferName;    //  交易类型描述 转账、限价单等
    UILabel*        _lbDate;            //  日期
    
    UILabel*        _lbMainDesc;        //  描述
    UILabel*        _lbMemo;            //  备注信息（可选）
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
    _lbMemo = nil;
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
        [self addSubview:_lbMainDesc];
        
        _lbMemo = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:self];
        _lbMemo.textAlignment = NSTextAlignmentLeft;
        _lbMemo.lineBreakMode = NSLineBreakByWordWrapping;
        _lbMemo.numberOfLines = 0;
        _lbMemo.hidden = YES;
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

+ (CGFloat)getCellHeight:(NSDictionary*)item leftMargin:(CGFloat)leftMargin
{
    assert(item);
    
    id uidata = [item objectForKey:@"uidata"];
    
    CGFloat fWidth = [[UIScreen mainScreen] bounds].size.width - leftMargin * 2;
    CGSize maxSize = CGSizeMake(fWidth, 9999);
    
    CGSize size = [ViewUtils auxSizeWithText:[uidata objectForKey:@"desc"] font:[UIFont systemFontOfSize:14] maxsize:maxSize];
    CGFloat dynamic_height = size.height;
    
    CGFloat fBase = 4 + 28 + dynamic_height + 12;
    
    //  备注
    id processed_memo = [uidata objectForKey:@"processed_memo"];
    if (processed_memo && [processed_memo isKindOfClass:[NSDictionary class]]) {
        CGSize memo_size = [ViewUtils auxSizeWithText:processed_memo[@"tips"] font:[UIFont systemFontOfSize:13] maxsize:maxSize];
        fBase += 6 + memo_size.height;
    }
    
    return fBase;
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
    _lbTransferName.textColor = [uidata objectForKey:@"color"];
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
    
    //  第二行 动态计算高度
    _lbMainDesc.text = [uidata objectForKey:@"desc"];
    _lbMainDesc.textColor = theme.textColorNormal;
    CGSize desc_size = [ViewUtils auxSizeWithText:_lbMainDesc.text font:_lbMainDesc.font maxsize:CGSizeMake(fWidth, 9999)];
    _lbMainDesc.frame = CGRectMake(xOffset, yOffset, fWidth, desc_size.height);
    yOffset += desc_size.height + 6;
    
    //  第三行 备注（可选）
    id processed_memo = [uidata objectForKey:@"processed_memo"];
    if (processed_memo && [processed_memo isKindOfClass:[NSDictionary class]]) {
        _lbMemo.hidden = NO;
        _lbMemo.text = [processed_memo objectForKey:@"tips"];
        _lbMemo.frame = CGRectMake(xOffset, yOffset, fWidth, fHeight - yOffset - 12);
        if ([[processed_memo objectForKey:@"decryptSuccessed"] boolValue] && ![[processed_memo objectForKey:@"isBlank"] boolValue]) {
            _lbMemo.textColor = theme.textColorMain;
        } else {
            _lbMemo.textColor = theme.textColorGray;
        }
    } else {
        _lbMemo.hidden = YES;
    }
}

@end
