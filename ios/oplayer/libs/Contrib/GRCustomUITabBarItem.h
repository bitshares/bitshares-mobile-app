//
//  GRCustomUITabBarItem.h
//  TabBar
//
//  Created by apple on 11-9-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
//the custom menuBar
@interface GRCustomUITabBarItem : UITabBarItem {
    UIImage  *customHighlightedImage;
	UIImage  *normalImage;
	NSString *imageString;
}
@property (nonatomic, retain) UIImage *customHighlightedImage;
@property (nonatomic, retain) UIImage  *normalImage;
@property (nonatomic,copy)    NSString *imageString;
- (id)initWithTitle:(NSString *)title tag:(NSInteger)tag;
@end
