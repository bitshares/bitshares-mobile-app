//
//  VCGatewayDeposit.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  网关充币

#import "VCBase.h"

@interface VCGatewayDeposit : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithUserFullInfo:(id)fullAccountData depositAddrItem:(id)depositAddrItem depositAssetItem:(id)depositAssetItem;

@end
