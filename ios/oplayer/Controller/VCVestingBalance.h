//
//  VCVestingBalance.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  待解冻金额

#import "VCBase.h"

@interface VCVestingBalance : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

/**
 *  (public) 计算已经解冻的余额数量。（可提取的）
 */
+ (unsigned long long)calcVestingBalanceAmount:(id)vesting;

@end
