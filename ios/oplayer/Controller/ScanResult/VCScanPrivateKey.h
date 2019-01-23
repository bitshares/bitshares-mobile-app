//
//  VCScanPrivateKey.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

@interface VCScanPrivateKey : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithPriKey:(NSString*)priKey pubKey:(NSString*)pubKey fullAccountData:(NSDictionary*)fullAccountData;

@end
