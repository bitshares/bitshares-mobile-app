//
//  MyPopviewManager.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import <Foundation/Foundation.h>
#import "WsPromise.h"
#import "ViewSimulateActionSheet.h"

typedef void (^Arg2CompletionBlock)(NSInteger buttonIndex, NSInteger cancelIndex);

@interface MyPopviewManager : NSObject<UIActionSheetDelegate, ViewSimulateActionSheetDelegate>

+ (MyPopviewManager*)sharedMyPopviewManager;

/**
 *  显示 ActionSheet。
 */
- (void)showActionSheet:(UIViewController*)vc
                message:(NSString*)message
                 cancel:(NSString*)cancelbuttonname
                  items:(NSArray*)items
                    key:(NSString*)key
               callback:(Arg2CompletionBlock)callback;

- (void)showActionSheet:(UIViewController*)vc message:(NSString*)message cancel:(NSString*)cancelbuttonname items:(NSArray*)itemnamelist callback:(Arg2CompletionBlock)callback;

/**
 *  显示 ActionSheet （带红色按钮重点提示）。
 */
- (void)showActionSheet:(UIViewController*)vc message:(NSString*)message cancel:(NSString*)cancelbuttonname red:(NSString*)redbuttonname items:(NSArray*)itemnamelist callback:(Arg2CompletionBlock)callback;

/*
 *  显示网页中用的安全密码输入框。
 */
- (WsPromise*)showWebviewPaymentDialog:(UIViewController*)vc
                   reserve_secure_text:(NSString*)reserve_secure_text
                              paytitle:(NSString*)paytitle;

/*
 *  显示场外交易下单时的模态输入框
 */
- (WsPromise*)showOtcTradeView:(UIViewController*)vc ad_info:(id)ad_info lock_info:(id)lock_info sell_user_balance:(id)sell_user_balance;

/**
 *  在底部显示列表选择控件
 */
- (WsPromise*)showModernListView:(UIViewController*)vc
                         message:(NSString*)message
                           items:(NSArray*)itemlist
                         itemkey:(NSString*)itemkey
                    defaultIndex:(NSInteger)defaultIndex;

@end
