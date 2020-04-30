//
//  VCPaySuccess.h
//  oplayer
//
//  Created by SYALON on 13-10-10.
//
//

#import "VCBase.h"

@interface VCPaySuccess : VCBase<UITableViewDelegate, UITableViewDataSource>

- (id)initWithResult:(NSArray*)trx_result
          to_account:(NSDictionary*)to_account
       amount_string:(NSString*)amount_string
  success_tip_string:(NSString*)success_tip_string;

@end
