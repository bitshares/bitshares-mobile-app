//
//  ViewFullScreenBase.h
//  ViewFullScreenBase
//
//  全屏模态对话框基础类
//
#import <UIKit/UIKit.h>
#import "AppCommon.h"
#import "ThemeManager.h"

@interface ViewFullScreenBase : UIView

@property (nonatomic, assign) BOOL cancelable;          //  是否允许点击空白区域取消对话框

-(void)showInView:(UIView*)view;
-(void)dismissWithCompletion:(void (^)())completion;

- (void)setupSubViews;
- (void)setupAnimationBeginPosition:(BOOL)bSlideIn;
- (void)setupAnimationEndPosition:(BOOL)bSlideIn;
- (void)onOutsideClicked;
- (void)onFollowKeyboard:(CGFloat)keyboard_y duration:(CGFloat)duration;

/*
 *  (protected) 辅助方法 - 生成Label。
 */
- (UILabel*)auxGenLabel:(UIFont*)font superview:(UIView*)superview;

@end
