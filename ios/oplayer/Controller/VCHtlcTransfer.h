//
//  VCHtlcTransfer.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"

/**
 *  HTLC合约部署方式。
 */
typedef enum EHtlcDeployMode
{
    EDM_PREIMAGE = 0,       //  根据原像部署
    EDM_HASHCODE,           //  根据Hash部署
} EHtlcDeployMode;

@interface VCHtlcTransfer : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithUserFullInfo:(NSDictionary*)full_account_data
                      mode:(EHtlcDeployMode)mode
              havePreimage:(BOOL)havePreimage
                  ref_htlc:(id)ref_htlc
                    ref_to:(id)ref_to;

@end
