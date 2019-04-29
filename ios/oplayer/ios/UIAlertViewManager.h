//
//  UIAlertViewManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>

typedef void (^NoArgsCompletionBlock)();
typedef void (^Arg1CompletionBlock)(NSInteger buttonIndex);
typedef void (^ArgTextFieldCompletionBlock)(NSInteger buttonIndex, NSString* tfvalue);

@interface UIAlertViewManager : NSObject

+ (UIAlertViewManager*)sharedUIAlertViewManager;

- (void)reset;

- (void)showMessage:(NSString*)pMessage withTitle:(NSString*)pTitle completion:(Arg1CompletionBlock)completion;
- (void)showMessageEx:(NSString*)pMessage withTitle:(NSString*)pTitle cancelButton:(NSString*)cancel otherButtons:(NSArray*)otherButtons completion:(Arg1CompletionBlock)completion;

#pragma mark- indirect call showMessageEx
- (void)showCancelConfirm:(NSString*)pMessage withTitle:(NSString*)pTitle completion:(Arg1CompletionBlock)completion;

/**
 *  显示文本输入框
 */
- (void)showInputBox:(NSString*)message
           withTitle:(NSString*)title
         placeholder:(NSString*)placeholder
          ispassword:(BOOL)ispassword
                  ok:(NSString*)okbutton
          completion:(ArgTextFieldCompletionBlock)completion;

@end
