//
//  ViewMemoKeyCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewMemoKeyCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "SettingManager.h"

#import "Extension.h"
#import "ChainObjectManager.h"

@interface ViewMemoKeyCell()
{
    NSMutableArray* _lbLineLabelArray;
    UIView*         _pBottomLine;
}

@end

@implementation ViewMemoKeyCell

@synthesize xOffset;

+ (CGFloat)calcViewHeight:(id)old_memokey new:(id)new_memokey
{
    assert(old_memokey && new_memokey);
    assert(![old_memokey isEqualToString:new_memokey]);
    
    //  (title + old + new) * line_height + space_height
    return (1 + 2) * 22 + 8;
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

- (id)initWithOldMemo:(id)old_memokey new:(id)new_memokey title:(NSString*)title
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        // Initialization code
        self.xOffset = 0;
        
        _lbLineLabelArray = [NSMutableArray array];
        
        UILabel* name = [self genOneLineLabel:title align:NSTextAlignmentLeft];
        UILabel* result = [self genOneLineLabel:NSLocalizedString(@"kOpDetailSubTitleOperate", @"操作") align:NSTextAlignmentRight];
        name.textColor = [ThemeManager sharedThemeManager].textColorGray;
        result.textColor = [ThemeManager sharedThemeManager].textColorGray;
        [_lbLineLabelArray addObject:@{@"name":name, @"result":result}];
        
        //  old memokey line
        name = [self genOneLineLabel:[NSString stringWithFormat:@"* %@", old_memokey] align:NSTextAlignmentLeft];
        result = [self genOneLineLabel:NSLocalizedString(@"kOpDetailSubOpDelete", @"删除") align:NSTextAlignmentRight];
        result.textColor = [ThemeManager sharedThemeManager].sellColor;
        [_lbLineLabelArray addObject:@{@"name":name, @"result":result}];
        
        //  new memokey line
        name = [self genOneLineLabel:[NSString stringWithFormat:@"* %@", new_memokey] align:NSTextAlignmentLeft];
        result = [self genOneLineLabel:NSLocalizedString(@"kOpDetailSubOpAdd", @"添加") align:NSTextAlignmentRight];
        result.textColor = [ThemeManager sharedThemeManager].buyColor;
        [_lbLineLabelArray addObject:@{@"name":name, @"result":result}];
        
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
        UILabel* result = [line objectForKey:@"result"];
        name.frame = CGRectMake(self.xOffset, idx * fLineHeight, w * 0.8, fLineHeight);
        result.frame = CGRectMake(self.xOffset + w * 0.8, idx * fLineHeight, 0.2 * w, fLineHeight);
    })];
    
    _pBottomLine.frame = CGRectMake(self.xOffset, self.bounds.size.height - 1.0f, self.bounds.size.width - self.xOffset, 0.5);
}

@end
