//
//  ViewAutoresizeContailerHor.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewAutoresizeContailerHor.h"
#import "ViewUtils.h"
#import "ThemeManager.h"

@interface ViewAutoresizeContailerHor()
{
    NSMutableArray* _views;
}

@end

@implementation ViewAutoresizeContailerHor

- (void)dealloc
{
    if (_views) {
        [_views removeAllObjects];
        _views = nil;
    }
}

- (id)initWithFrame:(CGRect)rect
{
    self = [super initWithFrame:rect];
    if (self) {
        _views = [NSMutableArray array];
        _fViewIntervalSpace = 12.0f;
    }
    return self;
}

- (void)addSubview:(UIView*)view tag:(NSInteger)tag
{
    view.tag = tag;
    [super addSubview:view];
    [_views addObject:view];
}

- (void)resizeFrame
{
    if (!_views || [_views count] <= 0) {
        return;
    }
    
    CGFloat fHeight = self.bounds.size.height;
    CGFloat fWidth = 0.0f;
    
    for (UIView* view in _views) {
        if ([view isKindOfClass:[UILabel class]]) {
            CGSize size = [ViewUtils auxSizeWithLabel:(UILabel*)view];
            fWidth += _fViewIntervalSpace;
            view.frame = CGRectMake(fWidth, 0, size.width, fHeight);
            fWidth += size.width;
        } else if ([view isKindOfClass:[UIButton class]]) {
            CGSize size = [ViewUtils auxSizeWithLabel:((UIButton*)view).titleLabel];
            fWidth += _fViewIntervalSpace;
            view.frame = CGRectMake(fWidth, 0, size.width, fHeight);
            fWidth += size.width;
        } else {
            assert(false);
        }
    }
    
    self.frame = CGRectMake(0, 0, fWidth, fHeight);
}

@end

@implementation TailerViewAssetAndButtons

- (void)dealloc
{
    _lbAssetName = nil;
}

- (id)initWithHeight:(CGFloat)fHeight asset_name:(NSString*)asset_name
{
    return [self initWithHeight:fHeight asset_name:asset_name button_names:nil target:nil action:nil];
}

- (id)initWithHeight:(CGFloat)fHeight asset_name:(NSString*)asset_name button_names:(NSArray*)button_names target:(id)target action:(SEL)action
{
    self = [super initWithFrame:CGRectMake(0, 0, 0, fHeight)];
    if (self) {
        NSInteger tagIndex = 0;
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        _lbAssetName = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:13] superview:nil];
        _lbAssetName.text = asset_name;
        _lbAssetName.textColor = theme.textColorMain;
        _lbAssetName.textAlignment = NSTextAlignmentRight;
        [self addSubview:_lbAssetName tag:tagIndex++];
        
        if (button_names && [button_names count] > 0) {
            assert(target);
            assert(action);
            
            UILabel* lbSpace = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13] superview:nil];
            lbSpace.text = @"|";
            lbSpace.textColor = theme.textColorGray;
            [self addSubview:lbSpace tag:tagIndex++];
            
            for (id name in button_names) {
                UIButton* btn = [UIButton buttonWithType:UIButtonTypeSystem];
                btn.titleLabel.font = [UIFont systemFontOfSize:13];
                [btn setTitle:name forState:UIControlStateNormal];
                [btn setTitleColor:theme.textColorHighlight forState:UIControlStateNormal];
                btn.userInteractionEnabled = YES;
                [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
                btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
                [self addSubview:btn tag:tagIndex++];
            }
        }
        
        [self resizeFrame];
    }
    
    return self;
}

- (void)drawAssetName:(NSString*)asset_name
{
    _lbAssetName.text = asset_name;
    [self resizeFrame];
}

- (void)drawButtonNames:(NSArray*)button_names
{
    NSInteger idx = 0;
    for (UIView* view in self.subviews) {
        if ([view isKindOfClass:[UIButton class]]) {
            if (idx >= [button_names count]) {
                break;
            }
            UIButton* btn = (UIButton*)view;
            [btn setTitle:[button_names objectAtIndex:idx] forState:UIControlStateNormal];
            ++idx;
        }
    }
    [self resizeFrame];
}

@end
