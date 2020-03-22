//
//  ViewFormatConditons.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewFormatConditons.h"
#import "ViewCheckBox.h"
#import "ViewUtils.h"
#import "ThemeManager.h"

enum
{
    kCondTypeRegular = 0,       //  检测条件：正则
    kCondLengthRange,           //  检测条件：字符串范围限制。
};

@interface ViewFormatConditons()
{
    NSMutableArray* _condition_array;
}

@end

@implementation ViewFormatConditons

- (void)dealloc
{
    _lastCheckString = nil;
    if (_condition_array) {
        [_condition_array removeAllObjects];
        _condition_array = nil;
    }
}

- (id)initWithFrame:(CGRect)rect
{
    self = [super initWithFrame:rect];
    if (self) {
        _isAlwaysShow = NO;
        _isAllConditionsMatched = NO;
        _lastCheckString = nil;
        _condition_array = [NSMutableArray array];
    }
    return self;
}

/*
 *  (public) 快速添加条件 - 包含大写字母、小写字母、0-9的阿拉伯数字、字母开头。
 */
- (void)fastConditionContainsUppercaseLetter:(NSString*)title
{
    [self addRegularCondition:title regular:@".*[A-Z]+.*" negative:NO];
}

- (void)fastConditionContainsLowercaseLetter:(NSString*)title
{
    [self addRegularCondition:title regular:@".*[a-z]+.*" negative:NO];
}

- (void)fastConditionContainsArabicNumerals:(NSString*)title
{
    [self addRegularCondition:title regular:@".*[0-9]+.*" negative:NO];
}

- (void)fastConditionBeginWithLetter:(NSString*)title
{
    [self addRegularCondition:title regular:@"^[A-Za-z]+.*" negative:NO];
}

- (void)fastConditionEndWithLetterOrDigit:(NSString*)title
{
    [self addRegularCondition:title regular:@".*[A-Za-z0-9]+$" negative:NO];
}

/*
 *  (public) 快速添加条件 - 包含2个以上非连续的大写字母。
 */
- (void)fastConditionContainsMoreThanTwoUppercaseLetterNonConsecutive:(NSString*)title
{
    [self addRegularCondition:title regular:@".*[A-Z]+[^A-Z]+[A-Z]+.*" negative:NO];
}

/*
 *  (public) 添加条件 - 正则匹配类型。
 *  negative - 否定，表示不匹配。
 */
- (void)addRegularCondition:(NSString*)title regular:(NSString*)regular negative:(BOOL)negative
{
    assert(regular);
    [self _addCondition:title condition:@{@"type":@(kCondTypeRegular), @"regular":regular, @"negative":@(negative)}];
}

/*
 *  (public) 添加条件 - 长度范围类型。区间范围 min..max。都是闭区间。
 *  negative - 否定，表示不匹配。
 */
- (void)addLengthCondition:(NSString*)title min_length:(NSInteger)min_length max_length:(NSInteger)max_length negative:(BOOL)negative
{
    assert(min_length > 0);
    assert(max_length >= min_length);
    [self _addCondition:title condition:@{@"type":@(kCondLengthRange), @"min":@(min_length), @"max":@(max_length), @"negative":@(negative)}];
}

- (void)_addCondition:(NSString*)title condition:(id)condition
{
    assert(title);
    assert(condition);
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    ViewCheckBox* checkbox = [[ViewCheckBox alloc] initWithFrame:CGRectZero];
    checkbox.labelTitle.text = title;
    checkbox.labelTitle.textColor = theme.textColorGray;
    checkbox.colorForChecked = theme.buyColor;
    checkbox.colorForUnchecked = theme.textColorGray;
    [self addSubview:checkbox];
    [_condition_array addObject:@{@"title":title, @"condition":condition, @"checkbox":checkbox}];
}

/*
 *  (public) 触发器 - 文字变更检测。
 */
- (void)onTextDidChange:(NSString*)new_string
{
    _lastCheckString = new_string;
    _isAllConditionsMatched = YES;
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    for (id item in _condition_array) {
        id condition = [item objectForKey:@"condition"];
        BOOL success = [self _checkCondition:condition value:new_string];
        if ([[condition objectForKey:@"negative"] boolValue]) {
            success = !success;
        }
        ViewCheckBox* checkbox = [item objectForKey:@"checkbox"];
        if (success) {
            //  条件匹配
            checkbox.isChecked = YES;
            checkbox.labelTitle.textColor = theme.buyColor;
        } else {
            //  条件不匹配
            checkbox.isChecked = NO;
            checkbox.labelTitle.textColor = theme.textColorGray;
            //  设置尚未全部匹配标记
            _isAllConditionsMatched = NO;
        }
    }
}

/*
 *  (private) 检测各种条件类型是否匹配
 */
- (BOOL)_checkCondition:(id)condition value:(NSString*)value
{
    switch ([[condition objectForKey:@"type"] integerValue]) {
        case kCondLengthRange:
            return [self _checkCondLengthRange:condition value:value];
        case kCondTypeRegular:
            return [self _checkCondRegular:condition value:value];
        default:
            NSAssert(NO, @"unkown type");
            break;
    }
    return NO;
}

- (BOOL)_checkCondRegular:(id)condition value:(NSString*)value
{
    if (!value) {
        return NO;
    }
    NSPredicate* pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", [condition objectForKey:@"regular"]];
    if (![pre evaluateWithObject:value]){
        return NO;
    }
    return YES;
}

- (BOOL)_checkCondLengthRange:(id)condition value:(NSString*)value
{
    if (!value) {
        return NO;
    }
    NSInteger min = [[condition objectForKey:@"min"] integerValue];
    NSInteger max = [[condition objectForKey:@"max"] integerValue];
    NSInteger len = value.length;
    return len >= min && len <= max;
}

- (CGFloat)cellHeight
{
    if (self.hidden) {
        return 0.0f;
    }
    //  单行高度 * 行数 + 下间距。
    return 28.0f * [_condition_array count] + 12;
}

/*
 *  (public) 重新计算尺寸。
 */
- (void)resizeFrame:(CGFloat)offsetX offsetY:(CGFloat)offsetY width:(CGFloat)width
{
    if (!_condition_array || [_condition_array count] <= 0) {
        return;
    }
    if (self.hidden) {
        return;
    }
    
    //    self.backgroundColor = [UIColor redColor];
    //  TODO:5.0 布局，每行显示1条，还是2条 考虑？
    CGFloat fOffsetX = 0.0f;
    CGFloat fOffsetY = 0.0f;
    CGFloat fLineHeight = 28.0f;
    for (id item in _condition_array) {
        ViewCheckBox* checkbox = [item objectForKey:@"checkbox"];
        checkbox.frame = CGRectMake(fOffsetX, fOffsetY, width, fLineHeight);
        fOffsetY += fLineHeight;
    }
    self.frame = CGRectMake(offsetX, offsetY, width, fOffsetY + 12.0f);
}

@end

