//
//  ViewKLineButtons.m
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import "ViewKLineButtons.h"
#import "WalletManager.h"
#import "NativeAppDelegate.h"
#import "UIDevice+Helper.h"
#import "UIImage+Template.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "VCBase.h"
#import "ViewKLine.h"

@interface ViewKLineButtons()
{
    __weak VCBase*      _owner;                 //  REMARK：声明为 weak，否则会导致循环引用。
    SEL                 _action;
    
    UILabel*            _sliderLabel;
    NSMutableArray*     _buttonArray;
}

@end

@implementation ViewKLineButtons

- (void)dealloc
{
    _owner = nil;
    _sliderLabel = nil;
}

- (id)initWithFrame:(CGRect)frame button_infos:(NSDictionary*)button_infos owner:(VCBase*)owner action:(SEL)action
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryNone;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.hideTopLine = YES;
        self.hideBottomLine = YES;
        self.backgroundColor = [UIColor clearColor];
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        assert(owner);
        _owner = owner;
        _action = action;
        
        assert(button_infos);
        id button_list = button_infos[@"button_list"];
        assert(button_list);
        NSInteger default_value = [button_infos[@"default_value"] integerValue];
        
        _buttonArray = [NSMutableArray array];
        CGFloat cellWidth = frame.size.width / [button_list count];
        for (id item in button_list) {
            //  按钮的值和名字
            NSInteger value = [[item objectForKey:@"value"] integerValue];
            NSString* name = [item objectForKey:@"name"];
        
            //  创建点击按钮
            UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(cellWidth * [_buttonArray count], 0, cellWidth, frame.size.height);
            btn.selected = value == default_value;
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            
            //  普通颜色 和 选中颜色
            assert(owner);
            [btn setTitleColor:theme.textColorGray forState:UIControlStateNormal];
            [btn setTitleColor:theme.textColorHighlight forState:UIControlStateSelected];
            [btn addTarget:self action:@selector(onSliderButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            [btn setTitle:name forState:UIControlStateNormal];
            btn.tag = value;
            
            [self addSubview:btn];
            
            [_buttonArray addObject:btn];
        }
        //  按钮下滑动横线
        UIButton* selected = [self getSelectedButton];
        if (selected){
            _sliderLabel = [[UILabel alloc]initWithFrame:CGRectMake(selected.frame.origin.x, frame.size.height - 2, cellWidth, 2)];
        }else{
            _sliderLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, frame.size.height - 2, cellWidth, 2)];
            _sliderLabel.hidden = YES;  //  没有选中按钮则不可见
        }
        _sliderLabel.backgroundColor = theme.tintColor;
        [self addSubview:_sliderLabel];
    }
    return self;
}

- (UIButton*)getSelectedButton
{
    for (UIButton* btn in _buttonArray) {
        if (btn.selected){
            return btn;
        }
    }
    return nil;
}

- (void)selectButton:(UIButton*)button newText:(NSString*)newText
{
    if (newText){
        [button setTitle:newText forState:UIControlStateNormal];
    }
    if (!button.selected){
        for (UIButton* btn in _buttonArray) {
            btn.selected = NO;
        }
        button.selected = YES;
        CGRect old = _sliderLabel.frame;
        _sliderLabel.frame = CGRectMake(button.frame.origin.x, old.origin.y, old.size.width, old.size.height);
        _sliderLabel.hidden = NO;
    }
}

- (void)updateButtonText:(NSInteger)btn_tag newText:(NSString*)newText
{
    for (UIButton* btn in _buttonArray) {
        if (btn.tag == btn_tag){
            [btn setTitle:newText forState:UIControlStateNormal];
            break;
        }
    }
}

- (void)onSliderButtonClicked:(UIButton*)sender
{
    if (!_owner){
        return;
    }
    
    NSInteger value = sender.tag;
    BOOL disable_selected = value == kBTS_KLINE_INDEX_BUTTON_VALUE || value == kBTS_KLINE_MORE_BUTTON_VALUE;
    if (!disable_selected){
        for (UIButton* btn in _buttonArray) {
            btn.selected = NO;
        }
        sender.selected = YES;
        CGRect old = _sliderLabel.frame;
        _sliderLabel.frame = CGRectMake(sender.frame.origin.x, old.origin.y, old.size.width, old.size.height);
        _sliderLabel.hidden = NO;
    }
    
    [_owner performSelector:_action withObject:sender];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)layoutSubviews
{
    [super layoutSubviews];
}

@end
