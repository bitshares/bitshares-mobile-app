//
//  VCBlindAccountImport.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  导入隐私地址

#import "VCBase.h"

@interface VCBlindAccountImport : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithResultPromise:(WsPromiseObject*)result_promise;

@end
