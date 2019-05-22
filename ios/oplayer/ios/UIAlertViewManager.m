//
//  UIAlertViewManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "UIAlertViewManager.h"
#import "SCLAlertView.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"

static UIAlertViewManager *_sharedUIAlertViewManager = nil;

@interface UIAlertViewManager()
{
    NSMutableArray* _alertViewList;
}
@end

@implementation UIAlertViewManager

+(UIAlertViewManager *)sharedUIAlertViewManager
{
    @synchronized(self)
    {
        if(!_sharedUIAlertViewManager)
        {
            _sharedUIAlertViewManager = [[UIAlertViewManager alloc] init];
        }
        return _sharedUIAlertViewManager;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _alertViewList = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
}

/**
 *  重置（关闭所有 alert ）
 */
- (void)reset
{
    if ([_alertViewList count] > 0)
    {
        for (SCLAlertView* alert in _alertViewList) {
            [alert hideView];
        }
        [_alertViewList removeAllObjects];
        [NativeAppDelegate sharedAppDelegate].alertViewWindow.hidden = YES;
        [[NativeAppDelegate sharedAppDelegate].window makeKeyWindow];
    }
}

/**
 *  @PRIVATE 处理按钮点击事件
 */
- (void)processButtonClicked:(SCLAlertView*)alert
                   keywindow:(UIWindow*)lastKeyWindow
                 buttonIndex:(NSUInteger)buttonIndex
                 istextfield:(BOOL)istextfield
                     tfvalue:(NSString*)tfvalue
                  completion:(Arg1CompletionBlock)completion
{
    NSLog(@"alert view button clicked: %d", (int)buttonIndex);
    
    //  REMARK：恢复keywindow
    [_alertViewList removeObject:alert];
    if ([_alertViewList count] <= 0){
        [NativeAppDelegate sharedAppDelegate].alertViewWindow.hidden = YES;
    }
    [lastKeyWindow makeKeyWindow];
    
    //  回调（如果有TextField值，则用 ArgTextFieldCompletionBlock 进行回调。
    if (completion){
        if (istextfield){
            ArgTextFieldCompletionBlock tf_callback = (ArgTextFieldCompletionBlock)completion;
            tf_callback(buttonIndex, tfvalue);
        }else{
            completion(buttonIndex);
        }
    }
}

- (void)_showMessageEx:(NSString*)pMessage
             withTitle:(NSString*)pTitle
          cancelButton:(NSString*)cancel
          otherButtons:(NSArray*)otherButtons
             textfield:(NSString*)placeholder
            ispassword:(BOOL)ispassword
            completion:(Arg1CompletionBlock)completion
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    UIWindow* currKeyWindow = [NativeAppDelegate sharedAppDelegate].window;
    
    SCLAlertView* alert = [[SCLAlertView alloc] init];
    
    alert.customViewColor = theme.textColorNormal;
    alert.shouldDismissOnTapOutside = NO;
    alert.showAnimationType = SimplyAppear;
    
    //  样式定制
    alert.tintTopCircle = NO;
    alert.useLargerIcon = NO;
    alert.backgroundViewColor = theme.appBackColor;
    alert.horizontalButtons = YES;
    [alert removeTopCircle];
    
    //  是否带文本输入框
    UITextField* textfield = nil;
    if (placeholder){
        //  输入框样式定制
        textfield = [alert addTextField:placeholder];
        textfield.secureTextEntry = ispassword;
        textfield.textColor = theme.textColorMain;
        textfield.tintColor = theme.tintColor;
        textfield.backgroundColor = [UIColor clearColor];
        textfield.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textfield.autocorrectionType = UITextAutocorrectionTypeNo;
        textfield.layer.masksToBounds = NO;
        textfield.layer.borderWidth = 0.5f;
        textfield.layer.cornerRadius = 1;
        textfield.layer.borderColor = theme.textColorNormal.CGColor;
        textfield.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder
                                                                          attributes:@{NSForegroundColorAttributeName:theme.textColorGray,
                                                                                       NSFontAttributeName:[UIFont systemFontOfSize:14]}];
    }
    
    //  其它按钮（有取消按钮则其它按钮索引从1开始，否则从0开始。）
    NSUInteger indexOffset = cancel ? 1 : 0;
    
    if (otherButtons){
        __weak SCLAlertView* weak_alert = alert;
        for (NSUInteger i = 0; i < [otherButtons count]; ++i) {
            NSString* btn = [otherButtons objectAtIndex:i];
            //  REMARK：ios的block在创建的时候就把i的值闭包进去了，不用再创建匿名函数。
            [alert addButton:btn actionBlock:^{
                BOOL istf = textfield != nil;
                NSString* tfvalue = textfield ? textfield.text : nil;
                [self processButtonClicked:weak_alert keywindow:currKeyWindow buttonIndex:(i + indexOffset) istextfield:istf tfvalue:tfvalue completion:completion];
            }];
        }
    }
    
    //  取消按钮放在其它按钮的下面（REMARK：取消按钮的index是0。）
    if (cancel){
        __weak SCLAlertView* weak_alert = alert;
        [alert addButton:cancel actionBlock:^{
            BOOL istf = textfield != nil;
            //  cancel按钮 tfvalue 值为nil。
            [self processButtonClicked:weak_alert keywindow:currKeyWindow buttonIndex:0 istextfield:istf tfvalue:nil completion:completion];
        }];
    }
    
    //  显示
    [_alertViewList addObject:alert];
    [alert showInfo:[[NativeAppDelegate sharedAppDelegate] getAlertViewWindowViewController]
              title:pTitle
           subTitle:pMessage
   closeButtonTitle:nil
           duration:0.0f];
}

- (void)showMessageEx:(NSString*)pMessage
            withTitle:(NSString*)pTitle
         cancelButton:(NSString*)cancel
         otherButtons:(NSArray*)otherButtons
           completion:(Arg1CompletionBlock)completion
{
    [self _showMessageEx:pMessage withTitle:pTitle cancelButton:cancel otherButtons:otherButtons textfield:nil ispassword:NO completion:completion];
}

/**
 *  显示 ［确定］ 对话框
 */
- (void)showMessage:(NSString*)pMessage withTitle:(NSString*)pTitle completion:(Arg1CompletionBlock)completion
{
    [self showMessageEx:pMessage
              withTitle:pTitle
           cancelButton:nil
           otherButtons:@[NSLocalizedString(@"kBtnOK", @"确定")]
             completion:completion];
}

/**
 *  显示 ［确定］［取消］对话框
 */
- (void)showCancelConfirm:(NSString*)pMessage withTitle:(NSString*)pTitle completion:(Arg1CompletionBlock)completion
{
    [self showMessageEx:pMessage
              withTitle:pTitle
           cancelButton:NSLocalizedString(@"kBtnCancel", @"取消")
           otherButtons:[NSArray arrayWithObject:NSLocalizedString(@"kBtnOK", @"确定")]
             completion:completion];
}

/**
 *  显示文本输入框
 */
- (void)showInputBox:(NSString*)message
           withTitle:(NSString*)title
         placeholder:(NSString*)placeholder
          ispassword:(BOOL)ispassword
                  ok:(NSString*)okbutton
          completion:(ArgTextFieldCompletionBlock)completion
{
    [self _showMessageEx:message
               withTitle:title
            cancelButton:NSLocalizedString(@"kBtnCancel", @"取消")
            otherButtons:[NSArray arrayWithObject:okbutton]
               textfield:placeholder
              ispassword:ispassword
              completion:(Arg1CompletionBlock)completion];
}

@end
