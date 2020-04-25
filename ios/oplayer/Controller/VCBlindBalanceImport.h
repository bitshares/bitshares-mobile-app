//
//  VCBlindBalanceImport.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  导入隐私转账收据

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCBlindBalanceImport : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIScrollViewDelegate>

- (id)initWithReceipt:(NSString*)receipt result_promise:(WsPromiseObject*)result_promise;

@end
