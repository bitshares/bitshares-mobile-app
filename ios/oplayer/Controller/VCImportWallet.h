//
//  VCImportWallet.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCBase.h"
#import "GCDWebUploader.h"

@interface VCImportWallet : VCBase<GCDWebUploaderDelegate, UITableViewDelegate, UITableViewDataSource>

- (id)initWithOwner:(VCBase*)owner;

@end
