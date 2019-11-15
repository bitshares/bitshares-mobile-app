//
//  ViewFullScreenBase.m
//  ViewFullScreenBase
//

#import "ViewFullScreenBase.h"

@interface ViewFullScreenBase()
{
    UITapGestureRecognizer* _pTap;
}

@end

@implementation ViewFullScreenBase

@synthesize cancelable;

- (void)dealloc
{
    _pTap = nil;
}

- (instancetype)init
{
    if (self = [super initWithFrame:[UIScreen mainScreen].bounds])
    {
        _pTap = nil;
        self.cancelable = NO;
    }
    return self;
}

-(void)_onTap:(UITapGestureRecognizer*)pTap
{
    [self onOutsideClicked];
}

- (void)setupSubViews
{
    //  子类重载：初始化各种子View
}

- (void)setupAnimationBeginPosition:(BOOL)bSlideIn
{
    //  子类重载：设置动画前起始位置
}

- (void)setupAnimationEndPosition:(BOOL)bSlideIn
{
    //  子类重载：设置动画后到目标位置
}

- (void)onOutsideClicked
{
    //  子类可重载：取消事件
    [self dismissWithCompletion:nil];
}

- (void)onFollowKeyboard:(CGFloat)keyboard_y duration:(CGFloat)duration
{
    //  子类可重载：键盘位置变更
}

-(void)showInView:(UIView*)view
{
    //  添加到目标View中
    if (self.superview) {
        [self removeFromSuperview];
    }
    [view addSubview:self];
    
    //  点击空白取消
    if (self.cancelable && !_pTap){
        UIView* pTapView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        pTapView.backgroundColor = [UIColor clearColor];
        [self addSubview:pTapView];
        _pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_onTap:)];
        _pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
        _pTap.enabled = NO;
        [pTapView addGestureRecognizer:_pTap];
    }
    
    //  初始化子View，放在空白tap事件之后。
    [self setupSubViews];
    
    //  显示时动画
    [self setupAnimationBeginPosition:YES];
    [UIView animateWithDuration:0.25f
                     animations:^{
                        [self setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.5]];
                        [self setupAnimationEndPosition:YES];
                     }
                     completion:^(BOOL finished) {
                        if (_pTap){
                            _pTap.enabled = YES;
                        }
                        //  注册键盘监听
                        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                 selector:@selector(_keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification
                                                                   object:nil];
                     }];
}

-(void)dismissWithCompletion:(void (^)())completion
{
    //  移除键盘监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_pTap){
        _pTap.enabled = NO;
    }
    //  消失时动画
    [self setupAnimationBeginPosition:NO];
    [UIView animateWithDuration:0.25f
                     animations:^{
                        [self setBackgroundColor:[UIColor clearColor]];
                        [self setupAnimationEndPosition:NO];
                     }
                     completion:^(BOOL finished) {
                        [self removeFromSuperview];
                        if (completion) {
                            completion();
                        }
                     }];
}

- (void)_keyboardWillChangeFrame:(NSNotification*)notification
{
    CGFloat keyboardY = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].origin.y;
    CGFloat duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [self onFollowKeyboard:keyboardY duration:duration];
}

/*
 *  (protected) 辅助方法 - 生成Label。
 */
- (UILabel*)auxGenLabel:(UIFont*)font superview:(UIView*)superview
{
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [ThemeManager sharedThemeManager].textColorMain;
    label.font = font;
    [superview addSubview:label];
    return label;
}

@end
