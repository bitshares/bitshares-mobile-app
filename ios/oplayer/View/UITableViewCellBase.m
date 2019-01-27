//
//  UITableViewCellBase.m
//  oplayer
//
//  Created by Aonichan on 16/1/29.
//
//

#import "UITableViewCellBase.h"
#import "ViewBlockLabel.h"
#import "ThemeManager.h"

@interface UITableViewCellBase()
{
    CAShapeLayer* _pBottomLine;
}

@end

@implementation UITableViewCellBase

@synthesize showCustomBottomLine;
@synthesize disableDelayTouchesByAccessoryView;
@synthesize hideTopLine, hideBottomLine;
@synthesize blockLabelVerCenter;

- (void)dealloc
{
    _pBottomLine = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.showCustomBottomLine = NO;
        self.disableDelayTouchesByAccessoryView = NO;
        self.hideTopLine = NO;
        self.hideBottomLine = NO;
        self.blockLabelVerCenter = NO;
        
        _pBottomLine = nil;
        
        self.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
        self.detailTextLabel.textColor = [ThemeManager sharedThemeManager].textColorNormal;
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    ViewBlockLabel* label = [self findViewBlockLabel];
    if (label)
    {
        //  REMARK：这里的 animated 标记暂时忽略，目前tableview的cell默认行为都是 false。
        if (highlighted)
        {
            label.layer.opacity = 0.5f;
        }
        else
        {
            label.layer.opacity = 1.0f;
        }
    }
    else
    {
        [super setHighlighted:highlighted animated:animated];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    ViewBlockLabel* label = [self findViewBlockLabel];
    if (label)
    {
        if (selected){
            //  REMARK：ios的动画真是个傻逼～ 透明度从1.0f渐变到0.5f完成之后，最后透明度还是1.0f。动画完成了状态还原了。fuck。
            
            //  先设置目标透明的、然后执行动画（有动画的情况下）
            float curr_opacity = label.layer.opacity;
            label.layer.opacity = 0.5f;
            if (animated){
                [self processAlphaAnimation:label.layer duration:0.2f from:curr_opacity to:label.layer.opacity];
            }
        }else{
            //  先设置目标透明的、然后执行动画（有动画的情况下）
            float curr_opacity = label.layer.opacity;
            label.layer.opacity = 1.0f;
            if (animated){
                [self processAlphaAnimation:label.layer duration:0.2f from:curr_opacity to:label.layer.opacity];
            }
        }
    }
    else
    {
        [super setSelected:selected animated:animated];
    }
}

- (void)processAlphaAnimation:(CALayer*)_layer duration:(CFTimeInterval)duration from:(float)from to:(float)to
{
    if (!_layer){
        return;
    }
    
    [_layer removeAllAnimations];
    
    CABasicAnimation* ani = [CABasicAnimation animationWithKeyPath:@"opacity"];
    ani.duration = duration;
    ani.removedOnCompletion = YES;
    ani.fromValue = [NSNumber numberWithFloat:from];
    ani.toValue = [NSNumber numberWithFloat:to];
    [_layer addAnimation:ani forKey:nil];
}

- (ViewBlockLabel*)findViewBlockLabel
{
    Class viewBlockLabelClass = NSClassFromString(@"ViewBlockLabel");
    for (UIView *view in self.contentView.subviews)
    {
        if ([view isKindOfClass:viewBlockLabelClass])
        {
            return (ViewBlockLabel*)view;
        }
    }
    return nil;
}

/**
 *  获取分割线的父视图
 */
- (UIView*)getSeparatorViewSuperView
{
    Class ios7cell_internal_klass = NSClassFromString(@"UITableViewCellScrollView");
    if (ios7cell_internal_klass){
        for (UIView* v1 in self.subviews){
            if ([v1 isKindOfClass:ios7cell_internal_klass]){
                return v1;
            }
        }
        return nil;
    }else{
        return self;
    }
}

- (void)closeDelayTouchesByAccessoryView
{
    if (!self.disableDelayTouchesByAccessoryView){
        return;
    }
    UIView* view = self.accessoryView;
    if (!view){
        return;
    }
    while (view.superview){
        if ([view respondsToSelector:@selector(setDelaysContentTouches:)]){
            [view performSelector:@selector(setDelaysContentTouches:) withObject:NO];
        }
        if ([view isKindOfClass:[UITableView class]]){
            break;
        }
        view = view.superview;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    //  关闭 setDelaysContentTouches
    [self closeDelayTouchesByAccessoryView];
    
    //  隐藏短横线
    if (self.hideTopLine || self.hideBottomLine){
        Class separator_klass = NSClassFromString(@"_UITableViewCellSeparatorView");    //  REMARK：分割线的class
        if (separator_klass){
            UIView* ownerview = [self getSeparatorViewSuperView];
            if (ownerview){
                for (UIView* v1 in ownerview.subviews) {
                    if ([v1 isKindOfClass:separator_klass]){
                        CGRect f = v1.frame;
                        if (self.hideTopLine && f.origin.y == 0){
                            v1.hidden = YES;
                            continue;
                        }
                        if (self.hideBottomLine && f.origin.y >= self.frame.size.height - f.size.height){
                            v1.hidden = YES;
                            continue;
                        }
                    }
                }
            }
        }
    }
    
    //  block label 垂直居中
    if (self.blockLabelVerCenter){
        Class klass = [ViewBlockLabel class];
        for (UIView* v1 in self.contentView.subviews) {
            if (![v1 isKindOfClass:klass]){
                continue;
            }
            v1.frame = CGRectMake(v1.frame.origin.x, (self.bounds.size.height - v1.bounds.size.height) / 2.0f, v1.bounds.size.width, v1.bounds.size.height);
        }
    }
    
    //  用户自定义下划线
    if (self.showCustomBottomLine){
        if (!_pBottomLine){
            _pBottomLine = [CAShapeLayer layer];
            _pBottomLine.lineWidth = 0.5f;
            _pBottomLine.strokeColor = [ThemeManager sharedThemeManager].bottomLineColor.CGColor;
            _pBottomLine.fillColor = [UIColor clearColor].CGColor;
            [self.layer addSublayer:_pBottomLine];
        }
        //  更新Path（因为cell的高度可能发生变化。）
        CGRect tfFrame = self.frame;
        CGFloat fOffsetY = tfFrame.size.height - 0.5;
        UIBezierPath* framePath = [[UIBezierPath alloc] init];
        CGPoint startPoint = CGPointMake(self.layoutMargins.left, fOffsetY);
        CGPoint endPoint   = CGPointMake(tfFrame.size.width, fOffsetY);
        [framePath moveToPoint:startPoint];
        [framePath addLineToPoint:endPoint];
        _pBottomLine.path = framePath.CGPath;
    }else{
        if (_pBottomLine){
            if (_pBottomLine.superlayer){
                [_pBottomLine removeFromSuperlayer];
            }
            _pBottomLine = nil;
        }
    }
}

#pragma mark- debug
- (void)printView:(UIView*)view level:(NSInteger)level
{
    if (!view){
        return;
    }
    NSMutableString* indent = [[NSMutableString alloc] init];
    for (int i = 0; i < level; ++i) {
        [indent appendString:@"\t"];
    }
    NSString* indent2 = [indent copy];
    for (UIView* v1 in view.subviews) {
        
        NSLog(@"%@level=%d:%@", indent2, (int)level, v1);
        [self printView:v1 level:level+1];
    }
}

#pragma mark- aux methods
/**
 *  (public) get owner tableview
 */
- (UITableView*)getParentTableView
{
    UITableView* tableView = nil;
    UIView* it = self;
    while (it.superview)
    {
        if ([it.superview isKindOfClass:[UITableView class]])
        {
            tableView = (UITableView*)it.superview;
            break;
        }
        it = it.superview;
    }
    assert(tableView);
    return tableView;
}

/**
 *  (public) 辅助计算文字尺寸
 */
- (CGSize)auxSizeWithText:(NSString*)text font:(UIFont*)font maxsize:(CGSize)maxsize
{
    assert(text);
    assert(font);
    return [text boundingRectWithSize:maxsize
                              options:NSStringDrawingUsesLineFragmentOrigin
                           attributes:@{NSFontAttributeName:font} context:nil].size;
}

/**
 *  (public) 辅助着色
 */
+ (NSMutableAttributedString*)genAndColorAttributedText:(NSString*)titleString
                                                  value:(NSString*)valueString
                                             titleColor:(UIColor*)titleColor
                                             valueColor:(UIColor*)valueColor
{
    NSString* finalString = [NSString stringWithFormat:@"%@%@", titleString, valueString];
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:finalString];
    NSRange range = [finalString rangeOfString:valueString];
    [attrString addAttribute:NSForegroundColorAttributeName value:titleColor range:NSMakeRange(0, range.location)];
    [attrString addAttribute:NSForegroundColorAttributeName value:valueColor range:range];
    return attrString;
}

- (NSMutableAttributedString*)genAndColorAttributedText:(NSString*)titleString
                                                  value:(NSString*)valueString
                                             titleColor:(UIColor*)titleColor
                                             valueColor:(UIColor*)valueColor
{
    return [[self class] genAndColorAttributedText:titleString value:valueString titleColor:titleColor valueColor:valueColor];
}

@end
