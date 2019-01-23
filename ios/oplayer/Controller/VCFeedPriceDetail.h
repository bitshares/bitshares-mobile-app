//
//  VCFeedPriceDetail.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

@interface VCFeedPriceDetailSubPage : VCBase<UITableViewDelegate, UITableViewDataSource>

- (id)initWithOwner:(VCBase*)owner asset:(NSDictionary*)asset;
- (void)onQueryFeedInfoResponsed:(id)data activeWitnessIds:(NSArray*)activeWitnessIds;

@end

@interface VCFeedPriceDetail : VCSlideControllerBase

@end
