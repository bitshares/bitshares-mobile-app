//
//  VCBlindBackupReceipt.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  隐私转账成功，备份收据信息。

#import "VCBase.h"

@interface VCBlindBackupReceipt : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithTrxResult:(NSArray*)transaction_confirmation_list;

@end
