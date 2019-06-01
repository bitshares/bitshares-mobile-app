//
//  ViewFeedPriceDataCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewFeedPriceDataCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewFeedPriceDataCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbWitnessName;     //  见证人
    UILabel*        _lbFeedPrice;       //  喂价
    UILabel*        _lbDiff;            //  偏差率
    UILabel*        _lbDate;            //  最近发布
}

@end

@implementation ViewFeedPriceDataCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbWitnessName = nil;
    _lbFeedPrice = nil;
    _lbDiff = nil;
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

        //  TODO:fowallet font name
        _lbWitnessName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbWitnessName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbWitnessName.textAlignment = NSTextAlignmentLeft;
        _lbWitnessName.numberOfLines = 1;
        _lbWitnessName.backgroundColor = [UIColor clearColor];
        _lbWitnessName.font = [UIFont systemFontOfSize:13.0f];
        [self addSubview:_lbWitnessName];

        _lbFeedPrice = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbFeedPrice.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbFeedPrice.textAlignment = NSTextAlignmentCenter;
        _lbFeedPrice.numberOfLines = 1;
        _lbFeedPrice.backgroundColor = [UIColor clearColor];
        _lbFeedPrice.font = [UIFont systemFontOfSize:13.0f];
        [self addSubview:_lbFeedPrice];
        
        _lbDiff = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbDiff.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbDiff.textAlignment = NSTextAlignmentCenter;
        _lbDiff.numberOfLines = 1;
        _lbDiff.backgroundColor = [UIColor clearColor];
        _lbDiff.font = [UIFont systemFontOfSize:13.0f];
        _lbDiff.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbDiff];
        
        _lbDate = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbDate.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbDate.textAlignment = NSTextAlignmentRight;
        _lbDate.numberOfLines = 1;
        _lbDate.backgroundColor = [UIColor clearColor];
        _lbDate.font = [UIFont systemFontOfSize:13.0f];
        _lbDate.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbDate];
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
    
    if (!_item){
        return;
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    
    if ([[_item objectForKey:@"title"] boolValue]){
        _lbWitnessName.text = NSLocalizedString(@"kVcFeedWitnessName", @"见证人");
        _lbWitnessName.textColor = theme.textColorNormal;
        
        _lbFeedPrice.text = NSLocalizedString(@"kVcFeedPriceName", @"喂价");
        _lbFeedPrice.textColor = theme.textColorNormal;

        _lbDiff.text = NSLocalizedString(@"kVcFeedRate", @"偏差率");
        _lbDiff.textColor = theme.textColorNormal;
        
        _lbDate.text = NSLocalizedString(@"kVcFeedPublishDate", @"最近发布");
        _lbDate.textColor = theme.textColorNormal;
    }else{
        _lbWitnessName.text = [_item objectForKey:@"name"];
        
        if ([[_item objectForKey:@"miss"] boolValue]){
            _lbWitnessName.textColor = theme.textColorNormal;
            
            _lbFeedPrice.text = @"--";
            _lbFeedPrice.textColor = theme.textColorNormal;
            
            _lbDiff.text = @"--";
            _lbDiff.textColor = theme.textColorNormal;
            
            _lbDate.text = NSLocalizedString(@"kVcFeedNoData", @"未发布");
            _lbDate.textColor = theme.textColorNormal;
        }else{
            _lbWitnessName.textColor = theme.textColorMain;
            
            _lbFeedPrice.text = [OrgUtils formatFloatValue:[_item objectForKey:@"price"]];
            _lbFeedPrice.textColor = theme.textColorMain;
            
            id diff = [_item objectForKey:@"diff"];
            NSComparisonResult result = [diff compare:[NSDecimalNumber zero]];
            if (result == NSOrderedDescending){
                _lbDiff.text = [NSString stringWithFormat:@"+%@%%", [OrgUtils formatFloatValue:diff]];
                _lbDiff.textColor = theme.buyColor;
            }else if (result == NSOrderedAscending){
                _lbDiff.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:diff]];
                _lbDiff.textColor = theme.sellColor;
            }else{
                _lbDiff.text = [NSString stringWithFormat:@"%@%%", [OrgUtils formatFloatValue:diff]];
                _lbDiff.textColor = theme.textColorMain;
            }
            
            _lbDate.text = [OrgUtils fmtFeedPublishDateString:[_item objectForKey:@"date"]];
            _lbDate.textColor = theme.textColorMain;
        }
    }
    
    _lbWitnessName.frame = CGRectMake(xOffset, 0, fWidth * 0.4, fCellHeight);
    _lbFeedPrice.frame = CGRectMake(xOffset + fWidth * 0.4, 0, fWidth * 0.2, fCellHeight);
    _lbDiff.frame = CGRectMake(xOffset + fWidth * 0.6, 0, fWidth * 0.2, fCellHeight);
    _lbDate.frame = CGRectMake(xOffset + fWidth * 0.8, 0, fWidth * 0.2, fCellHeight);
}

@end
