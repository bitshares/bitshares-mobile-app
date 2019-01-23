//
//  VCKLine.h
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCBase.h"

@interface VCKLine : VCBase<UITableViewDelegate, UITableViewDataSource>

- (id)initWithBaseAsset:(NSDictionary*)baseAsset quoteAsset:(NSDictionary*)quoteAsset;

@end
