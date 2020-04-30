//
//  VCTransferFromBlind.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  从隐私账户转出

#import "VCBase.h"

@interface VCTransferFromBlind : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithBlindBalance:(id)blind_balance;

@end
