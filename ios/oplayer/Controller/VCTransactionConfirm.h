//
//  VCTransactionConfirm.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

typedef void (^BtsppConfirmCallback)(BOOL isOk);

@interface VCTransactionConfirm : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

/**
 *  TODO:fowallet 其他需要确认的交易类型 待处理
 */
- (id)initWithTransferArgs:(NSDictionary*)transfer_args callback:(BtsppConfirmCallback)callback;

@end
