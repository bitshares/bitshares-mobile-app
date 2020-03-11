//
//  ViewNewPasswordCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewNewPasswordCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "Extension.h"

@interface ViewNewPasswordCell()
{
    UIView*                         _viewBack;
    NSMutableArray*                 _labels;
    NSString*                       _new_password;
    EBitsharesAccountPasswordLang   _curr_lang;
    NSMutableArray*                 _words;
}

@end

@implementation ViewNewPasswordCell

- (void)dealloc
{
    _new_password = nil;
    _labels = nil;
    _viewBack = nil;
    _words = nil;
}

- (id)init
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        
        //        self.showCustomBottomLine = YES;
        
        _words = [NSMutableArray array];
        
        _viewBack = [[UIView alloc] init];
        //  TODO:5.0 颜色考虑
        //        _viewBack.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3];
        //        _viewBack.backgroundColor = [ThemeManager sharedThemeManager].textColorGray;
        _viewBack.backgroundColor = [UIColor clearColor];
        _viewBack.layer.borderWidth = 0.5;
        _viewBack.layer.borderColor = [ThemeManager sharedThemeManager].textColorNormal.CGColor;
        [self addSubview:_viewBack];
        
        _labels = [NSMutableArray array];
        
        //  REMARK：目前中文16个标签，英语分组8个标签。
        for (NSInteger i = 0; i < 16; ++i) {
            UILabel* label = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:18] superview:_viewBack];
            label.textAlignment = NSTextAlignmentCenter;
            [_labels addObject:label];
        }
    }
    return self;
}

- (void)updateWithNewContent:(NSString*)new_password lang:(EBitsharesAccountPasswordLang)lang
{
    assert(new_password);
    [_words removeAllObjects];
    _curr_lang = lang;
    switch (lang) {
        case ebap_lang_zh:
        {
            id words = @[@"王", @"旁", @"清", @"投", @"见", @"五", @"王", @"旁", @"清", @"投", @"见", @"五", @"见", @"五", @"哦", @"喝"];
            assert([words count] == 16);
            NSInteger idx = 0;
            for (UILabel* label in _labels) {
                label.text = [words safeObjectAtIndex:idx] ?: @"";
                ++idx;
            }
            [_words addObjectsFromArray:words];
        }
            break;
        case ebap_lang_en:
        {
            id words = @[@"ab3d", @"Zdsf", @"ab3d", @"cdff", @"434a", @"Zdsf", @"cdff", @"434a"];
            assert([words count] == 8);
            NSInteger idx = 0;
            for (UILabel* label in _labels) {
                label.text = [words safeObjectAtIndex:idx] ?: @"";
                ++idx;
            }
            [_words addObjectsFromArray:words];
        }
            break;
        default:
            assert(false);
            break;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat fWidth = self.bounds.size.width;
    CGFloat fOffsetX = self.layoutMargins.left;
    CGFloat fContentWidth = fWidth - fOffsetX * 2;
    
    CGFloat fLineHeight = 28.0f;
    CGFloat fOffsetY = 8.0f;
    
    //  根据语言计算单行显示的单词or字符数
    NSInteger one_line_word_number = 8;
    switch (_curr_lang) {
        case ebap_lang_zh:
            one_line_word_number = 8;
            break;
        case ebap_lang_en:
            one_line_word_number = 4;
            break;
        default:
            assert(false);
            break;
    }
    
    //  背景尺寸
    _viewBack.frame = CGRectMake(fOffsetX, 0, fContentWidth, self.bounds.size.height);
    
    //  刷新所有Label尺寸以及可见性
    NSInteger word_num = [_words count];
    CGFloat fWordWidth = fContentWidth / one_line_word_number;
    NSInteger idx = 0;
    for (UILabel* label in _labels) {
        if (idx >= word_num) {
            label.hidden = YES;
        } else {
            label.hidden = NO;
            label.frame = CGRectMake(fWordWidth * (idx % one_line_word_number),
                                     fOffsetY + fLineHeight * (idx / one_line_word_number),
                                     fWordWidth, fLineHeight);
        }
        //  next
        ++idx;
    }
}

@end
