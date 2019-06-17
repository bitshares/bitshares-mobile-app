//
//  ViewGatewayCoinInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewGatewayCoinInfoCell.h"
#import "VCBase.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "SettingManager.h"
#import "GatewayAssetItemData.h"

@interface ViewGatewayCoinInfoCell()
{
    __weak VCBase*  _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    
    NSDictionary*   _item;
    
    UILabel*        _lbTitle;
    
    UIButton*       _lbDeposit;
    UIButton*       _lbWithdraw;
    
    UILabel*        _lbAssetFree;
    UILabel*        _lbAssetFreeFrozen;
}

@end

@implementation ViewGatewayCoinInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbTitle = nil;
    
    _lbDeposit = nil;
    _lbWithdraw = nil;
    
    _lbAssetFree = nil;
    _lbAssetFreeFrozen = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(VCBase*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        _owner = vc;
        
        _lbTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbTitle.textAlignment = NSTextAlignmentLeft;
        _lbTitle.numberOfLines = 1;
        _lbTitle.backgroundColor = [UIColor clearColor];
        _lbTitle.textColor = [ThemeManager sharedThemeManager].textColorMain;
        _lbTitle.font = [UIFont systemFontOfSize:16];
        [self addSubview:_lbTitle];

        //  button deposit
        UIColor* backColor = [ThemeManager sharedThemeManager].textColorHighlight;
        _lbDeposit = [UIButton buttonWithType:UIButtonTypeCustom];
        _lbDeposit.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [_lbDeposit setTitleColor:[ThemeManager sharedThemeManager].textColorMain forState:UIControlStateNormal];
        [_lbDeposit addTarget:self action:@selector(onButtonDepositClicked:) forControlEvents:UIControlEventTouchUpInside];
        [_lbDeposit setTitle:NSLocalizedString(@"kVcDWCellBtnNameDeposit", @"充币") forState:UIControlStateNormal];
        _lbDeposit.layer.borderWidth = 1;
        _lbDeposit.layer.cornerRadius = 0;
        _lbDeposit.layer.masksToBounds = YES;
        _lbDeposit.layer.borderColor = backColor.CGColor;
        _lbDeposit.layer.backgroundColor = backColor.CGColor;
        [self addSubview:_lbDeposit];
        
        //  button withdraw
        _lbWithdraw = [UIButton buttonWithType:UIButtonTypeCustom];
        _lbWithdraw.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [_lbWithdraw setTitleColor:[ThemeManager sharedThemeManager].textColorMain forState:UIControlStateNormal];
        [_lbWithdraw addTarget:self action:@selector(onButtonWithdrawClicked:) forControlEvents:UIControlEventTouchUpInside];
        [_lbWithdraw setTitle:NSLocalizedString(@"kVcDWCellBtnNameWithdraw", @"提币") forState:UIControlStateNormal];
        _lbWithdraw.layer.borderWidth = 1;
        _lbWithdraw.layer.cornerRadius = 0;
        _lbWithdraw.layer.masksToBounds = YES;
        _lbWithdraw.layer.borderColor = backColor.CGColor;
        _lbWithdraw.layer.backgroundColor = backColor.CGColor;
        [self addSubview:_lbWithdraw];
        
        _lbAssetFree = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAssetFree.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAssetFree.numberOfLines = 1;
        _lbAssetFree.backgroundColor = [UIColor clearColor];
        _lbAssetFree.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbAssetFree.font = [UIFont systemFontOfSize:14];
        _lbAssetFree.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbAssetFree];
        
        _lbAssetFreeFrozen = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAssetFreeFrozen.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAssetFreeFrozen.numberOfLines = 1;
        _lbAssetFreeFrozen.backgroundColor = [UIColor clearColor];
        _lbAssetFreeFrozen.textColor = [ThemeManager sharedThemeManager].textColorNormal;
        _lbAssetFreeFrozen.font = [UIFont systemFontOfSize:14];
        _lbAssetFreeFrozen.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbAssetFreeFrozen];
    }
    return self;
}

