//
//  ViewUtils.m
//  oplayer
//
//  Created by SYALON on 13-9-11.
//
//

#import "ViewUtils.h"
#import "UITableViewCellBase.h"

#import "VerticalAlignmentLabel.h"

#import "ThemeManager.h"
#import "AppCacheManager.h"

@implementation ViewUtils

/*
 *  (public) 辅助方法 - 查找指定类型的父类对象。
 */
+ (UIView*)findSuperView:(UIView*)view klass:(Class)super_view_class
{
    assert(view);
    assert(super_view_class);
    UIView* it = view;
    while (it.superview)
    {
        if ([it.superview isKindOfClass:super_view_class]) {
            return it.superview;
        }
        it = it.superview;
    }
    return nil;
}

+ (UITableView*)findSuperTableView:(UIView*)view
{
    return (UITableView*)[self findSuperView:view klass:[UITableView class]];
}

/*
 *  (public) 辅助方法 - 生成 TableView 用的 CELL 视图对象。
 */
+ (UITableViewCellBase*)auxGenTableViewCellLine:(NSString*)title_string
{
    return [self auxGenTableViewCellLine:title_string value:nil];
}

+ (UITableViewCellBase*)auxGenTableViewCellLine:(NSString*)title_string value:(NSString*)value_string
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.hideBottomLine = YES;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = title_string;
    cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
    cell.textLabel.textColor = theme.textColorNormal;
    cell.detailTextLabel.text = value_string ?: @"";
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
    cell.detailTextLabel.textColor = theme.textColorMain;
    return cell;
}

/*
 *  (public) 辅助方法 - 生成Label。
 */
+ (UILabel*)auxGenLabel:(UIFont*)font superview:(UIView*)superview
{
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [ThemeManager sharedThemeManager].textColorMain;
    label.font = font;
    if (superview) {
        [superview addSubview:label];
    }
    return label;
}

+ (VerticalAlignmentLabel*)auxGenVerLabel:(UIFont*)font
{
    VerticalAlignmentLabel* label = [[VerticalAlignmentLabel alloc] initWithFrame:CGRectZero];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [ThemeManager sharedThemeManager].textColorMain;
    label.font = font;
    label.text = @"";
    label.verticalAlignment = VerticalAlignmentMiddle;
    return label;
}

/*
 *  (public) 辅助计算文字尺寸
 */
+ (CGSize)auxSizeWithText:(NSString*)text font:(UIFont*)font maxsize:(CGSize)maxsize
{
    assert(text);
    assert(font);
    return [text boundingRectWithSize:maxsize
                              options:NSStringDrawingUsesLineFragmentOrigin
                           attributes:@{NSFontAttributeName:font}
                              context:nil].size;
}

+ (CGSize)auxSizeWithText:(NSString*)text font:(UIFont*)font
{
    return [self auxSizeWithText:text font:font maxsize:CGSizeMake(9999, 9999)];
}

+ (CGSize)auxSizeWithLabel:(UILabel*)label maxsize:(CGSize)maxsize
{
    assert(label);
    return [self auxSizeWithText:label.text font:label.font maxsize:maxsize];
}

+ (CGSize)auxSizeWithLabel:(UILabel*)label
{
    assert(label);
    return [self auxSizeWithText:label.text font:label.font];
}

/*
 *  (public) 辅助着色
 */
+ (NSMutableAttributedString*)genAndColorAttributedText:(NSString*)titleString
                                                  value:(NSString*)valueString
                                             titleColor:(UIColor*)titleColor
                                             valueColor:(UIColor*)valueColor
{
    assert(titleString && valueString && titleColor && valueColor);
    NSString* finalString = [NSString stringWithFormat:@"%@%@", titleString, valueString];
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:finalString];
    NSRange range = [finalString rangeOfString:valueString];
    [attrString addAttribute:NSForegroundColorAttributeName value:titleColor range:NSMakeRange(0, range.location)];
    [attrString addAttribute:NSForegroundColorAttributeName value:valueColor range:range];
    return attrString;
}

/*
 *  (public) 大部分输入框占位符默认属性字符串
 */
+ (NSAttributedString*)placeholderAttrString:(NSString*)placeholder
{
    return [self placeholderAttrString:placeholder
                                  font:[UIFont systemFontOfSize:17]
                                 color:[ThemeManager sharedThemeManager].textColorGray];
}

+ (NSAttributedString*)placeholderAttrString:(NSString*)placeholder font:(UIFont*)font color:(UIColor*)color
{
    assert(placeholder);
    assert(font);
    assert(color);
    
    return [[NSAttributedString alloc] initWithString:placeholder
                                           attributes:@{NSForegroundColorAttributeName:color,
                                                        NSFontAttributeName:font}];
}

/*
 *  (public) 根据隐私账户地址获取隐私账户显示名称。
 */
+ (NSString*)genBlindAccountDisplayName:(NSString*)blind_account_public_key
{
    AppCacheManager* pAppCache = [AppCacheManager sharedAppCacheManager];
    id blind_account = [pAppCache queryBlindAccount:blind_account_public_key];
    if (!blind_account) {
        //  获取账号失败
        return nil;
    }
    
    NSString* alias_name = @"";
    id parent_key = [blind_account objectForKey:@"parent_key"];
    if (parent_key && ![parent_key isEqualToString:@""]) {
        //  子账号（获取父账号）
        id parent_blind_account = [pAppCache queryBlindAccount:parent_key];
        assert(parent_blind_account);
        alias_name = [parent_blind_account objectForKey:@"alias_name"];
        NSInteger child_idx = [[blind_account objectForKey:@"child_key_index"] integerValue] + 1;
        switch (child_idx) {
            case 1:
                alias_name = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellSubAccount1st", @"%@的第 1 个子账号"),
                              alias_name];
                break;
            case 2:
                alias_name = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellSubAccount2nd", @"%@的第 %@ 个子账号"),
                              alias_name, @(child_idx)];
                break;
            case 3:
                alias_name = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellSubAccount3rd", @"%@的第 %@ 个子账号"),
                              alias_name, @(child_idx)];
                break;
            default:
                alias_name = [NSString stringWithFormat:NSLocalizedString(@"kVcStCellSubAccountnth", @"%@的第 %@ 个子账号"),
                              alias_name, @(child_idx)];
                break;
        }
        return alias_name;
    } else {
        //  主账号
        return [blind_account objectForKey:@"alias_name"];
    }
}

@end
