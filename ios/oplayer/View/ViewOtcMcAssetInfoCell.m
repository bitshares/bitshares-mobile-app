//
//  ViewOtcMcAssetInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewOtcMcAssetInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "SettingManager.h"

@interface ViewOtcMcAssetInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbAssetSymbol;
    
    UILabel*        _lbAvailTitle;
    UILabel*        _lbAvailValue;
    UILabel*        _lbFreezeTitle;
    UILabel*        _lbFreezeValue;
    UILabel*        _lbFeeTitle;
    UILabel*        _lbFeeValue;

    UIButton*       _btnTransferIn;
    UIButton*       _btnTransferOut;
}

@end

@implementation ViewOtcMcAssetInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbAssetSymbol = nil;
    
    _lbAvailTitle = nil;
    _lbAvailValue = nil;
    _lbFreezeTitle = nil;
    _lbFreezeValue = nil;
    _lbFeeTitle = nil;
    _lbFeeValue = nil;
    
    _btnTransferIn = nil;
    _btnTransferOut = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        _lbAssetSymbol = [self auxGenLabel:[UIFont boldSystemFontOfSize:16]];
        
        _lbAvailTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbAvailValue = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbAvailTitle.textColor = theme.textColorGray;
        _lbAvailValue.textColor = theme.textColorNormal;
        
        _lbFreezeTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbFreezeValue = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbFreezeTitle.textAlignment = NSTextAlignmentCenter;
        _lbFreezeValue.textAlignment = NSTextAlignmentCenter;
        _lbFreezeTitle.textColor = theme.textColorGray;
        _lbFreezeValue.textColor = theme.textColorNormal;
        
        _lbFeeTitle = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbFeeValue = [self auxGenLabel:[UIFont systemFontOfSize:13.0f]];
        _lbFeeTitle.textAlignment = NSTextAlignmentRight;
        _lbFeeValue.textAlignment = NSTextAlignmentRight;
        _lbFeeTitle.textColor = theme.textColorGray;
        _lbFeeValue.textColor = theme.textColorNormal;
        
        if (vc)
        {
            _btnTransferIn = [UIButton buttonWithType:UIButtonTypeSystem];
            _btnTransferIn.backgroundColor = [UIColor clearColor];
            
            [_btnTransferIn setTitle:NSLocalizedString(@"kOtcMcAssetBtnTransferIn", @"转入") forState:UIControlStateNormal];
            [_btnTransferIn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
            _btnTransferIn.titleLabel.font = [UIFont systemFontOfSize:16.0];
            _btnTransferIn.userInteractionEnabled = YES;
            [_btnTransferIn addTarget:vc action:@selector(onButtonClicked_TransferIn:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_btnTransferIn];
            
            _btnTransferOut = [UIButton buttonWithType:UIButtonTypeSystem];
            _btnTransferOut.backgroundColor = [UIColor clearColor];
            [_btnTransferOut setTitle:NSLocalizedString(@"kOtcMcAssetBtnTransferOut", @"转出") forState:UIControlStateNormal];
            [_btnTransferOut setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
            _btnTransferOut.titleLabel.font = [UIFont systemFontOfSize:16.0];
            _btnTransferOut.userInteractionEnabled = YES;
            [_btnTransferOut addTarget:vc action:@selector(onButtonClicked_TransferOut:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_btnTransferOut];
        }
        else
        {
            _btnTransferIn = nil;
            _btnTransferOut = nil;
        }
    }
    return self;
}

- (void)setTagData:(NSInteger)tag
{
    if (_btnTransferIn && _btnTransferOut){
        _btnTransferIn.tag = tag;
        _btnTransferOut.tag = tag;
    }
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
    
    CGFloat xOffset = self.layoutMargins.left;
    CGFloat fWidth = self.bounds.size.width;
    CGFloat fCellWidth = fWidth - xOffset * 2;
    
    //  header
    CGFloat fOffsetY = 4.0f;
    CGFloat fAssetLineHeight = 28.0f;
    CGFloat fLineHeight = 24.0;
    
    //  第一行
    _lbAssetSymbol.text = [_item objectForKey:@"assetSymbol"];
    _lbAssetSymbol.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fAssetLineHeight);
    fOffsetY += fAssetLineHeight;
    
    //  第二行
    _lbAvailTitle.text = NSLocalizedString(@"kOtcMcAssetListCellAvailable", @"可用");
    _lbFreezeTitle.text = NSLocalizedString(@"kOtcMcAssetListCellFreeze", @"冻结");
    _lbFeeTitle.text = NSLocalizedString(@"kOtcMcAssetListCellFees", @"平台手续费");
    _lbAvailTitle.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    _lbFreezeTitle.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    _lbFeeTitle.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    fOffsetY += fLineHeight;
    
    //  第三行
    _lbAvailValue.text = [NSString stringWithFormat:@"%@", [_item objectForKey:@"available"]];
    _lbFreezeValue.text = [NSString stringWithFormat:@"%@", [_item objectForKey:@"freeze"]];
    _lbFeeValue.text = [NSString stringWithFormat:@"%@", [_item objectForKey:@"fees"]];
    _lbAvailValue.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    _lbFreezeValue.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    _lbFeeValue.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    fOffsetY += fLineHeight;
    
    //  第四行 action
    if (_btnTransferIn && _btnTransferOut){
        _btnTransferIn.frame = CGRectMake(xOffset, fOffsetY, fCellWidth / 2, fAssetLineHeight);
        _btnTransferOut.frame = CGRectMake(xOffset + fCellWidth / 2, fOffsetY, fCellWidth / 2, fAssetLineHeight);
    }
}

@end