- (void)onButtonDepositClicked:(UIButton*)sender
{
    if (_owner && [_owner respondsToSelector:@selector(onButtonDepositClicked:)]){
        [_owner performSelector:@selector(onButtonDepositClicked:) withObject:sender];
    }
}

- (void)onButtonWithdrawClicked:(UIButton*)sender
{
    if (_owner && [_owner respondsToSelector:@selector(onButtonWithdrawClicked:)]){
        [_owner performSelector:@selector(onButtonWithdrawClicked:) withObject:sender];
    }
}

- (void)setTagData:(NSInteger)tag
{
    _lbDeposit.tag = tag;
    _lbWithdraw.tag = tag;
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
    CGFloat fOffsetY = 0.0f;
    CGFloat fLineHeight = 28;
    
    GatewayAssetItemData* appext = [_item objectForKey:@"kAppExt"];
    assert(appext);
    
    //  第一行
    _lbTitle.text = appext.symbol;
    _lbTitle.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, fLineHeight);
    
    //  第一行 按钮
    CGFloat fButtonWidth = 72.0f;
    _lbDeposit.frame = CGRectMake(fWidth - xOffset - fButtonWidth - fButtonWidth - 12, 6, fButtonWidth, 28);
    _lbWithdraw.frame = CGRectMake(fWidth - xOffset - fButtonWidth, 6, fButtonWidth, 28);
    
    //  充币按钮色调
    UIColor* btnTextColor;
    UIColor* btnBackColor;
    if (appext.enableDeposit){
        btnTextColor = [ThemeManager sharedThemeManager].textColorMain;
        btnBackColor = [ThemeManager sharedThemeManager].textColorHighlight;
    }else{
        btnTextColor = [ThemeManager sharedThemeManager].textColorNormal;
        btnBackColor = [ThemeManager sharedThemeManager].textColorGray;
    }
    _lbDeposit.layer.borderColor = btnBackColor.CGColor;
    _lbDeposit.layer.backgroundColor = btnBackColor.CGColor;
    [_lbDeposit setTitleColor:btnTextColor forState:UIControlStateNormal];
    
    //  提币按钮色调
    if (appext.enableWithdraw){
        btnTextColor = [ThemeManager sharedThemeManager].textColorMain;
        btnBackColor = [ThemeManager sharedThemeManager].textColorHighlight;
    }else{
        btnTextColor = [ThemeManager sharedThemeManager].textColorNormal;
        btnBackColor = [ThemeManager sharedThemeManager].textColorGray;
    }
    _lbWithdraw.layer.borderColor = btnBackColor.CGColor;
    _lbWithdraw.layer.backgroundColor = btnBackColor.CGColor;
    [_lbWithdraw setTitleColor:btnTextColor forState:UIControlStateNormal];
    fOffsetY += 40;
    
    //  第二行     可用资产    冻结资产
    id balance = appext.balance;
    assert(balance);
    NSString* strFreeValue = @"0";
    NSString* strOrderValue = @"0";
    BOOL bIsZERO = [[balance objectForKey:@"iszero"] boolValue];
    if (!bIsZERO){
        id asset = [[ChainObjectManager sharedChainObjectManager] getChainObjectByID:[balance objectForKey:@"asset_id"]];
        assert(asset);
        NSInteger precision = [[asset objectForKey:@"precision"] integerValue];
        strFreeValue = [OrgUtils formatAssetString:balance[@"free"] precision:precision];
        strOrderValue = [OrgUtils formatAssetString:balance[@"order"] precision:precision];
    }
    
    _lbAssetFree.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcAssetAvailable", @"可用"), strFreeValue];
    _lbAssetFree.frame = CGRectMake(xOffset, fOffsetY, fCellWidth / 2, 24);
    
    _lbAssetFreeFrozen.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"kVcAssetOnOrder", @"挂单"), strOrderValue];
    _lbAssetFreeFrozen.frame = CGRectMake(xOffset, fOffsetY, fCellWidth, 24);
    _lbAssetFreeFrozen.textAlignment = NSTextAlignmentRight;
    
    fOffsetY += fLineHeight;
}

@end
