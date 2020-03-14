//
//  ViewTradePercentButtonCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewTradePercentButtonCell.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "VCBase.h"
#import "Extension.h"

@interface ViewTradePercentButtonCell()
{
    __weak VCBase*  _owner;     //  REMARK：声明为 weak，否则会导致循环引用。
    NSMutableArray* _btnList;
}

@end

@implementation ViewTradePercentButtonCell

- (void)dealloc
{
    _owner = nil;
    if (_btnList){
        [_btnList removeAllObjects];
        _btnList = nil;
    }
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(VCBase*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.accessoryType = UITableViewCellAccessoryNone;
        self.backgroundColor = [UIColor clearColor];
        
        _owner = vc;
        _btnList = [NSMutableArray array];
        
        id percent_button_array_name = @[@"25%", @"50%", @"75%", @"100%"];
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        [percent_button_array_name ruby_each_with_index:(^(id name, NSInteger idx) {
            UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.backgroundColor = [UIColor clearColor];
            [btn setTitle:name forState:UIControlStateNormal];
            [btn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:13.0];
            btn.userInteractionEnabled = YES;
            [btn addTarget:self action:@selector(onButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            btn.tag = idx;
            btn.layer.borderWidth = 1;
            btn.layer.borderColor = theme.textColorHighlight.CGColor;
            [self addSubview:btn];
            [_btnList addObject:btn];
        })];
    }
    return self;
}

- (void)onButtonClicked:(UIButton*)sender
{
    
    if (_owner && [_owner respondsToSelector:@selector(onPercentButtonClicked:)]){
        [_owner performSelector:@selector(onPercentButtonClicked:) withObject:sender];
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
    
    if ([_btnList count] <= 0){
        return;
    }
    
    CGFloat fButtonSpace = 6.0f;
    CGFloat fTotalSpace = ([_btnList count] - 1) * fButtonSpace;
    
    CGFloat fOffsetX = self.layoutMargins.left;
    
    CGFloat fCellWidth = self.bounds.size.width - fOffsetX * 2 - fTotalSpace;
    CGFloat fButtonWidth = fCellWidth / (CGFloat)[_btnList count];
    CGFloat fButtonHeight = 22.0f;
    
    CGFloat fOffsetY = (self.bounds.size.height - fButtonHeight) / 2.0f;
    
    
    NSInteger idx = 0;
    for (UIButton* btn in _btnList) {
        btn.frame = CGRectMake(fOffsetX + (fButtonWidth + fButtonSpace) * idx, fOffsetY, fButtonWidth, fButtonHeight);
        ++idx;
    }
}

@end
