//
//  FaceCell.h
//  oplayer
//
//  Created by SYALON on 13-11-20.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewFaceCell : UITableViewCellBase

- (id)init;

- (void)refreshBackgroundOffset:(NSInteger)offset;
- (NSInteger)getMaxDragHeight;

@end
