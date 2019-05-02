//
//  ViewPermissionCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewPermissionCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "SettingManager.h"

#import "Extension.h"
#import "ChainObjectManager.h"

@interface ViewPermissionCell()
{
    NSDictionary*   _old_permission_json;
    NSDictionary*   _new_permission_json;
    
    NSMutableArray* _lbLineLabelArray;
    UIView*         _pBottomLine;
}

@end

@implementation ViewPermissionCell

@synthesize xOffset;

+ (CGFloat)calcViewHeight:(id)old_permission_json new:(id)new_permission_json
{
    assert(old_permission_json);
    NSMutableDictionary* total_keys = [NSMutableDictionary dictionary];
    for (id item in [old_permission_json objectForKey:@"account_auths"]) {
        assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
        [total_keys setObject:@YES forKey:[item firstObject]];
    }
    for (id item in [old_permission_json objectForKey:@"key_auths"]) {
        assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
        [total_keys setObject:@YES forKey:[item firstObject]];
    }
    if (new_permission_json){
        for (id item in [new_permission_json objectForKey:@"account_auths"]) {
            assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
            [total_keys setObject:@YES forKey:[item firstObject]];
        }
        for (id item in [new_permission_json objectForKey:@"key_auths"]) {
            assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
            [total_keys setObject:@YES forKey:[item firstObject]];
        }
    }
    //  N * line_height + space_height
    return ([total_keys count] + 2) * 22 + 8;
}

- (void)dealloc
{
    [_lbLineLabelArray removeAllObjects];
    _lbLineLabelArray = nil;
    _pBottomLine = nil;
}

- (UILabel*)genOneLineLabel:(NSString*)str align:(NSTextAlignment)align
{
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:13];
//    label.font = [UIFont fontWithName:@"Helvetica-Bold" size:13.0f];
    label.textAlignment = align;
    label.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    [self addSubview:label];
    if (str){
        label.text = str;
    }
    return label;
}

- (NSDictionary*)genLineLables:(NSString*)name old_value:(NSInteger)old_value new_value:(NSInteger)new_value
{
    UILabel* lbName = [self genOneLineLabel:name align:NSTextAlignmentLeft];
    UILabel* lbChange = [self genOneLineLabel:[NSString stringWithFormat:@"%@", @(new_value)] align:NSTextAlignmentRight];

    UILabel* lbResult = nil;
    if (old_value == new_value){
        lbResult = [self genOneLineLabel:@"0" align:NSTextAlignmentRight];
    }else if (new_value > old_value){
        //  变化 +
        lbResult = [self genOneLineLabel:[NSString stringWithFormat:@"+%@", @(new_value - old_value)] align:NSTextAlignmentRight];
        lbChange.textColor = [ThemeManager sharedThemeManager].buyColor;
    }else{
        //  变化 -
        lbResult = [self genOneLineLabel:[NSString stringWithFormat:@"%@", @(new_value - old_value)] align:NSTextAlignmentRight];
        lbChange.textColor = [ThemeManager sharedThemeManager].sellColor;
    }
    
    return @{@"name":lbName, @"change":lbChange, @"result":lbResult};
}

