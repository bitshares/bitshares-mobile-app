//
//  ViewActionsCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewActionsCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"
#import "Extension.h"

@interface ViewActionsCell()
{
    NSDictionary*   _item;
    NSMutableArray* _btnList;
    NSArray*        _btnInfos;
}

@end

@implementation ViewActionsCell

@synthesize item=_item;
@synthesize button_delegate;
@synthesize user_tag;

- (void)dealloc
{
    _item = nil;
    _btnInfos = nil;
    if (_btnList){
        [_btnList removeAllObjects];
        _btnList = nil;
    }
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier buttons:(NSArray*)buttons
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _btnList = [NSMutableArray array];
        
        self.button_delegate = nil;
        self.user_tag = 0;
        
        _btnInfos = [buttons copy];

        [buttons ruby_each_with_index:(^(id button_info, NSInteger idx) {
            UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.tag = idx;
            
            btn.backgroundColor = [UIColor clearColor];
            [btn setTitle:[button_info objectForKey:@"name"] forState:UIControlStateNormal];
            [btn setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:16.0];
            btn.userInteractionEnabled = YES;
            btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
            [btn addTarget:self action:@selector(onButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:btn];
            
            [_btnList addObject:btn];
        })];
    }
    return self;
}

- (void)onButtonClicked:(UIButton*)sender
{
    if (self.button_delegate && [self.button_delegate respondsToSelector:@selector(onButtonClicked:infos:)])
    {
        [self.button_delegate onButtonClicked:self infos:[_btnInfos objectAtIndex:sender.tag]];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)setTagData:(NSInteger)tag
{
    if (_btnList){
        for (UIButton* btn in _btnList) {
            btn.tag = tag;
        }
    }
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
    
    if ([_btnList count] <= 0){
        return;
    }
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fOffsetY = 0;
    CGFloat fCellWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    CGFloat fCellWidth30 = fCellWidth / (CGFloat)[_btnList count];
    
    NSInteger idx = 0;
    for (UIButton* btn in _btnList) {
        btn.frame = CGRectMake(xOffset + fCellWidth30 * idx, fOffsetY, fCellWidth30, fCellHeight);
        ++idx;
    }
}

@end
