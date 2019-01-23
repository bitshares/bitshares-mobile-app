//
//  VCTransfer.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"
#import <MessageUI/MessageUI.h>

@interface VCTransfer : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, MFMessageComposeViewControllerDelegate>

- (id)initWithUserFullInfo:(NSDictionary*)full_account_data defaultAsset:(NSDictionary*)defaultAsset;

@end
