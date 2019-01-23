//
//  MBProgressHUDSingleton.m
//  oplayer
//
//  Created by Aonichan on 15-11-26.
//
//

#import "MBProgressHUDSingleton.h"
#import "MBProgressHUD.h"
#import "ThemeManager.h"

static MBProgressHUDSingleton* _spMBProgressHUDSingleton = nil;

@interface MBProgressHUDSingleton()
{
    MBProgressHUD*  __block_hud;
}

@end

@implementation MBProgressHUDSingleton

+(MBProgressHUDSingleton *)sharedMBProgressHUDSingleton
{
    if(!_spMBProgressHUDSingleton)
    {
        _spMBProgressHUDSingleton = [[MBProgressHUDSingleton alloc] init];
    }
    return _spMBProgressHUDSingleton;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        __block_hud = nil;
    }
    return self;
}

- (void)dealloc
{
    __block_hud = nil;
}

- (BOOL)is_showing
{
    return __block_hud != nil;
}

- (void)showWithTitle:(NSString *)pTitle subTitle:(NSString*)pSubTitle andView:(UIView *)pOwnerView
{
    if (__block_hud)
        return;
    
    if(!pOwnerView)//owner被释放了?
        return;
    
    __block_hud = [[MBProgressHUD alloc] initWithView:pOwnerView];
    
    //  REMARK：BlockView风格定制
    
    //  1、关闭背景遮照
    __block_hud.dimBackground = NO;
    
    //  2、设置BlockView颜色
    CGFloat red, green, blue, alpha;
    [[ThemeManager sharedThemeManager].tabBarColor getRed:&red green:&green blue:&blue alpha:&alpha];
    __block_hud.color = [UIColor colorWithRed:red green:green blue:blue alpha:0.97f];
    
    //  3、设置BlockView主文字，可以为 nil。
    __block_hud.labelText = pTitle;
    
    //  4、子标题
    if (pSubTitle && ![pSubTitle isEqualToString:@""]){
        __block_hud.detailsLabelText = pSubTitle;
    }else{
        __block_hud.detailsLabelText = nil;
    }
    
    [__block_hud show:YES];
    [pOwnerView addSubview:__block_hud];
    __block_hud.accessibilityViewIsModal = YES;
}

- (void)showWithTitle:(NSString*)pTitle andView:(UIView*)pOwnerView
{
    [self showWithTitle:pTitle subTitle:nil andView:pOwnerView];
}

- (void)hide
{
    [self removeCancelButton];
    if (__block_hud)
    {
        __block_hud.removeFromSuperViewOnHide = YES;
        [__block_hud hide:YES];
        __block_hud = nil;
    }
}

- (void)addCancelButtonWithTarget:(id)target action:(SEL)action
{
    if (__block_hud)
    {
        //  先前添加过则先移除
        if (__block_hud.extraView)
        {
            [__block_hud.extraView removeFromSuperview];
            __block_hud.extraView = nil;
        }
        UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage* btn_image = [UIImage imageNamed:@"Cancel-64"];
        [btn setBackgroundImage:btn_image forState:UIControlStateNormal];
        btn.userInteractionEnabled = YES;
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        btn.frame = CGRectMake(0, 0, btn_image.size.width, btn_image.size.height);
        [__block_hud addSubview:btn];
        __block_hud.extraView = btn;
        [__block_hud setNeedsLayout];
        [__block_hud setNeedsDisplay];
    }
}

- (void)removeCancelButton
{
    if (__block_hud)
    {
        if (__block_hud.extraView)
        {
            [__block_hud.extraView removeFromSuperview];
            __block_hud.extraView = nil;
            [__block_hud setNeedsLayout];
            [__block_hud setNeedsDisplay];
        }
    }
}

- (void)updateTitle:(NSString*)pTitle subTitle:(NSString*)pSubTitle;
{
    if (__block_hud)
    {
        __block_hud.labelText = pTitle;
        if (pSubTitle && ![pSubTitle isEqualToString:@""]){
            __block_hud.detailsLabelText = pSubTitle;
        }else{
            __block_hud.detailsLabelText = nil;
        }
    }
}

@end