- (id)initWithPermission:(id)old_permission_json new:(id)new_permission_json title:(NSString*)title
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        // Initialization code
        self.xOffset = 0;
        
        _old_permission_json = old_permission_json;
        _new_permission_json = new_permission_json;
        assert(old_permission_json);
        
        _lbLineLabelArray = [NSMutableArray array];
        
        UILabel* name = [self genOneLineLabel:title align:NSTextAlignmentLeft];
        UILabel* change = [self genOneLineLabel:NSLocalizedString(@"kOpDetailSubTitleNewWeightOrThreshold", @"新阈值/新权重")
                                          align:NSTextAlignmentRight];
        UILabel* result = [self genOneLineLabel:NSLocalizedString(@"kOpDetailSubTitleChangeValue", @"变化量")
                                          align:NSTextAlignmentRight];
        name.textColor = [ThemeManager sharedThemeManager].textColorGray;
        change.textColor = [ThemeManager sharedThemeManager].textColorGray;
        result.textColor = [ThemeManager sharedThemeManager].textColorGray;
        [_lbLineLabelArray addObject:@{@"name":name, @"change":change, @"result":result}];
        [_lbLineLabelArray addObject:[self genLineLables:[NSString stringWithFormat:@"* %@", NSLocalizedString(@"kOpDetailSubPrefixThreshold", @"阈值")]
                                               old_value:[[old_permission_json objectForKey:@"weight_threshold"] integerValue]
                                               new_value:[[new_permission_json objectForKey:@"weight_threshold"] integerValue]]];
        
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        
        NSMutableDictionary* old_weights_hash = [NSMutableDictionary dictionary];
        NSMutableDictionary* new_weights_hash = [NSMutableDictionary dictionary];
        NSMutableDictionary* total_keys = [NSMutableDictionary dictionary];
        
        for (id item in [old_permission_json objectForKey:@"account_auths"]) {
            assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
            id account_id = [item firstObject];
            [old_weights_hash setObject:[item lastObject] forKey:account_id];
            [total_keys setObject:@{@"isaccount":@YES} forKey:account_id];
        }
        for (id item in [old_permission_json objectForKey:@"key_auths"]) {
            assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
            id key = [item firstObject];
            [old_weights_hash setObject:[item lastObject] forKey:key];
            [total_keys setObject:@{@"iskey":@YES} forKey:key];
        }
        for (id item in [new_permission_json objectForKey:@"account_auths"]) {
            assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
            id account_id = [item firstObject];
            [new_weights_hash setObject:[item lastObject] forKey:account_id];
            [total_keys setObject:@{@"isaccount":@YES} forKey:account_id];
        }
        for (id item in [new_permission_json objectForKey:@"key_auths"]) {
            assert([item isKindOfClass:[NSArray class]] && [item count] == 2);
            id key = [item firstObject];
            [new_weights_hash setObject:[item lastObject] forKey:key];
            [total_keys setObject:@{@"iskey":@YES} forKey:key];
        }
        
        for (id key in total_keys) {
            id info = [total_keys objectForKey:key];
            NSString* name;
            if ([[info objectForKey:@"isaccount"] boolValue]){
                name = [NSString stringWithFormat:@"* %@", [chainMgr getChainObjectByID:key][@"name"]];
            }else{
                name = [NSString stringWithFormat:@"* %@", key];
            }
            
            NSInteger iOldWeight = 0;
            NSInteger iNewWeight = 0;
            id old_weight = [old_weights_hash objectForKey:key];
            if (old_weight){
                iOldWeight = [old_weight integerValue];
            }
            id new_weight = [new_weights_hash objectForKey:key];
            if (new_weight){
                iNewWeight = [new_weight integerValue];
            }
            [_lbLineLabelArray addObject:[self genLineLables:name old_value:iOldWeight new_value:iNewWeight]];
        }
        
        _pBottomLine = [[UIView alloc] init];
        _pBottomLine.backgroundColor = [ThemeManager sharedThemeManager].bottomLineColor;
        [self addSubview:_pBottomLine];
    }
    return self;
}

- (CGFloat)getViewHeight
{
    //  N * line_height + space_height
    return [_lbLineLabelArray count] * 22 + 8;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat w = self.bounds.size.width - self.xOffset * 2;
    CGFloat fLineHeight = 22;
    [_lbLineLabelArray ruby_each_with_index:(^(id line, NSInteger idx) {
        UILabel* name = [line objectForKey:@"name"];
        UILabel* change = [line objectForKey:@"change"];
        UILabel* result = [line objectForKey:@"result"];
        if (idx == 0){
            name.frame = CGRectMake(self.xOffset, idx * fLineHeight, w * 0.4, fLineHeight);
            change.frame = CGRectMake(self.xOffset + w * 0.4, idx * fLineHeight, 0.4 * w, fLineHeight);
            result.frame = CGRectMake(self.xOffset + w * 0.8, idx * fLineHeight, 0.2 * w, fLineHeight);
        }else{
            name.frame = CGRectMake(self.xOffset, idx * fLineHeight, w * 0.6, fLineHeight);
            change.frame = CGRectMake(self.xOffset + w * 0.6, idx * fLineHeight, 0.2 * w, fLineHeight);
            result.frame = CGRectMake(self.xOffset + w * 0.8, idx * fLineHeight, 0.2 * w, fLineHeight);
        }
    })];
    
    _pBottomLine.frame = CGRectMake(self.xOffset, self.bounds.size.height - 1.0f, self.bounds.size.width - self.xOffset, 0.5);
}

@end
