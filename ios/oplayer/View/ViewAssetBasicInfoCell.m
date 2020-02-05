//
//  ViewAssetBasicInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewAssetBasicInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "ChainObjectManager.h"
#import "OrgUtils.h"

@interface ViewAssetBasicInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbAssetName;                   //  资产名
    UILabel*        _lbAssetType;                   //  资产类型（核心、智能币、预测市场、IOU欠条）
    
    UILabel*        _lbSupplyTitle;
    UILabel*        _lbSupply;                      //  供应量/流通量
    
    UILabel*        _lbMaxSupplyTitle;
    UILabel*        _lbMaxSupply;                   //  最大供应量
    
    UILabel*        _lbConfidentialSupplyTitle;
    UILabel*        _lbConfidentialSupply;          //  隐私供应量
    
    UILabel*        _lbAssetDesc;                   //  资产描述
}

@end

@implementation ViewAssetBasicInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbAssetName = nil;
    _lbAssetType = nil;
    
    _lbSupplyTitle = nil;
    _lbSupply = nil;
    
    _lbMaxSupplyTitle = nil;
    _lbMaxSupply = nil;
    
    _lbConfidentialSupplyTitle = nil;
    _lbConfidentialSupply = nil;
    
    _lbAssetDesc = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _lbAssetName = [self auxGenLabel:[UIFont boldSystemFontOfSize:16]];
        _lbAssetType = [self auxGenLabel:[UIFont boldSystemFontOfSize:12]];
        UIColor* backColor = [ThemeManager sharedThemeManager].textColorHighlight;
        _lbAssetType.textAlignment = NSTextAlignmentCenter;
        _lbAssetType.layer.borderWidth = 1;
        _lbAssetType.layer.cornerRadius = 2;
        _lbAssetType.layer.masksToBounds = YES;
        _lbAssetType.layer.borderColor = backColor.CGColor;
        _lbAssetType.layer.backgroundColor = backColor.CGColor;
        _lbAssetType.hidden = YES;
        
        //  左
        _lbSupplyTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbSupply = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        
        //  中
        _lbMaxSupplyTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbMaxSupply = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbMaxSupplyTitle.textAlignment = NSTextAlignmentCenter;
        _lbMaxSupply.textAlignment = NSTextAlignmentCenter;
        
        //  右
        _lbConfidentialSupplyTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbConfidentialSupply = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbConfidentialSupplyTitle.textAlignment = NSTextAlignmentRight;
        _lbConfidentialSupply.textAlignment = NSTextAlignmentRight;
        
        //  商家名
        _lbAssetDesc = [self auxGenLabel:[UIFont systemFontOfSize:13]];
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
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 0;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat firstLineHeight = 28.0f;
    CGFloat fLineHeight = 24.0f;
    
    //  第一行 资产名 类型  --- 发行人
    _lbAssetName.text = [_item objectForKey:@"symbol"];
    _lbAssetName.frame = CGRectMake(xOffset, yOffset, fWidth, firstLineHeight);
    
    //  Core、Smart资产标签
    NSString* asset_id = [_item objectForKey:@"id"];
    NSString* bitasset_data_id = [_item objectForKey:@"bitasset_data_id"];
    if ([chainMgr.grapheneCoreAssetID isEqualToString:asset_id]){
        _lbAssetType.text = @"Core";    //  TODO:fowallet 是否需要多语言 核心、智能资产
        _lbAssetType.hidden = NO;
    }else if (bitasset_data_id && ![bitasset_data_id isEqualToString:@""]){
        //  TODO:4.0 进一步区分 pm市场
        if ([[[chainMgr getChainObjectByID:bitasset_data_id] objectForKey:@"is_prediction_market"] boolValue]) {
            _lbAssetType.text = @"Prediction";   //  TODO:fowallet 是否需要多语言 核心、智能资产
        } else {
            _lbAssetType.text = @"Smart";   //  TODO:fowallet 是否需要多语言 核心、智能资产
        }
        _lbAssetType.hidden = NO;
    }else{
        _lbAssetType.hidden = YES;
    }
    if (!_lbAssetType.hidden){
        CGSize size1 = [ViewUtils auxSizeWithLabel:_lbAssetName];
        CGSize size2 = [ViewUtils auxSizeWithLabel:_lbAssetType];
        _lbAssetType.frame = CGRectMake(xOffset + size1.width + 4,
                                        yOffset + (firstLineHeight - size2.height - 2)/2,
                                        size2.width + 8, size2.height + 2);
    }

    yOffset += firstLineHeight;
    
    //  第二行 各种供应量标题
    _lbSupplyTitle.text = NSLocalizedString(@"kVcAssetMgrCellInfoCurSupply", @"当前供应量");
    _lbMaxSupplyTitle.text = NSLocalizedString(@"kVcAssetMgrCellInfoMaxSupply", @"最大供应量");
    _lbConfidentialSupplyTitle.text = NSLocalizedString(@"kVcAssetMgrCellInfoConSupply", @"隐私供应量");
    _lbSupplyTitle.textColor = theme.textColorGray;
    _lbMaxSupplyTitle.textColor = theme.textColorGray;
    _lbConfidentialSupplyTitle.textColor = theme.textColorGray;
    
    _lbSupplyTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbMaxSupplyTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbConfidentialSupplyTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  第三行 各种供应量数量
    id asset_options = [_item objectForKey:@"options"];
    assert(asset_options);
    NSInteger precision = [[_item objectForKey:@"precision"] integerValue];
    id dynamic_asset_data = [chainMgr getChainObjectByID:[_item objectForKey:@"dynamic_asset_data_id"]];
    assert(dynamic_asset_data);
    id n_cur_supply = [NSDecimalNumber decimalNumberWithMantissa:[[dynamic_asset_data objectForKey:@"current_supply"] unsignedLongLongValue]
                                                        exponent:-precision
                                                      isNegative:NO];
    id n_max_supply = [NSDecimalNumber decimalNumberWithMantissa:[[asset_options objectForKey:@"max_supply"] unsignedLongLongValue]
                                                        exponent:-precision
                                                      isNegative:NO];
    id n_confidential_supply = [NSDecimalNumber decimalNumberWithMantissa:[[dynamic_asset_data objectForKey:@"confidential_supply"] unsignedLongLongValue]
                                                                 exponent:-precision
                                                               isNegative:NO];
    
    _lbSupply.text = [OrgUtils formatFloatValue:n_cur_supply];
    _lbSupply.textColor = theme.textColorNormal;
    
    _lbMaxSupply.text = [OrgUtils formatFloatValue:n_max_supply];
    _lbMaxSupply.textColor = theme.textColorNormal;
    
    _lbConfidentialSupply.text = [OrgUtils formatFloatValue:n_confidential_supply];
    _lbConfidentialSupply.textColor = theme.textColorNormal;
    
    _lbSupply.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbMaxSupply.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbConfidentialSupply.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  获取资产描述
    NSString* description = [asset_options objectForKey:@"description"];
    id description_json = [OrgUtils parse_json:description];
    if (description_json) {
        id main_desc = [description_json objectForKey:@"main"];
        if (main_desc) {
            description = main_desc;
        }
    }
    _lbAssetDesc.text = description;
    _lbAssetDesc.textColor = theme.textColorMain;
    _lbAssetDesc.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
}

@end
