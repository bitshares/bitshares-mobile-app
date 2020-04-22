//
//  VCBlindTransfer.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  隐私账户间转账

#import "VCBase.h"

@interface VCBlindTransfer : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithBlindBalance:(id)blind_balance result_promise:(WsPromiseObject*)result_promise;

@end
