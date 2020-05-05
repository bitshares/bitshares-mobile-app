//
//  VCBlindOutputAddOne.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  新增or编辑隐私输出

#import "VCBase.h"

@interface VCBlindOutputAddOne : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithResultPromise:(WsPromiseObject*)result_promise asset:(NSDictionary*)asset n_max_balance:(NSDecimalNumber*)n_max_balance;

@end
