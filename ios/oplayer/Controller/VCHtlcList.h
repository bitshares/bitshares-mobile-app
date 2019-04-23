//
//  VCHtlcList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  HTLC object list / 哈希时间锁合约列表

#import "VCBase.h"

@interface VCHtlcList : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner fullAccountInfo:(NSDictionary*)accountInfo;

/**
 *  (public) 计算已经解冻的余额数量。（可提取的）
 */
+ (unsigned long long)calcVestingBalanceAmount:(id)vesting;

/**
 *  (public) query user htlc objects
 */
- (void)queryUserHTLCs;

@end
