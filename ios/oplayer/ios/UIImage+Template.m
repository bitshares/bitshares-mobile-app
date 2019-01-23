//
//  UIImage+Template.m
//  oplayer
//
//  Created by Aonichan on 16/1/30.
//
//

#import "UIImage+Template.h"

@implementation UIImage(Template)

+ (UIImage*)templateImageNamed:(NSString*)name
{
    return [[UIImage imageNamed:name] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@end
