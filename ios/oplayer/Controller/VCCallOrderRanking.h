//
//  VCCallOrderRanking.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import <UIKit/UIKit.h>
#import "VCSlideControllerBase.h"

@interface VCRankingList : VCBase<UITableViewDelegate, UITableViewDataSource>

- (id)initWithOwner:(VCBase*)owner asset:(NSDictionary*)asset;
- (void)onQueryCallOrderResponsed:(id)data;

@end

@interface VCCallOrderRanking : VCSlideControllerBase

@end
