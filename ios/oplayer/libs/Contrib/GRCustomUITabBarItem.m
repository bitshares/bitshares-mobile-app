//
//  GRCustomUITabBarItem.m
//  TabBar
//
//  Created by apple on 11-9-27.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GRCustomUITabBarItem.h"
#import "UIImage+Template.h"

@implementation GRCustomUITabBarItem
@synthesize customHighlightedImage,normalImage,imageString;
- (void)dealloc
{
    customHighlightedImage = nil;
    normalImage = nil;
}

- (UIImage *) selectedImage
{
	NSString *string = [NSString stringWithFormat:@"%@_b.png",self.imageString];
    return [UIImage templateImageNamed:string];
}

- (UIImage*) unselectedImage
{
	NSString *string = [NSString stringWithFormat:@"%@.png",self.imageString];
    return [UIImage templateImageNamed:string];
}

- (id)initWithTitle:(NSString *)title tag:(NSInteger)tag
{
	return [self initWithTitle:title image:nil tag:tag];
}
@end
