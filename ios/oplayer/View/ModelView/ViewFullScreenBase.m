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
    [self onCancelClicked];
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

- (void)onCancelClicked
{
    //  子类可重载：取消事件
    [self dismissWithCompletion:nil];
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
                     }];
}

-(void)dismissWithCompletion:(void (^)())completion
{
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

@end
